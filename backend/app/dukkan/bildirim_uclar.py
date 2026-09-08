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


# --------------------------------------------------------------------------- #
# TERCIH — DUKKAN'IN KENDI ANAHTARI
# --------------------------------------------------------------------------- #
# Yonetiyor'un `/me/bildirim-tercihleri` ucundan AYRI, cunku:
#   (1) Dukkan kullanicisinin Yonetiyor hesabi olmayabilir (bagimsiz
#       telefon kaydi) — o ucu cagiramaz;
#   (2) iki urunun bildirimleri farkli seyler. Tek anahtar olsaydi, pazar
#       yeri pinglerinden bunalan sakin SITESININ duyurularini da
#       susturmak zorunda kalirdi.
# Goc 0121'in modul basligindaki gerekce ile ayni.
class Tercih(BaseModel):
    bildirim_acik: bool | None = None
    bildirim_sesli: bool | None = None


@router.get("/bildirim-tercihi")
async def tercih_oku(
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Doner: {"bildirim_acik": bool, "bildirim_sesli": bool}."""
    r = (
        await db.execute(
            text("SELECT bildirim_acik, bildirim_sesli FROM dukkan_kullanici "
                 "WHERE id = :i"),
            {"i": kimlik.kullanici_id},
        )
    ).mappings().first()
    if r is None:
        raise HTTPException(status_code=404, detail="kullanici_yok")
    return dict(r)


@router.patch("/bildirim-tercihi")
async def tercih_yaz(
    govde: Tercih,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Tercihi gunceller. Doner: GUNCEL SATIR (istemci ne yazdigini degil,
    sunucuda NE OLDUGUNU gorsun — P217'de "Kaydedildi" yazip hicbir sey
    yazmayan akis bu yuzden fark edilmemisti).

    Bos govde 400: "hicbir alan verilmedi" ile "hepsi ayni kaldi" ayni
    yanit olsaydi, istemci hatasini kimse gormezdi.
    """
    alanlar = govde.model_dump(exclude_none=True)
    if not alanlar:
        raise HTTPException(status_code=400, detail="alan_yok")
    set_ifadesi = ", ".join(f"{k} = :{k}" for k in alanlar)
    await db.execute(
        text(f"UPDATE dukkan_kullanici SET {set_ifadesi} WHERE id = :i"),
        {**alanlar, "i": kimlik.kullanici_id},
    )
    return await tercih_oku(kimlik=kimlik, db=db)
