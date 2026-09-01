"""(P192 §3) KAYIP PARA VE EKSIK TAHAKKUK — kabul olcutleri 6, 7, 8, 15.

  6. Gecikme faizi BORC olarak yaziliyor ve tahsil edilebiliyor.
  7. Ayni doneme birden cok kalem yazilabiliyor; atlanan sessizce
     kaybolmuyor.
  8. Arsa payina ve metrekareye gore dagitim yapilabiliyor.
 15. Tahakkuk duzeltilebiliyor (ters kayitla).

Olculen kusurlar (`docs/finans-analiz.md`):
  * Faiz iki yerde hesaplaniyor ama HICBIR YERE yazilmiyordu; sakin ana
    borcunu odeyince faiz buharlasiyordu.
  * `UNIQUE (tenant, unit, donem)` ayni aya ikinci kalemi engelliyor ve
    toplu islemde carpisan satiri SESSIZCE atliyordu.
  * Arsa payi (KMK md. 20) dagitimi YOKTU.
  * Yanlis tahakkukun duzeltme yolu YOKTU.
"""
from __future__ import annotations

import uuid
from datetime import date, timedelta

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


def _daire(client, adm, **kw):
    govde = {"no": f"TH-{_sfx()}", "blok": "A"}
    govde.update(kw)
    r = client.post("/units", headers=adm, json=govde)
    assert r.status_code == 201, r.text
    return r.json()


def _tahakkuk(client, adm, unit_id, donem, tutar, **kw):
    govde = {"unit_id": unit_id, "donem": donem, "tutar_kurus": tutar}
    govde.update(kw)
    r = client.post("/dues/assessments", headers=adm, json=govde)
    assert r.status_code == 201, r.text
    return r.json()


def _bakiye(client, adm, unit_id) -> int:
    return client.get(f"/units/{unit_id}/dues", headers=adm).json()["bakiye_kurus"]


# ==================== OLCUT 7: AYNI DONEME COK KALEM ====================== #
def test_ayni_doneme_ikinci_kalem_yazilabilir(client, adm):
    """`UNIQUE (tenant, unit, donem)` bir VERI kurali gibi gorunuyordu ama
    yanlis bir IS kuraliydi: "Mart aidati + Mart cati onarimi" imkansizdi."""
    daire = _daire(client, adm)
    _tahakkuk(client, adm, daire["id"], "2031-03", 50000, kalem_tipi="aidat")
    ikinci = _tahakkuk(
        client, adm, daire["id"], "2031-03", 20000, kalem_tipi="olaganustu",
        aciklama="Cati onarimi",
    )
    assert ikinci["atlanan"] == 0
    assert ikinci["created"][0]["kalem_tipi"] == "olaganustu"
    assert _bakiye(client, adm, daire["id"]) == 70000


def test_atlanan_daire_SESSIZCE_kaybolmaz(client, adm, world):
    """Arsa payi girilmemis daire dagitimin disinda kalir ve bu SOYLENIR."""
    tanim = client.post("/gelir-gider-tanimlari", headers=adm, json={
        "ad": f"Aidat-{_sfx()}", "tip": "gider"}).json()
    payli = _daire(client, adm, arsa_payi=10)
    paysiz = _daire(client, adm)

    r = client.post("/borclandirma/toplu", headers=adm, json={
        "donem": "2031-04",
        "gelir_gider_tanim_id": tanim["id"],
        "suzgec": {"unit_ids": [payli["id"], paysiz["id"]]},
        "dagitim": "arsa_payi",
        "toplam_tutar_kurus": 100000,
    })
    assert r.status_code == 201, r.text
    govde = r.json()
    assert govde["atlanan"] == 1
    # SAYI YETMEZ: hangi daire, NIYE atlandi.
    assert [a["unit_id"] for a in govde["atlananlar"]] == [paysiz["id"]]
    assert govde["atlananlar"][0]["neden"] == "arsa_payi_girilmemis"
    assert govde["atlananlar"][0]["unit_no"] == paysiz["no"]


# ================= OLCUT 8: ARSA PAYI / METREKARE DAGITIMI ================ #
@pytest.mark.parametrize(
    "dagitim,alan", [("arsa_payi", "arsa_payi"), ("metrekare", "metrekare")]
)
def test_oransal_dagitim_kurus_kaybetmez(client, adm, dagitim, alan):
    """KMK md. 20 arsa payini sart kosar. Dagitilan toplam GIRDIYE ESIT
    olmali: her payi tek tek yuvarlamak kurusleri buharlastirirdi."""
    tanim = client.post("/gelir-gider-tanimlari", headers=adm, json={
        "ad": f"Gider-{_sfx()}", "tip": "gider"}).json()
    daireler = [_daire(client, adm, **{alan: agirlik}) for agirlik in (1, 1, 1)]
    donem = f"2031-0{5 if dagitim == 'arsa_payi' else 6}"

    # 100.001 kurus / 3 daire — bolunmeyen bir tutar bilincli secildi.
    onizleme = client.post("/borclandirma/toplu/onizleme", headers=adm, json={
        "donem": donem, "gelir_gider_tanim_id": tanim["id"],
        "suzgec": {"unit_ids": [d["id"] for d in daireler]},
        "dagitim": dagitim, "toplam_tutar_kurus": 100001,
    })
    assert onizleme.status_code == 200, onizleme.text
    paylar = [s["tutar_kurus"] for s in onizleme.json()["satirlar"]]
    assert sum(paylar) == 100001
    assert sorted(paylar) == [33333, 33334, 33334]


