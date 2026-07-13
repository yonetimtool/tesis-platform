"""Ziyaretci LOG kaydi: kayit + tek-hedef BILGILENDIRME push + RBAC + izolasyon.

ONAY/RED KALDIRILDI: ziyaretci artik yalniz bir gunluk (log) kaydidir — durum
alani yok, sakin yaniti (PATCH) yok. Guvenlik kaydeder + HEDEF sakine bir
bilgilendirme push'u gider.

RBAC/GIZLILIK (auth.md §4): KAYIT yalniz security + TEK hedef sakin secer
(target_resident_user_id, dairenin aktif sakini olmali). Gorunurluk/bildirim
YALNIZ hedef sakinde (ayni dairedeki es GORMEZ). OKUMA: admin+security TUM
gecmis; resident yalniz KENDINE HEDEFLENEN; yonetici VARSAYILAN KAPALI (403 —
tek-seferlik izinle acilir, bkz. test_unit_access); tesis_gorevlisi 403. Tenant
izolasyonu RLS ile.
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


def _register_visitor(client, headers, target, **over):
    """Guvenlik ziyaretci kaydeder. `target` = HEDEF sakin user id (tek hedef
    modeli, A): bilgilendirme push'u + gorunurluk YALNIZ onda."""
    body = {
        "ziyaretci_ad": f"Ziyaretci {uuid.uuid4().hex[:6]}",
        "target_resident_user_id": target,
    }
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


def _mk_security(owner_conn, tenant_id, email, pw):
    from app.security import hash_password

    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, email, password_hash, role) "
            "VALUES (%s,%s,%s,%s,'security'::user_role) RETURNING id",
            (tenant_id, f"Guard {email.split('@')[0]}", email, hash_password(pw)),
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
    # B tenant guvenligi: cross-tenant okuma izolasyonunu gostermek icin.
    guard_b_email = f"guardb-{suffix}@acme.com"
    _mk_security(owner_conn, world["b"], guard_b_email, pw)

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
        "diger_id": str(diger_id),
        "es": {"email": es_email, "password": pw},
        "diger": {"email": diger_email, "password": pw},
        "guard_b": {"email": guard_b_email, "password": pw},
    }
    # temizlik world fixture'inda: tenant silinince CASCADE.


# ----------------- hedef sakin secicisi (GET unit residents) ---------------- #
def test_daire_sakinleri_listesi_guvenlik_gorur(client, vworld):
    """GET /units/by-no/{unit_no}/residents: guvenlik dairenin AKTIF
    sakinlerini (user_id + ad) gorur — hedef sakin secicisi icin."""
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    r = client.get(
        f"/units/by-no/{vworld['unit1_no']}/residents", headers=guard
    )
    assert r.status_code == 200, r.text
    ids = {it["user_id"] for it in r.json()}
    assert {vworld["resident_a_id"], vworld["es_id"]} <= ids
    assert all(it["ad"] for it in r.json())
    for role in ("admin_a", "yonetici_a"):
        h = _headers(client, vworld["slug_a"], vworld[role])
        assert client.get(
            f"/units/by-no/{vworld['unit1_no']}/residents", headers=h
        ).status_code == 200, role


def test_daire_sakinleri_listesi_rbac_ve_404(client, vworld):
    """resident komsularini LISTELEYEMEZ (403); tesis_gorevlisi 403; olmayan
    daire 404."""
    for role in ("resident_a", "gorevli_a"):
        h = _headers(client, vworld["slug_a"], vworld[role])
        assert client.get(
            f"/units/by-no/{vworld['unit1_no']}/residents", headers=h
        ).status_code == 403, role
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    assert client.get(
        "/units/by-no/YOK-999/residents", headers=guard
    ).status_code == 404


def test_daire_sakinleri_listesi_tenant_izolasyonu(client, vworld):
    """B tenant guvenligi A'nin dairesinin sakinlerini goremez (RLS -> 404)."""
    guard_b = _headers(client, vworld["slug_b"], vworld["guard_b"])
    assert client.get(
        f"/units/by-no/{vworld['unit1_no']}/residents", headers=guard_b
    ).status_code == 404


# ------------------------------- kayit (log) -------------------------------- #
def test_guvenlik_unit_no_ile_kaydeder_log(client, vworld):
    """Log-only kayit: durum alani YOKTUR; kayit hedef sakini + daireyi tasir."""
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    v = _register_visitor(
        client, guard, vworld["resident_a_id"],
        ziyaretci_ad="Kurye Mehmet", unit_no=vworld["unit1_no"], notlar="Koli teslimati",
    )
    # LOG-ONLY: onay/red alanlari kaldirildi.
    assert "durum" not in v
    assert "yanitlayan_user_id" not in v and "yanit_zamani" not in v
    assert v["unit_id"] == vworld["unit1"]
    assert v["unit_no"] == vworld["unit1_no"]
    assert v["kaydeden_ad"] == "Guard A"
    assert v["notlar"] == "Koli teslimati"
    # Tek hedef modeli (A): kayit HEDEF sakini tasir (ad join'li).
    assert v["target_resident_user_id"] == vworld["resident_a_id"]
    assert v["target_resident_ad"] == "Resident A"


