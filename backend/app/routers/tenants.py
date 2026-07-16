"""POST/GET /tenants — admin (platform) cross-tenant tesis olusturma/listeleme.

Onboarding Model A: admin bir tenant + N yonetici hesabini birlikte acar;
BIRINCIL yonetici (listedeki ilk) ILK GIRISTE POST /tenant/setup ile tesisi
adlandirir/onaylar. tenant RLS FORCE oldugundan cross-tenant islem owner-sahipli
SECURITY DEFINER fonksiyonlarla yapilir (create_tenant_with_yoneticis /
list_all_tenants); YALNIZ admin'e acilir (RBAC). tenant_id GIZLI kimliktir.
"""
from __future__ import annotations

import json
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
    TenantAdminUpdate,
    TenantYoneticiOut,
    TenantYoneticiResetOut,
    TenantYoneticiUpdate,
    YoneticiCreatedOut,
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
    """Admin: yeni tenant + N yonetici acar (listedeki ILK yonetici BIRINCIL).

    Yonetici basina parola verilirse dogrudan belirlenir; verilmezse tek
    seferlik gecici kod uretilir (bir kez doner). `ad` verilmezse yer tutucu +
    rastgele slug; her durumda kurulum_tamamlandi=false (birincil ONAYLAR).
    Telefon GLOBAL benzersiz -> cakisma 409 (tenant olusmaz; tek transaction).
    """
    hazir: list[dict] = []
    for y in body.yoneticiler:
        try:
            phone = normalize_phone(y.phone)
        except ValueError:
            raise APIError(422, "validation_error", "Gecersiz telefon numarasi.")
        if y.password is not None:
            hazir.append({
                "ad": y.ad, "telefon": phone,
                "password_hash": hash_password(y.password),
                "temp_code_hash": None, "password_set": True, "temp_code": None,
            })
        else:
            code = generate_temp_code()
            hazir.append({
                "ad": y.ad, "telefon": phone, "password_hash": None,
                "temp_code_hash": hash_password(code), "password_set": False,
                "temp_code": code,
            })

    # Sema tekrari ham girdiye bakar; normalize SONRASI da cakisabilir
    # (orn. "0532..." ve "+90532..." ayni numaraya coker).
    phones = [h["telefon"] for h in hazir]
    if len(phones) != len(set(phones)):
        raise APIError(
            422, "validation_error",
            "Ayni telefon birden fazla yoneticide kullanilamaz.",
        )

    ad = body.ad or _PLACEHOLDER_AD
    payload = [
        {k: h[k] for k in
         ("ad", "telefon", "password_hash", "temp_code_hash", "password_set")}
        for h in hazir
    ]

    async with SessionLocal() as session:
        async with session.begin():
            try:
                rows = (
                    await session.execute(
                        text(
                            "SELECT tenant_id, user_id, telefon, birincil FROM "
                            "public.create_tenant_with_yoneticis("
                            ":ad, :slug, :tz, :kur, :yem, CAST(:yon AS jsonb))"
                        ),
                        {
                            "ad": ad,
                            "slug": slugify_tenant(ad),
                            "tz": "Europe/Istanbul",
                            "kur": False,
                            "yem": body.yonetim_email,
                            "yon": json.dumps(payload),
                        },
                    )
                ).all()
            except IntegrityError:
                raise APIError(409, "conflict", "Bu telefon zaten kayitli.")

    # INSERT ... RETURNING satir SIRASINI garanti etmez -> TELEFONLA esle.
    # (Yanlis esleme = yanlis kisiye gecici kod.)
    by_phone = {r.telefon: r for r in rows}

    return TenantAdminCreatedOut(
        tenant_id=rows[0].tenant_id,
        yoneticiler=[
            YoneticiCreatedOut(
                user_id=by_phone[h["telefon"]].user_id,
                ad=h["ad"],
                birincil=by_phone[h["telefon"]].birincil,
                temp_code=h["temp_code"],
            )
            for h in hazir
        ],
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


@router.patch("/{tenant_id}", response_model=TenantAdminDetail)
async def update_tenant(
    tenant_id: uuid.UUID,
    body: TenantAdminUpdate,
    _: AppUser = Depends(_ADMIN),
) -> TenantAdminDetail:
    """Admin: tesis ADINI degistirir (rename/duzeltme). kurulum_tamamlandi=true
    olur. Bilinmeyen tesis 404."""
    async with SessionLocal() as session:
        async with session.begin():
            updated = (
                await session.execute(
                    text("SELECT public.update_tenant_ad(:tid, :ad)"),
                    {"tid": tenant_id, "ad": body.ad},
                )
            ).scalar()
            if updated is None:
                raise APIError(404, "not_found", "Tesis bulunamadi.")
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
