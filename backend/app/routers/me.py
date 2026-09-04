"""Korumali ornek endpoint'ler — auth + tenant context + RBAC uctan uca dogrulama.

NOT: /me/checkpoints ve /admin/overview Faz-0 dogrulama amacli iskelet
endpoint'lerdir (openapi sozlesmesinde degiller). Gercek Checkpoint CRUD ve
panel uclari Prompt 3+'te sozlesmeye gore eklenecek.
"""
from __future__ import annotations

import logging
import uuid

from fastapi import APIRouter, Depends, Response
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, record_audit
from ..audit import audit_user
from ..db import SessionLocal, set_tenant
from ..deps import (
    get_current_user,
    get_redis,
    get_tenant_db,
    gorev_penceresi_disinda,
    require_role,
)
from ..errors import APIError
from ..gunlukleme import maskele_kimlik
from ..hiz_siniri import kod_istegi_say
from ..telefon_kodu import (
    eposta_kodu_uret_ve_gonder,
    eposta_kodunu_dogrula,
    kodu_dogrula,
)
from ..hesap_silme import hesabi_sil_veya_anonimlestir, son_admin_mi
from ..models import AppUser, AuditLog, Checkpoint, UserDevice
from ..schemas import (
    TesisDegistirIstek,
    TesisUyeligi,
    TesislerimYanit,
    TokenPair,
    AvatarUpdate,
    BildirimTercihleri,
    BildirimTercihUpdate,
    CheckpointBrief,
    CihazOut,
    HesapEtkinligiOut,
    HesapSilmeIstek,
    HesapSilmeSonuc,
    MeContactUpdate,
    MeEpostaDogrulaRequest,
    MeEpostaEkleRequest,
    MeProfileOut,
    MeTemaRequest,
    PasswordChangeRequest,
    UserOut,
)
from ..security import (
    access_token_ttl_seconds,
    create_access_token,
    create_refresh_token,
    hash_password,
    verify_password,
)
from ..storage import delete_objects, presign_get

logger = logging.getLogger(__name__)

router = APIRouter(tags=["me"])

# Self-servis profil fotografi — KENDI fotografi.
#
# (P167 §1.7) ADMIN VE DENETCI EKLENDI. Eski kume `yonetici + resident`ti ve
# gerekcesi "admin'e self-servis gerekmez"di. O gerekce bu turda GECERSIZ
# oldu: panelin sag ust kosesinde artik HER rol icin avatar cizilyor
# (`KullaniciMenusu`) ve profil sayfasi hepsine acik. Yukleme dugmesini
# gosterip ucun 403 dondurmesi, kullaniciya sebebi olmayan bir hata
# vermekti; dugmeyi role gore gizlemek ise ayni kurali ikinci bir yerde
# (istemcide) tekrar etmek olurdu.
#
# SAHA PERSONELI (security / tesis_gorevlisi) HALA DISARIDA ve bu bilincli:
# onlarin fotografi bir SUS degil OPERASYONEL KIMLIK kaydidir (vardiya,
# devriye, ziyaretci karsilama) ve yonetim `PATCH /users/{id}/avatar` ile
# yonetir. Kendi degistirebilselerdi, kimin kim oldugunu gosteren kayit
# denetlenemez hale gelirdi.
_AVATAR_ROLLER = require_role("admin", "yonetici", "denetci", "resident")


def _user_out(user: AppUser) -> UserOut:
    """AppUser -> UserOut; avatar_key varsa presigned GET URL doldurur."""
    return UserOut(
        id=user.id, tenant_id=user.tenant_id, ad=user.ad, email=user.email,
        eposta_dogrulandi=bool(user.eposta_dogrulandi),
        role=user.role, is_active=user.is_active,
        avatar_url=presign_get(user.avatar_key) if user.avatar_key else None,
        ui_tema=user.ui_tema,
    )


def _profile_out(user: AppUser) -> MeProfileOut:
    """(P167 §1.7) AppUser -> MeProfileOut; `avatar_url` presign ile doldurulur.

    `from_attributes` tek basina YETMEZ: modelde `avatar_key` (obje anahtari)
    var, semada `avatar_url` (kisa omurlu imzali baglanti). Anahtari
    istemciye vermek, bir kullanicinin baska bir tenant'in objesini
    tahmin etmesine zemin hazirlardi — `_user_out` ile AYNI kural.
    """
    out = MeProfileOut.model_validate(user)
    out.avatar_url = presign_get(user.avatar_key) if user.avatar_key else None
    return out


@router.get("/me", response_model=UserOut)
async def me(user: AppUser = Depends(get_current_user)) -> UserOut:
    """Access token'daki kullaniciyi doner (tenant context token'dan)."""
    return _user_out(user)


@router.patch("/me/tema", response_model=UserOut)
async def tema_guncelle(
    body: MeTemaRequest,
    user: AppUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_tenant_db),
) -> UserOut:
    """(P190 §5) Tema tercihi — HESAPTA saklanir (cihaz degil).

    Kozmetik bir tercihtir: denetime YAZILMAZ (bildirim/pazarlama
    tercihlerinin aksine hukuki bir sonucu yok). Deger `MeTemaRequest`in
    Literal'iyla sinirli; semadaki CHECK (goc 0076) ikinci savunma.
    """
    user.ui_tema = body.tema
    user.updated_at = func.now()
    await db.flush()
    return _user_out(user)


