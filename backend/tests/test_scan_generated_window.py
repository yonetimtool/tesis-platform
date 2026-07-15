"""E2E: plan olustur -> pencere UYGULAMA yolundan (scheduler.generate) uretilsin
-> guvenlik tarar -> hem /me/patrol-window hem /dashboard/live sayar.

Mevcut patrol testleri pencereyi DOGRUDAN INSERT eder (_ins_window), uretim
yolunu atlar. Kullanici bulgusu (tarama gunluge dusuyor ama Bugun/Turlarim
ilerlemedi) tam da uretim/eslesme yolunda; bu test o yolu uctan uca dogrular.
"""
from __future__ import annotations

import time as _time
import uuid
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

UTC = timezone.utc


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _now_covering_plan_times():
    """Su ani KESIN kapsayan tek gunluk-pencere icin (baslangic, bitis, periyot).

    Istanbul yerel gununde 00:00 -> 23:59 tek pencere (periyot=1439dk); now bu
    araligin son 1 dk'sinda degilse aktiftir (pratikte her zaman)."""
    return "00:00", "23:59", 1439


def test_generated_window_counts_scan(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])

    nfc = f"NFC-{uuid.uuid4().hex[:10]}"
    cp = client.post(
        "/checkpoints", headers=admin, json={"ad": "Giris", "nfc_tag_uid": nfc}
    ).json()

    bas, bit, per = _now_covering_plan_times()
    plan = client.post(
        "/patrol-plans",
        headers=admin,
        json={"ad": "E2E", "baslangic_saat": bas, "bitis_saat": bit, "periyot_dakika": per},
    ).json()
    client.put(
        f"/patrol-plans/{plan['id']}/checkpoints",
        headers=admin,
        json={"items": [{"checkpoint_id": cp["id"]}]},
    )

    # UYGULAMA yolu: plan olusturunca _regen_windows celery task'i (countdown=3)
    # pencereyi uretmeli. Beat'i beklemeden ~15sn icinde gorunmeli.
    window = None
    for _ in range(30):
        body = client.get("/me/patrol-window", headers=guard).json()
        if body["window"] is not None:
            window = body["window"]
            break
        _time.sleep(1)
    assert window is not None, (
        "Plan olusturulunca su ani kapsayan pencere URETILMEDI "
        "(scheduler.generate_patrol_windows calismiyor ya da pencere matematigi)."
    )

    # Tara (POST /scans) — checkpoint UID + su an.
    now = datetime.now(tz=UTC)
    r = client.post(
        "/scans",
        headers={**guard, "Idempotency-Key": uuid.uuid4().hex},
        json={"nfc_tag_uid": nfc, "okutma_zamani": now.isoformat(), "gps_lat": 41.0, "gps_lng": 29.0},
    )
    assert r.status_code == 201, r.text

    # /me/patrol-window (Turlarim) okutuldu ✓
    body = client.get("/me/patrol-window", headers=guard).json()
    w = next((w for w in body["windows"] if w["id"] == window["id"]), None)
    assert w is not None
    okutulan_cp = next(c for c in body["checkpoints"] if c["checkpoint_id"] == cp["id"])
    assert okutulan_cp["okutuldu"] is True, "Turlarim: tarama pencereye SAYILMADI"

    # /dashboard/live (yonetici Bugun) okutulan == 1
    live = client.get("/dashboard/live", headers=admin).json()
    lw = next((x for x in live["aktif_turlar"] if x["patrol_window_id"] == window["id"]), None)
    assert lw is not None, "Bugun: pencere aktif_turlar'da yok"
    assert lw["okutulan_checkpoint_sayisi"] == 1, (
        f"Bugun: okutulan sayilmadi (got {lw['okutulan_checkpoint_sayisi']})"
    )
