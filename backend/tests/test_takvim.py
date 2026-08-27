"""(P167 Asama 2) TAKVIM + KISISEL HATIRLATMA + PANO TERCIHI.

EN PAHALI SONUCLAR, testin agirligi da orada:

 1. SIZINTI. Hatirlatma KISISELDIR; ayni tesisteki baska bir yonetici bile
    gormemeli. Takvim ucu alti kaynagi birlestirdigi icin bu kural en kolay
    orada kaybolur — bir `where` dusse uc "calisir" gorunmeye devam eder.
 2. TEKRAR GENISLETMESI. "Her hafta" bir KURALDIR; pencereye dogru
    genisletilmezse kullanici hatirlatmasini HIC gormez (ya da yuz binlerce
    satir uretilir). Ay sonu (31 -> subat) ozellikle olculuyor.
 3. PENCERE SINIRI. Sinirsiz aralik, alti tablonun tamamini tek istekte
    suzdurmek olurdu.
 4. PANO TERCIHI SEMASI. JSONB serbest gorunur; uc tanimadigi anahtari
    ATMALI, yoksa sozlesme bosluguna doner.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).isoformat()


def _simdi() -> datetime:
    # Testler CANLI sunucuya gidiyor (repo notu): zaman bagimli olcumler
    # sabit tarih degil GERCEK SIMDIYE gore kurulur.
    return datetime.now(timezone.utc).replace(microsecond=0)


# --------------------------------------------------------------------------- #
# 1. HATIRLATMA CRUD + SAHIPLIK
# --------------------------------------------------------------------------- #
def test_hatirlatma_ekle_listele_guncelle_sil(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    an = _simdi() + timedelta(days=1)

    r = client.post("/hatirlatmalar", headers=y, json={
        "baslik": "Kazan bakimi", "baslangic": _iso(an), "renk": "turuncu",
    })
    assert r.status_code == 201, r.text
    hid = r.json()["id"]
    assert r.json()["tekrar"] == "yok"

    assert any(h["id"] == hid for h in client.get("/hatirlatmalar", headers=y).json())

    r = client.patch(f"/hatirlatmalar/{hid}", headers=y, json={"baslik": "Kazan servisi"})
    assert r.status_code == 200, r.text
    assert r.json()["baslik"] == "Kazan servisi"

    assert client.delete(f"/hatirlatmalar/{hid}", headers=y).status_code == 204
    assert not [h for h in client.get("/hatirlatmalar", headers=y).json() if h["id"] == hid]


def test_hatirlatma_BASKASININ_kaydina_dokunulamaz(client, world):
    # Ayni TESISIN iki yoneticisi. Kayit tenant'a degil KISIYE ait.
    a = _headers(client, world["slug_a"], world["yonetici_a"])
    b = _headers(client, world["slug_a"], world["admin_a"])
    an = _simdi() + timedelta(days=2)

    hid = client.post("/hatirlatmalar", headers=a, json={
        "baslik": "Ozel not", "baslangic": _iso(an),
    }).json()["id"]

    # B listede GORMEZ.
    assert not [h for h in client.get("/hatirlatmalar", headers=b).json() if h["id"] == hid]
    # B guncelleyemez ve silemez — ikisi de 404 ("senin degil" demek,
    # o kaydin VAR OLDUGUNU dogrulamak olurdu).
    assert client.patch(f"/hatirlatmalar/{hid}", headers=b,
                        json={"baslik": "x"}).status_code == 404
    assert client.delete(f"/hatirlatmalar/{hid}", headers=b).status_code == 404


def test_hatirlatma_bos_baslik_ve_ters_aralik_422(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    an = _simdi() + timedelta(days=1)

    assert client.post("/hatirlatmalar", headers=y, json={
        "baslik": "   ", "baslangic": _iso(an),
    }).status_code == 422
    assert client.post("/hatirlatmalar", headers=y, json={
        "baslik": "Ters", "baslangic": _iso(an), "bitis": _iso(an - timedelta(hours=1)),
    }).status_code == 422


def test_hatirlatma_KISMI_guncellemede_de_aralik_denetlenir(client, world):
    """Yalniz `bitis` gonderildiginde sema onu TEK BASINA gorur.

    Sema kaydin MEVCUT `baslangic`ini bilmez; kontrol birlesmis deger
    uzerinde yapilmasaydi hata veritabani kisitindan 500 olarak doner ve
    sebebi ekranda hic gorunmezdi.
    """
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    an = _simdi() + timedelta(days=3)
    hid = client.post("/hatirlatmalar", headers=y, json={
        "baslik": "Aralik", "baslangic": _iso(an),
    }).json()["id"]

    r = client.patch(f"/hatirlatmalar/{hid}", headers=y,
                     json={"bitis": _iso(an - timedelta(hours=2))})
    assert r.status_code == 422, r.text


def test_hatirlatma_SAHA_ROLLERINE_kapali(client, world):
    for kim in ("guard_a", "gorevli_a", "resident_a", "denetci_a"):
        h = _headers(client, world["slug_a"], world[kim])
        assert client.get("/hatirlatmalar", headers=h).status_code == 403, kim


# --------------------------------------------------------------------------- #
# 2. TAKVIM
# --------------------------------------------------------------------------- #
def test_takvim_kendi_hatirlatmasini_gosterir_baskasininkini_GOSTERMEZ(client, world):
    a = _headers(client, world["slug_a"], world["yonetici_a"])
    b = _headers(client, world["slug_a"], world["admin_a"])
    an = _simdi() + timedelta(days=1)
    client.post("/hatirlatmalar", headers=a, json={
        "baslik": "A-nin notu", "baslangic": _iso(an),
    })

    pencere = {"baslangic": _iso(an - timedelta(days=1)),
               "bitis": _iso(an + timedelta(days=1))}

    r = client.get("/takvim", headers=a, params=pencere)
    assert r.status_code == 200, r.text
    basliklar = [o["baslik"] for o in r.json()["items"] if o["tip"] == "hatirlatma"]
    assert "A-nin notu" in basliklar

    r = client.get("/takvim", headers=b, params=pencere)
    assert "A-nin notu" not in [
        o["baslik"] for o in r.json()["items"] if o["tip"] == "hatirlatma"
    ]


def test_takvim_HAFTALIK_tekrar_pencerede_genisletilir(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    # GECMISTE baslasin: sorgu `baslangic <= pencere_sonu` ile suzuyor ve
    # ust sinir YOK — cok once baslamis bir kural bugunku pencereye
    # dusmeli. Ust sinir konsaydi bu satir ELENIRDI.
    ilk = _simdi() - timedelta(days=70)
    client.post("/hatirlatmalar", headers=y, json={
        "baslik": "Haftalik toplanti", "baslangic": _iso(ilk), "tekrar": "haftalik",
    })

    bas = _simdi()
    r = client.get("/takvim", headers=y, params={
        "baslangic": _iso(bas), "bitis": _iso(bas + timedelta(days=28)),
    })
    assert r.status_code == 200, r.text
    ornekler = [o for o in r.json()["items"]
                if o["tip"] == "hatirlatma" and o["baslik"] == "Haftalik toplanti"]
    # 28 gunluk pencerede dort ya da bes ornek (ilk gunun konumuna gore).
    assert 4 <= len(ornekler) <= 5, ornekler
    # TEKRAR EDEN KAYIT COGALTILMAZ: hepsi AYNI id'yi tasir.
    assert len({o["id"] for o in ornekler}) == 1


def test_takvim_AYLIK_tekrar_ay_sonunu_kaydirmaz_ATLAMAZ(client, world):
    """Ayin 31'i olmayan aylarda kayit AYIN SON GUNUNE cekilir.

    Atlamak, "her ayin 31'i" diyen bir hatirlatmanin subatta HIC
    gorunmemesi demekti; ileri kaydirmak ise onu marta tasirdi.
    """
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    # 31 Ocak: subat/nisan gibi aylarda karsiligi yok.
    ilk = datetime(2026, 1, 31, 9, 0, tzinfo=timezone.utc)
    client.post("/hatirlatmalar", headers=y, json={
        "baslik": "Ay sonu kapanis", "baslangic": _iso(ilk), "tekrar": "aylik",
    })

    r = client.get("/takvim", headers=y, params={
        "baslangic": _iso(datetime(2026, 2, 1, tzinfo=timezone.utc)),
        "bitis": _iso(datetime(2026, 3, 31, 23, 59, tzinfo=timezone.utc)),
    })
    gunler = sorted(
        o["baslangic"][:10] for o in r.json()["items"]
        if o["tip"] == "hatirlatma" and o["baslik"] == "Ay sonu kapanis"
    )
    # 2026 artik yil DEGIL -> subat 28 gun.
    assert gunler == ["2026-02-28", "2026-03-31"], gunler


def test_takvim_pencere_zorunlu_ve_sinirli(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    bas = _simdi()
    # Ters aralik.
    assert client.get("/takvim", headers=y, params={
        "baslangic": _iso(bas), "bitis": _iso(bas - timedelta(days=1)),
    }).status_code == 422
    # 120 gunden genis.
    assert client.get("/takvim", headers=y, params={
        "baslangic": _iso(bas), "bitis": _iso(bas + timedelta(days=200)),
    }).status_code == 422
    # Parametresiz.
    assert client.get("/takvim", headers=y).status_code == 422


def test_takvim_ETKINLIGI_gosterir(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    an = _simdi() + timedelta(days=2)
    r = client.post("/events", headers=y, json={
        "baslik": "Site toplantisi", "aciklama": "Yillik genel kurul",
        "tarih": _iso(an),
    })
    assert r.status_code in (200, 201), r.text

    items = client.get("/takvim", headers=y, params={
        "baslangic": _iso(an - timedelta(days=1)),
        "bitis": _iso(an + timedelta(days=1)),
    }).json()["items"]
    assert any(o["tip"] == "etkinlik" and o["baslik"] == "Site toplantisi" for o in items)


def test_takvim_ZAMANA_gore_sirali(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    bas = _simdi()
    for gun in (5, 1, 3):
        client.post("/hatirlatmalar", headers=y, json={
            "baslik": f"N{gun}", "baslangic": _iso(bas + timedelta(days=gun)),
        })
    items = client.get("/takvim", headers=y, params={
        "baslangic": _iso(bas), "bitis": _iso(bas + timedelta(days=10)),
    }).json()["items"]
    zamanlar = [o["baslangic"] for o in items]
    assert zamanlar == sorted(zamanlar)


# --------------------------------------------------------------------------- #
# 3. PANO TERCIHI
# --------------------------------------------------------------------------- #
def test_pano_tercihi_bos_baslar_ve_yazilir(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    # BOS NESNE = "varsayilani kullan". Sunucu bir varsayilan URETMEZ.
    assert client.get("/me/pano-tercihi", headers=y).json() == {}

    duzen = {
        "widgetlar": [{"rota": "/dues"}, {"rota": "/finans?tip=gelir"}],
        "bolumler": [{"id": "takvim", "gizli": False}, {"id": "maket", "gizli": True}],
    }
    r = client.put("/me/pano-tercihi", headers=y, json=duzen)
    assert r.status_code == 200, r.text
    assert client.get("/me/pano-tercihi", headers=y).json() == duzen


def test_pano_tercihi_SATIRLAR_yazilir_ve_doner(client, world):
    # (P181 7.1/7.2) Satır bazlı yerleşim: sütun (1-4) + idler + banner.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    duzen = {
        "satirlar": [
            {"sutun": 2, "idler": ["finans", "maket"], "baslik": "Genel Bakış"},
            {"sutun": 1, "idler": ["takvim"]},
        ],
    }
    r = client.put("/me/pano-tercihi", headers=y, json=duzen)
    assert r.status_code == 200, r.text
    donen = client.get("/me/pano-tercihi", headers=y).json()
    assert donen["satirlar"][0]["sutun"] == 2
    assert donen["satirlar"][0]["idler"] == ["finans", "maket"]
    assert donen["satirlar"][0]["baslik"] == "Genel Bakış"
    assert donen["satirlar"][1]["sutun"] == 1


def test_pano_tercihi_SATIR_sutun_1_4_disi_422(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.put(
        "/me/pano-tercihi", headers=y,
        json={"satirlar": [{"sutun": 5, "idler": []}]},
    )
    assert r.status_code == 422


def test_pano_tercihi_TANIMADIGI_anahtari_ATAR(client, world):
    # JSONB serbest gorunur; uc semayla dogrular. Aksi hâlde arayuz
    # degistiginde veritabaninda hangi seklin durdugu bilinemez olurdu.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.put("/me/pano-tercihi", headers=y, json={
        "widgetlar": [{"rota": "/dues"}], "uydurma_alan": {"a": 1},
    })
    assert r.status_code == 200, r.text
    assert "uydurma_alan" not in r.json()


def test_pano_tercihi_ALTI_WIDGET_SINIRI_sunucuda(client, world):
    # Sinir istemcide kalsaydi, asan bir istek seridi tasiran bir pano
    # uretirdi ve kimse fark etmezdi.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.put("/me/pano-tercihi", headers=y, json={
        "widgetlar": [{"rota": f"/x{i}"} for i in range(7)],
    })
    assert r.status_code == 422, r.text


def test_pano_tercihi_HER_ROLE_acik_ve_KENDI_kaydi(client, world):
    a = _headers(client, world["slug_a"], world["yonetici_a"])
    s = _headers(client, world["slug_a"], world["resident_a"])
    client.put("/me/pano-tercihi", headers=a, json={"widgetlar": [{"rota": "/dues"}]})
    # Sakin de kendi kaydini yazabilir ve A'nininkini GORMEZ.
    assert client.get("/me/pano-tercihi", headers=s).json() == {}
    assert client.put("/me/pano-tercihi", headers=s,
                      json={"widgetlar": [{"rota": "/aidatim"}]}).status_code == 200
    assert client.get("/me/pano-tercihi", headers=a).json()["widgetlar"] == [
        {"rota": "/dues"}
    ]


# --------------------------------------------------------------------------- #
# 4. FINANS OZETININ UC YENI KARTI
# --------------------------------------------------------------------------- #
def test_ozet_BORCLARIM_ve_ONAY_BEKLEYEN_ve_ODENMIS_FATURA(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    kasa = client.post("/kasalar", headers=admin, json={
        "kod": f"K{uuid.uuid4().hex[:6]}", "ad": "Test Kasa",
    })
    assert kasa.status_code in (200, 201), kasa.text
    kasa_id = kasa.json()["id"]

    once = client.get("/finans/ozet", headers=admin).json()

    r = client.post("/finans/hareketler", headers=admin, json={"satirlar": [
        # Odenmemis gider -> "Borclarim"
        {"tip": "gider", "tutar_kurus": 30000, "kasa_id": kasa_id, "durum": "bekliyor"},
        # Onay bekleyen -> adet
        {"tip": "gider", "tutar_kurus": 10000, "kasa_id": kasa_id,
         "durum": "onay_bekliyor"},
        # Odenmis gider (bu ay) -> "Odenmis Faturalar"
        {"tip": "gider", "tutar_kurus": 20000, "kasa_id": kasa_id},
    ]})
    assert r.status_code == 201, r.text
    # VARSAYILAN `odendi`: govdede `durum` gonderilmeyen satir odenmis sayilir.
    assert [s["durum"] for s in r.json()["items"]] == [
        "bekliyor", "onay_bekliyor", "odendi"
    ]

    sonra = client.get("/finans/ozet", headers=admin).json()
    # `bekliyor` + `onay_bekliyor` = odenmemis toplam.
    assert sonra["borc_kurus"] - once["borc_kurus"] == 40000
    assert sonra["onay_bekleyen_adet"] - once["onay_bekleyen_adet"] == 1
    assert sonra["odenmis_fatura_ay_kurus"] - once["odenmis_fatura_ay_kurus"] == 20000