@router.patch("/me/avatar", response_model=UserOut)
async def update_my_avatar(
    body: AvatarUpdate,
    user: AppUser = Depends(_AVATAR_ROLLER),
    db: AsyncSession = Depends(get_tenant_db),
) -> UserOut:
    """Self-servis profil fotografi — YALNIZ personel rolleri (resident 403).

    Anahtar kendi tenant namespace'inde olmali (announcement _validate_foto_key
    deseni — IDOR engeli). Degisen/kaldirilan eski obje MinIO'dan silinir
    (artik erisilemez cop)."""
    if body.avatar_key is not None and not body.avatar_key.startswith(
        f"{user.tenant_id}/"
    ):
        raise APIError(422, "invalid_foto_key", "avatar_key_alan_disi")
    eski = user.avatar_key
    user.avatar_key = body.avatar_key
    user.updated_at = func.now()
    if eski and eski != body.avatar_key:
        delete_objects([eski])
    await audit_user(
        db, user, Action.AVATAR_UPDATE, resource_type="app_user",
        resource_id=user.id, meta={"kaldirildi": body.avatar_key is None},
    )
    return _user_out(user)


@router.get("/me/profile", response_model=MeProfileOut)
async def my_profile(user: AppUser = Depends(get_current_user)) -> MeProfileOut:
    """Self-servis profil: kullanicinin KENDI kimlik + iletisim alanlari.

    Tum roller kendi kaydini gorur (auth.md self-servis profil).
    """
    return _profile_out(user)


@router.patch("/me/password", status_code=204)
async def change_my_password(
    body: PasswordChangeRequest,
    user: AppUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_tenant_db),
) -> Response:
    """Self-servis parola degisimi — mevcut parola dogrulanir (auth.md).

    Mevcut parola hatali → 400 invalid_credentials (hangi alanin patladigi net;
    login'deki gizlilik ilkesi burada gerekmez — kullanici zaten kimlikli).
    Basarida yeni bcrypt hash yazilir; oturum (refresh) devam eder.
    """
    # (P149) PAROLASIZ KULLANICI DA PAROLA BELIRLEYEBILMELI.
    #
    # P148 sakinleri `password_hash=NULL` ile aciliyor; parolasi olmayan kisi
    # bu uctan bir parola KURAR. Dogrulama ARACI degisir, GUCU degismez:
    # parolasi olanda mevcut parola, olmayanda KOD ile sahiplik kaniti.
    #
    # (P184) KANAL E-POSTA: kod `amac='hesap_silme'` ile uretilir (hesap-sil
    # ile ayni tek-kullanimlik kanal) ve dogrulanmis e-posta varsa E-POSTA
    # kodu, yoksa telefon kodu dogrulanir — SMS kapali oldugundan bugun
    # calisan yol e-postadir. Giris/e-posta-ekleme kodu buraya YARAMAZ.
    if user.password_hash is None:
        if not body.kod:
            raise APIError(400, "code_required", "silme_kodu_gerekli")
        if user.email and user.eposta_dogrulandi:
            kayit = await eposta_kodunu_dogrula(
                db, tenant_id=user.tenant_id, eposta=user.email,
                kod=body.kod, amac="hesap_silme",
            )
            kayit.durum = "onaylandi"  # tek kullanimlik: tuket.
            kayit.karar_at = func.now()
        else:
            await kodu_dogrula(
                db, telefon=user.telefon or "", kod=body.kod, amac="hesap_silme"
            )
    elif not verify_password(body.current_password or "", user.password_hash):
        raise APIError(400, "invalid_credentials", "mevcut_parola_hatali")
    user.password_hash = hash_password(body.new_password)
    user.password_set = True
    user.updated_at = func.now()
    await audit_user(
        db, user, Action.PASSWORD_CHANGE, resource_type="app_user",
        resource_id=user.id,
    )
    # get_tenant_db transaction'i cikista commit eder (user ayni oturuma bagli).
    return Response(status_code=204)


# =========================================================================== #
# (P197) TELEFON (SMS) ILE SILME KODU UCU KALDIRILDI
# =========================================================================== #
# `POST /me/hesap-sil/kod-iste` SILINDI. Gerekcesi P196'da yazilan istisnanin
# ortadan kalkmasidir:
#
#   P196'da o ucta 502 donmemeyi SECMISTIK, cunku SMS urun genelinde kapali
#   olmasina ragmen uc kaldirilirsa TELEFON-ONLY bir kullanicinin hesabini
#   silmesinin hicbir yolu kalmiyordu (magaza sarti). Yani uc, calismadigi
#   hâlde "tek yol" oldugu icin duruyordu.
#
#   (P197) ARTIK TELEFON-ONLY KULLANICI YOK: `app_user.email` NOT NULL
#   (goc 0089) ve e-postasiz hesap acan tum yollar kapatildi. Herkesin bir
#   e-postasi var, dolayisiyla herkes `/me/hesap-sil/eposta-kod-iste`
#   kullanabilir. Calismayan bir ucu "tek yol" diye tutmanin gerekcesi
#   kalmadi ve calismayan bir uc, kullaniciya "kod gonderildi" diyen bir
#   yalandan ibaretti.
#
# MEVCUT E-POSTASIZ HESAPLAR (goc 0089'da sentetik adres alanlar) bu ucu
# zaten kullanamiyordu: SMS kapali oldugu icin kod hicbir zaman gitmiyordu.
# Onlar icin degisen bir sey YOK.
#
# `POST /me/hesap-sil` (asil silme) DEGISMEDI: kodu `amac='hesap_silme'`
# ile dogrular ve kodun hangi kanaldan gittigini bilmez.


