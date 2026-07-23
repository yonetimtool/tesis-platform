"""GET /me/patrol-window testleri — BUGUNUN pencereleri + checkpoint okutma durumu + aninda tamamlanma.

Mobil bulgusu: "aktif turumda hangi noktalari okuttum" listesi sunucudan
alinabilmeli. okutuldu PENCERE-GENELI (herhangi bir elemanin okutmasi sayilir) —
scheduler'in 'tamamlandi' mantigiyla tutarli.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

UTC = timezone.utc


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _checkpoint(client, headers, ad="CP"):
    nfc = f"NFC-{uuid.uuid4().hex[:10]}"
    return client.post(
        "/checkpoints", headers=headers, json={"ad": ad, "nfc_tag_uid": nfc}
    ).json()


def _plan_with_checkpoints(client, headers, cp_ids, ad="Devriye"):
    # periyot (1440dk) > plan suresi (6s) => TAM pencere sigmaz => plan olusunca
    # _regen_windows (celery) HICBIR pencere URETMEZ. Bu testler pencereleri elle
    # (_ins_window) ekler; boylece gece saatlerinde (yerel 00:00-06:00) uretimin
    # gercek aktif pencere olusturup elle eklenen pencerelerle CAKISMASI (odak/
    # sayim flake'i) engellenir. Uretim yolu ayrica test_scan_generated_window'da
    # ayrica dogrulanir.
    plan = client.post(
        "/patrol-plans",
        headers=headers,
        json={"ad": ad, "baslangic_saat": "00:00", "bitis_saat": "06:00", "periyot_dakika": 1440},
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
    return wid


def _ins_scan(conn, tid, gid, cid, when):
    conn.execute(
        "INSERT INTO scan_event (tenant_id, guard_id, checkpoint_id, nfc_tag_uid, okutma_zamani, idempotency_key) "
        "VALUES (%s,%s,%s,%s,%s,%s)",
        (tid, gid, cid, "NFC", when, uuid.uuid4().hex),
    )


def test_active_window_checkpoint_status(client, world, owner_conn):
    """Aktif pencere varken nokta listesi sirali/dogru; okutulan ✓ + zaman/okutan dolu."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    guard_id = client.get("/me", headers=guard).json()["id"]

    cp1 = _checkpoint(client, admin, ad="Giris")
    cp2 = _checkpoint(client, admin, ad="Otopark")
    plan = _plan_with_checkpoints(client, admin, [cp1["id"], cp2["id"]])

    now = datetime.now(tz=UTC)
    wid = _ins_window(owner_conn, world["a"], plan["id"], now - timedelta(minutes=5), now + timedelta(hours=1))
    scan_at = now - timedelta(minutes=1)
    _ins_scan(owner_conn, world["a"], guard_id, cp1["id"], scan_at)

    r = client.get("/me/patrol-window", headers=guard)
    assert r.status_code == 200, r.text
    body = r.json()
    assert {"window", "checkpoints", "windows"} <= set(body)

    assert body["window"] is not None
    assert body["window"]["id"] == str(wid)
    assert body["window"]["patrol_plan_id"] == plan["id"]
    assert body["window"]["plan_adi"] == "Devriye"
    assert body["window"]["durum"] == "bekliyor"

    cps = body["checkpoints"]
    assert [c["ad"] for c in cps] == ["Giris", "Otopark"]  # sira ile
    assert [c["sira"] for c in cps] == sorted(c["sira"] for c in cps)

    okutulan = next(c for c in cps if c["checkpoint_id"] == cp1["id"])
    assert okutulan["okutuldu"] is True
    assert okutulan["okutma_zamani"] is not None
    assert okutulan["okutan_user_id"] == guard_id

    bekleyen = next(c for c in cps if c["checkpoint_id"] == cp2["id"])
    assert bekleyen["okutuldu"] is False
    assert bekleyen["okutma_zamani"] is None
    assert bekleyen["okutan_user_id"] is None

    # windows[] ayni pencereyi kendi checkpoint listesiyle icerir
    w = next((w for w in body["windows"] if w["id"] == str(wid)), None)
    assert w is not None
    assert [c["ad"] for c in w["checkpoints"]] == ["Giris", "Otopark"]


