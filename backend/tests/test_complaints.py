"""Talep/Ariza acma + kendi/yonetim gorunumu + RBAC + izolasyon + kategori.

Durum gecisleri (convert/resolve/decline) + timeline uctan uca test_ticketing.py'de;
burada ACMA sekli, gorunurluk kapsami, RBAC ve tenant izolasyonu dogrulanir.

RBAC (auth.md §4): ACMA security+tesis_gorevlisi+resident (yonetici/admin 403);
OKUMA acan roller KENDI + admin/yonetici TUMU; durum gecisleri (convert/resolve/
decline) yalniz admin+yonetici (acan roller 403).

Sema: gorseller `foto_keys` (liste) ile acilir, okumada `fotograflar[].foto_url`
kisa-omurlu presigned GET doner; kategori dinamik `kategori_id` (task_category FK),
okumada `kategori_ad` ile birlikte doner.
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


def _new_category(client, mgr, ad="Elektrik"):
    r = client.post("/task-categories", headers=mgr, json={"ad": f"{ad}-{uuid.uuid4().hex[:6]}"})
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
        json={"ad": "Sakin Iki", "email": email,
              "telefon": "+90" + str(uuid.uuid4().int)[:10],
              "role": "resident", "password": pw},
    )
    assert r.status_code == 201, r.text
    return _headers(client, world["slug_a"], {"email": email, "password": pw})


# ------------------------------- acma --------------------------------------- #
def test_resident_acar_durum_acik(client, world):
    resident = _headers(client, world["slug_a"], world["resident_a"])
    c = _new(client, resident, baslik="Asansor arizali", mesaj="A blok asansoru durdu.")
    assert c["durum"] == "acik"
    assert c["acan_ad"] == "Resident A"
    assert c["fotograflar"] == []
    assert c["kategori_id"] is None and c["kategori_ad"] is None
    assert c["is_emri_id"] is None and c["is_emri_durum"] is None
    assert [h["durum"] for h in c["gecmis"]] == ["acik"]


def test_saha_rolleri_de_acar(client, world):
    """Kesin kural: security + tesis_gorevlisi de talep ACAR (201)."""
    for role, ad in (("guard_a", "Guard A"), ("gorevli_a", "Gorevli A")):
        h = _headers(client, world["slug_a"], world[role])
        c = _new(client, h, baslik=f"{ad} talebi")
        assert c["durum"] == "acik" and c["acan_ad"] == ad, role


def test_fotolu_acma_ve_okumada_foto_url(client, world):
    """presign (resident erisir) -> foto_keys ile ac -> okumada fotograflar[].
    foto_url doner (yonetim detayda da gorur)."""
    resident = _headers(client, world["slug_a"], world["resident_a"])
    pre = client.post(
        "/uploads/presign", headers=resident, json={"content_type": "image/jpeg"}
    )
    assert pre.status_code == 200, pre.text
    foto_key = pre.json()["foto_key"]

    c = _new(client, resident, baslik="Gorselli talep", foto_keys=[foto_key])
    assert [p["foto_key"] for p in c["fotograflar"]] == [foto_key]
    assert c["fotograflar"][0]["foto_url"] and "X-Amz-Signature" in c["fotograflar"][0]["foto_url"]

    # yonetim de detayda gorseli gorur
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    d = client.get(f"/complaints/{c['id']}", headers=yonetici)
    assert d.status_code == 200
    assert "X-Amz-Signature" in d.json()["fotograflar"][0]["foto_url"]


def test_foto_key_tenant_namespace_disina_cikamaz(client, world):
    """Duyurudaki IDOR korumasinin aynisi: yabanci/serbest anahtar 422."""
    resident = _headers(client, world["slug_a"], world["resident_a"])
    r = client.post(
        "/complaints",
        headers=resident,
        json={
            "baslik": "x",
            "mesaj": "y",
            "foto_keys": [f"{world['b']}/tasks/victim.jpg"],
        },
    )
    assert r.status_code == 422, r.text
    assert client.post(
        "/complaints",
        headers=resident,
        json={"baslik": "x", "mesaj": "y", "foto_keys": ["serbest/anahtar.jpg"]},
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
def test_acan_roller_yalniz_kendini_gorur_yonetim_tumunu(client, world):
    """Kesin kural: her acan rol (saha + sakin) YALNIZ kendi actigini gorur —
    baska acanin kaydini listede goremez, detayda 404; yonetim tumunu gorur."""
    resident1 = _headers(client, world["slug_a"], world["resident_a"])
    resident2 = _second_resident(client, world)
    guard = _headers(client, world["slug_a"], world["guard_a"])
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])

    c_res1 = _new(client, resident1, baslik="Sakin1 talebi")
    c_res2 = _new(client, resident2, baslik="Sakin2 talebi")
    c_guard = _new(client, guard, baslik="Guard talebi")
    c_gorevli = _new(client, gorevli, baslik="Gorevli talebi")

    # her acan yalniz KENDI kaydini listeler
    for h, kendi, yabanci in (
        (resident1, c_res1, c_guard),
        (guard, c_guard, c_res1),
        (gorevli, c_gorevli, c_res2),
    ):
        ids = [it["id"] for it in client.get(
            "/complaints", headers=h, params={"limit": 200}
        ).json()["items"]]
        assert kendi["id"] in ids and yabanci["id"] not in ids
        # detayda baskasinin talebi 404 (varlik sizdirilmaz)
        assert client.get(f"/complaints/{yabanci['id']}", headers=h).status_code == 404
        assert client.get(f"/complaints/{kendi['id']}", headers=h).status_code == 200

    # resident1, resident2'ninkini de goremez (ayni rol, farkli kisi)
    ids1 = [it["id"] for it in client.get(
        "/complaints", headers=resident1, params={"limit": 200}
    ).json()["items"]]
    assert c_res2["id"] not in ids1

    # yonetici + admin DORDUNU de gorur
    for role in ("yonetici_a", "admin_a"):
        h = _headers(client, world["slug_a"], world[role])
        ids = [it["id"] for it in client.get(
            "/complaints", headers=h, params={"limit": 200}
        ).json()["items"]]
        for c in (c_res1, c_res2, c_guard, c_gorevli):
            assert c["id"] in ids, role
        assert client.get(f"/complaints/{c_guard['id']}", headers=h).status_code == 200


def test_liste_durum_filtresi_ve_sira(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])
    a = _new(client, resident, baslik="Filtre-acik")
    b = _new(client, resident, baslik="Filtre-cozulecek")
    # durum gecisi artik dogrudan resolve endpoint'i ile (PATCH kaldirildi)
    assert client.post(
        f"/complaints/{b['id']}/resolve", headers=yonetici, json={}
    ).status_code == 200

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


# -------------------------------- RBAC -------------------------------------- #
def test_rbac_acan_roller_gecis_403_yonetim_acamaz(client, world):
    """Kesin kural: durum gecisleri (convert/resolve/decline) yalniz yonetim —
    acan roller (security/tesis_gorevlisi/resident) KENDI talebinde bile 403;
    yonetim (yonetici/admin) talep ACAMAZ (403), ama gecis yapar (resolve 200)."""
    # her acan rol kendi talebini acar; convert/resolve/decline 403
    for role in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        c = _new(client, h, baslik=f"RBAC {role}")
        assert client.post(
            f"/complaints/{c['id']}/resolve", headers=h, json={}
        ).status_code == 403, role
        assert client.post(
            f"/complaints/{c['id']}/decline", headers=h, json={"sebep": "x"}
        ).status_code == 403, role
        assert client.post(
            f"/complaints/{c['id']}/convert", headers=h,
            json={"atanan_user_id": str(uuid.uuid4()), "oncelik": "orta"},
        ).status_code == 403, role

    # yonetim talep ACAMAZ (kanalin cevaplayan tarafi) ama gecis yapar
    resident = _headers(client, world["slug_a"], world["resident_a"])
    for role in ("yonetici_a", "admin_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.post(
            "/complaints", headers=h, json={"baslik": "x", "mesaj": "y"}
        ).status_code == 403, role
        c = _new(client, resident, baslik=f"Yonetim cozer {role}")
        assert client.post(
            f"/complaints/{c['id']}/resolve", headers=h, json={}
        ).status_code == 200, role


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
    assert client.post(
        f"/complaints/{c['id']}/resolve", headers=yonetici_b, json={}
    ).status_code == 404


# ------------------------ kategori (dinamik task_category) ------------------ #
def test_kategori_ile_acma_ve_okuma(client, world):
    """Opsiyonel kategori: kategori_id ile acilir, okumada kategori_id +
    kategori_ad doner; kategorisiz eski davranis calisir (null)."""
    resident = _headers(client, world["slug_a"], world["resident_a"])
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    kat = _new_category(client, yonetici, ad="Gurultu")

    c = _new(client, resident, baslik="Gece muzik sesi", kategori_id=kat["id"])
    assert c["kategori_id"] == kat["id"]
    assert c["kategori_ad"] == kat["ad"]

    kategorisiz = _new(client, resident, baslik="Genel bir talep")
    assert kategorisiz["kategori_id"] is None and kategorisiz["kategori_ad"] is None

    # tekil okuma kategoriyi doner
    r = client.get(f"/complaints/{c['id']}", headers=resident)
    assert r.status_code == 200
    assert r.json()["kategori_id"] == kat["id"] and r.json()["kategori_ad"] == kat["ad"]


def test_kategori_gecersiz_uuid_422(client, world):
    """kategori_id UUID olmali; sekilsiz deger -> 422 (sema dogrulamasi)."""
    resident = _headers(client, world["slug_a"], world["resident_a"])
    r = client.post(
        "/complaints",
        headers=resident,
        json={"baslik": "x", "mesaj": "y", "kategori_id": "olmayan-tur"},
    )
    assert r.status_code == 422, r.text
