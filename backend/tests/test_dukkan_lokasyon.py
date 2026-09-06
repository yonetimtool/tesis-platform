"""(DUKKAN F1) LOKASYON AGACI + TURKCE ONARIMI.

===========================================================================
BU DOSYA NEYI KORUYOR
===========================================================================
Lokasyon verisi DISARIDAN geliyor ve HAM HALIYLE KULLANILAMAZ DURUMDAYDI.
Olculen kusur:
  * 74.402 Turkce adda 'ı' harfi SIFIR kez geciyordu — Turkcede 'ı' cok
    yaygin oldugu icin bu istatistiksel olarak imkansiz,
  * adlarin %83,6'si U+0307 birlesen nokta tasiyordu ("Mahallesi̇"),
  * il adlari bile bozuktu ("Balikesi̇r", "Di̇yarbakir").

Teshis: kaynak BUYUK HARFTI ve Turkce OLMAYAN yerel ayarla kucultulmustu
('İ'.lower() -> 'i'+U+0307, 'I'.lower() -> 'i').

Onarim BIRE BIR geri dondurulebilir; bu dosya onu KANITLIYOR ve KILITLIYOR.
Kaynak bir gun degistirilirse (guncelleme yolu: yilda 1-2 kez yeni dokum),
bu testler yeni verinin ayni kusuru tasiyip tasimadigini soyler.

NEDEN ONEMLI: bozuk bir ad yalnizca cirkin degil, URL'e girdigi icin
KALICI. "Balikesi̇r" bir kez slug'a donusup yayinlandiginda geri almak
301 zinciri demek.
"""
from __future__ import annotations

import pytest

from app.dukkan.lokasyon_yukle import _mahalle_ayikla, _onar, slugla

# --------------------------------------------------------------------- #
# 1. ONARIM ALGORITMASI — bilinen dogru adlara karsi
# --------------------------------------------------------------------- #

BOZUK_DOGRU = [
    ("Balikesi̇r", "Balıkesir"),
    ("Di̇yarbakir", "Diyarbakır"),
    ("Afyonkarahi̇sar", "Afyonkarahisar"),
    ("Deni̇zli̇", "Denizli"),
    ("Karai̇sali", "Karaisalı"),
    ("Çinarli Mahallesi̇", "Çınarlı Mahallesi"),
    ("Bariş Mahallesi̇", "Barış Mahallesi"),
    ("Akkapi Mahallesi̇", "Akkapı Mahallesi"),
    ("Ali̇dede Mahallesi̇", "Alidede Mahallesi"),
    ("Yüreği̇r", "Yüreğir"),
    # Bozulmamis metin DEGISMEMELI — onarim yalniz kusuru duzeltir.
    ("Adana", "Adana"),
    ("Çekmeköy", "Çekmeköy"),
    ("Çatalmeşe Mahallesi̇", "Çatalmeşe Mahallesi"),
]


@pytest.mark.parametrize("bozuk,dogru", BOZUK_DOGRU)
def test_ONARIM_bilinen_adlari_dogru_uretir(bozuk: str, dogru: str):
    assert _onar(bozuk) == dogru


def test_ONARIM_birlesen_nokta_BIRAKMAZ():
    """U+0307 kalirsa slug ve gorunum ikisi de bozulur."""
    for bozuk, _ in BOZUK_DOGRU:
        assert "̇" not in _onar(bozuk)


# --------------------------------------------------------------------- #
# 2. SLUG — SEO yolunun temeli
# --------------------------------------------------------------------- #

@pytest.mark.parametrize("ad,beklenen", [
    ("İstanbul", "istanbul"),
    ("Çekmeköy", "cekmekoy"),
    ("Çatalmeşe", "catalmese"),
    ("Balıkesir", "balikesir"),
    ("Diyarbakır", "diyarbakir"),
    ("Şanlıurfa", "sanliurfa"),
    ("Kahramanmaraş", "kahramanmaras"),
    ("Yeni  Mahalle", "yeni-mahalle"),     # cift bosluk tek tire
    ("Gazi Osman Paşa", "gazi-osman-pasa"),
])
def test_SLUG_turkce_harfleri_dogru_cevirir(ad: str, beklenen: str):
    assert slugla(ad) == beklenen


def test_SLUG_yalniz_URL_GUVENLI_karakter_uretir():
    import re
    for ad in ("Çatalmeşe", "Şirinyalı", "Gülüşlü", "19 Mayıs", "P.T.T"):
        s = slugla(ad)
        assert re.fullmatch(r"[a-z0-9-]+", s), f"{ad} -> {s}"
        assert not s.startswith("-") and not s.endswith("-")


# --------------------------------------------------------------------- #
# 3. HANGI KAYITLAR YUKLENIR
# --------------------------------------------------------------------- #

