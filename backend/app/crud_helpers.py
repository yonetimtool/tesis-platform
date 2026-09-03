"""CRUD router'lari icin ortak yardimcilar (404, integrity->4xx, referans dogrulama)."""
from __future__ import annotations

import re
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
        raise APIError(404, "not_found", "kayit_bulunamadi")
    return obj


def _pgcode(exc: IntegrityError) -> str | None:
    orig = getattr(exc, "orig", None)
    return getattr(orig, "sqlstate", None) or getattr(orig, "pgcode", None)


def is_unique_violation(exc: IntegrityError) -> bool:
    return _pgcode(exc) == "23505"


def kisit_adi(exc: IntegrityError) -> str | None:
    """Ihlal edilen KISITIN ADI (asyncpg `constraint_name`).

    (P211 §3) Neden gerekli: `create_payment` her unique ihlalini
    "ayni Idempotency-Key farkli govde" sayiyordu. Kullanici AYNI MAKBUZ
    NUMARASINI ikinci kez yazdiginda ihlal `uq_hareket_belge_no` oluyor ve
    ekranda ALAKASIZ bir mesaj cikiyordu (olculdu). Hangi kisidin kirildigi
    bilinmeden dogru cumle kurulamaz.
    """
    orig = getattr(exc, "orig", None)
    ad = getattr(orig, "constraint_name", None)
    if ad:
        return str(ad)
    ic = getattr(orig, "__cause__", None)
    ad = getattr(ic, "constraint_name", None)
    return str(ad) if ad else None


def is_exclusion_violation(exc: IntegrityError) -> bool:
    """EXCLUDE constraint ihlali (23P01) — orn. rezervasyon cakisma kisiti."""
    return _pgcode(exc) == "23P01"


def coord_eq(a, b) -> bool:
    """GPS koordinati esitligi (Numeric/float, 6 hane tolerans)."""
    if a is None or b is None:
        return a is b
    return round(float(a), 6) == round(float(b), 6)


def translate_integrity(exc: IntegrityError) -> APIError:
    """DB kisit ihlalini sozlesme hata zarfina cevir."""
    code = _pgcode(exc)
    if code == "23505":  # unique_violation
        return APIError(409, "conflict", "kayit_zaten_mevcut")
    if code == "23503":  # foreign_key_violation
        return APIError(409, "conflict", "iliskili_kayit_engeli")
    if code == "23514":  # check_violation
        return APIError(422, "validation_error", "deger_kisit_ihlali")
    if code == "23502":  # not_null_violation
        return APIError(422, "validation_error", "zorunlu_alan_eksik")
    return APIError(409, "conflict", "veritabani_kisit_ihlali")


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
            "checkpoint_listesi_bulunamadi",
            eksik=", ".join(missing),
        )


def norm_nfc(uid: str | None) -> str | None:
    """NFC UID normalizasyonu (strip + upper) — tum uclarda AYNI karsilastirma.

    Mobil UID'yi buyuk harf uretir ama panelden farkli formatta girilebilir;
    eslesme buyuk/kucuk harfe ve bas/son bosluga takilmasin (mobil §11 #3).
    """
    return uid.strip().upper() if uid is not None else None


def nfc_eq(a: str | None, b: str | None) -> bool:
    return norm_nfc(a) == norm_nfc(b)


# Plaka normalizasyonu: alfanumerik DISI her sey atilir (bosluk, tire, nokta),
# kalanlar buyuk harf. Turkce plakada harf yoktur ama kullanici "34 abc 123",
# "34-ABC-123", "34ABC123" yazabilir — hepsi AYNI araci gosterir.
_PLAKA_ATILACAK = re.compile(r"[^0-9A-Za-z]")


def norm_plaka(plaka: str) -> str:
    """Plakayi kanonik forma cevir (bosluksuz + BUYUK). Bos/gecersiz -> 422.

    DB'de YALNIZ normalize hali saklanir (ck_vehicle_pass_plaka bunu zorlar),
    boylece acik-gecis benzersizligi ve plaka aramasi format-bagimsiz calisir.
    """
    norm = _PLAKA_ATILACAK.sub("", plaka).upper()
    if not (2 <= len(norm) <= 20):
        raise APIError(422, "validation_error", "plaka_bicimi")
    return norm
