"""(DUKKAN F1) KAMU UCLARI — akisi GERCEKTEN surerek olcer.

Testler CANLI sunucuya gider (`client` fixture'i api konteynerine httpx
ile baglanir). Repo katmanini taklit etmiyoruz: P198 ve P200'de ayni
dikisten kirildik — repo duzeyinde taklit, tam da olcmek istedigimiz
serilestirme ve yonlendirme katmanini ATLIYOR.
"""
from __future__ import annotations


def test_IL_listesi_KIMLIKSIZ_erisilebilir(client):
    """SEO'nun tamami buna bagli: bot ve uye olmayan ziyaretci gorebilmeli."""
    r = client.get("/dukkan/lokasyon/il")
    assert r.status_code == 200, r.text
    iller = r.json()["items"]
    assert len(iller) == 81, f"il sayisi {len(iller)}"
    assert all("ad" in x and "slug" in x for x in iller)


def test_IL_listesi_TURKCE_SIRALI(client):
    """'Ağrı' 'Aksaray'dan ONCE gelmeli (Turkce harmanda ğ < k).

    Alfabetik sira kullanicinin il'i bulmasinin tek yolu; varsayilan
    (C) harmanda Turkce harfler listenin SONUNA dusup arayuzu bozardi.
    """
    adlar = [x["ad"] for x in client.get("/dukkan/lokasyon/il").json()["items"]]
    assert adlar[:5] == ["Adana", "Adıyaman", "Afyonkarahisar", "Ağrı", "Aksaray"], adlar[:5]


def test_ILCE_listesi(client):
    r = client.get("/dukkan/lokasyon/il/istanbul/ilce")
    assert r.status_code == 200
    d = r.json()
    assert d["il"]["ad"] == "İstanbul"
    assert len(d["items"]) == 39, "Istanbul 39 ilce"
    assert any(x["slug"] == "cekmekoy" for x in d["items"])


def test_OLMAYAN_il_404_doner_BOS_LISTE_DEGIL(client):
    """Bos liste, yanlis yazilmis bir slug'i 'bu ilde hic ilce yok' gibi
    gosterir ve hatayi GIZLERDI. Sessiz basarisizlik yok."""
    r = client.get("/dukkan/lokasyon/il/boyle-bir-il-yok/ilce")
    assert r.status_code == 404, r.text


def test_MAHALLE_listesi_ve_TURKCE_ONARIMI_UCTAN_gorunur(client):
    """Onarim yalniz veritabaninda degil, KULLANICIYA giden yanitta da olmali."""
    r = client.get("/dukkan/lokasyon/il/istanbul/ilce/cekmekoy/mahalle")
    assert r.status_code == 200
    items = r.json()["items"]
    assert len(items) == 21
    adlar = [x["ad"] for x in items]
    assert "Çatalmeşe" in adlar, adlar
    # Bozuk birlesen nokta HICBIR adda olmamali.
    assert not any("̇" in a for a in adlar), "yanitta BOZUK ad var"


def test_MAHALLE_ARAMASI(client):
    r = client.get(
        "/dukkan/lokasyon/il/istanbul/ilce/cekmekoy/mahalle", params={"q": "çatal"}
    )
    assert r.status_code == 200
    assert [x["slug"] for x in r.json()["items"]] == ["catalmese"]


def test_ARAMA_TURKCE_HARFSIZ_de_bulur(client):
    """AKISI SURERKEN OLCULDU: "catal" yazan kullanici HICBIR SEY
    bulamiyordu, oysa "Çatalmeşe" oradaydi.

    Turkce klavyesi olmayan ya da hizli yazan biri "cekmekoy", "catal",
    "sisli" yazar. Mahalle aramasi hem sakinin kendi mahallesini sectigi
    hem de USTANIN hizmet alani sectigi yer; bos sonuc "burada mahalle
    yok" gibi okunur ve akis orada durur.

    Cozum bedavaydi: `slug` sutunu zaten ASCII'ye katlanmis halde
    duruyordu (SEO icin uretilmisti). `unaccent` eklentisi gerekmedi.
    """
    yol = "/dukkan/lokasyon/il/istanbul/ilce/cekmekoy/mahalle"
    for q in ("çatal", "catal", "CATAL", "Çatalmeşe", "catalmese"):
        r = client.get(yol, params={"q": q})
        assert r.status_code == 200, r.text
        adlar = [x["ad"] for x in r.json()["items"]]
        assert adlar == ["Çatalmeşe"], f"q={q!r} -> {adlar}"


