"""(P213 §1) GURULTU ESIKLERI YONETICI AYARINDA.

===========================================================================
OLCULEN KUSUR — SESSIZ VE IKI KATLI
===========================================================================
P208 uc ayari SEMAYA ekledi (`gurultu_pencere_gun`, `gurultu_susma_gun`,
`gurultu_sakin_uyarisi`) ama ne yoneticinin yazabilecegi alan listesine
ne de `_to_settings` yanitina koydu. Sonuc:

  * yonetici degistiremiyordu (403),
  * GET her tesiste SEMA VARSAYILANINI donuyordu — yani ekran gercek
    degeri HIC gostermemisti.

Ikincisi P165'te birebir olculmus bir kusur sinifi ("PATCH 200 doner,
deger yazilir, yanit sema varsayilanini tasir").

Ayrica eskalasyon esigi KOD SABITIYDI (`asama >= 2`); artik tesis ayari.
"""
from __future__ import annotations


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


VARSAYILAN = {
    "gurultu_esigi": 5,
    "gurultu_pencere_gun": 30,
    "gurultu_susma_gun": 7,
    "gurultu_eskalasyon_esigi": 1,
}


def _geri_al(client, h):
    client.patch("/tenant/settings", headers=h, json=VARSAYILAN)


def test_DORT_AYAR_da_yanitta_GORUNUR(client, world):
    """Kusurun yarisi buydu: yanit alanlari tasimiyordu."""
    h = _h(client, world["slug_a"], world["yonetici_a"])
    d = client.get("/tenant/settings", headers=h).json()
    for alan in VARSAYILAN:
        assert alan in d, f"{alan} yanitta YOK"
    assert "gurultu_sakin_uyarisi" in d


def test_YONETICI_dordunu_de_DEGISTIREBILIR_ve_yanit_GERCEK_degeri_doner(
    client, world
):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    try:
        r = client.patch("/tenant/settings", headers=h, json={
            "gurultu_esigi": 8, "gurultu_pencere_gun": 60,
            "gurultu_susma_gun": 14, "gurultu_eskalasyon_esigi": 2,
        })
        assert r.status_code == 200, r.text
        d = r.json()
        # YANIT GERCEK DEGERI TASIR (sema varsayilani DEGIL).
        assert d["gurultu_esigi"] == 8
        assert d["gurultu_pencere_gun"] == 60
        assert d["gurultu_susma_gun"] == 14
        assert d["gurultu_eskalasyon_esigi"] == 2
        # GET de ayni seyi soyler.
        g = client.get("/tenant/settings", headers=h).json()
        assert g["gurultu_pencere_gun"] == 60 and g["gurultu_eskalasyon_esigi"] == 2
    finally:
        _geri_al(client, h)


def test_GECERSIZ_degerler_422(client, world):
    """Sessizce kabul YOK — sinirlar DB CHECK'iyle AYNI."""
    h = _h(client, world["slug_a"], world["yonetici_a"])
    gecersiz = [
        {"gurultu_esigi": 0},            # 1'den kucuk olamaz
        {"gurultu_esigi": 51},           # ust sinir
        {"gurultu_pencere_gun": -1},
        {"gurultu_pencere_gun": 366},
        {"gurultu_susma_gun": 400},
        {"gurultu_eskalasyon_esigi": 0},  # "her uyarida guvenlik" olurdu
        {"gurultu_eskalasyon_esigi": 11},
    ]
    for govde in gecersiz:
        r = client.patch("/tenant/settings", headers=h, json=govde)
        assert r.status_code == 422, f"{govde} -> {r.status_code} {r.text}"


def test_ESIK_1_KABUL_EDILIR_ama_sinirin_ucundadir(client, world):
    """1 gecerlidir (her sikayette anons) — kullanicinin bilincli
    tercihi olabilir; arayuz UYARIR, uc REDDETMEZ."""
    h = _h(client, world["slug_a"], world["yonetici_a"])
    try:
        r = client.patch("/tenant/settings", headers=h, json={"gurultu_esigi": 1})
        assert r.status_code == 200, r.text
        assert r.json()["gurultu_esigi"] == 1
    finally:
        _geri_al(client, h)


def test_DEGISIKLIK_DENETIME_yazilir(client, world, owner_conn):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    try:
        client.patch("/tenant/settings", headers=h, json={"gurultu_pencere_gun": 45})
        owner_conn.commit()
        satirlar = owner_conn.execute(
            "SELECT meta FROM audit_log WHERE tenant_id=%s AND resource_type='tenant' "
            "ORDER BY ts DESC LIMIT 5", (world["a"],)).fetchall()
        metalar = [r[0] for r in satirlar if r[0] and r[0].get("islem") == "gurultu_ayari"]
        assert metalar, "gurultu ayari denetime YAZILMADI"
        assert metalar[0]["yeni"]["gurultu_pencere_gun"] == 45
    finally:
        _geri_al(client, h)


def test_TESIS_BAZINDA_platform_geneli_DEGIL(client, world):
    """A'nin esigi B'yi ETKILEMEZ."""
    a = _h(client, world["slug_a"], world["yonetici_a"])
    b = _h(client, world["slug_b"], world["admin_b"])
    try:
        client.patch("/tenant/settings", headers=a, json={"gurultu_esigi": 9})
        assert client.get("/tenant/settings", headers=b).json()["gurultu_esigi"] != 9
    finally:
        _geri_al(client, a)


def test_DENETCI_degistiremez(client, world):
    """Salt-okuma rolu ayar yazamaz."""
    h = _h(client, world["slug_a"], world["denetci_a"])
    r = client.patch("/tenant/settings", headers=h, json={"gurultu_esigi": 7})
    assert r.status_code == 403, r.text