@router.post("/me/hesap-sil/eposta-kod-iste", response_model=dict)
async def hesap_silme_eposta_kodu_iste(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(get_current_user),
    redis=Depends(get_redis),
) -> dict[str, str]:
    """(P184) Parolasiz kullanici icin silme onay kodu — E-POSTAYA.

    (P197) ARTIK TEK YOL. SMS kardesi (`/me/hesap-sil/kod-iste`) kaldirildi;
    e-postasiz hesap kalmadigi icin (goc 0089) ona ihtiyac yok. `SMS_AKTIF=false`
    oldugundan bugun calisan yol budur; SSO ile kaydolan (parolasiz) kullanici
    kendi hesabini boyle silebilir. Kod `amac='hesap_silme'` ile uretilir —
    giris/parola/e-posta-ekleme kodu buraya YARAMAZ. Kilitleme YOK; oturum surer.
    """
    if not user.email or not user.eposta_dogrulandi:
        raise APIError(422, "no_email", "eposta_yok")
    await kod_istegi_say(redis, user.email, kapsam="hesap_silme_eposta")
    await _kod_gonder_ve_dogrula(
        db, tenant_id=user.tenant_id, eposta=user.email, amac="hesap_silme"
    )
    return {"durum": "gonderildi"}


@router.post("/me/eposta/kod-iste", response_model=dict)
async def eposta_dogrulama_kodu_iste(
    body: MeEpostaEkleRequest,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(get_current_user),
    redis=Depends(get_redis),
) -> dict[str, str]:
    """(P181 Bölüm 1) Mevcut kullanıcının e-postasını ekleme/doğrulama kodu.

    E-postasız YA DA e-postalı-ama-doğrulanmamış kullanıcı bir adres verir; koda
    gider. KİLİTLEME YOK — oturum sürer, bu yalnız "beklemede" durumu açar.
    Hız sınırı e-posta başına (kaba kuvvete karşı).
    """
    eposta = str(body.eposta).strip().lower()
    if "@" not in eposta or "." not in eposta.split("@")[-1]:
        raise APIError(422, "validation_error", "eposta_gecersiz")
    await kod_istegi_say(redis, eposta, kapsam="eposta_ekle")
    # =====================================================================
    # (P212-ek §1) ADRES BASKASINDAYSA: SESSIZ "gonderildi" DEGIL, 409
    # =====================================================================
    # OLCULEN KUSUR (prod): kullanici profilden e-postasini degistirdi,
    # ekran "dogrulama bekliyor" dedi, `mesaj_gonderim` tablosunda O
    # ADRESE AIT HIC KAYIT OLUSMADI. Sebep SMTP degil: akis gonderimi HIC
    # TETIKLEMIYORDU — istek bu erken `return`de bitiyordu.
    #
    # P184-ek §9 burada 409'u KALDIRIP tek bicimli yanita gecmisti;
    # gerekcesi "409 bir 'bu adres kimde' sorgusudur" idi. Karar
    # DEGISTIRILDI ve nedeni su:
    #
    #   1. BU UC KIMLIK DOGRULANMIS ve TENANT'A KAPALI. `auth.py`deki
    #      giris-kodu/parola-sifirlama uclari KIMLIKSIZDIR — orada tek
    #      bicimli yanit ZORUNLU ve DOKUNULMADI. Burada soran kisi zaten
    #      o tesisin uyesi; ogrendigi sey "bu adres tesisimde kayitli".
    #      Sakin listesi, personel listesi ve daire sakinleri o kisiye
    #      zaten gorunuyor — kazanc kucuk.
    #   2. BEDELI KALICI BIR CIKMAZDI: kullanici kendi e-postasini
    #      duzeltemiyor, neden olmadigini ogrenemiyor ve ekran ona
    #      "bekleyin" diyor. Sessizce yanlis calisan bir akis, bilgi
    #      sizdirmayan ama KULLANILAMAZ bir akistir.
    #   3. Kaba kuvvet ZATEN sinirli: `kod_istegi_say` adres basina hiz
    #      siniri uyguluyor (yukarida, bu daldan ONCE calisir).
    #
    # KIM OLDUGU YINE SIZMAZ: yanit yalnizca "bu adres kullanimda" der,
    # hangi kullanicida oldugunu SOYLEMEZ.
    baska = (
        await db.execute(
            select(AppUser.id).where(
                func.lower(AppUser.email) == eposta, AppUser.id != user.id
            )
        )
    ).scalar_one_or_none()
    if baska is not None:
        raise APIError(409, "conflict", "eposta_kullanimda")
    # (P184-ek §9) DEĞİŞTİRME BİLDİRİMİ: kullanıcının DOĞRULANMIŞ eski adresi
    # varsa ve yeni adres farklıysa, ESKİ adrese "değiştirme talebi alındı"
    # bildirimi gider (hesap ele geçirilmişse sahibi fark etsin). Eski adres
    # doğrulanana kadar GEÇERLİ kalır (`user.email` yalnız `dogrula`da değişir)
    # — kullanıcı arada kilitlenmez.
    if (
        user.email
        and user.eposta_dogrulandi
        and user.email.strip().lower() != eposta
    ):
        await _eposta_degistirme_bildirimi(db, user.tenant_id, user.email)
    await _kod_gonder_ve_dogrula(
        db, tenant_id=user.tenant_id, eposta=eposta, amac="eposta_ekle"
    )
    return {"durum": "gonderildi"}


