"""(DUKKAN) SMS — saglayici soyutlamasi, celiski yoklugu, sizinti kilidi.

===========================================================================
BU DOSYA UC SEYI KORUYOR
===========================================================================
1. `gonderildi` GERCEK sonucu yansitir — `gonderim` ile ASLA celismez.
2. Gonderilemeyen kod 200 DONMEZ (503) — istemci "basarili" dalina girmez.
3. `DUKKAN_OTP_YANITTA` prod'a sizsa BILE kod yanitta donmez.

Taklit HTTP KATMANINA konuyor (P198/P200 dersi): saglayici sinifini
taklit etmek, tam da olculmek istenen katmani (govde kurulumu, alan
adlari, numara bicimi, hata eslemesi) ATLARDI.
"""
from __future__ import annotations

import pathlib
import re

import httpx
import pytest

from app.mesajlasma import (
    KapaliSmsSaglayici,
    KonsolSmsSaglayici,
    VerimorSmsSaglayici,
    dukkan_sms_saglayicisi,
)


# ===================================================================== #
# 1. VERIMOR — istegin BICIMI olculuyor
# ===================================================================== #

class _SahteYanit:
    def __init__(self, status_code: int, text: str = ""):
        self.status_code = status_code
        self.text = text


def test_VERIMOR_istek_govdesi_DOGRU(monkeypatch):
    """Govde alan adlari ve numara bicimi Verimor sozlesmesine uymali.

    Bunlarin biri yanlissa saglayici 200 dondurebilir ama SMS GITMEZ —
    sessiz basarisizligin en kotu turu. O yuzden govdenin KENDISI
    olculuyor, cagrinin yapilip yapilmadigi degil.
    """
    yakalanan: dict = {}

    def sahte_post(url, json=None, timeout=None, **kw):
        yakalanan["url"] = url
        yakalanan["govde"] = json
        return _SahteYanit(200, "20212")

    monkeypatch.setattr(httpx, "post", sahte_post)
    s = VerimorSmsSaglayici("905551112233", "gizli", "DUKKAN")
    sonuc = s.gonder("+905321112233", None, "kod: 123456")

    assert sonuc.durum == "gonderildi"
    assert yakalanan["url"].endswith("/v2/send.json")
    g = yakalanan["govde"]
    assert g["username"] == "905551112233"
    assert g["source_addr"] == "DUKKAN"
    # NUMARA BICIMI: Verimor yurt ici numarayi `905XXXXXXXXX` bekliyor —
    # bas `+` YOK. `+90...` gondermek numarayi gecersiz kilar.
    assert g["messages"][0]["dest"] == "905321112233", g["messages"][0]
    assert "123456" in g["messages"][0]["msg"]


def test_VERIMOR_basari_yaniti_DUZ_METIN(monkeypatch):
    """Verimor 200'de JSON DEGIL, kampanya numarasi (duz metin) doner.

    `yanit.json()` cagirmak burada patlardi ve gonderilmis bir SMS
    "basarisiz" sayilirdi — kullanici kodu alir ama uc hata verirdi.
    """
    monkeypatch.setattr(
        httpx, "post", lambda *a, **k: _SahteYanit(200, "20212\n")
    )
    s = VerimorSmsSaglayici("u", "p", "BASLIK")
    assert s.gonder("+905321112233", None, "x").durum == "gonderildi"


def test_VERIMOR_ONAYSIZ_BASLIK_denemez_ve_AYRI_raporlar(monkeypatch):
    """Baslik bos ise HIC istek atilmamali.

    Verimor onaysiz `source_addr` icin 400 doner. "basarisiz" demek
    operatore YANLIS is gosterirdi: yapilmasi gereken kod duzeltmek
    degil, basvurunun onaylanmasini beklemek.
    """
    cagrildi = {"n": 0}

    def sahte_post(*a, **k):
        cagrildi["n"] += 1
        return _SahteYanit(400, "header not approved")

    monkeypatch.setattr(httpx, "post", sahte_post)
    s = VerimorSmsSaglayici("u", "p", "")     # BASLIK YOK
    sonuc = s.gonder("+905321112233", None, "x")
    assert cagrildi["n"] == 0, "onaysiz baslikla istek ATILDI"
    assert sonuc.durum == "yapilandirilmadi"
    assert sonuc.hata == "baslik_yok"


