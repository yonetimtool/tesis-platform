"""notification — idempotent uretim + GET/PATCH /notifications (RBAC, izolasyon)."""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from app.scheduler.service import detect_missed

UTC = timezone.utc
# (P253 A2) PENCERELER GERCEK GECMISTE — `test_dashboard` (P248) ile ayni
# kok neden: saat basi calisan `generate_patrol_windows`, aktif planin
# GELECEKTEKI ve takvime uymayan 'bekliyor' pencerelerini siler (dogru urun
# davranisi). 2029 tarihli "gecmis" pencere gercek saate gore GELECEKTIR;
# uretec test ile `detect_missed` arasina girerse pencere silinir ve
# bildirim hic yazilmaz (tam takimda `test_mark_read_and_isolation`
# StopIteration — olculdu). Gercek gecmise uretec dokunmaz.
_TABAN = (datetime.now(UTC) - timedelta(days=2)).replace(hour=0, minute=0, second=0, microsecond=0)
PAST_START = _TABAN.replace(hour=0, minute=0)
PAST_END = _TABAN.replace(hour=1, minute=0)
NOW_AFTER = _TABAN + timedelta(days=1)


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


def _plan(client, headers, cp_ids):
    plan = client.post(
        "/patrol-plans",
        headers=headers,
        json={"ad": "P", "baslangic_saat": "00:00", "bitis_saat": "06:00", "periyot_dakika": 60},
    ).json()
    client.put(
        f"/patrol-plans/{plan['id']}/checkpoints",
        headers=headers,
        json={"items": [{"checkpoint_id": c} for c in cp_ids]},
    )
    return plan


def _past_window(owner_conn, tenant_id, plan_id):
    wid = uuid.uuid4()
    owner_conn.execute(
        "INSERT INTO patrol_window (id, tenant_id, patrol_plan_id, pencere_baslangic, pencere_bitis, durum) "
        "VALUES (%s,%s,%s,%s,%s,'bekliyor')",
        (wid, tenant_id, plan_id, PAST_START, PAST_END),
    )
    return wid


def _make_missed(client, owner_conn, admin, tenant_id):
    """tenant'ta kacirilan bir tur + (detect ile) notification olustur; window id doner."""
    cp = _checkpoint(client, admin)
    plan = _plan(client, admin, [cp["id"]])
    wid = _past_window(owner_conn, tenant_id, plan["id"])
    detect_missed(now=NOW_AFTER)
    return wid


def _notif_count(owner_conn, wid):
    return owner_conn.execute(
        "SELECT count(*) FROM notification WHERE patrol_window_id=%s", (wid,)
    ).fetchone()[0]


# ----------------------------- idempotency --------------------------------- #
def test_detect_creates_notification_idempotently(client, world, owner_conn):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    wid = _make_missed(client, owner_conn, admin, world["a"])
    assert _notif_count(owner_conn, wid) == 1

    # pencereyi tekrar 'bekliyor' yapip detect'i tekrar kosalim -> CIFT kayit OLMAMALI
    owner_conn.execute("UPDATE patrol_window SET durum='bekliyor' WHERE id=%s", (wid,))
    detect_missed(now=NOW_AFTER)
    assert _notif_count(owner_conn, wid) == 1


# ---------------------------- GET /notifications --------------------------- #
def _tum_bildirimler(client, h, **params):
    """Butun sayfalar (200'luk) — tek sayfaya guvenmek tam takimda flake."""
    out, offset = [], 0
    while True:
        r = client.get("/notifications", headers=h,
                       params={**params, "limit": 200, "offset": offset})
        assert r.status_code == 200, r.text
        sayfa = r.json()
        out += sayfa["items"]
        offset += 200
        if offset >= sayfa["meta"]["total"] or not sayfa["items"]:
            return out


def test_list_notifications_and_okundu_filter(client, world, owner_conn):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    wid = _make_missed(client, owner_conn, admin, world["a"])

    r = client.get("/notifications", headers=admin)
    assert r.status_code == 200, r.text
    body = r.json()
    assert {"meta", "items"} <= set(body)
    # (P251) TUM SAYFALAR taranir: `detect_missed(taban+1g)` tesisteki BUTUN
    # bekleyen pencereler icin ayni anda bildirim uretir; tam takimda 50'yi
    # asar ve ayni zaman damgasinda sira `id`ye kalir — ilk sayfa yetmez.
    item = next((n for n in _tum_bildirimler(client, admin)
                 if n["patrol_window_id"] == str(wid)), None)
    assert item is not None
    assert item["tip"] == "kacirilan_tur" and item["okundu"] is False

    # okundu=false -> var; okundu=true -> yok
    assert any(
        n["patrol_window_id"] == str(wid)
        for n in _tum_bildirimler(client, admin, okundu=False)
    )
    assert all(
        n["patrol_window_id"] != str(wid)
        for n in _tum_bildirimler(client, admin, okundu=True)
    )