def test_MAHALLE_UCU_KIMLIK_DONDURUR(client):
    """`id` OLMADAN arayuz hizmet alani SECEMEZ — ilk yazimda tam bu
    bosluk vardi ve web'den basvuru TAMAMLANAMIYORDU.

    Hizmet alani ucu (`PUT /dukkan/isletme/{id}/hizmet-alanlari`) mahalle
    KIMLIGI ister, cunku mahalle slug'i yalniz ILCE ICINDE benzersizdir.
    Kamu ucu yalniz slug dondurseydi liste "gorunuyor ama secilemiyor"
    olurdu; isletme hizmet alani secemez, hizmet alani olmadan da basvuru
    yapamazdi. Backend kusursuz gorunurken akis SESSIZCE tikanirdi.
    """
    import uuid as _uuid

    r = client.get("/dukkan/lokasyon/il/istanbul/ilce/cekmekoy/mahalle")
    assert r.status_code == 200
    items = r.json()["items"]
    assert items
    for x in items:
        assert "id" in x, f"mahalle kaydinda `id` yok: {x}"
        # Gercekten UUID mi? Bos ya da bozuk bir dizge, hizmet alani
        # ucunda 422 uretir ve hata mahalle ucunda oldugu icin teshis
        # edilmesi zor olurdu.
        _uuid.UUID(x["id"])


def test_ILCE_SLUGU_IL_ICINDE_benzersiz_yol_bunu_yansitiyor(client):
    """Turkiye'de birden cok ilde "Merkez" ilcesi var.

    Yol il slug'ini de tasidigi icin iki farkli "merkez" birbirine
    karismiyor. Bu test onu davranistan dogruluyor.
    """
    a = client.get("/dukkan/lokasyon/il/bayburt/ilce/merkez/mahalle")
    b = client.get("/dukkan/lokasyon/il/yalova/ilce/merkez/mahalle")
    assert a.status_code == 200 and b.status_code == 200
    assert a.json()["items"] != b.json()["items"], (
        "iki farkli ilin 'merkez' ilcesi ayni mahalleleri donduruyor — "
        "ilce slug'i il baglamindan KOPMUS"
    )


def test_KATEGORI_agaci(client):
    r = client.get("/dukkan/kategori")
    assert r.status_code == 200
    analar = r.json()["items"]
    assert len(analar) >= 10
    # Iki seviye: her ananin alt listesi var.
    assert all("alt" in x for x in analar)
    tum_alt = {a["slug"] for x in analar for a in x["alt"]}
    # brief'in ornek SEO yolunun kategori parcasi.
    assert "elektrikci" in tum_alt
    assert "ev-temizligi" in tum_alt


def test_KATEGORI_UCUNCU_SEVIYE_YOK(client):
    """Iki seviye BILINCLI bir karar (docs/dukkan/01-veri-modeli.md §3).

    Ucuncu seviye hem URL'i hem kullaniciyi uzatir; daraltma V2'de
    kategoriye bagli SORU SETI ile yapilacak.
    """
    for ana in client.get("/dukkan/kategori").json()["items"]:
        for alt in ana["alt"]:
            assert "alt" not in alt, f"{alt['slug']} ucuncu seviye tasiyor"


def test_BRIEFTEKI_SEO_YOLU_ucundan_cozulebiliyor(client):
    """/istanbul/cekmekoy/catalmese/elektrikci — brief'in ornegi.

    Bu yolun her parcasinin API'den cozulebilir olmasi, SEO sayfasinin
    sunucuda cizilebilmesi demek.
    """
    il = client.get("/dukkan/lokasyon/il").json()["items"]
    assert any(x["slug"] == "istanbul" for x in il)
    ic = client.get("/dukkan/lokasyon/il/istanbul/ilce").json()["items"]
    assert any(x["slug"] == "cekmekoy" for x in ic)
    m = client.get(
        "/dukkan/lokasyon/il/istanbul/ilce/cekmekoy/mahalle"
    ).json()["items"]
    assert any(x["slug"] == "catalmese" for x in m)
    k = {a["slug"] for x in client.get("/dukkan/kategori").json()["items"]
         for a in x["alt"]}
    assert "elektrikci" in k


def test_DUKKAN_UCLARI_YAZMA_KABUL_ETMEZ(client):
    """Lokasyon/kategori HTTP uzerinden DEGISTIRILEMEZ.

    Bu iki tablo SEO yollarinin temeli; bir uctan yanlislikla
    degistirilebilir olmalari, canli baglantilarin sessizce olmesi
    demekti. 405 = metot yok (dogru cevap).
    """
    for metot, yol in [
        ("post", "/dukkan/lokasyon/il"),
        ("post", "/dukkan/kategori"),
        ("delete", "/dukkan/kategori"),
        ("put", "/dukkan/lokasyon/il"),
    ]:
        r = getattr(client, metot)(yol)
        assert r.status_code == 405, f"{metot.upper()} {yol} -> {r.status_code}"
