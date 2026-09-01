"""(P192 §2) KASA TUTARLILIGI — kabul olcutleri 4 ve 5 icin KALICI KAPI.

  4. Banka tahsilati BIR BANKA HESABINA yazilir, toplamlar tutar.
  5. Onay bekleyen gider bakiyeyi DUSURMEZ; onaylanabilir/reddedilebilir.

Olculen kusurlar (`docs/finans-analiz.md`):
  * P191 banka tahsilatlari `kasa_id=NULL` yaziliyordu: hicbir kasa
    bakiyesinde gorunmuyor ama genel toplamda sayiliyordu.
  * `kasa_bakiyeleri` `durum` suzgeci uygulamiyordu: onay bekleyen gider
    bakiyeyi SIMDIDEN dusuruyordu.
  * `durum='onay_bekliyor'` vardi ama ONAYLAYAN UC YOKTU.
"""
from __future__ import annotations

import uuid
from datetime import date

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
        "kod": f"KS{_sfx()}", "ad": "P192 Kasa", "acilis_bakiye_kurus": 500000})
    assert r.status_code == 201, r.text
    return r.json()


def _kasa_satiri(client, adm, kasa_id) -> dict:
    liste = client.get("/finans/kasa-bakiyeleri", headers=adm).json()["items"]
    return next(k for k in liste if k["kasa_id"] == kasa_id)


def _gider(client, adm, kasa_id, tutar, durum):
    r = client.post("/finans/hareketler", headers=adm, json={"satirlar": [
        {"tip": "gider", "tutar_kurus": tutar, "kasa_id": kasa_id, "durum": durum}]})
    assert r.status_code == 201, r.text
    return r.json()["items"][0]


# ==================== OLCUT 5: ONAY BEKLEYEN GIDER ========================== #
def test_onay_bekleyen_gider_bakiyeyi_dusurmez(client, adm, kasa):
    once = _kasa_satiri(client, adm, kasa["id"])
    assert once["bakiye_kurus"] == 500000 and once["bekleyen_cikis_kurus"] == 0

    _gider(client, adm, kasa["id"], 120000, "onay_bekliyor")

    sonra = _kasa_satiri(client, adm, kasa["id"])
    # Bakiye DEGISMEDI...
    assert sonra["bakiye_kurus"] == 500000
    # ...ama tutar KAYBOLMADI: ayri gosterilir ("bakiye X, bekleyen Y").
    assert sonra["bekleyen_cikis_kurus"] == 120000

    toplam = client.get("/finans/kasa-bakiyeleri", headers=adm).json()
    assert toplam["bekleyen_cikis_toplam_kurus"] >= 120000


def test_onaylayinca_bakiyeden_duser(client, adm, kasa):
    hareket = _gider(client, adm, kasa["id"], 80000, "onay_bekliyor")
    r = client.post(
        f"/finans/hareketler/{hareket['id']}/onayla", headers=adm, json={})
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "odendi"

    satir = _kasa_satiri(client, adm, kasa["id"])
    assert satir["bakiye_kurus"] == 500000 - 80000
    assert satir["bekleyen_cikis_kurus"] == 0


def test_reddedilen_gider_ne_bakiyeye_ne_beklemeye_girer(client, adm, kasa):
    hareket = _gider(client, adm, kasa["id"], 90000, "onay_bekliyor")
    r = client.post(
        f"/finans/hareketler/{hareket['id']}/reddet", headers=adm,
        json={"aciklama": "Fatura eksik"})
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "iptal"

    satir = _kasa_satiri(client, adm, kasa["id"])
    assert satir["bakiye_kurus"] == 500000
    # REDDEDILEN "bekleyen" DEGILDIR: hic gerceklesmeyecegi belli.
    assert satir["bekleyen_cikis_kurus"] == 0


def test_zaten_onaylanmis_hareket_tekrar_onaylanamaz(client, adm, kasa):
    hareket = _gider(client, adm, kasa["id"], 10000, "odendi")
    r = client.post(
        f"/finans/hareketler/{hareket['id']}/onayla", headers=adm, json={})
    assert r.status_code == 409
    assert r.json()["error"]["code"] == "conflict"


