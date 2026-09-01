"""Rapor MOTORU + KATALOG (P31) — `/raporlar/...`.

TEK UC, UC BICIM: `POST /raporlar/{kod}?bicim=tablo|excel|pdf`. Bicim basina
ayri uc acmak, ayni parametre modelini uc kez dogrulamak ve uc yerde
degistirmek demekti.

PARAMETRE MODALI TEK MODEL (`RaporParametre`): her rapor bu kumenin bir alt
kumesini kullanir. Rapor basina ayri model, modal bileseninin her rapor icin
yeniden yazilmasi olurdu.

RBAC: admin + yonetici. Raporlar site finansini ve kisi adlarini tasir;
saha ve sakin ERISEMEZ. (`ismi_goster=false` KVKK icin ayrica vardir:
kapiya asilacak listede ad OLMAMALI.)
"""
from __future__ import annotations

from dataclasses import dataclass

import uuid
from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, literal_column, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..borclandirma import gecikme_kurus
from .. import defter
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import (
    AppUser,
    DuesAssessment,
    Firma,
    FinansalHareket,
    GelirGiderTanim,
    IcraDosyasi,
    Kasa,
    RaporIsi,
    Tenant,
    TenantDokuman,
    Unit,
    UnitResident,
    VarlikEki,
)
from ..rapor_ciktilari import excel_uret, metin_pdf, pdf_uret
from ..storage import presign_get
from ..raporlar import (
    RaporParam,
    RaporSonuc,
    Sutun,
    borc_alacak_satirlari,
    detayli_borc_satirlari,
    ihtar_metni,
    kurus_metin,
    sirala,
    tahsilat_performansi,
)
from ..schemas import (
    RaporGrafikTanimi,
    RaporIsOut,
    RaporKatalogOgesi,
    RaporKatalogResponse,
    RaporParametre,
    RaporTablo,
)

router = APIRouter(tags=["raporlar"])

_YONETIM = require_role("admin", "yonetici")
# (P128) RAPOR URETIMI BIR OKUMADIR — HTTP fiili POST olsa da.
# `POST /raporlar/{kod}` hicbir satir yazmaz (dosyada tek bir `db.add`
# yoktur); POST secilmesinin sebebi rapor PARAMETRELERININ bir govde
# istemesidir. Denetciyi bu ucun disinda birakmak, ona gorevinin ana
# aracini (katalogdaki "Denetci bicimi" raporu dahil) kapatmak olurdu.
# Kural "fiil GET olsun" degil "MUTASYON olmasin"dir.
_RAPOR_OKUR = require_role("admin", "yonetici", "denetci")

#: Donem anahtari (YYYY-MM). `func.to_char` BIND PARAMETRESI uretir ve
#: Postgres GROUP BY'daki ifadeyle eslestiremez; `literal_column` ifadeyi
#: oldugu gibi gomer (repo genelinde bilinen tuzak).
_DONEM_IFADESI = literal_column("to_char(finansal_hareket.tarih, 'YYYY-MM')")

# =========================================================================== #
# (P167 Asama 5) KATALOG ARTIK KATEGORI VE ALAN DA TASIYOR
# =========================================================================== #
#
# Brief: "Rapor sayfasi KATEGORILI KART IZGARASI olacak" ve "Her raporun
# kendi filtre alanlari... Ortak bir RaporModali bileseni yaz; her rapor
# kendi alan tanimini versin."
#
# ALAN TANIMI NEREDE DURMALI: iki secenek vardi.
#   (a) Istemcide bir sozluk — her rapor icin hangi alanlarin cizilecegi.
#   (b) Sunucuda, katalogla birlikte.
#
# (b) SECILDI. Sebep: hangi parametreyi hangi raporun ANLAMLANDIRDIGINI
# `_uret` zaten biliyor. Istemcide ikinci bir liste tutmak, bir rapora yeni
# bir suzgec eklendiginde iki yerin ayrisabilmesi demekti — ve ayristiginda
# kusur SESSIZ olurdu: modal alani cizer, sunucu onu yok sayar, kullanici
# suzgecin calismadigini ancak ciktiya bakip anlar.
#
# BOLUNME: SUNUCU "hangi alanlar", ISTEMCI "nasil cizilir" (etiket, girdi
# turu, secenek kaynagi). Ikisi farkli bilgi turu ve dogru yerde duruyor.
#
# `agir` BAYRAGI (kuyruk kararinin tek kaynagi): brief "buyuk raporlar
# kuyruga girsin" diyor ama "buyuk"un olcusunu istemci bilemez. Sunucu
# hangi raporun tum defteri taradigini bilir; istemci yalnizca bayraga
# bakar ve senkron uc yerine kuyruk ucunu cagirir.


@dataclass(frozen=True)
class GrafikTanimi:
    """(P181 Bölüm 8) Bir raporun GRAFİK yapılandırması — TEK KAYNAK.

    Web (recharts), PDF (reportlab.graphics) ve Excel (openpyxl chart) aynı
    tanımı okur; grafik tipi/eksenleri iki yerde yaşamasın. `x` ve `seriler`
    rapor SÜTUN kimlikleridir (satırdaki alanlar). `tip`: cizgi (zaman serisi),
    sutun (karşılaştırma), pasta (dağılım).
    """

    tip: str  # "cizgi" | "sutun" | "pasta"
    x: str
    seriler: tuple[str, ...]


@dataclass(frozen=True)
class KatalogKaydi:
    baslik: str
    aciklama: str
    #: "listeler" | "ekstreler" | "dokumler" (brief §5'in uc kategorisi).
    kategori: str
    #: Bu raporun ANLAMLANDIRDIGI parametre alanlari.
    alanlar: tuple[str, ...]
    #: Tum defteri tarayan rapor mu? Istemci bunlari KUYRUGA yollar.
    agir: bool = False
    #: (P181 Bölüm 8) Grafik yapılandırması (yoksa yalnız tablo).
    grafik: GrafikTanimi | None = None


KATALOG_KAYITLARI: dict[str, KatalogKaydi] = {}

