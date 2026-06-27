"""Scheduler DB testleri — uretim idempotency, kacirildi/tamamlandi, izolasyon.

Veri owner (psycopg, RLS bypass) ile kurulur; service fonksiyonlari OWNER_DSN
(enumerasyon) + APP_DSN (tenant-scoped) env'lerini kullanir. notify mock'lanir.
`docker compose exec api pytest` ile calistirilir.
"""
from __future__ import annotations

import uuid
from datetime import datetime, time, timezone
from types import SimpleNamespace

import pytest

from app.scheduler import service
from app.scheduler.service import detect_missed, materialize_windows

UTC = timezone.utc

# Bitmis pencere senaryolari icin sabit gecmis aralik + gelecekteki "now".
W_START = datetime(2029, 12, 31, 0, 0, tzinfo=UTC)
W_END = datetime(2029, 12, 31, 1, 0, tzinfo=UTC)
NOW_AFTER = datetime(2030, 1, 1, 0, 0, tzinfo=UTC)


# ------------------------------- yardimcilar ------------------------------- #
def _tenant(conn, tzname="Europe/Istanbul") -> uuid.UUID:
    tid = uuid.uuid4()
    conn.execute(
        "INSERT INTO tenant (id, ad, slug, timezone) VALUES (%s,%s,%s,%s)",
        (tid, "Sched", f"s-{tid.hex[:10]}", tzname),
    )
    return tid


def _guard(conn, tid) -> uuid.UUID:
    gid = uuid.uuid4()
    conn.execute(
        "INSERT INTO app_user (id, tenant_id, ad, email, password_hash, role) "
        "VALUES (%s,%s,%s,%s,%s,%s::user_role)",
        (gid, tid, "Guard", f"g-{gid.hex[:8]}@x.com", "x", "security"),
    )
    return gid


def _plan(conn, tid, bas=time(0, 0), bit=time(6, 0), per=60, aktif=True) -> uuid.UUID:
    pid = uuid.uuid4()
    conn.execute(
        "INSERT INTO patrol_plan (id, tenant_id, ad, baslangic_saat, bitis_saat, periyot_dakika, aktif) "
        "VALUES (%s,%s,%s,%s,%s,%s,%s)",
        (pid, tid, "Plan", bas, bit, per, aktif),
    )
    return pid


def _checkpoint(conn, tid, aktif=True) -> uuid.UUID:
    cid = uuid.uuid4()
    conn.execute(
        "INSERT INTO checkpoint (id, tenant_id, ad, nfc_tag_uid, aktif) VALUES (%s,%s,%s,%s,%s)",
        (cid, tid, "CP", f"N-{cid.hex[:10]}", aktif),
    )
    return cid


def _assign(conn, tid, pid, cid, sira) -> None:
    conn.execute(
        "INSERT INTO patrol_plan_checkpoint (tenant_id, patrol_plan_id, checkpoint_id, sira) "
        "VALUES (%s,%s,%s,%s)",
        (tid, pid, cid, sira),
    )


def _window(conn, tid, pid, start=W_START, end=W_END, durum="bekliyor") -> uuid.UUID:
    wid = uuid.uuid4()
    conn.execute(
        "INSERT INTO patrol_window (id, tenant_id, patrol_plan_id, pencere_baslangic, pencere_bitis, durum) "
        "VALUES (%s,%s,%s,%s,%s,%s)",
        (wid, tid, pid, start, end, durum),
    )
    return wid


def _scan(conn, tid, gid, cid, when) -> None:
    conn.execute(
        "INSERT INTO scan_event (tenant_id, guard_id, checkpoint_id, nfc_tag_uid, okutma_zamani, idempotency_key) "
        "VALUES (%s,%s,%s,%s,%s,%s)",
        (tid, gid, cid, "NFC", when, uuid.uuid4().hex),
    )


def _windows_of(conn, pid):
    return conn.execute(
        "SELECT pencere_baslangic, pencere_bitis, durum FROM patrol_window "
        "WHERE patrol_plan_id = %s ORDER BY pencere_baslangic",
        (pid,),
    ).fetchall()


@pytest.fixture
def sched(owner_conn):
    """Tek tenant + guard; sonunda temizler (cascade)."""
    tid = _tenant(owner_conn)
    gid = _guard(owner_conn, tid)
    yield SimpleNamespace(tid=tid, gid=gid, conn=owner_conn)
    owner_conn.execute("DELETE FROM tenant WHERE id = %s", (tid,))


@pytest.fixture
def notify_spy(monkeypatch):
    recorded: list[dict] = []
    monkeypatch.setattr(service, "notify_missed_tour", lambda **kw: recorded.append(kw))
    return recorded


