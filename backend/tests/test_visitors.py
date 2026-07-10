"""Ziyaretci onay akisi: kayit + push hedefleri + onay/red + RBAC + izolasyon.

RBAC (auth.md §4, kesin kural): KAYIT yalniz security; YANIT yalniz O dairenin
AKTIF sakini (baska daire 404; ikinci yanit 409 — ilk kazanir); OKUMA
admin/yonetici/security TUM gecmis, resident yalniz KENDI daireleri,
tesis_gorevlisi 403. Tenant izolasyonu RLS ile.
"""
from __future__ import annotations

import uuid

import pytest


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _register_visitor(client, headers, **over):
    body = {"ziyaretci_ad": f"Ziyaretci {uuid.uuid4().hex[:6]}"}
    body.update(over)
    r = client.post("/visitors", headers=headers, json=body)
    assert r.status_code == 201, r.text
    return r.json()


def _mk_resident(owner_conn, tenant_id, email, pw):
    from app.security import hash_password

    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, email, password_hash, role) "
            "VALUES (%s,%s,%s,%s,'resident'::user_role) RETURNING id",
            (tenant_id, f"Sakin {email.split('@')[0]}", email, hash_password(pw)),
        )
        return cur.fetchone()[0]


def _mk_unit(owner_conn, tenant_id, no):
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO unit (tenant_id, no) VALUES (%s,%s) RETURNING id",
            (tenant_id, no),
        )
        return cur.fetchone()[0]


def _link(owner_conn, tenant_id, unit_id, user_id, bitis=None):
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO unit_resident (tenant_id, unit_id, user_id, bitis) "
            "VALUES (%s,%s,%s,%s)",
            (tenant_id, unit_id, user_id, bitis),
        )


@pytest.fixture
def vworld(client, world, owner_conn):
    """world + daireler ve sakin baglantilari:

    * unit1 (V-101): resident_a + es (resident_es) — AYNI dairede iki sakin.
    * unit2 (V-202): resident_diger — BASKA dairenin sakini.
    Sakinler email geriye-uyumlulugu ile login olur (auth.md §4 not).
    """
    a = world["a"]
    suffix = uuid.uuid4().hex[:6]
    pw = "VisitorPass1!"
    es_email = f"es-{suffix}@acme.com"
    diger_email = f"diger-{suffix}@acme.com"

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND email=%s AND role='resident'",
            (a, world["resident_a"]["email"]),
        )
        resident_a_id = cur.fetchone()[0]
    es_id = _mk_resident(owner_conn, a, es_email, pw)
    diger_id = _mk_resident(owner_conn, a, diger_email, pw)

    unit1 = _mk_unit(owner_conn, a, f"V-101-{suffix}")
    unit2 = _mk_unit(owner_conn, a, f"V-202-{suffix}")
    _link(owner_conn, a, unit1, resident_a_id)
    _link(owner_conn, a, unit1, es_id)
    _link(owner_conn, a, unit2, diger_id)

    return {
        **world,
        "unit1": str(unit1),
        "unit1_no": f"V-101-{suffix}",
        "unit2": str(unit2),
        "unit2_no": f"V-202-{suffix}",
        "resident_a_id": str(resident_a_id),
        "es_id": str(es_id),
        "es": {"email": es_email, "password": pw},
        "diger": {"email": diger_email, "password": pw},
    }
    # temizlik world fixture'inda: tenant silinince CASCADE.


# ------------------------------- kayit -------------------------------------- #
def test_guvenlik_unit_no_ile_kaydeder_bekliyor(client, vworld):
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    v = _register_visitor(
        client, guard,
        ziyaretci_ad="Kurye Mehmet", unit_no=vworld["unit1_no"], notlar="Koli teslimati",
    )
    assert v["durum"] == "bekliyor"
    assert v["unit_id"] == vworld["unit1"]
    assert v["unit_no"] == vworld["unit1_no"]
    assert v["kaydeden_ad"] == "Guard A"
    assert v["notlar"] == "Koli teslimati"
    assert v["yanitlayan_user_id"] is None and v["yanit_zamani"] is None


def test_guvenlik_unit_id_ile_de_kaydeder(client, vworld):
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    v = _register_visitor(client, guard, unit_id=vworld["unit1"])
    assert v["durum"] == "bekliyor" and v["unit_id"] == vworld["unit1"]


