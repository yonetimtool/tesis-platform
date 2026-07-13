"""Yonetici tek-seferlik (one-shot) daire erisim izni: talep + karar + tuketim.

Gizlilik (auth.md §4): ziyaretci/kargo VARSAYILAN olarak yonetici'ye kapali.
Yonetici bir daireye izin TALEBI acar -> dairenin sakini onaylar/reddeder.
Onay = tek-kullanimlik izin; yonetici o dairenin kaydini ILK okudugunda tuketilir
(used=true) -> sonraki okuma yeni talep ister. Tenant izolasyonu RLS ile.
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


def _link(owner_conn, tenant_id, unit_id, user_id):
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO unit_resident (tenant_id, unit_id, user_id) "
            "VALUES (%s,%s,%s)",
            (tenant_id, unit_id, user_id),
        )


@pytest.fixture
def uaworld(client, world, owner_conn):
    """world + iki daire: unit1 (resident_a bagli), unit2 (diger bagli)."""
    a = world["a"]
    suffix = uuid.uuid4().hex[:6]
    pw = "AccessPass1!"
    diger_email = f"uad-{suffix}@acme.com"

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND email=%s AND role='resident'",
            (a, world["resident_a"]["email"]),
        )
        resident_a_id = cur.fetchone()[0]
    diger_id = _mk_resident(owner_conn, a, diger_email, pw)

    unit1 = _mk_unit(owner_conn, a, f"UA-101-{suffix}")
    unit2 = _mk_unit(owner_conn, a, f"UA-202-{suffix}")
    _link(owner_conn, a, unit1, resident_a_id)
    _link(owner_conn, a, unit2, diger_id)

    return {
        **world,
        "unit1": str(unit1),
        "unit1_no": f"UA-101-{suffix}",
        "unit2": str(unit2),
        "unit2_no": f"UA-202-{suffix}",
        "resident_a_id": str(resident_a_id),
        "diger_id": str(diger_id),
        "diger": {"email": diger_email, "password": pw},
    }


def _register_visitor(client, guard, target, unit_no):
    r = client.post(
        "/visitors", headers=guard,
        json={
            "ziyaretci_ad": f"Z {uuid.uuid4().hex[:6]}",
            "unit_no": unit_no,
            "target_resident_user_id": target,
        },
    )
    assert r.status_code == 201, r.text
    return r.json()


def _open_request(client, yonetici, unit_no):
    r = client.post("/unit-access-request", headers=yonetici, json={"unit_no": unit_no})
    assert r.status_code == 201, r.text
    return r.json()


def _bulk(client, requester):
    r = client.post("/unit-access-request/bulk", headers=requester)
    assert r.status_code == 201, r.text
    return r.json()


# ------------------------------- talep -------------------------------------- #
def test_talep_yonetici_ve_admin(client, uaworld):
    """TALEP acma yonetici VEYA admin (ikisi de varsayilan kapali; scoped
    erisim icin talep acar) — security/gorevli/resident 403."""
    for role in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, uaworld["slug_a"], uaworld[role])
        assert client.post(
            "/unit-access-request", headers=h, json={"unit_no": uaworld["unit1_no"]}
        ).status_code == 403, role
    # hem yonetici hem admin talep acabilir (201)
    for role in ("yonetici_a", "admin_a"):
        h = _headers(client, uaworld["slug_a"], uaworld[role])
        req = _open_request(client, h, uaworld["unit1_no"])
        assert req["durum"] == "bekliyor" and req["used"] is False
        assert req["unit_id"] == uaworld["unit1"]


def test_talep_gecersiz_daire_422(client, uaworld):
    yonetici = _headers(client, uaworld["slug_a"], uaworld["yonetici_a"])
    r = client.post(
        "/unit-access-request", headers=yonetici, json={"unit_no": "YOK-000"}
    )
    assert r.status_code == 422 and r.json()["error"]["code"] == "invalid_reference"


def test_talep_push_daire_sakinlerine(client, uaworld):
    """Talep acilinca dairenin aktif sakinine push denenir (helper ile
    dogrulanir; canli test desenindeki gibi)."""
    resident = _headers(client, uaworld["slug_a"], uaworld["resident_a"])
    tag = uuid.uuid4().hex[:6]
    assert client.post(
        "/devices", headers=resident, json={"fcm_token": f"UA-{tag}", "platform": "android"}
    ).status_code in (200, 201)

    yonetici = _headers(client, uaworld["slug_a"], uaworld["yonetici_a"])
    _open_request(client, yonetici, uaworld["unit1_no"])

    from app.scheduler.notify import _fetch_device_tokens_for_users

    toks = set(_fetch_device_tokens_for_users(uaworld["a"], [uaworld["resident_a_id"]]))
    assert f"UA-{tag}" in toks


# ------------------------------- karar -------------------------------------- #
def test_karar_yalniz_dairenin_sakini(client, uaworld):
    """Karar yalniz talebin AIT OLDUGU dairenin sakininde; baska daire sakini
    404; personel/yonetici rol kapisinda 403."""
    yonetici = _headers(client, uaworld["slug_a"], uaworld["yonetici_a"])
    req = _open_request(client, yonetici, uaworld["unit1_no"])

    # baska dairenin sakini (diger) -> 404 (varlik sizdirilmaz)
    diger = _headers(client, uaworld["slug_a"], uaworld["diger"])
    assert client.patch(
        f"/unit-access-request/{req['id']}", headers=diger, json={"durum": "onaylandi"}
    ).status_code == 404
    # personel/yonetici/admin rol kapisinda 403 (karar sakinde)
    for role in ("guard_a", "gorevli_a", "yonetici_a", "admin_a"):
        h = _headers(client, uaworld["slug_a"], uaworld[role])
        assert client.patch(
            f"/unit-access-request/{req['id']}", headers=h, json={"durum": "onaylandi"}
        ).status_code == 403, role


def test_cifte_karar_409_ilk_kazanir(client, uaworld):
    yonetici = _headers(client, uaworld["slug_a"], uaworld["yonetici_a"])
    resident = _headers(client, uaworld["slug_a"], uaworld["resident_a"])
    req = _open_request(client, yonetici, uaworld["unit1_no"])
    assert client.patch(
        f"/unit-access-request/{req['id']}", headers=resident, json={"durum": "onaylandi"}
    ).status_code == 200
    assert client.patch(
        f"/unit-access-request/{req['id']}", headers=resident, json={"durum": "reddedildi"}
    ).status_code == 409


def test_karar_push_yoneticiye(client, uaworld):
    yonetici = _headers(client, uaworld["slug_a"], uaworld["yonetici_a"])
    resident = _headers(client, uaworld["slug_a"], uaworld["resident_a"])
    tag = uuid.uuid4().hex[:6]
    assert client.post(
        "/devices", headers=yonetici, json={"fcm_token": f"YON-{tag}", "platform": "android"}
    ).status_code in (200, 201)
    req = _open_request(client, yonetici, uaworld["unit1_no"])
    client.patch(
        f"/unit-access-request/{req['id']}", headers=resident, json={"durum": "onaylandi"}
    )

    # yoneticinin user id'sini /me ile al, token cozulur mu?
    yon_id = client.get("/me", headers=yonetici).json()["id"]
    from app.scheduler.notify import _fetch_device_tokens_for_users

    toks = set(_fetch_device_tokens_for_users(uaworld["a"], [yon_id]))
    assert f"YON-{tag}" in toks


# --------------------- one-shot izin akisi (visitor) ------------------------ #
def test_onay_sonrasi_yonetici_gorur_sonra_tukenir(client, uaworld):
    """Onaydan sonra yonetici o dairenin ziyaretcilerini bir kez gorur (izin
    TUKETILIR); ikinci okuma 403 (one-shot)."""
    guard = _headers(client, uaworld["slug_a"], uaworld["guard_a"])
    yonetici = _headers(client, uaworld["slug_a"], uaworld["yonetici_a"])
    resident = _headers(client, uaworld["slug_a"], uaworld["resident_a"])
    v = _register_visitor(client, guard, uaworld["resident_a_id"], uaworld["unit1_no"])

    # izin ONCESI: 403
    assert client.get(
        "/visitors", headers=yonetici, params={"unit_id": uaworld["unit1"]}
    ).status_code == 403

    req = _open_request(client, yonetici, uaworld["unit1_no"])
    assert client.patch(
        f"/unit-access-request/{req['id']}", headers=resident, json={"durum": "onaylandi"}
    ).status_code == 200

    # ILK okuma: 200 + o dairenin ziyaretcisi gorunur
    r1 = client.get("/visitors", headers=yonetici, params={"unit_id": uaworld["unit1"]})
    assert r1.status_code == 200, r1.text
    assert any(it["id"] == v["id"] for it in r1.json()["items"])

    # IKINCI okuma: izin tukendi -> 403
    assert client.get(
        "/visitors", headers=yonetici, params={"unit_id": uaworld["unit1"]}
    ).status_code == 403


def test_onay_sonrasi_yonetici_kargo_gorur_sonra_tukenir(client, uaworld):
    """Ayni izin mekanizmasi kargo icin de calisir (one-shot)."""
    guard = _headers(client, uaworld["slug_a"], uaworld["guard_a"])
    yonetici = _headers(client, uaworld["slug_a"], uaworld["yonetici_a"])
    resident = _headers(client, uaworld["slug_a"], uaworld["resident_a"])
    k = client.post(
        "/kargo", headers=guard,
        json={"firma": "Yurtici", "unit_no": uaworld["unit1_no"]},
    ).json()

    req = _open_request(client, yonetici, uaworld["unit1_no"])
    client.patch(
        f"/unit-access-request/{req['id']}", headers=resident, json={"durum": "onaylandi"}
    )
    r1 = client.get("/kargo", headers=yonetici, params={"unit_id": uaworld["unit1"]})
    assert r1.status_code == 200
    assert any(it["id"] == k["id"] for it in r1.json()["items"])
    assert client.get(
        "/kargo", headers=yonetici, params={"unit_id": uaworld["unit1"]}
    ).status_code == 403


def test_admin_da_izinle_gorur_sonra_tukenir(client, uaworld):
    """admin da (yonetici gibi) varsayilan KAPALI; talep+onay sonrasi bir kez
    gorur, sonra tukenir (uniform gizlilik modeli)."""
    guard = _headers(client, uaworld["slug_a"], uaworld["guard_a"])
    admin = _headers(client, uaworld["slug_a"], uaworld["admin_a"])
    resident = _headers(client, uaworld["slug_a"], uaworld["resident_a"])
    v = _register_visitor(client, guard, uaworld["resident_a_id"], uaworld["unit1_no"])

    # izin ONCESI: admin 403
    assert client.get(
        "/visitors", headers=admin, params={"unit_id": uaworld["unit1"]}
    ).status_code == 403

    req = _open_request(client, admin, uaworld["unit1_no"])
    assert client.patch(
        f"/unit-access-request/{req['id']}", headers=resident, json={"durum": "onaylandi"}
    ).status_code == 200

    r1 = client.get("/visitors", headers=admin, params={"unit_id": uaworld["unit1"]})
    assert r1.status_code == 200
    assert any(it["id"] == v["id"] for it in r1.json()["items"])
    # tukendi -> 403
    assert client.get(
        "/visitors", headers=admin, params={"unit_id": uaworld["unit1"]}
    ).status_code == 403


def test_red_sonrasi_yonetici_goremez(client, uaworld):
    yonetici = _headers(client, uaworld["slug_a"], uaworld["yonetici_a"])
    resident = _headers(client, uaworld["slug_a"], uaworld["resident_a"])
    req = _open_request(client, yonetici, uaworld["unit1_no"])
    assert client.patch(
        f"/unit-access-request/{req['id']}", headers=resident, json={"durum": "reddedildi"}
    ).status_code == 200
    assert client.get(
        "/visitors", headers=yonetici, params={"unit_id": uaworld["unit1"]}
    ).status_code == 403


def test_izin_daireye_ozel(client, uaworld):
    """unit1 izni unit2'yi acmaz — izin daire kapsamli."""
    guard = _headers(client, uaworld["slug_a"], uaworld["guard_a"])
    yonetici = _headers(client, uaworld["slug_a"], uaworld["yonetici_a"])
    resident = _headers(client, uaworld["slug_a"], uaworld["resident_a"])
    _register_visitor(client, guard, uaworld["diger_id"], uaworld["unit2_no"])

    req = _open_request(client, yonetici, uaworld["unit1_no"])
    client.patch(
        f"/unit-access-request/{req['id']}", headers=resident, json={"durum": "onaylandi"}
    )
    # unit2 icin izin yok -> 403
    assert client.get(
        "/visitors", headers=yonetici, params={"unit_id": uaworld["unit2"]}
    ).status_code == 403


