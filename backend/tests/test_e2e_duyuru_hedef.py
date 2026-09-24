"""(E2E 2026-09) BILDIRIM-12 — DUYURUDA HEDEF KITLE.

OLCULEN (once): `POST /announcements` hedef almiyordu; push tenant'taki
TUM rollere gidiyordu — duyuruyu yazan yonetici DAHIL.

Kilitlenen davranis:
  * Hedef (rol / malik-kiraci / blok) kaydedilir ve geri doner.
  * OKUMA KAPSAMI hedefe bagli: hedef disi kullanici listede GORMEZ, tekil
    GET 404. Yonetim (admin/yonetici) her zaman gorur.
  * Sakin tipi + blok YALNIZ sakinlere uygulanir ve AYNI dairede birlikte
    aranir; personel yalniz rol suzgecine tabidir.
  * Push YALNIZ hedefe gider ve OLUSTURAN kendi duyurusunun push'unu ALMAZ.
  * Hedef sonradan degistirilemez (PATCH tasimaz).
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
    body = {"baslik": f"Hedef {uuid.uuid4().hex[:6]}", "govde": "Icerik."}
    body.update(over)
    r = client.post("/announcements", headers=headers, json=body)
    assert r.status_code == 201, r.text
    return r.json()


def _listede(client, headers, ann_id) -> bool:
    items = client.get(
        "/announcements", headers=headers, params={"limit": 200}
    ).json()["items"]
    return any(it["id"] == ann_id for it in items)


def _sakini_daireye_bagla(client, admin, resident_id, blok, rol_tipi):
    u = client.post(
        "/units", headers=admin,
        json={"no": f"HD-{uuid.uuid4().hex[:6]}", "blok": blok},
    )
    assert u.status_code == 201, u.text
    r = client.post(
        f"/units/{u.json()['id']}/residents",
        headers=admin,
        json={"user_id": resident_id, "rol_tipi": rol_tipi},
    )
    assert r.status_code == 201, r.text


def _push_sayisi(owner_conn, user_id, since) -> int:
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM push_gonderim "
            "WHERE kimlik = 'duyuru' AND user_id = %s AND created_at >= %s",
            (user_id, since),
        )
        return cur.fetchone()[0]


def _simdi(owner_conn):
    with owner_conn.cursor() as cur:
        cur.execute("SELECT now()")
        return cur.fetchone()[0]


# ------------------------------------------------------------------------- #
def test_HEDEF_kaydedilir_ve_doner(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    a = _new(
        client, yon,
        hedef_roller=["resident", "security"],
        hedef_sakin_tipi="malik",
        hedef_bloklar=[" A", "A", ""],
    )
    assert set(a["hedef_roller"]) == {"resident", "security"}
    assert a["hedef_sakin_tipi"] == "malik"
    # bosluk/yinelenen/bos blok adi temizlenir
    assert a["hedef_bloklar"] == ["A"]
    client.delete(f"/announcements/{a['id']}", headers=yon)


def test_HEDEFSIZ_duyuru_herkese(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    a = _new(client, yon)
    assert a["hedef_roller"] == [] and a["hedef_bloklar"] == []
    assert a["hedef_sakin_tipi"] is None
    assert _listede(client, sakin, a["id"])
    assert _listede(client, guard, a["id"])
    client.delete(f"/announcements/{a['id']}", headers=yon)


def test_ROL_HEDEFI_disindaki_GORMEZ_yonetim_gorur(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    a = _new(client, yon, hedef_roller=["security"])
    assert _listede(client, guard, a["id"])
    assert client.get(f"/announcements/{a['id']}", headers=guard).status_code == 200
    # hedef disi sakin: listede yok, tekil 404 (varligi da sizmaz)
    assert not _listede(client, sakin, a["id"])
    assert client.get(f"/announcements/{a['id']}", headers=sakin).status_code == 404
    # yonetim her zaman gorur
    assert _listede(client, yon, a["id"])
    assert _listede(client, admin, a["id"])
    client.delete(f"/announcements/{a['id']}", headers=yon)


def test_BLOK_ve_SAKIN_TIPI_ayni_dairede_birlikte(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    rid = client.get("/me", headers=sakin).json()["id"]
    blok_x = f"HX{uuid.uuid4().hex[:4]}"
    blok_y = f"HY{uuid.uuid4().hex[:4]}"
    # X blokta KIRACI, Y blokta MALIK
    _sakini_daireye_bagla(client, admin, rid, blok_x, "kiraci")
    _sakini_daireye_bagla(client, admin, rid, blok_y, "malik")

    x_blok = _new(client, yon, hedef_bloklar=[blok_x])
    baska_blok = _new(client, yon, hedef_bloklar=[f"YOK{uuid.uuid4().hex[:4]}"])
    x_malikleri = _new(client, yon, hedef_bloklar=[blok_x], hedef_sakin_tipi="malik")
    y_malikleri = _new(client, yon, hedef_bloklar=[blok_y], hedef_sakin_tipi="malik")
    kiracilar = _new(client, yon, hedef_sakin_tipi="kiraci")

    assert _listede(client, sakin, x_blok["id"])
    assert not _listede(client, sakin, baska_blok["id"])
    # X'te kiraci, Y'de malik: "X blok malikleri" hedefinde DEGIL
    assert not _listede(client, sakin, x_malikleri["id"])
    assert _listede(client, sakin, y_malikleri["id"])
    assert _listede(client, sakin, kiracilar["id"])
    # blok/sakin tipi personele uygulanmaz (rol hedefi bos = herkes)
    assert _listede(client, guard, baska_blok["id"])

    for a in (x_blok, baska_blok, x_malikleri, y_malikleri, kiracilar):
        client.delete(f"/announcements/{a['id']}", headers=yon)


def test_PUSH_hedefe_gider_OLUSTURAN_almaz(client, world, owner_conn):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    ids = {}
    for ad, h in (("yon", yon), ("sakin", sakin), ("guard", guard)):
        ids[ad] = client.get("/me", headers=h).json()["id"]
        assert client.post(
            "/devices", headers=h,
            json={"fcm_token": f"DH-{uuid.uuid4().hex[:12]}", "platform": "android"},
        ).status_code == 201
    blok = f"HP{uuid.uuid4().hex[:4]}"
    _sakini_daireye_bagla(client, admin, ids["sakin"], blok, "malik")

    t0 = _simdi(owner_conn)
    herkes = _new(client, yon)
    # hedefsiz: sakin + guard alir, OLUSTURAN yonetici ALMAZ
    assert _push_sayisi(owner_conn, ids["sakin"], t0) >= 1
    assert _push_sayisi(owner_conn, ids["guard"], t0) >= 1
    assert _push_sayisi(owner_conn, ids["yon"], t0) == 0

    t1 = _simdi(owner_conn)
    yalniz_guvenlik = _new(client, yon, hedef_roller=["security"])
    assert _push_sayisi(owner_conn, ids["guard"], t1) >= 1
    assert _push_sayisi(owner_conn, ids["sakin"], t1) == 0

    t2 = _simdi(owner_conn)
    blok_sakinleri = _new(client, yon, hedef_roller=["resident"], hedef_bloklar=[blok])
    assert _push_sayisi(owner_conn, ids["sakin"], t2) >= 1
    assert _push_sayisi(owner_conn, ids["guard"], t2) == 0

    t3 = _simdi(owner_conn)
    baska_blok = _new(client, yon, hedef_bloklar=[f"YOK{uuid.uuid4().hex[:4]}"])
    assert _push_sayisi(owner_conn, ids["sakin"], t3) == 0

    for a in (herkes, yalniz_guvenlik, blok_sakinleri, baska_blok):
        client.delete(f"/announcements/{a['id']}", headers=yon)


def test_BILINMEYEN_hedef_422(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    for govde in (
        {"hedef_roller": ["uydurma_rol"]},
        {"hedef_sakin_tipi": "misafir"},
    ):
        r = client.post(
            "/announcements", headers=yon,
            json={"baslik": "x", "govde": "y", **govde},
        )
        assert r.status_code == 422, r.text


def test_HEDEF_PATCH_ile_DEGISMEZ(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    a = _new(client, yon, hedef_roller=["security"])
    p = client.patch(
        f"/announcements/{a['id']}", headers=yon,
        json={"govde": "Yeni.", "hedef_roller": []},
    )
    assert p.status_code == 200, p.text
    assert p.json()["hedef_roller"] == ["security"]
    client.delete(f"/announcements/{a['id']}", headers=yon)


def test_ARAMA_hedef_disi_duyuruyu_BULMAZ(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    iz = f"hdara{uuid.uuid4().hex[:6]}"
    a = _new(client, yon, baslik=f"Personel {iz}", hedef_roller=["security"])
    r = client.get("/arama", headers=sakin, params={"q": iz})
    assert r.status_code == 200, r.text
    # Yanit sorguyu (`q`) geri yansitir; bakilan VURUSLARdir.
    assert not [v for v in r.json()["items"] if iz in (v.get("baslik") or "")]
    client.delete(f"/announcements/{a['id']}", headers=yon)
