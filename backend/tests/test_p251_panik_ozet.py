"""(P251 §1) ACIL DURUM TAKIBI — sayilar sunucuda, durumlar enum'dan.

Olculen (ekranda goruldu):
  * "Acik cagri" yanlis alarm ve iptali SAYMAZ (istemci `kapandi_at`
    boslugundan sayiyordu; iptal/yanlis alarm o damgayi yazmaz),
  * kapatilan alarm acik sayisindan duser,
  * `durumlar` sunucunun TUM enum degerleri ("yanlis_alarm" dahil),
  * bilinmeyen durum 422 (500 degil), `?durum=yanlis_alarm` suzer,
  * `tatbikat` suzgeci gercek ve tatbikati ayirir; ozet tatbikati saymaz.
"""
from __future__ import annotations


def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _yayinla(alarm_id, client, admin):
    from app.tasks import panik_yayinla

    tid = client.get("/me", headers=admin).json()["tenant_id"]
    return panik_yayinla(alarm_id, tid)


def _ozet(client, h, **q):
    r = client.get("/panik", headers=h, params={"limit": 200, **q})
    assert r.status_code == 200, r.text
    return r.json()


def test_acik_sayisi_DURUMDAN_iptal_ve_yanlis_alarm_kapanan(client, world):
    sakin = _h(client, world["slug_a"], world["resident_a"])
    admin = _h(client, world["slug_a"], world["admin_a"])
    once = _ozet(client, admin)["ozet"]

    # 1) iptal penceresinde iptal -> "iptal"
    a1 = client.post("/panik", headers=sakin, json={"tip": "sakin"}).json()
    client.post(f"/panik/{a1['id']}/iptal", headers=sakin)
    # 2) gonderildikten sonra iptal -> "yanlis_alarm"
    a2 = client.post("/panik", headers=sakin, json={"tip": "sakin"}).json()
    _yayinla(a2["id"], client, admin)
    assert client.post(f"/panik/{a2['id']}/iptal", headers=sakin).json()["durum"] == "yanlis_alarm"
    # 3) gercekten acik, sonra kapatilan
    a3 = client.post("/panik", headers=sakin, json={"tip": "sakin"}).json()
    _yayinla(a3["id"], client, admin)

    ara = _ozet(client, admin)["ozet"]
    assert ara["acik"] == once["acik"] + 1, (once, ara)
    assert ara["yanlis_alarm"] == once["yanlis_alarm"] + 1
    assert ara["iptal"] == once["iptal"] + 1
    assert ara["kapanan"] == once["kapanan"] + 2
    assert ara["bugun"] >= once["bugun"] + 3

    assert client.post(f"/panik/{a3['id']}/kapat", headers=admin, json={}).status_code == 200
    son = _ozet(client, admin)["ozet"]
    assert son["acik"] == once["acik"]
    assert son["kapanan"] == once["kapanan"] + 3

    # Ozet DURUM SUZGECINDEN BAGIMSIZ.
    assert _ozet(client, admin, durum="kapandi")["ozet"] == son


def test_durumlar_ENUMDAN_ve_suzgec(client, world):
    from app.models import PANIK_DURUM

    admin = _h(client, world["slug_a"], world["admin_a"])
    g = _ozet(client, admin)
    assert g["durumlar"] == list(PANIK_DURUM.enums)
    assert "yanlis_alarm" in g["durumlar"]
    yanlis = _ozet(client, admin, durum="yanlis_alarm")["items"]
    assert all(i["durum"] == "yanlis_alarm" for i in yanlis)
    r = client.get("/panik", headers=admin, params={"durum": "uydurma"})
    assert r.status_code == 422, r.text


def test_tatbikat_suzgeci_ve_ozet_tatbikati_saymaz(client, world, owner_conn):
    admin = _h(client, world["slug_a"], world["admin_a"])
    sakin = _h(client, world["slug_a"], world["resident_a"])
    a = client.post("/panik", headers=sakin, json={"tip": "sakin"}).json()
    _yayinla(a["id"], client, admin)
    once = _ozet(client, admin)["ozet"]
    # Alarmi tatbikata baglamak icin bir tatbikat satiri (dogrudan): API
    # tatbikati kategori/kapsamla baslatir ve tum tesise yayin yapar.
    t = owner_conn.execute(
        "INSERT INTO panik_tatbikat (tenant_id, kategori, kapsam, durum) "
        "VALUES (%s, 'deprem', 'site', 'aktif') RETURNING id::text",
        (world["a"],),
    ).fetchone()[0]
    owner_conn.execute(
        "UPDATE panik_alarm SET tatbikat_id=%s WHERE id=%s", (t, a["id"]))
    sonra = _ozet(client, admin)["ozet"]
    assert sonra["acik"] == once["acik"] - 1
    assert sonra["tatbikat"] == once["tatbikat"] + 1

    gercek = {i["id"] for i in _ozet(client, admin, tatbikat="false")["items"]}
    tatbikat = _ozet(client, admin, tatbikat="true")["items"]
    assert a["id"] not in gercek
    assert a["id"] in {i["id"] for i in tatbikat}
    assert all(i["tatbikat"] for i in tatbikat)
    owner_conn.execute("UPDATE panik_alarm SET tatbikat_id=NULL, durum='kapandi' WHERE id=%s", (a["id"],))
    owner_conn.execute("DELETE FROM panik_tatbikat WHERE id=%s", (t,))
