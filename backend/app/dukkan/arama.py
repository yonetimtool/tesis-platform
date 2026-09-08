"""(DUKKAN F3) KAMU ARAMA + SEO SAYFA VERISI.

===========================================================================
GORUNURLUK KURALI TEK YERDE
===========================================================================
Bir isletme aramada ancak `durum='onayli' AND dogrulama_seviyesi >= 1`
ise cikar. Bu kosul BU DOSYADA TEK BIR SABITTE (`_GORUNUR`) ve her sorgu
onu kullanir.

Iki ayri yerde tekrarlansaydi biri bir gun unutulur ve onaysiz ya da
dogrulanmamis bir isletme aramaya SIZARDI — sahte isletme (T3) icin
aranan tam da bu.

===========================================================================
ESLESME HIZMET ALANINDAN, ADRESTEN DEGIL
===========================================================================
Bir usta Kadikoy'de oturup Atasehir'e gidebilir. Isletmenin ADRESINE gore
eslestirmek onu Atasehir aramalarindan dislardi. Eslesmenin tamami
`isletme_hizmet_alani` tablosu.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from .veritabani import get_dukkan_session

router = APIRouter(prefix="/dukkan", tags=["dukkan"])

#: ARAMADA GORUNME KOSULU — tek kaynak.
_GORUNUR = "i.durum = 'onayli' AND i.dogrulama_seviyesi >= 1"

#: Sayfa boyutu. 20: bir ekranda kaydirmadan gorulenden biraz fazla.
#: Daha buyugu ISR onbellek boyutunu ve ilk boyama suresini artirir;
#: daha kucugu kullaniciyi gereksiz sayfalamaya iter.
VARSAYILAN_BOYUT = 20
MAKS_BOYUT = 50


def _konum_kosulu(il, ilce, mahalle, param):
    """Konum suzgecini HIYERARSIK kurar. Doner: SQL kosulu ya da None."""
    if mahalle:
        if not (il and ilce):
            # Sessizce il/ilce'yi yok saymak, iki farkli ildeki ayni adli
            # mahalleyi BIRLESTIRIRDI (Turkiye'de onlarca "Merkez" var).
            raise HTTPException(status_code=422, detail="mahalle_icin_il_ilce_gerekli")
        param |= {"il": il, "ilce": ilce, "mahalle": mahalle}
        return (
            "EXISTS (SELECT 1 FROM isletme_hizmet_alani ha "
            " JOIN mahalle m ON m.id = ha.mahalle_id "
            " JOIN ilce ic ON ic.id = m.ilce_id JOIN il l ON l.id = ic.il_id "
            " WHERE ha.isletme_id = i.id AND l.slug = :il "
            "   AND ic.slug = :ilce AND m.slug = :mahalle)"
        )
    if ilce:
        if not il:
            raise HTTPException(status_code=422, detail="ilce_icin_il_gerekli")
        param |= {"il": il, "ilce": ilce}
        return (
            "EXISTS (SELECT 1 FROM isletme_hizmet_alani ha "
            " JOIN mahalle m ON m.id = ha.mahalle_id "
            " JOIN ilce ic ON ic.id = m.ilce_id JOIN il l ON l.id = ic.il_id "
            " WHERE ha.isletme_id = i.id AND l.slug = :il AND ic.slug = :ilce)"
        )
    if il:
        param |= {"il": il}
        return (
            "EXISTS (SELECT 1 FROM isletme_hizmet_alani ha "
            " JOIN mahalle m ON m.id = ha.mahalle_id "
            " JOIN ilce ic ON ic.id = m.ilce_id JOIN il l ON l.id = ic.il_id "
            " WHERE ha.isletme_id = i.id AND l.slug = :il)"
        )
    return None


@router.get("/isletme-ara")
async def isletme_ara(
    il: str | None = Query(None, description="il slug"),
    ilce: str | None = Query(None),
    mahalle: str | None = Query(None),
    kategori: str | None = Query(None, description="hizmet kategorisi slug"),
    q: str | None = Query(None, description="isletme adinda arama"),
    sirala: str = Query("puan", pattern="^(puan|yeni|ad)$"),
    sayfa: int = Query(1, ge=1, le=500),
    boyut: int = Query(VARSAYILAN_BOYUT, ge=1, le=MAKS_BOYUT),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Isletme aramasi — KIMLIKSIZ.

    Doner: {"items": [...], "toplam": n, "sayfa": n, "boyut": n}
    """
    param: dict = {}
    kosullar = [_GORUNUR]
    konum = _konum_kosulu(il, ilce, mahalle, param)
    if konum:
        kosullar.append(konum)

    if kategori:
        kosullar.append(
            "EXISTS (SELECT 1 FROM isletme_kategori ik "
            " JOIN kategori k ON k.id = ik.kategori_id "
            " WHERE ik.isletme_id = i.id AND k.slug = :kategori "
            "   AND k.ust_id IS NOT NULL)"
        )
        param["kategori"] = kategori

    if q:
        # `slug` uzerinden de bakiliyor: Turkce klavyesi olmayan kullanici
        # "cilingir" yazip "Çilingir Ali"yi bulabilmeli. Ayni gerekce
        # mahalle aramasinda da yazili (uclar.py) ve orada AKISI SURERKEN
        # olculmustu.
        from .lokasyon_yukle import slugla

        kosullar.append("(i.ad ILIKE :q OR i.slug LIKE :qs)")
        param |= {"q": f"%{q}%", "qs": f"%{slugla(q)}%"}

    nere = " AND ".join(kosullar)
    toplam = (
        await db.execute(text(f"SELECT count(*) FROM isletme i WHERE {nere}"), param)
    ).scalar_one()

    # Ikincil anahtar HER ZAMAN `i.id`: esit puanlarda PostgreSQL sirayi
    # GARANTI ETMEZ ve sayfa 2'de ayni isletme tekrar cikabilir ya da
    # biri hic gorunmeyebilir.
    sira = {
        "puan": "i.siralama_puani DESC, i.id",
        "yeni": "i.onaylandi_at DESC NULLS LAST, i.id",
        "ad": 'i.ad COLLATE "tr-TR-x-icu", i.id',
    }[sirala]

    satirlar = (
        await db.execute(
            text(
                f"""
                SELECT i.ad, i.slug, i.aciklama, i.telefon, i.whatsapp,
                       i.dogrulama_seviyesi, i.ortalama_puan, i.yorum_sayisi,
                       ARRAY(SELECT k.ad FROM isletme_kategori ik
                              JOIN kategori k ON k.id = ik.kategori_id
                              WHERE ik.isletme_id = i.id ORDER BY k.ad)
                         AS kategoriler
                FROM isletme i WHERE {nere}
                ORDER BY {sira} LIMIT :__l OFFSET :__o
                """
            ),
            param | {"__l": boyut, "__o": (sayfa - 1) * boyut},
        )
    ).mappings().all()

    # ==================================================================
    # (F8b) SPONSORLU BLOK — AYRI ANAHTAR, AYRI SORGU
    # ==================================================================
    # `items` icine karistirilmiyor ve bu KASITLI:
    #
    #   * Karistirmak, kullanicinin "en iyi sonuc" sandigi seyi satmak
    #     olurdu. O an organik listenin degeri duser — ve satilan sey tam
    #     olarak "degerli bir listenin ustunde olmak".
    #   * Ayri anahtar, istemcinin rozeti UNUTMASINI zorlastiriyor:
    #     sponsorlu sonuclar tek bir yerden gelir ve orada "Sponsorlu"
    #     etiketi zorunlu.
    #   * Sunucudaki `siralama_puani` bu sorgudan HABERSIZ kalir
    #     (`test_dukkan_reklam.py` bunu olcuyor).
    #
    # SPONSORLU ISLETME ORGANIK LISTEDE DE CIKAR (hak ettigi sirada).
    # Organikten cikarmak, paranin siraya karismasinin tersten haliydi.
    #
    # YALNIZ ILK SAYFADA: ikinci sayfaya inen kullanici zaten aramasini
    # surduruyor; oraya da reklam koymak, listeyi reklamla kesmek olurdu.
    from .reklam import sponsorlu_isletmeler

    sponsorlu = (
        await sponsorlu_isletmeler(
            db, kategori_slug=kategori, il=il, ilce=ilce, mahalle=mahalle)
        if sayfa == 1 else []
    )

    return {
        "items": [dict(x) for x in satirlar],
        "sponsorlu": sponsorlu,
        "toplam": toplam, "sayfa": sayfa, "boyut": boyut,
    }