async def _kod_gonder_ve_dogrula(
    db, *, tenant_id, eposta: str, amac: str
) -> None:
    """(P196) Kodu gonderir ve GERCEKTEN GITTIGINI dogrular.

    =======================================================================
    OLCULEN KUSUR — IKI AYRI HATA, TEK SONUC
    =======================================================================
    Kullanici profilden e-postasini degistiriyor, ekran "kod gonderildi"
    diyor, posta kutusuna HICBIR SEY gelmiyordu. Iki sebep vardi:

    1. `ayar` GECILMIYORDU. `eposta_kodu_uret_ve_gonder`in `ayar`
       parametresi opsiyonel ve verilmezse saglayici ENV'den secilir.
       Tesis KENDI SMTP'sini `mesaj_yapilandirma`ya girmisse ve ENV bos
       ise sonuc `LogEpostaSaglayici` olur: hicbir sey gonderilmez.
       OLCULDU — ayni dosyadaki oteki akislar (`auth.py` giris kodu ve
       parola sifirlama, `davet.py`) `ayar=ayar` GECIYOR ve calisiyor;
       yalniz bu iki cagri geciyordu. Kullanicinin gozlemi birebir
       bunu gosteriyordu: "davet ve OTP calisiyor, profil e-postasi
       gitmiyor". Bu, P172 §1'de kapatilan kusur sinifinin ta kendisi.

    2. GONDERIM SONUCU ATILIYORDU. Saglayici
       `durum='yapilandirilmadi'` donuyor, uc bunu okumadan
       `{"durum": "gonderildi"}` yaziyordu.

    =======================================================================
    NEDEN BURADA HATA DONUYORUZ (ama `auth.py`de DONMUYORUZ)
    =======================================================================
    Bu uclar KIMLIK DOGRULANMIS kullanicinin KENDI adresi icindir; hata
    donmek hicbir sey sizdirmaz. `auth.py`deki giris-kodu ve parola
    sifirlama uclari ise SIZDIRMAMA icin tek bicimli yanit verir: orada
    gonderim hatasini kullaniciya yansitmak "bu adres kayitli" demek
    olurdu (hata = adres var). O yuzden orada YALNIZ LOG var, burada
    log + HATA.
    """
    from ..gonderim import tenant_ayari

    ayar = await tenant_ayari(db, tenant_id)
    sonuc = await eposta_kodu_uret_ve_gonder(
        db, tenant_id=tenant_id, eposta=eposta, amac=amac, ayar=ayar
    )
    # =====================================================================
    # (P212-ek §1) YAPISAL KAPI: GONDERIM KAYDI YOKSA "gonderildi" YOK
    # =====================================================================
    # P196 "gonderim BASARISIZ oldu ama basarili dendi" halini kapatti.
    # ACIK KALAN hal ise "gonderim HIC DENENMEDI ama basarili dendi"ydi
    # ve prod'da tam olarak o yasandi: `mesaj_gonderim`de o adrese ait
    # HICBIR kayit yoktu.
    #
    # Bu kontrol ikisini de kapsar cunku SONUCA DEGIL IZE bakar: gonderim
    # denendiyse `telefon_kodu` AYRI OTURUMDA bir `mesaj_gonderim` satiri
    # yazar (basarili ya da basarisiz). Satir yoksa gonderim yolu hic
    # calismamistir — cagirinin hangi yeni erken-donusu eklendiginden
    # BAGIMSIZ olarak yakalanir. Yani bir sonraki "erken return"u de
    # bu kapi durdurur.
    if not await _gonderim_izi_var(tenant_id, eposta):
        logger.error(
            "kod gonderimi IZ BIRAKMADI amac=%s hedef=%s — akis gonderimi "
            "tetiklemedi", amac, maskele_kimlik(eposta),
        )
        raise APIError(502, "bad_gateway", "kod_gonderilemedi")
    if sonuc.durum != "gonderildi":
        # HATA DONUNCA istek transaction'i geri alinir; uretilen kod
        # satiri da gider. BU DOGRUDUR: gonderilmemis bir kodu
        # veritabaninda birakmak, kullanicinin asla ogrenemeyecegi bir
        # sirri saklamak olurdu. Teshis kaydi (`mesaj_gonderim`) AYRI
        # oturumda yazildigi icin geri alinmaz — bkz. `telefon_kodu`.
        raise APIError(502, "bad_gateway", "kod_gonderilemedi")


async def _gonderim_izi_var(tenant_id, eposta: str) -> bool:
    """(P212-ek §1) Son bir dakikada bu adrese GONDERIM KAYDI dustu mu?

    AYRI OTURUM: teshis kaydi da ayri oturumda yaziliyor (bkz.
    `telefon_kodu`); cagiranin oturumundan okumak, henuz commit edilmemis
    bir satiri aramak olurdu ve kapi HER ZAMAN kapali kalirdi.

    PENCERE 1 DAKIKA: "bu istekte yazildi mi" sorusunun pratik karsiligi.
    Daha genis bir pencere, onceki bir denemenin izini bu istegin izi
    sanardi.
    """
    from datetime import datetime, timedelta, timezone

    from ..db import SessionLocal, set_tenant
    from ..models import MesajGonderim

    sinir = datetime.now(tz=timezone.utc) - timedelta(minutes=1)
    async with SessionLocal() as oturum:
        await set_tenant(oturum, tenant_id)
        return (
            await oturum.execute(
                select(MesajGonderim.id).where(
                    MesajGonderim.kanal == "eposta",
                    func.lower(MesajGonderim.hedef) == eposta.lower(),
                    MesajGonderim.created_at >= sinir,
                ).limit(1)
            )
        ).scalar_one_or_none() is not None


