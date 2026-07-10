"""Site kurallari: yonetim CRUD + herkes okur + siralama + baslik aramasi
(?q= ILIKE) + foto roundtrip + RBAC + izolasyon.

RBAC (auth.md §4): CRUD admin+yonetici; OKUMA TUM roller. Arama SUNUCU
tarafinda ILIKE (buyuk/kucuk harf duyarsiz, joker kacisli, tenant-kapsamli).
Silme HARD DELETE (salt icerik). Foto mevcut presign akisi.
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


def _mk_rule(client, headers, **over):
    body = {
        "baslik": f"Kural {uuid.uuid4().hex[:6]}",
        "icerik": "Detayli kural metni.",
    }
    body.update(over)
    r = client.post("/site-rules", headers=headers, json=body)
    assert r.status_code == 201, r.text
    return r.json()


# ------------------------------- yonetim ------------------------------------ #
def test_yonetici_ekler_duzenler_siler(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    k = _mk_rule(client, yonetici, baslik="Havuz Saatleri", sira=2)
    assert k["baslik"] == "Havuz Saatleri"
    assert k["sira"] == 2
    assert k["olusturan_ad"] == "Yonetici A"
    assert k["foto_key"] is None and k["foto_url"] is None

    # duzenle: icerik + sira
    p = client.patch(f"/site-rules/{k['id']}", headers=yonetici,
                     json={"icerik": "Guncel metin.", "sira": 5})
    assert p.status_code == 200, p.text
    assert p.json()["icerik"] == "Guncel metin." and p.json()["sira"] == 5
    # bos govde 422
    assert client.patch(f"/site-rules/{k['id']}", headers=yonetici,
                        json={}).status_code == 422

    # sil (HARD DELETE) -> 404
    assert client.delete(f"/site-rules/{k['id']}", headers=yonetici).status_code == 204
    assert client.get(f"/site-rules/{k['id']}", headers=yonetici).status_code == 404

    # admin de ekleyebilir
    admin = _headers(client, world["slug_a"], world["admin_a"])
    assert client.post("/site-rules", headers=admin, json={
        "baslik": "Admin kurali", "icerik": "x",
    }).status_code == 201


def test_yonetim_rbac_ve_dogrulama(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    k = _mk_rule(client, yonetici)
    # personel + sakin CRUD YAPAMAZ
    for role in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.post("/site-rules", headers=h, json={
            "baslik": "x", "icerik": "y",
        }).status_code == 403, role
        assert client.patch(f"/site-rules/{k['id']}", headers=h,
                            json={"baslik": "x"}).status_code == 403, role
        assert client.delete(f"/site-rules/{k['id']}", headers=h).status_code == 403, role
    # dogrulama: bos baslik/icerik, negatif sira -> 422
    for body in (
        {"baslik": "", "icerik": "y"},
        {"baslik": "x", "icerik": ""},
        {"baslik": "x", "icerik": "y", "sira": -1},
    ):
        assert client.post("/site-rules", headers=yonetici,
                           json=body).status_code == 422, body


# --------------------------- okuma + siralama ------------------------------- #
def test_tum_roller_okur_liste_sirali(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    tag = uuid.uuid4().hex[:6]
    k3 = _mk_rule(client, yonetici, baslik=f"S3-{tag}", sira=3)
    k1 = _mk_rule(client, yonetici, baslik=f"S1-{tag}", sira=1)
    k2 = _mk_rule(client, yonetici, baslik=f"S2-{tag}", sira=2)

    for role in ("admin_a", "yonetici_a", "guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        r = client.get("/site-rules", headers=h, params={"limit": 200})
        assert r.status_code == 200, role
        ids = [it["id"] for it in r.json()["items"]]
        # sira ASC: S1 < S2 < S3 (olusturma sirasi 3-1-2 olsa da)
        assert ids.index(k1["id"]) < ids.index(k2["id"]) < ids.index(k3["id"]), role
        # detay da okunur
        assert client.get(f"/site-rules/{k1['id']}", headers=h).status_code == 200, role


# ------------------------------- arama (?q=) -------------------------------- #
def test_baslik_aramasi_buyuk_kucuk_duyarsiz(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])
    tag = uuid.uuid4().hex[:6]
    havuz = _mk_rule(client, yonetici, baslik=f"Havuz Saatleri {tag}")
    otopark = _mk_rule(client, yonetici, baslik=f"Otopark Kullanimi {tag}")

    # buyuk/kucuk harf duyarsiz esleme; eslesmeyen dislanir
    items = client.get("/site-rules", headers=resident,
                       params={"q": "hAvUz", "limit": 200}).json()["items"]
    ids = [it["id"] for it in items]
    assert havuz["id"] in ids and otopark["id"] not in ids
    # kismi esleme
    items2 = client.get("/site-rules", headers=resident,
                        params={"q": tag, "limit": 200}).json()["items"]
    ids2 = [it["id"] for it in items2]
    assert havuz["id"] in ids2 and otopark["id"] in ids2
    # eslesme yoksa bos + total 0
    bos = client.get("/site-rules", headers=resident,
                     params={"q": f"olmayan-{uuid.uuid4().hex}"}).json()
    assert bos["items"] == [] and bos["meta"]["total"] == 0
    # icerikte gecen ama baslikta gecmeyen kelime ESLESMEZ (arama basliga)
    icerik_kelimesi = client.get(
        "/site-rules", headers=resident,
        params={"q": "Detayli kural metni", "limit": 200},
    ).json()["items"]
    assert not any(it["id"] in (havuz["id"], otopark["id"]) for it in icerik_kelimesi)


def test_arama_joker_karakterleri_literal(client, world):
    """% ve _ ILIKE jokerleri kacislanir — 'q=%' her seyi ESLESTIRMEZ.

    NOT: httpx params '%' isaretini URL-kodlamaz (zaten-kodlu sayar) —
    sunucuya bozuk deger gitmesin diye sorgu ACIKCA quote edilir (gercek
    istemciler — curl/Dio — zaten dogru kodlar).
    """
    from urllib.parse import quote

    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    k = _mk_rule(client, yonetici, baslik=f"%100 Kural {uuid.uuid4().hex[:6]}")
    resident = _headers(client, world["slug_a"], world["resident_a"])
    # literal '%100' aramasi kaydi bulur
    ids = [it["id"] for it in client.get(
        f"/site-rules?q={quote('%100')}&limit=200", headers=resident
    ).json()["items"]]
    assert k["id"] in ids
    # '%zzz%' gibi jokerli desen literal aranir -> eslesme yok
    assert client.get(
        f"/site-rules?q={quote(f'%{uuid.uuid4().hex}%')}", headers=resident
    ).json()["meta"]["total"] == 0


# -------------------------------- foto -------------------------------------- #
def test_fotolu_kural_ve_okumada_foto_url(client, world):
    """MEVCUT presign akisi: yonetici presign -> foto_key ile kural ->
    okumada foto_url (presigned GET); acik null gorseli kaldirir."""
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    pre = client.post("/uploads/presign", headers=yonetici,
                      json={"content_type": "image/jpeg"})
    assert pre.status_code == 200, pre.text
    foto_key = pre.json()["foto_key"]

    k = _mk_rule(client, yonetici, foto_key=foto_key)
    assert k["foto_key"] == foto_key
    assert k["foto_url"] and "X-Amz-Signature" in k["foto_url"]

    # sakin da gorseli okur
    resident = _headers(client, world["slug_a"], world["resident_a"])
    d = client.get(f"/site-rules/{k['id']}", headers=resident)
    assert d.status_code == 200 and "X-Amz-Signature" in d.json()["foto_url"]

    # PATCH acik null -> gorsel kaldirilir
    p = client.patch(f"/site-rules/{k['id']}", headers=yonetici,
                     json={"foto_key": None})
    assert p.status_code == 200
    assert p.json()["foto_key"] is None and p.json()["foto_url"] is None


def test_foto_key_tenant_namespace_disina_cikamaz(client, world):
    """Complaints/kargo'daki IDOR korumasinin aynisi: yabanci anahtar 422."""
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    for foto_key in (f"{world['b']}/tasks/victim.jpg", "serbest/anahtar.jpg"):
        assert client.post("/site-rules", headers=yonetici, json={
            "baslik": "x", "icerik": "y", "foto_key": foto_key,
        }).status_code == 422, foto_key