def test_onay_uclari_denetime_yazar(client, adm, kasa, world, owner_conn):
    hareket = _gider(client, adm, kasa["id"], 11000, "onay_bekliyor")
    client.post(f"/finans/hareketler/{hareket['id']}/onayla", headers=adm, json={})
    say = owner_conn.execute(
        "SELECT count(*) FROM audit_log WHERE tenant_id=%s "
        "AND action='finans_hareket_onay' AND resource_id=%s",
        (str(world["a"]), hareket["id"]),
    ).fetchone()[0]
    assert say == 1


def test_onay_uclari_sakine_kapali(client, world, kasa, adm):
    hareket = _gider(client, adm, kasa["id"], 12000, "onay_bekliyor")
    res = _headers(client, world["slug_a"], world["resident_a"])
    for yol in ("onayla", "reddet"):
        r = client.post(
            f"/finans/hareketler/{hareket['id']}/{yol}", headers=res, json={})
        assert r.status_code == 403, yol


# ==================== OLCUT 4: BANKA TAHSILATI HESABA ====================== #
@pytest.fixture
def banka_hesabi(client, adm):
    r = client.post("/kasalar", headers=adm, json={
        "kod": f"BN{_sfx()}", "ad": "Site Banka", "banka_mi": True,
        "iban": f"TR{uuid.uuid4().int % 10**24:024d}",
        "acilis_bakiye_kurus": 0})
    assert r.status_code == 201, r.text
    return r.json()


def test_banka_tahsilati_secilen_hesaba_yazilir(
    client, adm, world, banka_hesabi, owner_conn
):
    """Ekstre HANGI HESABIN ekstresiyse tahsilat oraya girer.

    Onceden `kasa_id=NULL` yaziliyordu: para hicbir kasa bakiyesinde
    gorunmuyor ama genel toplamda sayiliyordu — kasa toplamlari genel
    toplamla TUTMUYORDU."""
    resident = _headers(client, world["slug_a"], world["resident_a"])
    resident_id = client.get("/me", headers=resident).json()["id"]
    unit = client.post("/units", headers=adm, json={
        "no": f"BK-{_sfx()}", "blok": "A"}).json()
    client.post(f"/units/{unit['id']}/residents", headers=adm,
                json={"user_id": resident_id, "rol_tipi": "malik"})
    # Kodun NASIL uretildigi (P30) bu testin konusu degil; eslestirmede
    # KULLANILDIGI konusu — dogrudan yazilir (P191 testleriyle ayni desen).
    kod = f"TS-{uuid.uuid4().hex[:6].upper().translate(str.maketrans('01IO', 'ABCD'))}"
    with owner_conn.cursor() as cur:
        cur.execute("UPDATE app_user SET odeme_kodu = %s WHERE id = %s",
                    (kod, resident_id))
    owner_conn.commit()
    client.post("/dues/assessments", headers=adm, json={
        "unit_id": unit["id"], "donem": "2035-07", "tutar_kurus": 40000})

    r = client.post("/banka/ice-aktar", headers=adm, json={
        "kaynak": "ekstre", "kasa_id": banka_hesabi["id"],
        "satirlar": [{"tarih": date.today().isoformat(), "tutar": 40000,
                      "aciklama": f"HAVALE {kod} AIDAT"}]})
    assert r.status_code == 201, r.text
    kosum = client.post("/banka/eslestir", headers=adm)
    assert kosum.status_code == 200, kosum.text

    satir = _kasa_satiri(client, adm, banka_hesabi["id"])
    assert satir["banka_mi"] is True
    assert satir["bakiye_kurus"] == 40000

    # ...ve genel toplam kasalarin toplamiyla TUTAR.
    liste = client.get("/finans/kasa-bakiyeleri", headers=adm).json()
    assert liste["genel_toplam_kurus"] == sum(
        k["bakiye_kurus"] for k in liste["items"]
    )


def test_kasa_verilmeyen_ekstre_de_bir_hesaba_baglanir(client, adm, owner_conn, world):
    r = client.post("/banka/ice-aktar", headers=adm, json={
        "kaynak": "ekstre",
        "satirlar": [{"tarih": date.today().isoformat(), "tutar": 1234,
                      "aciklama": f"SERBEST {_sfx()}"}]})
    assert r.status_code == 201, r.text
    bos = owner_conn.execute(
        "SELECT count(*) FROM bank_transaction WHERE tenant_id=%s AND kasa_id IS NULL",
        (str(world["a"]),),
    ).fetchone()[0]
    assert bos == 0
