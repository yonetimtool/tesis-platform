"""Task CRUD + completion (idempotency/RBAC/izolasyon/NFC) + foto presign akisi."""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _new_task(client, headers, **over):
    body = {"tip": "temizlik", "ad": "Cop topla"}
    body.update(over)
    r = client.post("/tasks", headers=headers, json=body)
    assert r.status_code == 201, r.text
    return r.json()


def _checkpoint(client, headers):
    nfc = f"NFC-{uuid.uuid4().hex[:10]}"
    return client.post("/checkpoints", headers=headers, json={"ad": "CP", "nfc_tag_uid": nfc}).json()


# -------------------------------- CRUD ------------------------------------- #
def test_task_crud_happy_path(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    t = _new_task(client, admin, tip="kontrol", ad="Kamelya kontrol", periyot_dakika=120)
    tid = t["id"]
    assert t["tip"] == "kontrol" and t["periyot_dakika"] == 120

    assert client.get(f"/tasks/{tid}", headers=admin).status_code == 200

    lr = client.get("/tasks", headers=admin, params={"tip": "kontrol", "limit": 10})
    assert lr.status_code == 200
    body = lr.json()
    assert body["meta"]["limit"] == 10
    assert any(it["id"] == tid for it in body["items"])
    assert all(it["tip"] == "kontrol" for it in body["items"])

    pr = client.patch(f"/tasks/{tid}", headers=admin, json={"ad": "Kamelya-2", "aktif": False})
    assert pr.status_code == 200 and pr.json()["ad"] == "Kamelya-2" and pr.json()["aktif"] is False

    assert client.delete(f"/tasks/{tid}", headers=admin).status_code == 204
    assert client.get(f"/tasks/{tid}", headers=admin).status_code == 404


def test_task_rbac_and_validation(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])

    # okuma izinli, yazma yasak
    assert client.get("/tasks", headers=gorevli).status_code == 200
    assert client.post("/tasks", headers=gorevli, json={"tip": "temizlik", "ad": "x"}).status_code == 403

    # gecersiz govde (tip yok) -> 422
    assert client.post("/tasks", headers=admin, json={"ad": "x"}).status_code == 422
    # capraz-tenant atanan_user -> 422
    r = client.post(
        "/tasks", headers=admin, json={"tip": "temizlik", "ad": "x", "atanan_user_id": str(uuid.uuid4())}
    )
    assert r.status_code == 422 and r.json()["error"]["code"] == "invalid_reference"


def test_task_tenant_isolation(client, world):
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    t = _new_task(client, admin_a)
    assert client.get(f"/tasks/{t['id']}", headers=admin_b).status_code == 404
    assert client.patch(f"/tasks/{t['id']}", headers=admin_b, json={"ad": "x"}).status_code == 404


# ----------------------------- completions --------------------------------- #
def test_completion_idempotency_and_400(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])
    t = _new_task(client, admin)
    key = uuid.uuid4().hex
    hdr = {**gorevli, "Idempotency-Key": key}
    payload = {"tamamlanma_zamani": "2026-06-28T08:00:00Z", "notlar": "tamam"}

    first = client.post(f"/tasks/{t['id']}/completions", headers=hdr, json=payload)
    assert first.status_code == 201, first.text
    cid = first.json()["id"]
    assert first.json()["tamamlayan_user_id"] == client.get("/me", headers=gorevli).json()["id"]

    # ayni key + ayni govde -> 200 ayni kayit
    again = client.post(f"/tasks/{t['id']}/completions", headers=hdr, json=payload)
    assert again.status_code == 200 and again.json()["id"] == cid

    # ayni key + farkli govde -> 409
    diff = client.post(
        f"/tasks/{t['id']}/completions",
        headers=hdr,
        json={"tamamlanma_zamani": "2026-06-28T09:00:00Z"},
    )
    assert diff.status_code == 409

    # key yok -> 400
    nokey = client.post(f"/tasks/{t['id']}/completions", headers=gorevli, json=payload)
    assert nokey.status_code == 400 and nokey.json()["error"]["code"] == "bad_request"


