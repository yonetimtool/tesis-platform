"""(DUKKAN F5) YORUM VE GUVEN.

===========================================================================
IKI KATMAN, ACIKCA ETIKETLI
===========================================================================
  A) 'platform' — `is_kaydi` kaydina bagli, ROZETLI, tam agirlik
  B) 'davet'    — isletmenin daveti + OTP, rozetsiz, 0.3 agirlik, KOTALI

Yalniz A'yi kabul etmek "dogru" gorunur ama isler telefonda hallolur ve
yorumlarin ~%90'i HIC DOGMAZ; pazar yeri yorumsuz kalir ve yorumsuz pazar
yeri ise yaramaz. Katı olan kural, burada guvenli olan kural degil.

Cozum filtrelemek degil AYIRMAK: `kaynak` alani her yanitta doner ve
kullanici hangi yorumun neye dayandigini GORUR.

===========================================================================
SAHTE YORUM BITIRILMIYOR — MALIYETI YUKSELTILIYOR
===========================================================================
Bunu iddia etmek yanlis olurdu (03-guven-ve-fraud.md §7). Yapilan:
  * kendi isletmesine yorum -> KESIN RET
  * yorumcu telefonu = isletme telefonu -> KESIN RET
  * davet kotasi = platform etkinligine bagli
  * ayni cihaz/IP'den ayni isletmeye 2+ yorum -> MODERASYON (ret DEGIL:
    ortak ev/isyeri IP'si mesru olabilir)
  * dogrulanmamis OLUMSUZ yorum -> MODERASYON (yayin geciKIR, kaybolmaz)
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from .isletme import _denetim, _sahiplik_dogrula
from .kimlik import (
    OTP_MAKS_DENEME,
    OTP_OMRU_DK,
    DukkanKimlik,
    kimlik_zorunlu,
    kod_dogru_mu,
    kod_hashle,
    kod_uret,
    telefon_normalize,
)
from .siralama import siralama_puani_hesapla
from .veritabani import get_dukkan_session

router = APIRouter(prefix="/dukkan", tags=["dukkan"])

#: DAVETLI yorumda ayni isletme + ayni telefon: bu kadar gunde bir.
DAVET_TEKRAR_GUN = 90

#: Kota tabani: hic teklif vermemis isletme bile bu kadar davet
#: gonderebilir. SIFIR YAPMADIM — yeni bir isletme, platform disinda
#: yaptigi ilk isler icin hic yorum toplayamaz ve "0 yorum" olarak
#: dogar; bu, arz tarafini basta cezalandirir.
KOTA_TABAN = 3
#: Her platform etkinligi (teklif/is) basina EK davet hakki.
KOTA_ETKINLIK_BASINA = 2
#: Aylik ust sinir — etkinligi cok olan isletme bile sinirsiz davet
#: gonderemesin.
KOTA_TAVAN = 30

#: Bu puanin altindaki DOGRULANMAMIS yorum once moderasyona duser.
OLUMSUZ_ESIK = 2


class YorumYaz(BaseModel):
    puan: int = Field(ge=1, le=5)
    metin: str | None = Field(default=None, max_length=2000)


class DavetIstek(BaseModel):
    telefon: str = Field(min_length=7, max_length=32)


class DavetliYorum(BaseModel):
    kod: str = Field(min_length=6, max_length=6)
    puan: int = Field(ge=1, le=5)
    metin: str | None = Field(default=None, max_length=2000)


class CevapYaz(BaseModel):
    metin: str = Field(min_length=1, max_length=2000)


class SikayetYaz(BaseModel):
    tip: str = Field(pattern="^(odeme|hizmet|sahte_isletme|yorum|kisisel_veri|diger)$")
    metin: str = Field(min_length=10, max_length=4000)
    isletme_slug: str | None = None
    iletisim: str | None = Field(default=None, max_length=200)


def _ip(istek: Request) -> str | None:
    return istek.headers.get("x-forwarded-for", "").split(",")[0].strip() or None


async def _kendi_isletmesi_mi(
    db: AsyncSession, kullanici_id: uuid.UUID, isletme_id: uuid.UUID
) -> bool:
    """Yorumcu, isletmenin SAHIBI ya da TELEFON SAHIBI mi? Doner: True/False.

    Iki ayri kontrol cunku ikisi de gercek bir kacak yolu:
      1. sahip dogrudan kendine yorum yazar,
      2. sahip, isletme numarasiyla ayri bir Dukkan hesabi acar.
    """
    satir = (
        await db.execute(
            text(
                "SELECT i.sahip_kullanici_id, i.telefon, k.telefon AS yorumcu_tel "
                "FROM isletme i CROSS JOIN dukkan_kullanici k "
                "WHERE i.id = :i AND k.id = :k"
            ),
            {"i": isletme_id, "k": kullanici_id},
        )
    ).mappings().first()
    if satir is None:
        return False
    if satir["sahip_kullanici_id"] == kullanici_id:
        return True
    try:
        return telefon_normalize(satir["telefon"]) == satir["yorumcu_tel"]
    except HTTPException:
        # Isletme telefonu bozuk bicimdeyse eslesme yapilamaz; yorum
        # engellenmez ama bu bir kacak degil — kayit akisi zaten
        # normalize edilmis numara istiyor.
        return False


async def _supheli_oruntu(
    db: AsyncSession, isletme_id: uuid.UUID, ip: str | None
) -> str | None:
    """Moderasyona dusurulmesi gereken bir oruntu var mi? Doner: sebep|None.

    RET DEGIL, ISARET: ortak ev/isyeri IP'si mesru olabilir. Otomatik ret
    dogru yorumlari da keserdi.
    """
    if not ip:
        return None
    n = (
        await db.execute(
            text("SELECT count(*) FROM yorum WHERE isletme_id = :i AND ip = :ip"),
            {"i": isletme_id, "ip": ip},
        )
    ).scalar_one()
    return f"ayni_ip_{n + 1}_yorum" if n >= 1 else None


# ===================================================================== #
# KATMAN A — DOGRULANMIS YORUM
# ===================================================================== #

@router.post("/is/{is_id}/yorum", status_code=201)
async def dogrulanmis_yorum(
    is_id: uuid.UUID,
    govde: YorumYaz,
    istek: Request,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Platform uzerinden tamamlanmis ise yorum. Doner: {"id","durum","kaynak"}.

    YALNIZ IS SAHIBI KULLANICI. Isletme sahibinin de isaretleyebildigi
    "tamamlandi" eyleminden farkli: yorum hakki musteriye ait.

    `UNIQUE(is_id)` veritabaninda: bir ise BIR yorum.
    """
    i = (
        await db.execute(
            text("SELECT id, kullanici_id, isletme_id, durum FROM is_kaydi "
                 "WHERE id = :i"),
            {"i": is_id},
        )
    ).mappings().first()
    if i is None:
        raise HTTPException(status_code=404, detail="is_bulunamadi")
    if i["kullanici_id"] != kimlik.kullanici_id:
        raise HTTPException(status_code=403, detail="is_size_ait_degil")
    if i["durum"] != "tamamlandi":
        # Tamamlanmamis ise yorum, isi yapmamis bir ustayi
        # degerlendirmek olurdu.
        raise HTTPException(status_code=409, detail="is_tamamlanmadi")
    if await _kendi_isletmesi_mi(db, kimlik.kullanici_id, i["isletme_id"]):
        raise HTTPException(status_code=403, detail="kendi_isletmenize_yorum")

    var = (
        await db.execute(
            text("SELECT 1 FROM yorum WHERE is_id = :i"), {"i": is_id}
        )
    ).first()
    if var:
        raise HTTPException(status_code=409, detail="zaten_yorum_yaptiniz")

    ip = _ip(istek)
    supheli = await _supheli_oruntu(db, i["isletme_id"], ip)
    # DOGRULANMIS yorum, OLUMSUZ olsa bile DOGRUDAN YAYINLANIR: gercek bir
    # is var ve susturmak yorum sistemini yalanci yapardi. Yalnizca
    # supheli oruntu moderasyona dusurur.
    durum = "beklemede" if supheli else "yayinda"

    yeni = (
        await db.execute(
            text(
                "INSERT INTO yorum (isletme_id, yazan_id, is_id, kaynak, puan, "
                " metin, durum, yayinlandi_at, supheli_sebep, ip) "
                "VALUES (:isl, :k, :is, 'platform', :p, :m, :d, "
                "        CASE WHEN :d = 'yayinda' THEN now() END, :s, :ip) "
                "RETURNING id, durum"
            ),
            {"isl": i["isletme_id"], "k": kimlik.kullanici_id, "is": is_id,
             "p": govde.puan, "m": govde.metin, "d": durum, "s": supheli,
             "ip": ip},
        )
    ).mappings().one()

    if durum == "yayinda":
        await siralama_puani_hesapla(db, i["isletme_id"])
    await _denetim(db, aktor_id=kimlik.kullanici_id, eylem="yorum_platform",
                   hedef_tip="yorum", hedef_id=yeni["id"], istek=istek)
    return {"id": str(yeni["id"]), "durum": yeni["durum"], "kaynak": "platform"}