# ------------------------------- okuma/izolasyon ---------------------------- #
def test_liste_kapsami(client, uaworld):
    """yonetici kendi taleplerini; resident kendi dairesine geleni gorur."""
    yonetici = _headers(client, uaworld["slug_a"], uaworld["yonetici_a"])
    resident = _headers(client, uaworld["slug_a"], uaworld["resident_a"])
    req = _open_request(client, yonetici, uaworld["unit1_no"])

    yon_ids = [it["id"] for it in client.get(
        "/unit-access-request", headers=yonetici, params={"limit": 200}
    ).json()["items"]]
    assert req["id"] in yon_ids
    res_ids = [it["id"] for it in client.get(
        "/unit-access-request", headers=resident, params={"limit": 200}
    ).json()["items"]]
    assert req["id"] in res_ids
    # baska dairenin sakini gormez
    diger = _headers(client, uaworld["slug_a"], uaworld["diger"])
    diger_ids = [it["id"] for it in client.get(
        "/unit-access-request", headers=diger, params={"limit": 200}
    ).json()["items"]]
    assert req["id"] not in diger_ids


def test_tenant_izolasyonu(client, uaworld):
    """B yoneticisi A'nin dairesi icin talep acamaz (daire B'de yok -> 422);
    A'nin talebini B goremez (RLS)."""
    yonetici_a = _headers(client, uaworld["slug_a"], uaworld["yonetici_a"])
    req = _open_request(client, yonetici_a, uaworld["unit1_no"])

    yonetici_b = _headers(client, uaworld["slug_b"], uaworld["yonetici_b"])
    assert client.post(
        "/unit-access-request", headers=yonetici_b, json={"unit_no": uaworld["unit1_no"]}
    ).status_code == 422  # daire B tenant'inda yok
    b_ids = [it["id"] for it in client.get(
        "/unit-access-request", headers=yonetici_b, params={"limit": 200}
    ).json()["items"]]
    assert req["id"] not in b_ids