def test_completion_tenant_isolation(client, world):
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    gorevli_b = _headers(client, world["slug_b"], world["admin_b"])  # B tarafi
    t = _new_task(client, admin_a)
    # B, A'nin task'ina completion yapamaz -> task gorunmez -> 404
    r = client.post(
        f"/tasks/{t['id']}/completions",
        headers={**gorevli_b, "Idempotency-Key": uuid.uuid4().hex},
        json={"tamamlanma_zamani": "2026-06-28T08:00:00Z"},
    )
    assert r.status_code == 404


def test_completion_nfc_mismatch(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])
    cp = _checkpoint(client, admin)
    t = _new_task(client, admin, checkpoint_id=cp["id"])

    # yanlis nfc -> 422
    bad = client.post(
        f"/tasks/{t['id']}/completions",
        headers={**gorevli, "Idempotency-Key": uuid.uuid4().hex},
        json={"tamamlanma_zamani": "2026-06-28T08:00:00Z", "nfc_tag_uid": "YANLIS"},
    )
    assert bad.status_code == 422

    # dogru nfc -> 201
    ok = client.post(
        f"/tasks/{t['id']}/completions",
        headers={**gorevli, "Idempotency-Key": uuid.uuid4().hex},
        json={"tamamlanma_zamani": "2026-06-28T08:00:00Z", "nfc_tag_uid": cp["nfc_tag_uid"]},
    )
    assert ok.status_code == 201


def test_completion_list(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])
    t = _new_task(client, admin)
    client.post(
        f"/tasks/{t['id']}/completions",
        headers={**gorevli, "Idempotency-Key": uuid.uuid4().hex},
        json={"tamamlanma_zamani": "2026-06-28T08:00:00Z"},
    )
    r = client.get(f"/tasks/{t['id']}/completions", headers=admin)
    assert r.status_code == 200
    assert r.json()["meta"]["total"] >= 1


# ------------------------------ foto akisi --------------------------------- #
def test_presign_and_completion_with_foto(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])

    # presign (gorevli yetkili)
    pr = client.post(
        "/uploads/presign", headers=gorevli, json={"content_type": "image/jpeg"}
    )
    assert pr.status_code == 200, pr.text
    body = pr.json()
    assert body["method"] == "PUT"
    assert body["foto_key"].startswith(f"{world['a']}/tasks/")
    assert body["foto_key"].endswith(".jpg")
    assert "X-Amz-Signature" in body["upload_url"]  # gecerli presigned URL

    # foto_key completion'da saklanir
    t = _new_task(client, admin)
    comp = client.post(
        f"/tasks/{t['id']}/completions",
        headers={**gorevli, "Idempotency-Key": uuid.uuid4().hex},
        json={"tamamlanma_zamani": "2026-06-28T08:00:00Z", "foto_key": body["foto_key"]},
    )
    assert comp.status_code == 201
    assert comp.json()["foto_key"] == body["foto_key"]


def test_presign_rbac_resident_allowed_for_complaint_foto(client, world):
    """resident presign'a SIKAYET/ONERI gorseli icin erisir (auth.md §4);
    saha kanit uclari (scans/completion) resident'a kapali kalir."""
    resident = _headers(client, world["slug_a"], world["resident_a"])
    r = client.post("/uploads/presign", headers=resident, json={"content_type": "image/jpeg"})
    assert r.status_code == 200


