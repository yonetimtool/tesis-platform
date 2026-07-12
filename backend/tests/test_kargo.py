"""Kargo/paket takibi: kayit(+foto) + push hedefleri + teslim + RBAC + izolasyon.

RBAC (auth.md §4, visitor deseni): KAYIT yalniz security; TESLIM yalniz O
dairenin AKTIF sakini (baska daire 404; ikinci isaret 409 — teslim alan
degismez); OKUMA admin+security TUM gecmis, resident yalniz KENDI daireleri
(es dahil — kargo unit-bazli); yonetici VARSAYILAN KAPALI (403 — tek-seferlik
izinle acilir, bkz. test_unit_access); tesis_gorevlisi 403. Foto mevcut presign
akisiyla (roundtrip + IDOR korumasi). Tenant izolasyonu RLS ile.
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


def _register_kargo(client, headers, **over):
    body = {"firma": f"Firma {uuid.uuid4().hex[:6]}"}
    body.update(over)
    r = client.post("/kargo", headers=headers, json=body)
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
def kworld(client, world, owner_conn):
    """world + daireler ve sakin baglantilari (test_visitors ile ayni desen):

    * unit1 (K-101): resident_a + es (resident_es) — AYNI dairede iki sakin.
    * unit2 (K-202): resident_diger — BASKA dairenin sakini.
    """
    a = world["a"]
    suffix = uuid.uuid4().hex[:6]
    pw = "KargoPass1!"
    es_email = f"kes-{suffix}@acme.com"
    diger_email = f"kdiger-{suffix}@acme.com"

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND email=%s AND role='resident'",
            (a, world["resident_a"]["email"]),
        )
        resident_a_id = cur.fetchone()[0]
    es_id = _mk_resident(owner_conn, a, es_email, pw)
    diger_id = _mk_resident(owner_conn, a, diger_email, pw)
    # B tenant guvenligi: cross-tenant okuma izolasyonu (admin+yonetici artik
    # varsayilan kapali; security okuyabilen tek rol).
    guard_b_email = f"kguardb-{suffix}@acme.com"
    _mk_security(owner_conn, world["b"], guard_b_email, pw)

    unit1 = _mk_unit(owner_conn, a, f"K-101-{suffix}")
    unit2 = _mk_unit(owner_conn, a, f"K-202-{suffix}")
    _link(owner_conn, a, unit1, resident_a_id)
    _link(owner_conn, a, unit1, es_id)
    _link(owner_conn, a, unit2, diger_id)

    return {
        **world,
        "unit1": str(unit1),
        "unit1_no": f"K-101-{suffix}",
        "unit2": str(unit2),
        "unit2_no": f"K-202-{suffix}",
        "resident_a_id": str(resident_a_id),
        "es_id": str(es_id),
        "es": {"email": es_email, "password": pw},
        "diger": {"email": diger_email, "password": pw},
        "guard_b": {"email": guard_b_email, "password": pw},
    }
    # temizlik world fixture'inda: tenant silinince CASCADE.


# ------------------------------- kayit -------------------------------------- #
def test_guvenlik_unit_no_ile_kaydeder_bekliyor(client, kworld):
    guard = _headers(client, kworld["slug_a"], kworld["guard_a"])
    k = _register_kargo(
        client, guard,
        firma="Aras Kargo", unit_no=kworld["unit1_no"], notlar="Orta boy koli",
    )
    assert k["durum"] == "bekliyor"
    assert k["unit_id"] == kworld["unit1"]
    assert k["unit_no"] == kworld["unit1_no"]
    assert k["firma"] == "Aras Kargo"
    assert k["kaydeden_ad"] == "Guard A"
    assert k["notlar"] == "Orta boy koli"
    assert k["foto_key"] is None and k["foto_url"] is None
    assert k["teslim_alan_user_id"] is None and k["teslim_zamani"] is None


def test_guvenlik_unit_id_ile_de_kaydeder(client, kworld):
    guard = _headers(client, kworld["slug_a"], kworld["guard_a"])
    k = _register_kargo(client, guard, unit_id=kworld["unit1"])
    assert k["durum"] == "bekliyor" and k["unit_id"] == kworld["unit1"]


def test_kayit_dogrulama(client, kworld):
    guard = _headers(client, kworld["slug_a"], kworld["guard_a"])
    # daire referansi: ikisi birden / hicbiri -> 422
    for body in (
        {"firma": "X"},
        {"firma": "X", "unit_id": kworld["unit1"], "unit_no": kworld["unit1_no"]},
    ):
        assert client.post("/kargo", headers=guard, json=body).status_code == 422, body
    # olmayan daire -> 422 invalid_reference
    r = client.post(
        "/kargo", headers=guard, json={"firma": "X", "unit_no": "YOK-999"}
    )
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "invalid_reference"
    # bos firma -> 422
    assert client.post(
        "/kargo", headers=guard,
        json={"firma": "", "unit_no": kworld["unit1_no"]},
    ).status_code == 422


def test_kayit_rbac_yalniz_guvenlik(client, kworld):
    """Kesin kural: kayit KAPI operasyonu — admin/yonetici/gorevli/sakin 403."""
    for role in ("admin_a", "yonetici_a", "gorevli_a", "resident_a"):
        h = _headers(client, kworld["slug_a"], kworld[role])
        assert client.post(
            "/kargo", headers=h,
            json={"firma": "X", "unit_no": kworld["unit1_no"]},
        ).status_code == 403, role


# -------------------------------- foto -------------------------------------- #
def test_fotolu_kayit_ve_okumada_foto_url(client, kworld):
    """MEVCUT presign akisi: guard presign -> foto_key ile kayit -> okumada
    foto_url (presigned GET) doner; sakin de kendi dairesinin paket fotosunu gorur."""
    guard = _headers(client, kworld["slug_a"], kworld["guard_a"])
    pre = client.post(
        "/uploads/presign", headers=guard, json={"content_type": "image/jpeg"}
    )
    assert pre.status_code == 200, pre.text
    foto_key = pre.json()["foto_key"]

    k = _register_kargo(
        client, guard, unit_no=kworld["unit1_no"], foto_key=foto_key
    )
    assert k["foto_key"] == foto_key
    assert k["foto_url"] and "X-Amz-Signature" in k["foto_url"]

    resident = _headers(client, kworld["slug_a"], kworld["resident_a"])
    d = client.get(f"/kargo/{k['id']}", headers=resident)
    assert d.status_code == 200 and "X-Amz-Signature" in d.json()["foto_url"]


def test_foto_key_tenant_namespace_disina_cikamaz(client, kworld):
    """Complaints'teki IDOR korumasinin aynisi: yabanci/serbest anahtar 422."""
    guard = _headers(client, kworld["slug_a"], kworld["guard_a"])
    for foto_key in (f"{kworld['b']}/tasks/victim.jpg", "serbest/anahtar.jpg"):
        r = client.post(
            "/kargo", headers=guard,
            json={"firma": "X", "unit_no": kworld["unit1_no"], "foto_key": foto_key},
        )
        assert r.status_code == 422, foto_key


