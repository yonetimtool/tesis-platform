"""(P155r2 / §3) YONETICI SELF-SIGNUP — tesis UYGULAMADAN acilir.

===========================================================================
NE DEGISTI
===========================================================================
Once: tesisi ADMIN acardi (`POST /tenants`), icine bir yonetici ON
TANIMLAR, ona tek kullanimlik bir kod verirdi; yonetici ilk giriste
tesisi adlandirirdi. Yani bir yoneticinin platforma girmesi icin bizim
elle bir sey yapmamiz gerekiyordu.

Simdi: yonetici "Tesis adini giriniz" der, ILERI'ye basar, tesis O ANDA
olusur ve oturumu ACILIR. Admin adimi YOKTUR.

`POST /tenants` KALDIRILMADI ve bu bilincli: platform sahibinin destek
islerinde (bir tesisi elle acmak, demo/tohum verisi kurmak) hâlâ tek
yoldur ve KILITLI KURAL 2 geregi demo hesaplarinin ayakta kalmasi ona
bagli. Kaldirilan sey onun BIRINCIL olmasidir — yonetici artik ondan
gecmiyor.

===========================================================================
TESIS KODU ISTEMCIDEN ALINMAZ, TETIKLEYICI URETIR
===========================================================================
Kod = adin ilk 4 harfi + '-' + YYAAGG (goc 0037, yerelden bagimsiz hâle
getirilmesi goc 0041). Kural VERITABANINDA bir tetikleyicide duruyor;
buradan uretmek onu ikinci bir yere kopyalamak, cakisma cozumunu
(rastgele iki haneli ek) da istemciye yikmak olurdu.

Turkce harf donusumu, 4 harften kisa adlar, rakamla baslayan adlar ve
ayni gun ayni ad cakismasi O TETIKLEYICIDE cozulmus durumda; bu uc
yalnizca adi verir.

===========================================================================
TESIS + YONETICI + (VARSA) SOSYAL KIMLIK — TEK TRANSACTION
===========================================================================
Sartname soruyor: "Kayit yarida kesilirse ne olur (tesis olustu ama
yonetici tamamlamadi)?"

YANIT: BOYLE BIR ARA DURUM YOK. Ucu de ayni transaction'da yazilir;
biri patlarsa hicbiri kalmaz. Kullanici yanit almadan cikarsa geriye
tesis DE kalmaz. Yanit aldiysa hesabi calisiyordur ve normal girisle
devam eder — "yarim kayit" diye bir durum uretmedik.

Bu, sosyal yolda ozellikle onemli: once tesisi acip sonra kimligi
baglamak, kimlik baglama patladiginda (orn. o Google hesabi baskasina
bagli) SAHIPSIZ bir tesis birakirdi.

===========================================================================
"ZATEN BIR SITEM VAR" NEDEN BURADA DEGIL
===========================================================================
Sartname §3: "Bu alanin ALTINDA 'Zaten bir sitem var' bagi → tesis kodu
girme ekrani. Ayni tesise ikinci, ucuncu yonetici boyle katilir."

O yol BU MODULDE DEGIL, `auth.rol_kayit_*` icinde — cunku KISITLAR
maddesi onu belirliyor: "Kod bilen biri kayit olamamali, yalniz onceden
eklenmis telefonla eslesen kaydolur." Yani ikinci yonetici de once
mevcut yonetici tarafindan EKLENMIS olmali; katilma, `rol='yonetici'`
ile yapilan sirdan bir rol eslesmesidir.

Aksi tasarim — "tesis kodunu bilen yonetici olur" — tesis kodu kamuya
acik ve tahmin edilebilir oldugundan (goc 0037 guvenlik notu) tesisin
TAMAMEN devralinmasi demekti. Sartnamenin iki maddesi arasindaki bu
gerilim KISITLAR lehine cozuldu.
"""
from __future__ import annotations

import json
import logging
import secrets
import uuid
from datetime import datetime, timedelta, timezone

import redis.asyncio as aioredis
from fastapi import APIRouter, Depends, Header
from sqlalchemy import func, or_, select, text
from sqlalchemy.exc import IntegrityError

from ..audit import Action, record_audit
from ..config import settings
from ..db import SessionLocal, set_tenant
from ..deps import get_redis
from ..errors import APIError
from ..gonderim import saglayici as kanal_saglayicisi, tenant_ayari
from ..hiz_siniri import kod_istegi_say
from ..models import AppUser, KayitOnayKuyrugu, OauthKimlik, Tenant, TesisUyelik
from ..schemas import (
    RolEpostaBaslaRequest,
    RolEpostaBaslaResponse,
    RolEpostaDogrulaRequest,
    RolEpostaDogrulaResponse,
    TesisOlusturRequest,
    TesisOlusturResponse,
    YoneticiBasvuruRequest,
    YoneticiBasvuruResponse,
    YoneticiDogrulaRequest,
    YoneticiDogrulaResponse,
    YoneticiTesisRequest,
)
from ..security import (
    create_kurulum_token,
    create_setup_token,
    decode_token,
    hash_password,
    normalize_phone,
    slugify_tenant,
    verify_password,
)
from ..telefon_kodu import (
    KOD_OMRU_DK,
    MAX_DENEME,
    eposta_kodunu_dogrula,
)
from .auth import _issue_token_pair
from .oauth import _baglama_coz

log = logging.getLogger(__name__)

router = APIRouter(prefix="/auth/kayit", tags=["auth"])