#: Katalog — kod -> (baslik, aciklama). Tek dogruluk kaynagi: hem `/katalog`
#: ucu hem yonlendirme buradan okur, yani listede gorunup calismayan bir
#: rapor OLAMAZ.
KATALOG_KAYITLARI = {
    # ---------------------------- LISTELER --------------------------------
    "borc_alacak": KatalogKaydi(
        "Borç-Alacak Listesi", "Dönem başı / dönem içi hareket / bakiye",
        "listeler",
        ("baslangic", "bitis", "tazminat_tarihi", "blok", "gelir_gider_tanim_id",
         "listeleme_tipi", "min_tutar_kurus", "max_tutar_kurus", "siralama",
         "ismi_goster", "icradakileri_goster"),
        agir=True,
    ),
    "detayli_borc": KatalogKaydi(
        "Detaylı Borç Listesi", "Gider kalemi başına DİNAMİK sütunlar",
        "listeler",
        # BRIEF "Borclandirma Turu 1* ... Turu 5" diyor — BES AYRI ALAN.
        # O bir MODAL YERLESIMIDIR, veri ise bir LISTEDIR: uc
        # `gelir_gider_tanim_idler` aliyor, modal bes secim cizip listeye
        # dolduruyor. Bes ayri alan adi acsaydik, altincisi istendiginde
        # sozlesme degismek zorunda kalirdi.
        ("baslangic", "bitis", "tazminat_tarihi", "blok",
         "gelir_gider_tanim_idler", "siralama", "ismi_goster"),
        agir=True,
    ),
    "site_sakinleri": KatalogKaydi(
        "Site Sakinleri Listesi", "Daire + sakin + ilişki tipi",
        "listeler",
        # (P168 §3) `iletisim_goster` EKLENDI — brief'in alan listesinde
        # vardi, katalogda yoktu; yani modal o kutuyu HIC cizmiyordu.
        # `ismi_goster` KORUNDU: brief onu saymiyor ama KVKK kontrolu
        # (kapiya asilacak listede ad olmamali) ve kaldirmak bir islev
        # kaybi olurdu.
        ("listeleme_tipi", "blok", "iletisim_goster", "ismi_goster", "imza"),
    ),
    "donemsel_bakiye": KatalogKaydi(
        "Dönemsel Bakiye", "Dönem bazında borç/tahsilat/bakiye",
        "listeler",
        ("blok", "unit_id", "gelir_gider_tanim_id",
         "baslangic_ay", "baslangic_yil", "bitis_ay", "bitis_yil",
         "tazminat_tarihi"),
        # (P181 8) ZAMAN SERİSİ → çizgi: dönem ekseninde borç/tahsilat/bakiye.
        grafik=GrafikTanimi("cizgi", "donem", ("borc", "tahsilat", "bakiye")),
    ),
    "notlar": KatalogKaydi(
        "Notlar", "Kayıtlara düşülen notlar (tarih + oluşturan + bölüm)",
        "listeler",
        ("baslangic", "bitis", "olusturan_user_id", "bolum"),
    ),
    # ---------------------------- EKSTRELER -------------------------------
    "kasa_ekstresi": KatalogKaydi(
        "Kasa Ekstresi", "Kasa bazında hareket dökümü",
        "ekstreler",
        ("kasa_id", "baslangic", "bitis"),
    ),
    "firma_ekstresi": KatalogKaydi(
        "Firma Ekstresi", "Firma bazında gider/gelir dökümü",
        "ekstreler",
        ("firma_id", "ekstre_turu", "baslangic", "bitis"),
    ),
    "hesap_ekstresi": KatalogKaydi(
        "Hesap Ekstresi", "Kişi/daire bazında borç ve tahsilat dökümü",
        "ekstreler",
        ("user_id", "blok", "unit_id", "baslangic", "bitis",
         "tazminat_tarihi", "listeleme_tipi"),
        # (P181 8) BAKİYE EĞİLİMİ → çizgi: tarih ekseninde yürüyen bakiye.
        grafik=GrafikTanimi("cizgi", "tarih", ("bakiye_kurus",)),
    ),
    # ---------------------------- DOKUMLER --------------------------------
    # (P167 §6.3) Brief, Dokuman Yonetimi ekraninda bir Excel disari-aktarim
    # ikonu istiyor. IKINCI BIR EXCEL YAZICISI YAZILMADI: rapor motorunun
    # Excel/PDF hatti zaten var, sutun bicimlendirmesi ve site basligi
    # orada. Ayri bir yazici, para/tarih bicimlerinin iki yerde yasamasi
    # ve birinde duzeltilen bir hatanin otekinde kalmasi olurdu.
    #
    # Yan fayda: liste artik Raporlar ekranindan da alinabiliyor.
    "dokuman_listesi": KatalogKaydi(
        "Doküman Listesi", "Yüklenen dosyalar (ad + yükleyen + tarih + boyut)",
        "dokumler",
        ("baslangic", "bitis"),
    ),
    "isletme_defteri": KatalogKaydi(
        "İşletme Defteri", "Tarih sıralı gelir/gider defteri",
        "dokumler",
        ("baslangic", "bitis", "aciklamalari_goster", "evrak_bilgisi_goster",
         "calisma_sekli"),
        agir=True,
    ),
    "finansal_hareketler": KatalogKaydi(
        "Finansal Hareketler", "Tüm hareket tipleri",
        "dokumler",
        ("baslangic", "bitis", "kasa_id", "listeleme_tipi", "evrak_tipi",
         "gelir_gider_tanim_id", "calisma_sekli"),
        agir=True,
    ),
    "makbuz_dokumu": KatalogKaydi(
        "Makbuz Dökümü", "Tahsilat makbuzları listesi",
        "dokumler",
        # (P168 §3) Brief "Tur*" istiyor -> `evrak_tipi`. Eskiden yalniz
        # `listeleme_tipi` vardi ve makbuzun TURU secilemiyordu.
        ("baslangic", "bitis", "evrak_tipi", "listeleme_tipi", "user_id"),
    ),
    "gelir_gider_ozet": KatalogKaydi(
        "Gelir-Gider Özet", "Kalem bazında gelir/gider toplamı",
        "dokumler",
        ("baslangic", "bitis", "calisma_sekli", "grup_goster"),
        # (P181 8) KARŞILAŞTIRMA → sütun: kalem ekseninde gelir vs gider.
        grafik=GrafikTanimi("sutun", "kalem", ("gelir", "gider")),
    ),
    "ihtar_yazisi": KatalogKaydi(
        "İhtar Yazısı", "Daire başına resmi uyarı (PDF)",
        "dokumler",
        # (P168 §3) Brief "Tarih*" istiyor -> `bitis`. Ihtar bir TARIHE
        # gore yazilir (o gune kadar birikmis borc) ve alan yoktu.
        ("user_id", "unit_id", "bitis", "tazminat_tarihi", "min_tutar_kurus"),
    ),
    # --- BRIEF'IN LISTESINDE OLMAYAN AMA DURAN IKI RAPOR ------------------
    # GENEL KISITLAR: "Mevcut islev kaybolmayacak." Ikisi de P31'de
    # yazildi ve calisiyor; katalogdan cikarmak, var olan bir yetenegi
    # sessizce silmek olurdu. `dokumler` kategorisine kondular.
    "tahsilat_performansi": KatalogKaydi(
        "Tahsilat Performansı", "Tahsilat oranı + yaşlandırma + eğilim",
        "dokumler",
        ("baslangic", "bitis"),
        # (P181 8) EĞİLİM → çizgi: dönem ekseninde borçlandırılan vs tahsil
        # edilen (ikisi de TL, aynı eksen). `oran` (%) FARKLI ölçek olduğundan
        # seriye katılmaz — kuruş TL ekseniyle karıştırmak yanıltırdı.
        grafik=GrafikTanimi("cizgi", "donem", ("borclandirilan", "tahsil")),
    ),
    "denetim_raporu": KatalogKaydi(
        "Denetim Raporu", "Denetçi biçimi: dönem gelir-gider + kasa mutabakatı",
        "dokumler",
        ("baslangic", "bitis"),
    ),
    # (P192 §5.5) MUHASEBECIYE DISA AKTARIM.
    #
    # AYRI BIR UC ACILMADI: rapor motoru zaten Excel/PDF uretiyor, site
    # basligi ve para/tarih bicimleri orada tek yerde. Ikinci bir yazici,
    # ayni bicimlendirmenin iki yerde yasamasi demekti.
    #
    # SUTUNLAR MUHASEBECININ ISTEDIKLERI: tarih, belge no, tur, aciklama,
    # borc/alacak (isaretli DEGIL — iki AYRI sutun; tek sutunda isaretli
    # tutar, muhasebe programlarina aktarmayi zorlastirir), kasa, daire,
    # donem, durum.
    "muhasebe_aktarim": KatalogKaydi(
        "Muhasebeye Aktarım", "Defter dökümü: tarih, belge, borç/alacak, kasa",
        "dokumler",
        ("baslangic", "bitis"),
        agir=True,
    ),
}