async def _eposta_degistirme_bildirimi(db, tenant_id, eski_adres: str) -> None:
    """(P184-ek §9) ESKİ adrese değiştirme bildirimi (kod DEĞİL) gönderir.

    Hata YUTULUR: bildirim gönderilemese de (SMTP kapalı/hatalı) e-posta
    değiştirme akışı engellenmemeli — bildirim bir güvenlik uyarısıdır, akışın
    ön koşulu değil.
    """
    from ..eposta_sablonlari import eposta_degistirme_bildirimi_metni
    from ..gonderim import saglayici as kanal_saglayicisi
    from ..gonderim import tenant_ayari

    try:
        ayar = await tenant_ayari(db, tenant_id)
        konu, govde = eposta_degistirme_bildirimi_metni()
        kanal_saglayicisi("eposta", ayar).gonder(eski_adres, konu, govde)
    except Exception:  # noqa: BLE001 — bildirim akışı engellemez
        pass


@router.post("/me/eposta/dogrula", response_model=UserOut)
async def eposta_dogrula_ekle(
    body: MeEpostaDogrulaRequest,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(get_current_user),
) -> UserOut:
    """(P181 Bölüm 1) Kod doğru → e-posta yazılır ve eposta_dogrulandi=true.

    Bundan sonra parola sıfırlama (Bölüm 2) ve OTP giriş (Bölüm 4) çalışır.
    """
    eposta = str(body.eposta).strip().lower()
    kayit = await eposta_kodunu_dogrula(
        db, tenant_id=user.tenant_id, eposta=eposta, kod=body.kod, amac="eposta_ekle"
    )
    # kod-iste ile dogrula arasında başka kullanıcı bu adresi doğrulamış olabilir:
    # unique kısıt (uq_app_user_tenant_email) commit'te 500 verirdi; net 409 döndür.
    baska = (
        await db.execute(
            select(AppUser.id).where(AppUser.email == eposta, AppUser.id != user.id)
        )
    ).scalar_one_or_none()
    if baska is not None:
        raise APIError(409, "conflict", "eposta_kullanimda")
    kayit.durum = "onaylandi"  # tek kullanımlık: verify helper yalnız
    kayit.karar_at = func.now()  # 'telefon_bekliyor' arar -> tekrar doğrulanamaz
    user.email = eposta
    user.eposta_dogrulandi = True
    user.updated_at = func.now()
    await audit_user(
        db, user, Action.USER_CONTACT_UPDATE, resource_type="app_user",
        resource_id=user.id, meta={"alan": "eposta_dogrulandi"},
    )
    return _user_out(user)


@router.post("/me/hesap-sil", response_model=HesapSilmeSonuc)
async def delete_my_account(
    body: HesapSilmeIstek,
    user: AppUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_tenant_db),
) -> HesapSilmeSonuc:
    """SELF-SERVIS HESAP SILME (App Store 5.1.1(v), P112).

    Apple'in kurali net: hesap acilabiliyorsa **uygulama icinden**
    silinebilmeli — destege yazdirmak, e-posta gonderttirmek ya da web
    sitesine yonlendirmek **reddedilme sebebidir**.

    YENIDEN KIMLIK DOGRULAMA ZORUNLU. Access token'i olan biri (odunc
    alinmis, kilidi acik birakilmis telefon) tek dokunusla baskasinin
    hesabini silememeli. `PATCH /me/password` ile AYNI desen: mevcut parola
    dogrulanir, hata 400 `invalid_credentials`.

    SON YONETICI ENGELI: tesisin tek admin/yoneticisi kendini silerse tesis
    **sahipsiz** kalir (kimse yeni yonetici atayamaz, aidat isleyemez).
    409 doner ve ne yapilmasi gerektigini soyler: **once devret**. Bu Apple
    kuralina aykiri degildir — kural "hesap silinebilmeli" der, "tesisi
    kullanilamaz hale getir" demez; kullanicinin onunde acik ve tek adimlik
    bir yol vardir.

    NE SILINIR / NE KALIR: bkz. `app/hesap_silme.py` (tek kaynak). Ozet:
    kimlik alanlari + cihaz kayitlari gider; yasal saklama yukumlulugu olan
    finans/denetim satirlari **anonim** olarak kalir.
    """
    # (P149) PAROLASIZ KULLANICI DA HESABINI SILEBILMELI.
    #
    # P148 sakinleri `password_hash=NULL` ile aciyor; burasi kosulsuz parola
    # ariyordu, yani kendi kaydolan sakin hesabini SILEMIYORDU. Play'in
    # "silme yolu calismali" sarti dogrudan ihlal ediliyordu.
    #
    # Dogrulama ARACI degisir, GUCU degismez: parolasi olanda parola,
    # olmayanda telefonuna gonderilen KOD. Ikisi de "hesabin sahibi
    # oldugunu kanitla" ayni esigi tasir; kod `amac='hesap_silme'` ile
    # uretilir, giris kodu buraya YARAMAZ.
    if user.password_hash is None:
        if not body.kod:
            raise APIError(400, "code_required", "silme_kodu_gerekli")
        # (P184) Dogrulama kanali kullanicinin SAHIP OLDUGUNA gore secilir:
        # dogrulanmis e-posta varsa E-POSTA kodu (SMS kapali, bugun tek calisan
        # yol), yoksa telefon kodu (SMS ileride acilirsa). Ikisi de
        # `amac='hesap_silme'`; kanallar karismaz.
        if user.email and user.eposta_dogrulandi:
            kayit = await eposta_kodunu_dogrula(
                db, tenant_id=user.tenant_id, eposta=user.email,
                kod=body.kod, amac="hesap_silme",
            )
            # Tek kullanimlik: verify yalniz 'telefon_bekliyor' arar; tuket.
            kayit.durum = "onaylandi"
            kayit.karar_at = func.now()
        else:
            await kodu_dogrula(
                db, telefon=user.telefon or "", kod=body.kod, amac="hesap_silme"
            )
    elif not verify_password(body.current_password or "", user.password_hash):
        raise APIError(400, "invalid_credentials", "mevcut_parola_hatali")
    if await son_admin_mi(db, user):
        raise APIError(409, "conflict", "son_yonetici_devretmeden_silinemez")

    # Aktor bilgisi ONCE kopyalanir: `hard_delete` yolunda `user` satiri
    # kalkar ve ORM nesnesinden okuma yapmak guvenli degildir.
    aktor_id, aktor_rol, aktor_tenant = user.id, user.role, user.tenant_id

    tam_silindi = await hesabi_sil_veya_anonimlestir(db, user, kendi_istegi=True)

    await record_audit(
        db,
        action=Action.ACCOUNT_SELF_DELETE,
        tenant_id=aktor_tenant,
        actor_user_id=aktor_id,
        actor_rol=aktor_rol,
        resource_type="app_user",
        resource_id=aktor_id,
        meta={"mode": "hard_delete" if tam_silindi else "anonymize"},
    )
    return HesapSilmeSonuc(deleted=tam_silindi)