#: Numara zaten platformda. SIZDIRIYOR MU? Evet, bir bit: "bu numara
#: kayitli". Yine de AYIRT EDICI bir hata seciliyor ve gerekcesi su:
#: kullanicinin numarasi KENDI numarasidir, ona "zaten kayitlisin, giris
#: yap" demek onu dogru kapiya yollar. Belirsiz bir hata verseydik,
#: hesabi olan yonetici tesisini ikinci kez acmaya calisip her seferinde
#: ayni duvara carpar ve destege yazardi. Numara taramasini engelleyen
#: sey burada hata metni degil, ONUNDEKI HIZ SINIRIDIR.
_TELEFON_KAYITLI = APIError(409, "conflict", "telefon_zaten_kayitli")

#: Sosyal kimlik baska bir hesaba bagli — o hesapla giris yapilmali.
_KIMLIK_BASKASINDA = APIError(409, "conflict", "oauth_baska_hesaba_bagli")

#: Hiz siniri kapsami. `kayit`/`giris`ten AYRI: tesis acmak farkli bir
#: eylemdir ve birinin sayaci otekini tuketmemeli.
_HIZ_KAPSAMI = "tesis_olustur"


@router.post("/tesis-olustur", response_model=TesisOlusturResponse, status_code=201)
async def tesis_olustur(
    body: TesisOlusturRequest,
    redis: aioredis.Redis = Depends(get_redis),
) -> TesisOlusturResponse:
    """Tesisi acar, ilk yoneticiyi yazar ve OTURUM ACAR.

    `kurulum_tamamlandi=true` DONUYOR ve bu bilincli: o bayragin tek isi
    "birincil yonetici tesisi adlandirdi mi" sorusunu yanitlamakti
    (mobil `setup_tenant_screen` onu bekler). Ad ARTIK BU ISTEKTE
    geliyor, yani adim zaten yapilmis durumda. `false` biraksaydik
    kullaniciyi az once yazdigi adi tekrar yazdigi bir ekrana
    dusururduk — sartname §3 ADIM 4 acikca "Ana ekran" diyor.

    Kurulum SIHIRBAZI (blok/daire/sakin/...) bundan AYRIDIR ve
    dokunulmadi; o zaten veriden sayiliyor, bayraktan degil.
    """
    try:
        telefon = normalize_phone(body.telefon)
    except ValueError:
        raise APIError(422, "validation_error", "telefon_gecersiz")

    # HIZ SINIRI DOGRULAMADAN ONCE — depodaki oteki kayit uclariyla ayni
    # sira. Sonra saymak, "bu numara kayitli mi" sorusunu sinirsiz
    # sordurup 409/201 farkindan yanit okumaya izin verirdi.
    await kod_istegi_say(redis, telefon, kapsam=_HIZ_KAPSAMI)

    # Sosyal yolda kimlik ONCE cozulur: gecersiz bir jeton yuzunden tesis
    # acip sonra geri almak yerine, hic acmamak.
    kimlik: dict | None = None
    if body.baglama_jetonu:
        kimlik = _baglama_coz(body.baglama_jetonu)

    async with SessionLocal() as session:
        async with session.begin():
            # --- 1) Numara bos mu? (RLS bootstrap: SECURITY DEFINER) ---
            if (
                await session.execute(
                    text("SELECT public.tenant_id_by_phone(:p)"), {"p": telefon}
                )
            ).scalar_one_or_none() is not None:
                raise _TELEFON_KAYITLI

            # --- 2) Sosyal kimlik baskasinda mi? ---
            if kimlik is not None:
                if (
                    await session.execute(
                        text("SELECT public.tenant_id_by_oauth(:s, :sub)"),
                        {"s": kimlik["saglayici"], "sub": kimlik["subject"]},
                    )
                ).scalar_one_or_none() is not None:
                    raise _KIMLIK_BASKASINDA

            # --- 3) Tesis + birincil yonetici ---
            # PAROLA DURUMU YONTEME GORE: elle kayitta kullanici parolayi
            # ZATEN girdi (`password_set=true`, gecici kod YOK). Sosyal
            # yolda parola HIC YOK ve olmamali — kimlik saglayicidadir.
            yonetici = {
                "ad": body.ad.strip(),
                "telefon": telefon,
                "password_hash": hash_password(body.parola) if body.parola else None,
                "temp_code_hash": None,
                "password_set": bool(body.parola),
            }
            try:
                satirlar = (
                    await session.execute(
                        text(
                            "SELECT tenant_id, user_id FROM "
                            "public.create_tenant_with_yoneticis("
                            ":ad, :slug, :tz, :kur, :yem, CAST(:yon AS jsonb))"
                        ),
                        {
                            "ad": body.tesis_ad.strip(),
                            "slug": slugify_tenant(body.tesis_ad),
                            "tz": "Europe/Istanbul",
                            "kur": True,
                            "yem": None,
                            "yon": json.dumps([yonetici]),
                        },
                    )
                ).all()
            except IntegrityError:
                # Yaris: ayni numarayla es zamanli iki istek. Adim 1'in
                # kontrolu ile INSERT arasindaki pencereyi veritabaninin
                # benzersizlik kisiti kapatir; kullaniciya AYNI hatayi
                # veriyoruz ki iki yol ayirt edilemesin.
                raise _TELEFON_KAYITLI

            tenant_id: uuid.UUID = satirlar[0].tenant_id
            user_id: uuid.UUID = satirlar[0].user_id

            # --- 4) Ayni transaction'da: baglam + sosyal kimlik + denetim ---
            await set_tenant(session, tenant_id)

            if kimlik is not None:
                session.add(
                    OauthKimlik(
                        tenant_id=tenant_id,
                        user_id=user_id,
                        saglayici=kimlik["saglayici"],
                        subject=kimlik["subject"],
                        eposta=kimlik.get("eposta"),
                    )
                )

            kayit_kodu = (
                await session.execute(
                    text("SELECT kayit_kodu FROM public.tenant WHERE id = :t"),
                    {"t": tenant_id},
                )
            ).scalar_one()

            await record_audit(
                session,
                action=Action.LOGIN_OK,
                tenant_id=tenant_id,
                actor_user_id=user_id,
                actor_rol="yonetici",
                resource_type="app_user",
                resource_id=user_id,
                meta={
                    "method": (
                        f"self_signup:oauth:{kimlik['saglayici']}"
                        if kimlik
                        else "self_signup:parola"
                    )
                },
            )

            # ORM nesnesi olarak yukleniyor: `_issue_token_pair` bir
            # `AppUser` bekliyor ve elde kurulmus bir nesne vermek, alan
            # eklendiginde sessizce eksik kalirdi. Transaction disinda
            # kullanilabilir cunku `SessionLocal` `expire_on_commit=False`.
            user = (
                await session.execute(select(AppUser).where(AppUser.id == user_id))
            ).scalar_one()

    # Jeton uretimi transaction DISINDA — depodaki oteki giris yollariyla
    # ayni desen (`_issue_token_pair` Redis'e yazar).
    cift = await _issue_token_pair(redis, user)
    return TesisOlusturResponse(
        tesis_ad=body.tesis_ad.strip(), tesis_kodu=kayit_kodu, jetonlar=cift
    )