#: Kategori SIRASI — brief §5'in sirasi. Istemci bunu kullanir; alfabetik
#: siralamak, "Listeler"i "Dokumler"in altina duşürürdü.
KATEGORI_SIRASI: tuple[str, ...] = ("listeler", "ekstreler", "dokumler")

#: GERIYE DONUK UYUM: dosyanin geri kalani `KATALOG[kod][0]` ile basligi
#: okuyor. Tek kaynak `KATALOG_KAYITLARI`; bu yalnizca ondan TURETILEN bir
#: gorunum — iki liste elle tutulsaydi biri guncellenip oteki unutulurdu.
KATALOG: dict[str, tuple[str, str]] = {
    k: (v.baslik, v.aciklama) for k, v in KATALOG_KAYITLARI.items()
}


@router.get("/raporlar/katalog", response_model=RaporKatalogResponse)
async def katalog(_: AppUser = Depends(_RAPOR_OKUR)) -> RaporKatalogResponse:
    """(P167 §5) Katalog artik KATEGORI, ALAN ve AGIRLIK da tasiyor.

    Istemci karti hangi bolume koyacagini, modalda hangi alanlari
    cizecegini ve senkron mu kuyruk mu cagiracagini BURADAN ogrenir —
    ikinci bir liste tutmaz.
    """
    return RaporKatalogResponse(
        kategoriler=list(KATEGORI_SIRASI),
        items=[
            RaporKatalogOgesi(
                kod=k, baslik=v.baslik, aciklama=v.aciklama,
                kategori=v.kategori, alanlar=list(v.alanlar), agir=v.agir,
                grafik=(
                    RaporGrafikTanimi(
                        tip=v.grafik.tip, x=v.grafik.x, seriler=list(v.grafik.seriler)
                    )
                    if v.grafik
                    else None
                ),
            )
            for k, v in KATALOG_KAYITLARI.items()
        ],
    )


# ------------------------------ veri toplama -------------------------------- #
async def _tenant(db: AsyncSession, user: AppUser) -> Tenant:
    return (
        await db.execute(select(Tenant).where(Tenant.id == user.tenant_id))
    ).scalar_one()


async def _kisi_borclari(
    db: AsyncSession, p: RaporParam, oran
) -> list[dict]:
    """Kisi/daire bazinda donem basi + donem ici toplamlar.

    HEDEFSIZ (daireye yazilmis) tahakkuklar da sayilir ve DAIRE satirinda
    gorunur: P28 oncesi kayitlar hedefsizdir ve raporda kaybolmalari,
    toplamlarin defterle tutmamasi demekti.
    """
    tazminat_gunu = p.tazminat_tarihi or p.bitis or datetime.now(timezone.utc).date()

    q = select(
        DuesAssessment.unit_id,
        Unit.no,
        Unit.blok,
        DuesAssessment.hedef_user_id,
        DuesAssessment.tutar_kurus,
        DuesAssessment.son_odeme_tarihi,
        DuesAssessment.gecikme_uygula,
        DuesAssessment.tarih,
        DuesAssessment.gelir_gider_tanim_id,
    # (P192 §6.3) Ters kayit cifti borc DEGILDIR.
    ).join(Unit, Unit.id == DuesAssessment.unit_id).where(*defter.gecerli_tahakkuk())
    if p.blok:
        q = q.where(Unit.blok == p.blok)
    if p.gelir_gider_tanim_id:
        q = q.where(
            DuesAssessment.gelir_gider_tanim_id == uuid.UUID(p.gelir_gider_tanim_id)
        )
    tahakkuklar = (await db.execute(q)).all()

    hq = select(
        FinansalHareket.unit_id,
        FinansalHareket.user_id,
        FinansalHareket.tip,
        FinansalHareket.tutar_kurus,
        FinansalHareket.tarih,
    ).where(FinansalHareket.tip.in_(["tahsilat", "iade"]))
    hareketler = (await db.execute(hq)).all()

    adlar = dict(
        (await db.execute(select(AppUser.id, AppUser.ad))).all()
    )
    icradakiler = set(
        (await db.execute(select(IcraDosyasi.user_id))).scalars().all()
    )

    kisiler: dict[tuple, dict] = {}

    def _kutu(unit_id, unit_no, user_id):
        anahtar = (unit_id, user_id)
        if anahtar not in kisiler:
            kisiler[anahtar] = {
                "unit_no": unit_no,
                "ad": adlar.get(user_id) if user_id else None,
                "bas_ana_para": 0, "bas_gecikme": 0,
                "ici_borc": 0, "ici_gecikme": 0,
                "ici_iade": 0, "ici_tahsilat": 0,
                "icrada": user_id in icradakiler if user_id else False,
                "kalemler": {},
            }
        return kisiler[anahtar]

    for uid, no, _blok, hedef, tutar, vade, gec_uygula, tarih, tanim in tahakkuklar:
        k = _kutu(uid, no, hedef)
        gec = gecikme_kurus(
            int(tutar), vade, tazminat_gunu, oran, uygula=bool(gec_uygula)
        )
        oncesi = p.baslangic is not None and tarih is not None and tarih < p.baslangic
        sonrasi = p.bitis is not None and tarih is not None and tarih > p.bitis
        if sonrasi:
            continue
        if oncesi:
            k["bas_ana_para"] += int(tutar)
            k["bas_gecikme"] += gec
        else:
            k["ici_borc"] += int(tutar)
            k["ici_gecikme"] += gec
        anahtar = str(tanim) if tanim else "diger"
        k["kalemler"][anahtar] = k["kalemler"].get(anahtar, 0) + int(tutar)

    for uid, kullanici, tip, tutar, tarih in hareketler:
        if p.baslangic and tarih and tarih < p.baslangic:
            continue
        if p.bitis and tarih and tarih > p.bitis:
            continue
        k = _kutu(uid, None, kullanici)
        if tip == "tahsilat":
            k["ici_tahsilat"] += int(tutar)
        else:
            k["ici_iade"] += int(tutar)

    return list(kisiler.values())


