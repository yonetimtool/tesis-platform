"""Rapor motoru + katalog (P31).

Iki katman:
  1. CEKIRDEK (veritabanisiz) — sutun dogrulugu, bakiye formulu, dinamik
     sutunlar, tahsilat orani, kurus bicimi. Bunlar raporun ANLAMIDIR.
  2. UC — katalog, uc bicim (tablo/excel/pdf), RBAC, parametre dogrulamasi.
"""
from __future__ import annotations

import uuid
from datetime import date

import pytest

from app.raporlar import (
    RaporParam,
    borc_alacak_satirlari,
    detayli_borc_satirlari,
    ihtar_metni,
    kurus_metin,
    sirala,
    tahsilat_performansi,
    tutar_suzgeci,
)


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def adm(client, world):
    return _headers(client, world["slug_a"], world["admin_a"])


# ============================== CEKIRDEK ==================================== #
def test_kurus_metni_TURKCE_gruplama():
    assert kurus_metin(125050) == "1.250,50"
    assert kurus_metin(0) == "0,00"
    assert kurus_metin(-500) == "-5,00"
    assert kurus_metin(123456789) == "1.234.567,89"
    assert kurus_metin(None) == ""


def test_borc_alacak_BAKIYE_FORMULU():
    """IADE tahsilati GERI ALIR, yani bakiyeyi ARTIRIR — "eksi tahsilat"
    diye yazmak isareti IKI KEZ uygulamak olurdu."""
    kisi = {
        "unit_no": "A-1", "ad": "X",
        "bas_ana_para": 10000, "bas_gecikme": 500,
        "ici_borc": 20000, "ici_gecikme": 300,
        "ici_iade": 1000, "ici_tahsilat": 15000,
    }
    sonuc = borc_alacak_satirlari([kisi], [], RaporParam())
    assert sonuc.satirlar[0]["bakiye"] == 10000 + 500 + 20000 + 300 + 1000 - 15000


def test_borc_alacak_ISMI_GOSTER_KAPALI_ad_SUTUNU_da_gider():
    """Kapiya asilacak listede ad OLMAMALI — degeri bosaltmak yetmez,
    SUTUN da kalkmali (bos sutun "adi neden yok" sorusunu dogururdu)."""
    sonuc = borc_alacak_satirlari(
        [{"unit_no": "A-1", "ad": "Gizli Kisi"}], [],
        RaporParam(ismi_goster=False),
    )
    assert all(s.anahtar != "ad" for s in sonuc.sutunlar)
    assert "ad" not in sonuc.satirlar[0]


def test_borc_alacak_ICRADAKILER_gizlenebilir():
    kisiler = [
        {"unit_no": "A-1", "icrada": False},
        {"unit_no": "A-2", "icrada": True},
    ]
    hepsi = borc_alacak_satirlari(kisiler, [], RaporParam())
    gizli = borc_alacak_satirlari(
        kisiler, [], RaporParam(icradakileri_goster=False)
    )
    assert len(hepsi.satirlar) == 2 and len(gizli.satirlar) == 1


def test_borc_alacak_LISTELEME_TIPI():
    kisiler = [
        {"unit_no": "A-1", "ici_borc": 1000},          # borclu
        {"unit_no": "A-2", "ici_tahsilat": 1000},      # alacakli (eksi bakiye)
    ]
    borclu = borc_alacak_satirlari(
        kisiler, [], RaporParam(listeleme_tipi="borclu")
    )
    alacakli = borc_alacak_satirlari(
        kisiler, [], RaporParam(listeleme_tipi="alacakli")
    )
    assert [s["unit_no"] for s in borclu.satirlar] == ["A-1"]
    assert [s["unit_no"] for s in alacakli.satirlar] == ["A-2"]


def test_borc_alacak_TOPLAM_satiri_sutun_basina():
    kisiler = [
        {"unit_no": "A-1", "ici_borc": 1000},
        {"unit_no": "A-2", "ici_borc": 2500},
    ]
    sonuc = borc_alacak_satirlari(kisiler, [], RaporParam())
    assert sonuc.toplamlar["ici_borc"] == 3500
    assert sonuc.toplamlar["bakiye"] == 3500