# ========================================================================== #
# (P177 §4-§6) YENI KAYIT AKISI — BAYRAK ARKASINDA
# ========================================================================== #
#
# ===========================================================================
# BAYRAK KAPALIYKEN HICBIR SEY DEGISMEZ
# ===========================================================================
# `YENI_KAYIT_AKISI=false` (varsayilan) iken bu bolumdeki DORT uc da
# `503 kayit_akisi_kapali` doner. Yukaridaki `tesis_olustur`,
# `auth.rol_kayit_basla/dogrula`, `auth.login`, `auth.login_phone` ve
# sosyal giris BU BAYRAGI OKUMAZ — yani mevcut kimlik sistemi birebir
# bugunku gibi calisir. Play kapali testi o sistemle yapilacagi icin
# varsayilan kapalidir.
#
# ===========================================================================
# YONETICI YOLU NEDEN UC ADIM
# ===========================================================================
#   1) basvuru  — bilgiler + onaylar; e-postaya kod
#   2) dogrula  — kod; kurulum jetonu (OTURUM DEGIL)
#   3) tesis    — site adi; MEVCUT mekanizma ile tesis + oturum
#
# Tesis 3. adimda aciliyor cunku dogrulanmamis bir adresle acilan tesis,
# sahibine ulasilamayan bir tesis olurdu. `tesis_olustur` (yukarida)
# TELEFON kimligiyle ayni isi tek adimda yapar ve DURUYOR — iki yol
# birbirini bozmadan yan yana yasar.
#
# ===========================================================================
# ROL YOLU: UC SART BIRLIKTE (§6)
# ===========================================================================
#   a) Tesis ID gecerli,  b) e-posta yoneticinin listesinde,  c) OTP dogru.
# Yalniz Tesis ID ile dogrulama yapilsaydi, kodu ogrenen herkes o siteye
# sakin olarak girerdi. Tesis ID KOLAYLIK saglar; YETKIYI listede olmak
# verir.
#
# Sartlardan biri tutmazsa hesap ACILMAZ ve deneme `kayit_onay_kuyrugu`na
# duser — sessizce kaybolmaz.

#: Bayrak kapali. `503` (404 DEGIL): uc VAR, gecici olarak KAPALI. 404
#: "boyle bir sey yok" der ve istemciyi yanlis teshise gonderirdi.
_AKIS_KAPALI = APIError(503, "unavailable", "kayit_akisi_kapali")

#: Adimlari ayirt ETTIRMEYEN tek hata — `auth._KAYIT_GECERSIZ` ile ayni
#: ilke. "kod yanlis" ile "boyle bir basvuru yok" arasindaki fark, hangi
#: adreslerin sistemde oldugunu sizdirirdi.
_BASVURU_GECERSIZ = APIError(422, "invalid_registration", "kayit_bilgileri_gecersiz")

_KURULUM_GECERSIZ = APIError(401, "invalid_token", "kurulum_jetonu_gecersiz")

#: §6'da kabul edilen roller. `yonetici` ve `admin` BILEREK YOK: yonetici
#: kendi yolundan (basvuru) gelir, ek yoneticiyi ise mevcut yonetici
#: ekler. Bu ucu, yoneticinin ONCEDEN EKLEDIGI kisilerdir.
_ROLLER = ("resident", "security", "gorevli")


def _kapi() -> None:
    """Bayrak kapaliysa dur. HER YENI UCUN ILK SATIRI."""
    if not settings.yeni_kayit_akisi:
        raise _AKIS_KAPALI