def test_kayit_dogrulama(client, vworld):
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    # daire referansi: ikisi birden / hicbiri -> 422
    for body in (
        {"ziyaretci_ad": "X"},
        {"ziyaretci_ad": "X", "unit_id": vworld["unit1"], "unit_no": vworld["unit1_no"]},
    ):
        assert client.post("/visitors", headers=guard, json=body).status_code == 422, body
    # olmayan daire -> 422 invalid_reference
    r = client.post(
        "/visitors", headers=guard,
        json={"ziyaretci_ad": "X", "unit_no": "YOK-999"},
    )
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "invalid_reference"
    assert client.post(
        "/visitors", headers=guard,
        json={"ziyaretci_ad": "X", "unit_id": str(uuid.uuid4())},
    ).status_code == 422
    # bos ziyaretci adi -> 422
    assert client.post(
        "/visitors", headers=guard,
        json={"ziyaretci_ad": "", "unit_no": vworld["unit1_no"]},
    ).status_code == 422


def test_kayit_rbac_yalniz_guvenlik(client, vworld):
    """Kesin kural: kayit KAPI operasyonu — admin/yonetici/gorevli/sakin 403."""
    for role in ("admin_a", "yonetici_a", "gorevli_a", "resident_a"):
        h = _headers(client, vworld["slug_a"], vworld[role])
        assert client.post(
            "/visitors", headers=h,
            json={"ziyaretci_ad": "X", "unit_no": vworld["unit1_no"]},
        ).status_code == 403, role


def test_kayit_push_tum_daire_sakinlerine_denenir(client, vworld):
    """Dairenin TUM aktif sakinlerinin cihaz token'lari push hedefidir
    (esler dahil); baska dairenin sakini hedef degildir."""
    resident1 = _headers(client, vworld["slug_a"], vworld["resident_a"])
    es = _headers(client, vworld["slug_a"], vworld["es"])
    tag = uuid.uuid4().hex[:6]
    for h, tok in ((resident1, f"RES1-{tag}"), (es, f"ES-{tag}")):
        assert client.post(
            "/devices", headers=h, json={"fcm_token": tok, "platform": "android"}
        ).status_code in (200, 201)

    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    _register_visitor(client, guard, unit_no=vworld["unit1_no"])  # push denenir (noop)

    # Router'in hedef secimi dispatch_external(target_user_ids=<daire sakinleri>);
    # ayni secim fonksiyonuyla iki sakinin de token'i cozulur (RLS-safe).
    from app.scheduler.notify import _fetch_device_tokens_for_users

    toks = set(
        _fetch_device_tokens_for_users(
            vworld["a"], [vworld["resident_a_id"], vworld["es_id"]]
        )
    )
    assert {f"RES1-{tag}", f"ES-{tag}"} <= toks


# ------------------------------- yanit -------------------------------------- #
def test_sakin_onaylar_yanitlayan_ve_zaman_damgalanir(client, vworld):
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    v = _register_visitor(client, guard, unit_no=vworld["unit1_no"])

    resident = _headers(client, vworld["slug_a"], vworld["resident_a"])
    p = client.patch(f"/visitors/{v['id']}", headers=resident, json={"durum": "onaylandi"})
    assert p.status_code == 200, p.text
    body = p.json()
    assert body["durum"] == "onaylandi"
    assert body["yanitlayan_user_id"] == vworld["resident_a_id"]
    assert body["yanitlayan_ad"] == "Resident A"
    assert body["yanit_zamani"] is not None

    # guvenlik ekraninda sonuc gorunur (canli durum)
    d = client.get(f"/visitors/{v['id']}", headers=guard).json()
    assert d["durum"] == "onaylandi" and d["yanitlayan_ad"] == "Resident A"


def test_sakin_reddeder(client, vworld):
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    v = _register_visitor(client, guard, unit_no=vworld["unit1_no"])
    es = _headers(client, vworld["slug_a"], vworld["es"])
    p = client.patch(f"/visitors/{v['id']}", headers=es, json={"durum": "reddedildi"})
    assert p.status_code == 200 and p.json()["durum"] == "reddedildi"
    assert p.json()["yanitlayan_user_id"] == vworld["es_id"]


