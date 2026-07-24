"""Profil fotografi (WP-D) — PATCH /me/avatar RBAC + tenant-onek + temizlik."""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _upload_foto(client, headers) -> str:
    """presign -> MinIO'ya PUT -> foto_key (announcement testleriyle ayni akis)."""
    import httpx

    r = client.post(
        "/uploads/presign", headers=headers,
        json={"content_type": "image/jpeg", "dosya_adi": "avatar.jpg"},
    )
    assert r.status_code == 200, r.text
    t = r.json()
    put = httpx.put(
        t["upload_url"], content=b"fake-jpeg-bytes",
        headers={"Content-Type": "image/jpeg"}, timeout=10,
    )
    assert put.status_code in (200, 204), put.text
    return t["foto_key"]


def test_yonetici_avatar_yukler_me_gorur_null_kaldirir(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    key = _upload_foto(client, yonetici)

    r = client.patch("/me/avatar", headers=yonetici, json={"avatar_key": key})
    assert r.status_code == 200, r.text
    assert r.json()["avatar_url"]  # presigned GET URL

    assert client.get("/me", headers=yonetici).json()["avatar_url"]

    r = client.patch("/me/avatar", headers=yonetici, json={"avatar_key": None})
    assert r.status_code == 200
    assert r.json()["avatar_url"] is None


def test_resident_403_yabanci_onek_422(client, world):
    resident = _headers(client, world["slug_a"], world["resident_a"])
    r = client.patch("/me/avatar", headers=resident, json={"avatar_key": "x/y.jpg"})
    assert r.status_code == 403

    guard = _headers(client, world["slug_a"], world["guard_a"])
    yabanci = f"{uuid.uuid4()}/avatars/kacak.jpg"  # baska tenant onegi -> IDOR engeli
    r = client.patch("/me/avatar", headers=guard, json={"avatar_key": yabanci})
    assert r.status_code == 422


def test_iletisim_kartinda_yonetici_avatari(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    key = _upload_foto(client, yonetici)
    client.patch("/me/avatar", headers=yonetici, json={"avatar_key": key})

    resident = _headers(client, world["slug_a"], world["resident_a"])
    r = client.get("/yonetici-iletisim", headers=resident)
    assert r.status_code == 200, r.text
    # Yanit sekli: {"yoneticiler": [YoneticiKart...], "yonetim_email": ...}
    assert any(k.get("avatar_url") for k in r.json()["yoneticiler"])