def _kod_uret() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def _eposta_gonder(ayar, hedef: str, konu: str, govde: str) -> None:
    """Gonderim hatasi KAYDI KIRMAZ — telefon_kodu ile ayni ilke.

    Kod/basvuru zaten yazildi; kullanici "tekrar gonder" diyebilir.
    Saglayici yapilandirilmamissa `yapilandirilmadi` doner ve SESSIZCE
    "gonderildi" DEMEZ.
    """
    try:
        kanal_saglayicisi("eposta", ayar).gonder(hedef, konu, govde)
    except Exception:  # noqa: BLE001 — gonderim, kaydi geri sardirmaz
        log.warning("kayit e-postasi gonderilemedi", exc_info=True)


# -------------------------------------------------------------------------- #
# 1) YONETICI BASVURUSU
# -------------------------------------------------------------------------- #
@router.post(
    "/yonetici-basvuru", response_model=YoneticiBasvuruResponse, status_code=201
)
async def yonetici_basvuru(
    body: YoneticiBasvuruRequest,
    redis: aioredis.Redis = Depends(get_redis),
    x_istemci_ip: str | None = Header(default=None, alias="X-Istemci-Ip"),
    x_istemci_ajan: str | None = Header(default=None, alias="X-Istemci-Ajan"),
) -> YoneticiBasvuruResponse:
    """Basvuruyu yazar ve e-postaya 6 haneli kod gonderir.

    IP VE TARAYICI BASLIKTAN: onay kaydinin ispat degeri icin gerekli
    (KVKK'da ispat yukumlulugu veri sorumlusundadir) ve tarayici kendi
    IP'sini BILEMEZ. Basliklari BFF ekler; istemcinin uydurabilecegi bir
    deger oldugu icin YETKI KARARINDA KULLANILMAZ, yalniz kaydedilir.

    TICARI ILETI ONAYI SAKLANIR AMA HICBIR ILETI GONDERILMEZ
    (`settings.ticari_ileti_aktif` varsayilan `False`): sirket ve IYS
    kaydi yok.
    """
    _kapi()

    eposta = str(body.eposta).lower()
    # HIZ SINIRI DOGRULAMADAN ONCE — depodaki oteki kayit uclariyla ayni
    # sira. Sonra saymak, "bu adres kayitli mi" sorusunu sinirsiz
    # sordurmaya izin verirdi.
    await kod_istegi_say(redis, eposta, kapsam="yonetici_basvuru")

    try:
        telefon = normalize_phone(body.telefon)
    except ValueError:
        raise APIError(422, "validation_error", "telefon_gecersiz")

    kod = _kod_uret()
    async with SessionLocal() as session:
        async with session.begin():
            await session.execute(
                text(
                    "SELECT public.yonetici_basvuru_ekle("
                    ":ad, :soyad, :eposta, :telefon, :ph, :os, :ok, :ot, "
                    ":ip, :ajan, :omur, :kh, :kodomur)"
                ),
                {
                    "ad": body.ad.strip(),
                    "soyad": body.soyad.strip(),
                    "eposta": eposta,
                    "telefon": telefon,
                    "ph": hash_password(body.parola),
                    "os": body.onay_sozlesme,
                    "ok": body.onay_kvkk,
                    "ot": body.onay_ticari,
                    # Basliktan gelen degerler SINIRLANIR: uzun bir baslik
                    # tabloyu sismek disinda bir sey yapmaz ama yine de
                    # sinirsiz metin yazmak dogru degil.
                    "ip": (x_istemci_ip or "")[:64] or None,
                    "ajan": (x_istemci_ajan or "")[:300] or None,
                    "omur": settings.yonetici_basvuru_omru_saat,
                    "kh": hash_password(kod),
                    "kodomur": KOD_OMRU_DK,
                },
            )

    # GONDERIM TRANSACTION DISINDA: SMTP yavas olabilir ve bir veritabani
    # transaction'ini ag beklemesiyle acik tutmak, havuzu tuketir.
    # TESIS AYARI YOK (henuz tesis yok) -> ENV saglayicisi.
    _eposta_gonder(
        None,
        eposta,
        "Yönetiyor doğrulama kodu",
        f"Yönetiyor doğrulama kodunuz: {kod} ({KOD_OMRU_DK} dk)",
    )
    return YoneticiBasvuruResponse()


# -------------------------------------------------------------------------- #
# 2) E-POSTA DOGRULAMA
# -------------------------------------------------------------------------- #
@router.post("/yonetici-dogrula", response_model=YoneticiDogrulaResponse)
async def yonetici_dogrula(body: YoneticiDogrulaRequest) -> YoneticiDogrulaResponse:
    """Kod dogruysa KURULUM JETONU doner (oturum DEGIL).

    SURE, DENEME SINIRI VE HASH `telefon_kodu`DAN: `KOD_OMRU_DK` ve
    `MAX_DENEME` oradan okunuyor, kod bcrypt'le karsilastiriliyor.
    Ikinci bir kural kumesi yazilmadi — bir gun birinde deneme sayaci
    artirilip otekinde unutulsaydi o kanal kaba kuvvete acik kalirdi.
    """
    _kapi()
    eposta = str(body.eposta).lower()

    async with SessionLocal() as session:
        satir = (
            await session.execute(
                text("SELECT * FROM public.yonetici_basvuru_bul(:e)"),
                {"e": eposta},
            )
        ).first()

    if satir is None or satir.durum != "beklemede" or not satir.kod_hash:
        raise _BASVURU_GECERSIZ
    if satir.kod_son_gecerlilik is None or satir.kod_son_gecerlilik < datetime.now(
        timezone.utc
    ):
        raise _BASVURU_GECERSIZ
    if satir.kod_deneme >= MAX_DENEME:
        raise _BASVURU_GECERSIZ

    if not verify_password(body.kod, satir.kod_hash):
        # SAYAC AYRI OTURUMDA: bu istek hata ile bitecek; ayni oturumda
        # tutmak sayaci geri sardirirdi (P148'de olculdu).
        async with SessionLocal() as s2:
            async with s2.begin():
                await s2.execute(
                    text("SELECT public.yonetici_basvuru_deneme_artir(:i)"),
                    {"i": str(satir.id)},
                )
        raise _BASVURU_GECERSIZ

    async with SessionLocal() as session:
        async with session.begin():
            onay = (
                await session.execute(
                    text("SELECT * FROM public.yonetici_basvuru_dogrula(:i)"),
                    {"i": str(satir.id)},
                )
            ).first()
    if onay is None:
        # Yaris: iki istek ayni kodla geldi, biri tuketti.
        raise _BASVURU_GECERSIZ

    return YoneticiDogrulaResponse(kurulum_jetonu=create_kurulum_token(basvuru_id=satir.id))


