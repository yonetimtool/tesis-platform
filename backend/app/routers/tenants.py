"""POST/GET /tenants — admin (platform) cross-tenant tesis olusturma/listeleme.

Onboarding Model A: admin bir tenant (isimsiz, kurulum_tamamlandi=false) +
yonetici hesabini birlikte acar; yonetici ILK GIRISTE POST /tenant/setup ile
adlandirir. tenant RLS FORCE oldugundan cross-tenant islem owner-sahipli
SECURITY DEFINER fonksiyonlarla yapilir (create_tenant_with_yonetici /
list_all_tenants); YALNIZ admin'e acilir (RBAC). tenant_id GIZLI kimliktir.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Response
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from ..db import SessionLocal
from ..deps import require_role
from ..errors import APIError
from ..models import AppUser
from ..schemas import (
    TenantAdminCreate,
    TenantAdminCreatedOut,
    TenantAdminDetail,
    TenantAdminListItem,
    TenantAdminListResponse,
    TenantYoneticiOut,
    TenantYoneticiResetOut,
    TenantYoneticiUpdate,
)
from ..security import (
    generate_temp_code,
    hash_password,
    normalize_phone,
    slugify_tenant,
)

router = APIRouter(prefix="/tenants", tags=["tenant"])

_ADMIN = require_role("admin")

# Yonetici tesisi adlandirana kadar gorunecek yer tutucu ad.
_PLACEHOLDER_AD = "(Kurulum bekliyor)"


@router.post("", response_model=TenantAdminCreatedOut, status_code=201)
async def create_tenant(
    body: TenantAdminCreate,
    _: AppUser = Depends(_ADMIN),
) -> TenantAdminCreatedOut:
    """Admin: yeni tenant (isimsiz, kurulum_tamamlandi=false) + yonetici acar.
    Parola verilirse dogrudan belirlenir; verilmezse gecici kod uretilir (bir
    kez doner). Telefon global benzersiz -> cakisma 409."""
    try:
        phone = normalize_phone(body.phone)
    except ValueError:
        raise APIError(422, "validation_error", "Gecersiz telefon numarasi.")

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

    async with SessionLocal() as session:
        async with session.begin():
            try:
                row = (
                    await session.execute(
                        text(
                            "SELECT tenant_id, user_id FROM "
                            "public.create_tenant_with_yonetici("
                            ":ad, :slug, :tz, :yad, :tel, :ph, :pset, :tch, :kur)"
                        ),
                        {
                            "ad": _PLACEHOLDER_AD,
                            "slug": slugify_tenant(_PLACEHOLDER_AD),
                            "tz": "Europe/Istanbul",
                            "yad": body.yonetici_ad,
                            "tel": phone,
                            "ph": password_hash,
                            "pset": password_set,
                            "tch": temp_code_hash,
                            "kur": False,
                        },
                    )
                ).one()
            except IntegrityError:
                raise APIError(409, "conflict", "Bu telefon zaten kayitli.")

    return TenantAdminCreatedOut(
        tenant_id=row.tenant_id,
        yonetici_user_id=row.user_id,
        temp_code=temp_code,
    )


@router.get("", response_model=TenantAdminListResponse)
async def list_tenants(
    _: AppUser = Depends(_ADMIN),
) -> TenantAdminListResponse:
    """Admin: TUM tesisler (id + ad + kurulum durumu + tarih). Baska tenant
    verisi (kullanici vb.) donmez."""
    async with SessionLocal() as session:
        async with session.begin():
            rows = (
                await session.execute(
                    text(
                        "SELECT id, ad, kurulum_tamamlandi, created_at "
                        "FROM public.list_all_tenants()"
                    )
                )
            ).all()
    return TenantAdminListResponse(
        items=[
            TenantAdminListItem(
                id=r.id,
                ad=r.ad,
                kurulum_tamamlandi=r.kurulum_tamamlandi,
                created_at=r.created_at,
            )
            for r in rows
        ]
    )


_DETAIL_SQL = text(
    "SELECT tenant_id, tenant_ad, kurulum_tamamlandi, tenant_created_at, "
    "yonetici_id, yonetici_ad, telefon, is_active, password_set "
    "FROM public.tenant_detail(:tid)"
)


def _to_detail(row) -> TenantAdminDetail:
    yonetici = None
    if row.yonetici_id is not None:
        yonetici = TenantYoneticiOut(
            id=row.yonetici_id,
            ad=row.yonetici_ad,
            telefon=row.telefon,
            is_active=row.is_active,
            password_set=row.password_set,
        )
    return TenantAdminDetail(
        tenant_id=row.tenant_id,
        ad=row.tenant_ad,
        kurulum_tamamlandi=row.kurulum_tamamlandi,
        created_at=row.tenant_created_at,
        yonetici=yonetici,
    )


async def _detail_or_404(session, tenant_id: uuid.UUID):
    """tenant_detail satirini doner; tenant yoksa 404."""
    row = (await session.execute(_DETAIL_SQL, {"tid": tenant_id})).one_or_none()
    if row is None:
        raise APIError(404, "not_found", "Tesis bulunamadi.")
    return row


@router.get("/{tenant_id}", response_model=TenantAdminDetail)
async def get_tenant(
    tenant_id: uuid.UUID,
    _: AppUser = Depends(_ADMIN),
) -> TenantAdminDetail:
    """Admin: tek tesis detayi + yoneticisi (ad, telefon, durum, kurulum)."""
    async with SessionLocal() as session:
        async with session.begin():
            row = await _detail_or_404(session, tenant_id)
    return _to_detail(row)


@router.patch("/{tenant_id}/yonetici", response_model=TenantAdminDetail)
async def update_yonetici(
    tenant_id: uuid.UUID,
    body: TenantYoneticiUpdate,
    _: AppUser = Depends(_ADMIN),
) -> TenantAdminDetail:
    """Admin: tesis yoneticisinin ad/telefon/aktifligini gunceller (kismi).
    Telefon global benzersiz -> cakisma 409. Yonetici yoksa 404."""
    phone = None
    if body.phone is not None:
        try:
            phone = normalize_phone(body.phone)
        except ValueError:
            raise APIError(422, "validation_error", "Gecersiz telefon numarasi.")

    async with SessionLocal() as session:
        async with session.begin():
            row = await _detail_or_404(session, tenant_id)
            if row.yonetici_id is None:
                raise APIError(404, "not_found", "Tesiste yonetici yok.")
            try:
                updated = (
                    await session.execute(
                        text(
                            "SELECT public.update_tenant_yonetici"
                            "(:tid, :uid, :ad, :tel, :act)"
                        ),
                        {
                            "tid": tenant_id,
                            "uid": row.yonetici_id,
                            "ad": body.ad,
                            "tel": phone,
                            "act": body.is_active,
                        },
                    )
                ).scalar()
            except IntegrityError:
                raise APIError(409, "conflict", "Bu telefon zaten kayitli.")
            if updated is None:
                raise APIError(404, "not_found", "Tesiste yonetici yok.")
            row = await _detail_or_404(session, tenant_id)
    return _to_detail(row)


@router.post(
    "/{tenant_id}/yonetici/reset-credential",
    response_model=TenantYoneticiResetOut,
)
async def reset_yonetici_credential(
    tenant_id: uuid.UUID,
    _: AppUser = Depends(_ADMIN),
) -> TenantYoneticiResetOut:
    """Admin: yonetici parolasini sifirlar + yeni TEK SEFERLIK gecici kod uretir
    (bir kez doner; admin yoneticiye iletir). Yonetici tekrar ilk-giris akisina
    duser. Yonetici yoksa 404."""
    temp_code = generate_temp_code()
    async with SessionLocal() as session:
        async with session.begin():
            row = await _detail_or_404(session, tenant_id)
            if row.yonetici_id is None:
                raise APIError(404, "not_found", "Tesiste yonetici yok.")
            updated = (
                await session.execute(
                    text(
                        "SELECT public.reset_tenant_yonetici_credential"
                        "(:tid, :uid, :tch)"
                    ),
                    {
                        "tid": tenant_id,
                        "uid": row.yonetici_id,
                        "tch": hash_password(temp_code),
                    },
                )
            ).scalar()
            if updated is None:
                raise APIError(404, "not_found", "Tesiste yonetici yok.")
    return TenantYoneticiResetOut(temp_code=temp_code)


@router.delete("/{tenant_id}", status_code=204)
async def delete_tenant_endpoint(
    tenant_id: uuid.UUID,
    _: AppUser = Depends(_ADMIN),
) -> Response:
    """Admin: tesisi ve ON DELETE CASCADE ile TUM verisini (yonetici + duyuru +
    daire + sakin...) siler. GERI ALINAMAZ. Bilinmeyen tesis 404."""
    async with SessionLocal() as session:
        async with session.begin():
            deleted = (
                await session.execute(
                    text("SELECT public.delete_tenant(:tid)"),
                    {"tid": tenant_id},
                )
            ).scalar()
            if deleted is None:
                raise APIError(404, "not_found", "Tesis bulunamadi.")
    return Response(status_code=204)
