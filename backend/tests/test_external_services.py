"""Dis Hizmetler — /external-services CRUD + not + RBAC + tenant izolasyon.

Yonetici (+admin) yazar; TUM roller (guvenlik/sakin dahil) okur.
"""
from __future__ import annotations


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _svc(tur="Çilingir", ad="Ali", soyad="Usta", telefon="+905551112233", **o):
    b = {"tur": tur, "ad": ad, "soyad": soyad, "telefon": telefon}
    b.update(o)
    return b


def test_yonetici_crud_ve_not(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    # ekle
    r = client.post("/external-services", headers=yon, json=_svc(aciklama="7/24 acar"))
    assert r.status_code == 201, r.text
    sid = r.json()["id"]
    assert r.json()["tur"] == "Çilingir" and r.json()["aciklama"] == "7/24 acar"

    # not ayarla
    note = "Yillardir guvendigimiz esnaflar; yabanci sokmayin."
    nr = client.put("/external-services/note", headers=yon, json={"note": note})
    assert nr.status_code == 200 and nr.json()["note"] == note

    # liste: not + kisi
    lst = client.get("/external-services", headers=yon).json()
    assert lst["note"] == note
    assert any(it["id"] == sid for it in lst["items"])

    # duzenle
    pr = client.patch(
        f"/external-services/{sid}", headers=yon, json={"telefon": "+905559998877"}
    )
    assert pr.status_code == 200 and pr.json()["telefon"] == "+905559998877"

    # sil
    assert client.delete(f"/external-services/{sid}", headers=yon).status_code == 204
    assert all(
        it["id"] != sid
        for it in client.get("/external-services", headers=yon).json()["items"]
    )


def test_okuma_tum_roller_yazma_yonetim(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    client.post("/external-services", headers=admin, json=_svc(tur="Elektrik"))
    # OKUMA: tum roller 200
    for role in ("admin_a", "yonetici_a", "guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.get("/external-services", headers=h).status_code == 200, role
    # YAZMA: yalniz admin + yonetici; digerleri 403
    for role in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.post("/external-services", headers=h, json=_svc()).status_code == 403, role
        assert client.put(
            "/external-services/note", headers=h, json={"note": "x"}
        ).status_code == 403, role


def test_tenant_izolasyonu(client, world):
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post("/external-services", headers=admin_a, json=_svc(ad="Gizli"))
    sid = r.json()["id"]
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    ids_b = {it["id"] for it in client.get("/external-services", headers=admin_b).json()["items"]}
    assert sid not in ids_b
    # B, A'nin kaydini goremez/silemez -> 404
    assert client.delete(f"/external-services/{sid}", headers=admin_b).status_code == 404
