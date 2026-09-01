"""(P193 §6) ARSA PAYI — TOPLU GIRIS.

Rehberde eksik 6: arsa payi YALNIZ tek tek girilebiliyordu — ne toplu
daire olusturmada ne Excel aktariminda sutunu vardi. 100 daireli bir
sitede bu 100 ayri form demekti; ve arsa payi girilmemis daire, arsa
payina gore dagitimin DISINDA kaldigi icin eksik giris SESSIZ bir yanlis
paylasima donusuyordu.
"""
from __future__ import annotations

import uuid


def _giris(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _blok() -> str:
    return "P" + uuid.uuid4().hex[:3].upper()


# ==================== 1) TOPLU OLUSTURMADA ARSA PAYI ==================== #

def test_TOPLU_OLUSTURMADA_arsa_payi_PARTIYE_yazilir(client, world):
    """Tip dairelerde (ayni kat plani) arsa payi hepsinde aynidir; 100
    daireyi tek tek dolasmak gereksiz bir istir."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    blok = _blok()
    r = client.post("/units/bulk", headers=h, json={
        "blok": blok, "kat_sayisi": 2, "kat_basi_daire": 3,
        "baslangic_no": 900, "arsa_payi": 0.0125, "metrekare": 120,
    })
    assert r.status_code == 201, r.text
    olusan = r.json()["olusturulan"]
    assert len(olusan) == 6
    assert all(u["arsa_payi"] == 0.0125 for u in olusan), "parti degeri yazilmadi"
    assert all(u["metrekare"] == 120 for u in olusan)


# ==================== 2) DAIRE BASINA FARKLI DEGER ==================== #

def test_ARSA_PAYI_TOPLU_daire_basina_FARKLI_deger_yazar(client, world):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    blok = _blok()
    r = client.post("/units/bulk", headers=h, json={
        "blok": blok, "kat_sayisi": 1, "kat_basi_daire": 3, "baslangic_no": 910,
    })
    assert r.status_code == 201, r.text
    daireler = r.json()["olusturulan"]

    satirlar = [
        {"id": daireler[0]["id"], "arsa_payi": 0.01},
        {"id": daireler[1]["id"], "arsa_payi": 0.02},
        {"id": daireler[2]["id"], "arsa_payi": 0.03},
    ]
    r = client.patch("/units/arsa-payi", headers=h, json={"satirlar": satirlar})
    assert r.status_code == 200, r.text
    assert r.json()["etkilenen"] == 3

    for beklenen, d in zip((0.01, 0.02, 0.03), daireler):
        g = client.get(f"/units/{d['id']}", headers=h)
        assert g.json()["arsa_payi"] == beklenen

    # NULL = KALDIR: ticari birim/ortak alan dagitim disinda kalabilmeli.
    r = client.patch("/units/arsa-payi", headers=h, json={
        "satirlar": [{"id": daireler[0]["id"], "arsa_payi": None}]})
    assert r.status_code == 200, r.text
    assert client.get(f"/units/{daireler[0]['id']}", headers=h).json()["arsa_payi"] is None


def test_BULUNMAYAN_KIMLIK_SESSIZCE_DUSMEZ(client, world):
    """RLS baska tenant'in satirini zaten gostermez; kimlik SAYIDA
    gorunmeli — yoksa kullanici 100 satir yolladigini ve 98'inin
    yazildigini fark edemezdi."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    yok = str(uuid.uuid4())
    r = client.patch("/units/arsa-payi", headers=h,
                     json={"satirlar": [{"id": yok, "arsa_payi": 0.5}]})
    assert r.status_code == 200, r.text
    assert r.json()["etkilenen"] == 0
    assert r.json()["atlanan"] == [yok]


# ==================== 3) TOPLAM GORUNUR ==================== #

def test_OZET_toplam_ve_EKSIK_GIRIS_sayisini_verir(client, world):
    """Arsa payi bir PAYDIR: toplami tutmayan bir dagilim gider
    paylasimini sessizce yanlis hesaplar."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    r = client.get("/units/arsa-payi-ozeti", headers=h)
    assert r.status_code == 200, r.text
    o = r.json()
    assert o["daire_sayisi"] == o["girilmis"] + o["girilmemis"]
    onceki = o["toplam"]

    blok = _blok()
    d = client.post("/units/bulk", headers=h, json={
        "blok": blok, "kat_sayisi": 1, "kat_basi_daire": 2,
        "baslangic_no": 920, "arsa_payi": 0.25,
    }).json()["olusturulan"]
    assert len(d) == 2

    o2 = client.get("/units/arsa-payi-ozeti", headers=h).json()
    assert round(o2["toplam"] - onceki, 6) == 0.5
    assert o2["girilmis"] >= 2


# ==================== 4) EXCEL AKTARIMI ==================== #

def test_AKTARIMDA_arsa_payi_SUTUNU_VAR_ve_MEVCUT_DAIREYI_GUNCELLER(client, world):
    """ASIL AKIS: yonetici once 100 daireyi TOPLU olusturur, sonra arsa
    paylarini iceren dosyayi yukler.

    Eskiden var olan daire kosulsuz ATLANIYORDU — yani dosyanin tamami
    "zaten kayitli" diye gecilir ve HICBIR arsa payi yazilmazdi.
    """
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    turler = client.get("/ice-aktarim/turler", headers=h).json()
    daire_turu = next(t for t in turler if t["kod"] == "daire")
    kodlar = {a["kod"] for a in daire_turu["alanlar"]}
    assert {"arsa_payi", "metrekare"} <= kodlar, "sutunlar bildirilmemis"

    blok = _blok()
    olusan = client.post("/units/bulk", headers=h, json={
        "blok": blok, "kat_sayisi": 1, "kat_basi_daire": 2, "baslangic_no": 930,
    }).json()["olusturulan"]
    hedef = olusan[0]

    r = client.post("/ice-aktarim/daire", headers=h, json={"satirlar": [
        {"satir_no": 2, "degerler": {
            "blok": blok, "daire_no": hedef["no"],
            "arsa_payi": "0,0125", "metrekare": "120,5"}},
    ]})
    assert r.status_code == 201, r.text
    sonuc = r.json()
    # ATLANDI DEGIL GUNCELLENDI: atlanan satir hicbir sey degistirmez.
    assert sonuc["guncellenen"] == 1, sonuc
    assert sonuc["atlanan"] == 0

    g = client.get(f"/units/{hedef['id']}", headers=h).json()
    assert g["arsa_payi"] == 0.0125
    assert g["metrekare"] == 120.5


def test_AKTARIMDA_OKUNAMAYAN_SAYI_HATA_verir(client, world):
    """Sessizce `None` yazmak, kullanicinin girdigi sayiyi yok saymak ve
    dagitimi fark edilmeden eksik birakmak olurdu."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    blok = _blok()
    r = client.post("/ice-aktarim/daire", headers=h, json={
        "yalniz_dogrula": True,
        "satirlar": [{"satir_no": 2, "degerler": {
            "blok": blok, "daire_no": f"{blok}-1", "arsa_payi": "yok"}}],
    })
    assert r.status_code == 201, r.text
    assert r.json()["hatali"] == 1
    assert r.json()["hatalar"][0]["alan"] == "arsa_payi"