def test_mahalle_ve_koy_YUKLENIR():
    assert _mahalle_ayikla("Çatalmeşe Mahallesi̇") == ("Çatalmeşe", "mahalle")
    assert _mahalle_ayikla("Akoluk Köyü") == ("Akoluk", "koy")


def test_MEVKI_ve_MEZRA_YUKLENMEZ():
    """Kirsal konum adlari hizmet alani DEGIL.

    Bir usta hizmet alani olarak "mevki" secmez. Kaynaktaki 22.912 mevki
    ve 5.337 mezra kaydini yuklemek, mahalle sececigini 45.000 yerine
    74.000 secenege cikarir ve hicbir isletme onlari secmeyecegi icin o
    sayfalar KALICI olarak esik altinda kalirdi (docs/dukkan/05-seo.md §3).
    """
    assert _mahalle_ayikla("Karatepe Mevki̇i̇") is None
    assert _mahalle_ayikla("Yukarikaya Mezrasi") is None


def test_BOS_kayit_YUKLENMEZ():
    """Kaynakta 45 adet bos dizge var; bos ad bos slug uretir ve
    /il/ilce// gibi bozuk bir yol dogururdu."""
    assert _mahalle_ayikla("") is None
    assert _mahalle_ayikla("   ") is None


# --------------------------------------------------------------------- #
# 4. VERITABANINDAKI SONUC — gercekten yuklendi mi
# --------------------------------------------------------------------- #

def test_VERITABANI_lokasyon_agaci_dolu(dukkan_conn):
    il = dukkan_conn.execute("SELECT count(*) FROM dukkan.il").fetchone()[0]
    ilce = dukkan_conn.execute("SELECT count(*) FROM dukkan.ilce").fetchone()[0]
    mah = dukkan_conn.execute("SELECT count(*) FROM dukkan.mahalle").fetchone()[0]
    assert il == 81, f"il sayisi {il} — 81 olmali"
    assert ilce > 900, f"ilce sayisi {ilce} dusuk"
    assert mah > 40000, f"mahalle sayisi {mah} dusuk"


def test_VERITABANINDA_BOZUK_AD_KALMADI(dukkan_conn):
    """ASIL KILIT: U+0307 tasiyan tek bir ad bile kalmamali."""
    for tablo in ("il", "ilce", "mahalle"):
        n = dukkan_conn.execute(
            f"SELECT count(*) FROM dukkan.{tablo} WHERE ad LIKE '%' || chr(775) || '%'"
        ).fetchone()[0]
        assert n == 0, f"dukkan.{tablo} icinde {n} BOZUK ad var"


def test_VERITABANINDA_dotless_i_VAR(dukkan_conn):
    """Ters yonlu kanit.

    Yukaridaki test, veri BOS olsaydi da gecerdi. Turkcede 'ı' cok
    yaygin: 44.719 mahalle adinda binlerce kez gecmeli. Sifir cikarsa
    onarim uygulanmamis demektir.
    """
    n = dukkan_conn.execute(
        "SELECT count(*) FROM dukkan.mahalle WHERE ad LIKE '%ı%'"
    ).fetchone()[0]
    assert n > 5000, f"'ı' iceren mahalle sayisi {n} — onarim uygulanmamis olabilir"


def test_BRIEFTEKI_ORNEK_YOL_cozulur(dukkan_conn):
    """brief'in ornek SEO yolu: /istanbul/cekmekoy/catalmese/elektrikci

    Lokasyon kismi gercekten cozulebiliyor mu? Bu, tum SEO tasariminin
    dayandigi tek sorgu.
    """
    satir = dukkan_conn.execute(
        """
        SELECT i.ad, ic.ad, m.ad
        FROM dukkan.mahalle m
        JOIN dukkan.ilce ic ON ic.id = m.ilce_id
        JOIN dukkan.il i ON i.id = ic.il_id
        WHERE i.slug = 'istanbul' AND ic.slug = 'cekmekoy'
          AND m.slug = 'catalmese'
        """
    ).fetchone()
    assert satir == ("İstanbul", "Çekmeköy", "Çatalmeşe"), satir


def test_VERI_KAYNAGI_izi_kayitli(dukkan_conn):
    """Kullanicinin sarti: 'kaynagi ve indirme tarihini belgele'."""
    satir = dukkan_conn.execute(
        "SELECT kaynak_url, lisans, indirme_tarihi, sha256, onarim_notu "
        "FROM dukkan.veri_kaynagi WHERE tur = 'lokasyon'"
    ).fetchone()
    assert satir is not None, "lokasyon veri kaynagi izi YOK"
    url, lisans, tarih, ozet, onarim = satir
    assert url.startswith("https://"), url
    assert lisans == "MIT", f"lisans '{lisans}' — ticari kullanima uygun olmali"
    assert tarih is not None
    assert len(ozet) == 64, "sha256 ozeti eksik"
    assert onarim, "onarim notu bos — verinin islenmis oldugu kayitli degil"
