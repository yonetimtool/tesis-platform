"""(P251 §10) PLATFORM GONDERIM GUNLUGU — e-posta, SMS, push; tum tesisler.

Olculen:
  * yalniz admin (yonetici 403); yonetici ham gunlugu (`/mesajlar/gecmis`,
    `/push/teshis`) de goremez,
  * iki tesisin kayitlari tek listede, tesis adiyla,
  * arama (alici adresi / hata), tesis, kanal, "yalniz basarisiz" suzgecleri,
  * push satiri kanal "push", hedef jetonun yalniz son 6 hanesi.
"""
from __future__ import annotations

import uuid


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _mesaj(owner_conn, tenant, hedef, durum, hata=None, kanal="eposta"):
    return owner_conn.execute(
        "INSERT INTO mesaj_gonderim (tenant_id, kanal, amac, hedef, govde, durum, hata, tur) "
        "VALUES (%s, %s, 'operasyonel', %s, 'x', %s, %s, 'odeme_kodu') RETURNING id::text",
        (tenant, kanal, hedef, durum, hata)).fetchone()[0]


def test_yalniz_platform(client, world):
    y = _h(client, world["slug_a"], world["yonetici_a"])
    assert client.get("/platform/gonderim-gunlugu", headers=y).status_code == 403
    assert client.get("/mesajlar/gecmis", headers=y).status_code == 403
    assert client.get("/push/teshis", headers=y).status_code == 403


def test_iki_tesis_arama_ve_suzgecler(client, world, owner_conn):
    adm = _h(client, world["slug_a"], world["admin_a"])
    ek = uuid.uuid4().hex[:8]
    a_ok = _mesaj(owner_conn, world["a"], f"p251-{ek}-a@ornek.com", "iletildi")
    a_kotu = _mesaj(owner_conn, world["a"], f"p251-{ek}-b@ornek.com", "basarisiz",
                    hata="535 5.7.8 Authentication failed")
    b_kotu = _mesaj(owner_conn, world["b"], f"p251-{ek}-c@ornek.com", "basarisiz", hata="bounce")
    p = owner_conn.execute(
        "INSERT INTO push_gonderim (tenant_id, kimlik, token_son6, platform, saglayici, durum, hata_kodu) "
        "VALUES (%s, 'kacirilan_tur', %s, 'android', 'fcm', 'gecersiz_token', 'UNREGISTERED') "
        "RETURNING id::text", (world["b"], ek[:6])).fetchone()[0]

    def liste(**q):
        r = client.get("/platform/gonderim-gunlugu", headers=adm, params={"limit": 200, **q})
        assert r.status_code == 200, r.text
        return r.json()

    hepsi = {i["id"]: i for i in liste(ara=f"p251-{ek}")["items"]}
    assert set(hepsi) == {a_ok, a_kotu, b_kotu}
    assert hepsi[a_kotu]["hata"].startswith("535")
    assert hepsi[b_kotu]["tesis_ad"] and hepsi[a_kotu]["tesis_ad"] != hepsi[b_kotu]["tesis_ad"]

    basarisiz = {i["id"] for i in liste(ara=f"p251-{ek}", basarisiz="true")["items"]}
    assert basarisiz == {a_kotu, b_kotu}
    sadece_b = {i["id"] for i in liste(ara=f"p251-{ek}", tenant_id=str(world["b"]))["items"]}
    assert sadece_b == {b_kotu}
    # Hata metninde arama.
    assert a_kotu in {i["id"] for i in liste(ara="5.7.8")["items"]}

    pushlar = {i["id"]: i for i in liste(kanal="push", basarisiz="true", tenant_id=str(world["b"]))["items"]}
    assert p in pushlar
    assert pushlar[p]["kanal"] == "push"
    assert pushlar[p]["hedef"].endswith(ek[:6]) and pushlar[p]["amac"] == "kacirilan_tur"
    assert client.get("/platform/gonderim-gunlugu", headers=adm,
                      params={"kanal": "faks"}).status_code == 422