# -------------------------------- push -------------------------------------- #
def test_kayit_push_tum_daire_sakinlerine_denenir(client, kworld):
    """Dairenin TUM aktif sakinlerinin cihaz token'lari push hedefidir
    (esler dahil) — visitor ile ayni hedef secimi (RLS-safe)."""
    resident1 = _headers(client, kworld["slug_a"], kworld["resident_a"])
    es = _headers(client, kworld["slug_a"], kworld["es"])
    tag = uuid.uuid4().hex[:6]
    for h, tok in ((resident1, f"KRES1-{tag}"), (es, f"KES-{tag}")):
        assert client.post(
            "/devices", headers=h, json={"fcm_token": tok, "platform": "android"}
        ).status_code in (200, 201)

    guard = _headers(client, kworld["slug_a"], kworld["guard_a"])
    _register_kargo(client, guard, unit_no=kworld["unit1_no"])  # push denenir (noop)

    from app.scheduler.notify import _fetch_device_tokens_for_users

    toks = set(
        _fetch_device_tokens_for_users(
            kworld["a"], [kworld["resident_a_id"], kworld["es_id"]]
        )
    )
    assert {f"KRES1-{tag}", f"KES-{tag}"} <= toks


# ------------------------------- teslim ------------------------------------- #
def test_sakin_teslim_alir_alan_ve_zaman_damgalanir(client, kworld):
    guard = _headers(client, kworld["slug_a"], kworld["guard_a"])
    k = _register_kargo(client, guard, unit_no=kworld["unit1_no"])

    resident = _headers(client, kworld["slug_a"], kworld["resident_a"])
    p = client.patch(
        f"/kargo/{k['id']}", headers=resident, json={"durum": "teslim_alindi"}
    )
    assert p.status_code == 200, p.text
    body = p.json()
    assert body["durum"] == "teslim_alindi"
    assert body["teslim_alan_user_id"] == kworld["resident_a_id"]
    assert body["teslim_alan_ad"] == "Resident A"
    assert body["teslim_zamani"] is not None

    # guvenlik ekraninda guncel durum gorunur
    d = client.get(f"/kargo/{k['id']}", headers=guard).json()
    assert d["durum"] == "teslim_alindi" and d["teslim_alan_ad"] == "Resident A"