# ===================================================================== #
# KATMAN B — DAVETLI YORUM
# ===================================================================== #

async def _davet_kotasi(db: AsyncSession, isletme_id: uuid.UUID) -> dict:
    """Bu ayki davet kotasi. Doner: {"hak", "kullanilan", "kalan"}.

    KOTA PLATFORM ETKINLIGINE BAGLI: hic teklif vermemis bir isletme
    yalniz `KOTA_TABAN` kadar davet gonderebilir. Sahte yorum uretmenin
    maliyeti boylece GERCEK IS YAPMAYA baglaniyor.
    """
    etkinlik = (
        await db.execute(
            text(
                "SELECT (SELECT count(*) FROM teklif WHERE isletme_id = :i "
                "         AND created_at > now() - interval '30 days') "
                "     + (SELECT count(*) FROM is_kaydi WHERE isletme_id = :i "
                "         AND created_at > now() - interval '30 days')"
            ),
            {"i": isletme_id},
        )
    ).scalar_one()
    hak = min(KOTA_TAVAN, KOTA_TABAN + etkinlik * KOTA_ETKINLIK_BASINA)
    # ==================================================================
    # YALNIZ GONDERILMIS DAVETLER SAYILIR (goc 0122)
    # ==================================================================
    # OLCULEN KUSUR: sayac TUM satirlari sayiyordu. Onayli SMS basligi
    # olmadigi surece her davet basarisiz oluyor — yani baslik onaylandigi
    # gun ilk isletmeler kotalarini HIC SMS GITMEDEN tuketmis olurdu.
    #
    # Basarisiz deneme kayitta DURUR (teshis icin) ama kotayi YEMEZ.
    # Ayni karar `telefon_dogrulama` icin goc 0116'da verildi.
    kullanilan = (
        await db.execute(
            text("SELECT count(*) FROM yorum_daveti WHERE isletme_id = :i "
                 "AND created_at > now() - interval '30 days' "
                 "AND gonderim_durumu = 'gonderildi'"),
            {"i": isletme_id},
        )
    ).scalar_one()
    return {"hak": hak, "kullanilan": kullanilan,
            "kalan": max(0, hak - kullanilan), "etkinlik": etkinlik}


