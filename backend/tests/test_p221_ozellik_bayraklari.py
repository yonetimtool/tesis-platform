"""(P221) OZELLIK BAYRAKLARI — Dukkan yuzeyi SUNUCUDAN acilir.

===========================================================================
NE KORUNUYOR
===========================================================================
1. VARSAYILAN KAPALI. Bayrak eksik/bozuk gelirse Dukkan SESSIZCE
   ACILMAZ. Ters yonde hata yapmak (yapilandirma unutulunca yayina
   girmek), hazir olmayan bir pazar yerini kullaniciya gostermek
   olurdu.
2. KIMLIK GEREKTIRMEZ. Hangi sekmelerin gorunecegi GIRIS EKRANINDAN
   ONCE belli olmali; uc oturum istemiyor ve kisiye/tesise ozel veri
   TASIMIYOR.
3. SUNUCUDAN KONTROL. Bayrak uygulamanin icinde olsaydi acmak icin
   YENI SURUM ve MAGAZA TURU gerekirdi — ozelligin varlik sebebi tam
   olarak bundan kacinmak.
"""
from __future__ import annotations


def test_KIMLIKSIZ_ERISILIR(client):
    """Giris ekranindan ONCE cagriliyor; oturum istemek onu
    kullanilamaz yapardi."""
    r = client.get("/ozellikler")
    assert r.status_code == 200, r.text


def test_VARSAYILAN_KAPALI(client):
    """Dev/test ortaminda bayrak ACIKCA acilmadi -> Dukkan KAPALI."""
    d = client.get("/ozellikler").json()
    assert d["dukkan"] is False, d


def test_ALAN_HER_ZAMAN_VAR(client):
    """Istemci `dukkan` alanini bekliyor; yoklugu ile `false` ayni sey
    OLMAMALI diye alan HER ZAMAN doner.

    Alan bazen eksik gelseydi istemci "eksik = kapali" varsayimini
    yapmak zorunda kalirdi ve o varsayim bir gun "eksik = acik"
    diye degistirilebilirdi.
    """
    d = client.get("/ozellikler").json()
    assert "dukkan" in d and isinstance(d["dukkan"], bool), d


def test_AYARDAN_OKUNUYOR(client, monkeypatch):
    """Bayrak ORTAM AYARINDAN geliyor — kodda sabit degil.

    `client` CANLI sunucuya gidiyor, o yuzden ayar surec disindan
    degistirilemiyor. Bunun yerine ucun FONKSIYONU dogrudan surulur:
    olculen sey "ayar okunuyor mu", tasima degil.
    """
    import asyncio

    from app.config import settings
    from app.routers.ozellikler import ozellikler

    monkeypatch.setattr(settings, "dukkan_mobil_acik", True, raising=False)
    assert asyncio.run(ozellikler()).dukkan is True

    monkeypatch.setattr(settings, "dukkan_mobil_acik", False, raising=False)
    assert asyncio.run(ozellikler()).dukkan is False


def test_SEMA_VARSAYILANI_FALSE():
    """Sema duzeyinde de kapali: yeni bir cagiran alani vermezse
    Dukkan acilmaz."""
    from app.schemas import OzellikBayraklari

    assert OzellikBayraklari().dukkan is False


def test_P253_harita_karo_url_ayardan(client, monkeypatch):
    """(P253 A2) Karo dosyasi ayarlanmissa tam adres; bossa None (harita kapali).
    Adres genel depolama adresi + `karo` kovasi + surumlu dosya adi."""
    from app.config import settings
    from app.routers.ozellikler import harita_karo_url

    monkeypatch.setattr(settings, "harita_karo_dosyasi", "", raising=False)
    assert harita_karo_url() is None
    monkeypatch.setattr(settings, "harita_karo_dosyasi", "turkiye-20261003.pmtiles", raising=False)
    monkeypatch.setattr(settings, "minio_endpoint", "https://storage.ornek.test/", raising=False)
    assert harita_karo_url() == "https://storage.ornek.test/karo/turkiye-20261003.pmtiles"
