"""yonetici rolu RBAC — gorev atama/takip, rapor okuma, admin-only sinirlar,
tenant izolasyonu (auth.md §4: yonetici = site yoneticisi, mobil, kendi tenant'i)."""
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


# ------------------------- gorev olusturma / atama ------------------------- #
def test_yonetici_gorev_olusturur_ve_saha_rollerine_atar(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])

    # security'ye atama
    r = client.post(
        "/tasks", headers=yonetici,
        json={"ad": "Kapi kontrol", "atanan_user_id": _me_id(client, guard)},
    )
    assert r.status_code == 201, r.text
    tid = r.json()["id"]

    # tesis_gorevlisi'ne yeniden atama (PATCH)
    gorevli_id = _me_id(client, gorevli)
    r = client.patch(f"/tasks/{tid}", headers=yonetici, json={"atanan_user_id": gorevli_id})
    assert r.status_code == 200 and r.json()["atanan_user_id"] == gorevli_id

    # takip: liste + detay + tamamlanmalar okunur
    assert client.get("/tasks", headers=yonetici).status_code == 200
    assert client.get(f"/tasks/{tid}", headers=yonetici).status_code == 200
    assert client.get(f"/tasks/{tid}/completions", headers=yonetici).status_code == 200

    # silme de yonetici'de
    assert client.delete(f"/tasks/{tid}", headers=yonetici).status_code == 204


def test_yonetici_saha_disi_role_atayamaz(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])

    for hedef in (_me_id(client, resident), _me_id(client, admin), _me_id(client, yonetici)):
        r = client.post(
            "/tasks", headers=yonetici,
            json={"ad": "x", "atanan_user_id": hedef},
        )
        assert r.status_code == 422, r.text
        assert r.json()["error"]["code"] == "invalid_reference"

    # admin icin atama kisiti yok (resident'e bile atayabilir — mevcut davranis)
    r = client.post(
        "/tasks", headers=admin,
        json={"ad": "y", "atanan_user_id": _me_id(client, resident)},
    )
    assert r.status_code == 201, r.text
    client.delete(f"/tasks/{r.json()['id']}", headers=admin)


def test_gorevli_atanan_gorevi_tamamlar(client, world):
    """tesis_gorevlisi gorev alabilir: yonetici atar, gorevli tamamlar."""
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])
    gorevli_id = _me_id(client, gorevli)

    t = client.post(
        "/tasks", headers=yonetici,
        json={"ad": "Lobi", "atanan_user_id": gorevli_id},
    ).json()
    r = client.post(
        f"/tasks/{t['id']}/completions",
        headers={**gorevli, "Idempotency-Key": uuid.uuid4().hex},
        json={"tamamlanma_zamani": "2026-07-08T09:00:00Z"},
    )
    assert r.status_code == 201, r.text
    assert r.json()["tamamlayan_user_id"] == gorevli_id

    # yonetici tamamlanmayi takip eder ama KENDISI completion gonderemez
    assert client.get(f"/tasks/{t['id']}/completions", headers=yonetici).status_code == 200
    deny = client.post(
        f"/tasks/{t['id']}/completions",
        headers={**yonetici, "Idempotency-Key": uuid.uuid4().hex},
        json={"tamamlanma_zamani": "2026-07-08T10:00:00Z"},
    )
    assert deny.status_code == 403


# ------------------------------ takip / rapor ------------------------------ #
def test_yonetici_takip_ve_rapor_okur(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    for path in (
        "/patrol-windows",
        "/dashboard/live",
        "/checkpoints",
        "/notifications",
        "/task-completions",
        "/tenant/settings",
        "/assets",
        "/users",
    ):
        assert client.get(path, headers=yonetici).status_code == 200, path


def test_yonetici_aidat_raporu_okur_yazamaz(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])

    u = client.post("/units", headers=admin, json={"no": f"Y-{uuid.uuid4().hex[:6]}"}).json()
    client.post(
        "/dues/assessments", headers=admin,
        json={"unit_id": u["id"], "donem": "2026-07", "tutar_kurus": 50000},
    )

    assert client.get("/dues/assessments", headers=yonetici).status_code == 200
    assert client.get("/dues/payments", headers=yonetici).status_code == 200
    r = client.get(f"/units/{u['id']}/dues", headers=yonetici)
    assert r.status_code == 200 and r.json()["toplam_tahakkuk_kurus"] == 50000

    # yazma admin-only
    assert client.post(
        "/dues/assessments", headers=yonetici,
        json={"unit_id": u["id"], "donem": "2026-08", "tutar_kurus": 1000},
    ).status_code == 403
    assert client.post(
        "/dues/payments", headers=yonetici,
        json={"unit_id": u["id"], "tutar_kurus": 1000, "yontem": "elden"},
    ).status_code == 403


