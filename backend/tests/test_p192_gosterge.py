"""(P192 §5) YONETICININ GORMESI GEREKENLER — kabul olcutleri 11 ve 12.

  11. Borc yaslandirma ekrani calisiyor.
  12. Muhasebeciye disa aktarim calisiyor.

Ayrica §5.2 (tahsilat gostergesi TEK KAYNAKTAN), §5.3 (borclulara toplu
islem) ve §5.4 (butce ile gerceklesen + sapma).
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


def _daire(client, adm):
    return client.post(
        "/units", headers=adm, json={"no": f"GS-{_sfx()}", "blok": "A"}
    ).json()


def _borc(client, adm, unit_id, donem, tutar, gun_once):
    vade = (date.today() - timedelta(days=gun_once)).isoformat()
    r = client.post("/dues/assessments", headers=adm, json={
        "unit_id": unit_id, "donem": donem, "tutar_kurus": tutar,
        "son_odeme_tarihi": vade})
    assert r.status_code == 201, r.text
    return r.json()["created"][0]


def _kova(govde, ad):
    return next(k for k in govde["kovalar"] if k["kova"] == ad)


# ======================= OLCUT 11: BORC YASLANDIRMA ======================== #
def test_yaslandirma_dogru_kovaya_koyar(client, adm):
    yeni = _daire(client, adm)
    orta = _daire(client, adm)
    eski = _daire(client, adm)
    _borc(client, adm, yeni["id"], "2036-01", 10000, 10)    # 0-30
    _borc(client, adm, orta["id"], "2036-02", 20000, 45)    # 31-60
    _borc(client, adm, eski["id"], "2036-03", 30000, 200)   # 90+

    govde = client.get("/finans/yaslandirma", headers=adm).json()
    assert any(
        d["unit_id"] == yeni["id"] for d in _kova(govde, "0-30")["daireler"]
    )
    assert any(
        d["unit_id"] == orta["id"] for d in _kova(govde, "31-60")["daireler"]
    )
    assert any(
        d["unit_id"] == eski["id"] for d in _kova(govde, "90+")["daireler"]
    )


def test_yaslandirma_daire_basina_TEK_kova(client, adm):
    """Bir dairenin uc gecikmis borcu varsa uc kovaya birden dagitmak,
    "kac daire 90+ gundur borclu" sorusunu toplami daire sayisini asan
    bir sayiyla yanitlardi."""
    daire = _daire(client, adm)
    _borc(client, adm, daire["id"], "2036-04", 10000, 10)
    _borc(client, adm, daire["id"], "2036-05", 20000, 200)

    govde = client.get("/finans/yaslandirma", headers=adm).json()
    gorunen = [
        (k["kova"], d) for k in govde["kovalar"] for d in k["daireler"]
        if d["unit_id"] == daire["id"]
    ]
    assert len(gorunen) == 1
    kova, satir = gorunen[0]
    # EN ESKI borcun kovasi ve TUM kalan borc orada.
    assert kova == "90+"
    assert satir["kalan_kurus"] == 30000


def test_yaslandirma_odenmis_borcu_saymaz(client, adm):
    daire = _daire(client, adm)
    borc = _borc(client, adm, daire["id"], "2036-06", 50000, 100)
    kasa = client.post("/kasalar", headers=adm, json={
        "kod": f"YS{_sfx()}", "ad": "Kasa"}).json()
    client.post("/finans/tahsilat", headers=adm, json={
        "kasa_id": kasa["id"], "tutar_kurus": 50000,
        "unit_id": daire["id"], "assessment_id": borc["id"]})

    govde = client.get("/finans/yaslandirma", headers=adm).json()
    assert not any(
        d["unit_id"] == daire["id"]
        for k in govde["kovalar"] for d in k["daireler"]
    )


def test_yaslandirma_ozet_daire_listesi_tasimaz(client, adm):
    """Kart yalnizca sayilari cizerken yuzlerce satir tasimasin."""
    daire = _daire(client, adm)
    _borc(client, adm, daire["id"], "2036-07", 15000, 5)
    govde = client.get(
        "/finans/yaslandirma", headers=adm, params={"ozet": "true"}).json()
    assert all(k["daireler"] == [] for k in govde["kovalar"])
    assert govde["toplam_daire"] >= 1


def test_yaslandirma_vadesi_GELMEMIS_borcu_saymaz(client, adm):
    daire = _daire(client, adm)
    ileri = (date.today() + timedelta(days=20)).isoformat()
    client.post("/dues/assessments", headers=adm, json={
        "unit_id": daire["id"], "donem": "2036-08", "tutar_kurus": 40000,
        "son_odeme_tarihi": ileri})
    govde = client.get("/finans/yaslandirma", headers=adm).json()
    assert not any(
        d["unit_id"] == daire["id"]
        for k in govde["kovalar"] for d in k["daireler"]
    )


# ==================== §5.2 TAHSILAT GOSTERGESI ============================= #
def test_gosterge_rapordaki_rakamla_AYNI(client, adm):
    """TEK KAYNAK: gosterge ile rapor ayni fonksiyonlari cagirir."""
    donem = "2036-09"
    daire = _daire(client, adm)
    borc = _borc(client, adm, daire["id"], donem, 80000, 5)
    kasa = client.post("/kasalar", headers=adm, json={
        "kod": f"GG{_sfx()}", "ad": "Kasa"}).json()
    client.post("/finans/tahsilat", headers=adm, json={
        "kasa_id": kasa["id"], "tutar_kurus": 40000,
        "unit_id": daire["id"], "assessment_id": borc["id"]})

    gosterge = client.get(
        "/finans/tahsilat-gostergesi", headers=adm, params={"donem": donem}
    ).json()
    rapor = client.get(
        "/reports/financial-summary", headers=adm, params={"donem": donem}
    ).json()["tahsilat"]

    assert gosterge["tahakkuk_kurus"] == rapor["tahakkuk_kurus"]
    assert gosterge["tahsilat_kurus"] == rapor["tahsilat_kurus"]
    assert gosterge["oran_yuzde"] == rapor["tahsilat_orani_yuzde"] == 50
    assert gosterge["onceki_donem"] == "2036-08"


# ======================= §5.3 BORCLULARA TOPLU ISLEM ======================= #
def test_toplu_hatirlatma_kapanmis_daireyi_ATLAR(client, adm, world):
    resident = _headers(client, world["slug_a"], world["resident_a"])
    resident_id = client.get("/me", headers=resident).json()["id"]
    borclu = _daire(client, adm)
    odeyen = _daire(client, adm)
    client.post(f"/units/{borclu['id']}/residents", headers=adm,
                json={"user_id": resident_id, "rol_tipi": "malik"})
    _borc(client, adm, borclu["id"], "2036-10", 10000, 15)
    t = _borc(client, adm, odeyen["id"], "2036-10", 10000, 15)
    kasa = client.post("/kasalar", headers=adm, json={
        "kod": f"TH{_sfx()}", "ad": "Kasa"}).json()
    client.post("/finans/tahsilat", headers=adm, json={
        "kasa_id": kasa["id"], "tutar_kurus": 10000,
        "unit_id": odeyen["id"], "assessment_id": t["id"]})

    r = client.post("/finans/borclulara/hatirlat", headers=adm, json={
        "unit_ids": [borclu["id"], odeyen["id"]]})
    assert r.status_code == 200, r.text
    assert r.json()["gonderilen"] == 1
    assert r.json()["atlanan"] == 1


def test_toplu_faiz_affi_ters_kayitla(client, adm):
    client.patch("/borclandirma/gecikme-ayari", headers=adm, json={
        "gecikme_aylik_yuzde": 10, "gecikme_uygula": True})
    daire = _daire(client, adm)
    _borc(client, adm, daire["id"], "2036-11", 100000, 70)
    client.post("/borclandirma/gecikme-faizi/isle", headers=adm)

    once = client.get(f"/units/{daire['id']}/dues", headers=adm).json()
    faiz = [a for a in once["assessments"] if a["kalem_tipi"] == "faiz"]
    assert faiz, once

    r = client.post("/finans/borclulara/faiz-affi", headers=adm, json={
        "unit_ids": [daire["id"]]})
    assert r.status_code == 200, r.text
    assert r.json()["affedilen_kalem"] == len(faiz)

    sonra = client.get(f"/units/{daire['id']}/dues", headers=adm).json()
    assert sonra["bakiye_kurus"] == 100000  # yalniz ana borc kaldi
    assert not [a for a in sonra["assessments"] if a["kalem_tipi"] == "faiz"]


def test_odeme_plani_vadeleri_aya_yayar_YENI_BORC_URETMEZ(client, adm):
    daire = _daire(client, adm)
    _borc(client, adm, daire["id"], "2036-12", 30000, 60)
    _borc(client, adm, daire["id"], "2037-01", 30000, 30)
    once = client.get(f"/units/{daire['id']}/dues", headers=adm).json()

    r = client.post("/finans/borclulara/odeme-plani", headers=adm, json={
        "unit_ids": [daire["id"]], "taksit_sayisi": 2,
        "ilk_vade": "2037-06-10"})
    assert r.status_code == 200, r.text
    assert r.json()["daire"] == 1

    sonra = client.get(f"/units/{daire['id']}/dues", headers=adm).json()
    # BORC TUTARI DEGISMEDI — yalniz vadeler yayildi.
    assert sonra["bakiye_kurus"] == once["bakiye_kurus"]
    assert len(sonra["assessments"]) == len(once["assessments"])
    vadeler = sorted(a["son_odeme_tarihi"] for a in sonra["assessments"])
    assert vadeler == ["2037-06-10", "2037-07-10"]


def test_toplu_islem_bos_liste_reddedilir(client, adm):
    """"Hepsi" anlamina gelen bos bir liste, yanlislikla butun siteye
    islem yapmayi bir tikla mumkun kilardi."""
    r = client.post("/finans/borclulara/hatirlat", headers=adm,
                    json={"unit_ids": []})
    assert r.status_code == 422


def test_toplu_islem_denetciye_kapali(client, world, adm):
    daire = _daire(client, adm)
    den = _headers(client, world["slug_a"], world["denetci_a"])
    assert client.get("/finans/yaslandirma", headers=den).status_code == 200
    assert client.post(
        "/finans/borclulara/hatirlat", headers=den,
        json={"unit_ids": [daire["id"]]},
    ).status_code == 403


# ==================== §5.4 BUTCE ILE GERCEKLESEN ========================== #
def test_butce_karsilastirma_sapma_gosterir(client, adm):
    kategori = client.post("/budget/categories", headers=adm, json={
        "ad": f"Bakim-{_sfx()}", "tip": "gider"}).json()
    hedef = client.post("/budget/hedefler", headers=adm, json={
        "yil": 2037, "donem": "2037-03", "kategori_id": kategori["id"],
        "tutar_kurus": 100000})
    assert hedef.status_code == 201, hedef.text
    client.post("/budget/entries", headers=adm, json={
        "kategori_id": kategori["id"], "tutar_kurus": 130000,
        "tarih": "2037-03-15"})

    govde = client.get("/budget/karsilastirma", headers=adm, params={
        "yil": 2037, "donem": "2037-03"}).json()
    satir = next(i for i in govde["items"] if i["kategori_id"] == kategori["id"])
    assert satir["hedef_kurus"] == 100000
    assert satir["gerceklesen_kurus"] == 130000
    assert satir["sapma_kurus"] == 30000 and satir["sapma_yuzde"] == 30


def test_hedef_ikinci_kez_yazilinca_GUNCELLENIR(client, adm):
    """Butce revize edilen bir seydir; "once sil, sonra ekle" akisi
    arada hedefsiz kalan bir an birakirdi."""
    kategori = client.post("/budget/categories", headers=adm, json={
        "ad": f"Sigorta-{_sfx()}", "tip": "gider"}).json()
    govde = {"yil": 2038, "kategori_id": kategori["id"], "tutar_kurus": 50000}
    ilk = client.post("/budget/hedefler", headers=adm, json=govde).json()
    ikinci = client.post(
        "/budget/hedefler", headers=adm, json={**govde, "tutar_kurus": 75000}
    ).json()
    assert ikinci["id"] == ilk["id"] and ikinci["tutar_kurus"] == 75000


def test_yillik_hedef_aylik_sorguda_ONIKIYE_BOLUNUR(client, adm):
    """Aylik hedefi olmayan bir kategoriyi "hedefsiz" saymak, yillik
    butcesi onaylanmis bir kalemi sifir hedefle gostermek olurdu."""
    kategori = client.post("/budget/categories", headers=adm, json={
        "ad": f"Asansor-{_sfx()}", "tip": "gider"}).json()
    client.post("/budget/hedefler", headers=adm, json={
        "yil": 2039, "kategori_id": kategori["id"], "tutar_kurus": 120000})
    govde = client.get("/budget/karsilastirma", headers=adm, params={
        "yil": 2039, "donem": "2039-05"}).json()
    satir = next(i for i in govde["items"] if i["kategori_id"] == kategori["id"])
    assert satir["hedef_kurus"] == 10000


# =================== OLCUT 12: MUHASEBEYE AKTARIM ========================= #
def test_muhasebe_aktarimi_borc_alacak_AYRI_sutun(client, adm):
    kasa = client.post("/kasalar", headers=adm, json={
        "kod": f"MA{_sfx()}", "ad": "Kasa"}).json()
    client.post("/finans/tahsilat", headers=adm, json={
        "kasa_id": kasa["id"], "tutar_kurus": 12345, "tarih": "2040-04-10"})
    client.post("/finans/hareketler", headers=adm, json={"satirlar": [
        {"tip": "gider", "tutar_kurus": 6789, "kasa_id": kasa["id"],
         "tarih": "2040-04-11"}]})

    r = client.post(
        "/raporlar/muhasebe_aktarim", headers=adm,
        params={"bicim": "tablo"},
        json={"baslangic": "2040-04-01", "bitis": "2040-04-30"},
    )
    assert r.status_code == 200, r.text
    govde = r.json()
    kodlar = [s["anahtar"] for s in govde["sutunlar"]]
    assert "borc" in kodlar and "alacak" in kodlar
    assert govde["toplamlar"]["alacak"] == 12345
    assert govde["toplamlar"]["borc"] == 6789


def test_muhasebe_aktarimi_ONAY_BEKLEYENI_disarida_birakir(client, adm):
    """Muhasebeciye giden dokum GERCEKLESMIS hareketlerin dokumudur."""
    kasa = client.post("/kasalar", headers=adm, json={
        "kod": f"MB{_sfx()}", "ad": "Kasa"}).json()
    client.post("/finans/hareketler", headers=adm, json={"satirlar": [
        {"tip": "gider", "tutar_kurus": 99999, "kasa_id": kasa["id"],
         "tarih": "2041-05-10", "durum": "onay_bekliyor"}]})

    r = client.post(
        "/raporlar/muhasebe_aktarim", headers=adm, params={"bicim": "tablo"},
        json={"baslangic": "2041-05-01", "bitis": "2041-05-31"},
    )
    assert r.json()["toplamlar"]["borc"] == 0


def test_muhasebe_aktarimi_EXCEL_uretir(client, adm):
    r = client.post(
        "/raporlar/muhasebe_aktarim", headers=adm, params={"bicim": "excel"},
        json={"baslangic": "2040-04-01", "bitis": "2040-04-30"},
    )
    assert r.status_code == 200, r.text
    assert "spreadsheet" in r.headers["content-type"]
