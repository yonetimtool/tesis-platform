"""GET /patrol-windows — tarih araligi/durum/plan filtresi, DESC, sayfalama,
tenant izolasyon, RBAC, bos aralik. patrol_window verisi owner_conn ile uretilir
(scheduler materialize ile ayni tabloya yazilir)."""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

UTC = timezone.utc
T1 = datetime(2027, 3, 1, 0, 0, tzinfo=UTC)
T2 = datetime(2027, 3, 2, 0, 0, tzinfo=UTC)
T3 = datetime(2027, 3, 3, 0, 0, tzinfo=UTC)
HOUR = timedelta(hours=1)


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _checkpoint(client, headers):
    nfc = f"NFC-{uuid.uuid4().hex[:10]}"
    return client.post("/checkpoints", headers=headers, json={"ad": "CP", "nfc_tag_uid": nfc}).json()


def _plan(client, headers, cp_ids, ad="Devriye"):
    plan = client.post(
        "/patrol-plans",
        headers=headers,
        json={"ad": ad, "baslangic_saat": "00:00", "bitis_saat": "06:00", "periyot_dakika": 60},
    ).json()
    client.put(
        f"/patrol-plans/{plan['id']}/checkpoints",
        headers=headers,
        json={"items": [{"checkpoint_id": c} for c in cp_ids]},
    )
    return plan


def _ins_window(conn, tid, pid, start, end, durum="bekliyor"):
    wid = uuid.uuid4()
    conn.execute(
        "INSERT INTO patrol_window (id, tenant_id, patrol_plan_id, pencere_baslangic, pencere_bitis, durum) "
        "VALUES (%s,%s,%s,%s,%s,%s)",
        (wid, tid, pid, start, end, durum),
    )
    return str(wid)


def _ins_scan(conn, tid, gid, cid, when):
    conn.execute(
        "INSERT INTO scan_event (tenant_id, guard_id, checkpoint_id, nfc_tag_uid, okutma_zamani, idempotency_key) "
        "VALUES (%s,%s,%s,%s,%s,%s)",
        (tid, gid, cid, "NFC", when, uuid.uuid4().hex),
    )


# ---------------------- aralik + durum + siralama + sayilar ----------------- #
def test_range_status_order_and_counts(client, world, owner_conn):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    guard_id = client.get("/me", headers=guard).json()["id"]

    cp1 = _checkpoint(client, admin)
    cp2 = _checkpoint(client, admin)
    plan = _plan(client, admin, [cp1["id"], cp2["id"]])

    w1 = _ins_window(owner_conn, world["a"], plan["id"], T1, T1 + HOUR, "tamamlandi")
    w2 = _ins_window(owner_conn, world["a"], plan["id"], T2, T2 + HOUR, "kacirildi")
    w3 = _ins_window(owner_conn, world["a"], plan["id"], T3, T3 + HOUR, "bekliyor")
    _ins_scan(owner_conn, world["a"], guard_id, cp1["id"], T1 + timedelta(seconds=5))  # w1 -> 1/2

    # tum kume: DESC (en yeni ustte) + sayilar + ozet
    r = client.get("/patrol-windows", headers=admin)
    assert r.status_code == 200, r.text
    body = r.json()
    ids = [w["id"] for w in body["items"]]
    assert ids == [w3, w2, w1]  # pencere_baslangic DESC
    by_id = {w["id"]: w for w in body["items"]}
    assert by_id[w1]["beklenen_checkpoint_sayisi"] == 2
    assert by_id[w1]["okutulan_checkpoint_sayisi"] == 1
    assert by_id[w3]["okutulan_checkpoint_sayisi"] == 0
    assert by_id[w1]["plan_adi"] == "Devriye"
    assert body["meta"]["total"] == 3
    assert body["ozet"] == {"toplam": 3, "tamamlandi": 1, "kacirildi": 1, "bekliyor": 1}

    # durum filtresi: yalniz kacirildi
    r = client.get("/patrol-windows", headers=admin, params={"durum": "kacirildi"})
    assert [w["id"] for w in r.json()["items"]] == [w2]
    assert r.json()["ozet"] == {"toplam": 1, "tamamlandi": 0, "kacirildi": 1, "bekliyor": 0}

    # tarih araligi (yari-acik): [T2, T3) -> yalniz w2
    r = client.get(
        "/patrol-windows",
        headers=admin,
        params={"baslangic": T2.isoformat(), "bitis": T3.isoformat()},
    )
    assert [w["id"] for w in r.json()["items"]] == [w2]
    assert r.json()["meta"]["total"] == 1


