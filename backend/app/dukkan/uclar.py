"""(DUKKAN F1) KAMU UCLARI — lokasyon agaci ve kategori.

===========================================================================
BU UCLAR NEDEN KIMLIKSIZ (security: [])
===========================================================================
Dukkan'in buyume kanali SEO. `/istanbul/cekmekoy/catalmese/elektrikci`
sayfasini hem arama motoru botu hem de hic uye olmamis bir ziyaretci
gorebilmeli. Lokasyon agaci ve kategori listesi KAMUYA ACIK veridir:
il/ilce/mahalle adlari zaten resmi ve herkese acik bilgi.

Kimlik istemek burada yalnizca SEO'yu oldururdu.

===========================================================================
YAZMA UCU YOK
===========================================================================
Bu dosyada yalnizca GET var. Lokasyon ve kategori verisi ELLE yuklenir
(`lokasyon_yukle.py`, `kategori_yukle.py`) ve HTTP uzerinden
degistirilemez. Sebep: bu iki tablo SEO yollarinin temeli; bir uctan
yanlislikla degistirilebilir olmalari, canli baglantilarin sessizce
olmesi demekti.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from .lokasyon_yukle import slugla
from .veritabani import get_dukkan_session

router = APIRouter(prefix="/dukkan", tags=["dukkan"])


@router.get("/lokasyon/il")
async def iller(db: AsyncSession = Depends(get_dukkan_session)) -> dict:
    """Turkiye'nin 81 ili — ad ve slug.

    Doner: {"items": [{"ad", "slug"}, ...]} — ada gore Turkce siralı.
    """
    satirlar = (
        await db.execute(
            text(
                "SELECT ad, slug FROM il "
                "ORDER BY ad COLLATE \"tr-TR-x-icu\""
            )
        )
    ).all()
    return {"items": [{"ad": a, "slug": s} for a, s in satirlar]}


@router.get("/lokasyon/il/{il_slug}/ilce")
async def ilceler(
    il_slug: str, db: AsyncSession = Depends(get_dukkan_session)
) -> dict:
    """Bir ilin ilceleri.

    Doner: {"il": {"ad","slug"}, "items": [{"ad","slug"}, ...]}
    Il bulunamazsa 404 — bos liste DEGIL. Bos liste, yanlis yazilmis bir
    il slug'ini "bu ilde hic ilce yok" gibi gosterir ve hatayi gizlerdi.
    """
    il = (
        await db.execute(
            text("SELECT id, ad, slug FROM il WHERE slug = :s"), {"s": il_slug}
        )
    ).first()
    if il is None:
        raise HTTPException(status_code=404, detail="il_bulunamadi")
    satirlar = (
        await db.execute(
            text(
                "SELECT ad, slug FROM ilce WHERE il_id = :i "
                "ORDER BY ad COLLATE \"tr-TR-x-icu\""
            ),
            {"i": il[0]},
        )
    ).all()
    return {
        "il": {"ad": il[1], "slug": il[2]},
        "items": [{"ad": a, "slug": s} for a, s in satirlar],
    }


@router.get("/lokasyon/il/{il_slug}/ilce/{ilce_slug}/mahalle")
async def mahalleler(
    il_slug: str,
    ilce_slug: str,
    q: str | None = Query(None, description="Ad icinde arama"),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Bir ilcenin mahalle/koyleri.

    Yol IL SLUG'INI DA ICERIR cunku ilce slug'i yalnizca IL ICINDE
    benzersizdir (`UNIQUE (il_id, slug)`): Turkiye'de birden cok ilde
    "Merkez" ilcesi var. Yalniz ilce slug'iyla sorulsaydi hangi ilin
    Merkez'i oldugu belirsiz kalirdi.

    Doner: {"ilce": {"ad","slug"}, "items": [{"ad","slug","tip"}, ...]}
    Bulunamazsa 404.
    """
    ilce = (
        await db.execute(
            text(
                "SELECT ic.id, ic.ad, ic.slug FROM ilce ic "
                "JOIN il i ON i.id = ic.il_id "
                "WHERE i.slug = :il AND ic.slug = :ic"
            ),
            {"il": il_slug, "ic": ilce_slug},
        )
    ).first()
    if ilce is None:
        raise HTTPException(status_code=404, detail="ilce_bulunamadi")

    # ARAMA TURKCE HARFSIZ DE CALISIR — olcerek eklendi.
    #
    # Ilk yazimda yalnizca `ad ILIKE` vardi ve akisi surerken su cikti:
    # "catal" yazan kullanici HICBIR SEY bulamiyordu, oysa "Çatalmeşe"
    # oradaydi. Turkce klavyesi olmayan ya da hizli yazan biri "cekmekoy",
    # "catal", "sisli" yazar. Mahalle aramasi hem sakinin kendi mahallesini
    # sectigi hem de USTANIN hizmet alani sectigi yer; bos sonuc donmesi
    # "burada mahalle yok" gibi okunur ve akis orada durur.
    #
    # Cozum BEDAVA: `slug` sutunu zaten ASCII'ye katlanmis halde duruyor
    # (SEO yolu icin uretilmisti). Ikinci bir "aranabilir ad" sutunu ya da
    # `unaccent` eklentisi GEREKMEDI.
    sql = (
        "SELECT ad, slug, tip FROM mahalle WHERE ilce_id = :i "
        "{filtre} ORDER BY ad COLLATE \"tr-TR-x-icu\" LIMIT 2000"
    )
    param: dict = {"i": ilce[0]}
    if q:
        sql = sql.format(filtre="AND (ad ILIKE :q OR slug LIKE :qs)")
        param["q"] = f"%{q}%"
        param["qs"] = f"%{slugla(q)}%"
    else:
        sql = sql.format(filtre="")
    satirlar = (await db.execute(text(sql), param)).all()
    return {
        "ilce": {"ad": ilce[1], "slug": ilce[2]},
        "items": [{"ad": a, "slug": s, "tip": t} for a, s, t in satirlar],
    }


@router.get("/kategori")
async def kategoriler(db: AsyncSession = Depends(get_dukkan_session)) -> dict:
    """Kategori agaci — iki seviye (ana > hizmet).

    Doner: {"items": [{"ad","slug","ikon","alt":[{"ad","slug"}, ...]}, ...]}
    Yalnizca `aktif` kategoriler. Sira `sira` sutununa gore.
    """
    satirlar = (
        await db.execute(
            text(
                "SELECT k.id, k.ad, k.slug, k.ikon, k.ust_id, k.sira "
                "FROM kategori k WHERE k.aktif ORDER BY k.sira, k.ad"
            )
        )
    ).all()
    analar: list[dict] = []
    indeks: dict = {}
    for kid, ad, slug, ikon, ust, _sira in satirlar:
        if ust is None:
            dugum = {"ad": ad, "slug": slug, "ikon": ikon, "alt": []}
            indeks[kid] = dugum
            analar.append(dugum)
    for kid, ad, slug, _ikon, ust, _sira in satirlar:
        if ust is not None and ust in indeks:
            indeks[ust]["alt"].append({"ad": ad, "slug": slug})
    return {"items": analar}