@router.patch("/me/contact", response_model=MeProfileOut)
async def update_my_contact(
    body: MeContactUpdate,
    user: AppUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_tenant_db),
) -> MeProfileOut:
    """Self-servis iletisim: kullanici KENDI ad + telefon + aranabilir rizasini yonetir.

    Yonetim ucu (PATCH /users/{id}/contact, admin/yonetici -> baskasi) ayri kalir;
    bu onun kendi-kaydi karsiligidir. Numara OTP'siz dogrudan kaydedilir.

    (P167 §1.7) `ad` BURAYA EKLENDI, yonetim ucuna DEGIL (bkz.
    `MeContactUpdate`). `email` bilerek DISARIDA: login anahtaridir ve
    dogrulama akisi olmadan degistirilmesi hesabi kaybettirebilir.
    """
    data = body.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(user, key, value)
    user.updated_at = func.now()
    await audit_user(
        db, user, Action.USER_CONTACT_UPDATE, resource_type="app_user",
        resource_id=user.id, meta={"self": True, "fields": list(data.keys())},
    )
    return _profile_out(user)


# =========================================================================== #
# (P167 §1.7) "GUVENLIK VE GIRIS" — kendi cihazlarim + kendi hesap etkinligim
# =========================================================================== #
#
# IKISI DE VAR OLAN UCLARIN KISITLI KOPYASI DEGIL, AYRI YETKI KARARLARIDIR:
#
#   GET /devices  -> TENANT'in tum cihazlari, YALNIZ admin (hata ayiklama).
#   GET /audit    -> TESISIN tum denetim kaydi, admin + denetci.
#
# Buradaki iki uc ise HER ROLE acik ve YALNIZ kisinin KENDI satirlarini
# doner. Kendi hesabinda hangi cihazin acik oldugunu ve son ne yapildigini
# gormek bir yonetim yetkisi degil, hesap guvenliginin en temel kosuludur —
# "sifremi baskasi mi biliyor" sorusunun tek cevaplanabilir yoludur.
#
# SUZGEC SUNUCUDA: istemciye tum liste gonderip orada suzmek, satirlarin
# TARAYICIYA ULASMASI demekti. Yetki, veriyi ureten sorgunun icinde.


@router.get("/me/cihazlar", response_model=list[CihazOut])
async def my_devices(
    user: AppUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_tenant_db),
) -> list[UserDevice]:
    """Kendi kayitli cihazlarim — en son gorunen ustte.

    PASIF CIHAZLAR DA DONER (`aktif=false`): "kaldirdim mi gercekten"
    sorusunun cevabi listede gorunmeli. Arayuz onlari soluk cizer.
    """
    rows = (
        await db.execute(
            select(UserDevice)
            .where(UserDevice.user_id == user.id)
            # `id` kirici — `/me/etkinlik` ile ayni gerekce: ayni saniyede
            # kaydedilen iki cihaz kararsiz sira verirdi. Bu uc sayfalamiyor
            # ama liste ekranda duruyor ve her tazelemede satirlarin yer
            # degistirmesi kullaniciya "bir sey degisti" hissi verirdi.
            .order_by(UserDevice.updated_at.desc(), UserDevice.id.desc())
        )
    ).scalars().all()
    return list(rows)


