"""CRUD router'lari icin ortak yardimcilar (404, integrity->4xx, referans dogrulama)."""
from __future__ import annotations

import uuid
from collections.abc import Iterable

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from .errors import APIError


async def get_or_404(db: AsyncSession, model: type, obj_id: uuid.UUID):
    """id ile kaydi getir; yoksa (veya RLS ile baska tenant'a aitse) 404."""
    obj = (
        await db.execute(select(model).where(model.id == obj_id))
    ).scalar_one_or_none()
    if obj is None:
        raise APIError(404, "not_found", "Kayit bulunamadi.")
    return obj


def _pgcode(exc: IntegrityError) -> str | None:
    orig = getattr(exc, "orig", None)
    return getattr(orig, "sqlstate", None) or getattr(orig, "pgcode", None)


def is_unique_violation(exc: IntegrityError) -> bool:
    return _pgcode(exc) == "23505"


def coord_eq(a, b) -> bool:
    """GPS koordinati esitligi (Numeric/float, 6 hane tolerans)."""
    if a is None or b is None:
        return a is b
    return round(float(a), 6) == round(float(b), 6)


def translate_integrity(exc: IntegrityError) -> APIError:
    """DB kisit ihlalini sozlesme hata zarfina cevir."""
    code = _pgcode(exc)
    if code == "23505":  # unique_violation
        return APIError(409, "conflict", "Kayit zaten mevcut (benzersizlik ihlali).")
    if code == "23503":  # foreign_key_violation
        return APIError(409, "conflict", "Iliskili kayit nedeniyle islem yapilamiyor.")
    if code == "23514":  # check_violation
        return APIError(422, "validation_error", "Deger kisit ihlali.")
    if code == "23502":  # not_null_violation
        return APIError(422, "validation_error", "Zorunlu alan eksik.")
    return APIError(409, "conflict", "Veritabani kisit ihlali.")


async def ensure_checkpoints_in_tenant(
    db: AsyncSession, checkpoint_ids: Iterable[uuid.UUID]
) -> None:
    """Verilen checkpoint id'lerinin hepsi (RLS ile) bu tenant'ta var mi?

    Capraz-tenant referansi uygulama katmaninda anlamli 422 ile reddet.
    """
    from .models import Checkpoint

    ids = list(dict.fromkeys(checkpoint_ids))  # tekrarsiz, sirayi koru
    if not ids:
        return
    found = set(
        (
            await db.execute(
                select(Checkpoint.id).where(Checkpoint.id.in_(ids))
            )
        )
        .scalars()
        .all()
    )
    missing = [str(i) for i in ids if i not in found]
    if missing:
        raise APIError(
            422,
            "invalid_reference",
            f"Checkpoint bu tenant'ta bulunamadi: {', '.join(missing)}",
        )
