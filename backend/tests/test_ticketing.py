"""Talep/Ariza -> Is Emri uctan uca: durum makinesi, convert, tamamlama oto-
cozum, decline, gecersiz gecis, RBAC, capraz-tenant izolasyon, timeline/sebep.

Canli sunucuya httpx ile vurur (conftest `client` + `world`). ASCII wire:
durum acik|is_emri|cozuldu|reddedildi; oncelik dusuk|orta|yuksek. Roller
conftest'te: guard_a=security, gorevli_a=tesis_gorevlisi.
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


def _me_id(client, headers):
    r = client.get("/me", headers=headers)
    assert r.status_code == 200, r.text
    return r.json()["id"]


def _mk_category(client, mgr_h, ad="Elektrik"):
    r = client.post("/task-categories", json={"ad": f"{ad}-{uuid.uuid4().hex[:6]}"}, headers=mgr_h)
    assert r.status_code == 201, r.text
    return r.json()["id"]


def _open_ticket(client, opener_h, kategori_id=None, foto_keys=None):
    body = {"baslik": "Asansor arizasi", "mesaj": "Asansor calismiyor"}
    if kategori_id:
        body["kategori_id"] = kategori_id
    if foto_keys:
        body["foto_keys"] = foto_keys
    r = client.post("/complaints", json=body, headers=opener_h)
    assert r.status_code == 201, r.text
    return r.json()


# ------------------------------- acma --------------------------------------- #
def test_open_ticket_writes_acik_history(client, world):
    """Sakin acar -> durum acik; timeline tek 'acik' satiri, actor_role=resident."""
    res_h = _headers(client, world["slug_a"], world["resident_a"])
    t = _open_ticket(client, res_h)
    assert t["durum"] == "acik"
    assert [h["durum"] for h in t["gecmis"]] == ["acik"]
    assert t["gecmis"][0]["actor_role"] == "resident"
    assert t["is_emri_id"] is None


def test_saha_opener_history_actor_role(client, world):
    """Saha rolu (tesis_gorevlisi) de acar; history actor_role o rolu tasir."""
    gor_h = _headers(client, world["slug_a"], world["gorevli_a"])
    t = _open_ticket(client, gor_h)
    assert t["durum"] == "acik"
    assert t["gecmis"][0]["actor_role"] == "tesis_gorevlisi"


# ------------------------------ convert ------------------------------------- #
def test_convert_creates_task_and_sets_is_emri(client, world):
    """Yonetici donusturur -> is emri (Task) olusur, durum is_emri, timeline
    acik->is_emri, is_emri_durum 'acik' (henuz tamamlanmadi)."""
    res_h = _headers(client, world["slug_a"], world["resident_a"])
    yon_h = _headers(client, world["slug_a"], world["yonetici_a"])
    kat = _mk_category(client, yon_h)
    t = _open_ticket(client, res_h, kategori_id=kat)
    sec_id = _me_id(client, _headers(client, world["slug_a"], world["guard_a"]))

    r = client.post(
        f"/complaints/{t['id']}/convert",
        json={"atanan_user_id": sec_id, "oncelik": "yuksek", "not": "acil"},
        headers=yon_h,
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["durum"] == "is_emri"
    assert body["is_emri_id"] is not None
    assert body["is_emri_durum"] == "acik"
    assert [h["durum"] for h in body["gecmis"]] == ["acik", "is_emri"]
    # convert notu is_emri satirinin sebep'ine yazilir
    is_emri_row = body["gecmis"][-1]
    assert is_emri_row["durum"] == "is_emri"
    assert is_emri_row["sebep"] == "acil"
    assert is_emri_row["actor_role"] == "yonetici"


def test_task_carries_ticket_context(client, world, owner_conn):
    """Talepten gelen is emri gorevinde atanan saha kullanicisi ticket_id +
    oncelik + kompakt talep ozeti (kategori/baslik/durum + acanin dairesi) gorur.
    Ticketsiz normal gorevde bu alanlar None."""
    res_h = _headers(client, world["slug_a"], world["resident_a"])
    yon_h = _headers(client, world["slug_a"], world["yonetici_a"])
    guard_h = _headers(client, world["slug_a"], world["guard_a"])
    kat = _mk_category(client, yon_h, ad="Tesisat")
    t = _open_ticket(client, res_h, kategori_id=kat)
    sec_id = _me_id(client, guard_h)
    res_id = _me_id(client, res_h)

    # Acanin (resident) dairesini bagla -> ticket ozetinde unit_label dolsun.
    unit_id = owner_conn.execute(
        "INSERT INTO unit (tenant_id, no, blok) VALUES (%s,%s,'A') RETURNING id",
        (str(world["a"]), f"TK-{uuid.uuid4().hex[:5]}"),
    ).fetchone()[0]
    owner_conn.execute(
        "INSERT INTO unit_resident (tenant_id, unit_id, user_id) VALUES (%s,%s,%s)",
        (str(world["a"]), unit_id, res_id),
    )
    unit_no = owner_conn.execute(
        "SELECT no FROM unit WHERE id=%s", (unit_id,)
    ).fetchone()[0]

    conv = client.post(
        f"/complaints/{t['id']}/convert",
        json={"atanan_user_id": sec_id, "oncelik": "yuksek", "not": "acil"},
        headers=yon_h,
    ).json()
    task_id = conv["is_emri_id"]

    # Atanan saha kullanicisi (guard) 'Gorevlerim' listesinde ticket baglamini gorur.
    items = client.get(
        "/tasks", headers=guard_h, params={"atanan_user_id": "me"}
    ).json()["items"]
    task = next(x for x in items if x["id"] == task_id)
    assert task["ticket_id"] == t["id"]
    assert task["oncelik"] == "yuksek"
    tk = task["ticket"]
    assert set(tk.keys()) == {"id", "kategori_ad", "baslik", "durum", "unit_label"}
    assert tk["id"] == t["id"] and tk["baslik"] == "Asansor arizasi"
    assert tk["durum"] == "is_emri" and tk["kategori_ad"] is not None
    assert tk["unit_label"] == unit_no

    # Detay (GET /tasks/{id}) ayni baglami tasir.
    d = client.get(f"/tasks/{task_id}", headers=guard_h).json()
    assert d["ticket_id"] == t["id"] and d["ticket"]["baslik"] == "Asansor arizasi"

    # Ticketsiz normal gorevde ticket alanlari None.
    plain = client.post(
        "/tasks", headers=yon_h,
        json={"ad": "Normal gorev", "atanan_user_id": sec_id},
    ).json()
    assert plain["ticket_id"] is None
    assert plain["oncelik"] is None and plain["ticket"] is None


def test_convert_invalid_assignee_422(client, world):
    """Atanan ayni tenant security/tesis_gorevlisi degilse 422 invalid_assignee.
    Resident'e (acan rol) atama denemesi reddedilir."""
    res_h = _headers(client, world["slug_a"], world["resident_a"])
    yon_h = _headers(client, world["slug_a"], world["yonetici_a"])
    t = _open_ticket(client, res_h)
    resident_id = _me_id(client, res_h)
    r = client.post(
        f"/complaints/{t['id']}/convert",
        json={"atanan_user_id": resident_id, "oncelik": "orta"},
        headers=yon_h,
    )
    assert r.status_code == 422, r.text
    assert r.json()["error"]["code"] == "invalid_assignee"