@router.delete("/me/cihazlar/{cihaz_id}", status_code=204)
async def remove_my_device(
    cihaz_id: uuid.UUID,
    user: AppUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_tenant_db),
) -> Response:
    """Bir cihazi KALDIR — satir silinmez, `aktif=false` olur.

    SILMEK YERINE PASIFLESTIRMEK bilincli: `uq_user_device_tenant_token`
    ayni token'in tekrar kaydini upsert'e cevirir; satiri silseydik ayni
    telefon yeniden giris yaptiginda YENI bir satir acilir ve kullanicinin
    cihaz gecmisi her giriste sifirlanirdi. Push gonderimi zaten `aktif`
    bayragina bakiyor — yani kaldirma ANINDA etkili.

    BASKASININ CIHAZI KALDIRILAMAZ: sorgu `user_id` ile kapali, bulunamayan
    satir 404. Baska bir kullanicinin cihaz id'sini tahmin etmek, ona
    bildirim gonderimini kesmek demekti.
    """
    cihaz = (
        await db.execute(
            select(UserDevice).where(
                UserDevice.id == cihaz_id, UserDevice.user_id == user.id
            )
        )
    ).scalar_one_or_none()
    if cihaz is None:
        raise APIError(404, "not_found", "cihaz_bulunamadi")
    cihaz.aktif = False
    cihaz.updated_at = func.now()
    await audit_user(
        db, user, Action.DEVICE_REMOVE, resource_type="user_device",
        resource_id=cihaz.id, meta={"self": True},
    )
    return Response(status_code=204)


@router.post("/me/cihazlar/tumunden-cik", response_model=dict)
async def remove_all_my_devices(
    user: AppUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_tenant_db),
) -> dict[str, int]:
    """TUM cihazlarimi kaldir — "telefonumu kaybettim" dugmesi.

    NE YAPMAZ: oturumlari sonlandirmaz. Refresh token'lar bu tabloda
    DEGIL ve burada sonlandirilmis gibi gostermek, kullaniciyi guvende
    sandigi hâlde guvende OLMADIGI bir yere birakirdi. Dugmenin metni de
    bunu soyler ("cihazlardan cik"), "her yerden cikis yap" demez.
    """
    rows = (
        await db.execute(
            select(UserDevice).where(
                UserDevice.user_id == user.id, UserDevice.aktif.is_(True)
            )
        )
    ).scalars().all()
    for cihaz in rows:
        cihaz.aktif = False
        cihaz.updated_at = func.now()
    await audit_user(
        db, user, Action.DEVICE_REMOVE, resource_type="user_device",
        resource_id=user.id, meta={"self": True, "adet": len(rows)},
    )
    return {"kaldirilan": len(rows)}


@router.get("/me/etkinlik", response_model=list[HesapEtkinligiOut])
async def my_activity(
    limit: int = 20,
    user: AppUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_tenant_db),
) -> list[AuditLog]:
    """Kendi hesap etkinligim — en yeni ustte, varsayilan son 20 satir.

    UST SINIR 100: denetim kaydi bir kullanici icin binlerce satira
    ciKabilir ve sinirsiz bir `limit`, tek istekle tabloyu suzduren bir
    yol acardi. Brief'in istedigi sayi 20; 100 rahat bir tavan.
    """
    n = max(1, min(limit, 100))
    rows = (
        await db.execute(
            select(AuditLog)
            .where(AuditLog.actor_user_id == user.id)
            # KARARLI SIRALAMA (`id` kirici): denetim satirlari toplu
            # yazildiginda `ts` MILISANIYESINE KADAR AYNI olabilir —
            # `audit_user` ayni islemde birden fazla satir yazar. Yalniz
            # `ts`e bakan bir siralama, ayni sorgunun iki cagrida farkli
            # sira dondurmesi demekti ve `limit` ile birleince bir satir
            # HER IKI sayfada da (ya da hicbirinde) gorunurdu.
            .order_by(AuditLog.ts.desc(), AuditLog.id.desc())
            .limit(n)
        )
    ).scalars().all()
    return list(rows)


# =========================================================================== #
# (P167 §1.7) BILDIRIM AYARLARI — kanal basina acik/kapali
# =========================================================================== #


@router.get("/me/bildirim-tercihleri", response_model=BildirimTercihleri)
async def my_notification_prefs(
    user: AppUser = Depends(get_current_user),
) -> AppUser:
    """Kendi bildirim kanali tercihlerim (e-posta / SMS / mobil)."""
    return user


@router.patch("/me/bildirim-tercihleri", response_model=BildirimTercihleri)
async def update_my_notification_prefs(
    body: BildirimTercihUpdate,
    user: AppUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_tenant_db),
) -> AppUser:
    """KISMI guncelleme — gonderilmeyen kanal DEGISMEZ.

    `/me/pazarlama-tercihleri` ile AYNI desen, AYRI kayit: oradaki bir
    KVKK RIZASI (varsayilani kapali, ispat yukumlulugu var), buradaki bir
    kullanim TERCIHI (varsayilani acik). Ikisini tek uca toplamak,
    pazarlamayi kapatan kisinin aidat bildirimini de kaybetmesi olurdu.

    DENETIME YAZILIR: "bildirimi neden almadim" sorusunun cevabi, tercihin
    NE ZAMAN degistigidir.
    """
    data = body.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(user, key, value)
    user.updated_at = func.now()
    await audit_user(
        db, user, Action.NOTIFICATION_PREFS_UPDATE, resource_type="app_user",
        resource_id=user.id, meta={"self": True, "fields": list(data.keys())},
    )
    return user


@router.get("/me/checkpoints", response_model=list[CheckpointBrief])
async def my_checkpoints(
    _user: AppUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_tenant_db),
) -> list[Checkpoint]:
    """Token'daki tenant'in checkpoint'lerini doner (RLS ile izole).

    Tenant izolasyonunu token uzerinden uctan uca dogrulamak icin (Faz-0).
    """
    rows = (await db.execute(select(Checkpoint).order_by(Checkpoint.ad))).scalars().all()
    return list(rows)