@router.get("/isletme-profil/{slug}")
async def isletme_profil(
    slug: str, db: AsyncSession = Depends(get_dukkan_session)
) -> dict:
    """Kamuya acik isletme profili. Doner: profil + kategoriler + bolgeler.

    SAHIBIN gordugu detaydan (`/dukkan/isletme/{id}`) AYRI VE DAR: burada
    `vergi_no`, `red_sebebi`, `askiya_alma_sebebi` YOK. Tek uc kullanip
    alan gizlemeye calismak, bir gun eklenen bir alani gizlemeyi unutmak
    demekti.

    Gorunmeyen isletme 404 — 403 DEGIL: "bu isletme var ama askida"
    bilgisi kamuya acik olmamali.
    """
    satir = (
        await db.execute(
            text(
                f"""
                SELECT i.id, i.ad, i.slug, i.aciklama, i.telefon, i.whatsapp,
                       i.eposta, i.dogrulama_seviyesi, i.ortalama_puan,
                       i.yorum_sayisi, i.onaylandi_at,
                       m.ad AS mahalle, ic.ad AS ilce, l.ad AS il
                FROM isletme i
                LEFT JOIN mahalle m ON m.id = i.adres_mahalle_id
                LEFT JOIN ilce ic ON ic.id = m.ilce_id
                LEFT JOIN il l ON l.id = ic.il_id
                WHERE i.slug = :s AND {_GORUNUR}
                """
            ),
            {"s": slug},
        )
    ).mappings().first()
    if satir is None:
        raise HTTPException(status_code=404, detail="isletme_bulunamadi")

    kategoriler = [dict(x) for x in (
        await db.execute(
            text("SELECT k.ad, k.slug FROM isletme_kategori ik "
                 "JOIN kategori k ON k.id = ik.kategori_id "
                 "WHERE ik.isletme_id = :i ORDER BY k.ad"),
            {"i": satir["id"]},
        )).mappings().all()]

    # HIZMET BOLGELERI OZETLENIYOR: 40 mahalle secen bir isletmenin
    # profilinde 40 satir sayfayi bogar. Ilce duzeyinde gruplayip mahalle
    # SAYISINI veriyoruz.
    bolgeler = [dict(x) for x in (
        await db.execute(
            text("SELECT l.ad AS il, ic.ad AS ilce, count(*) AS mahalle_sayisi "
                 "FROM isletme_hizmet_alani ha "
                 "JOIN mahalle m ON m.id = ha.mahalle_id "
                 "JOIN ilce ic ON ic.id = m.ilce_id "
                 "JOIN il l ON l.id = ic.il_id WHERE ha.isletme_id = :i "
                 "GROUP BY l.ad, ic.ad ORDER BY l.ad, ic.ad"),
            {"i": satir["id"]},
        )).mappings().all()]

    saatler = [dict(x) for x in (
        await db.execute(
            text("SELECT gun, acilis, kapanis, kapali "
                 "FROM isletme_calisma_saati WHERE isletme_id = :i ORDER BY gun"),
            {"i": satir["id"]},
        )).mappings().all()]

    d = dict(satir)
    d.pop("id", None)   # Kamu profilinde ic kimlik GEREKMEZ.
    d["kategoriler"] = kategoriler
    d["hizmet_bolgeleri"] = bolgeler
    d["calisma_saatleri"] = saatler
    return d


