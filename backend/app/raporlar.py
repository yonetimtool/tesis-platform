"""Rapor CERCEVESI (P31) — parametreler, kayit defteri, satir uretimi.

TEK CERCEVE, UC CIKTI: her rapor bir `Rapor` tanimidir ve `Göster` (tablo),
`Excel`, `PDF` ciktilarinin UCU DE AYNI satirlardan uretilir. Ucu ayri
uretmek, ayni raporun uc yerde farkli rakam gostermesine yol acardi —
bicimlendirme farki (yuvarlama, para birimi, tarih) sessizce ayrilir.

CIKTI URETIMI SUNUCUDA: istemcide XLSX/PDF uretmek, panelin ve mobilin ayni
raporu iki kez (ve farkli) bicimlendirmesi demekti.

Bu dosya SORGU CALISTIRMAZ; router veriyi toplar, buradaki saf fonksiyonlar
satirlari kurar. Boylece sutun dogrulugu veritabanina dokunmadan test
edilebilir.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from decimal import Decimal


# ============================== PARAMETRELER ================================ #
@dataclass(frozen=True)
class RaporParam:
    """Parametre modali (ref: apsiyon parameter-modal).

    Her rapor bu KUMENIN bir alt kumesini kullanir; kullanilmayan alanlar
    yok sayilir. Tek bir parametre nesnesi olmasi bilincli: rapor basina
    ayri model, modal bileseninin her rapor icin yeniden yazilmasi demekti.
    """

    baslangic: date | None = None
    bitis: date | None = None
    #: Gecikme tazminatinin HANGI TARIHE gore hesaplanacagi. `None` ise
    #: `bitis`, o da yoksa bugun. Ayri alan olmasi sart: donem raporunu
    #: bugunun tazminatiyla almak isteyen yonetim var.
    tazminat_tarihi: date | None = None
    blok: str | None = None
    gelir_gider_tanim_id: str | None = None
    #: Listeleme tipi — raporun kendi anlamlandirdigi serbest anahtar
    #: (orn. borc listesinde "borclu" | "alacakli" | "tumu").
    listeleme_tipi: str | None = None
    min_tutar_kurus: int | None = None
    max_tutar_kurus: int | None = None
    #: "unit_no" | "ad" | "bakiye" | "tarih" — rapor destekledigini uygular.
    siralama: str | None = None
    #: KVKK: ad gosterimi VARSAYILAN KAPALI degil ACIK degil — RAPORA gore.
    #: Bayrak acikca istenir cunku bazi ciktilar (kapiya asilan liste) ad
    #: TASIMAMALI.
    ismi_goster: bool = True
    #: Icra dosyasi acilmis kisiler listeye girsin mi.
    icradakileri_goster: bool = True


@dataclass(frozen=True)
class Sutun:
    """Rapor sutunu. `tip` bicimlendirmeyi belirler; genislik PDF icin."""

    anahtar: str
    baslik: str
    #: "metin" | "kurus" | "tarih" | "sayi"
    tip: str = "metin"
    genislik: int = 1


@dataclass
class RaporSonuc:
    """Bir raporun UC CIKTIYA da beslenen tek gercegi."""

    kod: str
    baslik: str
    sutunlar: list[Sutun]
    satirlar: list[dict]
    #: Alt toplam satiri (varsa) — Excel/PDF'te kalin, tabloda ayri.
    toplamlar: dict = field(default_factory=dict)
    #: Serbest metin raporlar (ihtar yazisi, denetim raporu) icin govde.
    metin: str | None = None


# =============================== YARDIMCILAR ================================ #
def kurus_metin(kurus: int | None) -> str:
    """KURUS -> "1.250,50" (Turkce gruplama, para birimi YOK).

    Para birimi simgesi ciktida ayri yazilir: Excel'de sayi hucresi olmali,
    PDF'te ise basligta bir kez gecmeli — her hucreye koymak toplamlari
    metne cevirirdi.
    """
    if kurus is None:
        return ""
    negatif = kurus < 0
    tam, kalan = divmod(abs(int(kurus)), 100)
    gruplu = f"{tam:,}".replace(",", ".")
    return f"{'-' if negatif else ''}{gruplu},{kalan:02d}"


def sirala(satirlar: list[dict], anahtar: str | None, varsayilan: str) -> list[dict]:
    """Guvenli siralama: bilinmeyen anahtar VARSAYILANA duser.

    Istemciden gelen anahtari dogrudan kullanmak, olmayan bir alanda
    KeyError ile 500 verirdi.
    """
    alan = anahtar if anahtar and satirlar and anahtar in satirlar[0] else varsayilan
    if not satirlar or alan not in satirlar[0]:
        return satirlar
    return sorted(
        satirlar,
        key=lambda s: (s.get(alan) is None, _sira_anahtari(s.get(alan))),
    )


def _sira_anahtari(deger):
    if isinstance(deger, (int, float, Decimal)):
        return deger
    return str(deger or "").casefold()


def tutar_suzgeci(
    satirlar: list[dict], alan: str, alt: int | None, ust: int | None
) -> list[dict]:
    """Min/maks tutar suzgeci — SINIRLAR DAHIL.

    Disarida birakmak ("> alt") kullanicinin "en az 100 TL" beklentisini
    bozardi: 100 TL borclu tam sinirdadir ve listede olmalidir.
    """
    def uygun(s: dict) -> bool:
        v = s.get(alan)
        if v is None:
            return alt is None
        if alt is not None and v < alt:
            return False
        if ust is not None and v > ust:
            return False
        return True

    return [s for s in satirlar if uygun(s)]


# =========================== SATIR URETICILERI ============================== #
def borc_alacak_satirlari(
    kisiler: list[dict], hareketler: list[dict], param: RaporParam
) -> RaporSonuc:
    """**Borç-Alacak Listesi** — dönem başı / dönem içi / bakiye.

    KOLON MANTIGI (raporun tamami bu ayrimda):
      * DONEM BASI = `baslangic`tan ONCEKI her sey (ana para + gecikme),
      * DONEM ICI  = araliktaki borclandirma / gecikme / iade / tahsilat,
      * BAKIYE     = donem basi + donem ici borc − donem ici tahsilat + iade.
    Iade TAHSILATI GERI ALIR, yani bakiyeyi ARTIRIR — "eksi tahsilat" diye
    yazmak isareti iki kez uygulamak olurdu.
    """
    sutunlar = [
        Sutun("unit_no", "Bağımsız Bölüm", genislik=2),
        Sutun("ad", "Ad Soyad", genislik=3),
        Sutun("bas_ana_para", "Dönem Başı Ana Para", "kurus", 2),
        Sutun("bas_gecikme", "Dönem Başı Gecikme", "kurus", 2),
        Sutun("ici_borc", "Dönem İçi Borçlandırma", "kurus", 2),
        Sutun("ici_gecikme", "Dönem İçi Gecikme", "kurus", 2),
        Sutun("ici_iade", "İade", "kurus", 2),
        Sutun("ici_tahsilat", "Tahsilat", "kurus", 2),
        Sutun("bakiye", "Bakiye", "kurus", 2),
    ]
    if not param.ismi_goster:
        sutunlar = [s for s in sutunlar if s.anahtar != "ad"]

    satirlar = []
    for k in kisiler:
        if not param.icradakileri_goster and k.get("icrada"):
            continue
        bakiye = (
            k.get("bas_ana_para", 0)
            + k.get("bas_gecikme", 0)
            + k.get("ici_borc", 0)
            + k.get("ici_gecikme", 0)
            + k.get("ici_iade", 0)
            - k.get("ici_tahsilat", 0)
        )
        satir = {**k, "bakiye": bakiye}
        if not param.ismi_goster:
            satir.pop("ad", None)
        satirlar.append(satir)

    if param.listeleme_tipi == "borclu":
        satirlar = [s for s in satirlar if s["bakiye"] > 0]
    elif param.listeleme_tipi == "alacakli":
        satirlar = [s for s in satirlar if s["bakiye"] < 0]

    satirlar = tutar_suzgeci(
        satirlar, "bakiye", param.min_tutar_kurus, param.max_tutar_kurus
    )
    satirlar = sirala(satirlar, param.siralama, "unit_no")
    toplamlar = {
        s.anahtar: sum(r.get(s.anahtar, 0) for r in satirlar)
        for s in sutunlar
        if s.tip == "kurus"
    }
    return RaporSonuc(
        "borc_alacak", "Borç-Alacak Listesi", sutunlar, satirlar, toplamlar
    )


def detayli_borc_satirlari(
    kisiler: list[dict], kalemler: list[dict], param: RaporParam
) -> RaporSonuc:
    """**Detaylı Borç Listesi** — sutunlar P27 TANIMLARINDAN DINAMIK gelir.

    Elektrik/Su/Doğal Gaz sabit sutunlar OLARAK YAZILMADI: her sitenin
    kalem listesi farklidir ve sabit sutunlar, kalemi olmayan siteye bos
    sutun, fazladan kalemi olana ise "Diğer"e sikismis rakam gosterirdi.
    Sutunlar tanim listesinden uretilir; tanimsiz borclar "Diğer"e toplanir.
    """
    sutunlar = [
        Sutun("unit_no", "Bağımsız Bölüm", genislik=2),
        Sutun("ad", "Ad Soyad", genislik=3),
    ]
    if not param.ismi_goster:
        sutunlar = [s for s in sutunlar if s.anahtar != "ad"]
    for kalem in kalemler:
        sutunlar.append(
            Sutun(f"kalem_{kalem['id']}", kalem["ad"], "kurus", 2)
        )
    sutunlar.append(Sutun("kalem_diger", "Diğer", "kurus", 2))
    sutunlar.append(Sutun("toplam", "Toplam", "kurus", 2))

    bilinen = {str(k["id"]) for k in kalemler}
    satirlar = []
    for k in kisiler:
        if not param.icradakileri_goster and k.get("icrada"):
            continue
        satir: dict = {"unit_no": k.get("unit_no")}
        if param.ismi_goster:
            satir["ad"] = k.get("ad")
        diger = 0
        toplam = 0
        for kalem in kalemler:
            deger = int(k.get("kalemler", {}).get(str(kalem["id"]), 0))
            satir[f"kalem_{kalem['id']}"] = deger
            toplam += deger
        for tid, deger in (k.get("kalemler") or {}).items():
            if tid not in bilinen:
                diger += int(deger)
        satir["kalem_diger"] = diger
        satir["toplam"] = toplam + diger
        satirlar.append(satir)

    satirlar = tutar_suzgeci(
        satirlar, "toplam", param.min_tutar_kurus, param.max_tutar_kurus
    )
    satirlar = sirala(satirlar, param.siralama, "unit_no")
    toplamlar = {
        s.anahtar: sum(r.get(s.anahtar, 0) for r in satirlar)
        for s in sutunlar
        if s.tip == "kurus"
    }
    return RaporSonuc(
        "detayli_borc", "Detaylı Borç Listesi", sutunlar, satirlar, toplamlar
    )


def tahsilat_performansi(
    donemler: list[dict], yaslandirma: list[dict]
) -> RaporSonuc:
    """**Tahsilat Performansı** — tahsilat orani + yaslandirma + egilim.

    ORAN TANIMI ONEMLI: `tahsil / borclandirilan` — "tahsil / toplam acik
    borc" DEGIL. Ikincisi gecmis donemlerin birikmis borcunu paya katar ve
    iyi bir ayi kotu gosterir; yonetim "bu ay ne kadarini topladim" bilmek
    ister.

    YASLANDIRMA kovalari 0-30 / 31-60 / 61-90 / 90+ gundur; bu esikler
    icra kararinin fiili esikleridir ve rapor o karari beslemek icindir.
    """
    sutunlar = [
        Sutun("donem", "Dönem", genislik=2),
        Sutun("borclandirilan", "Borçlandırılan", "kurus", 2),
        Sutun("tahsil", "Tahsil Edilen", "kurus", 2),
        Sutun("oran", "Tahsilat Oranı (%)", "sayi", 2),
    ]
    satirlar = []
    for d in donemler:
        borc = int(d.get("borclandirilan", 0))
        tahsil = int(d.get("tahsil", 0))
        # SIFIRA BOLME: borclandirma yoksa oran TANIMSIZDIR, 0 DEGIL —
        # 0 yazmak "hic tahsil edemedik" diye okunurdu.
        oran = round(tahsil * 100 / borc, 1) if borc else None
        satirlar.append(
            {"donem": d["donem"], "borclandirilan": borc,
             "tahsil": tahsil, "oran": oran}
        )
    satirlar.sort(key=lambda s: s["donem"])

    toplam_borc = sum(s["borclandirilan"] for s in satirlar)
    toplam_tahsil = sum(s["tahsil"] for s in satirlar)
    sonuc = RaporSonuc(
        "tahsilat_performansi", "Tahsilat Performansı", sutunlar, satirlar,
        {
            "borclandirilan": toplam_borc,
            "tahsil": toplam_tahsil,
            "oran": round(toplam_tahsil * 100 / toplam_borc, 1)
            if toplam_borc else None,
        },
    )
    # Yaslandirma AYRI bir tablo degil, ayni raporun ALT BOLUMU: iki ayri
    # rapor olsaydi yonetim ikisini yan yana koymak zorunda kalirdi.
    sonuc.metin = "Yaşlandırma: " + " · ".join(
        f"{k['kova']}: {kurus_metin(k['tutar_kurus'])}" for k in yaslandirma
    )
    return sonuc


def ihtar_metni(
    site_ad: str, kisi_ad: str, unit_no: str, borc_kurus: int,
    gecikme_kurus: int, tarih: date,
) -> str:
    """**İhtar Yazısı** — daire basina resmi uyari metni.

    SABLON KOD ICINDE, veritabaninda DEGIL: metin hukuki olarak sabittir ve
    tenant basina duzenlenebilir yapmak, yanlis kurgulanmis bir ihtarin
    hukuki gecerliligini riske atardi. Degisken YALNIZ rakamlar ve adlar.
    """
    toplam = borc_kurus + gecikme_kurus
    return (
        f"{site_ad}\n"
        f"Tarih: {tarih.isoformat()}\n\n"
        f"Sayın {kisi_ad},\n\n"
        f"{unit_no} numaralı bağımsız bölüme ait, işbu yazı tarihi itibarıyla "
        f"ödenmemiş {kurus_metin(borc_kurus)} TL ana para ve "
        f"{kurus_metin(gecikme_kurus)} TL gecikme tazminatı olmak üzere "
        f"toplam {kurus_metin(toplam)} TL borcunuz bulunmaktadır.\n\n"
        f"Kat Mülkiyeti Kanunu'nun 20. maddesi uyarınca, işbu ihtarın "
        f"tarafınıza tebliğinden itibaren yedi (7) gün içinde ödeme "
        f"yapmanızı; aksi hâlde hakkınızda icra takibi başlatılacağını "
        f"ihtaren bildiririz.\n\n"
        f"Saygılarımızla,\n{site_ad} Yönetimi"
    )