@router.get("/admin/overview", tags=["admin"])
async def admin_overview(
    user: AppUser = Depends(require_role("admin")),
) -> dict:
    """Sadece admin — RBAC demo (matristen ornek: yonetim ucu)."""
    return {"status": "ok", "role": user.role}


from .auth import _store_refresh, _uyelikler  # noqa: E402


# ===================== (P203 §2) COKLU TESIS ================================ #
#
# ===========================================================================
# NEDEN GECIS PAROLA SORMAZ — ve bunun KABUL EDILEN bedeli
# ===========================================================================
# Istek acikca "yeniden giris gerektirmeden" diyor. Kural su: bu sistemde
# KIMLIK E-POSTADIR. P197'den beri e-posta zorunlu ve tesis icinde
# benzersiz; davet, parola sifirlama, dogrulama — hepsi ondan gecer. Bir
# yonetici X e-postasiyla kullanici actiginda, "X'i kontrol eden kisi bu
# tesise girebilir" demis olur. Ayni e-postayi tasiyan iki satir, KURULUS
# GEREGI ayni kisidir.
#
# BEDELI ACIKCA YAZIYORUM: A tesisindeki oturumu ele geciren biri, ayni
# e-posta B tesisinde de varsa B'ye de gecebilir — B'nin parolasini
# bilmeden. Bunu kabul etmemizin sebebi, alternatifin DAHA KOTU olmasi:
# kisiye N tesis icin N parola ezberletmek, gercekte herkesin ayni
# parolayi kullanmasiyla sonuclanir — yani ayni riski, ustune parola
# yorgunlugu ekleyerek elde ederiz.
#
# SINIRLAR YINE DE UYGULANIR: hedef satir AKTIF olmali ve denetci gorev
# penceresi kurali burada da gecerlidir (girisle AYNI kapi). Gecis
# DENETIME yazilir.
#
# IZOLASYON: yeni jeton hedef tenant icin uretilir. Eski jeton kaynak
# tenant icin GECERLI KALIR (kullanici geri donebilmeli) ve hicbir jeton
# iki tenant'i birden tasimaz — RLS jetondaki tek `tenant_id`yi kullanir.
@router.get("/me/tesislerim", response_model=TesislerimYanit)
async def tesislerim(
    user: AppUser = Depends(get_current_user),
) -> TesislerimYanit:
    """Oturumdaki kisinin TUM tesis uyelikleri — uygulama ici secici.

    PAROLA ISTEMEZ: kimlik zaten kanitlanmis. Liste, kisinin KENDI
    e-postasina ait satirlardir; baska kimsenin verisi degil.
    """
    async with SessionLocal() as session:
        satirlar = await _uyelikler(session, user.email)
    return TesislerimYanit(
        tesisler=[
            TesisUyeligi(
                tenant_id=r["tenant_id"], slug=r["slug"], ad=r["tenant_ad"],
                rol=r["rol"],
            )
            for r in satirlar
            if r["is_active"]
        ]
    )


@router.post("/me/tesis-degistir", response_model=TokenPair)
async def tesis_degistir(
    body: TesisDegistirIstek,
    redis: aioredis.Redis = Depends(get_redis),
    user: AppUser = Depends(get_current_user),
) -> TokenPair:
    """Hedef tesis icin YENI jeton — yeniden giris YOK.

    Hedef, kisinin KENDI e-postasinin uyelikleri arasinda OLMALI.
    Aksi hâlde uc, "istedigim tenant'in jetonunu al" ucuna donusurdu —
    tesis izolasyonunun tam kalbi.
    """
    async with SessionLocal() as session:
        satirlar = await _uyelikler(session, user.email)
    hedef = next(
        (r for r in satirlar if r["tenant_id"] == body.tenant_id and r["is_active"]),
        None,
    )
    if hedef is None:
        # AYIRT ETTIRMEZ: "boyle bir tesis yok" ile "uye degilsin" ayni
        # yanit. Aksi hâlde uc, tenant kimligi sorgulama araci olurdu.
        raise APIError(403, "forbidden", "tesis_uyeligi_yok")

    async with SessionLocal() as session:
        async with session.begin():
            await set_tenant(session, hedef["tenant_id"])
            hedef_user = (
                await session.execute(
                    select(AppUser).where(AppUser.id == hedef["user_id"])
                )
            ).scalar_one_or_none()
            if hedef_user is None or not hedef_user.is_active:
                raise APIError(403, "forbidden", "tesis_uyeligi_yok")
            # (P128) Gorev penceresi disindaki denetci GIRISTE jeton
            # ALMIYOR; gecis o kapiyi ATLAYAN bir arka kapi olmamali.
            if gorev_penceresi_disinda(hedef_user):
                raise APIError(403, "forbidden", "gorev_suresi_disinda")
            await record_audit(
                session,
                action=Action.TESIS_DEGISTIR,
                tenant_id=hedef["tenant_id"],
                actor_user_id=hedef_user.id,
                actor_rol=hedef_user.role,
                resource_type="tenant",
                resource_id=hedef["tenant_id"],
                meta={"kaynak_tenant": str(user.tenant_id)},
            )

    access = create_access_token(
        user_id=hedef_user.id, tenant_id=hedef["tenant_id"], role=hedef_user.role
    )
    refresh, jti, fam = create_refresh_token(
        user_id=hedef_user.id, tenant_id=hedef["tenant_id"]
    )
    await _store_refresh(redis, jti, fam)
    return TokenPair(
        access_token=access,
        refresh_token=refresh,
        token_type="Bearer",
        expires_in=access_token_ttl_seconds(),
    )
