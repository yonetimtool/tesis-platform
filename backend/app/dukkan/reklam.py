"""(DUKKAN F8b) REKLAM — gorunurluk satisi ve sponsorlu yerlesim.

===========================================================================
PLATFORMUN TEK GELIRI
===========================================================================
Isletme -> platform DOGRUDAN SATIS. Odeme araciligi degil; kendi
hizmetimizin satisi. Talep/teklif/is akisiyla HICBIR baglantisi yok ve
olmayacak (bkz. `talep.py` baslgi + `test_dukkan_para_akisi_yok.py`).

===========================================================================
REKLAM ORGANIK SIRALAMAYI MANIPULE ETMEZ — YAPISAL AYRIM
===========================================================================
`siralama.py` `siralama_puani`nin TEK YAZMA YOLU ve reklamdan HABERSIZ.
Bu dosya o puana dokunmaz, okumaz bile.

Sponsorlu sonuclar AYRI SORGU ile alinir ve arayuzde AYRI BLOKTA
gosterilir. Organik listeye karistirmak, kullanicinin "en iyi sonuc"
sandigi seyi satmak olurdu — ve o an organik sonucun degeri duser,
dolayisiyla reklamin degeri de duser.

Sponsorlu isletme organik listede DE cikar (hak ettigi sirada).
Organikten cikarmak, paranin sıralamaya karismasinin tersten haliydi.

Kilit: `test_dukkan_reklam.py::test_REKLAM_SIRALAMA_PUANINI_DEGISTIRMEZ`.

===========================================================================
SLOT SINIRI: SAYILAR VERIDE, KODDA DEGIL
===========================================================================
Mahalle 1 / ilce 2 / il 3 ve %20 oran tavani birer TAHMIN. Bir mahallede
kac isletme oldugunu, bir ilcede kac arama yapildigini bugun bilmiyoruz.
Kodda sabit olsalardi her ayar bir dagitim demek olurdu.

`reklam_slot_kurali` tablosundan okunur; `etkin_at` ile versiyonlu ve
eski satirlar SILINMEZ ("o tarihte kural neydi" sorusu bir itirazda
sorulur).

ORAN TAVANI NEDEN VAR: mahallede 3 isletme varsa 1 slot bile listenin
ucte biri olur. Sayfa reklam panosuna donerse organik sonucun degeri
duser — ve satilan sey tam olarak "degerli bir listenin ustunde olmak".
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from .arama import _GORUNUR
from .isletme import _denetim, _sahiplik_dogrula
from .kimlik import DukkanKimlik, kimlik_zorunlu
from .veritabani import get_dukkan_session

router = APIRouter(prefix="/dukkan", tags=["dukkan"])

#: Kapsam -> (reklam sutunu, isletmenin hizmet alanindan turetilen sutun)
#:
#: Tek sozlukte toplaniyor: uc ayri yerde `if kapsam == ...` yazmak,
#: birinde yeni kapsamin unutulmasi demekti.
KAPSAM_SUTUNU = {"mahalle": "mahalle_id", "ilce": "ilce_id", "il": "il_id"}


class ReklamIstek(BaseModel):
    paket_id: uuid.UUID
    kategori_slug: str = Field(min_length=1, max_length=120)
    #: Kapsama gore YALNIZ BIRI verilir; sunucu tutarliligi dogrular.
    mahalle_id: uuid.UUID | None = None
    ilce_id: uuid.UUID | None = None
    il_id: uuid.UUID | None = None


async def slot_kurali(db: AsyncSession, kapsam: str) -> dict:
    """O kapsam icin GECERLI kural. Doner: {"azami_slot", "azami_oran"}.

    En son `etkin_at` kazanir. Kural yoksa 0 doner — yani SATIS KAPALI.
    "Kural bulunamadi" durumunda sinirsiz satmak, bir yapilandirma
    hatasini gelire cevirip sayfayi reklam panosuna dondururdu.
    """
    r = (
        await db.execute(
            text("SELECT azami_slot, azami_oran FROM reklam_slot_kurali "
                 "WHERE kapsam = :k AND etkin_at <= now() "
                 "ORDER BY etkin_at DESC LIMIT 1"),
            {"k": kapsam},
        )
    ).mappings().first()
    return dict(r) if r else {"azami_slot": 0, "azami_oran": 0}


async def _bolge_isletme_sayisi(
    db: AsyncSession, *, kapsam: str, bolge_id: uuid.UUID,
    kategori_id: uuid.UUID,
) -> int:
    """O bolge+kategoride GORUNUR isletme sayisi (oran tavani icin).

    `_GORUNUR` arama ile AYNI sabit: reklam orani, kullanicinin gercekten
    gordugu liste uzerinden hesaplanmali. Ayri bir kosul yazsaydim,
    "sayfada %20" iddiasi baska bir sayfanin %20'si olurdu.
    """
    nere = {
        "mahalle": "ha.mahalle_id = :b",
        "ilce": "m.ilce_id = :b",
        "il": "ic.il_id = :b",
    }[kapsam]
    return (
        await db.execute(
            text(f"""
                SELECT count(DISTINCT i.id) FROM isletme i
                JOIN isletme_hizmet_alani ha ON ha.isletme_id = i.id
                JOIN mahalle m ON m.id = ha.mahalle_id
                JOIN ilce ic ON ic.id = m.ilce_id
                JOIN isletme_kategori ik ON ik.isletme_id = i.id
                WHERE {_GORUNUR} AND {nere} AND ik.kategori_id = :kid
            """),
            {"b": bolge_id, "kid": kategori_id},
        )
    ).scalar_one()


async def _dolu_slot(
    db: AsyncSession, *, kapsam: str, bolge_id: uuid.UUID,
    kategori_id: uuid.UUID,
) -> int:
    """O bolge+kategoride SU AN yayinda olan reklam sayisi."""
    sutun = KAPSAM_SUTUNU[kapsam]
    return (
        await db.execute(
            text(f"SELECT count(*) FROM reklam WHERE durum = 'yayinda' "
                 f"  AND kapsam = :kap AND {sutun} = :b "
                 "  AND kategori_id = :kid "
                 "  AND now() >= baslangic AND now() < bitis"),
            {"kap": kapsam, "b": bolge_id, "kid": kategori_id},
        )
    ).scalar_one()


async def slot_durumu(
    db: AsyncSession, *, kapsam: str, bolge_id: uuid.UUID,
    kategori_id: uuid.UUID,
) -> dict:
    """Bu bolgede reklam satilabilir mi? Doner:
    {"azami", "dolu", "bos", "isletme_sayisi", "oran_tavani_slot"}.

    ETKIN AZAMI = min(kural slotu, oran tavaninin izin verdigi slot).
    """
    kural = await slot_kurali(db, kapsam)
    isletme = await _bolge_isletme_sayisi(
        db, kapsam=kapsam, bolge_id=bolge_id, kategori_id=kategori_id)
    # ORAN TAVANI: sponsorlu / (organik + sponsorlu) <= azami_oran
    # `int()` asagi yuvarlar — 3 isletme + %20 -> 0 slot. Yukari
    # yuvarlamak, tam da onlemek istedigimiz durumu uretirdi.
    oran_slot = int(isletme * float(kural["azami_oran"]) / 100)
    azami = min(int(kural["azami_slot"]), oran_slot)
    dolu = await _dolu_slot(
        db, kapsam=kapsam, bolge_id=bolge_id, kategori_id=kategori_id)
    return {
        "azami": azami,
        "dolu": dolu,
        "bos": max(0, azami - dolu),
        "isletme_sayisi": isletme,
        "oran_tavani_slot": oran_slot,
    }


def _bolge_sec(govde: ReklamIstek, kapsam: str) -> uuid.UUID:
    """Kapsama uyan bolge kimligini secer; tutarsizsa 400.

    Sunucu dogruluyor cunku arayuzde dogrulamak YETMEZ: ikinci istemci
    (mobil) o kontrolu tasimayabilir ve tutarsiz satir arama sorgusunda
    SESSIZCE hicbir yere dusmezdi.
    """
    verilenler = {
        "mahalle": govde.mahalle_id,
        "ilce": govde.ilce_id,
        "il": govde.il_id,
    }
    hedef = verilenler.pop(kapsam)
    if hedef is None or any(v is not None for v in verilenler.values()):
        raise HTTPException(
            status_code=400,
            detail="bolge_kapsamla_uyusmuyor",
        )
    return hedef


# ===================================================================== #
# UCLAR — KATALOG VE DURUM (isletme sahibi)
# ===================================================================== #

@router.get("/reklam/paketler")
async def paketler(db: AsyncSession = Depends(get_dukkan_session)) -> dict:
    """Satistaki reklam paketleri. Doner: {"items": [...]}.

    KIMLIKSIZ: fiyat gizli bir bilgi degil ve isletme kaydolmadan once
    "ne kadara mal olur" sorusunu cevaplayabilmeli.
    """
    satirlar = (
        await db.execute(
            text("SELECT id, ad, kapsam, gun, fiyat_kurus, kdv_orani "
                 "FROM reklam_paketi WHERE aktif ORDER BY sira, fiyat_kurus")
        )
    ).mappings().all()
    return {"items": [dict(x) for x in satirlar]}


@router.get("/reklam/slot-durumu")
async def slot_durumu_ucu(
    kapsam: str = Query(..., pattern="^(mahalle|ilce|il)$"),
    bolge_id: uuid.UUID = Query(...),
    kategori_slug: str = Query(..., min_length=1),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Bu bolgede yer var mi? Doner: slot_durumu + {"kategori_id"}.

    SATIN ALMADAN ONCE GORULEBILIR: "bu bolge dolu, siraya girin" demek,
    parayi alip sonra "aslinda dolu" demekten durust.
    """
    kategori_id = (
        await db.execute(
            text("SELECT id FROM kategori WHERE slug = :s AND ust_id IS NOT NULL"),
            {"s": kategori_slug},
        )
    ).scalar_one_or_none()
    if kategori_id is None:
        raise HTTPException(status_code=404, detail="kategori_yok")
    d = await slot_durumu(
        db, kapsam=kapsam, bolge_id=bolge_id, kategori_id=kategori_id)
    return {**d, "kategori_id": str(kategori_id)}


