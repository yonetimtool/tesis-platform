"""Sikayet/oneri: acma + kendi/yonetim gorunumu + yanit + RBAC + izolasyon.

RBAC (auth.md §4): ACMA resident; OKUMA resident KENDI + admin/yonetici TUMU;
PATCH (durum/yanit) admin+yonetici; security/tesis_gorevlisi TUM uclara 403.
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


def _new(client, headers, **over):
    body = {"baslik": f"Talep {uuid.uuid4().hex[:6]}", "mesaj": "Detayli mesaj."}
    body.update(over)
    r = client.post("/complaints", headers=headers, json=body)
    assert r.status_code == 201, r.text
    return r.json()


def _second_resident(client, world):
    """Ayni tenant'ta IKINCI bir sakin (admin uzerinden) — 'kendi kaydi'
    ayrimini test etmek icin."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    email = f"sakin2-{uuid.uuid4().hex[:8]}@acme.com"
    pw = "Sakin1234!"
    r = client.post(
        "/users",
        headers=admin,
        json={"ad": "Sakin Iki", "email": email, "role": "resident", "password": pw},
    )
    assert r.status_code == 201, r.text
    return _headers(client, world["slug_a"], {"email": email, "password": pw})


# ------------------------------- acma --------------------------------------- #
def test_resident_acar_durum_acik(client, world):
    resident = _headers(client, world["slug_a"], world["resident_a"])
    c = _new(client, resident, baslik="Asansor arizali", mesaj="A blok asansoru durdu.")
    assert c["durum"] == "acik"
    assert c["acan_ad"] == "Resident A"
    assert c["foto_key"] is None and c["foto_url"] is None
    assert c["yonetici_yaniti"] is None and c["yanit_zamani"] is None


def test_fotolu_acma_ve_okumada_foto_url(client, world):
    """presign (resident erisir) -> foto_key ile ac -> okumada foto_url doner."""
    resident = _headers(client, world["slug_a"], world["resident_a"])
    pre = client.post(
        "/uploads/presign", headers=resident, json={"content_type": "image/jpeg"}
    )
    assert pre.status_code == 200, pre.text
    foto_key = pre.json()["foto_key"]

    c = _new(client, resident, baslik="Gorselli talep", foto_key=foto_key)
    assert c["foto_key"] == foto_key
    assert c["foto_url"] and "X-Amz-Signature" in c["foto_url"]

    # yonetim de detayda gorseli gorur
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    d = client.get(f"/complaints/{c['id']}", headers=yonetici)
    assert d.status_code == 200 and "X-Amz-Signature" in d.json()["foto_url"]


def test_foto_key_tenant_namespace_disina_cikamaz(client, world):
    """Duyurudaki IDOR korumasinin aynisi: yabanci/serbest anahtar 422."""
    resident = _headers(client, world["slug_a"], world["resident_a"])
    r = client.post(
        "/complaints",
        headers=resident,
        json={
            "baslik": "x",
            "mesaj": "y",
            "foto_key": f"{world['b']}/tasks/victim.jpg",
        },
    )
    assert r.status_code == 422, r.text
    assert client.post(
        "/complaints",
        headers=resident,
        json={"baslik": "x", "mesaj": "y", "foto_key": "serbest/anahtar.jpg"},
    ).status_code == 422


def test_validation(client, world):
    resident = _headers(client, world["slug_a"], world["resident_a"])
    assert client.post(
        "/complaints", headers=resident, json={"baslik": "", "mesaj": "x"}
    ).status_code == 422
    assert client.post(
        "/complaints", headers=resident, json={"baslik": "x", "mesaj": ""}
    ).status_code == 422


# --------------------------- kendi / yonetim gorunumu ----------------------- #
def test_resident_yalniz_kendini_gorur_yonetim_tumunu(client, world):
    resident1 = _headers(client, world["slug_a"], world["resident_a"])
    resident2 = _second_resident(client, world)

    c1 = _new(client, resident1, baslik="Sakin1 talebi")
    c2 = _new(client, resident2, baslik="Sakin2 talebi")

    # resident1 listede KENDI talebini gorur, sakin2'ninkini GORMEZ
    ids1 = [it["id"] for it in client.get(
        "/complaints", headers=resident1, params={"limit": 200}
    ).json()["items"]]
    assert c1["id"] in ids1 and c2["id"] not in ids1

    # detayda da baskasinin talebi 404 (varlik sizdirilmaz)
    assert client.get(f"/complaints/{c2['id']}", headers=resident1).status_code == 404
    assert client.get(f"/complaints/{c1['id']}", headers=resident1).status_code == 200

    # yonetici + admin HER IKISINI de gorur
    for role in ("yonetici_a", "admin_a"):
        h = _headers(client, world["slug_a"], world[role])
        ids = [it["id"] for it in client.get(
            "/complaints", headers=h, params={"limit": 200}
        ).json()["items"]]
        assert c1["id"] in ids and c2["id"] in ids, role
        assert client.get(f"/complaints/{c1['id']}", headers=h).status_code == 200