def test_detayli_borc_DINAMIK_sutunlar():
    """Elektrik/Su sabit sutun OLARAK YAZILMADI: kalemi olmayan siteye bos
    sutun, fazladan kalemi olana "Diğer"e sikismis rakam gosterirdi."""
    kalemler = [{"id": "k1", "ad": "Elektrik"}, {"id": "k2", "ad": "Su"}]
    kisi = {"unit_no": "A-1", "ad": "X",
            "kalemler": {"k1": 5000, "k2": 3000, "bilinmeyen": 700}}
    sonuc = detayli_borc_satirlari([kisi], kalemler, RaporParam())
    basliklar = [s.baslik for s in sonuc.sutunlar]
    assert "Elektrik" in basliklar and "Su" in basliklar
    satir = sonuc.satirlar[0]
    assert satir["kalem_k1"] == 5000 and satir["kalem_k2"] == 3000
    # TANIMSIZ borc "Diğer"e toplanir — kaybolmaz.
    assert satir["kalem_diger"] == 700
    assert satir["toplam"] == 8700


def test_detayli_borc_KALEM_YOKSA_yalniz_diger():
    sonuc = detayli_borc_satirlari(
        [{"unit_no": "A-1", "kalemler": {"x": 100}}], [], RaporParam()
    )
    assert sonuc.satirlar[0]["kalem_diger"] == 100
    assert sonuc.satirlar[0]["toplam"] == 100


def test_tahsilat_orani_TANIMI():
    """Oran = tahsil / BORCLANDIRILAN. "tahsil / toplam acik borc" olsaydi
    gecmis birikmis borc payi sisirir ve iyi bir ayi kotu gosterirdi."""
    sonuc = tahsilat_performansi(
        [{"donem": "2026-01", "borclandirilan": 10000, "tahsil": 7500}], []
    )
    assert sonuc.satirlar[0]["oran"] == 75.0


def test_tahsilat_orani_SIFIRA_BOLME_None_doner():
    """Borclandirma yoksa oran TANIMSIZDIR, 0 DEGIL — 0 yazmak "hic tahsil
    edemedik" diye okunurdu."""
    sonuc = tahsilat_performansi(
        [{"donem": "2026-02", "borclandirilan": 0, "tahsil": 0}], []
    )
    assert sonuc.satirlar[0]["oran"] is None
    assert sonuc.toplamlar["oran"] is None


def test_tahsilat_YASLANDIRMA_metinde():
    sonuc = tahsilat_performansi(
        [{"donem": "2026-01", "borclandirilan": 100, "tahsil": 100}],
        [{"kova": "0-30 gün", "tutar_kurus": 25000}],
    )
    assert "0-30 gün" in sonuc.metin and "250,00" in sonuc.metin


def test_tutar_suzgeci_SINIRLAR_DAHIL():
    """100 TL borclu tam sinirdadir ve "en az 100 TL" listesinde OLMALIDIR."""
    satirlar = [{"b": 9999}, {"b": 10000}, {"b": 10001}]
    assert tutar_suzgeci(satirlar, "b", 10000, 10000) == [{"b": 10000}]


def test_siralama_BILINMEYEN_anahtar_varsayilana_duser():
    """Istemciden gelen anahtari dogrudan kullanmak KeyError ile 500
    verirdi."""
    satirlar = [{"unit_no": "B"}, {"unit_no": "A"}]
    assert sirala(satirlar, "olmayan_alan", "unit_no")[0]["unit_no"] == "A"


def test_ihtar_metni_TUTARLARI_ve_SURE_icerir():
    metin = ihtar_metni("Acme Sitesi", "Ali Veli", "A-12", 100000, 5000,
                        date(2026, 7, 31))
    assert "Acme Sitesi" in metin and "Ali Veli" in metin and "A-12" in metin
    assert "1.000,00" in metin and "50,00" in metin and "1.050,00" in metin
    assert "yedi (7) gün" in metin
    assert "20. maddesi" in metin


# ================================= UC ======================================= #
def test_katalog_TUM_raporlari_listeler(client, adm):
    """Listede gorunup CALISMAYAN bir rapor OLAMAZ: katalog ve yonlendirme
    ayni sozlukten okur."""
    r = client.get("/raporlar/katalog", headers=adm)
    assert r.status_code == 200
    kodlar = [i["kod"] for i in r.json()["items"]]
    assert len(kodlar) >= 12
    for kod in kodlar:
        cevap = client.post(f"/raporlar/{kod}?bicim=tablo", headers=adm, json={})
        assert cevap.status_code == 200, (kod, cevap.text)