def test_agirliga_gore_orantili(client, adm):
    tanim = client.post("/gelir-gider-tanimlari", headers=adm, json={
        "ad": f"Gider-{_sfx()}", "tip": "gider"}).json()
    buyuk = _daire(client, adm, arsa_payi=30)
    kucuk = _daire(client, adm, arsa_payi=10)
    r = client.post("/borclandirma/toplu/onizleme", headers=adm, json={
        "donem": "2031-07", "gelir_gider_tanim_id": tanim["id"],
        "suzgec": {"unit_ids": [buyuk["id"], kucuk["id"]]},
        "dagitim": "arsa_payi", "toplam_tutar_kurus": 80000,
    })
    paylar = {s["unit_id"]: s["tutar_kurus"] for s in r.json()["satirlar"]}
    assert paylar[buyuk["id"]] == 60000 and paylar[kucuk["id"]] == 20000


# ======================= OLCUT 6: GECIKME FAIZI =========================== #
@pytest.fixture
def faiz_acik(client, adm):
    r = client.patch("/borclandirma/gecikme-ayari", headers=adm, json={
        "gecikme_aylik_yuzde": 5, "gecikme_uygula": True})
    assert r.status_code == 200, r.text
    return r.json()


def test_faiz_BORC_olarak_yazilir_ve_tahsil_edilebilir(client, adm, faiz_acik):
    """Faiz eskiden EKRANDA HESAPLANAN bir sayiydi ve ana borc odenince
    buharlasiyordu. Artik ayri bir borc kalemidir."""
    daire = _daire(client, adm)
    vade = date.today() - timedelta(days=70)   # iki tam ay gecikme
    tahakkuk = _tahakkuk(
        client, adm, daire["id"], "2031-08", 100000,
        son_odeme_tarihi=vade.isoformat(),
    )["created"][0]

    onizleme = client.get(
        "/borclandirma/gecikme-faizi/onizleme", headers=adm).json()
    hedef = next(
        s for s in onizleme["items"] if s["assessment_id"] == tahakkuk["id"])
    assert hedef["fark_kurus"] == 10000  # %5 x 2 ay x 1000 TL

    islem = client.post("/borclandirma/gecikme-faizi/isle", headers=adm)
    assert islem.status_code == 201, islem.text
    assert islem.json()["toplam_kurus"] >= 10000

    # BAKIYEYE GIRDI.
    assert _bakiye(client, adm, daire["id"]) == 110000

    # Ana borc odense bile faiz AYAKTA kalir (buharlasmaz).
    kasa = client.post("/kasalar", headers=adm, json={
        "kod": f"FZ{_sfx()}", "ad": "Faiz Kasa"}).json()
    client.post("/finans/tahsilat", headers=adm, json={
        "kasa_id": kasa["id"], "tutar_kurus": 100000,
        "unit_id": daire["id"], "assessment_id": tahakkuk["id"]})
    assert _bakiye(client, adm, daire["id"]) == 10000

    # ...ve faiz kalemi TAHSIL EDILEBILIR.
    faiz_kalemi = next(
        a for a in client.get(f"/units/{daire['id']}/dues", headers=adm)
        .json()["assessments"] if a["kalem_tipi"] == "faiz"
    )
    client.post("/finans/tahsilat", headers=adm, json={
        "kasa_id": kasa["id"], "tutar_kurus": 10000,
        "unit_id": daire["id"], "assessment_id": faiz_kalemi["id"]})
    assert _bakiye(client, adm, daire["id"]) == 0


def test_faiz_isleme_IDEMPOTENT(client, adm, faiz_acik):
    daire = _daire(client, adm)
    vade = date.today() - timedelta(days=40)
    _tahakkuk(client, adm, daire["id"], "2031-09", 200000,
              son_odeme_tarihi=vade.isoformat())

    ilk = client.post("/borclandirma/gecikme-faizi/isle", headers=adm).json()
    bakiye = _bakiye(client, adm, daire["id"])
    ikinci = client.post("/borclandirma/gecikme-faizi/isle", headers=adm).json()

    assert ilk["yazilan"] >= 1
    # Ikinci kosum FARK bulmaz: borc iki katina cikmaz.
    assert all(
        s["unit_id"] != daire["id"] for s in ikinci["items"]
    ), ikinci
    assert _bakiye(client, adm, daire["id"]) == bakiye


