"""Platform destek kanali (WP1) — RBAC + RLS + admin capraz-tenant.

POST /support: YALNIZ yonetici. GET /support: yonetici kendi tenant'i (RLS).
GET /support/all + PATCH /support/{id}: YALNIZ admin (SECURITY DEFINER).
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


def _acir(client, headers, konu="Panel açılmıyor"):
    return client.post(
        "/support",
        headers=headers,
        json={"konu": konu, "aciklama": "Detaylı açıklama metni."},
    )


def test_yonetici_bilet_acar_ve_kendi_tenantini_gorur(client, world):
    yon_a = _headers(client, world["slug_a"], world["yonetici_a"])
    r = _acir(client, yon_a)
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["konu"] == "Panel açılmıyor"
    assert body["durum"] == "acik"
    assert body["admin_cevap"] is None

    lst = client.get("/support", headers=yon_a)
    assert lst.status_code == 200
    assert any(t["id"] == body["id"] for t in lst.json()["items"])


def test_rbac_yalniz_yonetici_acar(client, world):
    for kim in ["admin_a", "guard_a", "gorevli_a", "resident_a"]:
        h = _headers(client, world["slug_a"], world[kim])
        assert _acir(client, h).status_code == 403, kim


def test_rls_izolasyon_yonetici_b_a_biletini_gormez(client, world):
    yon_a = _headers(client, world["slug_a"], world["yonetici_a"])
    tid = _acir(client, yon_a).json()["id"]

    yon_b = _headers(client, world["slug_b"], world["yonetici_b"])
    lst_b = client.get("/support", headers=yon_b)
    assert lst_b.status_code == 200
    assert all(t["id"] != tid for t in lst_b.json()["items"])


def test_admin_tum_tenantlari_listeler_ve_yanitlar(client, world):
    yon_a = _headers(client, world["slug_a"], world["yonetici_a"])
    yon_b = _headers(client, world["slug_b"], world["yonetici_b"])
    ta = _acir(client, yon_a, konu="A bileti").json()["id"]
    tb = _acir(client, yon_b, konu="B bileti").json()["id"]

    admin = _headers(client, world["slug_a"], world["admin_a"])
    allr = client.get("/support/all", headers=admin, params={"limit": 200})
    assert allr.status_code == 200
    ids = {t["id"] for t in allr.json()["items"]}
    assert {ta, tb} <= ids  # capraz-tenant: iki tenant'in bileti de gorunur

    # tenant filtresi
    fr = client.get(
        "/support/all", headers=admin,
        params={"tenant_id": str(world["b"]), "limit": 200},
    )
    fids = {t["id"] for t in fr.json()["items"]}
    assert tb in fids and ta not in fids

    # admin yaniti + cozuldu
    pr = client.patch(
        f"/support/{ta}", headers=admin,
        json={"durum": "cozuldu", "admin_cevap": "Guncelleme yayinlandi."},
    )
    assert pr.status_code == 200, pr.text
    assert pr.json()["durum"] == "cozuldu"
    assert pr.json()["admin_cevap"] == "Guncelleme yayinlandi."

    # yonetici kendi listesinde cevabi gorur + durum filtresi calisir
    mine = client.get("/support", headers=yon_a).json()["items"]
    me = next(t for t in mine if t["id"] == ta)
    assert me["durum"] == "cozuldu" and me["admin_cevap"]
    fr2 = client.get("/support/all", headers=admin, params={"durum": "acik", "limit": 200})
    assert ta not in {t["id"] for t in fr2.json()["items"]}


def test_patch_yalniz_admin_ve_cross_tenant_404(client, world):
    yon_a = _headers(client, world["slug_a"], world["yonetici_a"])
    tid = _acir(client, yon_a).json()["id"]

    # yonetici yanitlayamaz
    assert client.patch(
        f"/support/{tid}", headers=yon_a, json={"durum": "cozuldu"}
    ).status_code == 403
    # admin /support/all disinda: olmayan id -> 404 (bilgi sizdirmaz)
    admin = _headers(client, world["slug_a"], world["admin_a"])
    assert client.patch(
        f"/support/{uuid.uuid4()}", headers=admin, json={"durum": "cozuldu"}
    ).status_code == 404
    # gecersiz durum -> 422
    assert client.patch(
        f"/support/{tid}", headers=admin, json={"durum": "kapandi"}
    ).status_code == 422


def test_audit_kaydi_create_ve_durum_degisikligi(client, world, owner_conn):
    yon_a = _headers(client, world["slug_a"], world["yonetici_a"])
    tid = _acir(client, yon_a).json()["id"]
    admin = _headers(client, world["slug_a"], world["admin_a"])
    client.patch(f"/support/{tid}", headers=admin, json={"durum": "cozuldu"})

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT action FROM audit_log WHERE resource_type='support_ticket' "
            "AND resource_id=%s ORDER BY ts",
            (str(tid),),
        )
        actions = [r[0] for r in cur.fetchall()]
    assert "support_ticket_create" in actions
    assert "support_ticket_update" in actions
