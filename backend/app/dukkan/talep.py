"""(DUKKAN F4) TALEP + TEKLIF + IS — KVKK'nin gobegi.

===========================================================================
GORUNURLUK KURALI TEK FONKSIYONDA
===========================================================================
`_talep_gorunumu()` bir talebi CAGIRANA GORE sekillendiren TEK yerdir.
Her uc oradan gecer.

Iki ayri yerde yazilsaydi biri bir gun unutulur ve acik adres sizardi.
Arayuzde gizlemek de YETMEZ: ikinci istemci (mobil) o gizlemeyi tasimaz —
kural SUNUCUDA olmak zorunda.

===========================================================================
`acik_adres` ANAHTAR OLARAK HEP VAR, DEGERI `null`
===========================================================================
Alani tamamen cikarmak, istemciyi "alan yok mu, izin mi yok?" ayrimini
yapmak zorunda birakirdi. Anahtar hep var; dolu olup olmamasi izne bagli.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from .bildirim import bildir
from .isletme import _denetim, _sahiplik_dogrula
from .kimlik import DukkanKimlik, kimlik_zorunlu
from .veritabani import get_dukkan_session

router = APIRouter(prefix="/dukkan", tags=["dukkan"])

#: Kurus ust siniri — 10 milyon TL. Yonetiyor'daki `KURUS_UST_SINIR`
#: karariyla ayni gerekce (P211): sinirsiz birakmak, bir hane fazla
#: yazan kullanicinin uydurma bir rakami kaydetmesi demek.
KURUS_UST_SINIR = 1_000_000_000


class TalepOlustur(BaseModel):
    kategori_slug: str
    il_slug: str
    ilce_slug: str
    mahalle_slug: str
    aciklama: str = Field(min_length=10, max_length=4000)
    baslik: str | None = Field(default=None, max_length=160)
    butce_min_kurus: int | None = Field(default=None, ge=0, le=KURUS_UST_SINIR)
    butce_max_kurus: int | None = Field(default=None, ge=0, le=KURUS_UST_SINIR)
    # ================================================================= #
    # KVKK PAYLASIM TERCIHLERI — UCU DE VARSAYILAN `False`
    # ================================================================= #
    # Kullanici formu dikkatsiz doldurdugunda olan sey "veri paylasilmadi"
    # olmali, "veri paylasildi" degil. Guvenli yon secimi.
    paylas_ad: bool = False
    paylas_telefon: bool = False
    paylas_adres: bool = False
    acik_adres: str | None = Field(default=None, max_length=500)
    tesis_id_beyan: uuid.UUID | None = None


class TeklifVer(BaseModel):
    tutar_kurus: int | None = Field(default=None, ge=0, le=KURUS_UST_SINIR)
    mesaj: str | None = Field(default=None, max_length=2000)


async def _talep_gorunumu(
    db: AsyncSession,
    talep_id: uuid.UUID,
    *,
    kullanici_id: uuid.UUID,
    isletme_id: uuid.UUID | None = None,
) -> dict:
    """Talebi CAGIRANA GORE sekillendirir. Doner: talep gorunumu (dict).

    Uc rol:
      * TALEP SAHIBI            -> her sey gorunur
      * KABUL EDILEN ISLETME    -> acik adres + telefon ACIK
      * TEKLIF VEREBILIR ISLETME-> yalniz mahalle (+ kullanici izin verdikleri)
      * BASKASI                 -> 403

    `acik_adres` ANAHTARI HER ZAMAN DONER; degeri izne bagli.
    """
    t = (
        await db.execute(
            text(
                """
                SELECT t.*, k.ad AS kategori_ad, k.slug AS kategori_slug,
                       m.ad AS mahalle, ic.ad AS ilce, l.ad AS il,
                       m.slug AS mahalle_slug, ic.slug AS ilce_slug,
                       l.slug AS il_slug,
                       ku.ad_soyad AS sahip_ad, ku.telefon AS sahip_telefon,
                       (SELECT count(*) FROM teklif tk
                         WHERE tk.talep_id = t.id
                           AND tk.durum = 'gonderildi') AS teklif_sayisi,
                       (SELECT ik.id FROM is_kaydi ik WHERE ik.talep_id = t.id) AS is_id,
                       (SELECT ik.isletme_id FROM is_kaydi ik WHERE ik.talep_id = t.id)
                         AS is_isletme_id
                FROM talep t
                JOIN kategori k ON k.id = t.kategori_id
                JOIN mahalle m ON m.id = t.mahalle_id
                JOIN ilce ic ON ic.id = m.ilce_id
                JOIN il l ON l.id = ic.il_id
                JOIN dukkan_kullanici ku ON ku.id = t.kullanici_id
                WHERE t.id = :i
                """
            ),
            {"i": talep_id},
        )
    ).mappings().first()
    if t is None:
        raise HTTPException(status_code=404, detail="talep_bulunamadi")

    sahip = t["kullanici_id"] == kullanici_id
    kabul_edilen = isletme_id is not None and t["is_isletme_id"] == isletme_id

    if not sahip and isletme_id is None:
        # Ne sahibi ne bir isletme -> talep BASKASININ.
        raise HTTPException(status_code=403, detail="talep_size_ait_degil")

    if not sahip and not kabul_edilen:
        # TEKLIF ASAMASI: isletmenin bu talebi gorme hakki, hizmet
        # alani + kategori eslesmesine baglidir. Eslesmiyorsa 403 —
        # aksi halde her isletme HER talebi okuyabilir ve bu, talep
        # hasadinin (T6) ta kendisi olurdu.
        uygun = (
            await db.execute(
                text(
                    "SELECT 1 FROM isletme_hizmet_alani ha "
                    "JOIN isletme_kategori ik ON ik.isletme_id = ha.isletme_id "
                    "WHERE ha.isletme_id = :isl AND ha.mahalle_id = :m "
                    "  AND ik.kategori_id = :k"
                ),
                {"isl": isletme_id, "m": t["mahalle_id"], "k": t["kategori_id"]},
            )
        ).first()
        if uygun is None:
            raise HTTPException(status_code=403, detail="talep_bolgenizde_degil")

    d = {
        "id": str(t["id"]),
        "baslik": t["baslik"],
        "aciklama": t["aciklama"],
        "kategori": {"ad": t["kategori_ad"], "slug": t["kategori_slug"]},
        "mahalle": {"ad": t["mahalle"], "slug": t["mahalle_slug"],
                    "ilce": t["ilce"], "ilce_slug": t["ilce_slug"],
                    "il": t["il"], "il_slug": t["il_slug"]},
        "butce_min_kurus": t["butce_min_kurus"],
        "butce_max_kurus": t["butce_max_kurus"],
        "durum": t["durum"],
        "teklif_sayisi": t["teklif_sayisi"],
        "created_at": t["created_at"],
        # ANAHTARLAR HER ZAMAN VAR — degerleri izne/asamaya bagli.
        "ad": None,
        "telefon": None,
        "acik_adres": None,
    }

    if sahip:
        d |= {
            "ad": t["sahip_ad"], "telefon": t["sahip_telefon"],
            "acik_adres": t["acik_adres"],
            "paylas_ad": t["paylas_ad"], "paylas_telefon": t["paylas_telefon"],
            "paylas_adres": t["paylas_adres"],
            "is_id": str(t["is_id"]) if t["is_id"] else None,
        }
        return d

    # --- ISLETME GORUNUMU --- #
    if t["paylas_ad"]:
        d["ad"] = t["sahip_ad"]
    if t["paylas_telefon"]:
        d["telefon"] = t["sahip_telefon"]

    if kabul_edilen:
        # IS KABUL EDILDI: acik adres ve telefon ACILIR.
        #
        # Telefon burada `paylas_telefon`dan BAGIMSIZ aciliyor: is kabul
        # edilmis, yani kullanici o isletmeyi SECMIS ve ustanin gelmesi
        # icin ulasabilmesi gerekiyor. Adres de ayni gerekceyle.
        d["telefon"] = t["sahip_telefon"]
        d["acik_adres"] = t["acik_adres"]
        d["is_id"] = str(t["is_id"])
    return d


@router.post("/talep", status_code=201)
async def talep_olustur(
    govde: TalepOlustur,
    istek: Request,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Yeni hizmet talebi. Doner: {"id", "durum", "eslesen_isletme"}.

    `eslesen_isletme` SAYIYI doner ve bu bilincli: kullanici talebinin
    KIMSEYE ulasmadigini ANINDA gormeli. Sessizce 0 isletmeye giden bir
    talep, kullaniciyi bos yere bekletirdi (P217'de olculen sinif).
    """
    if (govde.butce_min_kurus is not None and govde.butce_max_kurus is not None
            and govde.butce_min_kurus > govde.butce_max_kurus):
        raise HTTPException(status_code=422, detail="butce_araligi_gecersiz")

    kat = (
        await db.execute(
            text("SELECT id FROM kategori WHERE slug = :s AND aktif "
                 "AND ust_id IS NOT NULL"),
            {"s": govde.kategori_slug},
        )
    ).first()
    if kat is None:
        raise HTTPException(status_code=422, detail="kategori_bulunamadi")

    mah = (
        await db.execute(
            text("SELECT m.id FROM mahalle m "
                 "JOIN ilce ic ON ic.id = m.ilce_id JOIN il l ON l.id = ic.il_id "
                 "WHERE l.slug = :il AND ic.slug = :ilce AND m.slug = :m"),
            {"il": govde.il_slug, "ilce": govde.ilce_slug,
             "m": govde.mahalle_slug},
        )
    ).first()
    if mah is None:
        raise HTTPException(status_code=422, detail="mahalle_bulunamadi")

    # ADRES PAYLASILMAYACAKSA SAKLANMAZ.
    #
    # "Nasilsa gostermeyiz" diye saklamak, KVKK'nin veri minimizasyonu
    # ilkesine aykiri ve gereksiz bir sizinti yuzeyi. Kullanici izin
    # vermediyse veri HIC GIRMEZ.
    acik_adres = govde.acik_adres if govde.paylas_adres else None

    yeni = (
        await db.execute(
            text(
                "INSERT INTO talep (kullanici_id, kategori_id, mahalle_id, "
                " baslik, aciklama, butce_min_kurus, butce_max_kurus, "
                " paylas_ad, paylas_telefon, paylas_adres, acik_adres, "
                " tesis_id_beyan) "
                "VALUES (:k, :kat, :m, :b, :a, :bmin, :bmax, :pa, :pt, :pad, "
                "        :adres, :tesis) "
                "RETURNING id, durum"
            ),
            {
                "k": kimlik.kullanici_id, "kat": kat[0], "m": mah[0],
                "b": govde.baslik, "a": govde.aciklama,
                "bmin": govde.butce_min_kurus, "bmax": govde.butce_max_kurus,
                "pa": govde.paylas_ad, "pt": govde.paylas_telefon,
                "pad": govde.paylas_adres, "adres": acik_adres,
                "tesis": govde.tesis_id_beyan,
            },
        )
    ).mappings().one()

    eslesen = (
        await db.execute(
            text(
                "SELECT count(DISTINCT i.id) FROM isletme i "
                "JOIN isletme_hizmet_alani ha ON ha.isletme_id = i.id "
                "JOIN isletme_kategori ik ON ik.isletme_id = i.id "
                "WHERE ha.mahalle_id = :m AND ik.kategori_id = :k "
                "  AND i.durum = 'onayli' AND i.dogrulama_seviyesi >= 1"
            ),
            {"m": mah[0], "k": kat[0]},
        )
    ).scalar_one()

    await _denetim(db, aktor_id=kimlik.kullanici_id, eylem="talep_olustur",
                   hedef_tip="talep", hedef_id=yeni["id"], istek=istek)
    return {"id": str(yeni["id"]), "durum": yeni["durum"],
            "eslesen_isletme": eslesen}