def test_plan_filter_excludes_other_plan(client, world, owner_conn):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    cp = _checkpoint(client, admin)
    p1 = _plan(client, admin, [cp["id"]], ad="Plan-1")
    p2 = _plan(client, admin, [cp["id"]], ad="Plan-2")
    w1 = _ins_window(owner_conn, world["a"], p1["id"], T1, T1 + HOUR)
    _ins_window(owner_conn, world["a"], p2["id"], T2, T2 + HOUR)

    r = client.get("/patrol-windows", headers=admin, params={"patrol_plan_id": p1["id"]})
    assert [w["id"] for w in r.json()["items"]] == [w1]
    assert r.json()["ozet"]["toplam"] == 1


def test_pagination_desc(client, world, owner_conn):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    cp = _checkpoint(client, admin)
    plan = _plan(client, admin, [cp["id"]])
    w1 = _ins_window(owner_conn, world["a"], plan["id"], T1, T1 + HOUR)
    w2 = _ins_window(owner_conn, world["a"], plan["id"], T2, T2 + HOUR)
    w3 = _ins_window(owner_conn, world["a"], plan["id"], T3, T3 + HOUR)

    p0 = client.get("/patrol-windows", headers=admin, params={"limit": 2, "offset": 0}).json()
    assert [w["id"] for w in p0["items"]] == [w3, w2]
    assert p0["meta"]["total"] == 3
    p1 = client.get("/patrol-windows", headers=admin, params={"limit": 2, "offset": 2}).json()
    assert [w["id"] for w in p1["items"]] == [w1]


def test_empty_range_is_empty_not_error(client, world, owner_conn):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    cp = _checkpoint(client, admin)
    plan = _plan(client, admin, [cp["id"]])
    _ins_window(owner_conn, world["a"], plan["id"], T1, T1 + HOUR)

    far = datetime(2099, 1, 1, tzinfo=UTC)
    r = client.get("/patrol-windows", headers=admin, params={"baslangic": far.isoformat()})
    assert r.status_code == 200
    assert r.json()["items"] == []
    assert r.json()["meta"]["total"] == 0
    assert r.json()["ozet"] == {"toplam": 0, "tamamlandi": 0, "kacirildi": 0, "bekliyor": 0}


def test_tenant_isolation(client, world, owner_conn):
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    cp = _checkpoint(client, admin_a)
    plan = _plan(client, admin_a, [cp["id"]])
    wid_a = _ins_window(owner_conn, world["a"], plan["id"], T1, T1 + HOUR)

    # B admini A'nin penceresini GORMEZ (RLS)
    b_ids = [w["id"] for w in client.get("/patrol-windows", headers=admin_b).json()["items"]]
    assert wid_a not in b_ids
    # A admini gorur
    a_ids = [w["id"] for w in client.get("/patrol-windows", headers=admin_a).json()["items"]]
    assert wid_a in a_ids


def test_rbac(client, world):
    # security (guard) -> 200; gorevli/resident -> 403
    guard = _headers(client, world["slug_a"], world["guard_a"])
    assert client.get("/patrol-windows", headers=guard).status_code == 200
    for role in ("gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.get("/patrol-windows", headers=h).status_code == 403