# ------------------------------ toplu talep (bulk) -------------------------- #
def test_bulk_sakinli_tum_daireler_icin_bekleyen_olusur(client, uaworld):
    """Toplu talep: sakini olan TUM daireler (unit1 + unit2) icin bekleyen
    talep olusur. RBAC: admin VEYA yonetici; security/gorevli/resident 403."""
    # RBAC kapisi
    for role in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, uaworld["slug_a"], uaworld[role])
        assert client.post(
            "/unit-access-request/bulk", headers=h
        ).status_code == 403, role

    yonetici = _headers(client, uaworld["slug_a"], uaworld["yonetici_a"])
    res = _bulk(client, yonetici)
    assert res["created"] == 2 and res["skipped"] == 0
    unit_ids = {it["unit_id"] for it in res["items"]}
    assert unit_ids == {uaworld["unit1"], uaworld["unit2"]}
    assert all(it["durum"] == "bekliyor" and it["used"] is False for it in res["items"])


def test_bulk_admin_da_yapar(client, uaworld):
    admin = _headers(client, uaworld["slug_a"], uaworld["admin_a"])
    res = _bulk(client, admin)
    assert res["created"] == 2
    assert {it["unit_id"] for it in res["items"]} == {uaworld["unit1"], uaworld["unit2"]}