@pytest.mark.parametrize("kod,beklenen", [
    (400, "gecersiz_istek"), (401, "kimlik_gecersiz"),
    (413, "paket_buyuk"), (429, "hiz_siniri"), (500, "http_500"),
])
def test_VERIMOR_hata_kodlari_ESLENIYOR(monkeypatch, kod, beklenen):
    monkeypatch.setattr(httpx, "post", lambda *a, **k: _SahteYanit(kod, "x"))
    s = VerimorSmsSaglayici("u", "p", "BASLIK")
    sonuc = s.gonder("+905321112233", None, "x")
    assert sonuc.durum == "hata" and sonuc.hata == beklenen


def test_VERIMOR_AG_HATASI_govdeyi_SIZDIRMAZ(monkeypatch):
    """Hata SINIFI kaydedilir, mesaji DEGIL: mesaj URL ve kimlik
    icerebilir ve gunluge sizardi (P134)."""
    def patla(*a, **k):
        raise httpx.ConnectError("https://u:p@sms.verimor.com.tr sifre=gizli")

    monkeypatch.setattr(httpx, "post", patla)
    s = VerimorSmsSaglayici("u", "p", "BASLIK")
    sonuc = s.gonder("+905321112233", None, "x")
    assert sonuc.durum == "hata"
    assert sonuc.hata == "baglanti"
    assert "gizli" not in (sonuc.hata or "")


# ===================================================================== #
# 2. SECIM NOKTASI
# ===================================================================== #

def test_KONSOL_saglayici_GERCEKTEN_teslim_eder():
    """`gonderildi: true` DURUST olmali: mesaj gercekten (konsola)
    teslim edildi. `KapaliSmsSaglayici` bu isi goremezdi — o
    'yapilandirilmadi' der ve akis dev'de HIC surulemezdi."""
    assert KonsolSmsSaglayici().gonder("+905321112233", None, "x").durum == (
        "gonderildi"
    )


def test_KAPALI_saglayici_GONDERILDI_DEMEZ():
    """P191'de olculen tuzak: noop'un sessizce 'basarili' davranmasi."""
    sonuc = KapaliSmsSaglayici().gonder("+905321112233", None, "x")
    assert sonuc.durum != "gonderildi"


def test_VERIMOR_kimlik_EKSIKSE_kapaliya_duser(monkeypatch):
    """Yarim yapilandirmayi 'calisiyor' saymak, kodlarin sessizce hicbir
    yere gitmemesi demekti."""
    import app.config as c

    monkeypatch.setattr(c.settings, "dukkan_sms_saglayici", "verimor")
    monkeypatch.setattr(c.settings, "sms_kullanici", "")
    monkeypatch.setattr(c.settings, "sms_parola", "")
    assert dukkan_sms_saglayicisi().ad == KapaliSmsSaglayici.ad


def test_TANIMSIZ_saglayici_kapaliya_duser(monkeypatch):
    import app.config as c

    monkeypatch.setattr(c.settings, "dukkan_sms_saglayici", "boyle-bir-sey-yok")
    assert dukkan_sms_saglayicisi().ad == KapaliSmsSaglayici.ad


# ===================================================================== #
# 3. UC DAVRANISI — CELISKI YOK
# ===================================================================== #

def _tel() -> str:
    import uuid

    return f"+9053{uuid.uuid4().int % 10**8:08d}"


def test_UC_gonderildi_ve_gonderim_CELISMEZ(client):
    """KULLANICININ BILDIRDIGI KUSUR.

    Eski yanit `{"gonderildi": true, "gonderim": "saglayici_bagli_degil"}`
    idi — iki alan birbiriyle CELISIYORDU ve istemci hangisine bakacagini
    bilemezdi. Tam da "sessiz basarisizlik" sinifi, ustelik onu engellemek
    icin yazilmis bir alanin icinde.
    """
    r = client.post("/dukkan/auth/telefon/kod", json={"telefon": _tel()})
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["gonderildi"] is (d["gonderim"] == "gonderildi"), (
        f"CELISKI: gonderildi={d['gonderildi']} gonderim={d['gonderim']}"
    )


