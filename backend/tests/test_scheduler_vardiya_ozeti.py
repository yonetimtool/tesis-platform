"""(P181 Bölüm 10.2) VARDIYA SONU ÖZETİ — batching.

Devriye okutmaları tek tek push üretmez; vardiya BİTİNCE yönetime tek
"X/Y nokta okutuldu" özeti gider. Idempotent (vardiya+gün başına tek).
Veri owner (RLS bypass) ile kurulur; `dispatch_external` mock'lanır.
`docker compose exec api pytest` ile çalıştırılır.
"""
from __future__ import annotations

import uuid
from datetime import datetime, time, timezone
from types import SimpleNamespace

import pytest

from app.scheduler import service
from app.scheduler.service import summarize_ended_shifts

UTC = timezone.utc

# Perşembe 2026-01-15; İstanbul (+03) 09:00–17:00 vardiyası → [06:00Z, 14:00Z].
# now = 15:00Z (yerel 18:00) → vardiya bitmiş.
NOW = datetime(2026, 1, 15, 15, 0, tzinfo=UTC)
ICINDE = datetime(2026, 1, 15, 10, 0, tzinfo=UTC)   # vardiya aralığında
DISINDA = datetime(2026, 1, 15, 3, 0, tzinfo=UTC)   # vardiya öncesi (sayılmaz)

# GECE vardiyası: İstanbul (+03) 22:00–06:00 → dün başlar bugün biter.
# 14-01 22:00 yerel = 14-01 19:00Z; 15-01 06:00 yerel = 15-01 03:00Z.
# Pencere UTC'de [14-01 19:00Z, 15-01 03:00Z) — GECE YARISINI (00:00Z) AŞAR.
GECE_NOW = datetime(2026, 1, 15, 5, 0, tzinfo=UTC)      # yerel 08:00 → bitmiş
GECE_ONCE = datetime(2026, 1, 14, 20, 0, tzinfo=UTC)    # yerel 23:00 (gece yarısı ÖNCESİ) — içeride
GECE_SONRA = datetime(2026, 1, 15, 0, 0, tzinfo=UTC)    # yerel 03:00 (gece yarısı SONRASI) — içeride
GECE_DISI = datetime(2026, 1, 15, 4, 0, tzinfo=UTC)     # yerel 07:00 (bitiş sonrası) — dışarıda
GECE_SURUYOR = datetime(2026, 1, 15, 1, 0, tzinfo=UTC)  # yerel 04:00 — vardiya SÜRÜYOR


