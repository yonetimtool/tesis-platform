"""Etkinlik + RSVP: yonetim CRUD + push + seffaf sayilar + tek-RSVP upsert +
RBAC + izolasyon.

RBAC (auth.md §4): olustur/duzenle/sil admin+yonetici; OKUMA (sayilar dahil)
TUM roller — seffaflik; RSVP YALNIZ resident, kullanici basina TEK kayit
(UNIQUE + ON CONFLICT upsert — degistirilebilir, cift kayit imkansiz).
Kim-katiliyor listesi DONMEZ — yalniz sayi + kendi beyanim.
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


def _mk_event(client, headers, **over):
    body = {
        "baslik": f"Etkinlik {uuid.uuid4().hex[:6]}",
        "aciklama": "Detayli aciklama.",
        "tarih": "2026-08-15T18:00:00Z",
    }
    body.update(over)
    r = client.post("/events", headers=headers, json=body)
    assert r.status_code == 201, r.text
    return r.json()


def _second_resident(client, world):
    """Ayni tenant'ta IKINCI bir sakin — sayac/upsert testleri icin."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    email = f"etk-sakin-{uuid.uuid4().hex[:8]}@acme.com"
    pw = "Sakin1234!"
    r = client.post(
        "/users",
        headers=admin,
        json={"ad": "Etkinlik Sakini", "email": email, "role": "resident", "password": pw},
    )
    assert r.status_code == 201, r.text
    return _headers(client, world["slug_a"], {"email": email, "password": pw})


# ------------------------------- yonetim ------------------------------------ #
def test_yonetici_olusturur_sayilar_sifir(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    e = _mk_event(client, yonetici, baslik="Mac izleme", konum="Sosyal tesis")
    assert e["baslik"] == "Mac izleme"
    assert e["konum"] == "Sosyal tesis"
    assert e["olusturan_ad"] == "Yonetici A"
    assert e["katiliyorum_sayisi"] == 0 and e["katilmiyorum_sayisi"] == 0
    assert e["benim_durumum"] is None
    # admin de olusturur
    admin = _headers(client, world["slug_a"], world["admin_a"])
    assert client.post("/events", headers=admin, json={
        "baslik": "Admin etkinligi", "aciklama": "x", "tarih": "2026-08-16T10:00:00Z",
    }).status_code == 201


def test_olusturma_rbac_ve_dogrulama(client, world):
    # personel + sakin olusturamaz
    for role in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.post("/events", headers=h, json={
            "baslik": "x", "aciklama": "y", "tarih": "2026-08-15T18:00:00Z",
        }).status_code == 403, role
    # bos baslik/aciklama/tarih eksik -> 422
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    for body in (
        {"baslik": "", "aciklama": "y", "tarih": "2026-08-15T18:00:00Z"},
        {"baslik": "x", "aciklama": "", "tarih": "2026-08-15T18:00:00Z"},
        {"baslik": "x", "aciklama": "y"},
    ):
        assert client.post("/events", headers=yonetici, json=body).status_code == 422, body


def test_duzenle_ve_sil(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])
    e = _mk_event(client, yonetici)

    # duzenle: baslik + konum
    p = client.patch(f"/events/{e['id']}", headers=yonetici,
                     json={"baslik": "Guncel baslik", "konum": "Teras"})
    assert p.status_code == 200, p.text
    assert p.json()["baslik"] == "Guncel baslik" and p.json()["konum"] == "Teras"
    # bos govde 422
    assert client.patch(f"/events/{e['id']}", headers=yonetici, json={}).status_code == 422
    # personel/sakin duzenleyemez + silemez
    assert client.patch(f"/events/{e['id']}", headers=resident,
                        json={"baslik": "x"}).status_code == 403
    assert client.delete(f"/events/{e['id']}", headers=resident).status_code == 403

    # RSVP sonrasi sil: RSVP'ler CASCADE, kayit 404
    client.put(f"/events/{e['id']}/rsvp", headers=resident, json={"durum": "katiliyorum"})
    assert client.delete(f"/events/{e['id']}", headers=yonetici).status_code == 204
    assert client.get(f"/events/{e['id']}", headers=yonetici).status_code == 404


