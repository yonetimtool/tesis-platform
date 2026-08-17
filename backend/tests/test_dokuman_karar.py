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
# SAKIN GORUNURLUGU (P167 ek)
# --------------------------------------------------------------------------- #
def test_YENI_dokuman_sakine_KAPALI_baslar(client, world):
    """Bu testin kilitledigi sey bir VARSAYILAN degil, bir KARAR.

    Arsivde ne oldugu sozlesmede belirli degil: yonetim plani da olabilir,
    personel sozlesmesi de. Acik varsayilan, gecmiste "yalnizca yonetim
    gorur" varsayimiyla yuklenmis her dosyayi yayina cikarirdi — ve geri
    almak, o arada indirilmis dosyalari geri getirmezdi.
    """
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    d = _dokuman(client, y)
    assert d["sakine_acik"] is False


def test_SAKIN_yalnizca_ACILANLARI_gorur(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = _headers(client, world["slug_a"], world["resident_a"])

    kapali = _dokuman(client, y, ad=f"Personel-{uuid.uuid4().hex[:6]}")
    acik = _dokuman(client, y, ad=f"YonetimPlani-{uuid.uuid4().hex[:6]}")
    assert client.patch(
        f"/dokumanlar/{acik['id']}", headers=y, json={"sakine_acik": True}
    ).status_code == 200

    liste = client.get("/me/dokumanlar", headers=r)
    assert liste.status_code == 200, liste.text
    idler = {x["id"] for x in liste.json()["items"]}
    assert acik["id"] in idler
    assert kapali["id"] not in idler
    # TOPLAM da yalniz gorunenleri sayar: sayac kapalilari sayarsa,
    # sayfalama sakine var olmayan bir sayfayi vaat ederdi. Olcum
    # KARSILASTIRMALI — yonetim sayaci sakin sayacindan BUYUK olmali,
    # yoksa "suzgec calisiyor" iddiasi bosa duserdi.
    sakin_toplam = liste.json()["meta"]["total"]
    yonetim_toplam = client.get("/dokumanlar?limit=1", headers=y).json()["meta"]["total"]
    assert sakin_toplam < yonetim_toplam, (sakin_toplam, yonetim_toplam)


def test_SAKIN_KAPALI_dokumani_INDIREMEZ_404(client, world):
    # 403 DEGIL 404: 403 "bu belge var ama sana kapali" demek olurdu ve
    # arsivde neyin BULUNDUGUNU dogrulardi.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = _headers(client, world["slug_a"], world["resident_a"])
    kapali = _dokuman(client, y)
    assert client.get(
        f"/me/dokumanlar/{kapali['id']}/indir", headers=r
    ).status_code == 404


def test_SAKIN_ACIK_dokumani_INDIREBILIR(client, world):
    # Karsilik testi: 404'un sebebi "sakin hic indiremiyor" olmasin.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = _headers(client, world["slug_a"], world["resident_a"])
    d = _dokuman(client, y)
    client.patch(f"/dokumanlar/{d['id']}", headers=y, json={"sakine_acik": True})
    res = client.get(f"/me/dokumanlar/{d['id']}/indir", headers=r)
    assert res.status_code == 200, res.text
    assert res.json()["url"].startswith("http")
    assert res.json()["dosya_adi"] == d["ad"]


def test_SILINEN_dokuman_ACIK_OLSA_da_sakine_GORUNMEZ(client, world):
    """Iki suzgec TEK ifadeden besleniyor; bu test onu kilitler.

    Ayri ayri yazilsaydi biri `silindi_at`i unutur ve silinmis bir dosya
    sakinde indirilebilir kalirdi.
    """
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = _headers(client, world["slug_a"], world["resident_a"])
    d = _dokuman(client, y)
    client.patch(f"/dokumanlar/{d['id']}", headers=y, json={"sakine_acik": True})
    client.delete(f"/dokumanlar/{d['id']}", headers=y)

    idler = {x["id"] for x in client.get("/me/dokumanlar", headers=r).json()["items"]}
    assert d["id"] not in idler
    assert client.get(
        f"/me/dokumanlar/{d['id']}/indir", headers=r
    ).status_code == 404


def test_SAKIN_YUKLEYEN_ADINI_gormez(client, world):
    # Sakinin ihtiyaci "hangi belge"; "kim yukledi" degil. Personel adini
    # her sakine dagitmak amac sinirliligiyla bagdasmazdi.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = _headers(client, world["slug_a"], world["resident_a"])
    d = _dokuman(client, y)
    client.patch(f"/dokumanlar/{d['id']}", headers=y, json={"sakine_acik": True})

    yonetim = next(
        x for x in client.get("/dokumanlar?limit=200", headers=y).json()["items"]
        if x["id"] == d["id"]
    )
    assert yonetim["yukleyen_ad"], "yonetim listesinde yukleyen adi OLMALI"

    sakin = next(
        x for x in client.get("/me/dokumanlar", headers=r).json()["items"]
        if x["id"] == d["id"]
    )
    assert sakin["yukleyen_ad"] is None


def test_SAKIN_YONETIM_ucuna_ULASAMAZ(client, world):
    """Sakin ucu ACILDI diye yonetim ucu ACILMADI.

    Yonetim ucu TUM arsivi doner; sakinin oraya erisebilmesi, gorunurluk
    bayragini tamamen anlamsiz kilardi.
    """
    r = _headers(client, world["slug_a"], world["resident_a"])
    assert client.get("/dokumanlar", headers=r).status_code == 403
    d_id = uuid.uuid4()
    assert client.get(f"/dokumanlar/{d_id}/indir", headers=r).status_code == 403
    assert client.patch(
        f"/dokumanlar/{d_id}", headers=r, json={"sakine_acik": True}
    ).status_code == 403


def test_SAHA_PERSONELI_sakin_ucunu_KULLANAMAZ(client, world):
    # Uc SAKIN icin acildi. Guvenlik ve gorevli tesisin sakini degil
    # calisanidir; site dokumani onlarin isi degil.
    for kim in ("guard_a", "gorevli_a"):
        h = _headers(client, world["slug_a"], world[kim])
        assert client.get("/me/dokumanlar", headers=h).status_code == 403, kim


# --------------------------------------------------------------------------- #
# YETKI
# --------------------------------------------------------------------------- #
def test_SAHA_ROLLERI_dokuman_ve_karar_goremez(client, world):
    for kim in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[kim])
        assert client.get("/dokumanlar", headers=h).status_code == 403, kim
        assert client.get("/karar-defteri", headers=h).status_code == 403, kim
