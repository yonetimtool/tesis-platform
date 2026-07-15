"""Site sakini yonetimi — POST/GET/DELETE /residents (yonetici/admin).

Sakin KENDI kayit olamaz; yonetici ekler (daire + gecici kod), listeler ve
siteden cikarir (pasiflestir + daire bagini bitir). Telefon KVKK geregi listede
donmez. Canli API'ye vurur.
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


def _uphone() -> str:
    return "+90" + str(uuid.uuid4().int)[:10]


def test_add_list_remove_resident(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    phone = _uphone()

    # EKLE -> 201 + gecici kod + daire olusur
    r = client.post(
        "/residents",
        headers=yon,
        json={"ad": "Yeni Sakin", "telefon": phone, "unit_no": "R-1"},
    )
    assert r.status_code == 201, r.text
    temp = r.json()["temp_code"]
    uid = r.json()["user_id"]

    # LISTELE -> ad + daire no; telefon YOK
    lst = client.get("/residents", headers=yon)
    assert lst.status_code == 200, lst.text
    mine = next(i for i in lst.json()["items"] if i["user_id"] == uid)
    assert mine["ad"] == "Yeni Sakin"
    assert mine["unit_no"] == "R-1"
    assert mine["is_active"] is True
    assert "telefon" not in mine

    # Ilk giris (gecici kod) calisir -> parola kurulumu
    lp = client.post("/auth/login-phone", json={"phone": phone, "password": temp})
    assert lp.status_code == 200 and lp.json()["password_setup_required"] is True

    # CIKAR -> 204, pasiflesir
    assert client.delete(f"/residents/{uid}", headers=yon).status_code == 204

    # Artik o telefonla giris YAPILAMAZ (is_active=false)
    assert client.post(
        "/auth/login-phone", json={"phone": phone, "password": temp}
    ).status_code == 401

    # Listede is_active=false
    mine2 = next(
        i for i in client.get("/residents", headers=yon).json()["items"]
        if i["user_id"] == uid
    )
    assert mine2["is_active"] is False

    # Idempotent: tekrar cikar -> yine 204
    assert client.delete(f"/residents/{uid}", headers=yon).status_code == 204


def test_remove_nonexistent_resident_404(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    assert client.delete(f"/residents/{uuid.uuid4()}", headers=yon).status_code == 404


def test_residents_rbac(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    assert client.get("/residents", headers=admin).status_code == 200

    # saha rolleri + sakin: GET + DELETE 403 (rol kapisi handler'dan once)
    for role in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.get("/residents", headers=h).status_code == 403, role
        assert client.delete(
            f"/residents/{uuid.uuid4()}", headers=h
        ).status_code == 403, role