# --------------------------------- katalog ---------------------------------- #
async def _uret(
    db: AsyncSession, user: AppUser, kod: str, p: RaporParam
) -> RaporSonuc:
    tenant = await _tenant(db, user)
    oran = tenant.gecikme_aylik_yuzde

    if kod == "borc_alacak":
        return borc_alacak_satirlari(await _kisi_borclari(db, p, oran), [], p)

    if kod == "detayli_borc":
        kalemler = [
            {"id": str(i), "ad": a}
            for i, a in (
                await db.execute(
                    select(GelirGiderTanim.id, GelirGiderTanim.ad)
                    .where(GelirGiderTanim.tip != "gelir")
                    .order_by(GelirGiderTanim.ad)
                )
            ).all()
        ]
        return detayli_borc_satirlari(
            await _kisi_borclari(db, p, oran), kalemler, p
        )

    # ---------------- (P167 §5) NOTLAR — brief'in yeni raporu -------------
    #
    # KAYNAK `varlik_eki` (P154 §6.4): tur='not' olan satirlar. Ayri bir
    # "not" tablosu ACILMADI — notlar zaten orada duruyor ve ikinci bir
    # yer, ayni metnin iki kaynaktan okunabilmesi demekti.
    #
    # "BOLUM" = `varlik_tipi` (daire, gorev, talep, icra dosyasi...).
    # Brief'in adlandirmasi kullanicinin gordugu sey; sutun adi ise
    # veritabaninin. Ikisini eslestirmek raporun isi.
    if kod == "notlar":
        kosullar = [VarlikEki.tur == "not"]
        if p.baslangic:
            kosullar.append(VarlikEki.created_at >= p.baslangic)
        if p.bitis:
            # BITIS GUNU DAHIL: `created_at` bir zaman damgasi, `bitis` bir
            # gun. `<= bitis` yazsaydik o gunun 00:00'dan sonraki butun
            # notlari DISARIDA kalirdi — kullanicinin "31 Mart'a kadar"
            # dedigi sey 31 Mart'in tamamidir.
            kosullar.append(VarlikEki.created_at < p.bitis + timedelta(days=1))
        if p.olusturan_user_id:
            kosullar.append(VarlikEki.olusturan_user_id == p.olusturan_user_id)
        if p.bolum:
            kosullar.append(VarlikEki.varlik_tipi == p.bolum)
        rows = (
            await db.execute(
                select(
                    VarlikEki.created_at, VarlikEki.varlik_tipi,
                    VarlikEki.metin, AppUser.ad,
                )
                .join(AppUser, AppUser.id == VarlikEki.olusturan_user_id, isouter=True)
                .where(*kosullar)
                .order_by(VarlikEki.created_at.desc(), VarlikEki.id.desc())
            )
        ).all()
        return RaporSonuc(
            kod, KATALOG[kod][0],
            [
                Sutun("tarih", "Tarih", tip="tarih", genislik=2),
                Sutun("bolum", "Bölüm", genislik=2),
                Sutun("olusturan", "Oluşturan", genislik=2),
                Sutun("metin", "Not", genislik=5),
            ],
            [
                {"tarih": ts.date().isoformat(), "bolum": tip,
                 "olusturan": ad or "—", "metin": metin or ""}
                for ts, tip, metin, ad in rows
            ],
        )

    # ---------------- (P167 §6.3) DOKUMAN LISTESI -------------------------
    #
    # SILINMISLER DISARIDA: ekranda gorunmeyen bir satirin Excel'de
    # gorunmesi, iki ciktinin ayni soruya farkli cevap vermesi olurdu.
    if kod == "dokuman_listesi":
        kosullar = [TenantDokuman.silindi_at.is_(None)]
        if p.baslangic:
            kosullar.append(TenantDokuman.created_at >= p.baslangic)
        if p.bitis:
            # BITIS GUNU DAHIL (notlar raporuyla ayni gerekce).
            kosullar.append(
                TenantDokuman.created_at < p.bitis + timedelta(days=1)
            )
        rows = (
            await db.execute(
                select(
                    TenantDokuman.created_at, TenantDokuman.ad,
                    TenantDokuman.boyut_bayt, AppUser.ad,
                )
                .join(
                    AppUser,
                    AppUser.id == TenantDokuman.yukleyen_user_id,
                    isouter=True,
                )
                .where(*kosullar)
                .order_by(
                    TenantDokuman.created_at.desc(), TenantDokuman.id.desc()
                )
            )
        ).all()
        return RaporSonuc(
            kod, KATALOG[kod][0],
            [
                Sutun("tarih", "Eklenme Tarihi", tip="tarih", genislik=2),
                Sutun("ad", "Doküman Adı", genislik=5),
                Sutun("yukleyen", "Yükleyen", genislik=2),
                # BOYUT "sayi": Excel'de TOPLAM alinabilsin. Metin olarak
                # "1,2 MB" yazsaydik hucre toplanamazdi.
                Sutun("boyut_kb", "Boyut (KB)", tip="sayi", genislik=1),
            ],
            [
                {
                    "tarih": ts.date().isoformat(),
                    "ad": ad,
                    "yukleyen": yukleyen or "—",
                    # TAM SAYIYA YUVARLANIR: bayt gostermek okunmaz,
                    # ondalikli KB ise sahte bir hassasiyet olurdu.
                    "boyut_kb": round((boyut or 0) / 1024) or None,
                }
                for ts, ad, boyut, yukleyen in rows
            ],
        )

    # ---------------- (P167 §5) FIRMA EKSTRESI ----------------------------
    #
    # Firma bazli gider/gelir dokumu. `kasa_ekstresi` ile AYNI SEKIL ama
    # farkli eksen: biri PARANIN NEREDE durdugunu, oteki KIMINLE
    # calisildigini anlatir.
    if kod == "firma_ekstresi":
        kosullar = [FinansalHareket.firma_id.is_not(None)]
        if p.firma_id:
            kosullar.append(FinansalHareket.firma_id == p.firma_id)
        if p.baslangic:
            kosullar.append(FinansalHareket.tarih >= p.baslangic)
        if p.bitis:
            kosullar.append(FinansalHareket.tarih <= p.bitis)
        rows = (
            await db.execute(
                select(
                    FinansalHareket.tarih, FinansalHareket.belge_no,
                    FinansalHareket.tip, FinansalHareket.yon,
                    FinansalHareket.tutar_kurus, FinansalHareket.aciklama,
                    Firma.ad,
                )
                .join(Firma, Firma.id == FinansalHareket.firma_id, isouter=True)
                .where(*kosullar)
                .order_by(FinansalHareket.tarih, FinansalHareket.id)
            )
        ).all()
        satirlar = [
            {"tarih": tarih.isoformat(), "belge_no": belge or "—",
             "firma": firma or "—", "tip": tip,
             # YON ISARETI TUTARA GOMULUR: ekstrede "cikis" yazip tutari
             # arti gostermek, toplami gozle almayi imkansiz kilardi.
             "tutar_kurus": tutar if yon == "giris" else -tutar,
             "aciklama": aciklama or ""}
            for tarih, belge, tip, yon, tutar, aciklama, firma in rows
        ]
        sonuc = RaporSonuc(
            kod, KATALOG[kod][0],
            [
                Sutun("tarih", "Tarih", tip="tarih", genislik=2),
                Sutun("belge_no", "Belge No", genislik=2),
                Sutun("firma", "Firma", genislik=3),
                Sutun("tip", "Tür", genislik=2),
                Sutun("tutar_kurus", "Tutar", tip="kurus", genislik=2),
                Sutun("aciklama", "Açıklama", genislik=4),
            ],
            satirlar,
        )
        sonuc.toplamlar = {
            "tutar_kurus": sum(r["tutar_kurus"] for r in satirlar),
        }
        return sonuc

    # ---------------- (P167 §5) HESAP EKSTRESI ----------------------------
    #
    # Kisi/daire bazli BORC ve TAHSILAT dokumu — tek zaman cizgisinde.
    #
    # NEDEN IKI KAYNAK TEK LISTEDE: bir sakinin "hesabi" borclarindan ve
    # odemelerinden olusur. Ikisini ayri tablo gostermek, kullaniciyi
    # bakiyeyi kafadan hesaplamaya birakirdi.
    if kod == "hesap_ekstresi":
        borc_kosul = []
        tahsil_kosul = [FinansalHareket.tip == "tahsilat"]
        if p.baslangic:
            borc_kosul.append(DuesAssessment.tarih >= p.baslangic)
            tahsil_kosul.append(FinansalHareket.tarih >= p.baslangic)
        if p.bitis:
            borc_kosul.append(DuesAssessment.tarih <= p.bitis)
            tahsil_kosul.append(FinansalHareket.tarih <= p.bitis)
        if p.unit_id:
            borc_kosul.append(DuesAssessment.unit_id == p.unit_id)
            tahsil_kosul.append(FinansalHareket.unit_id == p.unit_id)
        if p.user_id:
            borc_kosul.append(DuesAssessment.hedef_user_id == p.user_id)
            tahsil_kosul.append(FinansalHareket.user_id == p.user_id)

        borclar = (
            await db.execute(
                select(DuesAssessment.tarih, DuesAssessment.donem,
                       DuesAssessment.tutar_kurus, Unit.no, Unit.blok)
                .join(Unit, Unit.id == DuesAssessment.unit_id, isouter=True)
                .where(*borc_kosul, *defter.gecerli_tahakkuk())
            )
        ).all()
        tahsilatlar = (
            await db.execute(
                select(FinansalHareket.tarih, FinansalHareket.belge_no,
                       FinansalHareket.tutar_kurus, Unit.no, Unit.blok)
                .join(Unit, Unit.id == FinansalHareket.unit_id, isouter=True)
                .where(*tahsil_kosul)
            )
        ).all()

        satirlar = []
        for tarih, donem, tutar, no, blok in borclar:
            if p.blok and blok != p.blok:
                continue
            satirlar.append({
                "tarih": (tarih or date.today()).isoformat(),
                "unit_no": no or "—", "aciklama": f"Tahakkuk {donem}",
                "borc_kurus": tutar, "alacak_kurus": 0,
            })
        for tarih, belge, tutar, no, blok in tahsilatlar:
            if p.blok and blok != p.blok:
                continue
            satirlar.append({
                "tarih": tarih.isoformat(),
                "unit_no": no or "—",
                "aciklama": f"Tahsilat {belge or ''}".strip(),
                "borc_kurus": 0, "alacak_kurus": tutar,
            })
        satirlar.sort(key=lambda r: (r["tarih"], r["unit_no"]))

        # YURUYEN BAKIYE: ekstrenin varlik sebebi. Satir satir borc/alacak
        # gostermek yetmez — kullanicinin sordugu sey "su an ne kadar".
        bakiye = 0
        for r in satirlar:
            bakiye += r["borc_kurus"] - r["alacak_kurus"]
            r["bakiye_kurus"] = bakiye

        if p.listeleme_tipi == "borclu":
            satirlar = [r for r in satirlar if r["borc_kurus"]]
        elif p.listeleme_tipi == "alacakli":
            satirlar = [r for r in satirlar if r["alacak_kurus"]]

        sonuc = RaporSonuc(
            kod, KATALOG[kod][0],
            [
                Sutun("tarih", "Tarih", tip="tarih", genislik=2),
                Sutun("unit_no", "Bağımsız Bölüm", genislik=2),
                Sutun("aciklama", "Açıklama", genislik=4),
                Sutun("borc_kurus", "Borç", tip="kurus", genislik=2),
                Sutun("alacak_kurus", "Alacak", tip="kurus", genislik=2),
                Sutun("bakiye_kurus", "Bakiye", tip="kurus", genislik=2),
            ],
            satirlar,
        )
        sonuc.toplamlar = {
            "borc_kurus": sum(r["borc_kurus"] for r in satirlar),
            "alacak_kurus": sum(r["alacak_kurus"] for r in satirlar),
        }
        return sonuc

    if kod == "site_sakinleri":
        rows = (
            await db.execute(
                select(
                    Unit.no, Unit.blok, AppUser.ad, UnitResident.rol_tipi,
                    AppUser.telefon, AppUser.email,
                )
                .join(UnitResident, UnitResident.unit_id == Unit.id)
                .join(AppUser, AppUser.id == UnitResident.user_id)
                .where(UnitResident.bitis.is_(None))
                .order_by(Unit.no)
            )
        ).all()
        sutunlar = [
            Sutun("unit_no", "Bağımsız Bölüm", genislik=2),
            Sutun("blok", "Blok"),
            Sutun("ad", "Ad Soyad", genislik=3),
            Sutun("rol_tipi", "İlişki Tipi", genislik=2),
        ]
        if not p.ismi_goster:
            sutunlar = [s for s in sutunlar if s.anahtar != "ad"]
        # (P168 §3) ILETISIM SUTUNLARI ISTEGE BAGLI VE VARSAYILAN KAPALI.
        #
        # Kutu SUTUN ACAR, degeri bosaltmaz: bos bir "Telefon" sutunu
        # "bu kisinin telefonu yok" demek olurdu — oysa gostermemeyi biz
        # sectik. (Ayni gerekce `ismi_goster` icin P31'de de yazilmisti.)
        if p.iletisim_goster:
            sutunlar += [
                Sutun("telefon", "Telefon", genislik=2),
                Sutun("email", "E-posta", genislik=3),
            ]
        satirlar = [
            {"unit_no": no, "blok": blok,
             **({"ad": ad} if p.ismi_goster else {}),
             "rol_tipi": rol or "—",
             **({"telefon": tel or "—", "email": eposta or "—"}
                if p.iletisim_goster else {})}
            for no, blok, ad, rol, tel, eposta in rows
            if not p.blok or blok == p.blok
        ]
        return RaporSonuc(kod, KATALOG[kod][0], sutunlar,
                          sirala(satirlar, p.siralama, "unit_no"))

    if kod == "donemsel_bakiye":
        borc = dict(
            (await db.execute(
                select(DuesAssessment.donem, func.sum(DuesAssessment.tutar_kurus))
                .where(*defter.gecerli_tahakkuk())
                .group_by(DuesAssessment.donem)
            )).all()
        )
        tahsil = dict(
            (await db.execute(
                # `func.to_char(...)` BIND PARAMETRESI uretir ve Postgres
                # GROUP BY'daki ifadeyle eslestiremez (GroupingError —
                # seffaflik panosunda da yasanmisti). `literal_column`
                # ifadeyi OLDUGU GIBI gomer.
                select(
                    _DONEM_IFADESI,
                    func.sum(FinansalHareket.tutar_kurus),
                )
                .where(FinansalHareket.tip == "tahsilat")
                .group_by(_DONEM_IFADESI)
            )).all()
        )
        donemler = sorted(set(borc) | set(tahsil))
        satirlar = []
        birikimli = 0
        for d in donemler:
            b, t = int(borc.get(d, 0)), int(tahsil.get(d, 0))
            birikimli += b - t
            satirlar.append({"donem": d, "borc": b, "tahsilat": t,
                             "bakiye": birikimli})
        return RaporSonuc(kod, KATALOG[kod][0], [
            Sutun("donem", "Dönem", genislik=2),
            Sutun("borc", "Borçlandırma", "kurus", 2),
            Sutun("tahsilat", "Tahsilat", "kurus", 2),
            Sutun("bakiye", "Birikimli Bakiye", "kurus", 2),
        ], satirlar)

    if kod in ("kasa_ekstresi", "isletme_defteri", "finansal_hareketler",
               "makbuz_dokumu"):
        return await _hareket_raporu(db, kod, p)

    if kod == "gelir_gider_ozet":
        rows = (
            await db.execute(
                select(
                    GelirGiderTanim.ad,
                    FinansalHareket.tip,
                    func.sum(FinansalHareket.tutar_kurus),
                )
                .join(
                    GelirGiderTanim,
                    GelirGiderTanim.id == FinansalHareket.gelir_gider_tanim_id,
                )
                .where(FinansalHareket.tip.in_(["gelir", "gider"]))
                .group_by(GelirGiderTanim.ad, FinansalHareket.tip)
            )
        ).all()
        birlesik: dict[str, dict] = {}
        for ad, tip, toplam in rows:
            kutu = birlesik.setdefault(ad, {"kalem": ad, "gelir": 0, "gider": 0})
            kutu[tip] += int(toplam)
        satirlar = list(birlesik.values())
        for s in satirlar:
            s["fark"] = s["gelir"] - s["gider"]
        sutunlar = [
            Sutun("kalem", "Kalem", genislik=3),
            Sutun("gelir", "Gelir", "kurus", 2),
            Sutun("gider", "Gider", "kurus", 2),
            Sutun("fark", "Fark", "kurus", 2),  # grafik: kalem→gelir/gider (sütun)
        ]
        return RaporSonuc(kod, KATALOG[kod][0], sutunlar, satirlar, {
            a: sum(s[a] for s in satirlar) for a in ("gelir", "gider", "fark")
        })

    if kod == "tahsilat_performansi":
        return await _tahsilat_performansi(db, p, oran)

    if kod == "denetim_raporu":
        return await _denetim(db, p)

    if kod == "muhasebe_aktarim":
        return await _muhasebe_aktarim(db, p)

    if kod == "ihtar_yazisi":
        return await _ihtar(db, user, p)

    raise APIError(404, "not_found", "rapor_bulunamadi")


