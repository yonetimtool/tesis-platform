"""(P203 §5) FAZLA MESAI — uc davranisi ve TEK DEFTER kurali.

===========================================================================
P192 TEK DEFTER KORUNDU
===========================================================================
Mesai gideri AYRI BIR TABLOYA YAZILMAZ: `finansal_hareket`e
`tip='gider'` olarak duser. Ikinci bir tablo, "bu ay ne kadar gider
yaptik" sorusunu iki yerden toplamak demekti.

OTOMATIK YAZMA YOK: hareket `durum='onay_bekliyor'` ile yazilir ve
bakiyeyi DUSURMEZ (P192 karari + istegin acik sarti).
"""
from __future__ import annotations

import datetime as dt
import uuid

import pytest


def _giris(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def mesai_duzeni(client, world, owner_conn):
    """12 saatlik vardiya; 1. hafta 5 gun (60s), 2. hafta 2 gun (24s).

    AY TOPLAMI 84 < 90 (iki haftanin normali) — yani AY UZERINDEN
    hesaplansaydi FAZLA MESAI CIKMAZDI. Hafta hafta bakinca ilk
    haftada 15 saat fazla var. Fixture bu ayrimi olculebilir kiliyor.
    """
    ek = uuid.uuid4().hex[:6]
    with owner_conn.cursor() as cur:
        cur.execute("DELETE FROM vardiya_plani WHERE tenant_id=%s", (world["a"],))
        cur.execute(
            "DELETE FROM finansal_hareket WHERE tenant_id=%s "
            "AND aciklama LIKE 'Fazla mesai%%'", (world["a"],))
        cur.execute(
            "INSERT INTO shift (tenant_id, ad, baslangic_saat, bitis_saat) "
            "VALUES (%s,%s,'08:00','20:00') RETURNING id", (world["a"], f"M{ek}"))
        sid = cur.fetchone()[0]
        cur.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND role='security' LIMIT 1",
            (world["a"],))
        uid = cur.fetchone()[0]
        cur.execute("DELETE FROM personel_kayit WHERE tenant_id=%s AND app_user_id=%s",
                    (world["a"], uid))
        cur.execute(
            "INSERT INTO personel_kayit (tenant_id, ad, app_user_id, maas_kurus) "
            "VALUES (%s,'Guard A',%s,2250000)", (world["a"], uid))
        for i in range(5):                       # 1. hafta: 60 saat
            cur.execute(
                "INSERT INTO vardiya_plani (tenant_id, shift_id, tarih, user_id) "
                "VALUES (%s,%s,%s,%s)",
                (world["a"], sid, dt.date(2026, 9, 1) + dt.timedelta(days=i), uid))
        for i in range(2):                       # 2. hafta: 24 saat
            cur.execute(
                "INSERT INTO vardiya_plani (tenant_id, shift_id, tarih, user_id) "
                "VALUES (%s,%s,%s,%s)",
                (world["a"], sid, dt.date(2026, 9, 8) + dt.timedelta(days=i), uid))
    yield {"user_id": str(uid), "shift_id": str(sid)}
    with owner_conn.cursor() as cur:
        cur.execute("DELETE FROM vardiya_plani WHERE tenant_id=%s", (world["a"],))
        cur.execute("DELETE FROM shift WHERE id=%s", (sid,))
        cur.execute("DELETE FROM personel_kayit WHERE tenant_id=%s AND app_user_id=%s",
                    (world["a"], uid))
        cur.execute(
            "DELETE FROM finansal_hareket WHERE tenant_id=%s "
            "AND aciklama LIKE 'Fazla mesai%%'", (world["a"],))


def _ozet(client, h, yil=2026, ay=9):
    r = client.get("/mesai/ozet", headers=h, params={"yil": yil, "ay": ay})
    assert r.status_code == 200, r.text
    return r.json()


# ============================ HESAP ======================================= #