def test_liste_durum_filtresi_ve_sira(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])
    a = _new(client, resident, baslik="Filtre-acik")
    b = _new(client, resident, baslik="Filtre-cozulecek")
    client.patch(f"/complaints/{b['id']}", headers=yonetici, json={"durum": "cozuldu"})

    acik = client.get(
        "/complaints", headers=yonetici, params={"durum": "acik", "limit": 200}
    ).json()["items"]
    assert all(it["durum"] == "acik" for it in acik)
    assert any(it["id"] == a["id"] for it in acik)
    assert not any(it["id"] == b["id"] for it in acik)

    # created_at DESC: b, a'dan sonra acildi -> tum listede once gelir
    hepsi = client.get("/complaints", headers=yonetici, params={"limit": 200}).json()
    ids = [it["id"] for it in hepsi["items"]]
    assert ids.index(b["id"]) < ids.index(a["id"])
    assert hepsi["meta"]["total"] >= 2


# ------------------------------ yanit (PATCH) ------------------------------- #
def test_yonetici_durum_ve_yanit_yazar(client, world):
    resident = _headers(client, world["slug_a"], world["resident_a"])
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    c = _new(client, resident, baslik="Yanit bekleyen")

    p = client.patch(
        f"/complaints/{c['id']}",
        headers=yonetici,
        json={"durum": "inceleniyor", "yonetici_yaniti": "Ekip yonlendirildi."},
    )
    assert p.status_code == 200, p.text
    body = p.json()
    assert body["durum"] == "inceleniyor"
    assert body["yonetici_yaniti"] == "Ekip yonlendirildi."
    assert body["yanitlayan_user_id"] and body["yanit_zamani"]

    # resident kendi talebinde YANITI gorur
    d = client.get(f"/complaints/{c['id']}", headers=resident).json()
    assert d["yonetici_yaniti"] == "Ekip yonlendirildi."

    # yalniz durum da degisebilir (yanit alanlari korunur)
    p2 = client.patch(
        f"/complaints/{c['id']}", headers=yonetici, json={"durum": "cozuldu"}
    )
    assert p2.status_code == 200 and p2.json()["durum"] == "cozuldu"
    assert p2.json()["yonetici_yaniti"] == "Ekip yonlendirildi."

    # bos govde 422; gecersiz durum 422
    assert client.patch(
        f"/complaints/{c['id']}", headers=yonetici, json={}
    ).status_code == 422
    assert client.patch(
        f"/complaints/{c['id']}", headers=yonetici, json={"durum": "kapandi"}
    ).status_code == 422


# -------------------------------- RBAC -------------------------------------- #
def test_rbac_resident_patch_403_saha_rolleri_tum_uclara_403(client, world):
    resident = _headers(client, world["slug_a"], world["resident_a"])
    c = _new(client, resident, baslik="RBAC talebi")

    # resident PATCH'e ERISEMEZ (kendi talebi olsa bile)
    assert client.patch(
        f"/complaints/{c['id']}", headers=resident, json={"durum": "cozuldu"}
    ).status_code == 403

    # security + tesis_gorevlisi: sakin<->yonetim kanali — TUM uclar 403
    for role in ("guard_a", "gorevli_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.get("/complaints", headers=h).status_code == 403, role
        assert client.get(f"/complaints/{c['id']}", headers=h).status_code == 403, role
        assert client.post(
            "/complaints", headers=h, json={"baslik": "x", "mesaj": "y"}
        ).status_code == 403, role
        assert client.patch(
            f"/complaints/{c['id']}", headers=h, json={"durum": "cozuldu"}
        ).status_code == 403, role

    # yonetim talep ACAMAZ (kanal sakinin agzi; yonetim yanitlar)
    for role in ("yonetici_a", "admin_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.post(
            "/complaints", headers=h, json={"baslik": "x", "mesaj": "y"}
        ).status_code == 403, role


def test_duyuru_olusturma_resident_403_teyit(client, world):
    """C) duyuru RBAC fix teyidi: resident duyuru OLUSTURAMAZ, yalniz okur."""
    resident = _headers(client, world["slug_a"], world["resident_a"])
    assert client.post(
        "/announcements", headers=resident, json={"baslik": "x", "govde": "y"}
    ).status_code == 403
    assert client.get("/announcements", headers=resident).status_code == 200


# ----------------------------- tenant izolasyonu ---------------------------- #
def test_tenant_izolasyonu(client, world):
    resident_a = _headers(client, world["slug_a"], world["resident_a"])
    c = _new(client, resident_a, baslik="A-ozel talep")

    # B tenant yonetimi A'nin talebini goremez/degistiremez (RLS -> 404)
    yonetici_b = _headers(client, world["slug_b"], world["yonetici_b"])
    b_ids = [it["id"] for it in client.get(
        "/complaints", headers=yonetici_b, params={"limit": 200}
    ).json()["items"]]
    assert c["id"] not in b_ids
    assert client.get(f"/complaints/{c['id']}", headers=yonetici_b).status_code == 404
    assert client.patch(
        f"/complaints/{c['id']}", headers=yonetici_b, json={"durum": "cozuldu"}
    ).status_code == 404
