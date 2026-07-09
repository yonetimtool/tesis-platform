"""Duyuru: CRUD + RBAC (gonderme admin/yonetici, okuma TUM roller) + izolasyon."""
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
    body = {"baslik": f"Duyuru {uuid.uuid4().hex[:6]}", "govde": "Icerik."}
    body.update(over)
    r = client.post("/announcements", headers=headers, json=body)
    assert r.status_code == 201, r.text
    return r.json()


# -------------------------------- CRUD ------------------------------------- #
def test_crud_happy_path_yonetici(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])

    a = _new(client, yonetici, baslik="Su kesintisi", govde="Yarin 10:00-12:00.")
    assert a["olusturan_ad"] == "Yonetici A"

    # detay + listede en yeni onde
    assert client.get(f"/announcements/{a['id']}", headers=yonetici).status_code == 200
    b = _new(client, yonetici, baslik="Ikinci duyuru")
    listed = client.get("/announcements", headers=yonetici, params={"limit": 10}).json()
    ids = [it["id"] for it in listed["items"]]
    assert ids.index(b["id"]) < ids.index(a["id"])  # created_at DESC

    # guncelle
    p = client.patch(
        f"/announcements/{a['id']}", headers=yonetici, json={"govde": "Iptal edildi."}
    )
    assert p.status_code == 200 and p.json()["govde"] == "Iptal edildi."

    # sil
    assert client.delete(f"/announcements/{a['id']}", headers=yonetici).status_code == 204
    assert client.get(f"/announcements/{a['id']}", headers=yonetici).status_code == 404
    client.delete(f"/announcements/{b['id']}", headers=yonetici)


def test_admin_da_gonderebilir_platform_tarafi(client, world):
    """Kesin kural (auth.md §4): olusturma yonetici (mobil) + admin (panel).
    Saha rolleri + resident 403 (asagidaki RBAC testinde)."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    a = _new(client, admin, baslik="Admin duyurusu")
    assert a["olusturan_ad"] == "Admin A"
    client.delete(f"/announcements/{a['id']}", headers=admin)


def test_validation(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    # bos baslik/govde -> 422
    assert client.post(
        "/announcements", headers=yonetici, json={"baslik": "", "govde": "x"}
    ).status_code == 422
    assert client.post(
        "/announcements", headers=yonetici, json={"baslik": "x", "govde": ""}
    ).status_code == 422
    # PATCH bos govdeyle de 422
    a = _new(client, yonetici)
    assert client.patch(
        f"/announcements/{a['id']}", headers=yonetici, json={"baslik": ""}
    ).status_code == 422
    client.delete(f"/announcements/{a['id']}", headers=yonetici)


# -------------------------------- RBAC ------------------------------------- #
def test_rbac_okuma_tum_roller_yazma_yonetim(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    a = _new(client, yonetici, baslik="Herkese acik")

    for role in ("admin_a", "yonetici_a", "guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        r = client.get("/announcements", headers=h)
        assert r.status_code == 200, f"{role}: {r.text}"
        assert any(it["id"] == a["id"] for it in r.json()["items"])
        assert client.get(f"/announcements/{a['id']}", headers=h).status_code == 200

    # saha rolleri + resident YAZAMAZ (403)
    for role in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.post(
            "/announcements", headers=h, json={"baslik": "x", "govde": "y"}
        ).status_code == 403, role
        assert client.patch(
            f"/announcements/{a['id']}", headers=h, json={"baslik": "z"}
        ).status_code == 403, role
        assert client.delete(
            f"/announcements/{a['id']}", headers=h
        ).status_code == 403, role

    client.delete(f"/announcements/{a['id']}", headers=yonetici)


# -------------------------------- foto ------------------------------------- #
def test_fotolu_duyuru_olustur_ve_oku(client, world):
    """Foto'lu duyuru: presign (yonetici erisir) → foto_key ile olustur →
    okumada foto_key + presigned GET foto_url tum okuyan rollere doner."""
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])

    pre = client.post(
        "/uploads/presign", headers=yonetici, json={"content_type": "image/jpeg"}
    )
    assert pre.status_code == 200, pre.text
    foto_key = pre.json()["foto_key"]
    assert "X-Amz-Signature" in pre.json()["upload_url"]

    a = _new(client, yonetici, baslik="Gorselli duyuru", foto_key=foto_key)
    assert a["foto_key"] == foto_key
    assert a["foto_url"] and "X-Amz-Signature" in a["foto_url"]

    # okuyan her rol foto_url'u gorur (liste + detay)
    for role in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        d = client.get(f"/announcements/{a['id']}", headers=h)
        assert d.status_code == 200, f"{role}: {d.text}"
        assert d.json()["foto_key"] == foto_key
        assert "X-Amz-Signature" in d.json()["foto_url"]
        listed = client.get(
            "/announcements", headers=h, params={"limit": 200}
        ).json()["items"]
        item = next(it for it in listed if it["id"] == a["id"])
        assert item["foto_url"]

    client.delete(f"/announcements/{a['id']}", headers=yonetici)


def test_fotosuz_duyuru_geriye_uyumlu(client, world):
    """foto_key gonderilmeyen duyuru eskisi gibi calisir; foto alanlari null."""
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    a = _new(client, yonetici, baslik="Duz duyuru")
    assert a["foto_key"] is None and a["foto_url"] is None

    d = client.get(f"/announcements/{a['id']}", headers=yonetici).json()
    assert d["foto_key"] is None and d["foto_url"] is None
    client.delete(f"/announcements/{a['id']}", headers=yonetici)


def test_foto_patch_ile_kaldirilir(client, world):
    """PATCH foto_key=null gorseli kaldirir; alan gonderilmezse dokunulmaz."""
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    foto_key = f"{world['a']}/tasks/deadbeef.jpg"
    a = _new(client, yonetici, foto_key=foto_key)

    # foto_key alani olmayan PATCH gorsele dokunmaz
    p = client.patch(
        f"/announcements/{a['id']}", headers=yonetici, json={"baslik": "Yeni baslik"}
    )
    assert p.status_code == 200 and p.json()["foto_key"] == foto_key

    # acik null gorseli kaldirir
    p = client.patch(
        f"/announcements/{a['id']}", headers=yonetici, json={"foto_key": None}
    )
    assert p.status_code == 200 and p.json()["foto_key"] is None
    client.delete(f"/announcements/{a['id']}", headers=yonetici)


def test_fotolu_olusturma_rbac(client, world):
    """Foto'lu bile olsa olusturma yalniz admin+yonetici; digerleri 403."""
    for role in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.post(
            "/announcements",
            headers=h,
            json={
                "baslik": "x",
                "govde": "y",
                "foto_key": f"{world['a']}/tasks/x.jpg",
            },
        ).status_code == 403, role