def test_OZET_hafta_hafta_hesaplar(client, world, mesai_duzeni):
    """AY TOPLAMIYLA hesaplansaydi 0 cikardi (84 < 90)."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    d = _ozet(client, h)
    k = next(k for k in d["kisiler"] if k["user_id"] == mesai_duzeni["user_id"])
    assert k["toplam_saat"] == 84.0
    assert k["fazla_saat"] == 15.0, "ay toplamiyla hesaplansaydi 0 olurdu"


def test_SAATLIK_UCRET_aylikten_turetilir(client, world, mesai_duzeni):
    """2.250.000 / 225 = 10.000 kurus (30 gun x 7,5 saat)."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    k = next(k for k in _ozet(client, h)["kisiler"]
             if k["user_id"] == mesai_duzeni["user_id"])
    assert k["saatlik_ucret_kurus"] == 10_000
    # 15 saat x 10.000 x 1.5 = 225.000
    assert k["fazla_mesai_kurus"] == 225_000


def test_KAYNAK_ACIKCA_PLAN_der(client, world, mesai_duzeni):
    """Sistemde gercek mesai kaydi (turnike/QR) YOK. Uydurulmus bir
    "gerceklesen" uretmek, PARAYA donusen bir sayiyi tahmine
    dayandirmak olurdu; yanit bunu ACIKCA soyler."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    assert _ozet(client, h)["kaynak"] == "plan"


def test_UCRETI_TANIMSIZ_kisi_ISARETLENIR_sifir_DEGIL(
    client, world, mesai_duzeni, owner_conn
):
    """Sifir yazmak, yoneticiye "mesai yok" demenin sessiz ve yanlis
    yoluydu."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    with owner_conn.cursor() as cur:
        cur.execute("UPDATE personel_kayit SET maas_kurus=NULL, "
                    "saatlik_ucret_kurus=NULL WHERE tenant_id=%s AND app_user_id=%s",
                    (world["a"], mesai_duzeni["user_id"]))
    k = next(k for k in _ozet(client, h)["kisiler"]
             if k["user_id"] == mesai_duzeni["user_id"])
    assert k["ucret_tanimsiz"] is True
    assert k["fazla_mesai_kurus"] is None
    assert k["fazla_saat"] == 15.0, "saat yine de hesaplanmali"


def test_KATSAYI_TENANT_AYARINDAN_gelir(client, world, mesai_duzeni, owner_conn):
    """(4857/41) Varsayilan 1.50 ama toplu is sozlesmesi daha yuksek
    olabilir; yazilim mesru bir sozlesmeyi imkansiz kilmamali."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    assert _ozet(client, h)["katsayi"] == 1.5
    with owner_conn.cursor() as cur:
        cur.execute("UPDATE tenant SET mesai_katsayisi=2.00 WHERE id=%s", (world["a"],))
    try:
        d = _ozet(client, h)
        assert d["katsayi"] == 2.0
        k = next(k for k in d["kisiler"] if k["user_id"] == mesai_duzeni["user_id"])
        assert k["fazla_mesai_kurus"] == 300_000     # 15 x 10.000 x 2
    finally:
        with owner_conn.cursor() as cur:
            cur.execute("UPDATE tenant SET mesai_katsayisi=1.50 WHERE id=%s",
                        (world["a"],))


# ====================== TEK DEFTER + ONAY KUYRUGU ========================= #

def test_GIDERE_YAZ_TEK_DEFTERE_ve_ONAY_BEKLIYOR(
    client, world, mesai_duzeni, owner_conn
):
    """KABUL KRITERI 11 + 12.

    Mesai gideri `finansal_hareket`e duser (P192 TEK DEFTER) ve
    `onay_bekliyor` ile yazilir (otomatik yazma YOK, bakiye
    DUSMEZ).
    """
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/mesai/gidere-yaz", headers=h, json={
        "yil": 2026, "ay": 9,
        "satirlar": [{"user_id": mesai_duzeni["user_id"]}]})
    assert r.status_code == 201, r.text
    assert len(r.json()) == 1

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT tip, yon, tutar_kurus, durum, user_id FROM finansal_hareket "
            "WHERE tenant_id=%s AND aciklama LIKE 'Fazla mesai%%'", (world["a"],))
        satir = cur.fetchone()
    assert satir is not None, "TEK DEFTERE yazilmali"
    tip, yon, tutar, durum, uid = satir
    assert tip == "gider" and yon == "cikis"
    assert tutar == 225_000
    assert durum == "onay_bekliyor", "otomatik gider YAZILMAMALI"
    assert str(uid) == mesai_duzeni["user_id"]


def test_AYRI_MESAI_TABLOSU_ACILMADI(owner_conn):
    """P192 TEK DEFTER kuralinin yapisal kilidi."""
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT tablename FROM pg_tables WHERE schemaname='public' "
            "AND (tablename LIKE '%mesai%' OR tablename LIKE '%overtime%')")
        assert cur.fetchall() == [], "mesai icin AYRI TABLO acilmis"


def test_YAZILDIKTAN_SONRA_ozet_ISARETLER(client, world, mesai_duzeni):
    """Ayni ay iki kez yazilmasin diye yonetici gormeli."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    assert _ozet(client, h)["kisiler"][0]["gidere_yazildi"] is False
    client.post("/mesai/gidere-yaz", headers=h, json={
        "yil": 2026, "ay": 9, "satirlar": [{"user_id": mesai_duzeni["user_id"]}]})
    k = next(k for k in _ozet(client, h)["kisiler"]
             if k["user_id"] == mesai_duzeni["user_id"])
    assert k["gidere_yazildi"] is True