# -------------------------------------------------------------------------- #
# 3) TESIS OLUSTURMA ("Site adı" adimi)
# -------------------------------------------------------------------------- #
@router.post("/yonetici-tesis", response_model=TesisOlusturResponse, status_code=201)
async def yonetici_tesis(
    body: YoneticiTesisRequest,
    redis: aioredis.Redis = Depends(get_redis),
) -> TesisOlusturResponse:
    """MEVCUT tesis mekanizmasiyla tesisi acar ve oturumu ACAR.

    `create_tenant_with_yoneticis` AYNEN kullaniliyor — sartname §5
    "Mevcut mekanizmayi degistirme, oldugu gibi kullan" diyor. Tesis
    kodunu (kayit_kodu) yine VERITABANINDAKI TETIKLEYICI uretir; buradan
    uretmek, kurali ikinci bir yere kopyalamak olurdu.

    TESIS ID HEM EKRANDA HEM E-POSTADA: yanitta doner (§5) ve ayrica
    e-postayla gonderilir. Yalniz ekranda gostermek, sekmeyi kapatan
    yoneticiyi destege yollardi.
    """
    _kapi()
    try:
        claims = decode_token(body.kurulum_jetonu, expected_type="tesis_kurulum")
    except Exception:  # noqa: BLE001 — jwt hatalari tek bir yanit uretir
        raise _KURULUM_GECERSIZ

    basvuru_id = claims.get("sub")
    if not basvuru_id:
        raise _KURULUM_GECERSIZ

    async with SessionLocal() as session:
        async with session.begin():
            # Basvuruyu YENIDEN OKU: jeton gecerli olsa bile basvuru bu
            # arada tamamlanmis olabilir (cift tiklama, iki sekme).
            # FONKSIYONDAN OKUNUYOR, DUZ `SELECT` DEGIL: tablo RLS
            # altinda ve POLITIKASI YOK (tenant'siz oldugu icin tenant
            # politikasi yazilamaz). Duz sorgu SESSIZCE SIFIR SATIR
            # doner ve "jeton gecersiz" gibi gorunur — olculdu.
            satir = (
                await session.execute(
                    text("SELECT * FROM public.yonetici_basvuru_getir(:i)"),
                    {"i": basvuru_id},
                )
            ).first()
            if satir is None or satir.durum != "dogrulandi":
                raise _KURULUM_GECERSIZ

            # Numara bu arada baskasi tarafindan alinmis olabilir.
            if (
                await session.execute(
                    text("SELECT public.tenant_id_by_phone(:p)"),
                    {"p": satir.telefon},
                )
            ).scalar_one_or_none() is not None:
                raise _TELEFON_KAYITLI

            yonetici = {
                "ad": f"{satir.ad} {satir.soyad}".strip(),
                "telefon": satir.telefon,
                "eposta": satir.eposta,
                "password_hash": satir.parola_hash,
                "temp_code_hash": None,
                "password_set": bool(satir.parola_hash),
            }
            try:
                satirlar = (
                    await session.execute(
                        text(
                            "SELECT tenant_id, user_id FROM "
                            "public.create_tenant_with_yoneticis("
                            ":ad, :slug, :tz, :kur, :yem, CAST(:yon AS jsonb))"
                        ),
                        {
                            "ad": body.tesis_ad.strip(),
                            "slug": slugify_tenant(body.tesis_ad),
                            "tz": "Europe/Istanbul",
                            "kur": True,
                            "yem": None,
                            "yon": json.dumps([yonetici]),
                        },
                    )
                ).all()
            except IntegrityError:
                raise _TELEFON_KAYITLI

            tenant_id: uuid.UUID = satirlar[0].tenant_id
            user_id: uuid.UUID = satirlar[0].user_id
            await set_tenant(session, tenant_id)

            kayit_kodu = (
                await session.execute(
                    text("SELECT kayit_kodu FROM public.tenant WHERE id = :t"),
                    {"t": tenant_id},
                )
            ).scalar_one()

            user = (
                await session.execute(select(AppUser).where(AppUser.id == user_id))
            ).scalar_one()

            # E-POSTA VE TICARI ILETI IZNI: `create_tenant_with_yoneticis`
            # yalniz ad/telefon/parola aliyor (goc 0037). E-postayi ve
            # rizayi burada yaziyoruz — fonksiyonun imzasini degistirmek,
            # onu cagiran oteki yollari (admin `POST /tenants`, tohum
            # verisi) da degistirmek olurdu.
            user.email = satir.eposta
            user.pazarlama_eposta = bool(satir.onay_ticari)
            user.pazarlama_guncelleme_at = func.now()

            # (§6) COK TESISLI UYELIK KAYDI — bugun okunmuyor, dogru
            # veriyi bugunden tutuyor. Bkz. models.TesisUyelik.
            session.add(
                TesisUyelik(
                    tenant_id=tenant_id,
                    user_id=user_id,
                    eposta=satir.eposta,
                    rol=user.role,
                    birincil=True,
                )
            )

            await session.execute(
                text("SELECT public.yonetici_basvuru_tamamla(:i)"),
                {"i": basvuru_id},
            )

            await record_audit(
                session,
                action=Action.LOGIN_OK,
                tenant_id=tenant_id,
                actor_user_id=user_id,
                actor_rol="yonetici",
                resource_type="app_user",
                resource_id=user_id,
                meta={"method": "yeni_kayit_akisi:eposta"},
            )

    _eposta_gonder(
        None,
        satir.eposta,
        f"{body.tesis_ad.strip()} — Tesis ID’niz",
        _yonetici_hosgeldin_metni(body.tesis_ad.strip(), kayit_kodu),
    )

    cift = await _issue_token_pair(redis, user)
    return TesisOlusturResponse(
        tesis_ad=body.tesis_ad.strip(), tesis_kodu=kayit_kodu, jetonlar=cift
    )


