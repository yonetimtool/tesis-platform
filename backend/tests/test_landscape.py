"""Peyzaj: Task (tip=peyzaj) + takvim + hatirlatma (yaklasan/kacirilan) + ilerleme."""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from app.scheduler.service import landscape_reminders

UTC = timezone.utc


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _ins_peyzaj(owner_conn, tenant_id, planlanan, periyot=None, aktif=True):
    tid = uuid.uuid4()
    owner_conn.execute(
        "INSERT INTO task (id, tenant_id, tip, ad, periyot_dakika, sonraki_planlanan, aktif) "
        "VALUES (%s,%s,'peyzaj',%s,%s,%s,%s)",
        (tid, tenant_id, "Cim bicme", periyot, planlanan, aktif),
    )
    return tid


def _notif_count(owner_conn, task_id, tip):
    return owner_conn.execute(
        "SELECT count(*) FROM notification WHERE task_id=%s AND tip=%s::notification_tip",
        (task_id, tip),
    ).fetchone()[0]


# ------------------------------ Task (peyzaj) ------------------------------ #
def test_peyzaj_task_via_task_api(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    cleaning = _headers(client, world["slug_a"], world["cleaning_a"])

    r = client.post(
        "/tasks",
        headers=admin,
        json={
            "tip": "peyzaj",
            "ad": "Cim bicme",
            "periyot_dakika": 1440,
            "sonraki_planlanan": "2030-06-01T08:00:00Z",
        },
    )
    assert r.status_code == 201, r.text
    assert r.json()["tip"] == "peyzaj"
    assert r.json()["sonraki_planlanan"].startswith("2030-06-01T08:00:00")

    # tip filtresi
    lst = client.get("/tasks", headers=admin, params={"tip": "peyzaj"}).json()
    assert any(it["id"] == r.json()["id"] for it in lst["items"])

    # RBAC: cleaning peyzaj task olusturamaz (Task CRUD admin)
    assert client.post("/tasks", headers=cleaning, json={"tip": "peyzaj", "ad": "x"}).status_code == 403


# ------------------------------- takvim ------------------------------------ #
def test_landscape_schedule_ordering_and_isolation(client, world, owner_conn):
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])

    t_late = _ins_peyzaj(owner_conn, world["a"], datetime(2030, 6, 3, 8, tzinfo=UTC))
    t_early = _ins_peyzaj(owner_conn, world["a"], datetime(2030, 6, 1, 8, tzinfo=UTC))
    t_mid = _ins_peyzaj(owner_conn, world["a"], datetime(2030, 6, 2, 8, tzinfo=UTC))
    # B'de de bir peyzaj (izolasyon icin)
    t_b = _ins_peyzaj(owner_conn, world["b"], datetime(2030, 6, 1, 8, tzinfo=UTC))

    body = client.get("/landscape/schedule", headers=admin_a).json()
    ids = [it["id"] for it in body["items"]]
    # sirali (artan) ve A'nin isleri
    pos = {i: ids.index(str(i)) for i in (t_early, t_mid, t_late)}
    assert pos[t_early] < pos[t_mid] < pos[t_late]
    assert str(t_b) not in ids  # tenant izole

    # B sadece kendi peyzajini gorur
    b_ids = [it["id"] for it in client.get("/landscape/schedule", headers=admin_b).json()["items"]]
    assert str(t_b) in b_ids and str(t_early) not in b_ids


# ----------------------------- hatirlatma ---------------------------------- #
def test_landscape_yaklasan_reminder_idempotent(client, world, owner_conn):
    now = datetime(2030, 1, 1, 0, 0, tzinfo=UTC)
    task_id = _ins_peyzaj(owner_conn, world["a"], datetime(2030, 1, 1, 6, 0, tzinfo=UTC))  # +6s, lead 24

    landscape_reminders(now=now)
    assert _notif_count(owner_conn, task_id, "peyzaj_yaklasan") == 1

    # ikinci kosum -> cift YOK (dedup_key)
    landscape_reminders(now=now)
    assert _notif_count(owner_conn, task_id, "peyzaj_yaklasan") == 1


def test_landscape_kacirilan_reminder_idempotent(client, world, owner_conn):
    now = datetime(2030, 2, 2, 0, 0, tzinfo=UTC)
    task_id = _ins_peyzaj(owner_conn, world["a"], datetime(2030, 2, 1, 8, 0, tzinfo=UTC))  # gecmis, tamamlama yok

    landscape_reminders(now=now)
    assert _notif_count(owner_conn, task_id, "peyzaj_kacirilan") == 1
    landscape_reminders(now=now)
    assert _notif_count(owner_conn, task_id, "peyzaj_kacirilan") == 1


# --------------------------- tamamlama ilerletir --------------------------- #
def test_completion_advances_next_planned(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    cleaning = _headers(client, world["slug_a"], world["cleaning_a"])

    t = client.post(
        "/tasks",
        headers=admin,
        json={
            "tip": "peyzaj",
            "ad": "Cim bicme",
            "periyot_dakika": 1440,  # 1 gun
            "sonraki_planlanan": "2030-06-01T08:00:00Z",
        },
    ).json()

    comp = client.post(
        f"/tasks/{t['id']}/completions",
        headers={**cleaning, "Idempotency-Key": uuid.uuid4().hex},
        json={"tamamlanma_zamani": "2030-06-01T09:00:00Z"},
    )
    assert comp.status_code == 201, comp.text

    after = client.get(f"/tasks/{t['id']}", headers=admin).json()
    assert after["sonraki_planlanan"].startswith("2030-06-02T08:00:00")  # +1 gun ilerledi
