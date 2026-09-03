"""(P207 §3) VARDIYA HATIRLATMA + BASLAMAMA UYARISI.

Veri owner (RLS bypass) ile kurulur; `dispatch_external` taklit edilir —
olculen sey ZAMANLAYICININ KARARI: kime, ne zaman, kac kez.

===========================================================================
EN KRITIK ÜÇ KILIT
===========================================================================
  1. IDEMPOTENT: ayni kademe ikinci kez GITMEZ (beat dakikada bir kosar),
  2. ILERI BAKAR: BASLAMIS vardiya icin hatirlatma YOK (telafi yok —
     "5 dakika kaldi" demek yanlis olurdu),
  3. BASLAMAMA UYARISI OKUTMA VARSA GITMEZ ve YONETIME gider.
"""
from __future__ import annotations

import uuid
from datetime import date, datetime, time, timedelta, timezone
from types import SimpleNamespace

import pytest

from app.scheduler import service
from app.scheduler.service import (
    hatirlatma_kademeleri,
    vardiya_baslamadi_uyarilari,
    vardiya_hatirlatmalari,
)

UTC = timezone.utc

# Istanbul (+03). Yerel 09:00 vardiyasi = 06:00Z.
GUN = date(2026, 1, 15)
BASLANGIC = time(9, 0)