@router.get("/sayfa/{il}/{ilce}/{mahalle}/{kategori}")
async def seo_sayfa(
    il: str, ilce: str, mahalle: str, kategori: str,
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """SEO bolge/kategori sayfasinin TUM verisi — tek istekte.

    Doner: {"konum", "kategori", "isletmeler", "toplam",
            "komsu_mahalleler", "diger_kategoriler"}

    SIFIR ISLETMEDE 404. Bos bir "yakinda" sayfasi INCE ICERIKTIR ve ceza
    sayfa basina degil ALAN ADI GENELINE isler (05-seo.md §3).

    ESIK KARARI ISTEMCIDE: burada yalniz SAYI donuyor; `noindex` karari
    `apps/dukkan-web/config/site.ts`teki `INCE_ICERIK_ESIGI` ile veriliyor
    — esik ayarlanabilir olmali ve TEK YERDE durmali.
    """
    konum = (
        await db.execute(
            text("SELECT l.ad AS il, l.slug AS il_slug, ic.ad AS ilce, "
                 "  ic.slug AS ilce_slug, m.ad AS mahalle, m.slug AS mahalle_slug, "
                 "  m.id AS mahalle_id, ic.id AS ilce_id "
                 "FROM mahalle m JOIN ilce ic ON ic.id = m.ilce_id "
                 "JOIN il l ON l.id = ic.il_id "
                 "WHERE l.slug = :il AND ic.slug = :ilce AND m.slug = :m"),
            {"il": il, "ilce": ilce, "m": mahalle},
        )
    ).mappings().first()
    if konum is None:
        raise HTTPException(status_code=404, detail="konum_bulunamadi")

    kat = (
        await db.execute(
            text("SELECT id, ad, slug, aciklama FROM kategori "
                 "WHERE slug = :s AND aktif AND ust_id IS NOT NULL"),
            {"s": kategori},
        )
    ).mappings().first()
    if kat is None:
        raise HTTPException(status_code=404, detail="kategori_bulunamadi")

    satirlar = (
        await db.execute(
            text(
                f"""
                SELECT i.ad, i.slug, i.aciklama, i.telefon, i.whatsapp,
                       i.dogrulama_seviyesi, i.ortalama_puan, i.yorum_sayisi
                FROM isletme i
                WHERE {_GORUNUR}
                  AND EXISTS (SELECT 1 FROM isletme_hizmet_alani ha
                               WHERE ha.isletme_id = i.id AND ha.mahalle_id = :mid)
                  AND EXISTS (SELECT 1 FROM isletme_kategori ik
                               WHERE ik.isletme_id = i.id AND ik.kategori_id = :kid)
                ORDER BY i.siralama_puani DESC, i.id LIMIT 50
                """
            ),
            {"mid": konum["mahalle_id"], "kid": kat["id"]},
        )
    ).mappings().all()

    if not satirlar:
        # 404 DOGRU CEVAP. Frontend 404 sayfasi bir UST seviyeyi (ilce) ve
        # "bu bolgede isletme misin?" cagrisini gosteriyor — arz tarafi
        # icin gercek bir kanal.
        raise HTTPException(status_code=404, detail="bu_bolgede_isletme_yok")

    # IC BAGLANTI: yalniz GERCEKTEN isletmesi olan komsular. Bos sayfaya
    # baglanti vermek, arama motoruna var olmayan sayfalarin haritasini
    # cizmek olurdu.
    komsular = [dict(x) for x in (
        await db.execute(
            text(f"""
                SELECT m.ad, m.slug, count(DISTINCT i.id) AS isletme_sayisi
                FROM mahalle m
                JOIN isletme_hizmet_alani ha ON ha.mahalle_id = m.id
                JOIN isletme i ON i.id = ha.isletme_id
                JOIN isletme_kategori ik ON ik.isletme_id = i.id
                WHERE m.ilce_id = :ilce_id AND m.id <> :mid
                  AND ik.kategori_id = :kid AND {_GORUNUR}
                GROUP BY m.ad, m.slug
                ORDER BY count(DISTINCT i.id) DESC, m.ad LIMIT 12
            """),
            {"ilce_id": konum["ilce_id"], "mid": konum["mahalle_id"],
             "kid": kat["id"]},
        )).mappings().all()]

    diger_kat = [dict(x) for x in (
        await db.execute(
            text(f"""
                SELECT k.ad, k.slug, count(DISTINCT i.id) AS isletme_sayisi
                FROM kategori k
                JOIN isletme_kategori ik ON ik.kategori_id = k.id
                JOIN isletme i ON i.id = ik.isletme_id
                JOIN isletme_hizmet_alani ha ON ha.isletme_id = i.id
                WHERE ha.mahalle_id = :mid AND k.id <> :kid
                  AND k.ust_id IS NOT NULL AND {_GORUNUR}
                GROUP BY k.ad, k.slug
                ORDER BY count(DISTINCT i.id) DESC, k.ad LIMIT 12
            """),
            {"mid": konum["mahalle_id"], "kid": kat["id"]},
        )).mappings().all()]

    return {
        "konum": {k: v for k, v in konum.items() if not k.endswith("_id")},
        "kategori": {"ad": kat["ad"], "slug": kat["slug"],
                     "aciklama": kat["aciklama"]},
        "isletmeler": [dict(x) for x in satirlar],
        "toplam": len(satirlar),
        "komsu_mahalleler": komsular,
        "diger_kategoriler": diger_kat,
    }


@router.get("/sitemap/sayfalar")
async def sitemap_sayfalar(
    esik: int = Query(3, ge=1, le=50),
    limit: int = Query(50000, ge=1, le=50000),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Sitemap'e girecek bolge/kategori yollari. Doner: {"items": [...]}.

    YALNIZ ESIGI GECENLER. Esik ISTEMCIDEN geliyor cunku deger
    `apps/dukkan-web/config/site.ts`te ve orada ayarlanabilir olmali —
    iki yerde tutmak, birinin bir gun otekinden ayrismasi demekti.

    Bu uc olmadan sitemap elle yazilmak zorunda kalirdi; `tanitim-web`in
    yedi yolluk sabit dizisi burada iSE YARAMAZ cunku Dukkan'da sayfalar
    isletme sayisina gore DOGAR VE OLUR.
    """
    satirlar = (
        await db.execute(
            text(f"""
                SELECT l.slug AS il, ic.slug AS ilce, m.slug AS mahalle,
                       k.slug AS kategori, count(DISTINCT i.id) AS sayi
                FROM isletme i
                JOIN isletme_hizmet_alani ha ON ha.isletme_id = i.id
                JOIN mahalle m ON m.id = ha.mahalle_id
                JOIN ilce ic ON ic.id = m.ilce_id
                JOIN il l ON l.id = ic.il_id
                JOIN isletme_kategori ik ON ik.isletme_id = i.id
                JOIN kategori k ON k.id = ik.kategori_id
                WHERE {_GORUNUR} AND k.ust_id IS NOT NULL
                GROUP BY l.slug, ic.slug, m.slug, k.slug
                HAVING count(DISTINCT i.id) >= :esik
                ORDER BY count(DISTINCT i.id) DESC
                LIMIT :limit
            """),
            {"esik": esik, "limit": limit},
        )
    ).mappings().all()
    return {"items": [dict(x) for x in satirlar], "esik": esik}
