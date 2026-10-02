"""(P250 §5) Giris ekranlarinda e-posta siniri: 254 karakter, SUNUCUDA.

Istemci sinirlari (web `TelefonAlani` kimlik kipi, mobil
`LengthLimitingTextInputFormatter`) kullaniciyi durdurur; asil koruma
burada. Olculen: 255+ karakterlik kimlik/e-posta 422 alir, 254 karakterlik
gecerli bir adres SINIR yuzunden reddedilmez.
"""
from __future__ import annotations

import uuid


def _eposta(n: int) -> str:
    """Tam `n` karakterlik, bicimce GECERLI bir adres (etiketler <= 63)."""
    yerel = "a" * 60
    kalan = n - len(yerel) - 1 - len(".com")
    etiketler = []
    while kalan > 0:
        k = min(50, kalan - 1) if kalan > 51 else kalan
        etiketler.append("b" * k)
        kalan -= k + 1
    adres = f"{yerel}@{'.'.join(etiketler)}.com"
    assert len(adres) == n, (len(adres), n)
    return adres


def test_login_kimlik_254_ustu_422(client):
    r = client.post(
        "/auth/login", json={"kimlik": "x" * 255, "password": "Parola123!"}
    )
    assert r.status_code == 422, r.text


def test_login_kimlik_254_sinir_yuzunden_reddedilmez(client):
    r = client.post(
        "/auth/login", json={"kimlik": _eposta(254), "password": "Parola123!"}
    )
    # Hesap yok -> 401; ONEMLI olan 422 (sinir) OLMAMASI.
    assert r.status_code != 422, r.text


def test_kod_ile_giris_ve_sifremi_unuttum_254_ustu_422(client):
    uzun = _eposta(254) + "x"  # 255
    for yol, govde in (
        ("/auth/giris/eposta-kod-iste", {"eposta": uzun}),
        ("/auth/giris/eposta-kod-dogrula", {"eposta": uzun, "kod": "123456"}),
        ("/auth/sifre/kod-iste", {"tenant_slug": "yok", "eposta": uzun}),
        (
            "/auth/sifre/dogrula-ve-ayarla",
            {
                "tenant_slug": "yok",
                "eposta": uzun,
                "kod": "123456",
                "yeni_parola": "CokGizli123!",
            },
        ),
    ):
        r = client.post(yol, json=govde)
        assert r.status_code == 422, (yol, r.status_code, r.text)


def test_kod_iste_254_gecerli_adres_kabul(client):
    # Benzersiz yerel kisim: hiz siniri (adres basina 3/15 dk) baska
    # kosumlarla carpismasin.
    adres = _eposta(254)
    adres = uuid.uuid4().hex[:8] + adres[8:]
    r = client.post("/auth/giris/eposta-kod-iste", json={"eposta": adres})
    assert r.status_code != 422, r.text