def test_foto_key_tenant_namespace_disina_cikamaz(client, world):
    """foto_key kendi tenant onekiyle baslamali — okumada sunucu bu anahtara
    presigned GET imzalar; baska tenant'in anahtari kabul edilirse capraz-tenant
    gorsel sizar (IDOR). Olusturma + PATCH ikisi de 422."""
    yonetici_b = _headers(client, world["slug_b"], world["yonetici_b"])

    # B yoneticisi A tenant'inin anahtarini gonderemez
    r = client.post(
        "/announcements",
        headers=yonetici_b,
        json={
            "baslik": "x",
            "govde": "y",
            "foto_key": f"{world['a']}/tasks/victim.jpg",
        },
    )
    assert r.status_code == 422, r.text

    # PATCH ile de sokulamaz
    a = _new(client, yonetici_b, baslik="B duyurusu")
    assert client.patch(
        f"/announcements/{a['id']}",
        headers=yonetici_b,
        json={"foto_key": f"{world['a']}/tasks/victim.jpg"},
    ).status_code == 422
    # tenant'siz/serbest anahtar da reddedilir
    assert client.patch(
        f"/announcements/{a['id']}",
        headers=yonetici_b,
        json={"foto_key": "serbest/anahtar.jpg"},
    ).status_code == 422
    client.delete(f"/announcements/{a['id']}", headers=yonetici_b)


# ----------------------------- tenant izolasyonu --------------------------- #
def test_tenant_izolasyonu(client, world):
    yonetici_a = _headers(client, world["slug_a"], world["yonetici_a"])
    yonetici_b = _headers(client, world["slug_b"], world["yonetici_b"])

    a = _new(client, yonetici_a, baslik="A-ozel duyuru")

    # B tenant'i A'nin duyurusunu goremez/degistiremez/silemez (RLS -> 404)
    b_ids = [it["id"] for it in client.get(
        "/announcements", headers=yonetici_b, params={"limit": 200}
    ).json()["items"]]
    assert a["id"] not in b_ids
    assert client.get(f"/announcements/{a['id']}", headers=yonetici_b).status_code == 404
    assert client.patch(
        f"/announcements/{a['id']}", headers=yonetici_b, json={"baslik": "ele gecti"}
    ).status_code == 404
    assert client.delete(f"/announcements/{a['id']}", headers=yonetici_b).status_code == 404

    client.delete(f"/announcements/{a['id']}", headers=yonetici_a)
