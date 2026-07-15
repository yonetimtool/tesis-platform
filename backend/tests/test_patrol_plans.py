"""Devriye plani (patrol_plan) — yonetici CRUD + checkpoint atama + RBAC.

Yonetici uygulamada devriye plani tanimlar: ad + saatler + tur sikligi
(periyot_dakika) + kontrol noktalari (tumu/spesifik). Yazma admin + yonetici;
saha rolleri yalniz OKUR.
"""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _checkpoint(client, h, ad="CP"):
    nfc = f"NFC-{uuid.uuid4().hex[:10]}"
    r = client.post("/checkpoints", headers=h, json={"ad": ad, "nfc_tag_uid": nfc})
    assert r.status_code == 201, r.text
    return r.json()["id"]


def _plan_body(**o):
    b = {
        "ad": "Gece devriyesi",
        "baslangic_saat": "22:00:00",
        "bitis_saat": "06:00:00",
        "periyot_dakika": 60,
    }
    b.update(o)
    return b


def test_yonetici_plan_crud_ve_checkpoint_atama(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    # olustur
    r = client.post("/patrol-plans", headers=yon, json=_plan_body())
    assert r.status_code == 201, r.text
    pid = r.json()["id"]
    assert r.json()["periyot_dakika"] == 60

    # duzenle (saat + tur sikligi)
    pr = client.patch(
        f"/patrol-plans/{pid}",
        headers=yon,
        json={"baslangic_saat": "23:00:00", "periyot_dakika": 30},
    )
    assert pr.status_code == 200, pr.text
    assert pr.json()["periyot_dakika"] == 30

    # checkpoint atama (spesifik/tumu — burada 2 nokta, sirali)
    cp1 = _checkpoint(client, yon, "Giris")
    cp2 = _checkpoint(client, yon, "Cikis")
    a = client.put(
        f"/patrol-plans/{pid}/checkpoints",
        headers=yon,
        json={"items": [{"checkpoint_id": cp1}, {"checkpoint_id": cp2}]},
    )
    assert a.status_code == 200, a.text
    got = client.get(f"/patrol-plans/{pid}/checkpoints", headers=yon).json()
    assert [c["checkpoint_id"] for c in got] == [cp1, cp2]  # sira korunur

    # detay checkpoint'leri icerir
    detay = client.get(f"/patrol-plans/{pid}", headers=yon).json()
    assert len(detay["checkpoints"]) == 2

    # sil
    assert client.delete(f"/patrol-plans/{pid}", headers=yon).status_code == 204
    assert client.get(f"/patrol-plans/{pid}", headers=yon).status_code == 404


def test_plan_rbac(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    pid = client.post("/patrol-plans", headers=yon, json=_plan_body()).json()["id"]
    # yazma yalniz admin + yonetici; saha/resident -> 403
    for role in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.post("/patrol-plans", headers=h, json=_plan_body()).status_code == 403, role
        assert client.patch(
            f"/patrol-plans/{pid}", headers=h, json={"periyot_dakika": 90}
        ).status_code == 403, role
        assert client.put(
            f"/patrol-plans/{pid}/checkpoints", headers=h, json={"items": []}
        ).status_code == 403, role
    # OKUMA: yonetici + saha (security/tesis_gorevlisi) 200; resident 403
    for role in ("yonetici_a", "guard_a", "gorevli_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.get("/patrol-plans", headers=h).status_code == 200, role
    resident = _headers(client, world["slug_a"], world["resident_a"])
    assert client.get("/patrol-plans", headers=resident).status_code == 403