def test_cifte_yanit_409_ilk_kazanir(client, vworld):
    """Ayni dairenin IKI sakini: ilk yanit gecerli, ikincisi 409; durum degismez."""
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    v = _register_visitor(client, guard, unit_no=vworld["unit1_no"])

    resident = _headers(client, vworld["slug_a"], vworld["resident_a"])
    es = _headers(client, vworld["slug_a"], vworld["es"])
    assert client.patch(
        f"/visitors/{v['id']}", headers=resident, json={"durum": "onaylandi"}
    ).status_code == 200
    r2 = client.patch(f"/visitors/{v['id']}", headers=es, json={"durum": "reddedildi"})
    assert r2.status_code == 409, r2.text
    # ayni sakin tekrar da yanitlayamaz
    assert client.patch(
        f"/visitors/{v['id']}", headers=resident, json={"durum": "reddedildi"}
    ).status_code == 409
    d = client.get(f"/visitors/{v['id']}", headers=guard).json()
    assert d["durum"] == "onaylandi"
    assert d["yanitlayan_user_id"] == vworld["resident_a_id"]


def test_baska_dairenin_sakini_yanitlayamaz_404(client, vworld):
    """Kesin kural: BASKA dairenin sakini 404 (varlik sizdirilmaz, bypass yok)."""
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    v = _register_visitor(client, guard, unit_no=vworld["unit1_no"])
    diger = _headers(client, vworld["slug_a"], vworld["diger"])
    r = client.patch(f"/visitors/{v['id']}", headers=diger, json={"durum": "onaylandi"})
    assert r.status_code == 404, r.text
    # kayit degismedi
    assert client.get(f"/visitors/{v['id']}", headers=guard).json()["durum"] == "bekliyor"


def test_yanit_rbac_personel_yanitlayamaz(client, vworld):
    """Onay yetkisi daire sakininde: guvenlik/gorevli/yonetici/admin PATCH 403."""
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    v = _register_visitor(client, guard, unit_no=vworld["unit1_no"])
    for role in ("guard_a", "gorevli_a", "yonetici_a", "admin_a"):
        h = _headers(client, vworld["slug_a"], vworld[role])
        assert client.patch(
            f"/visitors/{v['id']}", headers=h, json={"durum": "onaylandi"}
        ).status_code == 403, role


def test_yanit_dogrulama(client, vworld):
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    v = _register_visitor(client, guard, unit_no=vworld["unit1_no"])
    resident = _headers(client, vworld["slug_a"], vworld["resident_a"])
    # 'bekliyor'a geri donus / bilinmeyen durum / bos govde -> 422
    for body in ({"durum": "bekliyor"}, {"durum": "belki"}, {}):
        assert client.patch(
            f"/visitors/{v['id']}", headers=resident, json=body
        ).status_code == 422, body


# ------------------------------- okuma -------------------------------------- #
def test_sakin_yalniz_kendi_dairesinin_kayitlarini_gorur(client, vworld):
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    v1 = _register_visitor(client, guard, unit_no=vworld["unit1_no"])
    v2 = _register_visitor(client, guard, unit_no=vworld["unit2_no"])

    resident = _headers(client, vworld["slug_a"], vworld["resident_a"])
    ids = [it["id"] for it in client.get(
        "/visitors", headers=resident, params={"limit": 200}
    ).json()["items"]]
    assert v1["id"] in ids and v2["id"] not in ids
    # es de ayni dairenin kaydini gorur (coklu sakin)
    es = _headers(client, vworld["slug_a"], vworld["es"])
    es_ids = [it["id"] for it in client.get(
        "/visitors", headers=es, params={"limit": 200}
    ).json()["items"]]
    assert v1["id"] in es_ids
    # detay: baska dairenin kaydi 404 (varlik sizdirilmaz)
    assert client.get(f"/visitors/{v2['id']}", headers=resident).status_code == 404
    assert client.get(f"/visitors/{v1['id']}", headers=resident).status_code == 200


def test_guvenlik_ve_yonetim_tum_gecmisi_gorur(client, vworld):
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    v1 = _register_visitor(client, guard, unit_no=vworld["unit1_no"])
    v2 = _register_visitor(client, guard, unit_no=vworld["unit2_no"])
    for role in ("guard_a", "yonetici_a", "admin_a"):
        h = _headers(client, vworld["slug_a"], vworld[role])
        ids = [it["id"] for it in client.get(
            "/visitors", headers=h, params={"limit": 200}
        ).json()["items"]]
        assert v1["id"] in ids and v2["id"] in ids, role
        assert client.get(f"/visitors/{v1['id']}", headers=h).status_code == 200, role


