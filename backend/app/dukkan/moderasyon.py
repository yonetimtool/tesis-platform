"""(DUKKAN F2) MODERASYON — onay kuyrugu, belge incelemesi, aski.

===========================================================================
NEDEN INSAN, NEDEN OTOMASYON DEGIL
===========================================================================
Sahte isletme (T3) urunun en ciddi guvenlik ve hukuk riski: kullanicinin
KAPISINA dolandirici gonderebilir. V1'de bunu otomatik ayiklayacak
guvenilir bir yol YOK — GIB'in tek gelistiricinin kullanabilecegi
ucretsiz resmi bir toplu dogrulama API'si bulundugundan emin degilim
(docs/dukkan/03-guven-ve-fraud.md §3).

Gunde 5-10 basvuruda insan incelemesi gunde birkac dakika ve bir insanin
gozu sahte belgeyi bugun herhangi bir otomasyondan iyi yakalar.
ONCE HACIM, SONRA OTOMASYON.

===========================================================================
HER KARAR GEREKCELI VE KAYITLI
===========================================================================
`denetim` tablosu APPEND-ONLY (goc 0115 + setup_dukkan_role.py): bir
moderasyon karari sonradan "hic verilmemis" hale getirilemez. Itiraz
sureci buna dayaniyor — kararin kendisi kadar NEDEN verildigi de
saklanmali, yoksa itirazi degerlendiren kisi (ki ayni kisi olabilir)
neye baktigini bilemez.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from .kimlik import DukkanKimlik, moderator_zorunlu
from .siralama import siralama_puani_hesapla
from .veritabani import get_dukkan_session

router = APIRouter(prefix="/dukkan/moderasyon", tags=["dukkan"])


class IsletmeKarar(BaseModel):
    # `karar` ve `gerekce` AYRI alanlar: gerekceyi karar metnine gommek
    # ("reddedildi: belge okunmuyor") sonradan makineyle ayirmayi
    # imkansiz kilardi ve itiraz raporlari elle okunmak zorunda kalirdi.
    karar: str = Field(pattern="^(onayla|reddet|askiya_al|askiyi_kaldir)$")
    gerekce: str | None = Field(default=None, max_length=2000)


class BelgeKarar(BaseModel):
    karar: str = Field(pattern="^(onayla|reddet)$")
    not_metni: str | None = Field(default=None, max_length=2000)


@router.get("/kuyruk")
async def kuyruk(
    durum: str = Query("onay_bekliyor"),
    limit: int = Query(50, ge=1, le=200),
    _mod: DukkanKimlik = Depends(moderator_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Moderasyon kuyrugu — TEK EKRAN.

    Doner: {"items": [...], "toplam": n}

    Her satir, karar vermek icin gereken HER SEYI tasir: kategoriler,
    hizmet alani sayisi, belge durumu, telefon dogrulanmis mi. Moderatorun
    her basvuru icin ayri bir sayfa acmasi gerekseydi, gunde 10 basvuru
    30 dakikaya cikar ve is yapilmaz hale gelirdi.
    """
    if durum not in ("onay_bekliyor", "onayli", "askida", "reddedildi", "taslak"):
        raise HTTPException(status_code=422, detail="durum_gecersiz")

    satirlar = (
        await db.execute(
            text(
                """
                SELECT i.id, i.ad, i.slug, i.telefon, i.telefon_dogrulandi_at,
                       i.vergi_no, i.durum, i.dogrulama_seviyesi, i.created_at,
                       i.red_sebebi, i.askiya_alma_sebebi,
                       k.telefon AS sahip_telefon, k.ad_soyad AS sahip_ad,
                       (SELECT count(*) FROM isletme_hizmet_alani ha
                         WHERE ha.isletme_id = i.id) AS hizmet_alani_sayisi,
                       (SELECT count(*) FROM isletme_belge b
                         WHERE b.isletme_id = i.id) AS belge_sayisi,
                       (SELECT count(*) FROM isletme_belge b
                         WHERE b.isletme_id = i.id AND b.durum = 'bekliyor')
                         AS bekleyen_belge,
                       -- Vergi levhasi ozellikle ayri sayiliyor: kullanicinin
                       -- istegi "admin panelinde 'vergi levhasi yuklendi mi'
                       -- alani olsun, inceleme izi kalsin".
                       (SELECT count(*) FROM isletme_belge b
                         WHERE b.isletme_id = i.id AND b.tip = 'vergi_levhasi')
                         AS vergi_levhasi_sayisi,
                       ARRAY(SELECT kt.ad FROM isletme_kategori ik
                              JOIN kategori kt ON kt.id = ik.kategori_id
                              WHERE ik.isletme_id = i.id ORDER BY kt.ad)
                         AS kategoriler
                FROM isletme i
                JOIN dukkan_kullanici k ON k.id = i.sahip_kullanici_id
                WHERE i.durum = :d
                ORDER BY i.created_at
                LIMIT :l
                """
            ),
            {"d": durum, "l": limit},
        )
    ).mappings().all()

    toplam = (
        await db.execute(
            text("SELECT count(*) FROM isletme WHERE durum = :d"), {"d": durum}
        )
    ).scalar_one()
    return {"items": [dict(x) for x in satirlar], "toplam": toplam}


