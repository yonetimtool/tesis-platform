"""(P252 §4) Rapor isci kilitlenmesi — kok neden ve duzeltme.

OLCULEN (db gunlugu, bes tam kosunun besinde ayni):

    Process A: DELETE FROM tenant WHERE id IN ($1,$2)          (fikstur)
    Process B: UPDATE rapor_isi SET durum=..., dosya_key=...    (isci)
    CONTEXT:  while deleting tuple (...) in relation "rapor_isi"

Isci TEK islemde `uretiliyor` yazip rapor uretiyor, dosyayi yukluyor ve
ayni satiri `hazir` yapiyordu. Satirin son surumu ayni isleme ait
oldugundan ikinci UPDATE yabanci anahtar denetimini yeniden calistirir
(KEY SHARE: tenant/app_user) — cascade silme o satirlari tutarken bu
satiri bekledigi icin ikisi kilitlenir. Ayrica uretim/yukleme boyunca
islem "idle in transaction" kalir (goc 0074: 60 sn).

KILIT: uretim/yukleme aninda isin satiri KILITSIZ olmali (baska bir
islem `FOR UPDATE NOWAIT` alabilmeli). Duzeltme oncesi bu test duser.
"""
from __future__ import annotations

import json
import uuid

import psycopg
import pytest

from app import rapor_kuyruk
from app.config import settings
from app.tasks import _async_calistir


def _is(owner_conn, world, *, durum="bekliyor", yas_dk=0) -> uuid.UUID:
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND role='yonetici' LIMIT 1",
            (world["a"],),
        )
        uid = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO rapor_isi (tenant_id, user_id, kod, bicim, parametre, durum, created_at) "
            "VALUES (%s,%s,'dokuman_listesi','excel',%s,%s, now() - make_interval(mins => %s)) "
            "RETURNING id",
            (world["a"], uid, json.dumps({}), durum, yas_dk),
        )
        return cur.fetchone()[0]


def _durum(owner_conn, is_id):
    with owner_conn.cursor() as cur:
        cur.execute("SELECT durum, dosya_key FROM rapor_isi WHERE id=%s", (is_id,))
        return cur.fetchone()


@pytest.fixture
def yukleme_ani(monkeypatch):
    """`sunucudan_yukle` aninda cagrilan kanca — gercek yukleme de yapilir."""
    kancalar = []
    gercek = rapor_kuyruk.sunucudan_yukle

    def sahte(key, icerik, tur):
        for k in kancalar:
            k()
        return gercek(key, icerik, tur)

    monkeypatch.setattr(rapor_kuyruk, "sunucudan_yukle", sahte)
    return kancalar


def test_YUKLEME_ANINDA_is_satiri_KILITSIZ(world, owner_conn, yukleme_ani):
    is_id = _is(owner_conn, world)
    olcum = {}

    def kilit_dene():
        with psycopg.connect(settings.owner_dsn, connect_timeout=10) as c:
            try:
                c.execute("SELECT 1 FROM rapor_isi WHERE id=%s FOR UPDATE NOWAIT", (str(is_id),))
                olcum["kilitsiz"] = True
            except psycopg.errors.LockNotAvailable:
                olcum["kilitsiz"] = False
            c.rollback()

    yukleme_ani.append(kilit_dene)
    sonuc = _async_calistir(lambda: rapor_kuyruk.isi_uret(is_id))
    assert sonuc["durum"] == "hazir", sonuc
    assert olcum == {"kilitsiz": True}, "uretim/yukleme sirasinda isci satiri KILITLI tutuyor"
    durum, key = _durum(owner_conn, is_id)
    assert durum == "hazir" and key


def test_URETIM_SIRASINDA_SILINEN_is_sessizce_birakilir(world, owner_conn, yukleme_ani):
    """Tesis/is uretim sirasinda silinirse isci hata firlatmaz, beklemez."""
    is_id = _is(owner_conn, world)

    def sil():
        with psycopg.connect(settings.owner_dsn, autocommit=True, connect_timeout=10) as c:
            c.execute("SET lock_timeout = '3s'")
            c.execute("DELETE FROM rapor_isi WHERE id=%s", (str(is_id),))

    yukleme_ani.append(sil)
    assert _async_calistir(lambda: rapor_kuyruk.isi_uret(is_id)) == {"durum": "bulunamadi"}
    assert _durum(owner_conn, is_id) is None


def test_YETIM_is_yeniden_uretilir_TAZE_uretiliyor_atlanir(world, owner_conn):
    """`uretiliyor` artik ayri islemde yaziliyor: isci olurse geri alinmaz.
    Yeniden teslimde uzun suredir bekleyen YETIM is uretilir; tazesi (baska
    bir isci calisiyor) atlanir."""
    taze = _is(owner_conn, world, durum="uretiliyor")
    assert _async_calistir(lambda: rapor_kuyruk.isi_uret(taze)) == {"durum": "uretiliyor"}
    yetim = _is(owner_conn, world, durum="uretiliyor", yas_dk=60)
    assert _async_calistir(lambda: rapor_kuyruk.isi_uret(yetim))["durum"] == "hazir"
    assert _durum(owner_conn, yetim)[0] == "hazir"