def test_bulk_zaten_acik_veya_onayli_daireyi_atlar(client, uaworld):
    """Mukerrer bildirim spam'i olmasin: talebi acanin zaten acik (bekleyen)
    talebi olan daire ATLANIR."""
    yonetici = _headers(client, uaworld["slug_a"], uaworld["yonetici_a"])
    # unit1 icin tek-daire talep zaten acik
    _open_request(client, yonetici, uaworld["unit1_no"])
    res = _bulk(client, yonetici)
    assert res["created"] == 1 and res["skipped"] == 1
    assert {it["unit_id"] for it in res["items"]} == {uaworld["unit2"]}


def test_bulk_per_daire_riza_baypas_edilmez(client, uaworld):
    """KRITIK gizlilik: toplu talep hicbir onayi baypas ETMEZ. yonetici yalniz
    ONAYLAYAN dairenin (unit1) ziyaretcilerini gorur; onaylanmayan daire
    (unit2, bekliyor) icin hala 403."""
    guard = _headers(client, uaworld["slug_a"], uaworld["guard_a"])
    yonetici = _headers(client, uaworld["slug_a"], uaworld["yonetici_a"])
    resident = _headers(client, uaworld["slug_a"], uaworld["resident_a"])
    v1 = _register_visitor(client, guard, uaworld["resident_a_id"], uaworld["unit1_no"])

    res = _bulk(client, yonetici)
    # unit1 talebini bul + resident_a onaylar (unit2 bekliyor kalir)
    req_unit1 = next(it for it in res["items"] if it["unit_id"] == uaworld["unit1"])
    assert client.patch(
        f"/unit-access-request/{req_unit1['id']}", headers=resident,
        json={"durum": "onaylandi"},
    ).status_code == 200

    # unit1: onaylandi -> gorunur (bir kez)
    r1 = client.get("/visitors", headers=yonetici, params={"unit_id": uaworld["unit1"]})
    assert r1.status_code == 200
    assert any(it["id"] == v1["id"] for it in r1.json()["items"])
    # unit2: bekliyor (baypas YOK) -> 403
    assert client.get(
        "/visitors", headers=yonetici, params={"unit_id": uaworld["unit2"]}
    ).status_code == 403