@router.post("/isletme/{isletme_id}/karar")
async def isletme_karar(
    isletme_id: uuid.UUID,
    govde: IsletmeKarar,
    istek: Request,
    mod: DukkanKimlik = Depends(moderator_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Isletme hakkinda karar verir. Doner: {"durum", "dogrulama_seviyesi"}.

    RET VE ASKI ICIN GEREKCE ZORUNLU (422). Gerekcesiz bir ret,
    isletmeye ne duzeltecegini soylemez; itiraz sureci de degerlendirecek
    bir sey bulamaz.

    ONAYDA `dogrulama_seviyesi` en az 1 olur — ama telefon dogrulanmamissa
    onay REDDEDILIR (409). Seviye 0 aramada gorunmez oldugu icin, onayli
    ama seviye 0 bir isletme "onaylandi" gorunup HICBIR YERDE cikmazdi.
    """
    satir = (
        await db.execute(
            text("SELECT id, durum, dogrulama_seviyesi, telefon_dogrulandi_at "
                 "FROM isletme WHERE id = :i"),
            {"i": isletme_id},
        )
    ).mappings().first()
    if satir is None:
        raise HTTPException(status_code=404, detail="isletme_bulunamadi")

    if govde.karar in ("reddet", "askiya_al") and not (govde.gerekce or "").strip():
        raise HTTPException(status_code=422, detail="gerekce_zorunlu")

    if govde.karar == "onayla":
        if satir["telefon_dogrulandi_at"] is None:
            raise HTTPException(status_code=409, detail="telefon_dogrulanmamis")
        yeni_seviye = max(int(satir["dogrulama_seviyesi"]), 1)
        await db.execute(
            text("UPDATE isletme SET durum = 'onayli', onaylandi_at = now(), "
                 "dogrulama_seviyesi = :s, red_sebebi = NULL, "
                 "askiya_alma_sebebi = NULL, updated_at = now() WHERE id = :i"),
            {"i": isletme_id, "s": yeni_seviye},
        )
    elif govde.karar == "reddet":
        await db.execute(
            text("UPDATE isletme SET durum = 'reddedildi', red_sebebi = :g, "
                 "updated_at = now() WHERE id = :i"),
            {"i": isletme_id, "g": govde.gerekce},
        )
    elif govde.karar == "askiya_al":
        await db.execute(
            text("UPDATE isletme SET durum = 'askida', askiya_alma_sebebi = :g, "
                 "updated_at = now() WHERE id = :i"),
            {"i": isletme_id, "g": govde.gerekce},
        )
    else:  # askiyi_kaldir
        if satir["durum"] != "askida":
            raise HTTPException(status_code=409, detail="isletme_askida_degil")
        await db.execute(
            text("UPDATE isletme SET durum = 'onayli', askiya_alma_sebebi = NULL, "
                 "updated_at = now() WHERE id = :i"),
            {"i": isletme_id},
        )

    await db.execute(
        text("INSERT INTO denetim (aktor_id, aktor_tip, eylem, hedef_tip, "
             " hedef_id, gerekce, ip) "
             "VALUES (:a, 'moderator', :e, 'isletme', :h, :g, :ip)"),
        {
            "a": mod.kullanici_id, "e": f"moderasyon_{govde.karar}",
            "h": isletme_id, "g": govde.gerekce,
            "ip": istek.headers.get("x-forwarded-for", "").split(",")[0].strip()
                  or None,
        },
    )

    # PUAN YENIDEN HESAPLANIR: onay `dogrulama_seviyesi`ni ve
    # `onaylandi_at`i degistiriyor, ikisi de formulun girdisi. Hesabi
    # atlamak, yeni onaylanmis bir isletmenin puani 0 kalarak listenin
    # EN ALTINDA dogmasi demekti.
    await siralama_puani_hesapla(db, isletme_id)

    son = (
        await db.execute(
            text("SELECT durum, dogrulama_seviyesi FROM isletme WHERE id = :i"),
            {"i": isletme_id},
        )
    ).mappings().one()
    return dict(son)


@router.post("/belge/{belge_id}/karar")
async def belge_karar(
    belge_id: uuid.UUID,
    govde: BelgeKarar,
    istek: Request,
    mod: DukkanKimlik = Depends(moderator_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Belge incelemesi. Doner: {"durum", "dogrulama_seviyesi"}.

    ONAYLANAN BIR VERGI LEVHASI isletmeyi SEVIYE 2'ye ("Dogrulanmis
    isletme") tasir — ama YALNIZ isletme zaten `onayli` ve seviye >= 1
    ise. Askidaki ya da onaysiz bir isletmeye rozet vermek, rozeti
    anlamsiz kilardi.

    INCELEME IZI: `inceleyen_id` ve `incelendi_at` yaziliyor. Bir isletme
    sonradan sorun cikardiginda "biz bunu onaylarken neye baktik?"
    sorusunun cevabi olmali.
    """
    belge = (
        await db.execute(
            text("SELECT b.id, b.isletme_id, b.tip, b.durum, i.durum AS isl_durum, "
                 "       i.dogrulama_seviyesi "
                 "FROM isletme_belge b JOIN isletme i ON i.id = b.isletme_id "
                 "WHERE b.id = :b"),
            {"b": belge_id},
        )
    ).mappings().first()
    if belge is None:
        raise HTTPException(status_code=404, detail="belge_bulunamadi")

    yeni_durum = "onaylandi" if govde.karar == "onayla" else "reddedildi"
    if yeni_durum == "reddedildi" and not (govde.not_metni or "").strip():
        raise HTTPException(status_code=422, detail="gerekce_zorunlu")

    await db.execute(
        text("UPDATE isletme_belge SET durum = :d, inceleyen_id = :m, "
             "incelendi_at = now(), not_metni = :n WHERE id = :b"),
        {"d": yeni_durum, "m": mod.kullanici_id, "n": govde.not_metni,
         "b": belge_id},
    )

    seviye = int(belge["dogrulama_seviyesi"])
    if (
        yeni_durum == "onaylandi"
        and belge["tip"] == "vergi_levhasi"
        and belge["isl_durum"] == "onayli"
        and seviye >= 1
    ):
        seviye = max(seviye, 2)
        await db.execute(
            text("UPDATE isletme SET dogrulama_seviyesi = :s, updated_at = now() "
                 "WHERE id = :i"),
            {"s": seviye, "i": belge["isletme_id"]},
        )
        # Seviye degisti -> puan degisir.
        await siralama_puani_hesapla(db, belge["isletme_id"])

    await db.execute(
        text("INSERT INTO denetim (aktor_id, aktor_tip, eylem, hedef_tip, "
             " hedef_id, gerekce, ip) "
             "VALUES (:a, 'moderator', :e, 'belge', :h, :g, :ip)"),
        {"a": mod.kullanici_id, "e": f"belge_{govde.karar}", "h": belge_id,
         "g": govde.not_metni,
         "ip": istek.headers.get("x-forwarded-for", "").split(",")[0].strip()
               or None},
    )
    return {"durum": yeni_durum, "dogrulama_seviyesi": seviye}


@router.get("/isletme/{isletme_id}/denetim")
async def isletme_denetim(
    isletme_id: uuid.UUID,
    _mod: DukkanKimlik = Depends(moderator_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Bir isletmenin karar gecmisi. Doner: {"items": [...]}.

    Itiraz surecinin dayanagi: kim, ne zaman, hangi gerekceyle karar
    verdi. Tablo append-only oldugu icin bu liste GERIYE DONUK
    DEGISTIRILEMEZ.
    """
    satirlar = (
        await db.execute(
            text(
                "SELECT d.eylem, d.gerekce, d.created_at, k.telefon AS aktor "
                "FROM denetim d "
                "LEFT JOIN dukkan_kullanici k ON k.id = d.aktor_id "
                "WHERE (d.hedef_tip = 'isletme' AND d.hedef_id = :i) "
                "   OR (d.hedef_tip = 'belge' AND d.hedef_id IN "
                "       (SELECT id FROM isletme_belge WHERE isletme_id = :i)) "
                "ORDER BY d.created_at DESC LIMIT 200"
            ),
            {"i": isletme_id},
        )
    ).mappings().all()
    return {"items": [dict(x) for x in satirlar]}