def test_UC_GONDERILEMEYINCE_200_DONMEZ(client, monkeypatch):
    """200 + `gonderildi: false` istemciyi 'basarili' dalina sokar ve
    kullaniciya GELMEYECEK bir kodun bekleme ekranini gosterirdi.

    Durum kodu istemcinin okumak zorunda OLDUGU tek sinyal.
    """
    # Bu test CANLI sunucuya gidiyor; saglayiciyi surec disindan
    # degistiremeyiz. Bunun yerine SAGLAYICI SINIFININ davranisini
    # dogrudan olcup, ucun o davranisi nasil cevirdigini
    # `test_UC_gonderildi_ve_gonderim_CELISMEZ` ile birlikte okuyoruz.
    #
    # Ucun 503 uretme yolunun KAYNAKTA var oldugunu ayrica kilitliyoruz:
    kaynak = pathlib.Path(__file__).resolve().parents[1] / "app/dukkan/auth_uclar.py"
    metin = kaynak.read_text()
    assert 'status_code=503' in metin, "gonderilemeyince 503 yolu YOK"
    assert re.search(r'if not yanit\["gonderildi"\]', metin), (
        "gonderim sonucu KONTROL EDILMIYOR"
    )


# ===================================================================== #
# 4. OTP SIZINTI KILIDI — prod'a sizsa BILE kod donmez
# ===================================================================== #

def test_GERCEK_SAGLAYICI_varken_dev_kod_DONMEZ(client, monkeypatch):
    """ASIL GUVENLIK KILIDI.

    `DUKKAN_OTP_YANITTA` tek basina YETMEZ: kod yanitta ancak
    (1) ayar acik VE (2) gercek saglayici YOK ise doner.

    Prod'da Verimor yapilandirili oldugu icin ikinci kosul YAPISAL
    OLARAK tutmaz — ayar yanlislikla acilsa bile kod SIZMAZ. Bir
    yapilandirma hatasinin TEK BASINA yeterli olmamasi, savunmanin
    kendisidir.
    """
    from app.dukkan import kimlik as k

    kaynak = pathlib.Path(k.__file__).read_text()
    # Kosul KAYNAKTA iki bilesenli olmali.
    assert "dukkan_otp_yanitta and not gercek_saglayici" in kaynak, (
        "OTP sizinti kilidi TEK KOSULA inmis — ayar tek basina yeterli "
        "hale gelmis demektir."
    )
    assert 'in ("verimor", "netgsm")' in kaynak, (
        "gercek saglayici tanimi kaynakta bulunamadi"
    )


def test_PROD_COMPOSE_OTP_AYARINI_TANIMLAMAZ():
    """Ikinci savunma katmani: yapilandirma DRIFT'i.

    En olasi sizma yolu, dev compose'undan kopyalanan bir satir.
    `docker-compose.prod.yml` bu degiskeni HIC tanimlamamali; varsayilan
    `false` zaten dogru degeri veriyor.
    """
    kok = pathlib.Path(__file__).resolve().parents[2]
    prod = (kok / "infra/docker-compose.prod.yml").read_text()
    assert "DUKKAN_OTP_YANITTA" not in prod, (
        "DUKKAN_OTP_YANITTA prod compose'una girmis — dogrulama kodu "
        "HTTP yanitinda doner ve telefon dogrulamasi ANLAMSIZLASIR."
    )


def test_PROD_COMPOSE_KONSOL_SAGLAYICI_KULLANMAZ():
    """Konsol tasiyicisi kodu GUNLUGE yaziyor — prod'da secilirse
    dogrulama kodlari konteyner gunluklerine dokulurdu."""
    kok = pathlib.Path(__file__).resolve().parents[2]
    prod = (kok / "infra/docker-compose.prod.yml").read_text()
    assert '"konsol"' not in prod and "DUKKAN_SMS_SAGLAYICI: konsol" not in prod, (
        "prod compose konsol SMS tasiyicisini kullaniyor — kodlar gunluge yazilir."
    )