# ------------------- mobil §11 bulgulari (atama/foto/NFC) ------------------- #
def test_list_tasks_atanan_filter_me_and_uuid(client, world):
    """?atanan_user_id=me yalniz benimkiler; admin duz UUID ile baskasini suzer."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    gorevli_id = client.get("/me", headers=gorevli).json()["id"]
    guard_id = client.get("/me", headers=guard).json()["id"]

    mine = _new_task(client, admin, ad="Benimki", atanan_user_id=gorevli_id)
    other = _new_task(client, admin, ad="Baskasininki", atanan_user_id=guard_id)
    _new_task(client, admin, ad="Atanmamis")

    body = client.get("/tasks", headers=gorevli, params={"atanan_user_id": "me", "limit": 200}).json()
    ids = [it["id"] for it in body["items"]]
    assert mine["id"] in ids and other["id"] not in ids
    assert all(it["atanan_user_id"] == gorevli_id for it in body["items"])

    # panel: admin duz UUID ile suzer
    body = client.get("/tasks", headers=admin, params={"atanan_user_id": guard_id, "limit": 200}).json()
    ids = [it["id"] for it in body["items"]]
    assert other["id"] in ids and mine["id"] not in ids

    # gecersiz deger -> 422
    assert client.get("/tasks", headers=admin, params={"atanan_user_id": "bozuk"}).status_code == 422


def test_completion_foto_zorunlu(client, world):
    """foto_zorunlu=true iken foto'suz completion 422; foto'lu 201; false iken serbest."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])

    t = _new_task(client, admin, ad="Foto sart", foto_zorunlu=True)
    assert t["foto_zorunlu"] is True

    fotosuz = client.post(
        f"/tasks/{t['id']}/completions",
        headers={**gorevli, "Idempotency-Key": uuid.uuid4().hex},
        json={"tamamlanma_zamani": "2026-07-03T08:00:00Z"},
    )
    assert fotosuz.status_code == 422, fotosuz.text
    assert "foto" in fotosuz.json()["error"]["message"].lower()

    fotolu = client.post(
        f"/tasks/{t['id']}/completions",
        headers={**gorevli, "Idempotency-Key": uuid.uuid4().hex},
        json={"tamamlanma_zamani": "2026-07-03T08:00:00Z", "foto_key": "k/x.jpg"},
    )
    assert fotolu.status_code == 201, fotolu.text

    # varsayilan false: foto'suz serbest (mevcut davranis)
    serbest = _new_task(client, admin, ad="Foto serbest")
    assert serbest["foto_zorunlu"] is False
    ok = client.post(
        f"/tasks/{serbest['id']}/completions",
        headers={**gorevli, "Idempotency-Key": uuid.uuid4().hex},
        json={"tamamlanma_zamani": "2026-07-03T08:05:00Z"},
    )
    assert ok.status_code == 201

    # PATCH ile acilip kapanabilir
    p = client.patch(f"/tasks/{serbest['id']}", headers=admin, json={"foto_zorunlu": True})
    assert p.status_code == 200 and p.json()["foto_zorunlu"] is True


def test_completion_nfc_normalized_case_insensitive(client, world):
    """Kucuk harf / bosluklu UID'li completion normalize edilip eslesir (mobil §11 #3)."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])
    nfc = f"NFC-{uuid.uuid4().hex[:10].upper()}"
    cp = client.post("/checkpoints", headers=admin, json={"ad": "CP", "nfc_tag_uid": nfc}).json()
    t = _new_task(client, admin, checkpoint_id=cp["id"])

    r = client.post(
        f"/tasks/{t['id']}/completions",
        headers={**gorevli, "Idempotency-Key": uuid.uuid4().hex},
        json={"tamamlanma_zamani": "2026-07-03T09:00:00Z", "nfc_tag_uid": f"  {nfc.lower()} "},
    )
    assert r.status_code == 201, r.text

    # yanlis etiket normalize SONRASI da uyusmaz -> 422
    bad = client.post(
        f"/tasks/{t['id']}/completions",
        headers={**gorevli, "Idempotency-Key": uuid.uuid4().hex},
        json={"tamamlanma_zamani": "2026-07-03T09:05:00Z", "nfc_tag_uid": "yanlis"},
    )
    assert bad.status_code == 422