def test_SAAT_DUZELTILEBILIR(client, world, mesai_duzeni, owner_conn):
    """Hesap PLAN uzerinden; gercegi bilen yonetici saati
    duzeltebilmeli."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/mesai/gidere-yaz", headers=h, json={
        "yil": 2026, "ay": 9,
        "satirlar": [{"user_id": mesai_duzeni["user_id"],
                      "gerceklesen_fazla_saat": 10}]})
    assert r.status_code == 201, r.text
    with owner_conn.cursor() as cur:
        cur.execute("SELECT tutar_kurus FROM finansal_hareket WHERE tenant_id=%s "
                    "AND aciklama LIKE 'Fazla mesai%%'", (world["a"],))
        assert cur.fetchone()[0] == 150_000       # 10 x 10.000 x 1.5


def test_UCRETI_TANIMSIZ_kisi_SESSIZCE_ATLANMAZ(
    client, world, mesai_duzeni, owner_conn
):
    """Atlamak, yoneticiye "yazildi" deyip YAZMAMAK olurdu."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    with owner_conn.cursor() as cur:
        cur.execute("UPDATE personel_kayit SET maas_kurus=NULL "
                    "WHERE tenant_id=%s AND app_user_id=%s",
                    (world["a"], mesai_duzeni["user_id"]))
    r = client.post("/mesai/gidere-yaz", headers=h, json={
        "yil": 2026, "ay": 9, "satirlar": [{"user_id": mesai_duzeni["user_id"]}]})
    assert r.status_code == 422, r.text


def test_YAZMA_DENETIME_gecer(client, world, mesai_duzeni, owner_conn):
    """Para ureten bir hesabin kim tarafindan, hangi saat ve katsayiyla
    islendigi kayit altinda olmali."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    client.post("/mesai/gidere-yaz", headers=h, json={
        "yil": 2026, "ay": 9, "satirlar": [{"user_id": mesai_duzeni["user_id"]}]})
    with owner_conn.cursor() as cur:
        cur.execute("SELECT meta FROM audit_log WHERE tenant_id=%s "
                    "AND action='mesai_gidere_yaz' ORDER BY ts DESC LIMIT 1",
                    (world["a"],))
        meta = cur.fetchone()[0]
    assert meta["tutar_kurus"] == 225_000
    assert meta["katsayi"] == 1.5
    assert meta["donem"] == "2026-09"


# ============================== YETKI ===================================== #

def test_DENETCI_OKUR_YAZAMAZ(client, world, mesai_duzeni):
    h = _giris(client, world["slug_a"], world["denetci_a"])
    assert client.get("/mesai/ozet", headers=h,
                      params={"yil": 2026, "ay": 9}).status_code == 200
    r = client.post("/mesai/gidere-yaz", headers=h, json={
        "yil": 2026, "ay": 9, "satirlar": []})
    assert r.status_code == 403, r.text


def test_SAHA_MESAI_OZETINI_GOREMEZ(client, world, mesai_duzeni):
    """Ucret bilgisi PERSONEL VERISIDIR: bir gorevlinin baska
    gorevlilerin maasini gormesi icin sebep yok."""
    h = _giris(client, world["slug_a"], world["guard_a"])
    r = client.get("/mesai/ozet", headers=h, params={"yil": 2026, "ay": 9})
    assert r.status_code == 403, r.text