# ------------------------------- uretim ------------------------------------ #
def test_materialize_creates_six_and_is_idempotent(sched):
    pid = _plan(sched.conn, sched.tid, time(0, 0), time(6, 0), 60)
    now = datetime(2026, 1, 15, 12, 0, tzinfo=UTC)

    materialize_windows(now=now, horizon_days=1)
    rows = _windows_of(sched.conn, pid)
    assert len(rows) == 6
    assert all(r[2] == "bekliyor" for r in rows)
    # yerel 00:00 Istanbul (+03) -> 21:00Z onceki gun
    assert rows[0][0].astimezone(UTC) == datetime(2026, 1, 14, 21, 0, tzinfo=UTC)
    assert rows[-1][1].astimezone(UTC) == datetime(2026, 1, 15, 3, 0, tzinfo=UTC)

    # ikinci kez: cogalmaz
    materialize_windows(now=now, horizon_days=1)
    assert len(_windows_of(sched.conn, pid)) == 6


def test_materialize_skips_inactive_plan(sched):
    pid = _plan(sched.conn, sched.tid, aktif=False)
    materialize_windows(now=datetime(2026, 1, 15, 12, 0, tzinfo=UTC), horizon_days=1)
    assert _windows_of(sched.conn, pid) == []


# --------------------------- kacirilan / tamamlandi ------------------------ #
def test_missed_marks_kacirildi_and_notifies(sched, notify_spy):
    pid = _plan(sched.conn, sched.tid)
    c1 = _checkpoint(sched.conn, sched.tid)
    c2 = _checkpoint(sched.conn, sched.tid)
    _assign(sched.conn, sched.tid, pid, c1, 0)
    _assign(sched.conn, sched.tid, pid, c2, 1)
    wid = _window(sched.conn, sched.tid, pid)  # scan YOK

    detect_missed(now=NOW_AFTER)

    assert _windows_of(sched.conn, pid)[0][2] == "kacirildi"
    assert any(r["window_id"] == wid for r in notify_spy)

    # idempotent: ikinci kez tekrar islemez/loglamaz
    notify_spy.clear()
    detect_missed(now=NOW_AFTER)
    assert all(r["window_id"] != wid for r in notify_spy)
    assert _windows_of(sched.conn, pid)[0][2] == "kacirildi"


def test_completed_marks_tamamlandi_no_notify(sched, notify_spy):
    pid = _plan(sched.conn, sched.tid)
    c1 = _checkpoint(sched.conn, sched.tid)
    c2 = _checkpoint(sched.conn, sched.tid)
    _assign(sched.conn, sched.tid, pid, c1, 0)
    _assign(sched.conn, sched.tid, pid, c2, 1)
    wid = _window(sched.conn, sched.tid, pid)
    # her iki checkpoint pencere araliginda okutuldu
    _scan(sched.conn, sched.tid, sched.gid, c1, datetime(2029, 12, 31, 0, 30, tzinfo=UTC))
    _scan(sched.conn, sched.tid, sched.gid, c2, datetime(2029, 12, 31, 0, 40, tzinfo=UTC))

    detect_missed(now=NOW_AFTER)

    assert _windows_of(sched.conn, pid)[0][2] == "tamamlandi"
    assert all(r["window_id"] != wid for r in notify_spy)


# ------------------------------- izolasyon --------------------------------- #
def test_tenant_isolation_in_detection(owner_conn, notify_spy):
    a = _tenant(owner_conn)
    b = _tenant(owner_conn)
    try:
        pid_a = _plan(owner_conn, a)
        pid_b = _plan(owner_conn, b)
        cp_a = _checkpoint(owner_conn, a)
        cp_b = _checkpoint(owner_conn, b)
        _assign(owner_conn, a, pid_a, cp_a, 0)
        _assign(owner_conn, b, pid_b, cp_b, 0)
        wid_a = _window(owner_conn, a, pid_a)  # A: scan yok -> kacirildi
        wid_b = _window(owner_conn, b, pid_b)  # B: scan var -> tamamlandi
        gid_b = _guard(owner_conn, b)
        _scan(owner_conn, b, gid_b, cp_b, datetime(2029, 12, 31, 0, 30, tzinfo=UTC))

        detect_missed(now=NOW_AFTER)

        assert _windows_of(owner_conn, pid_a)[0][2] == "kacirildi"
        assert _windows_of(owner_conn, pid_b)[0][2] == "tamamlandi"
        # B'nin scan'i A'ya SIZMADI (A hala kacirildi); notify yalniz A icin
        assert any(r["window_id"] == wid_a for r in notify_spy)
        assert all(r["window_id"] != wid_b for r in notify_spy)
    finally:
        owner_conn.execute("DELETE FROM tenant WHERE id IN (%s,%s)", (a, b))
