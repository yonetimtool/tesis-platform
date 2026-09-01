"""(P192 §1) TEK DEFTER — kabul olcutleri 1-3 icin KALICI KAPI.

`docs/finans-analiz.md` uc kusur olcmustu ve bu dosya ucunu de kilitler:

  1. Vezneden girilen tahsilat sakinin borcunu KAPATMIYORDU.
  2. `/dues/payments` ile girilen odeme kasa bakiyesini ARTIRMIYORDU.
  3. "Tahsilat orani" iki ekranda IKI FARKLI rakam veriyordu.

Testler CANLI sunucuya vurur (bkz. conftest); para her yerde KURUS.
"""
from __future__ import annotations

import uuid

import pytest


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _sfx() -> str:
    return uuid.uuid4().hex[:6]


@pytest.fixture
def adm(client, world):
    return _headers(client, world["slug_a"], world["admin_a"])


@pytest.fixture
def kasa(client, adm):
    r = client.post("/kasalar", headers=adm, json={
        "kod": f"TD{_sfx()}", "ad": "P192 Kasa", "acilis_bakiye_kurus": 0})
    assert r.status_code == 201, r.text
    return r.json()


def _daire(client, adm):
    r = client.post("/units", headers=adm, json={"no": f"TD-{_sfx()}", "blok": "A"})
    assert r.status_code == 201, r.text
    return r.json()


def _tahakkuk(client, adm, unit_id, donem, tutar):
    r = client.post("/dues/assessments", headers=adm, json={
        "unit_id": unit_id, "donem": donem, "tutar_kurus": tutar})
    assert r.status_code == 201, r.text
    return r.json()["created"][0]


def _bakiye(client, adm, kasa_id) -> int:
    liste = client.get("/finans/kasa-bakiyeleri", headers=adm).json()["items"]
    return next(k for k in liste if k["kasa_id"] == kasa_id)["bakiye_kurus"]


def _daire_bakiye(client, adm, unit_id) -> int:
    return client.get(f"/units/{unit_id}/dues", headers=adm).json()["bakiye_kurus"]


# =========================== OLCUT 1: VEZNE -> BORC ========================= #
def test_vezneden_tahsilat_sakinin_borcunu_kapatir(client, adm, kasa):
    """OLCUT 1. Once `/finans/tahsilat` `finansal_hareket`e, daire bakiyesi
    ise `dues_payment`e bakiyordu; para giriyor, borc acik kaliyordu."""
    daire = _daire(client, adm)
    donem = "2029-01"
    tahakkuk = _tahakkuk(client, adm, daire["id"], donem, 60000)
    assert _daire_bakiye(client, adm, daire["id"]) == 60000

    r = client.post("/finans/tahsilat", headers=adm, json={
        "kasa_id": kasa["id"], "tutar_kurus": 60000,
        "unit_id": daire["id"], "assessment_id": tahakkuk["id"]})
    assert r.status_code == 201, r.text

    assert _daire_bakiye(client, adm, daire["id"]) == 0
    # ...ve ayni tahsilat aidat listesinde de gorunur (tek defter).
    odemeler = client.get(
        "/dues/payments", headers=adm, params={"unit_id": daire["id"]}
    ).json()["items"]
    assert [o["tutar_kurus"] for o in odemeler] == [60000]
    assert odemeler[0]["donem"] == donem  # donem tahakkuktan turedi


# =========================== OLCUT 2: AIDAT -> KASA ======================== #
def test_dues_payments_kasa_bakiyesini_artirir(client, adm, kasa):
    """OLCUT 2. `/dues/payments` `dues_payment`e yaziyordu ve o tablonun
    kasa bagi YOKTU: para "alindi" ama hicbir kasada gorunmuyordu."""
    daire = _daire(client, adm)
    tahakkuk = _tahakkuk(client, adm, daire["id"], "2029-02", 45000)
    once = _bakiye(client, adm, kasa["id"])

    r = client.post(
        "/dues/payments", headers={**adm, "Idempotency-Key": uuid.uuid4().hex},
        json={"unit_id": daire["id"], "assessment_id": tahakkuk["id"],
              "tutar_kurus": 45000, "yontem": "elden", "kasa_id": kasa["id"]},
    )
    assert r.status_code == 201, r.text

    assert _bakiye(client, adm, kasa["id"]) == once + 45000
    assert _daire_bakiye(client, adm, daire["id"]) == 0
    # Vezne listesinde de AYNI satir gorunur.
    hareketler = client.get(
        "/finans/hareketler", headers=adm, params={"limit": 200}
    ).json()["items"]
    assert any(h["id"] == r.json()["id"] for h in hareketler)