def test_uc_bicim_de_calisir(client, adm):
    for bicim, tur in [
        ("tablo", "application/json"),
        ("excel", "spreadsheetml"),
        ("pdf", "application/pdf"),
    ]:
        r = client.post(f"/raporlar/borc_alacak?bicim={bicim}", headers=adm,
                        json={})
        assert r.status_code == 200, (bicim, r.text)
        assert tur in r.headers["content-type"], (bicim, r.headers)
        if bicim != "tablo":
            assert len(r.content) > 500, bicim
            assert "attachment" in r.headers["content-disposition"]


def test_excel_XLSX_imzasi(client, adm):
    r = client.post("/raporlar/borc_alacak?bicim=excel", headers=adm, json={})
    # XLSX bir ZIP'tir: "PK" ile baslar.
    assert r.content[:2] == b"PK"


def test_pdf_imzasi_ve_SAYFA_ALTBILGISI(client, adm):
    r = client.post("/raporlar/site_sakinleri?bicim=pdf", headers=adm, json={})
    assert r.content[:5] == b"%PDF-"
    # Sayfa sayisi ONCEDEN bilinir (iki gecisli uretim): "n / m" yazilir.
    assert b"Sayfa" in r.content or b"/Count" in r.content


def test_ihtar_yazisi_METIN_PDF(client, adm):
    r = client.post("/raporlar/ihtar_yazisi?bicim=pdf", headers=adm, json={})
    assert r.status_code == 200 and r.content[:5] == b"%PDF-"


def test_gecersiz_kod_404_gecersiz_bicim_422(client, adm):
    assert client.post("/raporlar/olmayan?bicim=tablo", headers=adm,
                       json={}).status_code == 404
    assert client.post("/raporlar/borc_alacak?bicim=word", headers=adm,
                       json={}).status_code == 422


def test_parametre_dogrulamasi(client, adm):
    kotu_aralik = client.post("/raporlar/borc_alacak", headers=adm, json={
        "baslangic": "2026-06-01", "bitis": "2026-05-01"})
    assert kotu_aralik.status_code == 422
    kotu_tutar = client.post("/raporlar/borc_alacak", headers=adm, json={
        "min_tutar_kurus": 5000, "max_tutar_kurus": 1000})
    assert kotu_tutar.status_code == 422


def test_ismi_goster_KAPALI_ucta_da_calisir(client, adm):
    r = client.post("/raporlar/site_sakinleri", headers=adm,
                    json={"ismi_goster": False}).json()
    assert all(s["anahtar"] != "ad" for s in r["sutunlar"])


def test_denetim_raporu_KASA_MUTABAKATI(client, adm):
    """Denetci "rakam nereden geliyor" sorusunu SATIR SATIR cevaplayabilmeli."""
    kasa = client.post("/kasalar", headers=adm, json={
        "kod": f"DN{uuid.uuid4().hex[:4]}", "ad": "Denetim Kasa",
        "acilis_bakiye_kurus": 100000}).json()
    client.post("/finans/tahsilat", headers=adm, json={
        "kasa_id": kasa["id"], "tutar_kurus": 25000})

    r = client.post("/raporlar/denetim_raporu", headers=adm, json={}).json()
    satir = next(s for s in r["satirlar"] if kasa["kod"] in s["kasa"])
    assert satir["acilis"] == 100000
    assert satir["giris"] == 25000
    assert satir["bakiye"] == 125000, "acilis + giris - cikis tutmuyor"
    assert "Karar defteri" in (r["metin"] or "")


def test_rbac_YALNIZ_YONETIM(client, world):
    for rol, izin in [("admin_a", True), ("yonetici_a", True),
                      ("guard_a", False), ("gorevli_a", False),
                      ("resident_a", False)]:
        h = _headers(client, world["slug_a"], world[rol])
        r = client.get("/raporlar/katalog", headers=h)
        assert (r.status_code == 200) is izin, (rol, r.status_code)