def test_faiz_kapaliyken_hicbir_sey_yazilmaz(client, adm):
    """Bazi siteler faiz ALMAZ ve bu bir KARARDIR, eksik veri degil."""
    client.patch("/borclandirma/gecikme-ayari", headers=adm,
                 json={"gecikme_uygula": False})
    daire = _daire(client, adm)
    vade = date.today() - timedelta(days=100)
    _tahakkuk(client, adm, daire["id"], "2031-10", 300000,
              son_odeme_tarihi=vade.isoformat())

    onizleme = client.get(
        "/borclandirma/gecikme-faizi/onizleme", headers=adm).json()
    assert onizleme["uygulaniyor"] is False and onizleme["items"] == []
    assert client.post(
        "/borclandirma/gecikme-faizi/isle", headers=adm).json()["yazilan"] == 0
    assert _bakiye(client, adm, daire["id"]) == 300000
    # Ayari geri ac (diger testler etkilenmesin).
    client.patch("/borclandirma/gecikme-ayari", headers=adm,
                 json={"gecikme_uygula": True})


def test_faiz_affi_ters_kayitla(client, adm, faiz_acik, world, owner_conn):
    """Af, faiz kaleminin TERS KAYITLANMASIDIR — silme degil."""
    daire = _daire(client, adm)
    vade = date.today() - timedelta(days=40)
    _tahakkuk(client, adm, daire["id"], "2031-11", 100000,
              son_odeme_tarihi=vade.isoformat())
    client.post("/borclandirma/gecikme-faizi/isle", headers=adm)

    faiz = next(
        a for a in client.get(f"/units/{daire['id']}/dues", headers=adm)
        .json()["assessments"] if a["kalem_tipi"] == "faiz"
    )
    once = _bakiye(client, adm, daire["id"])
    r = client.post(
        f"/dues/assessments/{faiz['id']}/ters-kayit", headers=adm,
        json={"aciklama": "Faiz affi"})
    assert r.status_code == 201, r.text
    assert _bakiye(client, adm, daire["id"]) == once - faiz["tutar_kurus"]

    # SILINMEDI: iki satir da defterde durur.
    say = owner_conn.execute(
        "SELECT count(*) FROM dues_assessment WHERE tenant_id=%s AND unit_id=%s "
        "AND kalem_tipi='faiz'", (str(world["a"]), daire["id"]),
    ).fetchone()[0]
    assert say == 2
    # ...ve af DENETIME yazildi.
    assert owner_conn.execute(
        "SELECT count(*) FROM audit_log WHERE tenant_id=%s AND resource_id=%s",
        (str(world["a"]), r.json()["id"]),
    ).fetchone()[0] == 1


# ================ OLCUT 15: TAHAKKUK DUZELTME (TERS KAYIT) ================ #
def test_yanlis_tahakkuk_ters_kayitla_duzeltilir(client, adm):
    daire = _daire(client, adm)
    yanlis = _tahakkuk(client, adm, daire["id"], "2031-12", 999900)["created"][0]
    assert _bakiye(client, adm, daire["id"]) == 999900

    r = client.post(f"/dues/assessments/{yanlis['id']}/ters-kayit",
                    headers=adm, json={"aciklama": "Yanlis tutar"})
    assert r.status_code == 201, r.text
    assert r.json()["ters_kayit_id"] == yanlis["id"]
    assert _bakiye(client, adm, daire["id"]) == 0

    # Dogru tutar YENI bir kalem olarak yazilir — ayni doneme.
    _tahakkuk(client, adm, daire["id"], "2031-12", 99900)
    assert _bakiye(client, adm, daire["id"]) == 99900


def test_iki_kez_ters_kayitlanamaz(client, adm):
    daire = _daire(client, adm)
    t = _tahakkuk(client, adm, daire["id"], "2032-01", 5000)["created"][0]
    assert client.post(f"/dues/assessments/{t['id']}/ters-kayit",
                       headers=adm, json={}).status_code == 201
    ikinci = client.post(f"/dues/assessments/{t['id']}/ters-kayit",
                         headers=adm, json={})
    assert ikinci.status_code == 409


def test_odenmis_tahakkuk_ters_kayitlanamaz(client, adm):
    """Alinmis parayi karsiliksiz birakmak, daireyi ALACAKLI gosterirdi."""
    daire = _daire(client, adm)
    t = _tahakkuk(client, adm, daire["id"], "2032-02", 30000)["created"][0]
    kasa = client.post("/kasalar", headers=adm, json={
        "kod": f"TK{_sfx()}", "ad": "Kasa"}).json()
    client.post("/finans/tahsilat", headers=adm, json={
        "kasa_id": kasa["id"], "tutar_kurus": 30000,
        "unit_id": daire["id"], "assessment_id": t["id"]})

    r = client.post(f"/dues/assessments/{t['id']}/ters-kayit",
                    headers=adm, json={})
    assert r.status_code == 409