def test_cifte_teslim_409_alan_degismez(client, kworld):
    """Ayni dairenin IKI sakini: ilk isaret gecerli, ikincisi 409; teslim
    alan DEGISMEZ (atomik durum='bekliyor' kosulu)."""
    guard = _headers(client, kworld["slug_a"], kworld["guard_a"])
    k = _register_kargo(client, guard, unit_no=kworld["unit1_no"])

    resident = _headers(client, kworld["slug_a"], kworld["resident_a"])
    es = _headers(client, kworld["slug_a"], kworld["es"])
    assert client.patch(
        f"/kargo/{k['id']}", headers=resident, json={"durum": "teslim_alindi"}
    ).status_code == 200
    assert client.patch(
        f"/kargo/{k['id']}", headers=es, json={"durum": "teslim_alindi"}
    ).status_code == 409
    # ayni sakin tekrar da isaretleyemez
    assert client.patch(
        f"/kargo/{k['id']}", headers=resident, json={"durum": "teslim_alindi"}
    ).status_code == 409
    d = client.get(f"/kargo/{k['id']}", headers=guard).json()
    assert d["teslim_alan_user_id"] == kworld["resident_a_id"]


def test_baska_dairenin_sakini_teslim_alamaz_404(client, kworld):
    """Kesin kural: BASKA dairenin sakini 404 (varlik sizdirilmaz, bypass yok)."""
    guard = _headers(client, kworld["slug_a"], kworld["guard_a"])
    k = _register_kargo(client, guard, unit_no=kworld["unit1_no"])
    diger = _headers(client, kworld["slug_a"], kworld["diger"])
    assert client.patch(
        f"/kargo/{k['id']}", headers=diger, json={"durum": "teslim_alindi"}
    ).status_code == 404
    # kayit degismedi
    assert client.get(f"/kargo/{k['id']}", headers=guard).json()["durum"] == "bekliyor"


def test_teslim_rbac_personel_isaretleyemez(client, kworld):
    """Teslim yetkisi daire sakininde: guvenlik/gorevli/yonetici/admin PATCH 403."""
    guard = _headers(client, kworld["slug_a"], kworld["guard_a"])
    k = _register_kargo(client, guard, unit_no=kworld["unit1_no"])
    for role in ("guard_a", "gorevli_a", "yonetici_a", "admin_a"):
        h = _headers(client, kworld["slug_a"], kworld[role])
        assert client.patch(
            f"/kargo/{k['id']}", headers=h, json={"durum": "teslim_alindi"}
        ).status_code == 403, role