def _tenant(conn, tzname="Europe/Istanbul") -> uuid.UUID:
    tid = uuid.uuid4()
    conn.execute(
        "INSERT INTO tenant (id, ad, slug, timezone) VALUES (%s,%s,%s,%s)",
        (tid, "Vardiya", f"vardiya-{tid.hex[:10]}", tzname),
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


def _shift(conn, tid, bas=time(9, 0), bit=time(17, 0), gun="her_gun") -> uuid.UUID:
    sid = uuid.uuid4()
    conn.execute(
        "INSERT INTO shift (id, tenant_id, ad, baslangic_saat, bitis_saat, gun_tipi) "
        "VALUES (%s,%s,%s,%s,%s,%s::gun_tipi)",
        (sid, tid, "Gündüz", bas, bit, gun),
    )
    return sid


def _plan(conn, tid, shift_id) -> uuid.UUID:
    pid = uuid.uuid4()
    conn.execute(
        "INSERT INTO patrol_plan (id, tenant_id, ad, baslangic_saat, bitis_saat, "
        "periyot_dakika, aktif, shift_id) VALUES (%s,%s,%s,%s,%s,%s,%s,%s)",
        (pid, tid, "Plan", time(9, 0), time(17, 0), 60, True, shift_id),
    )
    return pid


def _checkpoint(conn, tid) -> uuid.UUID:
    cid = uuid.uuid4()
    conn.execute(
        "INSERT INTO checkpoint (id, tenant_id, ad, nfc_tag_uid, aktif) VALUES (%s,%s,%s,%s,true)",
        (cid, tid, "CP", f"N-{cid.hex[:10]}"),
    )
    return cid


def _assign(conn, tid, pid, cid, sira) -> None:
    conn.execute(
        "INSERT INTO patrol_plan_checkpoint (tenant_id, patrol_plan_id, checkpoint_id, sira) "
        "VALUES (%s,%s,%s,%s)",
        (tid, pid, cid, sira),
    )


def _scan(conn, tid, gid, cid, when) -> None:
    conn.execute(
        "INSERT INTO scan_event (tenant_id, guard_id, checkpoint_id, nfc_tag_uid, "
        "okutma_zamani, idempotency_key) VALUES (%s,%s,%s,%s,%s,%s)",
        (tid, gid, cid, "NFC", when, uuid.uuid4().hex),
    )


def _ozetler(conn, tid):
    return conn.execute(
        "SELECT mesaj_veri FROM notification WHERE tenant_id = %s AND tip = 'vardiya_ozeti'",
        (tid,),
    ).fetchall()


@pytest.fixture
def sched(owner_conn):
    tid = _tenant(owner_conn)
    gid = _guard(owner_conn, tid)
    yield SimpleNamespace(tid=tid, gid=gid, conn=owner_conn)
    owner_conn.execute("DELETE FROM tenant WHERE id = %s", (tid,))


@pytest.fixture
def push_spy(monkeypatch):
    rec: list[dict] = []
    monkeypatch.setattr(service, "dispatch_external", lambda k, **kw: rec.append({"k": k, **kw}))
    return rec


def test_vardiya_ozeti_OKUTULAN_BEKLENEN_sayar_ve_push(sched, push_spy):
    """2 nokta beklenir, 1'i okutulur → '1/2'; yönetime tek push."""
    sid = _shift(sched.conn, sched.tid)
    pid = _plan(sched.conn, sched.tid, sid)
    c1 = _checkpoint(sched.conn, sched.tid)
    c2 = _checkpoint(sched.conn, sched.tid)
    _assign(sched.conn, sched.tid, pid, c1, 0)
    _assign(sched.conn, sched.tid, pid, c2, 1)
    _scan(sched.conn, sched.tid, sched.gid, c1, ICINDE)          # sayılır
    _scan(sched.conn, sched.tid, sched.gid, c2, DISINDA)         # aralık dışı → sayılmaz

    assert summarize_ended_shifts(now=NOW) == 1
    ozet = _ozetler(sched.conn, sched.tid)
    assert len(ozet) == 1
    veri = ozet[0][0]
    assert veri["beklenen"] == 2 and veri["okutulan"] == 1
    # Yönetime (admin/yönetici) TEK push.
    assert len(push_spy) == 1
    assert push_spy[0]["k"] == "vardiya_ozeti"
    assert set(push_spy[0]["target_roles"]) == {"admin", "yonetici"}


def test_vardiya_ozeti_IDEMPOTENT(sched, push_spy):
    """Aynı vardiya-günü için ikinci koşum tekrar üretmez (dedup_key)."""
    sid = _shift(sched.conn, sched.tid)
    pid = _plan(sched.conn, sched.tid, sid)
    c1 = _checkpoint(sched.conn, sched.tid)
    _assign(sched.conn, sched.tid, pid, c1, 0)
    _scan(sched.conn, sched.tid, sched.gid, c1, ICINDE)

    assert summarize_ended_shifts(now=NOW) == 1
    assert summarize_ended_shifts(now=NOW) == 0          # ikinci kez: 0
    assert len(_ozetler(sched.conn, sched.tid)) == 1     # tek kayıt


def test_vardiya_BITMEDIYSE_ozet_yok(sched, push_spy):
    """Vardiya bitmeden (now vardiya aralığında) özet üretilmez."""
    sid = _shift(sched.conn, sched.tid)
    pid = _plan(sched.conn, sched.tid, sid)
    c1 = _checkpoint(sched.conn, sched.tid)
    _assign(sched.conn, sched.tid, pid, c1, 0)
    # now = yerel 12:00 (vardiya 09:00–17:00 SÜRÜYOR)
    erken = datetime(2026, 1, 15, 9, 0, tzinfo=UTC)  # yerel 12:00
    assert summarize_ended_shifts(now=erken) == 0
    assert _ozetler(sched.conn, sched.tid) == []


def test_vardiya_ozeti_GECE_vardiyasi_GECE_YARISI_asan_okutma_sayar(sched, push_spy):
    """GECE vardiyası (22:00–06:00): pencere gece yarısını aşar. Gece yarısı
    ÖNCESİ ve SONRASI okutmalar sayılır; bitiş sonrası sayılmaz. Özet gün
    anahtarı BAŞLAMA günü (14-01)."""
    sid = _shift(sched.conn, sched.tid, bas=time(22, 0), bit=time(6, 0))
    pid = _plan(sched.conn, sched.tid, sid)
    c1 = _checkpoint(sched.conn, sched.tid)
    c2 = _checkpoint(sched.conn, sched.tid)
    c3 = _checkpoint(sched.conn, sched.tid)
    _assign(sched.conn, sched.tid, pid, c1, 0)
    _assign(sched.conn, sched.tid, pid, c2, 1)
    _assign(sched.conn, sched.tid, pid, c3, 2)
    _scan(sched.conn, sched.tid, sched.gid, c1, GECE_ONCE)    # gece yarısı öncesi → sayılır
    _scan(sched.conn, sched.tid, sched.gid, c2, GECE_SONRA)   # gece yarısı sonrası → sayılır
    _scan(sched.conn, sched.tid, sched.gid, c3, GECE_DISI)    # bitiş sonrası → sayılmaz

    assert summarize_ended_shifts(now=GECE_NOW) == 1
    ozet = _ozetler(sched.conn, sched.tid)
    assert len(ozet) == 1
    veri = ozet[0][0]
    assert veri["beklenen"] == 3 and veri["okutulan"] == 2   # gece yarısını aşan iki okutma
    assert veri["gun"] == "14-01"                            # başlama günü
    assert len(push_spy) == 1 and push_spy[0]["k"] == "vardiya_ozeti"


def test_vardiya_ozeti_GECE_vardiyasi_SURERKEN_ozet_yok(sched, push_spy):
    """GECE vardiyası daha bitmeden (yerel 04:00, bitiş 06:00) özet üretilmez."""
    sid = _shift(sched.conn, sched.tid, bas=time(22, 0), bit=time(6, 0))
    pid = _plan(sched.conn, sched.tid, sid)
    c1 = _checkpoint(sched.conn, sched.tid)
    _assign(sched.conn, sched.tid, pid, c1, 0)
    _scan(sched.conn, sched.tid, sched.gid, c1, GECE_SONRA)   # okutma var ama vardiya sürüyor
    assert summarize_ended_shifts(now=GECE_SURUYOR) == 0
    assert _ozetler(sched.conn, sched.tid) == []


def test_vardiya_ozeti_GECE_vardiyasi_IDEMPOTENT(sched, push_spy):
    """Gece vardiyası da (başlama günü anahtarıyla) tek kez özetlenir."""
    sid = _shift(sched.conn, sched.tid, bas=time(22, 0), bit=time(6, 0))
    pid = _plan(sched.conn, sched.tid, sid)
    c1 = _checkpoint(sched.conn, sched.tid)
    _assign(sched.conn, sched.tid, pid, c1, 0)
    _scan(sched.conn, sched.tid, sched.gid, c1, GECE_SONRA)
    assert summarize_ended_shifts(now=GECE_NOW) == 1
    assert summarize_ended_shifts(now=GECE_NOW) == 0
    assert len(_ozetler(sched.conn, sched.tid)) == 1


def test_vardiya_gun_tipi_HAFTA_ICI_hafta_sonu_kosmaz(sched, push_spy):
    """hafta_ici vardiya, hafta sonu biten güne özet ÜRETMEZ."""
    sid = _shift(sched.conn, sched.tid, gun="hafta_ici")
    pid = _plan(sched.conn, sched.tid, sid)
    c1 = _checkpoint(sched.conn, sched.tid)
    _assign(sched.conn, sched.tid, pid, c1, 0)
    # 2026-01-17 Cumartesi 15:00Z (yerel 18:00) → hafta sonu.
    cumartesi = datetime(2026, 1, 17, 15, 0, tzinfo=UTC)
    assert summarize_ended_shifts(now=cumartesi) == 0
    assert _ozetler(sched.conn, sched.tid) == []