async def _hareket_raporu(db: AsyncSession, kod: str, p: RaporParam) -> RaporSonuc:
    """Dort hareket raporu AYNI sorgudan, farkli SUZGECLE cikar.

    Dort ayri sorgu yazmak, "işletme defterinde gorunen tutar finansal
    hareketlerde neden yok" tipi sessiz farklar uretirdi.
    """
    q = select(
        FinansalHareket.tarih, FinansalHareket.tip, FinansalHareket.yon,
        FinansalHareket.tutar_kurus, FinansalHareket.belge_no,
        FinansalHareket.aciklama, Kasa.ad, AppUser.ad,
    ).join(Kasa, Kasa.id == FinansalHareket.kasa_id, isouter=True) \
     .join(AppUser, AppUser.id == FinansalHareket.user_id, isouter=True)

    if kod == "makbuz_dokumu":
        q = q.where(FinansalHareket.tip == "tahsilat")
    elif kod == "isletme_defteri":
        q = q.where(FinansalHareket.tip.in_(["gelir", "gider"]))
    if p.baslangic:
        q = q.where(FinansalHareket.tarih >= p.baslangic)
    if p.bitis:
        q = q.where(FinansalHareket.tarih <= p.bitis)

    satirlar = [
        {"tarih": t.isoformat() if t else "", "tip": tip, "yon": yon,
         "tutar_kurus": int(tutar), "belge_no": belge or "",
         "aciklama": acik or "", "kasa": kasa or "",
         **({"kisi": kisi or ""} if p.ismi_goster else {})}
        for t, tip, yon, tutar, belge, acik, kasa, kisi in
        (await db.execute(q.order_by(FinansalHareket.tarih))).all()
    ]
    sutunlar = [
        Sutun("tarih", "Tarih", "tarih", 2),
        Sutun("tip", "Tip", genislik=2),
        Sutun("yon", "Yön"),
        Sutun("kasa", "Kasa", genislik=2),
    ]
    if p.ismi_goster:
        sutunlar.append(Sutun("kisi", "Kişi", genislik=3))
    sutunlar += [
        Sutun("belge_no", "Belge No", genislik=2),
        Sutun("aciklama", "Açıklama", genislik=4),
        Sutun("tutar_kurus", "Tutar", "kurus", 2),
    ]
    return RaporSonuc(kod, KATALOG[kod][0], sutunlar, satirlar, {
        "tutar_kurus": sum(s["tutar_kurus"] for s in satirlar)
    })