def test_okuma_rbac_gorevli_403(client, vworld):
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    v = _register_visitor(client, guard, unit_no=vworld["unit1_no"])
    gorevli = _headers(client, vworld["slug_a"], vworld["gorevli_a"])
    assert client.get("/visitors", headers=gorevli).status_code == 403
    assert client.get(f"/visitors/{v['id']}", headers=gorevli).status_code == 403


def test_liste_filtre_ve_sira(client, vworld):
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    resident = _headers(client, vworld["slug_a"], vworld["resident_a"])
    a = _register_visitor(client, guard, unit_no=vworld["unit1_no"])
    b = _register_visitor(client, guard, unit_no=vworld["unit2_no"])
    client.patch(f"/visitors/{a['id']}", headers=resident, json={"durum": "onaylandi"})

    # durum filtresi
    bekleyen = client.get(
        "/visitors", headers=guard, params={"durum": "bekliyor", "limit": 200}
    ).json()["items"]
    assert all(it["durum"] == "bekliyor" for it in bekleyen)
    assert any(it["id"] == b["id"] for it in bekleyen)
    assert not any(it["id"] == a["id"] for it in bekleyen)
    # daire filtresi
    unit1_kayitlari = client.get(
        "/visitors", headers=guard, params={"unit_id": vworld["unit1"], "limit": 200}
    ).json()["items"]
    assert all(it["unit_id"] == vworld["unit1"] for it in unit1_kayitlari)
    # gecersiz durum -> 422
    assert client.get(
        "/visitors", headers=guard, params={"durum": "olmayan"}
    ).status_code == 422
    # created_at DESC: b daha yeni -> once gelir
    hepsi = client.get("/visitors", headers=guard, params={"limit": 200}).json()
    ids = [it["id"] for it in hepsi["items"]]
    assert ids.index(b["id"]) < ids.index(a["id"])
    assert hepsi["meta"]["total"] >= 2
    # tarih filtresi: bitis cok eski -> ikisi de dusar
    eski = client.get(
        "/visitors", headers=guard,
        params={"bitis": "2000-01-01T00:00:00Z", "limit": 200},
    ).json()["items"]
    assert not any(it["id"] in (a["id"], b["id"]) for it in eski)


# ----------------------------- tenant izolasyonu ---------------------------- #
def test_tenant_izolasyonu(client, vworld):
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    v = _register_visitor(client, guard, unit_no=vworld["unit1_no"])

    # B tenant yonetimi A'nin kaydini goremez/degistiremez (RLS -> 404)
    yonetici_b = _headers(client, vworld["slug_b"], vworld["yonetici_b"])
    b_ids = [it["id"] for it in client.get(
        "/visitors", headers=yonetici_b, params={"limit": 200}
    ).json()["items"]]
    assert v["id"] not in b_ids
    assert client.get(f"/visitors/{v['id']}", headers=yonetici_b).status_code == 404
    assert client.patch(
        f"/visitors/{v['id']}", headers=yonetici_b, json={"durum": "onaylandi"}
    ).status_code == 403  # rol zaten yetkisiz; kayit da B'den gorunmez


def test_pasif_sakin_baglantisi_yanitlayamaz(client, vworld, owner_conn):
    """Daireden cikarilmis (bitis dolu) sakin YANITLAYAMAZ ve kayitlari GOREMEZ."""
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    v = _register_visitor(client, guard, unit_no=vworld["unit1_no"])

    # es'in baglantisini pasiflestir
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE unit_resident SET bitis = now() WHERE unit_id=%s AND user_id=%s",
            (vworld["unit1"], vworld["es_id"]),
        )
    es = _headers(client, vworld["slug_a"], vworld["es"])
    assert client.patch(
        f"/visitors/{v['id']}", headers=es, json={"durum": "onaylandi"}
    ).status_code == 404
    ids = [it["id"] for it in client.get(
        "/visitors", headers=es, params={"limit": 200}
    ).json()["items"]]
    assert v["id"] not in ids