def test_no_scans_all_unscanned(client, world, owner_conn):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])

    cp1 = _checkpoint(client, admin)
    cp2 = _checkpoint(client, admin)
    plan = _plan_with_checkpoints(client, admin, [cp1["id"], cp2["id"]])
    now = datetime.now(tz=UTC)
    _ins_window(owner_conn, world["a"], plan["id"], now - timedelta(minutes=5), now + timedelta(hours=1))

    body = client.get("/me/patrol-window", headers=guard).json()
    assert body["window"] is not None
    assert len(body["checkpoints"]) == 2
    assert all(c["okutuldu"] is False for c in body["checkpoints"])


def test_scan_outside_window_not_counted(client, world, owner_conn):
    """Pencere disindaki (onceki) scan okutuldu SAYILMAZ."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    guard_id = client.get("/me", headers=guard).json()["id"]

    cp = _checkpoint(client, admin)
    plan = _plan_with_checkpoints(client, admin, [cp["id"]])
    now = datetime.now(tz=UTC)
    _ins_window(owner_conn, world["a"], plan["id"], now - timedelta(minutes=5), now + timedelta(hours=1))
    # pencere baslangicindan ONCE okutulmus
    _ins_scan(owner_conn, world["a"], guard_id, cp["id"], now - timedelta(minutes=10))

    body = client.get("/me/patrol-window", headers=guard).json()
    assert body["window"] is not None
    assert body["checkpoints"][0]["okutuldu"] is False
    assert body["checkpoints"][0]["okutma_zamani"] is None


def test_no_active_window_returns_null_200(client, world, owner_conn):
    """Aktif pencere yokken window null + checkpoints [] (200, hata degil)."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])

    cp = _checkpoint(client, admin)
    plan = _plan_with_checkpoints(client, admin, [cp["id"]])
    now = datetime.now(tz=UTC)
    # DUN kalmis pencere — su an aktif DEGIL ve BUGUNUN listesinde de degil.
    # (now-3h/now-2h kullanmak gece-yarisi civari (yerel 02:00-06:00) pencereyi
    # bugune sarkitip windows[]'a sizdirir -> saat-flake; net dun kullaniyoruz.)
    _ins_window(
        owner_conn,
        world["a"],
        plan["id"],
        now - timedelta(days=1, hours=2),
        now - timedelta(days=1, hours=1),
    )

    r = client.get("/me/patrol-window", headers=guard)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["window"] is None
    assert body["checkpoints"] == []
    assert body["windows"] == []


def test_other_guards_scan_visible(client, world, owner_conn):
    """okutuldu pencere-GENELI: baska elemanin okutmasi da gorunur."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    admin_id = client.get("/me", headers=admin).json()["id"]

    cp = _checkpoint(client, admin)
    plan = _plan_with_checkpoints(client, admin, [cp["id"]])
    now = datetime.now(tz=UTC)
    _ins_window(owner_conn, world["a"], plan["id"], now - timedelta(minutes=5), now + timedelta(hours=1))
    # BASKA kullanici (admin) okutmus; guard yine de gormeli
    _ins_scan(owner_conn, world["a"], admin_id, cp["id"], now - timedelta(minutes=1))

    body = client.get("/me/patrol-window", headers=guard).json()
    assert body["checkpoints"][0]["okutuldu"] is True
    assert body["checkpoints"][0]["okutan_user_id"] == admin_id


def test_multiple_active_windows_all_returned(client, world, owner_conn):
    """Birden cok plan ayni anda aktifse hepsi windows[]'ta; window = bitisi en yakin."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])

    cp1 = _checkpoint(client, admin)
    cp2 = _checkpoint(client, admin)
    plan1 = _plan_with_checkpoints(client, admin, [cp1["id"]], ad="Plan-1")
    plan2 = _plan_with_checkpoints(client, admin, [cp2["id"]], ad="Plan-2")
    now = datetime.now(tz=UTC)
    # ODAK (window) = ilk AKTIF pencere; endpoint pencereleri (pencere_baslangic,
    # id) ile siralar (me_patrol.py). Iki pencere AYNI baslangica sahipse siralama
    # id (UUID) ile belirlenir -> NONDETERMINISTIK. Bu yuzden w_soon'u DAHA ERKEN
    # baslat: hem en erken baslangic hem en yakin bitis => "en acil" + deterministik
    # (saatten bagimsiz; UUID yarisina bagli DEGIL).
    w_late = _ins_window(owner_conn, world["a"], plan1["id"], now - timedelta(minutes=5), now + timedelta(hours=2))
    w_soon = _ins_window(owner_conn, world["a"], plan2["id"], now - timedelta(minutes=10), now + timedelta(hours=1))

    body = client.get("/me/patrol-window", headers=guard).json()
    ids = [w["id"] for w in body["windows"]]
    assert str(w_soon) in ids and str(w_late) in ids
    # window = en erken baslayan aktif pencere (= en acil; en yakin bitis).
    assert body["window"]["id"] == str(w_soon)
    assert body["checkpoints"] == next(
        w["checkpoints"] for w in body["windows"] if w["id"] == str(w_soon)
    )


