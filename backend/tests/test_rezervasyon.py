"""Ortak alan rezervasyonu: alan CRUD + talep + onay/red + CAKISMA ENGELI +
RBAC + izolasyon.

RBAC (auth.md §4): alan yonetimi admin+yonetici, alan okuma tum roller (aktif);
TALEP yalniz resident; KARAR yalniz admin+yonetici; OKUMA yonetim tumu,
resident kendi daireleri, saha rolleri 403.

CAKISMA (kesin mekanizma): DB partial EXCLUDE (btree_gist, tsrange &&,
WHERE durum='onaylandi') — iki cakisan onaydan yalniz biri basarir (23P01 ->
409); talep aninda onayli ile kesisen aralik da 409. Bitisik slot serbest.
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


def _mk_area(client, headers, **over):
    body = {"ad": f"Alan {uuid.uuid4().hex[:6]}"}
    body.update(over)
    r = client.post("/common-areas", headers=headers, json=body)
    assert r.status_code == 201, r.text
    return r.json()


def _request(client, headers, alan_id, *, tarih="2026-08-01",
             baslangic="10:00", bitis="12:00", expect=201, **over):
    body = {
        "alan_id": alan_id, "tarih": tarih, "baslangic": baslangic,
        "bitis": bitis, "kisi_sayisi": 2,
    }
    body.update(over)
    r = client.post("/reservations", headers=headers, json=body)
    assert r.status_code == expect, r.text
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


@pytest.fixture
def rworld(client, world, owner_conn):
    """world + daireler/sakinler + iki ortak alan (yonetici uzerinden API ile):

    * unit1 (R-101): resident_a + es (ayni dairede iki sakin).
    * unit2 (R-202): resident_diger.
    * alan1 (Havuz-benzeri), alan2 (Toplanti-benzeri) — tenant A.
    """
    a = world["a"]
    suffix = uuid.uuid4().hex[:6]
    pw = "RezPass1!"
    es_email = f"res-{suffix}@acme.com"
    diger_email = f"rdiger-{suffix}@acme.com"

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND email=%s AND role='resident'",
            (a, world["resident_a"]["email"]),
        )
        resident_a_id = cur.fetchone()[0]
    es_id = _mk_resident(owner_conn, a, es_email, pw)
    diger_id = _mk_resident(owner_conn, a, diger_email, pw)

    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO unit (tenant_id, no) VALUES (%s,%s) RETURNING id",
            (a, f"R-101-{suffix}"),
        )
        unit1 = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO unit (tenant_id, no) VALUES (%s,%s) RETURNING id",
            (a, f"R-202-{suffix}"),
        )
        unit2 = cur.fetchone()[0]
        for uid, unit in ((resident_a_id, unit1), (es_id, unit1), (diger_id, unit2)):
            cur.execute(
                "INSERT INTO unit_resident (tenant_id, unit_id, user_id) "
                "VALUES (%s,%s,%s)",
                (a, unit, uid),
            )

    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    alan1 = _mk_area(client, yonetici, ad=f"Havuz-{suffix}")
    alan2 = _mk_area(client, yonetici, ad=f"Toplanti-{suffix}")

    return {
        **world,
        "unit1": str(unit1),
        "unit1_no": f"R-101-{suffix}",
        "unit2": str(unit2),
        "resident_a_id": str(resident_a_id),
        "es": {"email": es_email, "password": pw},
        "diger": {"email": diger_email, "password": pw},
        "alan1": alan1["id"],
        "alan2": alan2["id"],
    }
    # temizlik world fixture'inda: tenant silinince CASCADE.


# ------------------------------ ortak alan ---------------------------------- #
def test_alan_crud_ve_rbac(client, rworld):
    yonetici = _headers(client, rworld["slug_a"], rworld["yonetici_a"])
    admin = _headers(client, rworld["slug_a"], rworld["admin_a"])
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    guard = _headers(client, rworld["slug_a"], rworld["guard_a"])

    alan = _mk_area(client, yonetici, ad=f"Teras-{uuid.uuid4().hex[:6]}",
                    aciklama="Cati terasi")
    assert alan["aktif"] is True and alan["aciklama"] == "Cati terasi"
    # ayni adla ikinci alan 409
    assert client.post(
        "/common-areas", headers=admin, json={"ad": alan["ad"]}
    ).status_code == 409
    # sakin/saha alan ACAMAZ
    for h in (resident, guard):
        assert client.post(
            "/common-areas", headers=h, json={"ad": "X"}
        ).status_code == 403
    # sakin/saha aktif alanlari OKUR
    for h in (resident, guard):
        ids = [it["id"] for it in client.get(
            "/common-areas", headers=h, params={"limit": 200}
        ).json()["items"]]
        assert alan["id"] in ids

    # pasiflestir (soft-delete): yonetim gorur, sakin GORMEZ
    p = client.patch(
        f"/common-areas/{alan['id']}", headers=yonetici, json={"aktif": False}
    )
    assert p.status_code == 200 and p.json()["aktif"] is False
    y_ids = [it["id"] for it in client.get(
        "/common-areas", headers=yonetici, params={"limit": 200}
    ).json()["items"]]
    assert alan["id"] in y_ids
    r_ids = [it["id"] for it in client.get(
        "/common-areas", headers=resident, params={"limit": 200}
    ).json()["items"]]
    assert alan["id"] not in r_ids
    # sakin pasif alana talep acamaz (422)
    _request(client, resident, alan["id"], expect=422)
    # bos govde PATCH 422
    assert client.patch(
        f"/common-areas/{alan['id']}", headers=yonetici, json={}
    ).status_code == 422


# -------------------------------- talep ------------------------------------- #
def test_sakin_talep_acar_bekliyor(client, rworld):
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    r = _request(client, resident, rworld["alan1"], kisi_sayisi=4,
                 notlar="Aile yuzme saati")
    assert r["durum"] == "bekliyor"
    assert r["unit_id"] == rworld["unit1"]  # daire kimlikten turedi
    assert r["unit_no"] == rworld["unit1_no"]
    assert r["baslangic"] == "10:00" and r["bitis"] == "12:00"
    assert r["kisi_sayisi"] == 4 and r["notlar"] == "Aile yuzme saati"
    assert r["talep_eden_ad"] == "Resident A"
    assert r["onaylayan_user_id"] is None and r["karar_zamani"] is None


def test_talep_dogrulama(client, rworld):
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    # bitis <= baslangic -> 422
    _request(client, resident, rworld["alan1"],
             baslangic="12:00", bitis="12:00", expect=422)
    _request(client, resident, rworld["alan1"],
             baslangic="12:00", bitis="10:00", expect=422)
    # kisi_sayisi 0 -> 422
    _request(client, resident, rworld["alan1"], kisi_sayisi=0, expect=422)
    # olmayan alan -> 422
    _request(client, resident, str(uuid.uuid4()), expect=422)
    # baskasinin dairesi unit_id olarak verilemez -> 422
    _request(client, resident, rworld["alan1"], unit_id=rworld["unit2"],
             expect=422)


def test_talep_rbac_yalniz_sakin(client, rworld):
    for role in ("admin_a", "yonetici_a", "guard_a", "gorevli_a"):
        h = _headers(client, rworld["slug_a"], rworld[role])
        assert client.post(
            "/reservations", headers=h,
            json={"alan_id": rworld["alan1"], "tarih": "2026-08-01",
                  "baslangic": "10:00", "bitis": "12:00", "kisi_sayisi": 2},
        ).status_code == 403, role


# ------------------------------ onay / red ---------------------------------- #
def test_onay_ve_red_damgalanir(client, rworld):
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    yonetici = _headers(client, rworld["slug_a"], rworld["yonetici_a"])

    r1 = _request(client, resident, rworld["alan1"], baslangic="08:00", bitis="09:00")
    p = client.patch(
        f"/reservations/{r1['id']}", headers=yonetici, json={"durum": "onaylandi"}
    )
    assert p.status_code == 200, p.text
    body = p.json()
    assert body["durum"] == "onaylandi"
    assert body["onaylayan_ad"] == "Yonetici A"
    assert body["karar_zamani"] is not None

    r2 = _request(client, resident, rworld["alan1"], baslangic="09:00", bitis="09:30")
    p2 = client.patch(
        f"/reservations/{r2['id']}", headers=yonetici, json={"durum": "reddedildi"}
    )
    assert p2.status_code == 200 and p2.json()["durum"] == "reddedildi"

    # zaten karara baglanmis kayda ikinci karar 409
    assert client.patch(
        f"/reservations/{r1['id']}", headers=yonetici, json={"durum": "reddedildi"}
    ).status_code == 409
    # gecersiz karar degerleri 422
    for body_ in ({"durum": "bekliyor"}, {"durum": "belki"}, {}):
        assert client.patch(
            f"/reservations/{r2['id']}", headers=yonetici, json=body_
        ).status_code == 422, body_


def test_karar_rbac_yalniz_yonetim(client, rworld):
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    r = _request(client, resident, rworld["alan1"], baslangic="06:00", bitis="07:00")
    for role in ("resident_a", "guard_a", "gorevli_a"):
        h = _headers(client, rworld["slug_a"], rworld[role])
        assert client.patch(
            f"/reservations/{r['id']}", headers=h, json={"durum": "onaylandi"}
        ).status_code == 403, role
    admin = _headers(client, rworld["slug_a"], rworld["admin_a"])
    assert client.patch(
        f"/reservations/{r['id']}", headers=admin, json={"durum": "onaylandi"}
    ).status_code == 200  # admin de karar verebilir


# ------------------------------ CAKISMA ENGELI ------------------------------ #
def test_cakisan_iki_onaydan_yalniz_biri_basarir(client, rworld):
    """ANA GARANTI (yaris/atomiklik): ust uste binen IKI BEKLEYEN talep
    serbestce acilir; onaya kaldirmada DB EXCLUDE kisiti devreye girer —
    ikinci onay 409 alir ve kayit ONAYLANMAZ."""
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    diger = _headers(client, rworld["slug_a"], rworld["diger"])
    yonetici = _headers(client, rworld["slug_a"], rworld["yonetici_a"])

    # iki cakisan BEKLEYEN talep (10-12 ve 11-13) — ikisi de kabul edilir
    r1 = _request(client, resident, rworld["alan1"],
                  tarih="2026-08-02", baslangic="10:00", bitis="12:00")
    r2 = _request(client, diger, rworld["alan1"],
                  tarih="2026-08-02", baslangic="11:00", bitis="13:00")

    assert client.patch(
        f"/reservations/{r1['id']}", headers=yonetici, json={"durum": "onaylandi"}
    ).status_code == 200
    # cakisan ikinci onay DB kisitina takilir -> 409, durum degismez
    p2 = client.patch(
        f"/reservations/{r2['id']}", headers=yonetici, json={"durum": "onaylandi"}
    )
    assert p2.status_code == 409, p2.text
    d2 = client.get(f"/reservations/{r2['id']}", headers=yonetici).json()
    assert d2["durum"] == "bekliyor"  # onaylanmadi; reddedilebilir/beklemede
    # cakisan talep REDDEDILEBILIR (kisit yalniz onayli satirlara)
    assert client.patch(
        f"/reservations/{r2['id']}", headers=yonetici, json={"durum": "reddedildi"}
    ).status_code == 200


def test_talep_aninda_onayli_ile_cakisan_409(client, rworld):
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    yonetici = _headers(client, rworld["slug_a"], rworld["yonetici_a"])
    r1 = _request(client, resident, rworld["alan1"],
                  tarih="2026-08-03", baslangic="14:00", bitis="16:00")
    assert client.patch(
        f"/reservations/{r1['id']}", headers=yonetici, json={"durum": "onaylandi"}
    ).status_code == 200
    # onayli ile kesisen YENI talep aninda 409 (bosuna bekletilmez)
    _request(client, resident, rworld["alan1"],
             tarih="2026-08-03", baslangic="15:00", bitis="17:00", expect=409)
    # tam kapsayan aralik da 409
    _request(client, resident, rworld["alan1"],
             tarih="2026-08-03", baslangic="13:00", bitis="18:00", expect=409)


def test_cakismayan_bitisik_farkli_alan_farkli_gun_serbest(client, rworld):
    """Sinir durumlari: bitisik slot (bitis == baslangic), farkli alan ve
    farkli gun CAKISMA DEGILDIR — hepsi onaylanabilir."""
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    yonetici = _headers(client, rworld["slug_a"], rworld["yonetici_a"])

    r1 = _request(client, resident, rworld["alan1"],
                  tarih="2026-08-04", baslangic="10:00", bitis="12:00")
    bitisik = _request(client, resident, rworld["alan1"],
                       tarih="2026-08-04", baslangic="12:00", bitis="14:00")
    baska_alan = _request(client, resident, rworld["alan2"],
                          tarih="2026-08-04", baslangic="10:00", bitis="12:00")
    baska_gun = _request(client, resident, rworld["alan1"],
                         tarih="2026-08-05", baslangic="10:00", bitis="12:00")
    for r in (r1, bitisik, baska_alan, baska_gun):
        assert client.patch(
            f"/reservations/{r['id']}", headers=yonetici, json={"durum": "onaylandi"}
        ).status_code == 200, r["id"]


# ------------------------------- okuma -------------------------------------- #
def test_sakin_yalniz_kendi_dairesinin_rezervasyonlarini_gorur(client, rworld):
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    es = _headers(client, rworld["slug_a"], rworld["es"])
    diger = _headers(client, rworld["slug_a"], rworld["diger"])
    yonetici = _headers(client, rworld["slug_a"], rworld["yonetici_a"])

    mine = _request(client, resident, rworld["alan1"],
                    tarih="2026-08-06", baslangic="10:00", bitis="11:00")
    theirs = _request(client, diger, rworld["alan1"],
                      tarih="2026-08-06", baslangic="11:00", bitis="12:00")

    ids = [it["id"] for it in client.get(
        "/reservations", headers=resident, params={"limit": 200}
    ).json()["items"]]
    assert mine["id"] in ids and theirs["id"] not in ids
    # es AYNI dairenin talebini gorur (daire bazli kapsam)
    es_ids = [it["id"] for it in client.get(
        "/reservations", headers=es, params={"limit": 200}
    ).json()["items"]]
    assert mine["id"] in es_ids
    # detay: baska dairenin kaydi 404 (varlik sizdirilmaz)
    assert client.get(f"/reservations/{theirs['id']}", headers=resident).status_code == 404
    # yonetim ikisini de gorur
    y_ids = [it["id"] for it in client.get(
        "/reservations", headers=yonetici, params={"limit": 200}
    ).json()["items"]]
    assert mine["id"] in y_ids and theirs["id"] in y_ids


def test_okuma_rbac_saha_403(client, rworld):
    for role in ("guard_a", "gorevli_a"):
        h = _headers(client, rworld["slug_a"], rworld[role])
        assert client.get("/reservations", headers=h).status_code == 403, role


def test_liste_filtreleri(client, rworld):
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    yonetici = _headers(client, rworld["slug_a"], rworld["yonetici_a"])
    a = _request(client, resident, rworld["alan1"],
                 tarih="2026-08-07", baslangic="10:00", bitis="11:00")
    b = _request(client, resident, rworld["alan2"],
                 tarih="2026-08-08", baslangic="10:00", bitis="11:00")
    client.patch(f"/reservations/{a['id']}", headers=yonetici,
                 json={"durum": "onaylandi"})

    # durum filtresi
    onayli = client.get(
        "/reservations", headers=yonetici,
        params={"durum": "onaylandi", "limit": 200},
    ).json()["items"]
    assert any(it["id"] == a["id"] for it in onayli)
    assert not any(it["id"] == b["id"] for it in onayli)
    # alan + tarih filtresi (gun gorunumu)
    gun = client.get(
        "/reservations", headers=yonetici,
        params={"alan_id": rworld["alan2"], "tarih": "2026-08-08", "limit": 200},
    ).json()["items"]
    assert [it["id"] for it in gun] == [b["id"]]
    # gecersiz durum 422
    assert client.get(
        "/reservations", headers=yonetici, params={"durum": "olmayan"}
    ).status_code == 422


# ----------------------------- tenant izolasyonu ---------------------------- #
def test_tenant_izolasyonu(client, rworld):
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    r = _request(client, resident, rworld["alan1"],
                 tarih="2026-08-09", baslangic="10:00", bitis="11:00")

    yonetici_b = _headers(client, rworld["slug_b"], rworld["yonetici_b"])
    # B yonetimi A'nin rezervasyonunu goremez/karara baglayamaz (RLS -> 404)
    b_ids = [it["id"] for it in client.get(
        "/reservations", headers=yonetici_b, params={"limit": 200}
    ).json()["items"]]
    assert r["id"] not in b_ids
    assert client.get(f"/reservations/{r['id']}", headers=yonetici_b).status_code == 404
    assert client.patch(
        f"/reservations/{r['id']}", headers=yonetici_b, json={"durum": "onaylandi"}
    ).status_code == 404
    # B yonetimi A'nin alanini da goremez
    b_alan_ids = [it["id"] for it in client.get(
        "/common-areas", headers=yonetici_b, params={"limit": 200}
    ).json()["items"]]
    assert rworld["alan1"] not in b_alan_ids


# ------------------------------ musaitlik / slotlar ------------------------- #
def test_alan_musaitlik_create_ve_okuma(client, rworld):
    yonetici = _headers(client, rworld["slug_a"], rworld["yonetici_a"])
    alan = _mk_area(client, yonetici, ad=f"Salon-{uuid.uuid4().hex[:6]}",
                    acilis="10:00", kapanis="14:00", slot_dakika=60)
    assert alan["acilis"] == "10:00" and alan["kapanis"] == "14:00"
    assert alan["slot_dakika"] == 60
    # kapanis <= acilis -> 422
    assert client.post(
        "/common-areas", headers=yonetici,
        json={"ad": f"X-{uuid.uuid4().hex[:6]}", "acilis": "14:00", "kapanis": "10:00"},
    ).status_code == 422
    # saat verilmezse tum-gun varsayilan (00:00, 60 dk) — mevcut davranis korunur
    d = _mk_area(client, yonetici, ad=f"Def-{uuid.uuid4().hex[:6]}")
    assert d["acilis"] == "00:00" and d["slot_dakika"] == 60
    # kismi guncelleme: yalniz slot_dakika
    p = client.patch(f"/common-areas/{alan['id']}", headers=yonetici,
                     json={"slot_dakika": 30})
    assert p.status_code == 200 and p.json()["slot_dakika"] == 30
    # tutarsiz saat guncellemesi (kapanis mevcut acilisten once) -> 422
    assert client.patch(f"/common-areas/{alan['id']}", headers=yonetici,
                        json={"kapanis": "09:00"}).status_code == 422


def test_slots_dolu_bos_ve_kimlik_yok(client, rworld):
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    yonetici = _headers(client, rworld["slug_a"], rworld["yonetici_a"])
    alan = _mk_area(client, yonetici, ad=f"Slot-{uuid.uuid4().hex[:6]}",
                    acilis="10:00", kapanis="14:00", slot_dakika=60)
    tarih = "2026-09-01"

    def _slots(headers):
        r = client.get(f"/common-areas/{alan['id']}/slots", headers=headers,
                       params={"date": tarih})
        assert r.status_code == 200, r.text
        return r.json()["items"]

    # baslangicta izgara tam ve hepsi BOS: 10-11, 11-12, 12-13, 13-14
    s0 = _slots(resident)
    assert [it["baslangic"] for it in s0] == ["10:00", "11:00", "12:00", "13:00"]
    assert [it["bitis"] for it in s0] == ["11:00", "12:00", "13:00", "14:00"]
    assert all(it["dolu"] is False for it in s0)

    # BEKLEYEN talep slotu DOLDURMAZ (yalniz onayli doldurur)
    r = _request(client, resident, alan["id"], tarih=tarih,
                 baslangic="11:00", bitis="12:00")
    assert all(it["dolu"] is False for it in _slots(resident))

    # ONAYLANINCA yalniz o slot DOLU; kesismeyen bitisik slotlar BOS kalir
    assert client.patch(f"/reservations/{r['id']}", headers=yonetici,
                        json={"durum": "onaylandi"}).status_code == 200
    s1 = _slots(resident)
    assert {it["baslangic"]: it["dolu"] for it in s1} == {
        "10:00": False, "11:00": True, "12:00": False, "13:00": False,
    }
    # GIZLILIK: slot yalniz saat + dolu tasir, kim rezerve etmis SIZMAZ
    for it in s1:
        assert set(it.keys()) == {"baslangic", "bitis", "dolu"}

    # TUM roller slotlari okuyabilir (sakin secebilsin, saha da gorebilir)
    for role in ("resident_a", "guard_a", "gorevli_a", "yonetici_a", "admin_a"):
        _slots(_headers(client, rworld["slug_a"], rworld[role]))


def test_slots_pasif_alan_sakine_404(client, rworld):
    yonetici = _headers(client, rworld["slug_a"], rworld["yonetici_a"])
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    alan = _mk_area(client, yonetici, ad=f"Pasif-{uuid.uuid4().hex[:6]}",
                    acilis="10:00", kapanis="12:00")
    client.patch(f"/common-areas/{alan['id']}", headers=yonetici,
                 json={"aktif": False})
    # pasif alan sakine gorunmez (rezerve edilemez -> varlik sizdirilmaz)
    assert client.get(f"/common-areas/{alan['id']}/slots", headers=resident,
                      params={"date": "2026-09-02"}).status_code == 404
    # yonetim pasif alanin slotlarini gorur (duzenleme baglami)
    assert client.get(f"/common-areas/{alan['id']}/slots", headers=yonetici,
                      params={"date": "2026-09-02"}).status_code == 200


def test_talep_musaitlik_penceresi_disi_422(client, rworld):
    yonetici = _headers(client, rworld["slug_a"], rworld["yonetici_a"])
    resident = _headers(client, rworld["slug_a"], rworld["resident_a"])
    alan = _mk_area(client, yonetici, ad=f"Pencere-{uuid.uuid4().hex[:6]}",
                    acilis="10:00", kapanis="14:00", slot_dakika=60)
    # acilis oncesi / kapanis sonrasi -> 422 (musaitlik disi)
    _request(client, resident, alan["id"], tarih="2026-09-03",
             baslangic="09:00", bitis="10:00", expect=422)
    _request(client, resident, alan["id"], tarih="2026-09-03",
             baslangic="14:00", bitis="15:00", expect=422)
    # pencere ici -> 201
    _request(client, resident, alan["id"], tarih="2026-09-03",
             baslangic="10:00", bitis="11:00", expect=201)