async def _tahsilat_performansi(
    db: AsyncSession, p: RaporParam, oran
) -> RaporSonuc:
    borc = dict(
        (await db.execute(
            select(DuesAssessment.donem, func.sum(DuesAssessment.tutar_kurus))
            .where(*defter.gecerli_tahakkuk())
            .group_by(DuesAssessment.donem)
        )).all()
    )
    tahsil = dict(
        (await db.execute(
            select(
                _DONEM_IFADESI,
                func.sum(FinansalHareket.tutar_kurus),
            )
            .where(FinansalHareket.tip == "tahsilat",
                   FinansalHareket.durum == defter.GERCEKLESEN)
            .group_by(_DONEM_IFADESI)
        )).all()
    )
    donemler = [
        {"donem": d, "borclandirilan": int(borc.get(d, 0)),
         "tahsil": int(tahsil.get(d, 0))}
        for d in sorted(set(borc) | set(tahsil))
    ]

    # YASLANDIRMA: vadesi gecmis borclarin kova dagilimi.
    bugun = p.tazminat_tarihi or datetime.now(timezone.utc).date()
    vadeli = (
        await db.execute(
            select(DuesAssessment.son_odeme_tarihi, DuesAssessment.tutar_kurus)
            .where(DuesAssessment.son_odeme_tarihi.is_not(None),
                   *defter.gecerli_tahakkuk())
        )
    ).all()
    kovalar = {"0-30 gün": 0, "31-60 gün": 0, "61-90 gün": 0, "90+ gün": 0}
    for vade, tutar in vadeli:
        gun = (bugun - vade).days
        if gun <= 0:
            continue
        if gun <= 30:
            kovalar["0-30 gün"] += int(tutar)
        elif gun <= 60:
            kovalar["31-60 gün"] += int(tutar)
        elif gun <= 90:
            kovalar["61-90 gün"] += int(tutar)
        else:
            kovalar["90+ gün"] += int(tutar)
    _ = oran
    return tahsilat_performansi(
        donemler, [{"kova": k, "tutar_kurus": v} for k, v in kovalar.items()]
    )


