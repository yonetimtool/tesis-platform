"""(DUKKAN F6) BILDIRIM UCLARI — cihaz kaydi, liste, okundu."""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from .kimlik import DukkanKimlik, kimlik_zorunlu
from .veritabani import get_dukkan_session

router = APIRouter(prefix="/dukkan", tags=["dukkan"])


class CihazKaydi(BaseModel):
    fcm_token: str = Field(min_length=10, max_length=512)
    platform: str | None = Field(default=None, pattern="^(android|ios|web)$")
    dil: str = Field(default="tr", max_length=8)


@router.post("/cihaz")
async def cihaz_kaydet(
    govde: CihazKaydi,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Cihaz jetonunu kaydeder/tazeler. Doner: {"kayitli": true}.

    AYNI JETON BASKA KULLANICIDAYSA DEVRALINIR (`ON CONFLICT`): cihaz el
    degistirdiginde (ortak telefon, ikinci el) eski sahibin bildirimleri
    yeni kullaniciya DUSMEMELI. Jeton UNIQUE oldugu icin bu devralma
    veritabaninda garanti.
    """
    await db.execute(
        text(
            "INSERT INTO dukkan_cihaz (kullanici_id, fcm_token, platform, dil) "
            "VALUES (:k, :t, :p, :d) "
            "ON CONFLICT (fcm_token) DO UPDATE SET "
            "  kullanici_id = EXCLUDED.kullanici_id, "
            "  platform = EXCLUDED.platform, dil = EXCLUDED.dil, "
            "  son_gorulme = now()"
        ),
        {"k": kimlik.kullanici_id, "t": govde.fcm_token,
         "p": govde.platform, "d": govde.dil},
    )
    return {"kayitli": True}


@router.delete("/cihaz")
async def cihaz_sil(
    fcm_token: str = Query(..., min_length=10),
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Cihaz kaydini siler (cikis). Doner: {"silinen": n}.

    SAYI DONDURUYOR: sifir ise arayuz "cikis yapildi" derken bildirimlerin
    devam edecegini bilmeli (P217 dersi).
    """
    r = await db.execute(
        text("DELETE FROM dukkan_cihaz WHERE fcm_token = :t AND kullanici_id = :k"),
        {"t": fcm_token, "k": kimlik.kullanici_id},
    )
    return {"silinen": r.rowcount}


@router.get("/bildirim")
async def bildirimler(
    limit: int = Query(50, ge=1, le=200),
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Kullanicinin bildirimleri. Doner: {"items": [...], "okunmamis": n}.

    METIN DONMUYOR, `tip` + `veri` donuyor: istemci metni KENDI dilinde
    uretir. Sunucuda uretilmis bir metin, kullanici dilini degistirdiginde
    eski dilde kalirdi.
    """
    satirlar = (
        await db.execute(
            text("SELECT id, tip, veri, hedef_yol, gonderildi_at, okundu_at, "
                 "       created_at FROM bildirim "
                 "WHERE kullanici_id = :k ORDER BY created_at DESC LIMIT :l"),
            {"k": kimlik.kullanici_id, "l": limit},
        )
    ).mappings().all()
    okunmamis = (
        await db.execute(
            text("SELECT count(*) FROM bildirim WHERE kullanici_id = :k "
                 "AND okundu_at IS NULL"),
            {"k": kimlik.kullanici_id},
        )
    ).scalar_one()
    return {"items": [dict(x) for x in satirlar], "okunmamis": okunmamis}


@router.post("/bildirim/okundu")
async def okundu_isaretle(
    bildirim_id: uuid.UUID | None = Query(
        None, description="Verilmezse HEPSI okundu isaretlenir"),
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Bildirimi/bildirimleri okundu isaretler. Doner: {"okunan": n}."""
    if bildirim_id:
        r = await db.execute(
            text("UPDATE bildirim SET okundu_at = now() "
                 "WHERE id = :i AND kullanici_id = :k AND okundu_at IS NULL"),
            {"i": bildirim_id, "k": kimlik.kullanici_id},
        )
    else:
        r = await db.execute(
            text("UPDATE bildirim SET okundu_at = now() "
                 "WHERE kullanici_id = :k AND okundu_at IS NULL"),
            {"k": kimlik.kullanici_id},
        )
    return {"okunan": r.rowcount}
