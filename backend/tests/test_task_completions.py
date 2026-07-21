"""GET /task-completions — capraz-gorev tamamlama gecmisi: tarih/kategori/task_id/
tamamlayan filtresi, DESC, sayfalama, ozet (KATEGORI dagilimi; NULL -> "Diğer"),
tenant izolasyon, RBAC, bos aralik. Sabit tip kaldirildi; gorev tipi = yonetici-
tanimli kategori. Veri /tasks/{id}/completions POST ile uretilir."""
from __future__ import annotations

import uuid

T1 = "2027-05-01T08:00:00Z"
T2 = "2027-05-02T08:00:00Z"
T3 = "2027-05-03T08:00:00Z"


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _new_category(client, admin, ad):
    r = client.post("/task-categories", headers=admin, json={"ad": ad})
    assert r.status_code == 201, r.text
    return r.json()


def _new_task(client, headers, ad, kategori_id=None, atanan_user_id=None):
    body = {"ad": ad}
    if kategori_id is not None:
        body["kategori_id"] = kategori_id
    # Saha kullanicisi YALNIZ kendine atanan gorevi tamamlayabilir (aksi 404 —
    # _assignee_visibility). Tamamlayacak kullaniciya atayarak kurala uyuyoruz.
    if atanan_user_id is not None:
        body["atanan_user_id"] = atanan_user_id
    r = client.post("/tasks", headers=headers, json=body)
    assert r.status_code == 201, r.text
    return r.json()


def _complete(client, completer, task_id, when, **extra):
    hdr = {**completer, "Idempotency-Key": uuid.uuid4().hex}
    r = client.post(f"/tasks/{task_id}/completions", headers=hdr, json={"tamamlanma_zamani": when, **extra})
    assert r.status_code == 201, r.text
    return r.json()


def _world_a_data(client, world):
    """A tenant'inda 3 tamamlama: 'Temizlik' kategorili @T1 (gorevli, foto+nfc),
    'Kontrol' kategorili @T2 (gorevli), KATEGORISIZ (Diğer) @T3 (guard)."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    gorevli_id = client.get("/me", headers=gorevli).json()["id"]
    guard_id = client.get("/me", headers=guard).json()["id"]

    cat_tem = _new_category(client, admin, "Temizlik")
    cat_kon = _new_category(client, admin, "Kontrol")
    t_tem = _new_task(client, admin, "Cop", cat_tem["id"], atanan_user_id=gorevli_id)
    t_kon = _new_task(client, admin, "Kontrol", cat_kon["id"], atanan_user_id=gorevli_id)
    t_pey = _new_task(client, admin, "Sulama", atanan_user_id=guard_id)  # kategorisiz -> "Diğer"

    c1 = _complete(client, gorevli, t_tem["id"], T1, foto_key="a/x.jpg", nfc_tag_uid="04AABB")
    c2 = _complete(client, gorevli, t_kon["id"], T2)
    c3 = _complete(client, guard, t_pey["id"], T3)
    return {
        "admin": admin, "tesis_gorevlisi": gorevli, "guard": guard,
        "gorevli_id": gorevli_id, "guard_id": guard_id,
        "cat_tem": cat_tem, "cat_kon": cat_kon,
        "t_tem": t_tem, "t_kon": t_kon, "t_pey": t_pey,
        "c1": c1["id"], "c2": c2["id"], "c3": c3["id"],
    }


def _ozet_map(body):
    return {k["kategori_ad"]: k["sayi"] for k in body["ozet"]["kalemler"]}


# ----------------------- DESC + ozet + foto/nfc bool ------------------------ #
def test_list_order_ozet_and_flags(client, world):
    d = _world_a_data(client, world)
    r = client.get("/task-completions", headers=d["admin"])
    assert r.status_code == 200, r.text
    body = r.json()
    assert [it["id"] for it in body["items"]] == [d["c3"], d["c2"], d["c1"]]  # DESC by zaman
    assert body["meta"]["total"] == 3
    assert body["ozet"]["toplam"] == 3
    assert _ozet_map(body) == {"Temizlik": 1, "Kontrol": 1, "Diğer": 1}

    by_id = {it["id"]: it for it in body["items"]}
    assert by_id[d["c1"]]["foto_var"] is True and by_id[d["c1"]]["nfc_dogrulandi"] is True
    assert by_id[d["c2"]]["foto_var"] is False and by_id[d["c2"]]["nfc_dogrulandi"] is False
    assert by_id[d["c1"]]["task_adi"] == "Cop" and by_id[d["c1"]]["kategori_ad"] == "Temizlik"
    assert by_id[d["c3"]]["kategori_ad"] == "Diğer"  # kategorisiz


def test_filters_kategori_task_tamamlayan_and_range(client, world):
    d = _world_a_data(client, world)
    admin = d["admin"]

    # kategori filtresi
    r = client.get("/task-completions", headers=admin, params={"kategori_id": d["cat_tem"]["id"]})
    assert [it["id"] for it in r.json()["items"]] == [d["c1"]]
    assert _ozet_map(r.json()) == {"Temizlik": 1}

    # task_id filtresi
    r = client.get("/task-completions", headers=admin, params={"task_id": d["t_kon"]["id"]})
    assert [it["id"] for it in r.json()["items"]] == [d["c2"]]

    # tamamlayan filtresi (guard -> sadece kategorisiz)
    r = client.get("/task-completions", headers=admin, params={"tamamlayan_user_id": d["guard_id"]})
    assert [it["id"] for it in r.json()["items"]] == [d["c3"]]

    # tarih araligi yari-acik [T2, T3) -> sadece c2
    r = client.get("/task-completions", headers=admin, params={"baslangic": T2, "bitis": T3})
    assert [it["id"] for it in r.json()["items"]] == [d["c2"]]
    assert r.json()["meta"]["total"] == 1


def test_pagination_desc(client, world):
    d = _world_a_data(client, world)
    p0 = client.get("/task-completions", headers=d["admin"], params={"limit": 2, "offset": 0}).json()
    assert [it["id"] for it in p0["items"]] == [d["c3"], d["c2"]]
    assert p0["meta"]["total"] == 3
    p1 = client.get("/task-completions", headers=d["admin"], params={"limit": 2, "offset": 2}).json()
    assert [it["id"] for it in p1["items"]] == [d["c1"]]


def test_empty_range_is_empty(client, world):
    d = _world_a_data(client, world)
    r = client.get("/task-completions", headers=d["admin"], params={"baslangic": "2099-01-01T00:00:00Z"})
    assert r.status_code == 200
    assert r.json()["items"] == []
    assert r.json()["meta"]["total"] == 0
    assert r.json()["ozet"] == {"toplam": 0, "kalemler": []}


def test_tenant_isolation(client, world):
    d = _world_a_data(client, world)
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    b_ids = [it["id"] for it in client.get("/task-completions", headers=admin_b).json()["items"]]
    assert d["c1"] not in b_ids and d["c3"] not in b_ids


def test_rbac(client, world):
    """Kesin matris: gorev-yonetimi GORUNTULEME (takip gecmisi dahil) —
    yonetici/security/tesis_gorevlisi/admin 200; resident 403."""
    for role in ("admin_a", "yonetici_a", "guard_a", "gorevli_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.get("/task-completions", headers=h).status_code == 200, role
    resident = _headers(client, world["slug_a"], world["resident_a"])
    assert client.get("/task-completions", headers=resident).status_code == 403
