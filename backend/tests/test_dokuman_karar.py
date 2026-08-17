"""(P167 Asama 6) KARAR DEFTERI + DOKUMAN YONETIMI.

EN PAHALI SONUCLAR, testin agirligi da orada:

 1. INDIRILEMEYEN ARSIV. Dosya yuklenebiliyor, listelenebiliyor ama
    INDIRILEMIYORDU — arsivin tek amaci olan sey yapilamiyordu.
 2. DEPODA BIRIKEN COP. Silme kaydi siliyor, MinIO objesi sonsuza kadar
    kaliyordu; hicbir uygulama yolundan erisilemedigi icin kimse fark
    etmiyordu.
 3. NUMARA UYDURMA. Karar numarasi zorunluydu; seri tutarliligi insan
    hafizasina birakilmisti.
"""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _dokuman(client, headers, ad="Yonetim Plani"):
    anahtar = f"test/{uuid.uuid4().hex}.pdf"
    r = client.post("/dokumanlar", headers=headers, json={
        "ad": ad, "obje_anahtari": anahtar, "boyut_bayt": 1024,
    })
    assert r.status_code == 201, r.text
    return r.json()


# --------------------------------------------------------------------------- #
# KARAR DEFTERI
# --------------------------------------------------------------------------- #
def test_karar_NUMARASIZ_olusturulabilir_ve_MERKEZI_seriden_alir(client, world):
    """Brief'in alan listesinde yildiz yalniz "Konu"da.

    Numarayi zorunlu tutmak, her karar icin kullaniciyi bir numara
    UYDURMAYA zorlar ve serinin tutarliligini insan hafizasina birakirdi.
    """
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/karar-defteri", headers=y, json={
        "konu": "Asansor bakimi", "metin": "Yillik bakim sozlesmesi yenilendi.",
    })
    assert r.status_code == 201, r.text
    no = r.json()["karar_no"]
    # AYRI BIR SAYAC ACILMADI: Asama 4'un merkezi serisiyle ayni bicim.
    assert no.startswith("KRR-"), no
    assert len(no.split("-")) == 3, no


def test_karar_numarasi_ARDISIK_ilerler(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    numaralar = []
    for i in range(2):
        r = client.post("/karar-defteri", headers=y, json={
            "konu": f"Konu {i}", "metin": "metin",
        })
        assert r.status_code == 201, r.text
        numaralar.append(r.json()["karar_no"])
    sira = [int(n.split("-")[-1]) for n in numaralar]
    assert sira[1] == sira[0] + 1, numaralar


def test_KULLANICININ_yazdigi_numara_KORUNUR(client, world):
    # Merkezi uretimin amaci kullaniciyi ENGELLEMEK degil: elinde gercek
    # bir karar numarasi olan kisi onu yazabilmeli.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    ozel = f"2026/{uuid.uuid4().hex[:6]}"
    r = client.post("/karar-defteri", headers=y, json={
        "karar_no": ozel, "konu": "Ozel numarali", "metin": "metin",
    })
    assert r.status_code == 201, r.text
    assert r.json()["karar_no"] == ozel


def test_KONU_ve_METIN_hala_ZORUNLU(client, world):
    # Numara serbestlestirildi diye her sey serbestlesmedi: konusuz bir
    # karar, defterde ne oldugu okunamayan bir satir olurdu.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    assert client.post("/karar-defteri", headers=y, json={"metin": "x"}).status_code == 422
    assert client.post("/karar-defteri", headers=y, json={"konu": "x"}).status_code == 422


def test_karar_UYELERI_gorevleriyle_saklanir(client, world):
    # Brief "birden fazla Uye satiri" istiyor ve uyenin GOREVI de var;
    # duz bir ad listesi gorevi tasiyamazdi.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/karar-defteri", headers=y, json={
        "konu": "Genel kurul", "metin": "metin",
        "baskan_ad": "Ali Veli",
        "uyeler": [
            {"ad": "Ayse Yilmaz", "gorev": "Uye"},
            {"ad": "Mehmet Kaya", "gorev": "Denetci"},
        ],
    })
    assert r.status_code == 201, r.text
    uyeler = r.json()["uyeler"]
    assert [u["ad"] for u in uyeler] == ["Ayse Yilmaz", "Mehmet Kaya"]
    assert {u["gorev"] for u in uyeler} == {"Uye", "Denetci"}


# --------------------------------------------------------------------------- #
# DOKUMAN — INDIRME
# --------------------------------------------------------------------------- #
def test_dokuman_INDIRILEBILIR(client, world):
    """Bu uc EKSIKTI: arsivin tek amaci olan sey yapilamiyordu."""
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    d = _dokuman(client, y)
    r = client.get(f"/dokumanlar/{d['id']}/indir", headers=y)
    assert r.status_code == 200, r.text
    govde = r.json()
    assert govde["url"]
    assert govde["dosya_adi"] == d["ad"]