async def _muhasebe_aktarim(db: AsyncSession, p: RaporParam) -> RaporSonuc:
    """(P192 §5.5) MUHASEBECIYE DEFTER DOKUMU.

    BORC ve ALACAK AYRI SUTUN: tek sutunda isaretli tutar vermek,
    muhasebe programlarina aktarmayi zorlastirir (cogu iki sutun bekler)
    ve isaretin yonunu okuyanin yorumuna birakirdi.

    ONAY BEKLEYEN ve IPTAL SATIRLARI DISARIDA: muhasebeciye giden dokum
    GERCEKLESMIS hareketlerin dokumudur; onaylanmamis bir gideri
    aktarmak, defterde olmayan bir kaydi muhasebeye sokmak olurdu.
    """
    where = [FinansalHareket.durum == defter.GERCEKLESEN]
    if p.baslangic:
        where.append(FinansalHareket.tarih >= p.baslangic)
    if p.bitis:
        where.append(FinansalHareket.tarih <= p.bitis)

    rows = (
        await db.execute(
            select(
                FinansalHareket.tarih,
                FinansalHareket.belge_no,
                FinansalHareket.tip,
                FinansalHareket.yon,
                FinansalHareket.tutar_kurus,
                FinansalHareket.aciklama,
                FinansalHareket.donem,
                Kasa.kod,
                Unit.no,
            )
            .outerjoin(Kasa, Kasa.id == FinansalHareket.kasa_id)
            .outerjoin(Unit, Unit.id == FinansalHareket.unit_id)
            .where(*where)
            .order_by(FinansalHareket.tarih, FinansalHareket.belge_no,
                      FinansalHareket.id)
        )
    ).all()

    satirlar = [
        {
            "tarih": tarih.isoformat() if tarih else "",
            "belge_no": belge or "",
            "tur": tip,
            "aciklama": aciklama or "",
            # BORC = kasadan CIKAN, ALACAK = kasaya GIREN. Muhasebe
            # terminolojisi KASA acisindandir.
            "borc": int(tutar) if yon == "cikis" else 0,
            "alacak": int(tutar) if yon == "giris" else 0,
            "kasa": kasa_kod or "",
            "daire": daire_no or "",
            "donem": donem or "",
        }
        for tarih, belge, tip, yon, tutar, aciklama, donem, kasa_kod, daire_no
        in rows
    ]
    sutunlar = [
        Sutun("tarih", "Tarih", genislik=2),
        Sutun("belge_no", "Belge No", genislik=2),
        Sutun("tur", "Tür", genislik=2),
        Sutun("aciklama", "Açıklama", genislik=4),
        Sutun("borc", "Borç", "kurus", 2),
        Sutun("alacak", "Alacak", "kurus", 2),
        Sutun("kasa", "Kasa", genislik=2),
        Sutun("daire", "Daire", genislik=2),
        Sutun("donem", "Dönem", genislik=2),
    ]
    return RaporSonuc(
        "muhasebe_aktarim", KATALOG["muhasebe_aktarim"][0], sutunlar, satirlar,
        {
            "borc": sum(s["borc"] for s in satirlar),
            "alacak": sum(s["alacak"] for s in satirlar),
        },
    )


async def _denetim(db: AsyncSession, p: RaporParam) -> RaporSonuc:
    """**Denetim Raporu** — denetci bicimi.

    Kasa MUTABAKATI raporun cekirdegidir: acilis + hareketler = bakiye
    esitligini SATIR SATIR gosterir. Denetci "rakam nereden geliyor"
    sorusunu bu tabloda cevaplayabilmeli; tek bir toplam yazmak
    mutabakat degil beyandir.
    """
    kasalar = (await db.execute(select(Kasa).order_by(Kasa.kod))).scalars().all()
    # (P192 §2.2) YALNIZ GERCEKLESMIS hareketler. Suzgec yokken onay
    # bekleyen bir gider mutabakat tablosunda cikis olarak gorunuyor ve
    # "acilis + hareket = bakiye" esitligi kasa bakiyeleri ekraniyla
    # ayrisiyordu.
    #
    # (Burada daha once bir OLU SATIR vardi: sorgu calistirilip sonucu
    # `and []` ile atiliyordu; `docs/finans-analiz.md` raporladi.)
    hareket: dict = {}
    ham = (
        await db.execute(
            select(FinansalHareket.kasa_id, FinansalHareket.yon,
                   func.sum(FinansalHareket.tutar_kurus))
            .where(FinansalHareket.durum == defter.GERCEKLESEN)
            .group_by(FinansalHareket.kasa_id, FinansalHareket.yon)
        )
    ).all()
    for kid, yon, toplam in ham:
        hareket.setdefault(kid, {"giris": 0, "cikis": 0})[yon] = int(toplam)

    satirlar = []
    for k in kasalar:
        h = hareket.get(k.id, {"giris": 0, "cikis": 0})
        giris, cikis = h.get("giris", 0), h.get("cikis", 0)
        satirlar.append({
            "kasa": f"{k.kod} · {k.ad}",
            "acilis": k.acilis_bakiye_kurus,
            "giris": giris, "cikis": cikis,
            "bakiye": k.acilis_bakiye_kurus + giris - cikis,
        })
    sutunlar = [
        Sutun("kasa", "Kasa", genislik=3),
        Sutun("acilis", "Açılış", "kurus", 2),
        Sutun("giris", "Giriş", "kurus", 2),
        Sutun("cikis", "Çıkış", "kurus", 2),
        Sutun("bakiye", "Bakiye", "kurus", 2),
    ]
    sonuc = RaporSonuc("denetim_raporu", KATALOG["denetim_raporu"][0],
                       sutunlar, satirlar, {
        a: sum(s[a] for s in satirlar)
        for a in ("acilis", "giris", "cikis", "bakiye")
    })
    gelir = sum(s["giris"] for s in satirlar)
    gider = sum(s["cikis"] for s in satirlar)
    sonuc.metin = (
        f"Dönem gelir toplamı: {kurus_metin(gelir)} TL · "
        f"Dönem gider toplamı: {kurus_metin(gider)} TL · "
        f"Fark: {kurus_metin(gelir - gider)} TL\n"
        "Karar defteri referansları: yönetim kurulu karar numaraları bu "
        "rapora EKLENMEZ; karar defteri ayrı bir kayıttır ve denetçiye "
        "aslı ile sunulur."
    )
    return sonuc


async def _ihtar(db: AsyncSession, user: AppUser, p: RaporParam) -> RaporSonuc:
    """**İhtar Yazısı** — borclu daire basina resmi metin.

    Tek bir PDF'te ARDI ARDINA uretilir: daire basina ayri dosya, 40 daireli
    bir sitede 40 indirme demekti.
    """
    tenant = await _tenant(db, user)
    kisiler = await _kisi_borclari(db, p, tenant.gecikme_aylik_yuzde)
    bugun = p.tazminat_tarihi or datetime.now(timezone.utc).date()
    parcalar = []
    for k in kisiler:
        borc = (k["bas_ana_para"] + k["ici_borc"]) - k["ici_tahsilat"]
        gec = k["bas_gecikme"] + k["ici_gecikme"]
        if borc <= 0:
            continue
        if p.min_tutar_kurus is not None and borc < p.min_tutar_kurus:
            continue
        parcalar.append(ihtar_metni(
            tenant.ad, k.get("ad") or "İlgili Bağımsız Bölüm Maliki",
            k.get("unit_no") or "—", borc, gec, bugun,
        ))
    sonuc = RaporSonuc("ihtar_yazisi", KATALOG["ihtar_yazisi"][0], [], [])
    sonuc.metin = ("\n\n" + "-" * 60 + "\n\n").join(parcalar) or \
        "Ödenmemiş borcu olan bağımsız bölüm bulunmamaktadır."
    return sonuc


def _param(body: RaporParametre) -> RaporParam:
    """Pydantic govdesini rapor motorunun dataclass'ina cevir.

    DUZ `**model_dump()` YETMEZ: pydantic `uuid.UUID` ve `list` uretir,
    dataclass ise `str` ve `tuple` bekliyor (sorgu karsilastirmalari metin
    uzerinden yapiliyor). Donusumu tek yerde yapmak, her cagri yerinde
    unutulabilecek bir adimi ortadan kaldiriyor.
    """
    ham = body.model_dump()
    for alan in (
        "gelir_gider_tanim_id", "kasa_id", "firma_id", "user_id", "unit_id",
        "olusturan_user_id",
    ):
        if ham.get(alan) is not None:
            ham[alan] = str(ham[alan])
    ham["gelir_gider_tanim_idler"] = tuple(
        str(x) for x in (ham.get("gelir_gider_tanim_idler") or [])
    )
    return RaporParam(**ham)