def test_granted_units_yalniz_onayli_kullanilmamis(client, uaworld):
    """granted-units: talebi acanin SU AN goruntuleyebilecegi (onaylandi +
    kullanilmamis) daireler. Bekleyen daire listede yok; tuketilince duser.
    RBAC: resident 403 (talep eden gorunumu)."""
    guard = _headers(client, uaworld["slug_a"], uaworld["guard_a"])
    yonetici = _headers(client, uaworld["slug_a"], uaworld["yonetici_a"])
    resident = _headers(client, uaworld["slug_a"], uaworld["resident_a"])
    _register_visitor(client, guard, uaworld["resident_a_id"], uaworld["unit1_no"])

    res = _bulk(client, yonetici)
    req_unit1 = next(it for it in res["items"] if it["unit_id"] == uaworld["unit1"])
    client.patch(
        f"/unit-access-request/{req_unit1['id']}", headers=resident,
        json={"durum": "onaylandi"},
    )

    # onayli + kullanilmamis: yalniz unit1
    g = client.get("/unit-access-request/granted-units", headers=yonetici)
    assert g.status_code == 200
    granted_units = {it["unit_id"] for it in g.json()["items"]}
    assert granted_units == {uaworld["unit1"]}

    # tuketince (ILK okuma) listeden duser
    assert client.get(
        "/visitors", headers=yonetici, params={"unit_id": uaworld["unit1"]}
    ).status_code == 200
    g2 = client.get("/unit-access-request/granted-units", headers=yonetici).json()
    assert uaworld["unit1"] not in {it["unit_id"] for it in g2["items"]}

    # RBAC: resident granted-units GORMEZ (talep eden gorunumu)
    assert client.get(
        "/unit-access-request/granted-units", headers=resident
    ).status_code == 403