def test_teslim_dogrulama(client, kworld):
    guard = _headers(client, kworld["slug_a"], kworld["guard_a"])
    k = _register_kargo(client, guard, unit_no=kworld["unit1_no"])
    resident = _headers(client, kworld["slug_a"], kworld["resident_a"])
    # 'bekliyor'a geri donus / bilinmeyen durum / bos govde -> 422
    for body in ({"durum": "bekliyor"}, {"durum": "kayip"}, {}):
        assert client.patch(
            f"/kargo/{k['id']}", headers=resident, json=body
        ).status_code == 422, body


# ------------------------------- okuma -------------------------------------- #
def test_sakin_yalniz_kendi_dairesinin_paketlerini_gorur(client, kworld):
    guard = _headers(client, kworld["slug_a"], kworld["guard_a"])
    k1 = _register_kargo(client, guard, unit_no=kworld["unit1_no"])
    k2 = _register_kargo(client, guard, unit_no=kworld["unit2_no"])

    resident = _headers(client, kworld["slug_a"], kworld["resident_a"])
    ids = [it["id"] for it in client.get(
        "/kargo", headers=resident, params={"limit": 200}
    ).json()["items"]]
    assert k1["id"] in ids and k2["id"] not in ids
    # es de ayni dairenin paketini gorur (coklu sakin)
    es = _headers(client, kworld["slug_a"], kworld["es"])
    es_ids = [it["id"] for it in client.get(
        "/kargo", headers=es, params={"limit": 200}
    ).json()["items"]]
    assert k1["id"] in es_ids
    # detay: baska dairenin paketi 404 (varlik sizdirilmaz)
    assert client.get(f"/kargo/{k2['id']}", headers=resident).status_code == 404
    assert client.get(f"/kargo/{k1['id']}", headers=resident).status_code == 200


def test_guvenlik_tum_gecmisi_gorur_yonetim_403(client, kworld):
    """A (KVKK): YALNIZ guvenlik (kapi ops) TUM gecmisi gorur; YONETICI VE
    ADMIN VARSAYILAN KAPALI -> 403 (ziyaretci ile ayni gizlilik)."""
    guard = _headers(client, kworld["slug_a"], kworld["guard_a"])
    k1 = _register_kargo(client, guard, unit_no=kworld["unit1_no"])
    k2 = _register_kargo(client, guard, unit_no=kworld["unit2_no"])
    ids = [it["id"] for it in client.get(
        "/kargo", headers=guard, params={"limit": 200}
    ).json()["items"]]
    assert k1["id"] in ids and k2["id"] in ids
    assert client.get(f"/kargo/{k1['id']}", headers=guard).status_code == 200
    # yonetici VE admin: izinsiz 403 (liste + unit_id'li liste + detay)
    for role in ("yonetici_a", "admin_a"):
        h = _headers(client, kworld["slug_a"], kworld[role])
        assert client.get(
            "/kargo", headers=h, params={"limit": 200}
        ).status_code == 403, role
        assert client.get(
            "/kargo", headers=h, params={"unit_id": kworld["unit1"]}
        ).status_code == 403, role
        assert client.get(f"/kargo/{k1['id']}", headers=h).status_code == 403, role


def test_okuma_rbac_gorevli_403(client, kworld):
    guard = _headers(client, kworld["slug_a"], kworld["guard_a"])
    k = _register_kargo(client, guard, unit_no=kworld["unit1_no"])
    gorevli = _headers(client, kworld["slug_a"], kworld["gorevli_a"])
    assert client.get("/kargo", headers=gorevli).status_code == 403
    assert client.get(f"/kargo/{k['id']}", headers=gorevli).status_code == 403