def _yonetici_hosgeldin_metni(tesis_ad: str, tesis_kodu: str) -> str:
    """(§4) Yoneticiye giden e-posta — SADE ve ISLEVSEL.

    Sartname: "Bu turda e-posta SADE ve islevsel olsun. Kurumsal HTML
    sablonlari ayri bir turda gelecek, o yuzden sablonu TEK YERDEN
    degistirilebilir tut, tasarima vakit harcama."

    Bu yuzden duz metin ve TEK FONKSIYON. HTML sablonu geldiginde
    degisecek yer burasidir, cagiran yerler degil.

    ICERIK (§4): magaza baglantilari + web giris adresi + Tesis ID.
    Magaza baglantisi YAPILANDIRILMISSA eklenir; bos bir App Store
    id'siyle kirik baglanti gondermek hic gondermemekten kotudur.
    """
    satirlar = [
        f"{tesis_ad} için Yönetiyor hesabınız hazır.",
        "",
        f"Tesis ID: {tesis_kodu}",
        "Bu kodu sitenizdeki kişilerle paylaşacaksınız.",
        "",
        f"Web'den giriş: {settings.portal_base_url.rstrip('/')}",
    ]
    if settings.play_store_url:
        satirlar.append(f"Android uygulaması: {settings.play_store_url}")
    if settings.app_store_url:
        satirlar.append(f"iOS uygulaması: {settings.app_store_url}")
    return "\n".join(satirlar)


# -------------------------------------------------------------------------- #
# 4) ROL KAYDI — E-POSTA ILE (§6)
# -------------------------------------------------------------------------- #
#
# ===========================================================================
# UC SART BIRLIKTE — KARAR VERILDI (sartname §6)
# ===========================================================================
#   a) Girilen Tesis ID gecerli olacak,
#   b) Kisinin e-postasi, o tesiste YONETICININ EKLEDIGI LISTEDE bulunacak,
#   c) O e-postaya giden OTP dogrulanacak.
#
# Gerekce sartnamede yazili ve dogru: yalniz Tesis ID ile dogrulama
# yapilsaydi, ID'yi ogrenen herkes o siteye sakin olarak girerdi. Tesis ID
# KOLAYLIK saglar; YETKIYI listede olmak verir.
#
# "LISTEDE OLMAK" NE DEMEK — OLCULEBILIR TANIM: o tenant'ta, verilen
# e-postayla, AKTIF, istenen ROLDE ve PAROLASI HENUZ BELIRLENMEMIS bir
# `app_user` satiri var demektir. Son sart onemli: parolasi olan hesap bu
# yoldan GECMEZ, yoksa uc ikinci bir PAROLA SIFIRLAMA yuzeyi olurdu
# (telefon yolundaki `rol_kayit_basla` ile ayni kural).
#
# ===========================================================================
# SMS YOK
# ===========================================================================
# Bu yol e-posta koduyla calisir. Telefonlu kardesi (`auth.rol_kayit_*`)
# DURUYOR ve degistirilmedi, ama `settings.sms_aktif=False` oldugu icin
# oradaki kod da GONDERILMEZ. Yani bugun kaydolmanin calisan tek yolu
# budur.


