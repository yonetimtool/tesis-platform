"""Saha personeli avatari (P3) — yonetici yonetir; /me/avatar RBAC daraldi."""
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
    import httpx

    r = client.post(
        "/uploads/presign", headers=headers,
        json={"content_type": "image/jpeg", "dosya_adi": "p.jpg"},
    )
    assert r.status_code == 200, r.text
    t = r.json()
    put = httpx.put(t["upload_url"], content=b"x",
                    headers={"Content-Type": "image/jpeg"}, timeout=10)
    assert put.status_code in (200, 204), put.text
    return t["foto_key"]


def _staff_id(client, world, role):
    who = {"security": "guard_a", "tesis_gorevlisi": "gorevli_a"}[role]
    me = _headers(client, world["slug_a"], world[who])
    return client.get("/me", headers=me).json()["id"]


def test_me_avatar_rbac_yonetici_resident_evet_digerleri_403(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    res = _headers(client, world["slug_a"], world["resident_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])

    key_y = _upload_foto(client, yon)
    assert client.patch("/me/avatar", headers=yon,
                        json={"avatar_key": key_y}).status_code == 200
    key_r = _upload_foto(client, res)
    assert client.patch("/me/avatar", headers=res,
                        json={"avatar_key": key_r}).status_code == 200
    # saha rolleri + admin self-servis KAPALI
    for h in (guard, admin):
        assert client.patch("/me/avatar", headers=h,
                            json={"avatar_key": None}).status_code == 403


def test_yonetici_saha_personeline_avatar_atar_listede_gorunur(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    gid = _staff_id(client, world, "security")
    key = _upload_foto(client, yon)

    r = client.patch(f"/users/{gid}/avatar", headers=yon,
                     json={"avatar_key": key})
    assert r.status_code == 200, r.text
    assert r.json()["avatar_url"]

    r = client.get("/users", headers=yon, params={"role": "security"})
    item = next(i for i in r.json()["items"] if i["id"] == gid)
    assert item["avatar_url"]


def test_users_avatar_rbac_ve_hedef_kisiti(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    yon = _headers(client, world["slug_a"], world["yonetici_a"])

    gid = _staff_id(client, world, "security")
    # admin + guard bu ucu KULLANAMAZ (yalniz yonetici)
    for h in (admin, guard):
        assert client.patch(f"/users/{gid}/avatar", headers=h,
                            json={"avatar_key": None}).status_code == 403
    # hedef saha disi (resident) -> 422
    res_me = _headers(client, world["slug_a"], world["resident_a"])
    rid = client.get("/me", headers=res_me).json()["id"]
    key = _upload_foto(client, yon)
    assert client.patch(f"/users/{rid}/avatar", headers=yon,
                        json={"avatar_key": key}).status_code == 422
    # yabanci onek -> 422
    assert client.patch(f"/users/{gid}/avatar", headers=yon,
                        json={"avatar_key": f"{uuid.uuid4()}/x.jpg"}).status_code == 422


def test_users_avatar_tenant_izolasyonu(client, world):
    yon_b = _headers(client, world["slug_b"], world["yonetici_b"])
    gid_a = _staff_id(client, world, "security")  # tenant A personeli
    r = client.patch(f"/users/{gid_a}/avatar", headers=yon_b,
                     json={"avatar_key": None})
    assert r.status_code == 404  # RLS: B, A'nin kullanicisini goremez