def test_resident_cannot_convert(client, world):
    """Acan rol (resident) convert edemez -> 403 (yalniz admin/yonetici)."""
    res_h = _headers(client, world["slug_a"], world["resident_a"])
    t = _open_ticket(client, res_h)
    r = client.post(
        f"/complaints/{t['id']}/convert",
        json={"atanan_user_id": str(uuid.uuid4()), "oncelik": "orta"},
        headers=res_h,
    )
    assert r.status_code == 403, r.text


# ------------------- tamamlama oto-cozum (is_emri -> cozuldu) --------------- #
def test_completion_auto_resolves_ticket(client, world):
    """Bagli is emri atanan saha kullanicisi tarafindan tamamlaninca talep
    oto-cozulur: durum cozuldu, timeline acik->is_emri->cozuldu."""
    res_h = _headers(client, world["slug_a"], world["resident_a"])
    yon_h = _headers(client, world["slug_a"], world["yonetici_a"])
    sec_h = _headers(client, world["slug_a"], world["guard_a"])
    sec_id = _me_id(client, sec_h)

    t = _open_ticket(client, res_h)
    conv = client.post(
        f"/complaints/{t['id']}/convert",
        json={"atanan_user_id": sec_id, "oncelik": "orta"},
        headers=yon_h,
    ).json()
    task_id = conv["is_emri_id"]

    # Atanan kullanici KENDI gorevini tamamlar (tamamlanma_zamani zorunlu).
    r = client.post(
        f"/tasks/{task_id}/completions",
        json={"tamamlanma_zamani": "2027-06-01T09:00:00Z"},
        headers={**sec_h, "Idempotency-Key": str(uuid.uuid4())},
    )
    assert r.status_code == 201, r.text

    detail = client.get(f"/complaints/{t['id']}", headers=yon_h).json()
    assert detail["durum"] == "cozuldu"
    assert [h["durum"] for h in detail["gecmis"]] == ["acik", "is_emri", "cozuldu"]
    assert detail["is_emri_durum"] == "tamamlandi"
    # oto-cozum satirinin actor_role'u tamamlayan sahanin rolu
    assert detail["gecmis"][-1]["actor_role"] == "security"


