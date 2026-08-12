"""POST /residents — yonetici daire + sakin hesabini tek adimda acar.

Sakin kimlik modeli (bkz. /contracts/auth.md §1.2): sakin email ile DEGIL,
daire no + parola ile girer. Yonetici sakini olustururken TEK SEFERLIK gecici
kod uretilir; kod yalniz bu yanitta duz metin doner (yonetici sakine iletir),
DB'de bcrypt hash'i saklanir. Sakin ilk giriste kodu kullanir ve kalici
parolasini belirlemek zorundadir (/auth/set-password).

RBAC: yonetici + admin (unit CRUD'un admin-only olmasi bundan ayridir; bu uc
yoneticinin sakin acma akisidir ve unit'i gerekirse ortulu olusturur).
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Response
from sqlalchemy import and_, func, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import is_unique_violation, translate_integrity
from ..davet import davet_olustur_ve_gonder
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..hesap_silme import hesabi_sil_veya_anonimlestir
from ..models import AppUser, Unit, UnitResident
from ..schemas import (
    DavetGonderimSonucu,
    ResidentCreate,
    ResidentCreatedOut,
    ResidentDeleteOut,
    ResidentListItem,
    ResidentListResponse,
    ResidentResetPasswordOut,
    ResidentUpdate,
)
from ..security import generate_temp_code, hash_password

router = APIRouter(prefix="/residents", tags=["auth"])

_YONETIM = require_role("admin", "yonetici")

#: `exclude_unset` ile "hic gonderilmedi"yi "acikca null gonderildi"den
#: ayirmak icin nobetci — `None` gecerli bir DEGERDIR (email temizleme).
_ATLA = object()


@router.post("", response_model=ResidentCreatedOut, status_code=201)
async def create_resident(
    body: ResidentCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> ResidentCreatedOut:
    # 1) unit: ayni no varsa mevcut kullanilir (ayni daireye malik VE
    #    kiraci baglanabilir — sinir 1b'de), yoksa ortulu olusturulur.
    unit: Unit | None = (
        await db.execute(select(Unit).where(Unit.no == body.unit_no))
    ).scalar_one_or_none()
    if unit is None:
        unit = Unit(tenant_id=user.tenant_id, no=body.unit_no, blok=body.blok)
        db.add(unit)
        try:
            await db.flush()
        except IntegrityError as exc:
            raise translate_integrity(exc)

    # 1b) (P154 / Asama 5) DAIRE BASINA HER ROLDEN BIR AKTIF HESAP.
    #
    # KONTROL BURADA EKSIKTI: kural goc 0049 ile kondu ve `units.
    # assign_resident` ile ICE AKTARIM onu `daire_rolu_dolu_mu` uzerinden
    # uyguluyordu; sakin acmanin ASIL kapisi olan BU UC ise uygulamiyordu.
    # Veritabani indeksi (unit_id, rol_tipi) ikinci bir MALIKI yakalar ama
    # PostgreSQL benzersiz indekslerde NULL'lari catistirmaz — yani
    # `rol_tipi` verilmeden acilan sakinler bu daireye SINIRSIZ eklenirdi.
    # Mobil form artik ad ve rol tipi SORMADIGI icin (yalniz telefon +
    # daire no) o dal varsayilan yol hâline geliyor; bosluk kapatilmali.
    from .units import daire_rolu_dolu_mu  # yerel import: ice_aktarim ile ayni

    if await daire_rolu_dolu_mu(db, unit.id, body.rol_tipi):
        raise APIError(409, "conflict", "daire_zaten_dolu")

    # 2) sakin hesabi. Parola VERILDIYSE dogrudan belirlenir (gecici kod YOK);
    #    verilmediyse tek seferlik gecici kod uretilir.
    if body.password is not None:
        temp_code = None
        password_hash = hash_password(body.password)
        password_set = True
        temp_code_hash = None
    else:
        temp_code = generate_temp_code()
        password_hash = None
        password_set = False
        temp_code_hash = hash_password(temp_code)
    resident = AppUser(
        tenant_id=user.tenant_id,
        # Ad verilmediyse DAIREDEN turetilen gecici ad — gerekcesi
        # `ResidentCreate` docstring'inde (sutunu global nullable yapmak
        # brief'in dokunmadigi her ekrani ilgilendirirdi).
        ad=body.ad or f"{unit.no} sakini",
        email=str(body.email) if body.email else None,
        telefon=body.telefon,
        role="resident",
        password_hash=password_hash,
        temp_code_hash=temp_code_hash,
        password_set=password_set,
    )
    db.add(resident)
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            # telefon global benzersiz; email tenant-ici benzersiz — hangisi
            # oldugu ayirt edilmeden tek mesaj (numara/e-posta cakismasi).
            raise APIError(409, "conflict", "telefon_veya_email_zaten_kayitli")
        raise translate_integrity(exc)

    # 3) aktif daire-sakin baglantisi.
    db.add(
        UnitResident(
            tenant_id=user.tenant_id,
            unit_id=unit.id,
            user_id=resident.id,
            rol_tipi=body.rol_tipi,
        )
    )
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)

    await audit_user(
        db, user, Action.RESIDENT_CREATE, resource_type="app_user",
        resource_id=resident.id, meta={"unit_id": str(unit.id)},
    )

    # (P155 §7) DAVET: parolasiz acilan hesaba jetonlu kayit bagi gonder.
    # Parola VERILDIYSE davet anlamsizdir (hesap zaten girebilir).
    davet_ozeti = None
    if not password_set:
        tenant_ad = (
            await db.execute(
                text("SELECT ad FROM tenant WHERE id = :t"),
                {"t": str(user.tenant_id)},
            )
        ).scalar_one()
        gonderildi = await davet_olustur_ve_gonder(
            db, user=resident, tenant_ad=tenant_ad, gonderen_id=user.id,
        )
        davet_ozeti = DavetGonderimSonucu(gonderildi=gonderildi, kanal="sms")

    return ResidentCreatedOut(
        user_id=resident.id,
        unit_id=unit.id,
        unit_no=unit.no,
        ad=resident.ad,
        email=resident.email,
        temp_code=temp_code,
        davet=davet_ozeti,
    )


@router.get("", response_model=ResidentListResponse)
async def list_residents(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> ResidentListResponse:
    """Site sakinleri (yonetici/admin) — ad + aktif daire no + durum.

    Telefon KVKK geregi DONMEZ. unit_no aktif (bitis IS NULL) daire baglarindan
    turer; coklu daire virgulle birlesir, yoksa null. RLS ile tenant-kapsamli.
    """
    rows = (
        await db.execute(
            select(
                AppUser.id,
                AppUser.ad,
                AppUser.is_active,
                func.string_agg(Unit.no, ", ").label("unit_no"),
            )
            .outerjoin(
                UnitResident,
                and_(
                    UnitResident.user_id == AppUser.id,
                    UnitResident.bitis.is_(None),
                ),
            )
            .outerjoin(Unit, Unit.id == UnitResident.unit_id)
            .where(AppUser.role == "resident")
            .group_by(AppUser.id, AppUser.ad, AppUser.is_active)
            .order_by(AppUser.ad)
        )
    ).all()
    return ResidentListResponse(
        items=[
            ResidentListItem(
                user_id=r.id, ad=r.ad, unit_no=r.unit_no, is_active=r.is_active
            )
            for r in rows
        ]
    )


async def _resident_or_404(db: AsyncSession, user_id: uuid.UUID) -> AppUser:
    resident = (
        await db.execute(
            select(AppUser).where(
                AppUser.id == user_id, AppUser.role == "resident"
            )
        )
    ).scalar_one_or_none()
    if resident is None:
        raise APIError(404, "not_found", "sakin_bulunamadi")
    return resident


@router.patch("/{user_id}", status_code=204)
async def update_resident(
    user_id: uuid.UUID,
    body: ResidentUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> Response:
    """Sakini duzenle (yonetici/admin) — P23b: olusturmadaki TUM alanlar.

    `ad`, `telefon` (global benzersiz; cakisma 409), `email` (acikca null =
    temizle) ve `rol_tipi` (malik/kiraci). `rol_tipi` kullanicinin AKTIF
    daire baglarina uygulanir; aktif bagi yoksa **422** — once daire
    atanmalidir (`POST /units/{id}/residents`).

    Gonderilmeyen alan DEGISMEZ (`exclude_unset`).
    """
    resident = await _resident_or_404(db, user_id)
    alanlar = body.model_dump(exclude_unset=True)
    fields = list(alanlar.keys())
    # rol_tipi kullanicinin kendi satirinda DEGIL, daire BAGINDA durur.
    rol_tipi = alanlar.pop("rol_tipi", _ATLA)
    if rol_tipi is not _ATLA:
        baglar = (
            await db.execute(
                select(UnitResident).where(
                    UnitResident.user_id == user_id,
                    UnitResident.bitis.is_(None),
                )
            )
        ).scalars().all()
        if not baglar:
            raise APIError(422, "invalid_reference", "sakin_daireye_bagli_degil")
        for bag in baglar:
            bag.rol_tipi = rol_tipi
    for key, value in alanlar.items():
        setattr(resident, key, value)
    resident.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "telefon_zaten_kayitli")
        raise translate_integrity(exc)
    # meta: yalniz DEGISEN ALAN ADLARI (deger YOK — KVKK).
    await audit_user(
        db, user, Action.RESIDENT_UPDATE, resource_type="app_user",
        resource_id=user_id, meta={"fields": fields},
    )
    return Response(status_code=204)


@router.post("/{user_id}/reset-password", response_model=ResidentResetPasswordOut)
async def reset_resident_password(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> ResidentResetPasswordOut:
    """Sakin parolasini sifirla (yonetici/admin): yeni TEK SEFERLIK gecici kod
    uretir. Sakin telefon + bu kodla girip yeni parolasini belirler (§1.3).
    Kod YALNIZ bu yanitta duz metin doner."""
    resident = await _resident_or_404(db, user_id)
    temp_code = generate_temp_code()
    resident.password_hash = None
    resident.password_set = False
    resident.temp_code_hash = hash_password(temp_code)
    resident.updated_at = func.now()
    await db.flush()
    await audit_user(
        db, user, Action.RESIDENT_RESET_PASSWORD, resource_type="app_user",
        resource_id=user_id,
    )
    return ResidentResetPasswordOut(temp_code=temp_code)


@router.delete("/{user_id}", response_model=ResidentDeleteOut)
async def remove_resident_from_site(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> ResidentDeleteOut:
    """Sakini SIL / ANONIMLESTIR (KVKK silme hakki; yonetici/admin).

    (P112) KURAL TEK YERDE: ne silinip ne kaldigi `app/hesap_silme.py`de
    yazilidir ve self-servis silme (`POST /me/hesap-sil`) AYNI cekirdegi
    kullanir. Eskiden mantik burada gomuluydu; ikinci cagirani eklerken
    kopyalamak, KVKK ayrimini iki yerde tutmak ve birinde duzeltilip
    digerinde unutulan bir alanin **silinmis sanilan kisisel veri**
    birakmasi demekti.

    `deleted=true`  -> gecmissiz sakin, satir tamamen silindi.
    `deleted=false` -> gecmisi var (FK RESTRICT); satir kaldi, kimlik
                       alanlari temizlendi. Finans/denetim satirlari yasal
                       saklama geregi KALIR ve artik anonim kullaniciya
                       isaret eder.
    role=resident degilse 404.
    """
    resident = await _resident_or_404(db, user_id)
    tam_silindi = await hesabi_sil_veya_anonimlestir(
        db, resident, kendi_istegi=False
    )
    await audit_user(
        db, user,
        Action.RESIDENT_DELETE if tam_silindi else Action.RESIDENT_ERASURE,
        resource_type="app_user", resource_id=user_id,
        meta={"mode": "hard_delete" if tam_silindi else "anonymize"},
    )
    return ResidentDeleteOut(deleted=tam_silindi)