def _tenant(conn, *, kademe="15", baslamadi=15) -> uuid.UUID:
    tid = uuid.uuid4()
    conn.execute(
        "INSERT INTO tenant (id, ad, slug, timezone, vardiya_hatirlatma_dk, "
        "vardiya_baslamadi_dk) VALUES (%s,%s,%s,%s,%s,%s)",
        (tid, "Hatirlatma", f"hat-{tid.hex[:10]}", "Europe/Istanbul",
         kademe, baslamadi),
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


def _plan(conn, tid, gid, *, tarih=GUN, bas=BASLANGIC) -> uuid.UUID:
    pid = uuid.uuid4()
    conn.execute(
        "INSERT INTO vardiya_plani (id, tenant_id, shift_id, tarih, user_id, "
        "baslangic_saat, bitis_saat) VALUES (%s,%s,NULL,%s,%s,%s,%s)",
        (pid, tid, tarih, gid, bas, time(17, 0)),
    )
    return pid


def _bildirimler(conn, tid, tip):
    return conn.execute(
        "SELECT dedup_key, mesaj_veri, user_id FROM notification "
        "WHERE tenant_id = %s AND tip = %s::notification_tip",
        (tid, tip),
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
    monkeypatch.setattr(
        service, "dispatch_external", lambda k, **kw: rec.append({"k": k, **kw})
    )
    return rec


# ======================= 1) KADEME COZUMLEME ============================== #

def test_KADEMELER_buyukten_kucuge_ve_SINIRLI():
    """Kullanici "5,30" yazsa bile once 30 dakika kalinca hatirlatilir;
    sirasiz birakmak ayni vardiyada once 5 sonra 30 bildirimi demekti."""
    assert hatirlatma_kademeleri("5,30") == [30, 5]
    assert hatirlatma_kademeleri("30, 15 ,5") == [30, 15, 5]
    # UCTEN FAZLASI KIRPILIR: bildirim yorgunlugu hatirlatmayi anlamsiz
    # yapardi.
    assert hatirlatma_kademeleri("60,45,30,15,5") == [60, 45, 30]
    # GECERSIZ/BOS = KAPALI.
    assert hatirlatma_kademeleri("") == []
    assert hatirlatma_kademeleri(None) == []
    assert hatirlatma_kademeleri("abc") == []
    # 0 ANLAMSIZ (vardiya baslarken "0 dakika kaldi").
    assert hatirlatma_kademeleri("0") == []


# ========================= 2) HATIRLATMA ================================== #

def test_HATIRLATMA_PENCEREDE_gider_ve_KISIYE(sched, push_spy):
    _plan(sched.conn, sched.tid, sched.gid)
    # Vardiya 06:00Z; 15 dakika kala = 05:45Z.
    n = vardiya_hatirlatmalari(now=datetime(2026, 1, 15, 5, 45, tzinfo=UTC))
    assert n == 1

    satirlar = _bildirimler(sched.conn, sched.tid, "vardiya_hatirlatma")
    assert len(satirlar) == 1
    assert satirlar[0][1]["dakika"] == 15
    # BILDIRIM KISIYE YAZILIR: yoneticinin listesinde gorunmemeli.
    assert satirlar[0][2] == sched.gid
    # PUSH DA KISIYE: rol hedefi YOK.
    assert push_spy[0]["k"] == "vardiya_hatirlatma"
    assert push_spy[0]["target_user_ids"] == [sched.gid]
    assert push_spy[0]["target_roles"] is None


def test_HATIRLATMA_IDEMPOTENT(sched, push_spy):
    """Beat dakikada bir kosar; ayni kademe ikinci kez GITMEZ."""
    _plan(sched.conn, sched.tid, sched.gid)
    an = datetime(2026, 1, 15, 5, 45, tzinfo=UTC)
    assert vardiya_hatirlatmalari(now=an) == 1
    assert vardiya_hatirlatmalari(now=an) == 0
    assert len(_bildirimler(sched.conn, sched.tid, "vardiya_hatirlatma")) == 1
    assert len(push_spy) == 1


def test_BASLAMIS_vardiya_icin_HATIRLATMA_YOK(sched, push_spy):
    """ILERI BAKAR, GERI BAKMAZ: gecmis vardiya icin "5 dakika kaldi"
    demek yanlis olurdu ve kacirilmis vardiyayi geri getirmezdi."""
    _plan(sched.conn, sched.tid, sched.gid)
    # 06:30Z: vardiya YARIM SAAT ONCE basladi.
    assert vardiya_hatirlatmalari(
        now=datetime(2026, 1, 15, 6, 30, tzinfo=UTC)
    ) == 0
    assert push_spy == []


def test_PENCERE_DISINDA_hatirlatma_YOK(sched):
    _plan(sched.conn, sched.tid, sched.gid)
    # 1 saat kala: 15 dakika kademesinin penceresi DEGIL.
    assert vardiya_hatirlatmalari(
        now=datetime(2026, 1, 15, 5, 0, tzinfo=UTC)
    ) == 0


def test_IKI_KADEME_IKI_AYRI_BILDIRIM(owner_conn, push_spy):
    """Kademe dedup anahtarina GIRER: girmeseydi ikinci kademe "zaten
    gonderildi" diye yutulurdu."""
    tid = _tenant(owner_conn, kademe="30,5")
    gid = _guard(owner_conn, tid)
    _plan(owner_conn, tid, gid)
    try:
        assert vardiya_hatirlatmalari(
            now=datetime(2026, 1, 15, 5, 30, tzinfo=UTC)) == 1
        assert vardiya_hatirlatmalari(
            now=datetime(2026, 1, 15, 5, 55, tzinfo=UTC)) == 1
        satirlar = _bildirimler(owner_conn, tid, "vardiya_hatirlatma")
        assert {s[1]["dakika"] for s in satirlar} == {30, 5}
    finally:
        owner_conn.execute("DELETE FROM tenant WHERE id = %s", (tid,))


def test_KADEME_KAPALIYSA_hicbir_sey_gitmez(owner_conn, push_spy):
    tid = _tenant(owner_conn, kademe="")
    gid = _guard(owner_conn, tid)
    _plan(owner_conn, tid, gid)
    try:
        assert vardiya_hatirlatmalari(
            now=datetime(2026, 1, 15, 5, 45, tzinfo=UTC)) == 0
    finally:
        owner_conn.execute("DELETE FROM tenant WHERE id = %s", (tid,))


def test_IPTAL_EDILMIS_plan_hatirlatilmaz(sched):
    pid = _plan(sched.conn, sched.tid, sched.gid)
    sched.conn.execute(
        "UPDATE vardiya_plani SET durum='iptal' WHERE id=%s", (pid,))
    assert vardiya_hatirlatmalari(
        now=datetime(2026, 1, 15, 5, 45, tzinfo=UTC)) == 0


# ===================== 3) VARDIYAYA BASLAMAMA ============================= #

def test_OKUTMA_YOKSA_YONETIME_uyari(sched, push_spy):
    _plan(sched.conn, sched.tid, sched.gid)
    # Vardiya 06:00Z basladi; 15 dk tolerans -> 06:20Z'de uyari.
    n = vardiya_baslamadi_uyarilari(
        now=datetime(2026, 1, 15, 6, 20, tzinfo=UTC))
    assert n == 1
    satirlar = _bildirimler(sched.conn, sched.tid, "vardiya_baslamadi")
    assert len(satirlar) == 1
    # UYARI YONETIME GIDER: personele "gelmedin" demek faydasiz bicim;
    # sorunu cozecek kisi yoneticidir.
    assert push_spy[0]["target_roles"] == ("admin", "yonetici")


def test_OKUTMA_VARSA_uyari_GITMEZ(sched, push_spy):
    _plan(sched.conn, sched.tid, sched.gid)
    cid = uuid.uuid4()
    sched.conn.execute(
        "INSERT INTO checkpoint (id, tenant_id, ad, nfc_tag_uid, aktif) "
        "VALUES (%s,%s,%s,%s,true)", (cid, sched.tid, "CP", f"N-{cid.hex[:8]}"))
    sched.conn.execute(
        "INSERT INTO scan_event (tenant_id, guard_id, checkpoint_id, "
        "nfc_tag_uid, okutma_zamani, idempotency_key) "
        "VALUES (%s,%s,%s,%s,%s,%s)",
        (sched.tid, sched.gid, cid, "NFC",
         datetime(2026, 1, 15, 6, 5, tzinfo=UTC), uuid.uuid4().hex))
    assert vardiya_baslamadi_uyarilari(
        now=datetime(2026, 1, 15, 6, 20, tzinfo=UTC)) == 0
    assert push_spy == []


def test_BASLAMADI_IDEMPOTENT(sched, push_spy):
    _plan(sched.conn, sched.tid, sched.gid)
    an = datetime(2026, 1, 15, 6, 20, tzinfo=UTC)
    assert vardiya_baslamadi_uyarilari(now=an) == 1
    assert vardiya_baslamadi_uyarilari(now=an) == 0
    assert len(push_spy) == 1


def test_TOLERANS_DOLMADAN_uyari_YOK(sched):
    _plan(sched.conn, sched.tid, sched.gid)
    # 06:10Z: 10 dakika gecti, tolerans 15.
    assert vardiya_baslamadi_uyarilari(
        now=datetime(2026, 1, 15, 6, 10, tzinfo=UTC)) == 0


def test_BASLAMADI_KAPALIYSA_uyari_YOK(owner_conn):
    tid = _tenant(owner_conn, baslamadi=0)
    gid = _guard(owner_conn, tid)
    _plan(owner_conn, tid, gid)
    try:
        assert vardiya_baslamadi_uyarilari(
            now=datetime(2026, 1, 15, 6, 20, tzinfo=UTC)) == 0
    finally:
        owner_conn.execute("DELETE FROM tenant WHERE id = %s", (tid,))


def test_COK_ESKI_vardiya_icin_uyari_YOK(sched):
    """Ust sinir (tolerans+60 dk): her kosumda butun gunu taramak,
    dedup sayesinde bildirim uretmez ama gereksiz sorgu olurdu."""
    _plan(sched.conn, sched.tid, sched.gid)
    # 09:00Z: vardiya 3 saat once basladi.
    assert vardiya_baslamadi_uyarilari(
        now=datetime(2026, 1, 15, 9, 0, tzinfo=UTC)) == 0


# ===================== 4) TESIS IZOLASYONU ================================ #

def test_BASKA_TESISIN_plani_HATIRLATILMAZ(owner_conn, push_spy):
    """Zamanlayici her tenant icin RLS baglami kurar; A'nin gorevi B'nin
    planini gormemeli."""
    a = _tenant(owner_conn)
    b = _tenant(owner_conn)
    gid_b = _guard(owner_conn, b)
    _plan(owner_conn, b, gid_b)
    try:
        vardiya_hatirlatmalari(now=datetime(2026, 1, 15, 5, 45, tzinfo=UTC))
        assert _bildirimler(owner_conn, a, "vardiya_hatirlatma") == []
        assert len(_bildirimler(owner_conn, b, "vardiya_hatirlatma")) == 1
    finally:
        owner_conn.execute("DELETE FROM tenant WHERE id IN (%s,%s)", (a, b))


# ============== (P210) 5 DAKIKA KADEMESI GERCEKTEN AYARLANABILIYOR ========= #

def test_BES_DAKIKA_kademesi_AYARLANABILIR_ve_CALISIR(owner_conn, push_spy):
    """(P210 madde 4) Ses dosyasi "5 dk kala" anonsu icin uretildi;
    ayarin o degeri gercekten kabul ettigini ve pencerenin tuttugunu
    olcuyoruz.

    P207'de varsayilan 15 dk ve en fazla 3 kademeydi; 5 SINIRLARIN
    ICINDE (1..240) ve tek basina da yazilabiliyor.
    """
    from app.scheduler.service import hatirlatma_kademeleri

    assert hatirlatma_kademeleri("5") == [5]
    assert hatirlatma_kademeleri("30,15,5") == [30, 15, 5]

    tid = _tenant(owner_conn, kademe="5")
    gid = _guard(owner_conn, tid)
    _plan(owner_conn, tid, gid)
    try:
        # Vardiya 06:00Z; 5 dakika kala = 05:55Z.
        assert vardiya_hatirlatmalari(
            now=datetime(2026, 1, 15, 5, 55, tzinfo=UTC)) == 1
        satirlar = _bildirimler(owner_conn, tid, "vardiya_hatirlatma")
        assert satirlar[0][1]["dakika"] == 5
        # 6 dakika kala PENCERE DISI (kademe-1 < kalan <= kademe).
        assert vardiya_hatirlatmalari(
            now=datetime(2026, 1, 15, 5, 53, tzinfo=UTC)) == 0
    finally:
        owner_conn.execute("DELETE FROM tenant WHERE id = %s", (tid,))


def test_BES_DAKIKA_hatirlatmasi_VARDIYA_KANALINDAN_gider():
    """Zincirin son halkasi: 5 dk kala giden bildirim, ses dosyasinin
    uretildigi kanaldan calmali."""
    from app.push_kanal import KANAL_VARDIYA, VARDIYA_SES_ADI, kanal_sec, ses_adi

    assert kanal_sec("vardiya_hatirlatma", sesli=True) == KANAL_VARDIYA
    assert ses_adi("vardiya_hatirlatma", sesli=True) == f"{VARDIYA_SES_ADI}.caf"
