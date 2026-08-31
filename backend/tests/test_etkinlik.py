"""Etkinlik + RSVP: yonetim CRUD + push + seffaf sayilar + tek-RSVP upsert +
RBAC + izolasyon.

RBAC (auth.md §4): olustur/duzenle/sil admin+yonetici; OKUMA (sayilar dahil)
TUM roller — seffaflik; RSVP YALNIZ resident, kullanici basina TEK kayit
(UNIQUE, KILITLI — ilk beyandan sonra degistirilemez; tekrar PUT 409, cift
kayit imkansiz). Kim-katiliyor listesi DONMEZ — yalniz sayi + kendi beyanim.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone


def _iso(**delta) -> str:
    """GERCEK simdiye GORELI ISO zaman — testler saate/gune bagli kalmasin."""
    return (datetime.now(timezone.utc) + timedelta(**delta)).isoformat()


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


def _second_resident(client, world, owner_conn):
    """Ayni tenant'ta IKINCI bir sakin — sayac/upsert testleri icin."""
    from app.security import hash_password

    admin = _headers(client, world["slug_a"], world["admin_a"])
    email = f"etk-sakin-{uuid.uuid4().hex[:8]}@acme.com"
    pw = "Sakin1234!"
    r = client.post(
        "/users",
        headers=admin,
        json={"ad": "Etkinlik Sakini", "email": email,
              "telefon": "+90" + str(uuid.uuid4().int)[:10],
              "role": "resident"},
    )
    assert r.status_code == 201, r.text
    # (P186) POST /users parola almaz ve yonetici parola atayamaz; giris
    # yapabilmesi icin parolayi DB'ye dogrudan yaz (world fixture'i gibi).
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE app_user SET password_hash=%s, password_set=true WHERE id=%s",
            (hash_password(pw), r.json()["id"]),
        )
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
def test_rsvp_sayaci_yansitir_ve_beyan_kilitli_cift_kayit_yok(client, world, owner_conn):
    """ANA AKIS: katiliyorum -> sayi 1; ikinci sakin -> 2. Beyan KILITLI:
    ilk beyandan sonra tekrar PUT (farkli VEYA ayni durum) 409 doner; sayilar
    degismez, cift kayit olusmaz (secim kesin)."""
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    resident1 = _headers(client, world["slug_a"], world["resident_a"])
    resident2 = _second_resident(client, world, owner_conn)
    e = _mk_event(client, yonetici, baslik="RSVP akisi")

    r1 = client.put(f"/events/{e['id']}/rsvp", headers=resident1,
                    json={"durum": "katiliyorum"})
    assert r1.status_code == 200, r1.text
    assert r1.json()["katiliyorum_sayisi"] == 1
    assert r1.json()["benim_durumum"] == "katiliyorum"

    r2 = client.put(f"/events/{e['id']}/rsvp", headers=resident2,
                    json={"durum": "katiliyorum"})
    assert r2.json()["katiliyorum_sayisi"] == 2

    # resident1 beyanini DEGISTIREMEZ: kilit -> 409, sayilar sabit kalir
    r3 = client.put(f"/events/{e['id']}/rsvp", headers=resident1,
                    json={"durum": "katilmiyorum"})
    assert r3.status_code == 409, r3.text
    assert r3.json()["error"]["code"] == "already_answered"

    # ayni durumu tekrar PUT etmek de KILITLI (idempotent degil — 409)
    r4 = client.put(f"/events/{e['id']}/rsvp", headers=resident1,
                    json={"durum": "katiliyorum"})
    assert r4.status_code == 409, r4.text

    # sayilar hic degismedi: resident1 katiliyor + resident2 katiliyor = 2/0
    body = client.get(f"/events/{e['id']}", headers=resident1).json()
    assert body["katiliyorum_sayisi"] == 2
    assert body["katilmiyorum_sayisi"] == 0
    assert body["benim_durumum"] == "katiliyorum"


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

    # (P191 §2) `Cihaz` doner (token + dil + SAHIBI) — yalniz token'lar.
    toks = {c.token for c in _fetch_device_tokens(world["a"], ("resident",))}
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


