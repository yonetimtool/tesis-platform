"""Yonetici tek-seferlik (one-shot) daire erisim izni — ziyaretci/kargo
gorunurlugu icin paylasilan tuketim kontrolu.

Gizlilik modeli (auth.md §4 — KVKK): ziyaretci ve kargo kayitlari VARSAYILAN
olarak hem yonetici'ye hem admin'e kapalidir. Talebi acan (yonetici/admin) bir
daireye `POST /unit-access-request` ile izin TALEBI acar; dairenin sakini
onaylar -> tek-kullanimlik izin olusur. Talebi acan o dairenin kayitlarini ILK
okudugunda izin TUKETILIR (used=true); sonraki okuma yeni talep ister. Sureye
bagli DEGIL (one-shot, deterministik).
"""
from __future__ import annotations

import uuid

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from .models import UnitAccessPermission


async def try_consume_unit_permission(
    db: AsyncSession,
    unit_id: uuid.UUID,
    requester_id: uuid.UUID,
) -> bool:
    """Talebi acan (yonetici/admin) icin bu daireye ait GECERLI KULLANILMAMIS
    onayli izni bul ve TUKET (used=true). Atomik: tek satiri secip `used=false`
    kosullu UPDATE eder — es zamanli iki okuma yarissa yalniz biri tuketir,
    digeri False alir (403). Tuketilecek izin yoksa False (erisim reddedilir).

    `granted_to_yonetici_user_id` kolonu talebi acan yonetici VEYA admin id'sini
    tutar (isim tarihsel). RLS aktif oldugundan sorgu tenant icinde kalir.
    """
    pid = (
        await db.execute(
            select(UnitAccessPermission.id)
            .where(
                UnitAccessPermission.unit_id == unit_id,
                UnitAccessPermission.granted_to_yonetici_user_id == requester_id,
                UnitAccessPermission.durum == "onaylandi",
                UnitAccessPermission.used.is_(False),
            )
            .order_by(UnitAccessPermission.requested_at)
            .limit(1)
        )
    ).scalar_one_or_none()
    if pid is None:
        return False
    res = await db.execute(
        update(UnitAccessPermission)
        .where(
            UnitAccessPermission.id == pid,
            UnitAccessPermission.used.is_(False),
        )
        .values(used=True, used_at=func.now())
    )
    return res.rowcount > 0
