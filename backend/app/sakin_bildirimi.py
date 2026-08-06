"""(P147) Sakine ait bildirim SATIRI yazma — anlik push'un kalici ikizi.

NEDEN AYRI BIR YARDIMCI: `dispatch_external` anlik bildirimi gonderir ve
GERIYE HICBIR SEY BIRAKMAZ. Bildirimi o an kaciran kullanici icin olay yok
olur. Bu yardimci ayni olayi `notification` tablosuna da yazar; ikisi yan
yana cagrilir.

METIN KAYDA DONDURULMAZ: satir yalnizca `mesaj_kimlik` + `mesaj_veri`
tutar, okuma yolu metni ISTEGIN dilinde uretir (tur 16 karari). `mesaj`
sutunu NOT NULL oldugu icin Turkce karsiligi doldurulur — eski satirlarla
ayni bicim, ama okuma yolu onu KULLANMAZ.
"""
from __future__ import annotations

import uuid
from collections.abc import Iterable, Mapping

from sqlalchemy.ext.asyncio import AsyncSession

from .models import Notification
from .push_metinleri import push_govdesi


def sakin_bildirimi_yaz(
    db: AsyncSession,
    *,
    tenant_id: uuid.UUID,
    tip: str,
    user_ids: Iterable[uuid.UUID],
    veri: Mapping[str, object] | None = None,
    task_id: uuid.UUID | None = None,
) -> list[Notification]:
    """Her alici icin BIR satir yazar (flush cagirani yapar).

    Alici basina ayri satir: okundu bilgisi KISIYE aittir. Tek satiri
    paylastirsaydik bir kullanicinin okumasi digerininkini de "okundu"
    yapardi — kargo gibi cok alicili olaylarda bu gorulur bir kusurdur.
    """
    veri = dict(veri or {})
    satirlar: list[Notification] = []
    for uid in dict.fromkeys(user_ids):  # yinelenen alici tek satir
        row = Notification(
            tenant_id=tenant_id,
            user_id=uid,
            tip=tip,
            mesaj=push_govdesi(tip, "tr", veri),
            mesaj_kimlik=tip,
            mesaj_veri=veri,
            task_id=task_id,
        )
        db.add(row)
        satirlar.append(row)
    return satirlar
