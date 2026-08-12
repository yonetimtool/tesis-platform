"""Kullanici yonetimi — GET/POST/PATCH /users (admin) — /contracts/openapi.yaml.

Mevcut app_user tablosu uzerinde calisir (yeni tablo yok). parola bcrypt ile
hash'lenir; password_hash YANITTA donmez (UserAdminOut'ta yok). tenant token'dan,
RLS izole. email tenant icinde benzersiz -> cakisma 409. Silme yok; pasiflestirme
is_active=false (PATCH).
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404, is_unique_violation, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Tenant
from ..roller import yonetilebilir
from ..schemas import (
    AcilabilirRollerOut,
    AvatarUpdate,
    DavetGonderimSonucu,
    ResidentResetPasswordOut,
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
from ..security import generate_temp_code, hash_password
from ..storage import delete_objects, presign_get

router = APIRouter(prefix="/users", tags=["users"])

_ADMIN = require_role("admin")
# yonetici gorev atamak icin kullanici listesini OKUR; CRUD admin-only (auth.md §4).
# (P35) Amir de okur: kendi ekibini yonetebilmesi icin listeyi gormeli.
_READER = require_role("admin", "yonetici", "guvenlik_amiri")
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
# Saha personeli fotosu YALNIZ yonetici yonetir (spec P3); hedef saha personeli.
_AVATAR_MANAGER = require_role("yonetici")
_AVATAR_HEDEF_ROLLER = {"security", "tesis_gorevlisi"}


def _admin_out(obj: AppUser) -> UserAdminOut:
    """AppUser -> UserAdminOut; avatar_key varsa presigned GET URL doldurur."""
    out = UserAdminOut.model_validate(obj)
    out.avatar_url = presign_get(obj.avatar_key) if obj.avatar_key else None
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
    return _admin_out(await get_or_404(db, AppUser, user_id))


@router.post("", response_model=UserCreatedOut, status_code=201)
async def create_user(
    body: UserCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_USER_CREATOR),
) -> UserCreatedOut:
    # (P130) TEK kural, TEK tablo: yonetilen kume disi -> 403.
    # Eskiden rol basina IF vardi; yeni bir rol eklenince (P128 `denetci`)
    # hicbir IF'e girmez ve SESSIZCE her seyi acabilir olurdu.
    if body.role not in yonetilebilir(user.role):
        raise APIError(
            403, "forbidden", _ACMA_HATASI.get(user.role, "rol_olusturulamaz")
        )
    # password verilirse admin parolayi dogrudan belirler (password_set=true);
    # verilmezse TEK SEFERLIK gecici kod uretilir (temp password first) —
    # kod yanitta bir kez doner, kullanici telefonla girip parola belirler.
    temp_code: str | None = None
    if body.password is not None:
        password_hash = hash_password(body.password)
        password_set = True
        temp_code_hash = None
    else:
        temp_code = generate_temp_code()
        password_hash = None
        password_set = False
        temp_code_hash = hash_password(temp_code)

    obj = AppUser(
        tenant_id=user.tenant_id,
        ad=body.ad,
        email=str(body.email) if body.email else None,
        telefon=body.telefon,
        aranabilir=body.aranabilir,
        password_hash=password_hash,
        password_set=password_set,
        temp_code_hash=temp_code_hash,
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
    # (P155 §7) DAVET: parolasiz acilan personel/denetci hesabina jetonlu
    # kayit bagi gonderilir. Eskiden yalniz E-POSTASI OLANA tek-seferlik kod
    # gidiyordu; davet SMS'i ASIL kanal yapar (telefon her zaman var) ve
    # e-postayi EK yapar — sartname §7'nin kanal onceligi. Gonderim katmani
    # (`gonderim.saglayici`) ayni: SMTP/SMS yoksa saglayici LOG'dur ve
    # `gonderildi=false` doner; yonetici panelden gitmeyeni gorur.
    #
    # AD OPSIYONEL DEGIL (personelde): `UserCreate.ad` zorunlu; davet ad
    # on-doldurmasi burada gerekmiyor.
    davet_ozeti = None
    if not password_set:
        tenant_adi = (
            await db.execute(select(Tenant.ad).where(Tenant.id == user.tenant_id))
        ).scalar_one_or_none() or ""
        gonderildi = await davet_olustur_ve_gonder(
            db, user=obj, tenant_ad=tenant_adi, gonderen_id=user.id,
        )
        davet_ozeti = DavetGonderimSonucu(gonderildi=gonderildi, kanal="sms")

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
        temp_code=temp_code,
        davet=davet_ozeti,
    )


@router.patch("/{user_id}", response_model=UserAdminOut)
async def update_user(
    user_id: uuid.UUID,
    body: UserUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_USER_CREATOR),
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
    new_password = data.pop("password", None)
    if "email" in data and data["email"] is not None:
        data["email"] = str(data["email"])
    for key, value in data.items():
        setattr(obj, key, value)
    if new_password is not None:
        obj.password_hash = hash_password(new_password)
        obj.password_set = True
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise _CONTACT_CONFLICT
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.USER_UPDATE, resource_type="app_user",
        # HEDEFIN ROLU de yazilir: "kim, HANGI ROLDEKI kaydi, hangi
        # alanlarda degistirdi" sorusu aylar sonra da cevaplanabilsin.
        # (Aktoru ve rolunu `audit_user` zaten yaziyor.)
        resource_id=obj.id,
        meta={"fields": list(data.keys()), "hedef_rol": obj.role},
    )
    return _admin_out(obj)


@router.delete("/{user_id}", status_code=204)
async def delete_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_USER_CREATOR),
) -> Response:
    """(P154 / Asama 5) Kullaniciyi SILER.

    Brief: "Yonetici; sakin, guvenlik, tesis gorevlisi ve denetci
    hesaplarinin telefonunu guncelleyebilir, KULLANICIYI SILEBILIR."

    SERT SILME, `is_active=false` DEGIL — ve bu Asama 1'deki yonetici
    silmeyle AYNI gerekce: yumusak silme ZATEN `PATCH is_active` ile
    yapilabiliyor; iki dugmenin ayni isi yapmasi kullaniciyi yaniltirdi.
    "Sil" dendiginde kayit gitmelidir.

    AYNI KAPIDAN GECER: `_yonetim_kapisi` — yonetici kendi kumesi disindaki
    (orn. admin) bir kaydi silemez. Kapiyi burada tekrar yazmak, biri
    guncellenip otekinin unutulmasi demekti.

    KENDINI SILEMEZ: oturumu acik olan kisinin kendi kaydini silmesi,
    tesisi yoneticisiz birakabilir ve geri alinamaz. Kendi hesabini silmek
    isteyen icin AYRI ve onayli bir yol var (`POST /me/hesap-sil`, KVKK).
    """
    obj = await get_or_404(db, AppUser, user_id)
    # KENDI HESABI KONTROLU KAPIDAN ONCE: sirasi ters olsaydi kendi
    # kaydini silmeye calisan bir yonetici "bu hesap turunu duzenleme
    # yetkiniz yok" mesajini alirdi — dogru ama YANILTICI; asil sebep
    # yetki degil, kendini silemiyor olmasi.
    if obj.id == user.id:
        raise APIError(409, "conflict", "kendi_hesabini_silemez")
    _yonetim_kapisi(user, obj.role)

    await audit_user(
        db, user, Action.USER_DELETE, resource_type="app_user",
        resource_id=obj.id,
        meta={"rol": obj.role, "ad": obj.ad},
    )
    await db.delete(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    return Response(status_code=204)


@router.post("/{user_id}/reset-password", response_model=ResidentResetPasswordOut)
async def reset_user_password(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_USER_CREATOR),
) -> "ResidentResetPasswordOut":
    """Personel parolasini sifirla (admin + yonetici): yeni TEK SEFERLIK gecici
    kod uretir; personel telefon + bu kodla girip yeni parolasini belirler. Kod
    yalniz bu yanitta doner. yonetici YALNIZ saha personeli (guvenlik/tesis
    gorevlisi) icin sifirlar."""
    obj = await get_or_404(db, AppUser, user_id)
    # Parola sifirlama da AYNI kapidan: kaydina dokunamadigin kisinin
    # parolasini da sifirlayamazsin.
    _yonetim_kapisi(user, obj.role)
    temp_code = generate_temp_code()
    obj.password_hash = None
    obj.password_set = False
    obj.temp_code_hash = hash_password(temp_code)
    obj.updated_at = func.now()
    await db.flush()
    await audit_user(
        db, user, Action.USER_RESET_PASSWORD, resource_type="app_user",
        resource_id=obj.id,
    )
    return ResidentResetPasswordOut(temp_code=temp_code)


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
