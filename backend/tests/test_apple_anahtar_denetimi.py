"""(P253 acil) APPLE OZEL ANAHTARI — acilis denetimi + dosyadan okuma.

OLCULEN KUSUR (prod): `.env`teki anahtarin `-----END PRIVATE KEY-----`
satiri eksikti; ilk Apple girisi 500 donuyordu ve kimse acilista fark
etmedi. Simdi: kesik/bozuk/yanlis tur anahtar acilista HATA olarak
gunluge yazilir, Apple `hazir` olmaz (dugme gizli, 503 — 500 degil).
"""
from __future__ import annotations

import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec, rsa


def _pem(anahtar) -> str:
    return anahtar.private_bytes(
        serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption()).decode()


@pytest.fixture
def apple(monkeypatch):
    from app.config import settings

    monkeypatch.setattr(settings, "oauth_apple_client_id", "com.ornek.web")
    monkeypatch.setattr(settings, "oauth_apple_aud", "")
    monkeypatch.setattr(settings, "oauth_apple_team_id", "TEAM123456")
    monkeypatch.setattr(settings, "oauth_apple_key_id", "KEY1234567")
    monkeypatch.setattr(settings, "oauth_apple_private_key_file", "")

    def kur(icerik: str = "", dosya: str = ""):
        monkeypatch.setattr(settings, "oauth_apple_private_key", icerik)
        monkeypatch.setattr(settings, "oauth_apple_private_key_file", dosya)
    return kur


def _durum():
    from app.oauth import apple_anahtar_sorunu, saglayicilar

    return apple_anahtar_sorunu(), saglayicilar()["apple"].hazir


def test_GECERLI_tek_satir_env_kacisli(apple):
    apple(_pem(ec.generate_private_key(ec.SECP256R1())).replace("\n", "\\n"))
    assert _durum() == (None, True)


def test_GECERLI_tirnakli_env(apple):
    apple('"' + _pem(ec.generate_private_key(ec.SECP256R1())).replace("\n", "\\n") + '"')
    assert _durum() == (None, True)


def test_KESIK_anahtar_END_satiri_yok_APPLE_KAPALI(apple):
    """Prod'daki olay: son satir eksik."""
    pem = _pem(ec.generate_private_key(ec.SECP256R1()))
    apple(pem.replace("-----END PRIVATE KEY-----", "").replace("\n", "\\n"))
    sorun, hazir = _durum()
    assert "END PRIVATE KEY" in sorun and hazir is False


def test_GOVDESI_bozuk_anahtar(apple):
    apple("-----BEGIN PRIVATE KEY-----\\nbozuk\\n-----END PRIVATE KEY-----")
    sorun, hazir = _durum()
    assert "cozulemedi" in sorun and hazir is False


def test_RSA_anahtar_ES256_degil(apple):
    apple(_pem(rsa.generate_private_key(public_exponent=65537, key_size=2048)))
    sorun, hazir = _durum()
    assert "P-256" in sorun and hazir is False


def test_BOS_anahtar(apple):
    apple("")
    sorun, hazir = _durum()
    assert "BOS" in sorun and hazir is False


def test_DOSYADAN_okur_ve_icerige_yegdir(apple, tmp_path):
    p = tmp_path / "apple-auth.p8"
    p.write_text(_pem(ec.generate_private_key(ec.SECP256R1())))
    apple("bozuk-icerik", dosya=str(p))
    assert _durum() == (None, True)
    from app.oauth import _apple_istemci_sirri, saglayicilar

    import jwt
    sir = _apple_istemci_sirri(saglayicilar()["apple"])
    assert jwt.get_unverified_header(sir)["alg"] == "ES256"


def test_DOSYA_yoksa_APPLE_KAPALI(apple, tmp_path):
    apple("", dosya=str(tmp_path / "yok.p8"))
    sorun, hazir = _durum()
    assert "okunamadi" in sorun and hazir is False


def test_APPLE_yapilandirilmamissa_sorun_yok(monkeypatch):
    from app.config import settings
    from app.oauth import apple_anahtar_sorunu

    monkeypatch.setattr(settings, "oauth_apple_client_id", "")
    assert apple_anahtar_sorunu() is None


def test_ACILIS_gunlugu_HATA_yazar_icerigi_YAZMAZ(apple):
    import logging

    from app.main import _apple_anahtar_gunlukle

    kayitlar: list[logging.LogRecord] = []

    class _Topla(logging.Handler):
        def emit(self, record):
            kayitlar.append(record)

    h = _Topla(level=logging.ERROR)
    logging.getLogger("app.main").addHandler(h)
    try:
        apple("-----BEGIN PRIVATE KEY-----\\nGIZLIGOVDE\\n")
        _apple_anahtar_gunlukle()
    finally:
        logging.getLogger("app.main").removeHandler(h)
    metin = " ".join(r.getMessage() for r in kayitlar)
    assert "APPLE ILE GIRIS KAPALI" in metin
    assert "GIZLIGOVDE" not in metin