def test_indirme_OBJE_ANAHTARI_DEGIL_URL_doner(client, world):
    # Anahtar istemciye verilseydi hem depo yapisi disari sizar hem de
    # iznin SURESI kaybolurdu.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    d = _dokuman(client, y)
    govde = client.get(f"/dokumanlar/{d['id']}/indir", headers=y).json()
    assert "obje_anahtari" not in govde
    assert govde["url"].startswith("http")


def test_OLMAYAN_dokuman_404(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.get(f"/dokumanlar/{uuid.uuid4()}/indir", headers=y)
    assert r.status_code == 404, r.text


# --------------------------------------------------------------------------- #
# DOKUMAN — YUMUSAK SILME
# --------------------------------------------------------------------------- #
def test_SILINEN_dokuman_LISTEDE_YOK(client, world):
    """Yumusak silme kullaniciya SILME gibi gorunmeli.

    "Silindi ama hala listede" bir kayit, dugmenin calismadigi izlenimi
    verirdi.
    """
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    d = _dokuman(client, y, ad=f"Silinecek-{uuid.uuid4().hex[:6]}")

    once = client.get("/dokumanlar?limit=200", headers=y).json()
    assert any(x["id"] == d["id"] for x in once["items"])

    assert client.delete(f"/dokumanlar/{d['id']}", headers=y).status_code == 204

    sonra = client.get("/dokumanlar?limit=200", headers=y).json()
    assert not any(x["id"] == d["id"] for x in sonra["items"])
    # TOPLAM da dusmeli: sayac silinmisleri sayarsa, sayfalama var olmayan
    # bir sayfayi vaat ederdi.
    assert sonra["meta"]["total"] == once["meta"]["total"] - 1


def test_SILINEN_dokuman_INDIRILEMEZ(client, world):
    # Listede gorunmeyen bir kaydin baglantisi calisiyor olsaydi, silme
    # yalnizca GORSEL olurdu.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    d = _dokuman(client, y)
    client.delete(f"/dokumanlar/{d['id']}", headers=y)
    assert client.get(f"/dokumanlar/{d['id']}/indir", headers=y).status_code == 404


def test_IKI_KEZ_SILME_404(client, world):
    # Zaten silinmis bir kayda tekrar silme demek, var olmayan bir seyi
    # silmektir.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    d = _dokuman(client, y)
    assert client.delete(f"/dokumanlar/{d['id']}", headers=y).status_code == 204
    assert client.delete(f"/dokumanlar/{d['id']}", headers=y).status_code == 404


def test_SILINEN_dokuman_RAPORDA_da_YOK(client, world):
    # Ekranda gorunmeyen bir satirin Excel'de gorunmesi, iki ciktinin ayni
    # soruya farkli cevap vermesi olurdu.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    ad = f"Rapor-{uuid.uuid4().hex[:8]}"
    d = _dokuman(client, y, ad=ad)

    once = client.post("/raporlar/dokuman_listesi?bicim=tablo", headers=y, json={}).json()
    assert any(s["ad"] == ad for s in once["satirlar"])

    client.delete(f"/dokumanlar/{d['id']}", headers=y)

    sonra = client.post("/raporlar/dokuman_listesi?bicim=tablo", headers=y, json={}).json()
    assert not any(s["ad"] == ad for s in sonra["satirlar"])


# --------------------------------------------------------------------------- #
# DOKUMAN LISTESI RAPORU
# --------------------------------------------------------------------------- #
def test_dokuman_raporu_KATALOGDA_ve_SUTUNLARI_dogru(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    katalog = client.get("/raporlar/katalog", headers=y).json()
    oge = next(o for o in katalog["items"] if o["kod"] == "dokuman_listesi")
    assert oge["kategori"] == "dokumler"

    r = client.post("/raporlar/dokuman_listesi?bicim=tablo", headers=y, json={})
    assert r.status_code == 200, r.text
    anahtarlar = [s["anahtar"] for s in r.json()["sutunlar"]]
    # Brief §6.3'un kolonlari: Eklenme Tarihi · Dokuman Adi (+ yukleyen,
    # boyut). BOYUT "sayi" tipinde: Excel'de TOPLAM alinabilsin diye.
    assert anahtarlar == ["tarih", "ad", "yukleyen", "boyut_kb"]
    tipler = {s["anahtar"]: s.get("tip") for s in r.json()["sutunlar"]}
    assert tipler["boyut_kb"] == "sayi"


def test_dokuman_raporu_EXCEL_uretir(client, world):
    # IKINCI BIR EXCEL YAZICISI YAZILMADI: rapor motorunun hatti
    # kullaniliyor. Bu test o hattin bu rapor icin de calistigini kilitler.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    _dokuman(client, y)
    r = client.post("/raporlar/dokuman_listesi?bicim=excel", headers=y, json={})
    assert r.status_code == 200, r.text
    assert len(r.content) > 100


# --------------------------------------------------------------------------- #
# YETKI
# --------------------------------------------------------------------------- #
def test_SAHA_ROLLERI_dokuman_ve_karar_goremez(client, world):
    for kim in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[kim])
        assert client.get("/dokumanlar", headers=h).status_code == 403, kim
        assert client.get("/karar-defteri", headers=h).status_code == 403, kim