def test_rbac(client, world):
    """admin + security 200; gorevli/resident 403 (dashboard ile tutarli)."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    sec = _headers(client, world["slug_a"], world["guard_a"])
    cle = _headers(client, world["slug_a"], world["gorevli_a"])
    res = _headers(client, world["slug_a"], world["resident_a"])
    assert client.get("/me/patrol-window", headers=admin).status_code == 200
    assert client.get("/me/patrol-window", headers=sec).status_code == 200
    r = client.get("/me/patrol-window", headers=cle)
    assert r.status_code == 403 and r.json()["error"]["code"] == "forbidden"
    r = client.get("/me/patrol-window", headers=res)
    assert r.status_code == 403 and r.json()["error"]["code"] == "forbidden"


def test_tenant_isolation(client, world, owner_conn):
    """A'nin aktif penceresi B'nin /me/patrol-window cevabina sizmaz."""
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])

    cp = _checkpoint(client, admin_a)
    plan = _plan_with_checkpoints(client, admin_a, [cp["id"]])
    now = datetime.now(tz=UTC)
    wid = _ins_window(owner_conn, world["a"], plan["id"], now - timedelta(minutes=5), now + timedelta(hours=1))

    body_b = client.get("/me/patrol-window", headers=admin_b).json()
    assert all(w["id"] != str(wid) for w in body_b["windows"])
    assert body_b["window"] is None or body_b["window"]["id"] != str(wid)


def _scan(client, guard, nfc, when):
    return client.post(
        "/scans",
        headers={**guard, "Idempotency-Key": uuid.uuid4().hex},
        json={"nfc_tag_uid": nfc, "okutma_zamani": when.isoformat(), "gps_lat": 41.0, "gps_lng": 29.0},
    )


def test_bugun_pencereleri_aktif_olmayan_dahil(client, world, owner_conn):
    """Bugune ait pencereler (aktif olmayan YAKLASAN dahil) windows[] icinde
    doner; window (ODAK) yalniz SU AN aktif olandir."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    cp = _checkpoint(client, admin)
    plan = _plan_with_checkpoints(client, admin, [cp["id"]])
    now = datetime.now(tz=UTC)
    aktif = _ins_window(
        owner_conn, world["a"], plan["id"], now - timedelta(minutes=5), now + timedelta(minutes=30)
    )
    yaklasan = _ins_window(
        owner_conn, world["a"], plan["id"], now + timedelta(hours=1), now + timedelta(hours=2)
    )
    body = client.get("/me/patrol-window", headers=guard).json()
    ids = {w["id"] for w in body["windows"]}
    assert str(aktif) in ids and str(yaklasan) in ids  # ikisi de BUGUN listesinde
    assert body["window"] is not None and body["window"]["id"] == str(aktif)  # odak=aktif


def test_scan_pencereyi_aninda_tamamlar(client, world, owner_conn):
    """Aktif pencerede TUM checkpoint'ler POST /scans ile okutulunca pencere
    HEMEN 'tamamlandi' olur (bitisini beklemeden); eksikken 'bekliyor' kalir."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    cp1 = _checkpoint(client, admin, ad="A")
    cp2 = _checkpoint(client, admin, ad="B")
    plan = _plan_with_checkpoints(client, admin, [cp1["id"], cp2["id"]])
    now = datetime.now(tz=UTC)
    wid = _ins_window(
        owner_conn, world["a"], plan["id"], now - timedelta(minutes=5), now + timedelta(hours=1)
    )

    def _durum():
        d = client.get("/me/patrol-window", headers=guard).json()
        return next(w for w in d["windows"] if w["id"] == str(wid))["durum"]

    # cp1 tara -> hala bekliyor (1/2)
    assert _scan(client, guard, cp1["nfc_tag_uid"], now).status_code == 201
    assert _durum() == "bekliyor"

    # cp2 tara -> HEMEN tamamlandi (2/2)
    assert _scan(client, guard, cp2["nfc_tag_uid"], now).status_code == 201
    assert _durum() == "tamamlandi"