# ------------------------------- acil durum -------------------------------- #
def test_yonetici_acil_durum_tetikler_ve_yonetir(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])

    r = client.post(
        "/emergency",
        headers={**yonetici, "Idempotency-Key": uuid.uuid4().hex},
        json={"notlar": "asansor arizasi"},
    )
    assert r.status_code == 201, r.text
    alert_id = r.json()["id"]

    assert client.get("/emergency", headers=yonetici).status_code == 200
    solved = client.patch(
        f"/emergency/{alert_id}", headers=yonetici, json={"notlar": "cozuldu"}
    )
    assert solved.status_code == 200 and solved.json()["durum"] == "cozuldu"


# --------------------------- admin-only sinirlar --------------------------- #
def test_yonetici_yapilandirma_ve_saha_kaniti_403(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])

    # yapilandirma / CRUD admin-only
    # NOT: checkpoint CRUD artik admin+YONETICI (Parca D — yonetici uygulamada
    # kontrol noktasi tanimlar); bkz. test_scans.py::test_checkpoint_crud_by_yonetici.
    assert client.post("/shifts", headers=yonetici, json={"ad": "x", "baslangic_saat": "08:00", "bitis_saat": "16:00"}).status_code == 403
    # NOT: patrol-plan CRUD artik admin+YONETICI (yonetici uygulamada devriye
    # plani tanimlar); bkz. test_patrol_plans.py.
    assert client.post("/assets", headers=yonetici, json={"ad": "x"}).status_code == 403
    # NOT: daire (unit) CRUD artik admin+YONETICI (D-viz Rev-1 bina yerlesimi);
    # bkz. test_blocks.py + test_building_map.py. Burada admin-only olanlar kalir.
    assert client.patch("/tenant/settings", headers=yonetici, json={"acil_durum_telefon": "+900"}).status_code == 403
    # POST /users: yonetici artik KENDI tenant'inda saha personeli acabilir
    # (Ozellik 3), ama admin/yonetici/resident rolu ACAMAZ (yetki yukseltme yok).
    assert client.post(
        "/users", headers=yonetici,
        json={"ad": "x", "telefon": "+905557778899", "role": "admin", "password": "Parola123!"},
    ).status_code == 403
    assert client.get("/devices", headers=yonetici).status_code == 403

    # tanim okumalari yonetici'ye kapali olanlar (saha rollerine ozel)
    assert client.get("/shifts", headers=yonetici).status_code == 403
    # NOT: patrol-plans OKUMA artik yonetici'ye ACIK (devriye plani yonetimi).
    assert client.get("/patrol-plans", headers=yonetici).status_code == 200
    assert client.get("/me/patrol-window", headers=yonetici).status_code == 403

    # saha kaniti uretemez
    assert client.post(
        "/scans",
        headers={**yonetici, "Idempotency-Key": uuid.uuid4().hex},
        json={"nfc_tag_uid": "YOK", "okutma_zamani": "2026-07-08T09:00:00Z"},
    ).status_code == 403
    # presign: yonetici DUYURU GORSELI icin erisir (saha kanit akisi degil) — 200
    assert client.post("/uploads/presign", headers=yonetici, json={"content_type": "image/jpeg"}).status_code == 200

    # panel ucu (admin-only ornek uc) — panele giremez mantigi
    assert client.get("/admin/overview", headers=yonetici).status_code == 403


# ----------------------------- tenant izolasyonu --------------------------- #
def test_yonetici_kendi_tenantiyla_sinirli(client, world):
    yonetici_a = _headers(client, world["slug_a"], world["yonetici_a"])
    yonetici_b = _headers(client, world["slug_b"], world["yonetici_b"])
    guard_a_id = _me_id(client, _headers(client, world["slug_a"], world["guard_a"]))

    t = client.post(
        "/tasks", headers=yonetici_a,
        json={"ad": "A-gizli", "atanan_user_id": guard_a_id},
    ).json()

    # B yoneticisi A'nin gorevini goremez/degistiremez/silemez (RLS -> 404)
    assert client.get(f"/tasks/{t['id']}", headers=yonetici_b).status_code == 404
    assert client.patch(f"/tasks/{t['id']}", headers=yonetici_b, json={"ad": "ele gecti"}).status_code == 404
    assert client.delete(f"/tasks/{t['id']}", headers=yonetici_b).status_code == 404
    b_ids = [it["id"] for it in client.get("/tasks", headers=yonetici_b, params={"limit": 200}).json()["items"]]
    assert t["id"] not in b_ids

    # A tenant'indaki kullaniciya B'den atama yapilamaz (RLS -> 422 invalid_reference)
    r = client.post(
        "/tasks", headers=yonetici_b,
        json={"ad": "capraz", "atanan_user_id": guard_a_id},
    )
    assert r.status_code == 422 and r.json()["error"]["code"] == "invalid_reference"

    # B yoneticisi A'nin kullanicilarini listede goremez
    b_users = client.get("/users", headers=yonetici_b, params={"limit": 200}).json()["items"]
    assert all(u["email"] != "guard@example.com" for u in b_users)

    client.delete(f"/tasks/{t['id']}", headers=yonetici_a)