# ------------------------------ gorsel (WP-H) ------------------------------- #
def test_gorselli_etkinlik_ve_okumada_foto_url(client, world):
    """MEVCUT presign akisi (duyuru/site kurali ile AYNI): yonetici presign ->
    foto_key ile etkinlik -> okumada foto_url (presigned GET). Sakin de gorur;
    acik null gorseli kaldirir."""
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    pre = client.post("/uploads/presign", headers=yonetici,
                      json={"content_type": "image/jpeg"})
    assert pre.status_code == 200, pre.text
    foto_key = pre.json()["foto_key"]

    e = _mk_event(client, yonetici, foto_key=foto_key)
    assert e["foto_key"] == foto_key
    assert e["foto_url"] and "X-Amz-Signature" in e["foto_url"]

    # sakin da gorseli okur (ana ekran "yaklasan etkinlikler" bolumu)
    resident = _headers(client, world["slug_a"], world["resident_a"])
    d = client.get(f"/events/{e['id']}", headers=resident)
    assert d.status_code == 200 and "X-Amz-Signature" in d.json()["foto_url"]

    # PATCH ile gorsel degistirme + acik null ile kaldirma
    pre2 = client.post("/uploads/presign", headers=yonetici,
                       json={"content_type": "image/png"})
    yeni_key = pre2.json()["foto_key"]
    p = client.patch(f"/events/{e['id']}", headers=yonetici,
                     json={"foto_key": yeni_key})
    assert p.status_code == 200 and p.json()["foto_key"] == yeni_key

    p = client.patch(f"/events/{e['id']}", headers=yonetici,
                     json={"foto_key": None})
    assert p.status_code == 200
    assert p.json()["foto_key"] is None and p.json()["foto_url"] is None


def test_gorsel_foto_key_tenant_namespace_disina_cikamaz(client, world):
    """Duyuru/site kurali/kargo ile ayni IDOR korumasi: yabanci anahtar 422."""
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    for foto_key in (f"{world['b']}/tasks/victim.jpg", "serbest/anahtar.jpg"):
        r = client.post("/events", headers=yonetici, json={
            "baslik": f"E{uuid.uuid4().hex[:5]}", "aciklama": "x",
            "tarih": _iso(days=2), "foto_key": foto_key,
        })
        assert r.status_code == 422, foto_key
    # PATCH de korumali
    e = _mk_event(client, yonetici)
    assert client.patch(f"/events/{e['id']}", headers=yonetici, json={
        "foto_key": f"{world['b']}/tasks/victim.jpg",
    }).status_code == 422


# ----------------------- yaklasan/aktif suzgeci (WP-H) ---------------------- #
def test_aktif_suzgeci_bitis_zamani_gecene_kadar_listede(client, world):
    """?aktif=true: COALESCE(bitis_zamani, tarih) >= now().

    * suren  : basladi ama bitmedi -> AKTIF (bitis alani olmasa duserdi)
    * yaklasan: henuz baslamadi    -> AKTIF
    * bitmis : bitisi gecti        -> AKTIF DEGIL
    * anlik  : bitis YOK, tarih gecti -> AKTIF DEGIL
    """
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    tag = uuid.uuid4().hex[:6]
    suren = _mk_event(client, yonetici, baslik=f"Suren {tag}",
                      tarih=_iso(hours=-1), bitis_zamani=_iso(hours=2))
    yaklasan = _mk_event(client, yonetici, baslik=f"Yaklasan {tag}",
                         tarih=_iso(days=3), bitis_zamani=_iso(days=3, hours=4))
    bitmis = _mk_event(client, yonetici, baslik=f"Bitmis {tag}",
                       tarih=_iso(days=-2), bitis_zamani=_iso(days=-2, hours=3))
    anlik_gecmis = _mk_event(client, yonetici, baslik=f"Anlik {tag}",
                             tarih=_iso(hours=-3))

    aktifler = client.get("/events", headers=yonetici,
                          params={"aktif": "true", "limit": 200}).json()["items"]
    ids = [i["id"] for i in aktifler]
    assert suren["id"] in ids and yaklasan["id"] in ids
    assert bitmis["id"] not in ids and anlik_gecmis["id"] not in ids

    # aktif=true YAKLASAN siralamasi: en yakin bitis once
    kendi = [i["id"] for i in aktifler if i["id"] in (suren["id"], yaklasan["id"])]
    assert kendi == [suren["id"], yaklasan["id"]]

    # aktif=false: bitmisler
    bitmisler = [i["id"] for i in client.get(
        "/events", headers=yonetici, params={"aktif": "false", "limit": 200}
    ).json()["items"]]
    assert bitmis["id"] in bitmisler and anlik_gecmis["id"] in bitmisler
    assert suren["id"] not in bitmisler

    # suzgecsiz: hepsi (geriye uyumlu)
    tumu = [i["id"] for i in client.get(
        "/events", headers=yonetici, params={"limit": 200}
    ).json()["items"]]
    for e in (suren, yaklasan, bitmis, anlik_gecmis):
        assert e["id"] in tumu