def test_guvenlik_unit_id_ile_de_kaydeder(client, vworld):
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    v = _register_visitor(
        client, guard, vworld["resident_a_id"], unit_id=vworld["unit1"]
    )
    assert v["unit_id"] == vworld["unit1"] and "durum" not in v


def test_kayit_hedef_daire_sakini_degilse_422(client, vworld):
    """Hedef sakin O dairenin AKTIF sakini olmali; baska dairenin sakinini
    (veya rastgele id) hedef gostermek -> 422 invalid_reference."""
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    r = client.post(
        "/visitors", headers=guard,
        json={
            "ziyaretci_ad": "X", "unit_no": vworld["unit1_no"],
            "target_resident_user_id": vworld["diger_id"],
        },
    )
    assert r.status_code == 422 and r.json()["error"]["code"] == "invalid_reference"
    assert client.post(
        "/visitors", headers=guard,
        json={
            "ziyaretci_ad": "X", "unit_no": vworld["unit1_no"],
            "target_resident_user_id": str(uuid.uuid4()),
        },
    ).status_code == 422


def test_kayit_dogrulama(client, vworld):
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    tgt = vworld["resident_a_id"]
    for body in (
        {"ziyaretci_ad": "X", "target_resident_user_id": tgt},
        {"ziyaretci_ad": "X", "target_resident_user_id": tgt,
         "unit_id": vworld["unit1"], "unit_no": vworld["unit1_no"]},
    ):
        assert client.post("/visitors", headers=guard, json=body).status_code == 422, body
    # hedef sakin eksik -> 422
    assert client.post(
        "/visitors", headers=guard,
        json={"ziyaretci_ad": "X", "unit_no": vworld["unit1_no"]},
    ).status_code == 422
    # olmayan daire -> 422 invalid_reference
    r = client.post(
        "/visitors", headers=guard,
        json={"ziyaretci_ad": "X", "unit_no": "YOK-999", "target_resident_user_id": tgt},
    )
    assert r.status_code == 422 and r.json()["error"]["code"] == "invalid_reference"
    assert client.post(
        "/visitors", headers=guard,
        json={"ziyaretci_ad": "X", "unit_id": str(uuid.uuid4()),
              "target_resident_user_id": tgt},
    ).status_code == 422
    # bos ziyaretci adi -> 422
    assert client.post(
        "/visitors", headers=guard,
        json={"ziyaretci_ad": "", "unit_no": vworld["unit1_no"],
              "target_resident_user_id": tgt},
    ).status_code == 422


def test_kayit_rbac_yalniz_guvenlik(client, vworld):
    """Kesin kural: kayit KAPI operasyonu — admin/yonetici/gorevli/sakin 403."""
    for role in ("admin_a", "yonetici_a", "gorevli_a", "resident_a"):
        h = _headers(client, vworld["slug_a"], vworld[role])
        assert client.post(
            "/visitors", headers=h,
            json={"ziyaretci_ad": "X", "unit_no": vworld["unit1_no"],
                  "target_resident_user_id": vworld["resident_a_id"]},
        ).status_code == 403, role


def test_kayit_bilgilendirme_push_yalniz_hedef_sakine(client, vworld):
    """Log-only: kayit HEDEF sakine BILGILENDIRME push'u tetikler — ayni
    dairedeki es hedef DEGILSE bildirilmez. (Onay/red istenmez; sadece haber.)"""
    resident1 = _headers(client, vworld["slug_a"], vworld["resident_a"])
    es = _headers(client, vworld["slug_a"], vworld["es"])
    tag = uuid.uuid4().hex[:6]
    for h, tok in ((resident1, f"RES1-{tag}"), (es, f"ES-{tag}")):
        assert client.post(
            "/devices", headers=h, json={"fcm_token": tok, "platform": "android"}
        ).status_code in (200, 201)

    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    v = _register_visitor(client, guard, vworld["resident_a_id"], unit_no=vworld["unit1_no"])
    assert v["target_resident_user_id"] == vworld["resident_a_id"]

    from app.scheduler.notify import _fetch_device_tokens_for_users

    hedef_toks = set(_fetch_device_tokens_for_users(vworld["a"], [vworld["resident_a_id"]]))
    assert f"RES1-{tag}" in hedef_toks
    assert f"ES-{tag}" not in hedef_toks