@router.get("/isletme/{isletme_id}/yorum-daveti/kota")
async def davet_kotasi(
    isletme_id: uuid.UUID,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Kalan davet hakki. Doner: {"hak","kullanilan","kalan","etkinlik"}.

    Isletme kotasini GORMELI: gormezse "neden gonderemiyorum" sorusu
    cevapsiz kalir ve destek yuku dogar.
    """
    await _sahiplik_dogrula(db, kimlik.kullanici_id, isletme_id)
    return await _davet_kotasi(db, isletme_id)


@router.post("/isletme/{isletme_id}/yorum-daveti", status_code=201)
async def yorum_daveti_gonder(
    isletme_id: uuid.UUID,
    govde: DavetIstek,
    istek: Request,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Musteriye yorum daveti gonderir. Doner: {"id","gonderildi","kalan"}.

    KOTA ASIMI 429 ve MODERATORE BILDIRILIR: sessizce reddetmek kotuye
    kullanimi GORUNMEZ yapar — engellenen deneme de bir sinyaldir
    (03-guven-ve-fraud.md §2.2b-c).
    """
    isl = await _sahiplik_dogrula(db, kimlik.kullanici_id, isletme_id)
    if isl["durum"] != "onayli":
        raise HTTPException(status_code=403, detail="isletme_onayli_degil")

    telefon = telefon_normalize(govde.telefon)

    # KENDI NUMARASINA DAVET: en kaba sahte yorum yolu.
    isl_tel = (
        await db.execute(
            text("SELECT telefon FROM isletme WHERE id = :i"), {"i": isletme_id}
        )
    ).scalar_one()
    try:
        if telefon_normalize(isl_tel) == telefon:
            raise HTTPException(status_code=403, detail="kendi_numaraniza_davet")
    except HTTPException as e:
        if e.status_code == 403:
            raise

    kota = await _davet_kotasi(db, isletme_id)
    if kota["kalan"] <= 0:
        # ==============================================================
        # AYRI OTURUM — ve bu bir kusur duzeltmesi
        # ==============================================================
        # Ilk yazimda kayit MEVCUT oturuma yazilip hemen ardindan
        # `HTTPException` firlatiliyordu. Istek basarisiz oldugu icin
        # transaction GERI SARILIYOR ve denetim kaydi KAYBOLUYORDU —
        # olculdu, test "kota asimi DENETIME yazilmadi" dedi.
        #
        # Ironi tam burada: kaydin varlik sebebi "engellenen deneme de
        # bir sinyaldir" idi ve sinyal, tam da engellendigi icin
        # siliniyordu. Kotuye kullanim GORUNMEZ kalirdi.
        #
        # Cozum: denetim satirini AYRI ve KENDI commit'i olan bir
        # oturuma yazmak. Ayni ilke Yonetiyor'da `audit_user` icin de
        # gecerli (KVKK denetim kaydi isteme baglanamaz).
        from .veritabani import SessionLocal

        async with SessionLocal() as denetim_oturumu:
            async with denetim_oturumu.begin():
                await denetim_oturumu.execute(
                    text("INSERT INTO denetim (aktor_id, aktor_tip, eylem, "
                         " hedef_tip, hedef_id, gerekce) "
                         "VALUES (:a, 'sistem', 'kota_asimi', 'isletme', "
                         "        :h, :g)"),
                    {"a": kimlik.kullanici_id, "h": isletme_id,
                     "g": f"davet kotasi asildi (hak={kota['hak']}, "
                          f"kullanilan={kota['kullanilan']})"},
                )
        raise HTTPException(status_code=429, detail="davet_kotasi_doldu")

    # 90 GUNDE BIR: ayni isletme + ayni numara.
    # AYNI DERT, IKINCI SAYAC (goc 0122): bu kural da TUM satirlari
    # sayiyordu. Gonderilemeyen bir davet, o numarayi UC AY boyunca
    # kilitliyordu — musteri hicbir sey almamisken. Isletme "davet
    # gonderdim, gelmedi, tekrar gondereyim" diyemiyordu.
    son = (
        await db.execute(
            text("SELECT 1 FROM yorum_daveti WHERE isletme_id = :i "
                 "AND telefon = :t "
                 "AND created_at > now() - make_interval(days => :g) "
                 "AND gonderim_durumu = 'gonderildi'"),
            {"i": isletme_id, "t": telefon, "g": DAVET_TEKRAR_GUN},
        )
    ).first()
    if son:
        raise HTTPException(status_code=409, detail="bu_numaraya_yakinda_davet")

    from ..config import settings
    from ..mesajlasma import dukkan_sms_saglayicisi

    isl_ad = (
        await db.execute(
            text("SELECT ad FROM isletme WHERE id = :i"), {"i": isletme_id}
        )
    ).scalar_one()

    # ==================================================================
    # ONCE GONDER, SONRA YAZ — `kimlik.kod_gonder_ve_kaydet` ile AYNI SIRA
    # ==================================================================
    # Once yazip sonra UPDATE etmek de olurdu; tek INSERT tercih edildi
    # cunku UPDATE unutuldugunda kayit sessizce 'saglayici_yok' kalir ve
    # kotayi yemez — yani hatanin YONU yanlis olurdu (herkese sinirsiz
    # davet). Tek yazimda boyle bir ara durum yok.
    kod = kod_uret()
    sonuc = dukkan_sms_saglayicisi().gonder(
        telefon, None,
        f"{isl_ad} hizmetini degerlendirmeniz icin kod: {kod}. "
        "Dukkan uzerinden.",
    )
    gonderildi = sonuc.durum == "gonderildi"
    # Degerler `telefon_dogrulama` ile BIREBIR AYNI (goc 0116/0122):
    # iki sayacin ileride ayrisma ihtimali olmasin.
    if gonderildi:
        gonderim_durumu = "gonderildi"
    elif sonuc.hata == "baslik_yok":
        gonderim_durumu = "baslik_yok"
    elif sonuc.durum == "yapilandirilmadi":
        gonderim_durumu = "saglayici_yok"
    else:
        gonderim_durumu = "basarisiz"

    yeni = (
        await db.execute(
            text("INSERT INTO yorum_daveti (isletme_id, telefon, kod_hash, "
                 " gecerlilik, gonderim_durumu, gonderim_hatasi, saglayici) "
                 "VALUES (:i, :t, :h, now() + interval '7 days', "
                 "        :gd, :gh, :sg) RETURNING id"),
            {"i": isletme_id, "t": telefon, "h": kod_hashle(kod, telefon),
             "gd": gonderim_durumu, "gh": sonuc.hata,
             "sg": sonuc.saglayici},
        )
    ).mappings().one()

    yanit = {
        "id": str(yeni["id"]),
        # CELISKI YOK: `gonderildi` gercek sonucu yansitir (SMS turunde
        # olculen kusurun ayni sinifI).
        "gonderildi": gonderildi,
        "gonderim": sonuc.durum if gonderildi else (sonuc.hata or sonuc.durum),
        # GONDERILMEDIYSE KOTA DUSMEZ. Yanitta dusurup veritabaninda
        # dusurmemek, arayuzu sunucuyla CELISTIRIRDI — ve isletme
        # "kotam bitti" sanip denemeyi birakirdi.
        "kalan": kota["kalan"] - 1 if gonderildi else kota["kalan"],
    }
    if settings.dukkan_otp_yanitta and (
        settings.dukkan_sms_saglayici or ""
    ).strip().lower() not in ("verimor", "netgsm"):
        yanit["dev_kod"] = kod
    return yanit


@router.post("/yorum-daveti/dogrula", status_code=201)
async def davetli_yorum(
    govde: DavetliYorum,
    istek: Request,
    telefon: str = Query(..., description="Davetin gonderildigi numara"),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Davet koduyla yorum yazar — KIMLIKSIZ (OTP kimligi kaniti).

    Doner: {"id","durum","kaynak"}

    Kullanicinin Dukkan hesabi OLMAYABILIR: telefonuna gelen kodla
    dogruluyoruz ve gerekiyorsa hesabi aciyoruz. Once kayit istemek,
    davetlerin cogunun cevapsiz kalmasi demekti.
    """
    tel = telefon_normalize(telefon)
    d = (
        await db.execute(
            text("SELECT id, isletme_id, kod_hash, durum, deneme, gecerlilik "
                 "FROM yorum_daveti WHERE telefon = :t "
                 "ORDER BY created_at DESC LIMIT 1"),
            {"t": tel},
        )
    ).mappings().first()
    if d is None:
        raise HTTPException(status_code=404, detail="davet_bulunamadi")
    if d["durum"] != "gonderildi":
        raise HTTPException(status_code=409, detail="davet_kullanilmis")
    if d["deneme"] >= OTP_MAKS_DENEME:
        raise HTTPException(status_code=429, detail="cok_fazla_deneme")

    from datetime import datetime, timezone

    if d["gecerlilik"] < datetime.now(timezone.utc):
        raise HTTPException(status_code=410, detail="davet_suresi_doldu")
    if not kod_dogru_mu(govde.kod, tel, d["kod_hash"]):
        await db.execute(
            text("UPDATE yorum_daveti SET deneme = deneme + 1 WHERE id = :i"),
            {"i": d["id"]},
        )
        raise HTTPException(status_code=401, detail="kod_hatali")

    kullanici = (
        await db.execute(
            text("SELECT id FROM dukkan_kullanici WHERE telefon = :t"), {"t": tel}
        )
    ).first()
    if kullanici is None:
        kullanici = (
            await db.execute(
                text("INSERT INTO dukkan_kullanici (telefon, "
                     " telefon_dogrulandi_at, kvkk_onay_at) "
                     "VALUES (:t, now(), now()) RETURNING id"),
                {"t": tel},
            )
        ).first()
    kullanici_id = kullanici[0]

    if await _kendi_isletmesi_mi(db, kullanici_id, d["isletme_id"]):
        raise HTTPException(status_code=403, detail="kendi_isletmenize_yorum")

    var = (
        await db.execute(
            text("SELECT 1 FROM yorum WHERE isletme_id = :i AND yazan_id = :k "
                 "AND kaynak = 'davet'"),
            {"i": d["isletme_id"], "k": kullanici_id},
        )
    ).first()
    if var:
        raise HTTPException(status_code=409, detail="zaten_yorum_yaptiniz")

    ip = _ip(istek)
    supheli = await _supheli_oruntu(db, d["isletme_id"], ip)
    # DAVETLI + OLUMSUZ yorum MODERASYONA duser (dogrulanmis is YOK).
    # Yayin GECIKIR, KAYBOLMAZ — rakip saldirisini (T2) susturmadan
    # yavaslatmanin yolu.
    if supheli is None and govde.puan <= OLUMSUZ_ESIK:
        supheli = "dogrulanmamis_olumsuz"
    durum = "beklemede" if supheli else "yayinda"

    yeni = (
        await db.execute(
            text("INSERT INTO yorum (isletme_id, yazan_id, kaynak, puan, metin, "
                 " durum, yayinlandi_at, supheli_sebep, ip) "
                 "VALUES (:i, :k, 'davet', :p, :m, :d, "
                 "        CASE WHEN :d = 'yayinda' THEN now() END, :s, :ip) "
                 "RETURNING id, durum"),
            {"i": d["isletme_id"], "k": kullanici_id, "p": govde.puan,
             "m": govde.metin, "d": durum, "s": supheli, "ip": ip},
        )
    ).mappings().one()
    await db.execute(
        text("UPDATE yorum_daveti SET durum='kullanildi', kullanildi_at=now() "
             "WHERE id = :i"),
        {"i": d["id"]},
    )
    if durum == "yayinda":
        await siralama_puani_hesapla(db, d["isletme_id"])
    return {"id": str(yeni["id"]), "durum": yeni["durum"], "kaynak": "davet"}


# ===================================================================== #
# KAMU: YORUM LISTESI — IKI KATMAN AYRI GOSTERILIR
# ===================================================================== #

@router.get("/isletme-profil/{slug}/yorum")
async def yorumlar(
    slug: str,
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Isletmenin yayindaki yorumlari — KIMLIKSIZ.

    Doner: {"items":[...], "ozet": {"dogrulanmis": n, "davetli": n}}

    `kaynak` HER YORUMDA doner ve ozet iki katmani AYRI sayar: kullanici
    "8 dogrulanmis" ile "0 dogrulanmis, 40 davetli" arasindaki farki
    KENDI okur. Karari gizlemek yerine GORUNUR kiliyoruz.
    """
    isl = (
        await db.execute(
            text("SELECT id FROM isletme WHERE slug = :s "
                 "AND durum = 'onayli' AND dogrulama_seviyesi >= 1"),
            {"s": slug},
        )
    ).first()
    if isl is None:
        raise HTTPException(status_code=404, detail="isletme_bulunamadi")

    satirlar = (
        await db.execute(
            text(
                "SELECT y.id, y.kaynak, y.puan, y.metin, y.yayinlandi_at, "
                "       c.metin AS cevap, c.created_at AS cevap_at "
                "FROM yorum y "
                "LEFT JOIN yorum_cevap c ON c.yorum_id = y.id "
                "  AND c.durum = 'yayinda' "
                "WHERE y.isletme_id = :i AND y.durum = 'yayinda' "
                "ORDER BY y.kaynak = 'platform' DESC, y.yayinlandi_at DESC "
                "LIMIT :l"
            ),
            {"i": isl[0], "l": limit},
        )
    ).mappings().all()

    ozet = (
        await db.execute(
            text("SELECT count(*) FILTER (WHERE kaynak='platform') AS dogrulanmis, "
                 "       count(*) FILTER (WHERE kaynak='davet') AS davetli "
                 "FROM yorum WHERE isletme_id = :i AND durum = 'yayinda'"),
            {"i": isl[0]},
        )
    ).mappings().one()

    return {"items": [dict(x) for x in satirlar], "ozet": dict(ozet)}


# ===================================================================== #
# CEVAP HAKKI — cogu durumda EN IYI SAVUNMA
# ===================================================================== #

@router.post("/yorum/{yorum_id}/cevap", status_code=201)
async def yoruma_cevap(
    yorum_id: uuid.UUID,
    govde: CevapYaz,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Isletmenin herkese acik cevabi. Doner: {"id"}.

    ISLETME YORUMU SILEMEZ — silebilseydi sistemin tamami anlamsiz
    olurdu. Cevap verebilir; okuyucu iki tarafi gorur ve cogu durumda
    en iyi savunma budur.
    """
    y = (
        await db.execute(
            text("SELECT id, isletme_id FROM yorum WHERE id = :i "
                 "AND durum = 'yayinda'"),
            {"i": yorum_id},
        )
    ).mappings().first()
    if y is None:
        raise HTTPException(status_code=404, detail="yorum_bulunamadi")
    await _sahiplik_dogrula(db, kimlik.kullanici_id, y["isletme_id"])

    var = (
        await db.execute(
            text("SELECT 1 FROM yorum_cevap WHERE yorum_id = :i"), {"i": yorum_id}
        )
    ).first()
    if var:
        raise HTTPException(status_code=409, detail="zaten_cevap_verdiniz")

    yeni = (
        await db.execute(
            text("INSERT INTO yorum_cevap (yorum_id, isletme_id, metin) "
                 "VALUES (:y, :i, :m) RETURNING id"),
            {"y": yorum_id, "i": y["isletme_id"], "m": govde.metin},
        )
    ).mappings().one()
    return {"id": str(yeni["id"])}


@router.post("/yorum/{yorum_id}/bildir")
async def yorum_bildir(
    yorum_id: uuid.UUID,
    istek: Request,
    kimlik: DukkanKimlik = Depends(kimlik_zorunlu),
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Yorumu moderasyona bildirir. Doner: {"bildirildi": true}.

    ISLETME SILEMEZ, ISARETLEYEBILIR. Silme yetkisi verilseydi olumsuz
    her yorum kaybolur ve yorum sistemi anlamsizlasirdi.
    """
    y = (
        await db.execute(
            text("SELECT id, isletme_id FROM yorum WHERE id = :i"), {"i": yorum_id}
        )
    ).mappings().first()
    if y is None:
        raise HTTPException(status_code=404, detail="yorum_bulunamadi")

    await db.execute(
        text("INSERT INTO sikayet (sikayetci_id, isletme_id, yorum_id, tip, "
             " metin, ip) VALUES (:s, :i, :y, 'yorum', "
             " 'Yorum isletme tarafindan bildirildi.', :ip)"),
        {"s": kimlik.kullanici_id, "i": y["isletme_id"], "y": yorum_id,
         "ip": _ip(istek)},
    )
    return {"bildirildi": True}


# ===================================================================== #
# SIKAYET — KIMLIKSIZ de yapilabilir
# ===================================================================== #

@router.post("/sikayet", status_code=201)
async def sikayet_olustur(
    govde: SikayetYaz,
    istek: Request,
    db: AsyncSession = Depends(get_dukkan_session),
) -> dict:
    """Sikayet kaydi — KIMLIKSIZ.

    Doner: {"id", "durum"}

    KIMLIK ZORUNLU DEGIL ve bu bilincli: dolandirilan ve hesabi olmayan
    bir kullanici sikayet EDEMESEYDI, en cok duyulmasi gereken ses
    kesilirdi. `iletisim` alani opsiyonel — sonuc bildirilebilsin diye.
    """
    isletme_id = None
    if govde.isletme_slug:
        satir = (
            await db.execute(
                text("SELECT id FROM isletme WHERE slug = :s"),
                {"s": govde.isletme_slug},
            )
        ).first()
        # Bulunamazsa 422 DEGIL: sikayet KAYDEDILIR. Yanlis yazilmis bir
        # slug yuzunden bir dolandiricilik sikayetini reddetmek, en kotu
        # sonucu uretirdi.
        isletme_id = satir[0] if satir else None

    yeni = (
        await db.execute(
            text("INSERT INTO sikayet (isletme_id, tip, metin, iletisim, ip) "
                 "VALUES (:i, :t, :m, :il, :ip) RETURNING id, durum"),
            {"i": isletme_id, "t": govde.tip, "m": govde.metin,
             "il": govde.iletisim, "ip": _ip(istek)},
        )
    ).mappings().one()
    return {"id": str(yeni["id"]), "durum": yeni["durum"]}