# ------------------------------- resolve ------------------------------------ #
def test_resolve_note_in_timeline(client, world):
    """Dogrudan coz -> durum cozuldu; cozum_notu son timeline satirinin sebep'i."""
    res_h = _headers(client, world["slug_a"], world["resident_a"])
    yon_h = _headers(client, world["slug_a"], world["yonetici_a"])
    t = _open_ticket(client, res_h)
    r = client.post(
        f"/complaints/{t['id']}/resolve",
        json={"cozum_notu": "yerinde halledildi"},
        headers=yon_h,
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["durum"] == "cozuldu"
    assert body["gecmis"][-1]["durum"] == "cozuldu"
    assert body["gecmis"][-1]["sebep"] == "yerinde halledildi"


# ------------------------------- decline ------------------------------------ #
def test_decline_requires_reason(client, world):
    """Reddet: sebep ZORUNLU (yoksa 422); sebep ile durum reddedildi + sebep
    timeline'a yazilir."""
    res_h = _headers(client, world["slug_a"], world["resident_a"])
    yon_h = _headers(client, world["slug_a"], world["yonetici_a"])
    t = _open_ticket(client, res_h)

    assert client.post(f"/complaints/{t['id']}/decline", json={}, headers=yon_h).status_code == 422
    r = client.post(f"/complaints/{t['id']}/decline", json={"sebep": "gecersiz"}, headers=yon_h)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["durum"] == "reddedildi"
    assert body["gecmis"][-1]["durum"] == "reddedildi"
    assert body["gecmis"][-1]["sebep"] == "gecersiz"


# ------------------------- gecersiz gecis (terminal) ------------------------ #
def test_invalid_transition_after_terminal(client, world):
    """cozuldu terminal: sonrasinda decline 422 invalid_transition."""
    res_h = _headers(client, world["slug_a"], world["resident_a"])
    yon_h = _headers(client, world["slug_a"], world["yonetici_a"])
    t = _open_ticket(client, res_h)
    assert client.post(f"/complaints/{t['id']}/resolve", json={}, headers=yon_h).status_code == 200
    r = client.post(f"/complaints/{t['id']}/decline", json={"sebep": "x"}, headers=yon_h)
    assert r.status_code == 422, r.text
    assert r.json()["error"]["code"] == "invalid_transition"


def test_invalid_transition_convert_after_resolved(client, world):
    """cozuldu terminal: convert de 422 invalid_transition (acik->is_emri disi)."""
    res_h = _headers(client, world["slug_a"], world["resident_a"])
    yon_h = _headers(client, world["slug_a"], world["yonetici_a"])
    sec_id = _me_id(client, _headers(client, world["slug_a"], world["guard_a"]))
    t = _open_ticket(client, res_h)
    assert client.post(f"/complaints/{t['id']}/resolve", json={}, headers=yon_h).status_code == 200
    r = client.post(
        f"/complaints/{t['id']}/convert",
        json={"atanan_user_id": sec_id, "oncelik": "orta"},
        headers=yon_h,
    )
    assert r.status_code == 422, r.text
    assert r.json()["error"]["code"] == "invalid_transition"


# --------------------------- capraz-tenant izolasyon ------------------------ #
def test_cross_tenant_get_404(client, world):
    """B tenant yonetimi A'nin talebini goremez (RLS -> 404)."""
    res_h = _headers(client, world["slug_a"], world["resident_a"])
    t = _open_ticket(client, res_h)
    b_yon = _headers(client, world["slug_b"], world["yonetici_b"])
    assert client.get(f"/complaints/{t['id']}", headers=b_yon).status_code == 404


def test_cross_tenant_convert_404(client, world):
    """B tenant yonetimi A'nin talebini donusturemez (RLS -> 404)."""
    res_h = _headers(client, world["slug_a"], world["resident_a"])
    t = _open_ticket(client, res_h)
    b_yon = _headers(client, world["slug_b"], world["yonetici_b"])
    r = client.post(
        f"/complaints/{t['id']}/convert",
        json={"atanan_user_id": str(uuid.uuid4()), "oncelik": "orta"},
        headers=b_yon,
    )
    assert r.status_code == 404, r.text
