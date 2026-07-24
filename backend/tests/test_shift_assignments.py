"""Vardiya atamasi (WP-E) — PUT /shifts/{id}/assignments RBAC + rol kisiti."""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _me_id(client, headers):
    return client.get("/me", headers=headers).json()["id"]


def _vardiya_ac(client, admin_headers) -> str:
    r = client.post(
        "/shifts", headers=admin_headers,
        json={"ad": f"Test-{uuid.uuid4().hex[:6]}", "baslangic_saat": "06:00",
              "bitis_saat": "14:00"},
    )
    assert r.status_code == 201, r.text
    return r.json()["id"]


def test_yonetici_atar_listede_personel_gorunur(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])
    sid = _vardiya_ac(client, admin)

    r = client.put(
        f"/shifts/{sid}/assignments", headers=yonetici,
        json={"user_ids": [_me_id(client, guard), _me_id(client, gorevli)]},
    )
    assert r.status_code == 200, r.text
    assert len(r.json()["personel"]) == 2
    assert {p["ad"] for p in r.json()["personel"]} == {"Guard A", "Gorevli A"}

    # GET listesi de personeli tasir (security okuyabilir)
    r = client.get("/shifts", headers=guard)
    item = next(i for i in r.json()["items"] if i["id"] == sid)
    assert len(item["personel"]) == 2

    # declarative replace: bos liste atamayi temizler
    r = client.put(f"/shifts/{sid}/assignments", headers=yonetici,
                   json={"user_ids": []})
    assert r.status_code == 200 and r.json()["personel"] == []


def test_rbac_ve_rol_kisiti(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])
    sid = _vardiya_ac(client, admin)

    # security/resident atama YAPAMAZ
    for h in (guard, resident):
        r = client.put(f"/shifts/{sid}/assignments", headers=h,
                       json={"user_ids": []})
        assert r.status_code == 403

    # resident ATANAMAZ (yalniz security|tesis_gorevlisi)
    r = client.put(
        f"/shifts/{sid}/assignments", headers=admin,
        json={"user_ids": [_me_id(client, resident)]},
    )
    assert r.status_code == 422


def test_tenant_izolasyonu(client, world):
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    yonetici_b = _headers(client, world["slug_b"], world["yonetici_b"])
    sid = _vardiya_ac(client, admin_a)
    r = client.put(f"/shifts/{sid}/assignments", headers=yonetici_b,
                   json={"user_ids": []})
    assert r.status_code == 404  # RLS: B, A'nin vardiyasini goremez