# ----------------------------- tenant izolasyonu ---------------------------- #
def test_tenant_izolasyonu_liste_detay_arama(client, world):
    yonetici_a = _headers(client, world["slug_a"], world["yonetici_a"])
    tag = uuid.uuid4().hex[:6]
    k = _mk_rule(client, yonetici_a, baslik=f"A-ozel kural {tag}")

    yonetici_b = _headers(client, world["slug_b"], world["yonetici_b"])
    # B listede/detayda goremez, degistiremez/silemez (RLS -> 404)
    b_ids = [it["id"] for it in client.get(
        "/site-rules", headers=yonetici_b, params={"limit": 200}
    ).json()["items"]]
    assert k["id"] not in b_ids
    assert client.get(f"/site-rules/{k['id']}", headers=yonetici_b).status_code == 404
    assert client.patch(f"/site-rules/{k['id']}", headers=yonetici_b,
                        json={"baslik": "gasp"}).status_code == 404
    assert client.delete(f"/site-rules/{k['id']}", headers=yonetici_b).status_code == 404
    # ARAMA da tenant-kapsamli: B'nin aramasina A'nin kurali SIZMAZ
    assert client.get(
        "/site-rules", headers=yonetici_b, params={"q": tag}
    ).json()["meta"]["total"] == 0