# --------------------------- okuma + seffaf sayilar ------------------------- #
def test_tum_roller_okur_ve_sayilari_gorur(client, world):
    """SEFFAFLIK: sayilari 5 rolun 5'i de gorur (kimlik listesi yok)."""
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])
    e = _mk_event(client, yonetici, baslik="Seffaf sayac")
    client.put(f"/events/{e['id']}/rsvp", headers=resident, json={"durum": "katiliyorum"})

    for role in ("admin_a", "yonetici_a", "guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        d = client.get(f"/events/{e['id']}", headers=h)
        assert d.status_code == 200, role
        body = d.json()
        assert body["katiliyorum_sayisi"] == 1, role
        assert body["katilmiyorum_sayisi"] == 0, role
        # kimlik listesi DONMEZ — yalniz sayi + kendi beyanim
        assert "katilanlar" not in body and "rsvps" not in body
        # listede de ayni sayilar
        items = client.get("/events", headers=h, params={"limit": 200}).json()["items"]
        it = next(i for i in items if i["id"] == e["id"])
        assert it["katiliyorum_sayisi"] == 1, role

    # beyan sahibi kendi durumunu gorur; digerleri gormez (null)
    assert client.get(f"/events/{e['id']}", headers=resident).json()[
        "benim_durumum"] == "katiliyorum"
    guard = _headers(client, world["slug_a"], world["guard_a"])
    assert client.get(f"/events/{e['id']}", headers=guard).json()["benim_durumum"] is None


# --------------------------------- RSVP ------------------------------------- #
def test_rsvp_sayaci_yansitir_ve_degistirilebilir_cift_kayit_yok(client, world):
    """ANA AKIS: katiliyorum -> sayi 1; ikinci sakin -> 2; beyan degisince
    sayilar guncellenir, TOPLAM degismez (upsert — cift kayit yok)."""
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    resident1 = _headers(client, world["slug_a"], world["resident_a"])
    resident2 = _second_resident(client, world)
    e = _mk_event(client, yonetici, baslik="RSVP akisi")

    r1 = client.put(f"/events/{e['id']}/rsvp", headers=resident1,
                    json={"durum": "katiliyorum"})
    assert r1.status_code == 200, r1.text
    assert r1.json()["katiliyorum_sayisi"] == 1
    assert r1.json()["benim_durumum"] == "katiliyorum"

    r2 = client.put(f"/events/{e['id']}/rsvp", headers=resident2,
                    json={"durum": "katiliyorum"})
    assert r2.json()["katiliyorum_sayisi"] == 2

    # resident1 beyanini DEGISTIRIR: katiliyor 1'e duser, katilmiyor 1 olur
    r3 = client.put(f"/events/{e['id']}/rsvp", headers=resident1,
                    json={"durum": "katilmiyorum"})
    assert r3.status_code == 200
    body = r3.json()
    assert body["katiliyorum_sayisi"] == 1
    assert body["katilmiyorum_sayisi"] == 1
    assert body["benim_durumum"] == "katilmiyorum"

    # ayni beyani tekrar PUT: idempotent, sayilar sabit (cift kayit yok)
    r4 = client.put(f"/events/{e['id']}/rsvp", headers=resident1,
                    json={"durum": "katilmiyorum"})
    assert r4.json()["katiliyorum_sayisi"] == 1
    assert r4.json()["katilmiyorum_sayisi"] == 1


def test_rsvp_rbac_ve_dogrulama(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])
    e = _mk_event(client, yonetici)
    # personel + yonetim RSVP veremez (muhatap sakinler — karar)
    for role in ("admin_a", "yonetici_a", "guard_a", "gorevli_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.put(f"/events/{e['id']}/rsvp", headers=h,
                          json={"durum": "katiliyorum"}).status_code == 403, role
    # gecersiz durum / bos govde 422; olmayan etkinlik 404
    for body in ({"durum": "belki"}, {}):
        assert client.put(f"/events/{e['id']}/rsvp", headers=resident,
                          json=body).status_code == 422, body
    assert client.put(f"/events/{uuid.uuid4()}/rsvp", headers=resident,
                      json={"durum": "katiliyorum"}).status_code == 404


# --------------------------------- push ------------------------------------- #
def test_olusturma_pushu_sakin_cihazlarina_denenir(client, world):
    """Yeni etkinlik push'unun hedefi SAKIN rolu cihazlaridir; personel
    cihazi hedef degildir (ayni RLS-safe secim fonksiyonuyla dogrulanir)."""
    resident = _headers(client, world["slug_a"], world["resident_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    tag = uuid.uuid4().hex[:6]
    assert client.post("/devices", headers=resident,
                       json={"fcm_token": f"ETK-RES-{tag}", "platform": "android"}
                       ).status_code in (200, 201)
    assert client.post("/devices", headers=guard,
                       json={"fcm_token": f"ETK-GRD-{tag}", "platform": "android"}
                       ).status_code in (200, 201)

    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    _mk_event(client, yonetici)  # push denenir (server noop)

    from app.scheduler.notify import _fetch_device_tokens

    toks = set(_fetch_device_tokens(world["a"], ("resident",)))
    assert f"ETK-RES-{tag}" in toks
    assert f"ETK-GRD-{tag}" not in toks


# ----------------------------- tenant izolasyonu ---------------------------- #
def test_tenant_izolasyonu(client, world):
    yonetici_a = _headers(client, world["slug_a"], world["yonetici_a"])
    e = _mk_event(client, yonetici_a, baslik="A-ozel etkinlik")

    yonetici_b = _headers(client, world["slug_b"], world["yonetici_b"])
    b_ids = [it["id"] for it in client.get(
        "/events", headers=yonetici_b, params={"limit": 200}
    ).json()["items"]]
    assert e["id"] not in b_ids
    assert client.get(f"/events/{e['id']}", headers=yonetici_b).status_code == 404
    assert client.patch(f"/events/{e['id']}", headers=yonetici_b,
                        json={"baslik": "gasp"}).status_code == 404
    assert client.delete(f"/events/{e['id']}", headers=yonetici_b).status_code == 404
