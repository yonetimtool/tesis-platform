"""(P243 §4) WEB GORUNUM MODU — hesapta saklanir."""
from __future__ import annotations


def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_VARSAYILAN_STANDART(client, world):
    admin = _h(client, world["slug_a"], world["admin_a"])
    assert client.get("/me", headers=admin).json()["ui_gorunum"] == "standart"


def test_BUYUK_KAYDEDILIR_ve_OTURUMLAR_ARASI_KALIR(client, world):
    """Tema ile ayni gerekce: baska tarayicida da ayni gorunum gelmeli."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    r = client.patch("/me/gorunum", headers=admin, json={"gorunum": "buyuk"})
    assert r.status_code == 200, r.text
    assert r.json()["ui_gorunum"] == "buyuk"
    # YENI OTURUM (yeni jeton) — tercih DURUYOR.
    yeni = _h(client, world["slug_a"], world["admin_a"])
    assert client.get("/me", headers=yeni).json()["ui_gorunum"] == "buyuk"


def test_GECERSIZ_DEGER_REDDEDILIR(client, world):
    # Sessizce standarda dusmek, kullaniciya ayarinin uygulandigini
    # sandirirdi.
    admin = _h(client, world["slug_a"], world["admin_a"])
    r = client.patch("/me/gorunum", headers=admin, json={"gorunum": "devasa"})
    assert r.status_code == 422


def test_HER_ROL_KENDI_GORUNUMUNU_AYARLAR(client, world):
    """Kozmetik tercih: rol kapisi YOK, herkes kendi hesabina yazar."""
    for rol in ("guard_a", "resident_a", "gorevli_a", "yonetici_a"):
        h = _h(client, world["slug_a"], world[rol])
        r = client.patch("/me/gorunum", headers=h, json={"gorunum": "buyuk"})
        assert r.status_code == 200, (rol, r.text)


def test_BASKASININ_GORUNUMU_DEGISMEZ(client, world):
    admin = _h(client, world["slug_a"], world["admin_a"])
    guard = _h(client, world["slug_a"], world["guard_a"])
    client.patch("/me/gorunum", headers=admin, json={"gorunum": "buyuk"})
    client.patch("/me/gorunum", headers=guard, json={"gorunum": "standart"})
    assert client.get("/me", headers=admin).json()["ui_gorunum"] == "buyuk"
    assert client.get("/me", headers=guard).json()["ui_gorunum"] == "standart"