def test_list_notifications_tenant_isolation(client, world, owner_conn):
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    wid = _make_missed(client, owner_conn, admin_a, world["a"])

    b_items = client.get("/notifications", headers=admin_b).json()["items"]
    assert all(n["patrol_window_id"] != str(wid) for n in b_items)


def test_notifications_rbac(client, world):
    sec = _headers(client, world["slug_a"], world["guard_a"])
    res = _headers(client, world["slug_a"], world["resident_a"])
    assert client.get("/notifications", headers=sec).status_code == 200
    # (P147) Sakin ARTIK 403 ALMIYOR — uc ona da acildi, ama AYNI
    # SATIRLARI GORMUYOR. Erisimin yerini KAPSAM aldi: yonetim alarmlari
    # (`user_id IS NULL`) sakine donmez. Bu kilit erisimi, kapsam ayrimini
    # ise `test_sakin_bildirimleri.py` olcer — biri gevserse digeri duser.
    assert client.get("/notifications", headers=res).status_code == 200


# --------------------------- PATCH /notifications -------------------------- #
def test_mark_read_and_isolation(client, world, owner_conn):
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    wid = _make_missed(client, owner_conn, admin_a, world["a"])

    nid = next(
        n["id"]
        for n in client.get("/notifications", headers=admin_a).json()["items"]
        if n["patrol_window_id"] == str(wid)
    )

    # B, A'nin bildirimini guncelleyemez -> 404 (RLS)
    assert client.patch(f"/notifications/{nid}", headers=admin_b, json={"okundu": True}).status_code == 404

    # A okundu=true yapar
    pr = client.patch(f"/notifications/{nid}", headers=admin_a, json={"okundu": True})
    assert pr.status_code == 200 and pr.json()["okundu"] is True
    # artik okundu=true filtresinde gorunur
    assert any(
        n["id"] == nid
        for n in client.get("/notifications", headers=admin_a, params={"okundu": True}).json()["items"]
    )


# ------------------- (P253 A2) uretec araya girerse ------------------------- #
def test_URETEC_ARAYA_GIRSE_DE_bildirim_yazilir(client, world, owner_conn):
    """Kararsizligin KOK NEDENI: saat basi `materialize_windows` test ile
    `detect_missed` arasina girince 2029 tarihli (gercekte GELECEK) pencere
    takvim disi sayilip siliniyordu. Taban gercek gecmiste: uretec dokunmaz."""
    from app.scheduler.service import materialize_windows

    admin = _headers(client, world["slug_a"], world["admin_a"])
    cp = _checkpoint(client, admin)
    plan = _plan(client, admin, [cp["id"]])
    wid = _past_window(owner_conn, world["a"], plan["id"])
    materialize_windows()
    detect_missed(now=NOW_AFTER)
    assert _notif_count(owner_conn, wid) == 1


def test_PENCERE_TESTLERINDE_SABIT_GELECEK_TARIH_YOK():
    """Ayni sinif uc kez dondu (P248 dashboard, P253 notifications/scans/
    scheduler_db). Pencere ya da okutma kuran bir test SABIT bir gelecek
    tarihi "gecmis" diye kullanamaz (2029 ve sonrasi sabit yil). Bilerek
    gelecek olan satir `gelecek-bilerek` isaretini tasir."""
    import pathlib
    import re

    desen = re.compile(r"datetime\(20[3-9]\d|datetime\(2029|[\"']20(29|[3-9]\d)-\d\d-\d\d")
    suclu = []
    for f in sorted(pathlib.Path(__file__).parent.glob("test_*.py")):
        metin = f.read_text(encoding="utf-8")
        if "patrol_window" not in metin and "detect_missed" not in metin:
            continue
        for i, satir in enumerate(metin.splitlines(), 1):
            if (satir.lstrip().startswith("#") or "desen = re.compile" in satir
                    or "gelecek-bilerek" in satir):
                continue
            if desen.search(satir):
                suclu.append(f"{f.name}:{i}: {satir.strip()}")
    assert not suclu, "Gercek gecmise bagli taban kullanin (_TABAN):\n" + "\n".join(suclu)
