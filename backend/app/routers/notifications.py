"""GET /notifications + PATCH /notifications/{id} — /contracts/openapi.yaml.

RBAC (auth.md §4): admin + security. tenant token'dan; RLS izole.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Header, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..errors import APIError
from ..deps import get_tenant_db, require_role
from ..hata_metinleri import istek_dili
from ..models import AppUser, Notification
from ..push_metinleri import push_govdesi
from ..schemas import NotificationListResponse, NotificationOut, NotificationUpdate

router = APIRouter(prefix="/notifications", tags=["notifications"])

# (P35) Amir P34 alarmlarinin MUHATABIDIR: gormezse turu devralamaz.
# (P147) `resident` EKLENDI — ama AYNI SATIRLARI GORMEZ, bkz. `_kapsam`.
_VIEWER = require_role(
    "admin", "yonetici", "security", "guvenlik_amiri", "resident"
)

# Yonetim alarmlarini goren roller. Sakin BURADA YOK.
_YONETIM_GOZU = ("admin", "yonetici", "security", "guvenlik_amiri")


def _kapsam(user: AppUser):
    """(P147) KIM HANGI SATIRI GORUR — tek yerde.

    Iki ayri bildirim TURU ayni tabloda duruyor ve karistirilmamalari
    gerekiyor:
      * `user_id IS NULL` -> tesise ait YONETIM alarmi (kacirilan tur,
        eksik checkpoint...). Sakin bunlari gormemeli: baska dairelerin
        ve tesisin isleyisine dair bilgi tasirlar.
      * `user_id = <kisi>` -> o kisinin KENDI olayi (kargosu, talebi).
        Yonetim bunlari gormemeli: kisisel bildirim akisidir.

    Kural cikarimla degil ACIKCA yazili; yeni bir rol eklenirse
    `_YONETIM_GOZU`ne girmedikce KENDI satirlarini gorur.
    """
    if user.role in _YONETIM_GOZU:
        return Notification.user_id.is_(None)
    return Notification.user_id == user.id


def _out(row: Notification, dil: str) -> NotificationOut:
    """Kayit -> yanit; metin ISTEGIN dilinde uretilir.

    Kimlik yoksa (tur 16 oncesi satir) kayittaki `mesaj` aynen doner —
    geri uyumluluk; o metin donmus Turkce'dir ve cevrilemez.
    """
    out = NotificationOut.model_validate(row)
    if row.mesaj_kimlik:
        out.mesaj = push_govdesi(row.mesaj_kimlik, dil, row.mesaj_veri or {})
    return out


@router.get("", response_model=NotificationListResponse)
async def list_notifications(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    okundu: bool | None = Query(None),
    accept_language: str | None = Header(None, alias="Accept-Language"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_VIEWER),
) -> NotificationListResponse:
    where = [_kapsam(user)]
    if okundu is not None:
        where.append(Notification.okundu == okundu)
    total = (
        await db.execute(select(func.count()).select_from(Notification).where(*where))
    ).scalar_one()
    rows = (
        await db.execute(
            select(Notification)
            .where(*where)
            .order_by(Notification.created_at.desc(), Notification.id.desc())
            .limit(limit)
            .offset(offset)
        )
    ).scalars().all()
    dil = istek_dili(accept_language)
    return NotificationListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_out(r, dil) for r in rows],
    )


@router.patch("/{notification_id}", response_model=NotificationOut)
async def update_notification(
    notification_id: uuid.UUID,
    body: NotificationUpdate,
    accept_language: str | None = Header(None, alias="Accept-Language"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_VIEWER),
) -> NotificationOut:
    # (P147) OKUMA KAPSAMI YAZMADA DA GECERLI. Once kapsamsiz
    # `get_or_404` vardi: sakin BASKASININ bildirimini — hatta bir yonetim
    # alarmini — okundu isaretleyebilirdi. Ayni `_kapsam` suzgeci
    # uygulaniyor; kapsam disi kayit icin 404 (varligi da sizmaz).
    obj = (
        await db.execute(
            select(Notification).where(
                Notification.id == notification_id, _kapsam(user)
            )
        )
    ).scalar_one_or_none()
    if obj is None:
        raise APIError(404, "not_found", "kayit_bulunamadi")
    obj.okundu = body.okundu
    await db.flush()
    await db.refresh(obj)
    return _out(obj, istek_dili(accept_language))
