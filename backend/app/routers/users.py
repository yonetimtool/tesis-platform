"""Kullanici yonetimi — GET/POST/PATCH /users (admin) — /contracts/openapi.yaml.

Mevcut app_user tablosu uzerinde calisir (yeni tablo yok). parola bcrypt ile
hash'lenir; password_hash YANITTA donmez (UserAdminOut'ta yok). tenant token'dan,
RLS izole. email tenant icinde benzersiz -> cakisma 409. Silme yok; pasiflestirme
is_active=false (PATCH).
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Header, Query
from sqlalchemy import delete as sa_delete, func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404, is_unique_violation, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..hata_metinleri import istek_dili
from ..hesap_silme import hesabi_sil_veya_anonimlestir
from ..models import AppUser, Davet, Tenant, Unit, UnitResident, UserDevice
from ..roller import yonetilebilir
from ..schemas import (
    OdemeKoduListe,
    OdemeKoduSatiri,
    AcilabilirRollerOut,
    AvatarUpdate,
    DavetGonderimSonucu,
    ResidentDeleteOut,
    UserAdminListItem,
    UserAdminListResponse,
    UserAdminOut,
    UserContactUpdate,
    UserCreate,
    UserCreatedOut,
    UserRoleLiteral,
    UserUpdate,
)
from ..davet import davet_olustur_ve_gonder
from ..storage import delete_objects, presign_get

router = APIRouter(prefix="/users", tags=["users"])

_ADMIN = require_role("admin")
# yonetici gorev atamak icin kullanici listesini OKUR; CRUD admin-only (auth.md §4).
# (P35) Amir de okur: kendi ekibini yonetebilmesi icin listeyi gormeli.
_READER = require_role("admin", "yonetici", "guvenlik_amiri")
# (P193 §7) Odeme kodlari TESIS YONETIMI isidir; guvenlik amiri disarida
# kalir — kod bir FINANS verisidir ve amirin isi saha ekibidir.
_YONETIM = require_role("admin", "yonetici")
# Kullanici OLUSTURMA: admin (her rol) + yonetici (YALNIZ saha personeli)
# + (P35) guvenlik amiri (YALNIZ guvenlik personeli — kendi ekibi).
_USER_CREATOR = require_role("admin", "yonetici", "guvenlik_amiri")
# (P130 + duzeltme turu) KIM KIMI YONETIR: TEK kaynak app/roller.py.
# OLUSTURMA, DUZENLEME, PASIFLESTIRME ve PAROLA SIFIRLAMA ayni kumeden
# okur — daha once duzenleme burada AYRI bir `if` zinciriyle yazilmisti ve
# tablodan ayrismisti (yonetici sakini acabiliyor ama duzenleyemiyordu).
#
# Kural ihlali mesajlari role OZEL: "yetkiniz yok" demek, yoneticiye NEYI
# yapabildigini hic anlatmazdi.
_ACMA_HATASI = {
    "yonetici": "rol_olusturulamaz_yalniz_saha",
    "guvenlik_amiri": "rol_olusturulamaz_yalniz_guvenlik",
}
_DUZENLEME_HATASI = {
    "yonetici": "yalniz_yonetilen_rol_duzenlenir",
    "guvenlik_amiri": "yalniz_guvenlik_personeli_duzenlenir",
}
_ROL_DEGISTIRME_HATASI = {
    "yonetici": "rol_yonetilen_kumeye_cevrilir",
    "guvenlik_amiri": "rol_yalniz_guvenlik_yapilabilir",
}


def _yonetim_kapisi(user: AppUser, hedef_rol: str) -> None:
    """Cagiran, `hedef_rol` rolundeki bir kaydi yonetebilir mi? Degilse 403.

    TEK KAPI: create/update/reset-password hepsi buradan gecer. Ayri ayri
    yazildiginda biri guncellenip otekiler unutuluyordu.
    """
    if hedef_rol not in yonetilebilir(user.role):
        raise APIError(
            403, "forbidden", _DUZENLEME_HATASI.get(user.role, "yetkiniz_yok")
        )
# Iletisim ayari (telefon + arama rizasi) admin + yonetici yonetir (rol/parola
# gibi hassas alanlara dokunmadan — yetki yukseltme yok).
_CONTACT_MANAGER = require_role("admin", "yonetici")
# telefon global benzersiz; email tenant-ici benzersiz — hangisi cakisti
# ayirt edilmeden tek mesaj.

_CONTACT_CONFLICT = APIError(409, "conflict", "telefon_veya_email_zaten_kayitli")
# (P186 §2.2) Tamamlanmis (sahiplenilmis) hesabin e-postasi = giris kimligi;
# yoneticinin panelden ezmesi hesap-ele-gecirme vektorudur. Kisi kendi
# dogrulanmali `PATCH /me/eposta` akisini kullanir (kod yeniye, bildirim eskiye).
_EPOSTA_TAMAMLANAN = APIError(
    409, "conflict", "eposta_tamamlanan_hesapta_degistirilemez"
)
# (P185/P186) Daire (unit_resident) atamasi YALNIZ bu roller icin anlamli.
# Rol bu kumeden cikarsa ( or. resident -> security) aktif daire baglari
# kaldirilir (bkz. update_user); kume icinde kalirsa (resident <-> yonetici)
# korunur.
DAIRE_ROLLERI: frozenset[str] = frozenset({"resident", "yonetici"})


async def _aktif_daire_baglari(
    db: AsyncSession, user_id: uuid.UUID
) -> list[UnitResident]:
    """Kullanicinin AKTIF (bitmemis) daire baglari — bos olabilir."""
    return list(
        (
            await db.execute(
                select(UnitResident).where(
                    UnitResident.user_id == user_id,
                    UnitResident.bitis.is_(None),
                )
            )
        )
        .scalars()
        .all()
    )
# Saha personeli fotosu YALNIZ yonetici yonetir (spec P3); hedef saha personeli.
_AVATAR_MANAGER = require_role("yonetici")
_AVATAR_HEDEF_ROLLER = {"security", "tesis_gorevlisi"}


def _admin_out(obj: AppUser) -> UserAdminOut:
    """AppUser -> UserAdminOut; avatar_key varsa presigned GET URL doldurur."""
    out = UserAdminOut.model_validate(obj)
    out.avatar_url = presign_get(obj.avatar_key) if obj.avatar_key else None
    out.kayit_tamamlandi = obj.password_set
    return out


def _list_item(obj: AppUser) -> UserAdminListItem:
    out = UserAdminListItem.model_validate(obj)
    out.avatar_url = presign_get(obj.avatar_key) if obj.avatar_key else None
    return out


@router.get("", response_model=UserAdminListResponse)
async def list_users(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    role: UserRoleLiteral | None = Query(None),
    is_active: bool | None = Query(None),
    q: str | None = Query(None),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> UserAdminListResponse:
    where = []
    if role is not None:
        where.append(AppUser.role == role)
    if is_active is not None:
        where.append(AppUser.is_active == is_active)
    if q:
        like = f"%{q}%"
        where.append(or_(AppUser.ad.ilike(like), AppUser.email.ilike(like)))
    total = (await db.execute(select(func.count()).select_from(AppUser).where(*where))).scalar_one()
    rows = (
        await db.execute(select(AppUser).where(*where).order_by(AppUser.ad, AppUser.id).limit(limit).offset(offset))
    ).scalars().all()
    return UserAdminListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_list_item(r) for r in rows],
    )


@router.get("/acilabilir-roller", response_model=AcilabilirRollerOut)
async def acilabilir_roller(
    user: AppUser = Depends(_USER_CREATOR),
) -> AcilabilirRollerOut:
    """(P130) Cagiran kullanicinin ACABILECEGI roller.

    NEDEN BIR UC: panel/`app.*` acilir listesi bugune kadar ALTI rolu de
    gosteriyordu; site yoneticisi "Platform Admin"i secebiliyor ve 403
    aliyordu. Listeyi istemcide sabitlemek ayni gercegin IKINCI kopyasi
    olurdu ve zamanla sunucudan ayrisirdi (ayrisma yonu de kotudur:
    gosterilen ama calismayan secenek).

    ROTA SIRASI: bu tanim `/{user_id}`den ONCE gelmek ZORUNDA — sonra
    gelseydi yol degiskene eslesir ve UUID cozumlemesi 422 dondururdu.

    (Duzeltme turu) AYNI KUME DUZENLEMEYI de yonetir; uc adi olusturma
    baglaminda kaldi (panelin acilir listesi bunu okur) ama kaynak tablo
    `YONETILEBILIR_ROLLER`dir.
    """
    return AcilabilirRollerOut(roller=sorted(yonetilebilir(user.role)))


@router.get("/{user_id}", response_model=UserAdminOut)
async def get_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> UserAdminOut:
    obj = await get_or_404(db, AppUser, user_id)
    out = _admin_out(obj)
    # (P186 §2.1) Duzenleme formu mevcut daire atamasini on-doldurur.
    baglar = await _aktif_daire_baglari(db, obj.id)
    out.daire_id = baglar[0].unit_id if baglar else None
    # (P193 §7 / eksik 5) BILDIRIM TESHISI — YALNIZ DETAYDA.
    #
    # "Sakine bildirim gitmiyor" sikayetinin uc olasi cevabi var: kanal
    # tercihi kapali, e-posta dogrulanmamis, ya da kayitli mobil cihaz
    # yok. Ucu de burada gorunur. LISTEDE DEGIL: bu alanlar teshis
    # icindir ve toplu listede gostermek, ihtiyac olmadan herkesin
    # tercihini dokmek olurdu (veri en az).
    out.bildirim_eposta = obj.bildirim_eposta
    out.bildirim_sms = obj.bildirim_sms
    out.bildirim_mobil = obj.bildirim_mobil
    out.mobil_cihaz_sayisi = (
        await db.execute(
            select(func.count())
            .select_from(UserDevice)
            .where(UserDevice.user_id == obj.id, UserDevice.aktif.is_(True))
        )
    ).scalar_one()
    # (eksik 10) Odeme kodu — VARSA gosterilir, BURADA URETILMEZ.
    # Uretim `POST /users/odeme-kodlari` ile BILINCLI bir eylemdir.
    out.odeme_kodu = obj.odeme_kodu
    return out


# ============== (P193 §7 / eksik 10) ODEME KODLARI — LISTE ================= #
#
# Banka eslestirmesinin KESIN calismasi, sakinin havale aciklamasina kendi
# kodunu yazmasina bagli. Kod sakinin uygulamasinda gorunuyordu ama
# yonetici goremiyordu — yani "aciklamaya kodunuzu yazin" diye duyurmasi
# mumkun degildi; her sakine tek tek sormasi gerekirdi.
@router.post("/odeme-kodlari", response_model=OdemeKoduListe)
async def odeme_kodlari(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> OdemeKoduListe:
    """Sakinlerin odeme kodlarini listeler; EKSIK OLANLARI URETIR.

    NEDEN POST: uc YAZAR. Kodlar tembel uretiliyordu (sakin ilk kez
    odeme ekranini acinca) ve bugune kadar cogu sakinin kodu HIC YOKTU —
    yani salt okuyan bir uc bos bir liste dondururdu. Yonetici "kodlari
    duyuracagim" dedigi anda kodlarin VAR OLMASI gerekir.

    TEMBEL URETIM GEREKCESI KORUNDU: kod, hicbir zaman havale
    yapmayacak yuz binlerce kayit icin PESIN uretilmiyor; yalnizca
    yonetici bu ekrani acinca ve YALNIZ KENDI TESISININ sakinleri icin
    uretilir.
    """
    from .. import odeme_kodu as kod_modulu

    sakinler = (
        (await db.execute(
            select(AppUser)
            .where(AppUser.role == "resident", AppUser.is_active.is_(True))
            .order_by(AppUser.ad)
        )).scalars().all()
    )
    uretilen = 0
    for k in sakinler:
        if k.odeme_kodu:
            continue
        for _ in range(5):
            k.odeme_kodu = kod_modulu.uret()
            try:
                async with db.begin_nested():
                    await db.flush()
                uretilen += 1
                break
            except IntegrityError:
                # Cakisma pratikte imkansiz ama SIFIR degil; benzersizlik
                # kisitina guvenip yeniden denenir (sakin tarafindaki
                # `_kod_ver` ile AYNI desen).
                k.odeme_kodu = None

    # Daire numarasi da doner: duyuru "A-12 -> ABC123" seklinde yazilir;
    # yalniz ad ile ayni isimli iki sakin ayirt edilemezdi.
    daireler = dict(
        (
            await db.execute(
                select(UnitResident.user_id, Unit.no)
                .join(Unit, Unit.id == UnitResident.unit_id)
                .where(UnitResident.bitis.is_(None))
            )
        ).all()
    )
    return OdemeKoduListe(
        uretilen=uretilen,
        items=[
            OdemeKoduSatiri(
                user_id=k.id, ad=k.ad, daire_no=daireler.get(k.id),
                odeme_kodu=k.odeme_kodu or "",
            )
            for k in sakinler
            if k.odeme_kodu
        ],
    )


@router.post("", response_model=UserCreatedOut, status_code=201)
async def create_user(
    body: UserCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_USER_CREATOR),
    accept_language: str | None = Header(None),
) -> UserCreatedOut:
    # (P130) TEK kural, TEK tablo: yonetilen kume disi -> 403.
    # Eskiden rol basina IF vardi; yeni bir rol eklenince (P128 `denetci`)
    # hicbir IF'e girmez ve SESSIZCE her seyi acabilir olurdu.
    if body.role not in yonetilebilir(user.role):
        raise APIError(
            403, "forbidden", _ACMA_HATASI.get(user.role, "rol_olusturulamaz")
        )
    # (P186) YONETICI ARTIK PAROLA ATAMAZ, GECICI KOD DA URETILMEZ.
    # Yeni akista kisi kendi kimligini kendisi kurar: davet e-postasindaki
    # Tesis ID ile mobil "Kayit ol" -> SSO ya da e-posta + KENDI parolasi.
    # Yoneticinin parola belirlemesi hem gereksiz hem guvenlik acigiydi (o
    # parolayla hesaba girebilirdi). Hesap DAIMA parolasiz acilir; sahiplenme
    # yalniz DAVET yoluyladir (asagida her zaman gonderilir).
    obj = AppUser(
        tenant_id=user.tenant_id,
        ad=body.ad,
        email=str(body.email) if body.email else None,
        telefon=body.telefon,
        aranabilir=body.aranabilir,
        password_hash=None,
        password_set=False,
        temp_code_hash=None,
        role=body.role,
        is_active=True,
        # (P128) Gorev penceresi (denetci); diger rollerde None gelir.
        gorev_baslangic=body.gorev_baslangic,
        gorev_bitis=body.gorev_bitis,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise _CONTACT_CONFLICT
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.USER_CREATE, resource_type="app_user",
        # meta'da KISISEL VERI DEGERI yok (ad/telefon/e-posta girmez):
        # acilan ROL ve gorev penceresinin VARLIGI. Denetim izinde "kim,
        # hangi rolde, kime hangi yetkiyi verdi" sorusuna bu yeter.
        resource_id=obj.id,
        meta={
            "role": obj.role,
            "gorev_penceresi": bool(obj.gorev_baslangic or obj.gorev_bitis),
        },
    )
    # (P155 §7 · P186) DAVET: hesap DAIMA parolasiz oldugundan HER ZAMAN jetonlu
    # kayit bagi gonderilir (SMS + varsa HTML e-posta). Kisi bu Tesis ID ile
    # mobilden "Kayit ol" der ve kendi kimligini kurar. Gonderim katmani
    # (`gonderim.saglayici`) ayni: SMTP/SMS yoksa saglayici LOG'dur ve
    # `gonderildi=false` doner; yonetici panelden gitmeyeni gorur.
    tenant_adi = (
        await db.execute(select(Tenant.ad).where(Tenant.id == user.tenant_id))
    ).scalar_one_or_none() or ""
    gonderildi = await davet_olustur_ve_gonder(
        db, user=obj, tenant_ad=tenant_adi, gonderen_id=user.id,
        dil=istek_dili(accept_language),
    )
    # (P188) BIRINCIL kanal E-POSTA (SMS kapali). Ozet kanali da e-posta.
    davet_ozeti = DavetGonderimSonucu(gonderildi=gonderildi, kanal="eposta")

    return UserCreatedOut(
        id=obj.id,
        ad=obj.ad,
        email=obj.email,
        telefon=obj.telefon,
        aranabilir=obj.aranabilir,
        role=obj.role,
        is_active=obj.is_active,
        gorev_baslangic=obj.gorev_baslangic,
        gorev_bitis=obj.gorev_bitis,
        created_at=obj.created_at,
        davet=davet_ozeti,
    )


@router.patch("/{user_id}", response_model=UserAdminOut)
async def update_user(
    user_id: uuid.UUID,
    body: UserUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_USER_CREATOR),
    accept_language: str | None = Header(None),
) -> UserAdminOut:
    obj = await get_or_404(db, AppUser, user_id)
    # IKI YONLU KONTROL, ikisi de sart:
    #   1. HEDEF kaydin rolu yonetilen kumede mi (kime dokunabilir),
    #   2. yeni rol de o kumede mi (yetki YUKSELTME yok — kendi rolunu ya da
    #      platform admini uretemez).
    # `admin` icin kume tum roller oldugundan ikisi de serbesttir.
    _yonetim_kapisi(user, obj.role)
    if body.role is not None and body.role not in yonetilebilir(user.role):
        raise APIError(
            403, "forbidden",
            _ROL_DEGISTIRME_HATASI.get(user.role, "rol_degistirilemez"),
        )
    data = body.model_dump(exclude_unset=True)
    if "email" in data and data["email"] is not None:
        data["email"] = str(data["email"])

    # --- Degisiklik oncesi durum (karar icin) ---
    eski_rol = obj.role
    eski_email = obj.email
    # E-postanin GERCEKTEN degistigi (ayni deger gonderilmesi degisim degil).
    eposta_yeni = data.get("email") if "email" in data else None
    eposta_degisti = "email" in data and eposta_yeni != eski_email

    # (P186 §2.2) TAMAMLANMIS HESABIN E-POSTASI DEGISTIRILEMEZ (bosaltma dahil).
    # Sahiplenilmis hesabin e-postasi giris kimligidir; panelden ezmek
    # hesap-ele-gecirme olurdu. Kisi kendi dogrulamali akisini kullanir.
    if eposta_degisti and obj.password_set:
        raise _EPOSTA_TAMAMLANAN

    for key, value in data.items():
        setattr(obj, key, value)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise _CONTACT_CONFLICT
        raise translate_integrity(exc)

    # (P186 §2.3) ROL, DAIRE-TUTAN KUMEDEN CIKTIYSA aktif daire baglarini
    # kaldir: bir guvenlikci/gorevli daireyi isgal edip gercek sakini
    # engellememeli ve daire listesinde yanlis rolde gorunmemeli. Kume
    # icinde kalirsa (resident <-> yonetici) bag KORUNUR.
    kaldirilan_bag = 0
    if "role" in data and eski_rol != obj.role and obj.role not in DAIRE_ROLLERI:
        for bag in await _aktif_daire_baglari(db, obj.id):
            bag.bitis = datetime.now(tz=timezone.utc)
            kaldirilan_bag += 1
        if kaldirilan_bag:
            await db.flush()

    await db.refresh(obj)

    # (P186 §2.2) TAMAMLANMAMIS HESAPTA E-POSTA DEGISIMI -> DAVETI YENIDEN
    # GONDER. `davet_olustur_veya_tazele` yeni jeton uretip eski `jeton_hash`i
    # ezer (ESKI DAVET BAGI OLUR) ve davet YENI adrese gider.
    davet_yeniden = False
    if eposta_degisti and not obj.password_set and obj.email:
        tenant_adi = (
            await db.execute(select(Tenant.ad).where(Tenant.id == user.tenant_id))
        ).scalar_one_or_none() or ""
        await davet_olustur_ve_gonder(
            db, user=obj, tenant_ad=tenant_adi, gonderen_id=user.id,
            dil=istek_dili(accept_language),
        )
        davet_yeniden = True

    await audit_user(
        db, user, Action.USER_UPDATE, resource_type="app_user",
        # HEDEFIN ROLU de yazilir: "kim, HANGI ROLDEKI kaydi, hangi
        # alanlarda degistirdi" sorusu aylar sonra da cevaplanabilsin.
        # (Aktoru ve rolunu `audit_user` zaten yaziyor.) HASSAS DEGER YOK:
        # yalniz alan ADLARI + hangi yan etkiler tetiklendi.
        resource_id=obj.id,
        meta={
            "fields": list(data.keys()),
            "hedef_rol": obj.role,
            **({"davet_yeniden": True} if davet_yeniden else {}),
            **({"daire_baglari_kaldirildi": kaldirilan_bag} if kaldirilan_bag else {}),
        },
    )
    out = _admin_out(obj)
    baglar = await _aktif_daire_baglari(db, obj.id)
    out.daire_id = baglar[0].unit_id if baglar else None
    return out


@router.delete("/{user_id}", response_model=ResidentDeleteOut)
async def delete_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_USER_CREATOR),
) -> ResidentDeleteOut:
    """Kullaniciyi siler — GECMISI YOKSA SERT, VARSA ANONIMLESTIRIR (KVKK).

    (P189) DAVRANIS DEGISTI. Onceden HAM `db.delete` idi: gecmisi olan
    (sikayet/talep/devriye okutma/finans — FK RESTRICT) bir kullanici
    silinmek istendiginde IntegrityError firlatiyor, yonetici "sil" deyince
    veri butunlugunu bozan sifreli bir hata aliyordu. Artik SELF-SERVIS
    hesap-silme ve SAKIN-CIKARMA ile AYNI akilli silme kullanilir
    (`hesabi_sil_veya_anonimlestir`):
      * gecmis YOK  -> satir GERCEKTEN gider (deleted=true),
      * gecmis VAR  -> kimlik alanlari temizlenir, aktif DAIRE baglari
        kapatilir, CIHAZ/push kayitlari silinir, is_active=false; defter ve
        denetim satirlari KALIR (deleted=false). KVKK: kisisel veri gider,
        yasal saklama gereken kayitlar durur.

    KARARIN GEREKCESI (kullanicinin sorusu): sert silme, gecmisi olan
    kullanicida ya veri butunlugunu bozar ya da (FK RESTRICT) hic calismaz;
    akilli silme ikisini de cozer ve platformun geri kalaniyla tutarlidir.

    #4 (davet/daire/oturum):
      * DAVET: bekleyen davet GECERSIZ kilinir (satir silinir) — hesap
        gidince/anonimlesince davet bagi anlamsizdir.
      * DAIRE: aktif `unit_resident` baglari kapatilir (anonimlestirmede);
        sert silmede satir zaten hesapla gider.
      * OTURUM: `is_active=false` sonraki giris/yenilemeyi reddeder;
        cihaz/push kayitlari silinir. Access jetonu durum-suz ve kisa
        omurludur, dogal olarak suresi dolar.

    KENDINI SILEMEZ (409). YETKI: `_yonetim_kapisi` (sunucu tarafi) —
    yonetici yalnizca YONETTIGI rolleri siler; kendi kumesi disini (orn.
    admin) silemez.
    """
    obj = await get_or_404(db, AppUser, user_id)
    # KENDI HESABI KONTROLU KAPIDAN ONCE: sirasi ters olsaydi kendi kaydini
    # silmeye calisan bir yonetici "yetkiniz yok" mesajini alirdi — dogru ama
    # YANILTICI; asil sebep yetki degil, kendini silemiyor olmasi.
    if obj.id == user.id:
        raise APIError(409, "conflict", "kendi_hesabini_silemez")
    _yonetim_kapisi(user, obj.role)
    rol = obj.role  # sert silme sonrasi `obj` erisilemez olabilir; simdi oku.

    # (P189) Bekleyen daveti GECERSIZ kil (FK yok; ayri statement). Hesap
    # silinince/anonimlesince davet bagi tuketilemez olmali.
    await db.execute(sa_delete(Davet).where(Davet.user_id == obj.id))

    # Akilli silme: gecmis yoksa hard delete, varsa anonimlestir.
    silindi = await hesabi_sil_veya_anonimlestir(db, obj, kendi_istegi=False)

    await audit_user(
        db, user, Action.USER_DELETE, resource_type="app_user",
        resource_id=user_id,
        # HASSAS DEGER YOK: yalniz rol + hangi mod (hard/anonymize).
        meta={"rol": rol, "mod": "hard_delete" if silindi else "anonymize"},
    )
    return ResidentDeleteOut(deleted=silindi)


# (P186-ek2) POST /users/{id}/reset-password KALDIRILDI. Yonetici bir
# kullanicinin parolasini SIFIRLAYAMAZ: sifirlanan tek-seferlik kod, yoneticinin
# o hesaba (kullanicidan once) girip parola belirlemesine izin verirdi —
# hesap-ele-gecirme. Kurtarma yollari: (a) tamamlanmamis hesap icin DAVETI
# yeniden gonder (`POST /davet/{id}/yeniden`); (b) kullanici kendisi
# "sifremi unuttum" (e-posta OTP, `POST /auth/sifre-sifirla`) ya da
# `PATCH /me/password` (mevcut parola/kod). Bkz docs/P186-kararlar.md.


@router.patch("/{user_id}/contact", response_model=UserAdminOut)
async def update_user_contact(
    user_id: uuid.UUID,
    body: UserContactUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_CONTACT_MANAGER),
) -> UserAdminOut:
    """Rol-bazli arama iletisim ayari (C1a): telefon + arama rizasi.

    admin + yonetici yonetir — rol/parola/is_active gibi hassas alanlara
    DOKUNMADAN (tam PATCH admin-only kalir; yonetici burada yalniz iletisim
    ayarini gunceller — yetki yukseltme yok). Numara yonetim tarafindan girilir;
    kullanici bu turda kendi yonetmez.
    """
    obj = await get_or_404(db, AppUser, user_id)
    data = body.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(obj, key, value)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        # telefon GLOBAL benzersiz -> baska kullanicinin numarasi verilirse cakisir.
        if is_unique_violation(exc):
            raise _CONTACT_CONFLICT
        raise translate_integrity(exc)
    await db.refresh(obj)
    # C1a iletisim/riza degisikligi (telefon + aranabilir) — KVKK acisindan onemli.
    await audit_user(
        db, user, Action.USER_CONTACT_UPDATE, resource_type="app_user",
        resource_id=obj.id, meta={"fields": list(data.keys())},
    )
    return _admin_out(obj)


@router.patch("/{user_id}/avatar", response_model=UserAdminOut)
async def update_user_avatar(
    user_id: uuid.UUID,
    body: AvatarUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_AVATAR_MANAGER),
) -> UserAdminOut:
    """Saha personeli profil fotografi — YALNIZ yonetici. Hedef ayni tenant'ta
    (RLS) ve rolu saha personeli (security/tesis_gorevlisi) olmali; degilse 422.
    avatar_key yoneticinin kendi tenant namespace'inde (IDOR). null kaldirir;
    eski MinIO objesi silinir."""
    obj = await get_or_404(db, AppUser, user_id)
    if obj.role not in _AVATAR_HEDEF_ROLLER:
        raise APIError(422, "invalid_target",
                       "yalniz_saha_personeline_foto")
    if body.avatar_key is not None and not body.avatar_key.startswith(
        f"{user.tenant_id}/"
    ):
        raise APIError(422, "invalid_foto_key", "avatar_key_alan_disi")
    eski = obj.avatar_key
    obj.avatar_key = body.avatar_key
    obj.updated_at = func.now()
    if eski and eski != body.avatar_key:
        delete_objects([eski])
    await audit_user(
        db, user, Action.AVATAR_UPDATE, resource_type="app_user",
        resource_id=obj.id, meta={"hedef": str(obj.id),
                                  "kaldirildi": body.avatar_key is None},
    )
    return _admin_out(obj)
