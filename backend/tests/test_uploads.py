"""POST /uploads/presign — gorsel content-type allow-list + boyut sinirlama
(PresignRequest, Task 3) + tenant-onekli foto_key (storage.make_foto_key).
"""
from __future__ import annotations


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_presign_rejects_non_image(client, world):
    h = _headers(client, world["slug_a"], world["resident_a"])
    r = client.post(
        "/uploads/presign", headers=h, json={"content_type": "application/pdf"}
    )
    assert r.status_code == 422


def test_presign_image_ok_and_key_is_tenant_prefixed(client, world):
    h = _headers(client, world["slug_a"], world["resident_a"])
    r = client.post(
        "/uploads/presign", headers=h, json={"content_type": "image/jpeg", "boyut": 1024}
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["method"] == "PUT"
    assert body["foto_key"].startswith(f"{world['a']}/")


def test_presign_rejects_oversize(client, world):
    h = _headers(client, world["slug_a"], world["resident_a"])
    r = client.post(
        "/uploads/presign",
        headers=h,
        json={"content_type": "image/png", "boyut": 9 * 1024 * 1024},
    )
    assert r.status_code == 422
