"""Entegrasyon konfig CRUD + RBAC + sir-gizliligi + SSRF-korumali tetik + izolasyon.

RBAC (auth.md §4): YALNIZ admin+yonetici; digerleri 403. Sir GET'te donmez
(write-only). Tetik ic/ozel hedefi REDDEDER (SSRF). Tenant izole (RLS).
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


def _mk(client, admin, **over):
    body = {
        "ad": f"Entegrasyon {uuid.uuid4().hex[:6]}",
        "endpoint_url": "https://example.com/hook",
        "payload_template": '{"text": "{{message}}"}',
    }
    body.update(over)
    r = client.post("/integrations", headers=admin, json=body)
    assert r.status_code == 201, r.text
    return r.json()


# ------------------------------- RBAC --------------------------------------- #
def test_crud_rbac(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])

    # admin + yonetici olusturur
    a = _mk(client, admin)
    b = _mk(client, yonetici)
    assert client.get("/integrations", headers=yonetici).status_code == 200
    assert client.get(f"/integrations/{a['id']}", headers=admin).status_code == 200
    assert client.patch(
        f"/integrations/{a['id']}", headers=yonetici, json={"aktif": False}
    ).status_code == 200
    assert client.delete(f"/integrations/{b['id']}", headers=admin).status_code == 204

    # security/gorevli/resident: TUM uclarda 403
    for role in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.get("/integrations", headers=h).status_code == 403, role
        assert client.post(
            "/integrations", headers=h,
            json={"ad": "x", "endpoint_url": "https://example.com/h"},
        ).status_code == 403, role
        assert client.get(f"/integrations/{a['id']}", headers=h).status_code == 403, role
        assert client.patch(
            f"/integrations/{a['id']}", headers=h, json={"aktif": True}
        ).status_code == 403, role
        assert client.delete(f"/integrations/{a['id']}", headers=h).status_code == 403, role
        assert client.get("/integrations/presets", headers=h).status_code == 403, role
        assert client.post(
            f"/integrations/{a['id']}/trigger", headers=h, json={}
        ).status_code == 403, role


# --------------------------- sir gizliligi ---------------------------------- #
def test_sir_gette_donmez_writeonly(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    secret = "super-secret-token-XYZ"
    created = _mk(
        client, admin, auth_type="bearer", auth_secret=secret,
    )
    # Olusturma yaniti: sir yok, auth_secret_set=true
    assert "auth_secret" not in created and "auth_secret_enc" not in created
    assert created["auth_secret_set"] is True
    assert secret not in str(created)

    # GET detay + liste: sir ASLA gorunmez
    detay = client.get(f"/integrations/{created['id']}", headers=admin).json()
    assert secret not in str(detay) and "auth_secret" not in detay
    assert detay["auth_secret_set"] is True
    liste = client.get("/integrations", headers=admin).json()
    assert secret not in str(liste)

    # auth_type=none -> sir temizlenir
    upd = client.patch(
        f"/integrations/{created['id']}", headers=admin, json={"auth_type": "none"}
    ).json()
    assert upd["auth_secret_set"] is False


# ------------------------------ presetler ----------------------------------- #
def test_presetler(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    presets = client.get("/integrations/presets", headers=admin).json()
    keys = {p["key"] for p in presets}
    assert {"webhook-generic", "megaphone-generic", "smarthome-generic"} <= keys
    # her preset generic webhook uzerinde (channel_type + template dolu)
    for p in presets:
        assert p["http_method"] and p["payload_template"]


# ------------------------- SSRF-korumali tetik ------------------------------ #
def test_tetik_ic_hedefleri_reddeder(client, world):
    """KRITIK: ic/ozel/metadata URL'li entegrasyon tetiklenince SSRF ENGELI —
    {ok:false, error} (istek ic aga CIKMAZ). Coklu vaka."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    for url in (
        "http://127.0.0.1/x",
        "http://localhost/x",
        "http://10.0.0.5/x",
        "http://169.254.169.254/latest/meta-data/",
        "http://192.168.1.20/x",
    ):
        integ = _mk(client, admin, endpoint_url=url)
        r = client.post(f"/integrations/{integ['id']}/trigger", headers=admin, json={})
        assert r.status_code == 200, r.text
        out = r.json()
        assert out["ok"] is False, url
        assert out["error"], url  # engellendi mesaji


def test_gecersiz_sema_create_422(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/integrations", headers=admin,
        json={"ad": "x", "endpoint_url": "ftp://example.com/x"},
    )
    assert r.status_code == 422


# --------------------------- tenant izolasyonu ------------------------------ #
def test_tenant_izolasyonu(client, world):
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    a = _mk(client, admin_a)
    # B admini A'nin entegrasyonunu goremez/tetikleyemez (RLS -> 404)
    b_ids = {it["id"] for it in client.get("/integrations", headers=admin_b).json()["items"]}
    assert a["id"] not in b_ids
    assert client.get(f"/integrations/{a['id']}", headers=admin_b).status_code == 404
    assert client.post(
        f"/integrations/{a['id']}/trigger", headers=admin_b, json={}
    ).status_code == 404