def test_dues_payments_kasa_verilmezse_de_bir_kasaya_yazilir(client, adm):
    """Kasa gonderilmediginde satir `kasa_id=NULL` KALMAZ.

    Kalsaydi para defterde gorunur, hicbir kasa bakiyesinde gorunmez ama
    genel toplamda sayilirdi — kasa toplamlari genel toplamla tutmazdi."""
    daire = _daire(client, adm)
    r = client.post(
        "/dues/payments", headers={**adm, "Idempotency-Key": uuid.uuid4().hex},
        json={"unit_id": daire["id"], "tutar_kurus": 1000, "yontem": "elden"},
    )
    assert r.status_code == 201, r.text
    hareket = next(
        h for h in client.get(
            "/finans/hareketler", headers=adm, params={"limit": 200}
        ).json()["items"] if h["id"] == r.json()["id"]
    )
    assert hareket["kasa_id"] is not None


# ===================== OLCUT 3: TEK RAKAM, HER EKRANDA ==================== #
def test_tahsilat_orani_her_ekranda_ayni(client, adm, world, kasa):
    """OLCUT 3. Rapor `dues_payment`ten, panel `finansal_hareket`ten
    hesapliyordu; ayni ay iki farkli rakam verebiliyordu."""
    donem = "2029-03"
    daire_a, daire_b = _daire(client, adm), _daire(client, adm)
    t_a = _tahakkuk(client, adm, daire_a["id"], donem, 100000)
    _tahakkuk(client, adm, daire_b["id"], donem, 100000)

    # Bir daire vezneden, oteki aidat ucundan odesin — IKI FARKLI YOL.
    client.post("/finans/tahsilat", headers=adm, json={
        "kasa_id": kasa["id"], "tutar_kurus": 100000,
        "unit_id": daire_a["id"], "assessment_id": t_a["id"]})

    rapor = client.get(
        "/reports/financial-summary", headers=adm, params={"donem": donem}
    ).json()["tahsilat"]
    board = client.get(f"/transparency/{donem}", headers=adm).json()["aidat"]

    assert rapor["tahakkuk_kurus"] == board["tahakkuk_kurus"] == 200000
    assert rapor["tahsilat_kurus"] == board["tahsilat_kurus"] == 100000
    assert rapor["tahsilat_orani_yuzde"] == board["tutar_orani_yuzde"] == 50
    assert rapor["geciken_daire_sayisi"] == board["geciken_daire_sayisi"] == 1


# ============================ IADE BORCU ACAR ============================== #
def test_iade_borcu_yeniden_acar(client, adm, kasa):
    """Iade edilen tahsilat borcu YENIDEN ACAR.

    Iade satiri borc atfini tasimasaydi para kasadan cikar ama borc kapali
    gorunurdu — sakin odemedigi bir borcu odenmis sanirdi."""
    daire = _daire(client, adm)
    tahakkuk = _tahakkuk(client, adm, daire["id"], "2029-04", 30000)
    tahsilat = client.post("/finans/tahsilat", headers=adm, json={
        "kasa_id": kasa["id"], "tutar_kurus": 30000,
        "unit_id": daire["id"], "assessment_id": tahakkuk["id"]}).json()
    assert _daire_bakiye(client, adm, daire["id"]) == 0

    r = client.post("/finans/iade", headers=adm, json={
        "hareket_id": tahsilat["id"], "tutar_kurus": 30000})
    assert r.status_code == 201, r.text
    assert _daire_bakiye(client, adm, daire["id"]) == 30000


# ====================== ESKI DEFTERE ARTIK YAZILMIYOR ===================== #
def test_eski_tablolara_yazilmiyor(client, adm, world, owner_conn, kasa):
    """`dues_payment` ve `budget_entry` ARTIK YAZILMAZ.

    Tablolar yerinde durur (goc 0083 satirlari deftere tasidi) ama yeni
    hicbir para hareketi oraya dusmez; duserse uc defter yeniden dogar."""
    tid = str(world["a"])

    def _say(tablo: str) -> int:
        return owner_conn.execute(
            f"SELECT count(*) FROM {tablo} WHERE tenant_id=%s", (tid,)
        ).fetchone()[0]

    once = (_say("dues_payment"), _say("budget_entry"))

    daire = _daire(client, adm)
    tahakkuk = _tahakkuk(client, adm, daire["id"], "2029-05", 5000)
    client.post(
        "/dues/payments", headers={**adm, "Idempotency-Key": uuid.uuid4().hex},
        json={"unit_id": daire["id"], "assessment_id": tahakkuk["id"],
              "tutar_kurus": 5000, "yontem": "elden", "kasa_id": kasa["id"]},
    )
    kategori = client.post("/budget/categories", headers=adm, json={
        "ad": f"Gider-{_sfx()}", "tip": "gider"}).json()
    client.post("/budget/entries", headers=adm, json={
        "kategori_id": kategori["id"], "tutar_kurus": 7000, "tarih": "2029-05-10"})

    assert (_say("dues_payment"), _say("budget_entry")) == once
