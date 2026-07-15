"""Site sakini yonetimi — POST/GET/PATCH/DELETE /residents + reset-password.

Sakin KENDI kayit olamaz; yonetici ekler/listeler/duzenler/siler/parola-sifirlar.
DELETE AKILLI: gecmissiz sakin tamamen silinir; gecmisi olan pasiflestirilir;
telefon HER DURUMDA serbest kalir (yeniden kayit mumkun). Canli API'ye vurur.
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


def _add(client, yon, telefon, ad="Sakin", unit="R-1"):
    r = client.post(
        "/residents", headers=yon, json={"ad": ad, "telefon": telefon, "unit_no": unit}
    )
    assert r.status_code == 201, r.text
    return r.json()


# ------------------------------ ekle / listele ---------------------------- #
def test_add_and_list_resident(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    phone = _uphone()
    res = _add(client, yon, phone, ad="Yeni Sakin", unit="R-1")
    uid = res["user_id"]

    mine = next(
        i for i in client.get("/residents", headers=yon).json()["items"]
        if i["user_id"] == uid
    )
    assert mine["ad"] == "Yeni Sakin" and mine["unit_no"] == "R-1"
    assert mine["is_active"] is True
    assert "telefon" not in mine  # KVKK


def test_add_resident_with_password_skips_temp_code(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    phone = _uphone()
    r = client.post(
        "/residents",
        headers=yon,
        json={"ad": "Parolali", "telefon": phone, "unit_no": "P-9", "password": "Sakin1234!"},
    )
    assert r.status_code == 201, r.text
    assert r.json()["temp_code"] is None  # parola verildi -> gecici kod YOK
    # dogrudan parola ile telefon-login (kurulum gerekmez)
    lp = client.post("/auth/login-phone", json={"phone": phone, "password": "Sakin1234!"})
    assert lp.status_code == 200 and lp.json()["password_setup_required"] is False
    # zayif parola -> 422
    weak = client.post(
        "/residents",
        headers=yon,
        json={"ad": "x", "telefon": _uphone(), "unit_no": "P-7", "password": "zayifparola"},
    )
    assert weak.status_code == 422


# --------------------------------- duzenle -------------------------------- #
def test_edit_resident_and_phone_freed(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    phone_a = _uphone()
    phone_b = _uphone()
    uid = _add(client, yon, phone_a, ad="Ali")["user_id"]

    # ad + telefon guncelle
    r = client.patch(f"/residents/{uid}", headers=yon, json={"ad": "Ali Veli", "telefon": phone_b})
    assert r.status_code == 204, r.text
    mine = next(i for i in client.get("/residents", headers=yon).json()["items"] if i["user_id"] == uid)
    assert mine["ad"] == "Ali Veli"

    # eski numara serbest -> yeni sakin acilir; yeni numara dolu -> cakisma 409
    assert _add(client, yon, phone_a, unit="R-2")  # 201
    dup = client.post("/residents", headers=yon, json={"ad": "x", "telefon": phone_b, "unit_no": "R-3"})
    assert dup.status_code == 409

    # bos govde 422; olmayan sakin 404
    assert client.patch(f"/residents/{uid}", headers=yon, json={}).status_code == 422
    assert client.patch(f"/residents/{uuid.uuid4()}", headers=yon, json={"ad": "z"}).status_code == 404


# ----------------------------- parola sifirla ----------------------------- #
def test_reset_password(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    phone = _uphone()
    uid = _add(client, yon, phone)["user_id"]

    r = client.post(f"/residents/{uid}/reset-password", headers=yon)
    assert r.status_code == 200, r.text
    code = r.json()["temp_code"]

    # yeni kod ile telefon-login -> parola kurulumu gerekli
    lp = client.post("/auth/login-phone", json={"phone": phone, "password": code})
    assert lp.status_code == 200 and lp.json()["password_setup_required"] is True

    assert client.post(f"/residents/{uuid.uuid4()}/reset-password", headers=yon).status_code == 404


# ------------------------------- akilli sil ------------------------------- #
def test_smart_delete_no_history_removes_and_frees_phone(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    phone = _uphone()
    uid = _add(client, yon, phone)["user_id"]

    d = client.delete(f"/residents/{uid}", headers=yon)
    assert d.status_code == 200 and d.json()["deleted"] is True

    # tamamen silindi -> listede yok; ayni numarayla yeniden kayit 201
    assert all(i["user_id"] != uid for i in client.get("/residents", headers=yon).json()["items"])
    assert _add(client, yon, phone, unit="R-9")  # numara serbest


def test_smart_delete_with_history_deactivates_and_frees_phone(client, world, owner_conn):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    phone = _uphone()
    uid = _add(client, yon, phone, ad="Gecmisli")["user_id"]

    # RESTRICT bagimlilik: sakin bir sikayet acmis (owner ile dogrudan, RLS bypass)
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO complaint (tenant_id, acan_user_id, baslik, mesaj) VALUES (%s,%s,%s,%s)",
            (world["a"], uid, "gecmis", "kayit"),
        )

    d = client.delete(f"/residents/{uid}", headers=yon)
    assert d.status_code == 200 and d.json()["deleted"] is False  # pasiflestirildi

    # pasif + telefon serbest: listede is_active=false, ayni numarayla yeniden 201
    mine = next(i for i in client.get("/residents", headers=yon).json()["items"] if i["user_id"] == uid)
    assert mine["is_active"] is False
    assert _add(client, yon, phone, unit="R-8")  # numara serbest


# --------------------------------- RBAC ----------------------------------- #
def test_residents_rbac(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    assert client.get("/residents", headers=admin).status_code == 200

    rid = uuid.uuid4()
    for role in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.get("/residents", headers=h).status_code == 403, role
        assert client.delete(f"/residents/{rid}", headers=h).status_code == 403, role
        assert client.patch(f"/residents/{rid}", headers=h, json={"ad": "x"}).status_code == 403, role
        assert client.post(f"/residents/{rid}/reset-password", headers=h).status_code == 403, role
