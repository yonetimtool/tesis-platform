"""(P192 §6) SORUNLU YERLER — kabul olcutleri 13, 14, 16.

  13. `budget.py` denetim izi yaziyor.
  14. Cift tiklama iki tahsilat yazmiyor.
  16. Para hesaplarinda float kalmadi.

(15 — tahakkuk duzeltme — `test_p192_tahakkuk.py`de kilitli.)
"""
from __future__ import annotations

import uuid
from decimal import Decimal

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


# ==================== OLCUT 13: BUTCE DENETIM IZI ========================== #
def test_butce_defterine_yazma_DENETIME_islenir(client, adm, world, owner_conn):
    """`budget.py`de tek bir `audit_user` cagrisi YOKTU: seffaflik
    yayinini besleyen defter, denetim izi olmadan yaziliyordu."""
    kategori = client.post("/budget/categories", headers=adm, json={
        "ad": f"Denetim-{_sfx()}", "tip": "gider"}).json()
    kayit = client.post("/budget/entries", headers=adm, json={
        "kategori_id": kategori["id"], "tutar_kurus": 4321,
        "tarih": "2042-01-10"})
    assert kayit.status_code == 201, kayit.text

    say = owner_conn.execute(
        "SELECT count(*) FROM audit_log WHERE tenant_id=%s AND resource_id=%s",
        (str(world["a"]), kayit.json()["id"]),
    ).fetchone()[0]
    assert say == 1


def test_butce_silme_TERS_KAYIT_yazar_ve_denetime_islenir(
    client, adm, world, owner_conn
):
    """Defterde DELETE yetkisi yok (goc 0047): silme, ters kayit."""
    kategori = client.post("/budget/categories", headers=adm, json={
        "ad": f"Silme-{_sfx()}", "tip": "gider"}).json()
    kayit = client.post("/budget/entries", headers=adm, json={
        "kategori_id": kategori["id"], "tutar_kurus": 5555,
        "tarih": "2042-02-10"}).json()

    assert client.delete(
        f"/budget/entries/{kayit['id']}", headers=adm
    ).status_code == 204

    # SATIR DURUYOR (silinmedi), ters kayiti yazildi.
    kalan = owner_conn.execute(
        "SELECT count(*) FROM finansal_hareket WHERE tenant_id=%s AND id=%s",
        (str(world["a"]), kayit["id"]),
    ).fetchone()[0]
    assert kalan == 1
    ters = owner_conn.execute(
        "SELECT count(*) FROM finansal_hareket WHERE tenant_id=%s "
        "AND ters_kayit_id=%s", (str(world["a"]), kayit["id"]),
    ).fetchone()[0]
    assert ters == 1

    # ...ve listede GORUNMUYOR (ikisi birbirini goturuyor).
    liste = client.get("/budget/entries", headers=adm, params={
        "kategori_id": kategori["id"], "limit": 200}).json()["items"]
    assert all(i["id"] != kayit["id"] for i in liste)


# ==================== OLCUT 14: CIFT TIKLAMA KORUMASI ====================== #
def test_ayni_idempotency_anahtari_IKINCI_tahsilat_yazmaz(client, adm, world):
    """Zaman asimi sonrasi tekrar (kullanici "kaydedilmedi" sanip yeniden
    basar) kasada IKI hareket olusturabilirdi."""
    kasa = client.post("/kasalar", headers=adm, json={
        "kod": f"CT{_sfx()}", "ad": "Kasa"}).json()
    anahtar = uuid.uuid4().hex
    govde = {"kasa_id": kasa["id"], "tutar_kurus": 33333}

    ilk = client.post("/finans/tahsilat", headers={**adm, "Idempotency-Key": anahtar},
                      json=govde)
    assert ilk.status_code == 201, ilk.text
    ikinci = client.post("/finans/tahsilat",
                         headers={**adm, "Idempotency-Key": anahtar}, json=govde)
    # TEKRAR = AYNI YANIT, YENI KAYIT DEGIL.
    assert ikinci.status_code == 200
    assert ikinci.json()["id"] == ilk.json()["id"]

    bakiye = next(
        k for k in client.get("/finans/kasa-bakiyeleri", headers=adm).json()["items"]
        if k["kasa_id"] == kasa["id"]
    )
    assert bakiye["bakiye_kurus"] == 33333


def test_ayni_anahtar_FARKLI_govde_409(client, adm):
    """Ayni kimlikle baska bir tutar gondermek istemci kusurudur; sessizce
    eski kaydi dondurmek "kaydedildi" deyip PARAYI KAYDETMEMEK olurdu."""
    kasa = client.post("/kasalar", headers=adm, json={
        "kod": f"CF{_sfx()}", "ad": "Kasa"}).json()
    anahtar = uuid.uuid4().hex
    client.post("/finans/tahsilat", headers={**adm, "Idempotency-Key": anahtar},
                json={"kasa_id": kasa["id"], "tutar_kurus": 100})
    r = client.post("/finans/tahsilat", headers={**adm, "Idempotency-Key": anahtar},
                    json={"kasa_id": kasa["id"], "tutar_kurus": 200})
    assert r.status_code == 409


# ======================== OLCUT 16: FLOAT KALMADI ========================== #
def test_sayac_dagitimi_ARA_HESAPTA_float_kullanmaz():
    """Ikili gosterimde 12.3 - 12.0 = 0.2999999999999989 cikar ve birim
    fiyatla carpilinca KURUS KAYAR. Para hesabinda float YOK."""
    from app.borclandirma import sayac_tuketim_dagitimi

    paylar, ortak = sayac_tuketim_dagitimi(
        ana_tuketim=12.3,
        bolum_tuketimleri=[12.0],
        birim_fiyat_kurus=1000,
        ortak_alan_yuzde=100,
    )
    # 0.3 birim x 1000 kurus = 300 kurus. Float ile 299 cikardi.
    assert ortak == 300
    assert paylar == [12000 + 300]


def test_oransal_dagitim_kurus_kaybetmez_ve_DETERMINISTIK():
    """En buyuk kalan yontemi: dagitilan toplam HER ZAMAN girdiye esit.
    Beraberlikte KUCUK INDEKS once — ayni girdi iki farkli dagitim
    uretmemeli."""
    from app.borclandirma import oransal_dagit

    paylar = oransal_dagit(100001, [1, 1, 1])
    assert sum(paylar) == 100001
    assert paylar == [33334, 33334, 33333]

    # Agirliksiz daire ATLANIR (None), sessizce sifir borclandirilmaz.
    kismi = oransal_dagit(1000, [Decimal("2"), None, Decimal("0")])
    assert kismi == [1000, None, None]


def test_esit_dagit_kurus_kaybetmez():
    from app.borclandirma import esit_dagit

    assert sum(esit_dagit(10001, 3)) == 10001