@router.get("/reklam/benim")
async def benim_reklamlarim(
    isletme_id: uuid.UUID = Query(...),
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Isletmenin reklamlari (gecmis dahil). Doner: {"items": [...]}.

    BITMIS REKLAM DA DONER: "gecen ay hangi reklam yayindaydi" sorusu bir
    faturada ya da itirazda sorulur; listeden dusurmek onu cevapsiz
    birakirdi.
    """
    await _sahiplik_dogrula(db, kimlik.kullanici_id, isletme_id)
    satirlar = (
        await db.execute(
            text("""
                SELECT r.id, r.kapsam, r.durum, r.baslangic, r.bitis,
                       r.kapanis_sebebi, k.ad AS kategori,
                       COALESCE(m.ad, ic.ad, l.ad) AS bolge,
                       p.ad AS paket, p.fiyat_kurus
                FROM reklam r
                JOIN kategori k ON k.id = r.kategori_id
                LEFT JOIN mahalle m ON m.id = r.mahalle_id
                LEFT JOIN ilce ic ON ic.id = r.ilce_id
                LEFT JOIN il l ON l.id = r.il_id
                LEFT JOIN reklam_paketi p ON p.id = r.paket_id
                WHERE r.isletme_id = :i ORDER BY r.created_at DESC
            """),
            {"i": isletme_id},
        )
    ).mappings().all()
    return {"items": [dict(x) for x in satirlar]}


# ===================================================================== #
# YAYINA ALMA — odemeden AYRI
# ===================================================================== #
# Bu fonksiyon parayi BILMEZ. Odeme F8c'de kendi modulunde ve basarili
# odemeden SONRA burayi cagirir.
#
# NEDEN AYRI: reklamin elle acilabilmesi gerekiyor (hediye, telafi,
# tanitim donemi). Yayin mantigi odemeye baglansaydi, her istisna icin
# sahte bir odeme kaydi uretmek gerekirdi ve defter kirlenirdi.

async def reklam_ac(
    db: AsyncSession,
    *,
    isletme_id: uuid.UUID,
    paket_id: uuid.UUID | None,
    kapsam: str,
    bolge_id: uuid.UUID,
    kategori_id: uuid.UUID,
    gun: int,
) -> uuid.UUID:
    """Reklami YAYINA alir. Doner: reklam id.

    SLOT KONTROLU BURADA — cagiranin yapmasina birakilmadi: iki cagiran
    (satin alma ucu ve elle acma) ayni kontrolu iki kez yazsaydi, biri
    bir gun eskirdi.

    Yine de son soz VERITABANINDA: `EXCLUDE` kisiti ayni isletmenin
    cakisan iki reklamini engelliyor. Uygulama duzeyinde saymak es
    zamanli iki istegin IKISINI DE gecirebilirdi (TOCTOU).
    """
    d = await slot_durumu(
        db, kapsam=kapsam, bolge_id=bolge_id, kategori_id=kategori_id)
    if d["bos"] <= 0:
        # AYRINTI YANITTA DEGIL: zarf yalniz `code` + `message` tasir
        # (sozlesme). Kac slot dolu/bos bilgisini isteyen istemci
        # `/dukkan/reklam/slot-durumu` ucunu cagirir — ve o uc satis
        # oncesinde ZATEN cagriliyor.
        raise HTTPException(status_code=409, detail="bolge_dolu")
    sutun = KAPSAM_SUTUNU[kapsam]
    bitis = datetime.now(timezone.utc) + timedelta(days=gun)
    yeni = (
        await db.execute(
            text(f"INSERT INTO reklam (isletme_id, paket_id, kapsam, "
                 f" {sutun}, kategori_id, bitis) "
                 "VALUES (:i, :p, :kap, :b, :kid, :bit) RETURNING id"),
            {"i": isletme_id, "p": paket_id, "kap": kapsam, "b": bolge_id,
             "kid": kategori_id, "bit": bitis},
        )
    ).scalar_one()
    return yeni


@router.post("/reklam", status_code=201)
async def reklam_satin_al(
    govde: ReklamIstek,
    istek: Request,
    isletme_id: uuid.UUID = Query(...),
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Reklam satin alir. Doner: {"id", "bitis"} ya da 409 `bolge_dolu`.

    F8b'DE ODEME YOK: bu uc reklami DOGRUDAN acar. Odeme F8c'de araya
    girecek. Iki fazi ayirmak, reklam yayin mantiginin odeme saglayicisi
    olmadan da OLCULEBILMESINI sagliyor.

    ON KOSUL: isletme ONAYLI olmali. Onaysiz isletmenin reklami, aramada
    hic gorunmeyen bir isletmeye para odetmek olurdu.
    """
    isl = await _sahiplik_dogrula(db, kimlik.kullanici_id, isletme_id)
    if isl["durum"] != "onayli":
        raise HTTPException(status_code=403, detail="isletme_onayli_degil")

    paket = (
        await db.execute(
            text("SELECT id, kapsam, gun FROM reklam_paketi "
                 "WHERE id = :p AND aktif"),
            {"p": govde.paket_id},
        )
    ).mappings().first()
    if paket is None:
        raise HTTPException(status_code=404, detail="paket_yok")

    kategori_id = (
        await db.execute(
            text("SELECT id FROM kategori WHERE slug = :s AND ust_id IS NOT NULL"),
            {"s": govde.kategori_slug},
        )
    ).scalar_one_or_none()
    if kategori_id is None:
        raise HTTPException(status_code=404, detail="kategori_yok")
    # ISLETMENIN O KATEGORIDE OLMASI SART: olmayan bir kategoride reklam
    # almak, alakasiz aramalarda cikmak demek — hem kullanici hem
    # reklamveren icin degersiz.
    var = (
        await db.execute(
            text("SELECT 1 FROM isletme_kategori WHERE isletme_id = :i "
                 "AND kategori_id = :k"),
            {"i": isletme_id, "k": kategori_id},
        )
    ).first()
    if var is None:
        raise HTTPException(
            status_code=400, detail="isletme_bu_kategoride_degil")

    bolge_id = _bolge_sec(govde, paket["kapsam"])
    yeni = await reklam_ac(
        db, isletme_id=isletme_id, paket_id=paket["id"],
        kapsam=paket["kapsam"], bolge_id=bolge_id,
        kategori_id=kategori_id, gun=paket["gun"])
    await _denetim(db, aktor_id=kimlik.kullanici_id, eylem="reklam_acildi",
                   hedef_tip="reklam", hedef_id=yeni, istek=istek)
    bitis = (
        await db.execute(text("SELECT bitis FROM reklam WHERE id = :i"),
                         {"i": yeni})
    ).scalar_one()
    return {"id": str(yeni), "bitis": bitis}


# ===================================================================== #
# BEKLEME LISTESI — bolge doluyken
# ===================================================================== #
# ROTASYON YERINE BEKLEME (kullanicinin karari, gerekcesiyle):
# fazla satip sirayla gostermek daha cok gelir getirir ama isletme ne
# satin aldigini bilemez, "ne kadar gorundum" sorusu dogar ve platform
# onu KANITLAMAK zorunda kalir. Kapali satis durust: "bu bolge dolu,
# siraya girin".

@router.post("/reklam/bekleme", status_code=201)
async def beklemeye_gir(
    govde: ReklamIstek,
    isletme_id: uuid.UUID = Query(...),
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Dolu bolgede siraya girer. Doner: {"id", "sira"}.

    `sira` DONUYOR: "siradasiniz" demek yetmez — kacinci oldugunu
    bilmeyen isletme bekleyip beklememeye karar veremez.
    """
    await _sahiplik_dogrula(db, kimlik.kullanici_id, isletme_id)
    paket = (
        await db.execute(
            text("SELECT kapsam FROM reklam_paketi WHERE id = :p"),
            {"p": govde.paket_id},
        )
    ).mappings().first()
    if paket is None:
        raise HTTPException(status_code=404, detail="paket_yok")
    kategori_id = (
        await db.execute(
            text("SELECT id FROM kategori WHERE slug = :s AND ust_id IS NOT NULL"),
            {"s": govde.kategori_slug},
        )
    ).scalar_one_or_none()
    if kategori_id is None:
        raise HTTPException(status_code=404, detail="kategori_yok")

    kapsam = paket["kapsam"]
    bolge_id = _bolge_sec(govde, kapsam)
    d = await slot_durumu(
        db, kapsam=kapsam, bolge_id=bolge_id, kategori_id=kategori_id)
    if d["bos"] > 0:
        # YER VARKEN SIRAYA ALMA: isletme bekledigini sanip beklerken
        # satin alabilecegi bir yer bos dururdu.
        raise HTTPException(
            status_code=409, detail="yer_var")

    sutun = KAPSAM_SUTUNU[kapsam]
    try:
        yeni = (
            await db.execute(
                text(f"INSERT INTO reklam_bekleme (isletme_id, kapsam, "
                     f" {sutun}, kategori_id) VALUES (:i, :kap, :b, :kid) "
                     "RETURNING id"),
                {"i": isletme_id, "kap": kapsam, "b": bolge_id,
                 "kid": kategori_id},
            )
        ).scalar_one()
    except Exception as e:  # UNIQUE ihlali: zaten sirada
        if "uq_reklam_bekleme_tekil" in str(e):
            raise HTTPException(
                status_code=409, detail="zaten_sirada") from e
        raise

    sira = (
        await db.execute(
            text(f"SELECT count(*) FROM reklam_bekleme "
                 "WHERE durum = 'bekliyor' AND kategori_id = :kid "
                 f"  AND kapsam = :kap AND {sutun} = :b "
                 "  AND created_at <= (SELECT created_at FROM reklam_bekleme "
                 "                      WHERE id = :yeni)"),
            {"kid": kategori_id, "kap": kapsam, "b": bolge_id, "yeni": yeni},
        )
    ).scalar_one()
    return {"id": str(yeni), "sira": sira}


@router.delete("/reklam/bekleme/{bekleme_id}")
async def beklemeden_cik(
    bekleme_id: uuid.UUID,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Siradan cikar. Doner: {"cikan": n}.

    SILMIYOR, `vazgecti` isaretliyor: "kac isletme siraya girip vazgecti"
    sorusu, bolge fiyatlamasi icin bir sinyaldir.
    """
    isletme_id = (
        await db.execute(
            text("SELECT isletme_id FROM reklam_bekleme WHERE id = :i"),
            {"i": bekleme_id},
        )
    ).scalar_one_or_none()
    if isletme_id is None:
        raise HTTPException(status_code=404, detail="kayit_yok")
    await _sahiplik_dogrula(db, kimlik.kullanici_id, isletme_id)
    r = await db.execute(
        text("UPDATE reklam_bekleme SET durum='vazgecti', updated_at=now() "
             "WHERE id = :i AND durum = 'bekliyor'"),
        {"i": bekleme_id},
    )
    return {"cikan": r.rowcount}


# ===================================================================== #
# SPONSORLU YERLESIM — ARAMANIN YANINDA, ICINDE DEGIL
# ===================================================================== #

async def sponsorlu_isletmeler(
    db: AsyncSession,
    *,
    kategori_slug: str | None,
    il: str | None,
    ilce: str | None,
    mahalle: str | None,
    limit: int = 3,
) -> list[dict]:
    """Aramaya eslesen SPONSORLU isletmeler. Doner: liste (bos olabilir).

    ==================================================================
    ORGANIK SORGUYA DOKUNMUYOR
    ==================================================================
    Bu AYRI bir sorgu. Arama sorgusuna `LEFT JOIN reklam` ekleyip
    siralamaya katmak daha az kod olurdu — ve tam olarak yasaklanan sey
    o: para organik siraya karisirdi.

    ==================================================================
    KAPSAM DARDAN GENISE
    ==================================================================
    Kullanici mahalle secmisse once MAHALLE reklamlari, sonra ilce,
    sonra il. Daha genis kapsam daha pahali ama daha az hedefli; dar
    olanin once cikmasi hem kullaniciya hem reklamverene dogru geliyor.

    KATEGORI ZORUNLU: kategorisiz aramada sponsorlu gosterilmiyor.
    "Cekmekoy'de her sey" araması yapan kullaniciya elektrikci reklami
    gostermek, alakasiz reklamdir ve tikla(n)mayan reklam iki tarafi da
    memnuniyetsiz birakir.
    """
    if not kategori_slug or not il:
        return []

    kosullar = [
        _GORUNUR,
        "r.durum = 'yayinda'",
        "now() >= r.baslangic AND now() < r.bitis",
        "k.slug = :kategori AND k.ust_id IS NOT NULL",
    ]
    param: dict = {"kategori": kategori_slug, "il": il, "__l": limit}

    # Kapsam esleme: kullanicinin bulundugu yeri KAPSAYAN reklamlar.
    kapsam_kosulu = ["(r.kapsam = 'il' AND li.slug = :il)"]
    if ilce:
        kapsam_kosulu.append(
            "(r.kapsam = 'ilce' AND ici.slug = :ilce AND lii.slug = :il)")
        param["ilce"] = ilce
    if mahalle and ilce:
        kapsam_kosulu.append(
            "(r.kapsam = 'mahalle' AND mm.slug = :mahalle "
            " AND icm.slug = :ilce AND lim.slug = :il)")
        param["mahalle"] = mahalle
    kosullar.append("(" + " OR ".join(kapsam_kosulu) + ")")

    satirlar = (
        await db.execute(
            text(f"""
                SELECT DISTINCT ON (i.id)
                       i.ad, i.slug, i.aciklama, i.telefon, i.whatsapp,
                       i.dogrulama_seviyesi, i.ortalama_puan, i.yorum_sayisi,
                       r.kapsam AS reklam_kapsami,
                       ARRAY(SELECT k2.ad FROM isletme_kategori ik2
                              JOIN kategori k2 ON k2.id = ik2.kategori_id
                              WHERE ik2.isletme_id = i.id ORDER BY k2.ad)
                         AS kategoriler
                FROM reklam r
                JOIN isletme i ON i.id = r.isletme_id
                JOIN kategori k ON k.id = r.kategori_id
                LEFT JOIN il  li  ON li.id  = r.il_id
                LEFT JOIN ilce ici ON ici.id = r.ilce_id
                LEFT JOIN il  lii ON lii.id = ici.il_id
                LEFT JOIN mahalle mm ON mm.id = r.mahalle_id
                LEFT JOIN ilce icm ON icm.id = mm.ilce_id
                LEFT JOIN il  lim ON lim.id = icm.il_id
                WHERE {" AND ".join(kosullar)}
                -- SIRA: dar kapsam once (mahalle > ilce > il), sonra
                -- ESKI ALAN ONCE. Sponsorlu blogun KENDI ICINDE
                -- `siralama_puani` KULLANILMIYOR: kullanilsaydi para ile
                -- organik puan ayni sorguda bulusur ve ayrim bulanirdi.
                ORDER BY i.id,
                         CASE r.kapsam WHEN 'mahalle' THEN 0
                                       WHEN 'ilce' THEN 1 ELSE 2 END,
                         r.baslangic
                LIMIT :__l
            """),
            param,
        )
    ).mappings().all()
    # `sponsorlu` BAYRAGI SUNUCUDAN: istemcinin "bu listeden gelenler
    # sponsorludur" varsayimina birakilsaydi, ikinci istemci (mobil) o
    # varsayimi tasimayabilir ve rozet DUSERDI. Rozet zorunlu.
    return [{**dict(x), "sponsorlu": True} for x in satirlar]