@router.post("/rol-eposta-basla", response_model=RolEpostaBaslaResponse)
async def rol_eposta_basla(
    body: RolEpostaBaslaRequest,
    redis: aioredis.Redis = Depends(get_redis),
) -> RolEpostaBaslaResponse:
    """Tesis ID + e-posta + rol -> eslesirse e-postaya kod gonderir.

    ESLESME SONUCU YANITTAN OKUNAMAZ: eslesse de esleşmese de ayni yanit
    doner (`durum='kod_gonderildi'`). Aksi hâlde uc, "bu sitede su adres
    var mi" sorgusuna donusurdu.

    TESIS KODU HATASI SOYLENIR (422): kod zaten kamuya aciktir ve en sik
    yazim hatasi orada olur. Kullaniciyi "kod gonderildi" deyip bos bir
    gelen kutusuna bakmaya birakmak, yardim degil eziyet olurdu.
    """
    _kapi()
    if body.rol not in _ROLLER:
        raise _BASVURU_GECERSIZ

    eposta = str(body.eposta).lower()
    # HIZ SINIRI KIMLIGE BAGLI: `tesis:eposta`. Yalniz e-posta kullanmak,
    # ayni adresi tasiyan iki tesisin sayacini birlestirirdi
    # (`auth.eposta_giris_kodu_iste` ile ayni kural).
    await kod_istegi_say(
        redis, f"{body.tesis_kodu.strip()}:{eposta}", kapsam="rol_kayit_eposta"
    )

    kod = _kod_uret()
    async with SessionLocal() as session:
        async with session.begin():
            tenant_id = (
                await session.execute(
                    text("SELECT public.tenant_id_by_kayit_kodu(:k)"),
                    {"k": body.tesis_kodu.strip()},
                )
            ).scalar_one_or_none()
            if tenant_id is None:
                raise _BASVURU_GECERSIZ

            await set_tenant(session, tenant_id)
            tenant_ad = (
                await session.execute(select(Tenant.ad).where(Tenant.id == tenant_id))
            ).scalar_one()

            user = (
                await session.execute(
                    select(AppUser).where(func.lower(AppUser.email) == eposta)
                )
            ).scalar_one_or_none()

            uygun, sebep = _liste_kontrolu(user, body.rol)

            if uygun:
                # BURADAN SONRASI SESSIZ: yanit degismez, yalniz kod
                # gonderilip gonderilmeyecegi belirlenir.
                await eposta_kodu_uret_ve_gonder_kodla(
                    session, tenant_id=tenant_id, eposta=eposta, kod=kod
                )
            else:
                # (§6) DENEME KAYBOLMAZ: yoneticinin onay kuyruguna duser.
                # Gercek bir sakin, yonetici onu baska bir adresle listeye
                # yazdigi icin de buraya duser — en sik durum budur ve
                # yoneticinin bakabilecegi bir yer olmali.
                await _kuyruga_yaz(
                    session,
                    tenant_id=tenant_id,
                    eposta=eposta,
                    rol=body.rol,
                    ad=body.ad,
                    telefon=body.telefon,
                    sebep=sebep,
                )

    return RolEpostaBaslaResponse(tesis_ad=tenant_ad)


def _liste_kontrolu(user: AppUser | None, rol: str) -> tuple[bool, str]:
    """(b) sarti: kisi YONETICININ EKLEDIGI listede mi?

    Donus: (uygun_mu, kuyruk_sebebi). Sebep yalniz uygun DEGILSE
    anlamlidir ve yoneticinin panelinde gorunur — "bir sey oldu" demek,
    yoneticiyi tahmine birakirdi.
    """
    if user is None or not user.is_active:
        return False, "liste_disi"
    if user.role != rol:
        # Kisi listede AMA baska rolde. Yoneticinin gormesi gereken tam
        # olarak bu: rolu duzeltmesi yeter.
        return False, "rol_uyusmuyor"
    if user.password_set:
        # Hesap ZATEN sahiplenilmis. Kaydolmaya calisan kisi ya hesabini
        # unutmustur (yolu `/auth/giris/eposta-kod-iste`) ya da baskasidir.
        return False, "hesap_kullanimda"
    return True, ""


async def _kuyruga_yaz(
    session,
    *,
    tenant_id: uuid.UUID,
    eposta: str,
    rol: str,
    ad: str | None,
    telefon: str | None,
    sebep: str,
) -> None:
    """Onay kuyruguna yazar; ayni adresten ACIK kayit varsa TAZELER.

    Tazeleme bilincli: ayni kisi bes kez denerse yoneticinin kuyrugunda
    bes satir olusmamali (`uq_kayit_onay_acik` bunu veritabaninda da
    zorluyor).
    """
    mevcut = (
        await session.execute(
            select(KayitOnayKuyrugu).where(
                KayitOnayKuyrugu.eposta == eposta,
                KayitOnayKuyrugu.durum == "bekliyor",
            )
        )
    ).scalar_one_or_none()
    if mevcut is not None:
        mevcut.rol = rol
        mevcut.sebep = sebep
        if ad:
            mevcut.ad = ad
        if telefon:
            mevcut.telefon = telefon
        return
    session.add(
        KayitOnayKuyrugu(
            tenant_id=tenant_id,
            eposta=eposta,
            rol=rol,
            ad=(ad or None),
            telefon=(telefon or None),
            sebep=sebep,
        )
    )


async def eposta_kodu_uret_ve_gonder_kodla(
    session, *, tenant_id: uuid.UUID, eposta: str, kod: str
) -> None:
    """`telefon_kodu.eposta_kodu_uret_ve_gonder`in KOD DISARIDAN verilen esi.

    NEDEN AYRI: o fonksiyon kodu KENDI uretir ve dondurmez — dogru bir
    tasarim (kod cagirana sizmasin). Burada kod, `amac='kayit'` satirini
    yazmadan ONCE uretilmek zorunda cunku gonderim transaction DISINDA
    yapiliyor (SMTP beklemesi veritabani transaction'ini acik tutmasin).

    KURAL KUMESI KOPYALANMADI: sure (`KOD_OMRU_DK`), hash'leme
    (`hash_password`) ve ezme davranisi ayni moduldeki kaynaklardan
    geliyor.
    """
    from ..models import KayitDogrulama

    await session.execute(
        text(
            "DELETE FROM kayit_dogrulama WHERE eposta = :e AND amac = 'kayit' "
            "AND durum = 'telefon_bekliyor'"
        ),
        {"e": eposta},
    )
    session.add(
        KayitDogrulama(
            tenant_id=tenant_id,
            eposta=eposta,
            amac="kayit",
            kod_hash=hash_password(kod),
            son_gecerlilik=datetime.now(timezone.utc)
            + timedelta(minutes=KOD_OMRU_DK),
        )
    )
    ayar = await tenant_ayari(session, tenant_id)
    _eposta_gonder(
        ayar,
        eposta,
        "Yönetiyor doğrulama kodu",
        f"Yönetiyor doğrulama kodunuz: {kod} ({KOD_OMRU_DK} dk)",
    )