# ------------------------- onay/red kaldirildi (PATCH yok) ------------------ #
def test_yanit_ucu_kaldirildi_405(client, vworld):
    """Onay/red akisi KALDIRILDI: PATCH /visitors/{id} artik YOK -> 405
    (method not allowed). Hicbir rol ziyaretci 'yanitlayamaz'."""
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    v = _register_visitor(client, guard, vworld["resident_a_id"], unit_no=vworld["unit1_no"])
    for role in ("resident_a", "es", "guard_a", "yonetici_a", "admin_a"):
        h = _headers(client, vworld["slug_a"], vworld[role])
        r = client.patch(f"/visitors/{v['id']}", headers=h, json={"durum": "onaylandi"})
        assert r.status_code == 405, (role, r.status_code)


# ------------------------------- okuma -------------------------------------- #
def test_sakin_yalniz_kendine_hedeflenen_kayitlari_gorur(client, vworld):
    """Tek hedef modeli (A): sakin YALNIZ kendine hedeflenen kaydi gorur —
    ayni dairedeki es'e hedeflenmis kaydi GORMEZ; baska dairenin kaydini da."""
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    v_a = _register_visitor(client, guard, vworld["resident_a_id"], unit_no=vworld["unit1_no"])
    v_es = _register_visitor(client, guard, vworld["es_id"], unit_no=vworld["unit1_no"])
    v2 = _register_visitor(client, guard, vworld["diger_id"], unit_no=vworld["unit2_no"])

    resident = _headers(client, vworld["slug_a"], vworld["resident_a"])
    ids = [it["id"] for it in client.get(
        "/visitors", headers=resident, params={"limit": 200}
    ).json()["items"]]
    assert v_a["id"] in ids
    assert v_es["id"] not in ids and v2["id"] not in ids
    assert client.get(f"/visitors/{v_es['id']}", headers=resident).status_code == 404
    assert client.get(f"/visitors/{v2['id']}", headers=resident).status_code == 404
    assert client.get(f"/visitors/{v_a['id']}", headers=resident).status_code == 200


def test_guvenlik_tum_gecmisi_gorur_yonetim_403(client, vworld):
    """A (KVKK): YALNIZ guvenlik (kapi ops — vardiya devri) TUM gecmisi gorur;
    YONETICI VE ADMIN VARSAYILAN KAPALI -> 403 (izin almadan goremez)."""
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    v1 = _register_visitor(client, guard, vworld["resident_a_id"], unit_no=vworld["unit1_no"])
    v2 = _register_visitor(client, guard, vworld["diger_id"], unit_no=vworld["unit2_no"])
    ids = [it["id"] for it in client.get(
        "/visitors", headers=guard, params={"limit": 200}
    ).json()["items"]]
    assert v1["id"] in ids and v2["id"] in ids
    assert client.get(f"/visitors/{v1['id']}", headers=guard).status_code == 200
    for role in ("yonetici_a", "admin_a"):
        h = _headers(client, vworld["slug_a"], vworld[role])
        assert client.get(
            "/visitors", headers=h, params={"limit": 200}
        ).status_code == 403, role
        assert client.get(
            "/visitors", headers=h, params={"unit_id": vworld["unit1"]}
        ).status_code == 403, role
        assert client.get(f"/visitors/{v1['id']}", headers=h).status_code == 403, role


def test_okuma_rbac_gorevli_403(client, vworld):
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    v = _register_visitor(client, guard, vworld["resident_a_id"], unit_no=vworld["unit1_no"])
    gorevli = _headers(client, vworld["slug_a"], vworld["gorevli_a"])
    assert client.get("/visitors", headers=gorevli).status_code == 403
    assert client.get(f"/visitors/{v['id']}", headers=gorevli).status_code == 403


def test_liste_filtre_ve_sira(client, vworld):
    """Daire filtresi + created_at DESC + tarih filtresi (durum filtresi
    kaldirildi — log-only)."""
    guard = _headers(client, vworld["slug_a"], vworld["guard_a"])
    a = _register_visitor(client, guard, vworld["resident_a_id"], unit_no=vworld["unit1_no"])
    b = _register_visitor(client, guard, vworld["diger_id"], unit_no=vworld["unit2_no"])

    unit1_kayitlari = client.get(
        "/visitors", headers=guard, params={"unit_id": vworld["unit1"], "limit": 200}
    ).json()["items"]
    assert all(it["unit_id"] == vworld["unit1"] for it in unit1_kayitlari)
    assert any(it["id"] == a["id"] for it in unit1_kayitlari)
    assert not any(it["id"] == b["id"] for it in unit1_kayitlari)
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
    v = _register_visitor(client, guard, vworld["resident_a_id"], unit_no=vworld["unit1_no"])

    guard_b = _headers(client, vworld["slug_b"], vworld["guard_b"])
    b_ids = [it["id"] for it in client.get(
        "/visitors", headers=guard_b, params={"limit": 200}
    ).json()["items"]]
    assert v["id"] not in b_ids
    assert client.get(f"/visitors/{v['id']}", headers=guard_b).status_code == 404