def test_liste_filtre_ve_sira(client, kworld):
    guard = _headers(client, kworld["slug_a"], kworld["guard_a"])
    resident = _headers(client, kworld["slug_a"], kworld["resident_a"])
    a = _register_kargo(client, guard, unit_no=kworld["unit1_no"])
    b = _register_kargo(client, guard, unit_no=kworld["unit2_no"])
    client.patch(f"/kargo/{a['id']}", headers=resident, json={"durum": "teslim_alindi"})

    # durum filtresi
    bekleyen = client.get(
        "/kargo", headers=guard, params={"durum": "bekliyor", "limit": 200}
    ).json()["items"]
    assert all(it["durum"] == "bekliyor" for it in bekleyen)
    assert any(it["id"] == b["id"] for it in bekleyen)
    assert not any(it["id"] == a["id"] for it in bekleyen)
    # daire filtresi
    unit1_kayitlari = client.get(
        "/kargo", headers=guard, params={"unit_id": kworld["unit1"], "limit": 200}
    ).json()["items"]
    assert all(it["unit_id"] == kworld["unit1"] for it in unit1_kayitlari)
    # gecersiz durum -> 422
    assert client.get(
        "/kargo", headers=guard, params={"durum": "olmayan"}
    ).status_code == 422
    # created_at DESC: b daha yeni -> once gelir
    hepsi = client.get("/kargo", headers=guard, params={"limit": 200}).json()
    ids = [it["id"] for it in hepsi["items"]]
    assert ids.index(b["id"]) < ids.index(a["id"])
    assert hepsi["meta"]["total"] >= 2
    # tarih filtresi: bitis cok eski -> ikisi de duser
    eski = client.get(
        "/kargo", headers=guard,
        params={"bitis": "2000-01-01T00:00:00Z", "limit": 200},
    ).json()["items"]
    assert not any(it["id"] in (a["id"], b["id"]) for it in eski)


# ----------------------------- tenant izolasyonu ---------------------------- #
def test_tenant_izolasyonu(client, kworld):
    guard = _headers(client, kworld["slug_a"], kworld["guard_a"])
    k = _register_kargo(client, guard, unit_no=kworld["unit1_no"])

    # Okuma icin guard_b (admin+yonetici artik varsayilan kapali — izolasyonu
    # gosteremez). RLS: B guvenligi A'nin kaydini goremez.
    guard_b = _headers(client, kworld["slug_b"], kworld["guard_b"])
    b_ids = [it["id"] for it in client.get(
        "/kargo", headers=guard_b, params={"limit": 200}
    ).json()["items"]]
    assert k["id"] not in b_ids
    assert client.get(f"/kargo/{k['id']}", headers=guard_b).status_code == 404
    yonetici_b = _headers(client, kworld["slug_b"], kworld["yonetici_b"])
    assert client.patch(
        f"/kargo/{k['id']}", headers=yonetici_b, json={"durum": "teslim_alindi"}
    ).status_code == 403  # rol zaten yetkisiz; kayit da B'den gorunmez


def test_pasif_sakin_baglantisi_teslim_alamaz(client, kworld, owner_conn):
    """Daireden cikarilmis (bitis dolu) sakin TESLIM ALAMAZ ve paketleri GOREMEZ."""
    guard = _headers(client, kworld["slug_a"], kworld["guard_a"])
    k = _register_kargo(client, guard, unit_no=kworld["unit1_no"])

    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE unit_resident SET bitis = now() WHERE unit_id=%s AND user_id=%s",
            (kworld["unit1"], kworld["es_id"]),
        )
    es = _headers(client, kworld["slug_a"], kworld["es"])
    assert client.patch(
        f"/kargo/{k['id']}", headers=es, json={"durum": "teslim_alindi"}
    ).status_code == 404
    ids = [it["id"] for it in client.get(
        "/kargo", headers=es, params={"limit": 200}
    ).json()["items"]]
    assert k["id"] not in ids