@router.get("/talep")
async def taleplerim(
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Kullanicinin KENDI talepleri. Doner: {"items": [...]}."""
    satirlar = (
        await db.execute(
            text(
                "SELECT t.id, t.baslik, t.aciklama, t.durum, t.created_at, "
                "       k.ad AS kategori, m.ad AS mahalle, ic.ad AS ilce, "
                "       (SELECT count(*) FROM teklif tk WHERE tk.talep_id = t.id "
                "         AND tk.durum = 'gonderildi') AS teklif_sayisi "
                "FROM talep t JOIN kategori k ON k.id = t.kategori_id "
                "JOIN mahalle m ON m.id = t.mahalle_id "
                "JOIN ilce ic ON ic.id = m.ilce_id "
                "WHERE t.kullanici_id = :k ORDER BY t.created_at DESC"
            ),
            {"k": kimlik.kullanici_id},
        )
    ).mappings().all()
    return {"items": [dict(x) for x in satirlar]}


@router.get("/talep/{talep_id}")
async def talep_detay(
    talep_id: uuid.UUID,
    isletme_id: uuid.UUID | None = Query(
        None, description="Isletme sahibi olarak bakiliyorsa isletme kimligi"),
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Talep detayi — GORUNUM CAGIRANA GORE DEGISIR (`_talep_gorunumu`).

    `isletme_id` verilirse once SAHIPLIK dogrulanir: baskasinin
    isletmesi adina talep okumak, o isletmenin bolgesindeki tum
    talepleri okumak demekti.
    """
    if isletme_id is not None:
        await _sahiplik_dogrula(db, kimlik.kullanici_id, isletme_id)
    return await _talep_gorunumu(db, talep_id,
                                 kullanici_id=kimlik.kullanici_id,
                                 isletme_id=isletme_id)


@router.post("/talep/{talep_id}/iptal")
async def talep_iptal(
    talep_id: uuid.UUID,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Talebi iptal eder. Doner: {"durum": "iptal"}."""
    t = (
        await db.execute(
            text("SELECT kullanici_id, durum FROM talep WHERE id = :i"),
            {"i": talep_id},
        )
    ).mappings().first()
    if t is None:
        raise HTTPException(status_code=404, detail="talep_bulunamadi")
    if t["kullanici_id"] != kimlik.kullanici_id:
        raise HTTPException(status_code=403, detail="talep_size_ait_degil")
    if t["durum"] == "is_verildi":
        # Is verilmis bir talebi iptal etmek, ustanin kabul ettigi isi
        # tek tarafli silmek olurdu. Is akisi `is` uzerinden yurur.
        raise HTTPException(status_code=409, detail="is_verilmis_talep")
    await db.execute(
        text("UPDATE talep SET durum='iptal', updated_at=now() WHERE id=:i"),
        {"i": talep_id},
    )
    return {"durum": "iptal"}


@router.get("/isletme/{isletme_id}/talepler")
async def isletmeye_gelen_talepler(
    isletme_id: uuid.UUID,
    limit: int = Query(50, ge=1, le=200),
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Isletmenin hizmet alani + kategorisiyle eslesen ACIK talepler.

    Doner: {"items": [...]} — her kalem TEKLIF ASAMASI gorunumunde,
    yani ACIK ADRES YOK, ad/telefon yalniz kullanici izin verdiyse.

    Kendi verdigi teklif varsa `benim_teklifim` doluyor: isletme ayni
    talebe iki kez teklif vermeye calisip 409 almasin.
    """
    await _sahiplik_dogrula(db, kimlik.kullanici_id, isletme_id)
    satirlar = (
        await db.execute(
            text(
                """
                SELECT t.id, t.baslik, t.aciklama, t.durum, t.created_at,
                       t.butce_min_kurus, t.butce_max_kurus,
                       t.paylas_ad, t.paylas_telefon,
                       ku.ad_soyad, ku.telefon,
                       k.ad AS kategori, m.ad AS mahalle, ic.ad AS ilce,
                       l.ad AS il,
                       (SELECT tk.id FROM teklif tk WHERE tk.talep_id = t.id
                         AND tk.isletme_id = :isl) AS benim_teklifim
                FROM talep t
                JOIN kategori k ON k.id = t.kategori_id
                JOIN mahalle m ON m.id = t.mahalle_id
                JOIN ilce ic ON ic.id = m.ilce_id
                JOIN il l ON l.id = ic.il_id
                JOIN dukkan_kullanici ku ON ku.id = t.kullanici_id
                WHERE t.durum IN ('acik', 'teklif_var')
                  AND EXISTS (SELECT 1 FROM isletme_hizmet_alani ha
                               WHERE ha.isletme_id = :isl
                                 AND ha.mahalle_id = t.mahalle_id)
                  AND EXISTS (SELECT 1 FROM isletme_kategori ik
                               WHERE ik.isletme_id = :isl
                                 AND ik.kategori_id = t.kategori_id)
                ORDER BY t.created_at DESC LIMIT :l
                """
            ),
            {"isl": isletme_id, "l": limit},
        )
    ).mappings().all()

    # ACIK ADRES BU SORGUDA HIC SECILMIYOR — teklif asamasinda gorunmez.
    # Secip sonra silmek yerine HIC OKUMAMAK, bir gun "sil" adiminin
    # unutulmasi riskini ortadan kaldirir.
    return {
        "items": [
            {
                "id": str(x["id"]), "baslik": x["baslik"],
                "aciklama": x["aciklama"], "durum": x["durum"],
                "created_at": x["created_at"],
                "butce_min_kurus": x["butce_min_kurus"],
                "butce_max_kurus": x["butce_max_kurus"],
                "kategori": x["kategori"],
                "mahalle": x["mahalle"], "ilce": x["ilce"], "il": x["il"],
                "ad": x["ad_soyad"] if x["paylas_ad"] else None,
                "telefon": x["telefon"] if x["paylas_telefon"] else None,
                "acik_adres": None,
                "benim_teklifim": (str(x["benim_teklifim"])
                                   if x["benim_teklifim"] else None),
            }
            for x in satirlar
        ]
    }


@router.post("/talep/{talep_id}/teklif", status_code=201)
async def teklif_ver(
    talep_id: uuid.UUID,
    govde: TeklifVer,
    istek: Request,
    isletme_id: uuid.UUID = Query(..., description="Teklifi veren isletme"),
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Talebe teklif verir. Doner: {"id", "durum"}.

    ON KOSUL: isletme ONAYLI ve talep onun BOLGESINDE+KATEGORISINDE
    olmali. `_talep_gorunumu` bu ikisini de dogruluyor (403).
    """
    isl = await _sahiplik_dogrula(db, kimlik.kullanici_id, isletme_id)
    if isl["durum"] != "onayli":
        # Onaysiz isletme teklif veremez: kullanici, aramada hic
        # gormedigi bir isletmeden teklif alirdi.
        raise HTTPException(status_code=403, detail="isletme_onayli_degil")

    # Bolge/kategori eslesmesini ve talebin varligini dogrular (403/404).
    await _talep_gorunumu(db, talep_id, kullanici_id=kimlik.kullanici_id,
                          isletme_id=isletme_id)

    t = (
        await db.execute(
            text("SELECT durum FROM talep WHERE id = :i"), {"i": talep_id}
        )
    ).mappings().one()
    if t["durum"] not in ("acik", "teklif_var"):
        raise HTTPException(status_code=409, detail="talep_teklife_kapali")

    var = (
        await db.execute(
            text("SELECT id FROM teklif WHERE talep_id=:t AND isletme_id=:i"),
            {"t": talep_id, "i": isletme_id},
        )
    ).first()
    if var:
        raise HTTPException(status_code=409, detail="zaten_teklif_verdiniz")

    yeni = (
        await db.execute(
            text("INSERT INTO teklif (talep_id, isletme_id, tutar_kurus, mesaj) "
                 "VALUES (:t, :i, :tut, :m) RETURNING id, durum"),
            {"t": talep_id, "i": isletme_id, "tut": govde.tutar_kurus,
             "m": govde.mesaj},
        )
    ).mappings().one()
    await db.execute(
        text("UPDATE talep SET durum='teklif_var', updated_at=now() "
             "WHERE id=:i AND durum='acik'"),
        {"i": talep_id},
    )
    # TALEP SAHIBINE BILDIRIM. Teklif gelen kullanici bunu ANINDA
    # bilmeli: teklifi gormeyen musteri baska yerden usta bulur ve
    # teklif veren isletme bosuna beklemis olur.
    sahip = (
        await db.execute(
            text("SELECT t.kullanici_id, i.ad FROM talep t "
                 "CROSS JOIN isletme i WHERE t.id = :t AND i.id = :i"),
            {"t": talep_id, "i": isletme_id},
        )
    ).mappings().one()
    await bildir(
        db, kullanici_id=sahip["kullanici_id"], tip="teklif_geldi",
        baslik="Yeni teklif",
        govde=f"{sahip['ad']} talebine teklif verdi.",
        veri={"talep_id": str(talep_id), "isletme": sahip["ad"]},
    )
    await _denetim(db, aktor_id=kimlik.kullanici_id, eylem="teklif_ver",
                   hedef_tip="teklif", hedef_id=yeni["id"], istek=istek)
    return {"id": str(yeni["id"]), "durum": yeni["durum"]}


@router.get("/talep/{talep_id}/teklifler")
async def teklifler(
    talep_id: uuid.UUID,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Talebe gelen teklifler — YALNIZ TALEP SAHIBI.

    Doner: {"items": [...]}

    Bir isletme BASKA isletmelerin tekliflerini GOREMEZ: gorseydi
    fiyat kirma ve teklif kopyalama mumkun olurdu.
    """
    t = (
        await db.execute(
            text("SELECT kullanici_id FROM talep WHERE id = :i"), {"i": talep_id}
        )
    ).mappings().first()
    if t is None:
        raise HTTPException(status_code=404, detail="talep_bulunamadi")
    if t["kullanici_id"] != kimlik.kullanici_id:
        raise HTTPException(status_code=403, detail="talep_size_ait_degil")

    satirlar = (
        await db.execute(
            text(
                "SELECT tk.id, tk.tutar_kurus, tk.mesaj, tk.durum, "
                "       tk.created_at, i.ad AS isletme_ad, i.slug AS isletme_slug, "
                "       i.telefon AS isletme_telefon, i.whatsapp, "
                "       i.dogrulama_seviyesi, i.ortalama_puan, i.yorum_sayisi "
                "FROM teklif tk JOIN isletme i ON i.id = tk.isletme_id "
                "WHERE tk.talep_id = :t "
                "ORDER BY tk.durum = 'kabul' DESC, i.siralama_puani DESC, tk.id"
            ),
            {"t": talep_id},
        )
    ).mappings().all()
    return {"items": [dict(x) for x in satirlar]}


@router.post("/teklif/{teklif_id}/kabul")
async def teklif_kabul(
    teklif_id: uuid.UUID,
    istek: Request,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Teklifi kabul eder ve `is` kaydini acar. Doner: {"is_id", "durum"}.

    ==================================================================
    BU UC ADRESI ACAN TEK YER
    ==================================================================
    `is` satirinin VARLIGI iki seyin anahtari: acik adres + telefonun
    kabul edilen isletmeye acilmasi, ve (F5) dogrulanmis yorum hakki.

    BIR TALEPTEN BIR IS (`talep_id` UNIQUE). Ayni talebi iki ustaya
    vermek isteyen kullanici IKINCI BIR TALEP acar — aksi halde
    "hangi isin yorumu bu?" sorusu cevapsiz kalirdi.
    """
    tk = (
        await db.execute(
            text("SELECT tk.id, tk.talep_id, tk.isletme_id, tk.durum, "
                 "       t.kullanici_id, t.durum AS talep_durum "
                 "FROM teklif tk JOIN talep t ON t.id = tk.talep_id "
                 "WHERE tk.id = :i"),
            {"i": teklif_id},
        )
    ).mappings().first()
    if tk is None:
        raise HTTPException(status_code=404, detail="teklif_bulunamadi")
    if tk["kullanici_id"] != kimlik.kullanici_id:
        raise HTTPException(status_code=403, detail="talep_size_ait_degil")
    if tk["durum"] != "gonderildi":
        raise HTTPException(status_code=409, detail="teklif_kabul_edilemez")
    if tk["talep_durum"] == "is_verildi":
        raise HTTPException(status_code=409, detail="talep_zaten_is_verildi")

    yeni = (
        await db.execute(
            text("INSERT INTO is_kaydi (talep_id, teklif_id, isletme_id, kullanici_id) "
                 "VALUES (:t, :tk, :i, :k) RETURNING id"),
            {"t": tk["talep_id"], "tk": teklif_id, "i": tk["isletme_id"],
             "k": kimlik.kullanici_id},
        )
    ).mappings().one()

    await db.execute(
        text("UPDATE teklif SET durum='kabul', updated_at=now() WHERE id=:i"),
        {"i": teklif_id},
    )
    # DIGER TEKLIFLER REDDEDILIR — ve bu kullaniciya da isletmelere de
    # dogruyu soyler: "bekliyor" halinde birakmak, teklif veren ustayi
    # gereksiz yere bekletirdi.
    await db.execute(
        text("UPDATE teklif SET durum='red', updated_at=now() "
             "WHERE talep_id=:t AND id<>:i AND durum='gonderildi'"),
        {"t": tk["talep_id"], "i": teklif_id},
    )
    await db.execute(
        text("UPDATE talep SET durum='is_verildi', updated_at=now() WHERE id=:t"),
        {"t": tk["talep_id"]},
    )
    # ISLETME SAHIBINE BILDIRIM: is verildi ve ADRES ACILDI. Ustanin
    # bunu gormemesi, kabul edilmis bir isin yapilmamasi demek.
    isl_sahip = (
        await db.execute(
            text("SELECT sahip_kullanici_id, ad FROM isletme WHERE id = :i"),
            {"i": tk["isletme_id"]},
        )
    ).mappings().one()
    await bildir(
        db, kullanici_id=isl_sahip["sahip_kullanici_id"], tip="is_verildi",
        baslik="İş verildi",
        govde="Teklifiniz kabul edildi. Müşteri bilgileri açıldı.",
        veri={"isletme_id": str(tk["isletme_id"]),
              "talep_id": str(tk["talep_id"])},
    )
    await _denetim(db, aktor_id=kimlik.kullanici_id, eylem="teklif_kabul",
                   hedef_tip="is", hedef_id=yeni["id"], istek=istek)
    return {"is_id": str(yeni["id"]), "durum": "kabul"}


@router.post("/is/{is_id}/tamamlandi")
async def is_tamamlandi(
    is_id: uuid.UUID,
    istek: Request,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Isi tamamlandi isaretler. Doner: {"durum", "yorum_hakki"}.

    KULLANICI YA DA ISLETME SAHIBI isaretleyebilir. Yalniz kullaniciya
    birakmak, isini bitiren ustanin yorum hakkinin dogmasini musterinin
    unutkanligina baglardi; yalniz isletmeye birakmak ise ustaya "bitti"
    deme yetkisini tek tarafli verirdi. Ikisi de isaretleyebilir ama
    YORUM HAKKI yalniz KULLANICIDA (F5).
    """
    i = (
        await db.execute(
            text("SELECT ik.id, ik.kullanici_id, ik.isletme_id, ik.durum, "
                 "       isl.sahip_kullanici_id "
                 "FROM is_kaydi ik JOIN isletme isl ON isl.id = ik.isletme_id "
                 "WHERE ik.id = :i"),
            {"i": is_id},
        )
    ).mappings().first()
    if i is None:
        raise HTTPException(status_code=404, detail="is_bulunamadi")
    if kimlik.kullanici_id not in (i["kullanici_id"], i["sahip_kullanici_id"]):
        raise HTTPException(status_code=403, detail="is_size_ait_degil")
    if i["durum"] in ("iptal", "anlasmazlik"):
        raise HTTPException(status_code=409, detail="is_kapali")

    await db.execute(
        text("UPDATE is_kaydi SET durum='tamamlandi', tamamlandi_at=now(), "
             "updated_at=now() WHERE id=:i"),
        {"i": is_id},
    )
    await _denetim(db, aktor_id=kimlik.kullanici_id, eylem="is_tamamlandi",
                   hedef_tip="is", hedef_id=is_id, istek=istek)
    return {"durum": "tamamlandi",
            "yorum_hakki": kimlik.kullanici_id == i["kullanici_id"]}