def test_aktif_suzgeci_meta_total_suzulmus_kumeyi_sayar(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    _mk_event(client, yonetici, tarih=_iso(days=-5))  # bitmis
    tumu = client.get("/events", headers=yonetici,
                      params={"limit": 1}).json()["meta"]["total"]
    aktif = client.get("/events", headers=yonetici,
                       params={"limit": 1, "aktif": "true"}).json()["meta"]["total"]
    assert aktif < tumu


def test_sakin_yaklasan_etkinlikleri_gorselleriyle_okur(client, world):
    """Ana ekran bolumu: sakin ?aktif=true + limit ile yaklasanlari okur."""
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    foto_key = client.post("/uploads/presign", headers=yonetici,
                           json={"content_type": "image/jpeg"}).json()["foto_key"]
    e = _mk_event(client, yonetici, baslik=f"Bahar {uuid.uuid4().hex[:5]}",
                  tarih=_iso(days=1), bitis_zamani=_iso(days=1, hours=5),
                  foto_key=foto_key)

    resident = _headers(client, world["slug_a"], world["resident_a"])
    r = client.get("/events", headers=resident,
                   params={"aktif": "true", "limit": 5})
    assert r.status_code == 200
    kayit = next((i for i in r.json()["items"] if i["id"] == e["id"]), None)
    assert kayit is not None
    assert kayit["bitis_zamani"] is not None
    assert "X-Amz-Signature" in kayit["foto_url"]


def test_bitis_zamani_baslangictan_once_olamaz_422(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    # olusturmada
    r = client.post("/events", headers=yonetici, json={
        "baslik": f"E{uuid.uuid4().hex[:5]}", "aciklama": "x",
        "tarih": _iso(days=3), "bitis_zamani": _iso(days=2),
    })
    assert r.status_code == 422, r.text

    # PATCH: yalniz bitis gonderilse bile MEVCUT baslangicla dogrulanir
    e = _mk_event(client, yonetici, tarih=_iso(days=3))
    assert client.patch(f"/events/{e['id']}", headers=yonetici, json={
        "bitis_zamani": _iso(days=1),
    }).status_code == 422
    # ... ve yalniz tarih gonderilse bile MEVCUT bitisle dogrulanir
    e2 = _mk_event(client, yonetici, tarih=_iso(days=3),
                   bitis_zamani=_iso(days=3, hours=2))
    assert client.patch(f"/events/{e2['id']}", headers=yonetici, json={
        "tarih": _iso(days=9),
    }).status_code == 422

    # gecerli guncelleme + acik null ile bitisi kaldirma (anlik etkinlik)
    ok = client.patch(f"/events/{e2['id']}", headers=yonetici, json={
        "bitis_zamani": _iso(days=4),
    })
    assert ok.status_code == 200 and ok.json()["bitis_zamani"] is not None
    ok = client.patch(f"/events/{e2['id']}", headers=yonetici,
                      json={"bitis_zamani": None})
    assert ok.status_code == 200 and ok.json()["bitis_zamani"] is None


def test_naive_zaman_utc_kabul_edilir_karisik_govde_500_URETMEZ(client, world):
    """Regresyon: naive ve aware datetime karsilastirilamaz (TypeError).

    Sozlesme konvansiyonu "tum zamanlar UTC" oldugu icin naive deger UTC
    kabul edilir; aksi halde karisik govde (naive tarih + aware bitis) ya da
    "naive bitis + DB'den gelen aware tarih" PATCH'i 500 uretirdi.
    """
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    naive = "2026-09-01T18:00:00"
    aware = "2026-09-01T21:00:00Z"

    # 1) karisik govde: naive baslangic + aware bitis -> 201 (500 DEGIL)
    r = client.post("/events", headers=yonetici, json={
        "baslik": f"Karisik {uuid.uuid4().hex[:5]}", "aciklama": "x",
        "tarih": naive, "bitis_zamani": aware,
    })
    assert r.status_code == 201, r.text
    e = r.json()

    # 2) PATCH: naive bitis, DB'de aware baslangic -> 200 (500 DEGIL)
    p = client.patch(f"/events/{e['id']}", headers=yonetici,
                     json={"bitis_zamani": "2026-09-01T23:30:00"})
    assert p.status_code == 200, p.text

    # 3) naive degerlerde de ters aralik yakalanir (422, 500 degil)
    bad = client.patch(f"/events/{e['id']}", headers=yonetici,
                       json={"bitis_zamani": "2026-08-01T10:00:00"})
    assert bad.status_code == 422, bad.text
