"""(P120) IDN ALAN ADI — CORS origin normallestirmesi.

NEDEN VAR: birincil musteri alani `yönetiyor.com` bir IDN'dir. Tarayici
`Origin` basligini DAIMA punycode gonderir
(`https://panel.xn--ynetiyor-n4a.com`) ama insan yapilandirmaya unicode
yazar. `CORSMiddleware.allow_origins` TAM ESLESME yapar; iki bicim
ayrisirsa hicbir istek gecmez ve belirti "CORS bozuk" diye gorunur —
alan adinin YAZIM BICIMI kimsenin aklina gelmez.

Bu dosya SAF BIRIM testidir (sunucuya gitmez).
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest

from app.config import Settings, _punycode_origin, settings


class TestPunycodeOrigin:
    def test_idn_konak_ace_ye_cevrilir(self):
        assert (
            _punycode_origin("https://yönetiyor.com")
            == "https://xn--ynetiyor-n4a.com"
        )

    def test_alt_alan_da_cevrilir(self):
        assert (
            _punycode_origin("https://panel.yönetiyor.com")
            == "https://panel.xn--ynetiyor-n4a.com"
        )

    def test_PORT_KORUNUR(self):
        # `netloc`i butun halinde `idna` codec'ine vermek `:8443` yuzunden
        # hata verirdi; konak ayri cevriliyor.
        assert (
            _punycode_origin("https://yönetiyor.com:8443")
            == "https://xn--ynetiyor-n4a.com:8443"
        )

    def test_BUYUK_HARF_de_cevrilir(self):
        # Kullanici yapilandirmaya buyuk harfle yazabilir; `Origin` basligi
        # kucuk harflidir.
        assert (
            _punycode_origin("https://YÖNETIYOR.com")
            == "https://xn--ynetiyor-n4a.com"
        )

    @pytest.mark.parametrize(
        "origin",
        [
            "https://panel.yonetio.site",  # zaten ASCII
            "http://localhost:3000",
            "http://[::1]:8000",           # IPv6 literal
            "bozuk",                       # konak yok
            "",
        ],
    )
    def test_CEVIRI_GEREKMEYEN_ya_da_COZULEMEYEN_None_doner(self, origin):
        # None = "cagiran ham degeri kullansin". Burada patlamak, tek bir
        # yazim hatasi yuzunden UYGULAMANIN ACILMAMASI demek olurdu.
        assert _punycode_origin(origin) is None


class TestCorsOriginListesi:
    def test_UNICODE_yazilirsa_PUNYCODE_de_listeye_girer(self):
        # ASIL KORUMA. Yapilandirmada yalniz unicode varsa, punycode
        # eklenmedigi surece tarayicidan gelen HICBIR istek gecmez.
        s = Settings(cors_origins="https://panel.yönetiyor.com")
        assert "https://panel.xn--ynetiyor-n4a.com" in s.cors_origin_list

    def test_UNICODE_bicimi_de_KORUNUR(self):
        # Dusurmek, elle test eden birinin unicode origin'le denedigi
        # senaryoyu bozardi; ikisi de gecerli kalir.
        s = Settings(cors_origins="https://panel.yönetiyor.com")
        assert "https://panel.yönetiyor.com" in s.cors_origin_list

    def test_TEKRAR_ETMEZ(self):
        # Ayni origin iki bicimde yazildiysa liste sismez.
        s = Settings(
            cors_origins=(
                "https://panel.yönetiyor.com,"
                "https://panel.xn--ynetiyor-n4a.com"
            )
        )
        liste = s.cors_origin_list
        assert len(liste) == len(set(liste))
        assert liste.count("https://panel.xn--ynetiyor-n4a.com") == 1

    def test_ESKI_ALAN_bozulmadi(self):
        # Gerilemenin en pahali hali: yeni alan eklerken eskisini dusurmek.
        s = Settings(
            cors_origins=(
                "https://panel.yonetio.site,https://panel.yönetiyor.com"
            )
        )
        assert "https://panel.yonetio.site" in s.cors_origin_list

    def test_BOS_deger_middleware_i_ACMAZ(self):
        # Dev varsayilani: liste bos => `main.py` CORS middleware'ini HIC
        # eklemez. Bir bosluk/virgul artiginin bunu bozmadigini olcuyoruz.
        assert Settings(cors_origins="").cors_origin_list == []
        assert Settings(cors_origins="  , ,").cors_origin_list == []

    def test_BOSLUKLAR_kirpilir(self):
        s = Settings(cors_origins="  https://panel.yonetio.site  ,  ")
        assert s.cors_origin_list == ["https://panel.yonetio.site"]


class TestPortalTabanAdresi:
    """Sakine GIDEN mesajlardaki `{odeme_linki}` etiketinin tabani.

    BULUNAN GERCEK HATA (P120): `routers/mesajlar.py` icinde
    `yonetio.app/ode` SABIT KODLUYDU ve o alan adi **bize ait degil**
    (NS'i Cloudflare; bizim alanlarimizin hepsi Hostinger'da). Aidat
    hatirlatma SMS/e-postalarinda sakinlere UCUNCU BIR TARAFIN alan
    adina baglanti gonderiyorduk.
    """

    #: Sahip oldugumuz alan adlari (punycode dahil).
    SAHIP = ("yonetio.site", "yönetiyor.com", "xn--ynetiyor-n4a.com")

    def test_VARSAYILAN_bize_ait_bir_alan(self):
        assert any(f"://{a}" in settings.portal_base_url for a in self.SAHIP), (
            f"portal_base_url bize ait olmayan bir alana bakiyor: "
            f"{settings.portal_base_url}"
        )

    def test_MESAJ_KODUNDA_sabit_konak_YOK(self):
        # Ayarin var olmasi yetmez: kodda ayrica sabit bir adres KALMAMALI.
        kaynak = Path("app/routers/mesajlar.py").read_text(encoding="utf-8")
        # Onizleme ornegi (`https://ornek/ode`) sahte bir konaktir, gecerli.
        adresler = [
            a for a in re.findall(r"https?://([^/\s\"']+)", kaynak)
            if a != "ornek"
        ]
        assert adresler == [], f"mesajlar.py'de sabit kodlu konak: {adresler}"

    def test_ETIKET_ayardan_uretiliyor(self):
        kaynak = Path("app/routers/mesajlar.py").read_text(encoding="utf-8")
        assert "settings.portal_base_url" in kaynak