@router.post("/rol-eposta-dogrula", response_model=RolEpostaDogrulaResponse)
async def rol_eposta_dogrula(
    body: RolEpostaDogrulaRequest,
) -> RolEpostaDogrulaResponse:
    """(c) sarti + (a),(b) YENIDEN: uc sart da tutarsa parola jetonu.

    SARTLAR IKINCI KEZ KONTROL EDILIYOR ve bu bir tekrar degil bir
    GEREKLILIK: `basla` ile `dogrula` arasinda dakikalar gecer ve o arada
    yonetici kisiyi listeden cikarmis ya da hesap baska bir yoldan
    sahiplenilmis olabilir. Yalniz koda bakmak, gecmisteki bir yetkiyi
    bugun kullanmak olurdu.

    =======================================================================
    ROL BURADA YENIDEN ARANMAZ — VE BU BILINCLI
    =======================================================================
    `basla` adiminda kisinin BEYAN ETTIGI rol, listedeki rolle
    karsilastirilir; uymazsa kuyruga duser. Bu adimda ise beklenen rol
    KULLANICININ KENDI ROLUNDEN alinir, yani rol kontrolu etkisizdir.

    Bilerek: gercek guvenlik degismezi "bu e-posta bu tesisin listesinde
    ve kisi o posta kutusunu kontrol ediyor"dur. Rol, listedeki hesabin
    bir OZELLIGIDIR — kisinin ileri surdugu bir yetki iddiasi degil.

    Tersini yapmak ZARAR VERIRDI: yonetici iki adim arasinda rolu
    DUZELTTIGINDE (en sik senaryo — `basla` zaten "rol_uyusmuyor" ile
    kuyruga dusurmus, yonetici bakmis ve duzeltmis), kisi dogru koda
    sahip oldugu hâlde yeniden kuyruga duserdi.

    TEK YANIT TIPI, IKI SONUC: `hazir` ya da `onay_bekliyor`. Ayri hata
    kodlari dondurmek, hangi sartin tutmadigini disariya sizdirirdi.
    """
    _kapi()
    eposta = str(body.eposta).lower()

    async with SessionLocal() as session:
        async with session.begin():
            tenant_id = (
                await session.execute(
                    text("SELECT public.tenant_id_by_kayit_kodu(:k)"),
                    {"k": body.tesis_kodu.strip()},
                )
            ).scalar_one_or_none()
            if tenant_id is None:
                raise _BASVURU_GECERSIZ

            # (c) KOD — `telefon_kodu` mekanizmasi, ikinci bir kural yok.
            kayit = await eposta_kodunu_dogrula(
                session,
                tenant_id=tenant_id,
                eposta=eposta,
                kod=body.kod,
                amac="kayit",
            )

            # (b) LISTE — YENIDEN.
            user = (
                await session.execute(
                    select(AppUser).where(func.lower(AppUser.email) == eposta)
                )
            ).scalar_one_or_none()
            # BEKLENEN ROL KULLANICIDAN: rol bu adimda bir iddia degil,
            # listedeki hesabin ozelligidir (gerekce docstring'de).
            uygun, sebep = _liste_kontrolu(user, user.role if user else "")
            if not uygun or user is None:
                await _kuyruga_yaz(
                    session,
                    tenant_id=tenant_id,
                    eposta=eposta,
                    rol=(user.role if user else "resident"),
                    ad=None,
                    telefon=None,
                    sebep=sebep or "liste_disi",
                )
                return RolEpostaDogrulaResponse(durum="onay_bekliyor")

            # KOD TUKETILIR ve `set-password` kapisina TASINIR: o uc
            # tek-kullanimliligi `temp_code_hash`ten okur. Ikinci bir
            # tek-kullanim mekanizmasi yazmamak icin ayni kapi kullaniliyor
            # (`auth.rol_kayit_dogrula` ile birebir ayni desen).
            user.temp_code_hash = kayit.kod_hash
            kayit.durum = "onaylandi"
            kayit.karar_at = func.now()

            # (§6) COK TESISLI UYELIK KAYDI — bugun okunmuyor.
            mevcut_uyelik = (
                await session.execute(
                    select(TesisUyelik).where(TesisUyelik.user_id == user.id)
                )
            ).scalar_one_or_none()
            if mevcut_uyelik is None:
                session.add(
                    TesisUyelik(
                        tenant_id=tenant_id,
                        user_id=user.id,
                        eposta=eposta,
                        rol=user.role,
                        birincil=True,
                    )
                )

            await session.flush()
            jeton = create_setup_token(user_id=user.id, tenant_id=user.tenant_id)

    return RolEpostaDogrulaResponse(durum="hazir", setup_token=jeton)