# --------------------------------- uc --------------------------------------- #
@router.post("/raporlar/{kod}")
async def rapor_uret(
    kod: str,
    body: RaporParametre,
    bicim: str = Query("tablo", description="tablo | excel | pdf"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_RAPOR_OKUR),
):
    """Raporu UC BICIMDEN biriyle uret.

    Bicim basina ayri uc acmak, ayni parametre modelini uc kez dogrulamak
    ve uc yerde degistirmek demekti.
    """
    if kod not in KATALOG:
        raise APIError(404, "not_found", "rapor_bulunamadi")
    if bicim not in ("tablo", "excel", "pdf"):
        raise APIError(422, "validation_error", "gecersiz_rapor_bicimi")

    p = _param(body)
    sonuc = await _uret(db, user, kod, p)
    tenant = await _tenant(db, user)

    if bicim == "tablo":
        return RaporTablo(
            kod=sonuc.kod, baslik=sonuc.baslik,
            sutunlar=[
                {"anahtar": s.anahtar, "baslik": s.baslik, "tip": s.tip}
                for s in sonuc.sutunlar
            ],
            satirlar=sonuc.satirlar, toplamlar=sonuc.toplamlar,
            metin=sonuc.metin,
        )

    # (P181 Bölüm 8) Grafik yapılandırması katalogda; Excel/PDF çıktısına
    # gömülür (web/PDF/Excel aynı tek kaynağı okur).
    kayit = KATALOG_KAYITLARI.get(sonuc.kod)
    grafik = kayit.grafik if kayit else None
    if bicim == "excel":
        icerik = excel_uret(sonuc, tenant.ad, p.baslangic, p.bitis, grafik=grafik)
        tur = ("application/vnd.openxmlformats-officedocument"
               ".spreadsheetml.sheet")
        uzanti = "xlsx"
    else:
        icerik = (
            metin_pdf(sonuc.baslik, sonuc.metin or "", tenant.ad)
            if not sonuc.sutunlar
            else pdf_uret(sonuc, tenant.ad, p.baslangic, p.bitis, grafik=grafik)
        )
        tur = "application/pdf"
        uzanti = "pdf"

    gun = datetime.now(timezone.utc).strftime("%Y%m%d")
    return Response(
        content=icerik,
        media_type=tur,
        headers={
            "Content-Disposition":
                f'attachment; filename="{kod}-{gun}.{uzanti}"',
        },
    )


# =========================================================================== #
# (P167 Asama 5) KUYRUK — agir raporlar arka planda
# =========================================================================== #
#
# NEDEN AYRI UC, "otomatik kuyruga al" DEGIL: senkron uc bir DOSYA doner,
# kuyruk ucu bir IS KIMLIGI. Ayni ucun bazen dosya bazen kimlik dondurmesi,
# her cagri yerini iki yaniti da ayirt etmeye zorlardi — ve o ayrimi
# unutan bir istemci, JSON'u dosya diye indirirdi.
#
# HANGI RAPORUN AGIR OLDUGUNU SUNUCU SOYLER (`KATALOG_KAYITLARI[...].agir`)
# ve istemci ona gore hangi ucu cagiracagini secer. Olcu istemcide
# olsaydi, yeni bir agir rapor eklendiginde arayuz onu senkron cagirmaya
# devam ederdi.


@router.post("/raporlar/{kod}/kuyruk", response_model=RaporIsOut, status_code=202)
async def rapor_kuyruga_al(
    kod: str,
    body: RaporParametre,
    bicim: str = Query("excel", description="excel | pdf"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_RAPOR_OKUR),
) -> RaporIsi:
    """Raporu KUYRUGA al — 202 + is kimligi doner, dosya DEGIL.

    `bicim=tablo` KABUL EDILMEZ: tablo ciktisi ekranda gosterilir ve zaten
    hizlidir; onu kuyruga almak, kullaniciyi gormek istedigi seyi beklemeye
    zorlamak olurdu.
    """
    if kod not in KATALOG:
        raise APIError(404, "not_found", "rapor_bulunamadi")
    if bicim not in ("excel", "pdf"):
        raise APIError(422, "validation_error", "gecersiz_rapor_bicimi")

    isim = RaporIsi(
        tenant_id=user.tenant_id, user_id=user.id, kod=kod, bicim=bicim,
        # PARAMETRE JSON OLARAK SAKLANIR: is kuyruga girdikten sonra
        # kullanicinin sectigi suzgecler DEGISMEMELI.
        parametre=body.model_dump(mode="json"),
    )
    db.add(isim)
    await db.flush()
    await db.refresh(isim)

    # GOREV COMMIT'TEN SONRA GONDERILMELI ama `get_tenant_db` cikista
    # commit ediyor. `after_commit` kancasi yerine gorev BURADA
    # gonderiliyor ve `rapor_kuyruk.isi_uret` satiri BULAMAZSA sessizce
    # cikiyor ("bulunamadi") — worker istegi commit'ten once alirsa bir
    # sonraki denemede bulur. Alternatif (commit kancasi) bu router'i
    # oturum yasam dongusune baglardi.
    from ..tasks import rapor_uret_gorevi

    rapor_uret_gorevi.delay(str(isim.id))
    return isim


@router.get("/raporlar/isler", response_model=list[RaporIsOut])
async def rapor_islerim(
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_RAPOR_OKUR),
) -> list[RaporIsi]:
    """KENDI rapor islerim — en yeni ustte.

    YALNIZ KENDI: rapor ciktisi kisi adlari ve site finansi tasir; ayni
    tesisteki baska bir yoneticinin BASKASININ istedigi dosyayi indirmesi
    icin bir sebep yok. Suzgec sorgunun icinde.
    """
    rows = (
        await db.execute(
            select(RaporIsi)
            .where(RaporIsi.user_id == user.id)
            .order_by(RaporIsi.created_at.desc(), RaporIsi.id.desc())
            .limit(limit)
        )
    ).scalars().all()
    return list(rows)


@router.get("/raporlar/isler/{is_id}/indir")
async def rapor_isi_indir(
    is_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_RAPOR_OKUR),
) -> dict:
    """Hazir isin INDIRME BAGLANTISINI doner (kisa omurlu presigned URL).

    DOSYAYI BU UC AKITMAZ: megabaytlarca veriyi uygulama surecinden
    gecirmek, MinIO'nun ZATEN yaptigi isi ikinci kez yapmak olurdu.
    Istemci baglantiyi alir ve dogrudan indirir.
    """
    isim = (
        await db.execute(
            select(RaporIsi).where(
                RaporIsi.id == is_id, RaporIsi.user_id == user.id
            )
        )
    ).scalar_one_or_none()
    if isim is None:
        raise APIError(404, "not_found", "rapor_isi_bulunamadi")
    if isim.durum != "hazir" or not isim.dosya_key:
        raise APIError(409, "conflict", "rapor_isi_hazir_degil")
    return {"url": presign_get(isim.dosya_key), "dosya_adi": isim.dosya_adi}
