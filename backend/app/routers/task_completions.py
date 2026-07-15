"""GET /task-completions — capraz-gorev tamamlama gecmisi — /contracts/openapi.yaml.

/tasks/{id}/completions tek gorev icindir; bu uc TUM gorevlerin tamamlanma
GECMISI icindir ("gecen hafta hangi gorevler tamamlandi, kim, hangi tip").
/patrol-windows ile BIREBIR ayni desen: tarih araligi + tip/task_id/tamamlayan
filtresi, DESC, sayfalama, response.ozet (filtrelenmis tum kume uzerinden).
Mevcut task_completion tablosu uzerinde okuma — yeni tablo yok. RBAC (kesin
matris, auth.md §4): gorev-YONETIMI goruntuleme — admin + yonetici + security
+ tesis_gorevlisi; resident 403. tenant-izole (RLS).
"""
from __future__ import annotations

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from ..deps import get_tenant_db, require_role
from ..models import AppUser
from ..schemas import (
    PageMetaOut,
    TaskCompletionHistoryListResponse,
    TaskCompletionHistoryOut,
    TaskCompletionKategoriSayi,
    TaskCompletionOzet,
)

router = APIRouter(prefix="/task-completions", tags=["tasks"])

_VIEWER = require_role("admin", "yonetici", "security", "tesis_gorevlisi")

# Gorev tipi = yonetici-tanimli kategori (NULL -> "Diğer"); sabit tip kaldirildi.
# {where} sabit kosul parcalarindan kurulur; degerler her zaman bound param.
_LIST_SQL = """
    SELECT tc.id, tc.task_id, t.ad AS task_adi,
           COALESCE(cat.ad, 'Diğer') AS kategori_ad,
           tc.tamamlayan_user_id, tc.tamamlanma_zamani,
           (tc.foto_key IS NOT NULL)    AS foto_var,
           (tc.nfc_tag_uid IS NOT NULL) AS nfc_dogrulandi,
           tc.notlar
    FROM task_completion tc
    JOIN task t ON t.id = tc.task_id
    LEFT JOIN task_category cat ON cat.id = t.kategori_id
    {where}
    ORDER BY tc.tamamlanma_zamani DESC
    LIMIT :limit OFFSET :offset
"""
_COUNT_SQL = "SELECT count(*) FROM task_completion tc JOIN task t ON t.id = tc.task_id {where}"
_OZET_SQL = (
    "SELECT COALESCE(cat.ad, 'Diğer') AS kategori_ad, count(*) AS n "
    "FROM task_completion tc JOIN task t ON t.id = tc.task_id "
    "LEFT JOIN task_category cat ON cat.id = t.kategori_id "
    "{where} GROUP BY COALESCE(cat.ad, 'Diğer') ORDER BY n DESC, kategori_ad"
)


@router.get("", response_model=TaskCompletionHistoryListResponse)
async def list_task_completions(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    baslangic: datetime | None = Query(None, description="tamamlanma_zamani >= bu an"),
    bitis: datetime | None = Query(None, description="tamamlanma_zamani < bu an (yari-acik)"),
    kategori_id: uuid.UUID | None = Query(None, description="kategori filtresi"),
    task_id: uuid.UUID | None = Query(None),
    tamamlayan_user_id: uuid.UUID | None = Query(None),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_VIEWER),
) -> TaskCompletionHistoryListResponse:
    conds: list[str] = []
    params: dict[str, object] = {}
    if baslangic is not None:
        conds.append("tc.tamamlanma_zamani >= :baslangic")
        params["baslangic"] = baslangic
    if bitis is not None:
        conds.append("tc.tamamlanma_zamani < :bitis")
        params["bitis"] = bitis
    if kategori_id is not None:
        conds.append("t.kategori_id = :kategori_id")
        params["kategori_id"] = kategori_id
    if task_id is not None:
        conds.append("tc.task_id = :task_id")
        params["task_id"] = task_id
    if tamamlayan_user_id is not None:
        conds.append("tc.tamamlayan_user_id = :tamamlayan")
        params["tamamlayan"] = tamamlayan_user_id
    where = ("WHERE " + " AND ".join(conds)) if conds else ""

    total = (
        await db.execute(text(_COUNT_SQL.format(where=where)), params)
    ).scalar_one()

    ozet_rows = (
        await db.execute(text(_OZET_SQL.format(where=where)), params)
    ).all()
    ozet = TaskCompletionOzet(
        toplam=int(total),
        kalemler=[
            TaskCompletionKategoriSayi(kategori_ad=r[0], sayi=int(r[1]))
            for r in ozet_rows
        ],
    )

    rows = (
        await db.execute(
            text(_LIST_SQL.format(where=where)),
            {**params, "limit": limit, "offset": offset},
        )
    ).mappings().all()
    items = [
        TaskCompletionHistoryOut(
            id=r["id"],
            task_id=r["task_id"],
            task_adi=r["task_adi"],
            kategori_ad=r["kategori_ad"],
            tamamlayan_user_id=r["tamamlayan_user_id"],
            tamamlanma_zamani=r["tamamlanma_zamani"],
            foto_var=bool(r["foto_var"]),
            nfc_dogrulandi=bool(r["nfc_dogrulandi"]),
            notlar=r["notlar"],
        )
        for r in rows
    ]

    return TaskCompletionHistoryListResponse(
        meta=PageMetaOut(limit=limit, offset=offset, total=int(total)),
        ozet=ozet,
        items=items,
    )
