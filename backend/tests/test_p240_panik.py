"""(P240 §1) PANIK BUTONU — uctan uca akis.

===========================================================================
NE OLCULUYOR
===========================================================================
Kabul kriterleri sirasiyla:
  1. Uc tip, DOGRU kisilere gidiyor (ve yanlis role gitmiyor).
  2. Iptal penceresi: iptal edilirse HICBIR bildirim yok.
  3. Takip: kim gordu, kim mudahale etti, ne zaman kapandi, sure.
  4. Suistimal kisiti GERCEK ACILI ENGELLEMIYOR (reddetme yok).
  5. Yetki askisi sureli ve satir yine de yaziliyor.

BROKER YOK: testte Celery calismiyor, yani `_yayin_planla` ya kuyruga
yazar ya da duser. Ikisi de olcumu bozmasin diye testler yayini ACIKCA
tetikler (`_yayinla`) — gercek akista bunu gecikmeli gorev yapar.
"""
from __future__ import annotations

import datetime as dt
import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _uid(client, h):
    return client.get("/me", headers=h).json()["id"]


def _yayinla(alarm_id: str, tenant_slug: str, client, admin):
    """Gecikmeli yayini ELDE tetikler (broker yok).

    Tenant kimligini `/me`den alir: gorev RLS baglamini kendisi kurar.
    """
    from app.tasks import panik_yayinla

    tid = client.get("/me", headers=admin).json()["tenant_id"]
    return panik_yayinla(alarm_id, tid)


# ============================== 1) UC TIP ================================= #
def test_sakin_panigi_GUVENLIGE_ve_YONETIME_gider(client, world):
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard_id = _uid(client, _headers(client, world["slug_a"], world["guard_a"]))

    r = client.post("/panik", headers=sakin, json={"tip": "sakin"})
    assert r.status_code == 201, r.text
    alarm = r.json()
    assert alarm["durum"] == "beklemede", "yayin HENUZ yapilmamali"
    assert alarm["iptal_penceresi_sn"] >= 1
    # Alici satirlari da HENUZ YOK: iptal penceresi icinde kimse
    # rahatsiz edilmedi.
    assert alarm["alicilar"] == []

    _yayinla(alarm["id"], world["slug_a"], client, admin)

    d = client.get(f"/panik/{alarm['id']}", headers=admin).json()
    assert d["durum"] == "acik"
    alici_idler = {a["user_id"] for a in d["alicilar"]}
    assert guard_id in alici_idler, "guvenlik almali"
    roller = {a["rol"] for a in d["alicilar"]}
    assert "resident" not in roller, "DIGER SAKINLER almamali (kisisel veri)"


def test_sakin_panigini_YONETICI_TETIKLEYEMEZ(client, world):
    # Yoneticinin dairesi yoktur; onun actigi "sakin panigi" alicilara
    # gidecek ADRESI OLMAYAN bir alarm olurdu. Dogru dugme `guvenlik`.
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    assert client.post("/panik", headers=yon, json={"tip": "sakin"}).status_code == 403


def test_yonetici_anonsu_HERKESE_gider(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])
    sakin_id = _uid(client, _headers(client, world["slug_a"], world["resident_a"]))

    r = client.post("/panik", headers=yon, json={"tip": "yonetici_anons"})
    assert r.status_code == 201, r.text
    _yayinla(r.json()["id"], world["slug_a"], client, admin)

    d = client.get(f"/panik/{r.json()['id']}", headers=admin).json()
    assert sakin_id in {a["user_id"] for a in d["alicilar"]}, "sakinler de almali"


def test_anonsu_SAKIN_TETIKLEYEMEZ(client, world):
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    r = client.post("/panik", headers=sakin, json={"tip": "yonetici_anons"})
    assert r.status_code == 403


def test_tetikleyen_KENDI_alarminin_alicisi_DEGIL(client, world):
    # Kendi telefonunda calan alarm yeni bir bilgi vermez ve "kim gordu"
    # olcusunu kirletirdi.
    guard_h = _headers(client, world["slug_a"], world["guard_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard_id = _uid(client, guard_h)

    r = client.post("/panik", headers=guard_h, json={"tip": "guvenlik"})
    _yayinla(r.json()["id"], world["slug_a"], client, admin)
    d = client.get(f"/panik/{r.json()['id']}", headers=admin).json()
    assert guard_id not in {a["user_id"] for a in d["alicilar"]}


# ============================ 2) IPTAL ==================================== #
def test_IPTAL_PENCERESINDE_iptal_HICBIR_BILDIRIM_GITMEZ(client, world):
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])

    alarm = client.post("/panik", headers=sakin, json={"tip": "sakin"}).json()
    r = client.post(f"/panik/{alarm['id']}/iptal", headers=sakin)
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "iptal"

    # Gecikmeli gorev SONRADAN kossa bile yayin YAPMAZ.
    _yayinla(alarm["id"], world["slug_a"], client, admin)
    d = client.get(f"/panik/{alarm['id']}", headers=admin).json()
    assert d["durum"] == "iptal"
    assert d["alicilar"] == [], "iptal sonrasi alici OLMAMALI"


def test_GONDERILDIKTEN_SONRA_iptal_YANLIS_ALARM_olur(client, world):
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])

    alarm = client.post("/panik", headers=sakin, json={"tip": "sakin"}).json()
    _yayinla(alarm["id"], world["slug_a"], client, admin)

    r = client.post(f"/panik/{alarm['id']}/iptal", headers=sakin)
    assert r.status_code == 200, r.text
    # `iptal` ile `yanlis_alarm` AYRI: birincisinde kimse rahatsiz
    # edilmedi, ikincisinde edildi.
    assert r.json()["durum"] == "yanlis_alarm"
    assert r.json()["alicilar"], "rahatsiz edilenler KAYITLI kalmali"


def test_BASKASININ_alarmini_IPTAL_EDEMEZSIN(client, world):
    # Gercek bir acili susturmanin en kolay yolu bu olurdu.
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    alarm = client.post("/panik", headers=sakin, json={"tip": "sakin"}).json()
    assert client.post(f"/panik/{alarm['id']}/iptal", headers=yon).status_code == 403


# ============================ 3) TAKIP ==================================== #
def test_GORDUM_MUDAHALE_KAPAT_ve_SURE(client, world):
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    guard_id = _uid(client, guard)

    alarm = client.post("/panik", headers=sakin, json={"tip": "sakin"}).json()
    _yayinla(alarm["id"], world["slug_a"], client, admin)

    r = client.post(f"/panik/{alarm['id']}/gordum", headers=guard)
    assert r.status_code == 200, r.text
    benim = [a for a in r.json()["alicilar"] if a["user_id"] == guard_id][0]
    assert benim["goruldu_at"] is not None
    assert benim["mudahale_at"] is None

    r = client.post(f"/panik/{alarm['id']}/mudahale", headers=guard)
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "mudahale"
    assert r.json()["mudahale_suresi_sn"] is not None

    r = client.post(
        f"/panik/{alarm['id']}/kapat", headers=guard, json={"kapanis_notu": "Yanlislikla"}
    )
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "kapandi"
    assert r.json()["kapanis_notu"] == "Yanlislikla"
    assert r.json()["kapatan_user_id"] == guard_id


def test_ALICI_OLMAYAN_gordum_DIYEMEZ(client, world):
    # Olcum "alarmi ALANLARIN kaci gordu" sorusudur; alici olmayan biri
    # o paydayi bozardi.
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])
    alarm = client.post("/panik", headers=sakin, json={"tip": "sakin"}).json()
    _yayinla(alarm["id"], world["slug_a"], client, admin)
    assert client.post(f"/panik/{alarm['id']}/gordum", headers=sakin).status_code == 403


def test_AKTIF_UCU_yalniz_BANA_gelenleri_doner(client, world):
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])

    alarm = client.post("/panik", headers=sakin, json={"tip": "sakin"}).json()
    # Yayinlanmadan once: `beklemede` alarm AKTIF listede GORUNMEZ,
    # yoksa iptal penceresi anlamsiz olurdu.
    assert all(a["id"] != alarm["id"] for a in client.get("/panik/aktif", headers=guard).json())

    _yayinla(alarm["id"], world["slug_a"], client, admin)
    assert any(a["id"] == alarm["id"] for a in client.get("/panik/aktif", headers=guard).json())
    # Tetikleyen ALICI DEGIL -> kendi aktif listesinde yok.
    assert all(a["id"] != alarm["id"] for a in client.get("/panik/aktif", headers=sakin).json())

    # "GORDUM" DEDIKTEN SONRA EKRANI KAPLAMAZ: kapatilamaz bir uyariyi
    # sonsuz bir engele cevirmek olurdu. Alarm TAKIP LISTESINDE kalir.
    client.post(f"/panik/{alarm['id']}/gordum", headers=guard)
    assert all(a["id"] != alarm["id"] for a in client.get("/panik/aktif", headers=guard).json())
    assert any(
        a["id"] == alarm["id"] for a in client.get("/panik", headers=guard).json()["items"]
    )


def test_SAKIN_LISTEDE_yalniz_KENDI_alarmlarini_gorur(client, world):
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    guard_h = _headers(client, world["slug_a"], world["guard_a"])
    sakin_id = _uid(client, sakin)

    client.post("/panik", headers=guard_h, json={"tip": "guvenlik"})
    client.post("/panik", headers=sakin, json={"tip": "sakin"})

    items = client.get("/panik", headers=sakin).json()["items"]
    assert items, "kendi alarmini gormeli"
    assert all(a["olusturan_user_id"] == sakin_id for a in items)


# ========================= 4) SUISTIMAL =================================== #
def test_TEKRAR_BASMA_REDDEDILMEZ_yeni_alarm_da_URETMEZ(client, world):
    # Gercek acil durumda ikinci kez basan kisi "duyulmadi" diye
    # dusunuyordur; istegi REDDETMEK tam o anda alarmi susturmak olurdu.
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    ilk = client.post("/panik", headers=sakin, json={"tip": "sakin"})
    assert ilk.status_code == 201
    for _ in range(5):
        tekrar = client.post("/panik", headers=sakin, json={"tip": "sakin"})
        assert tekrar.status_code == 201, "asla reddedilmemeli"
        assert tekrar.json()["id"] == ilk.json()["id"], "YENI alarm uretmemeli"


def test_YANLIS_ALARM_SAYACI_aliciya_baglam_verir(client, world):
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])

    a1 = client.post("/panik", headers=sakin, json={"tip": "sakin"}).json()
    client.post(f"/panik/{a1['id']}/iptal", headers=sakin)

    a2 = client.post("/panik", headers=sakin, json={"tip": "sakin"}).json()
    _yayinla(a2["id"], world["slug_a"], client, admin)
    d = client.get(f"/panik/{a2['id']}", headers=admin).json()
    assert d["son_24s_yanlis_alarm"] >= 1


# ========================== 5) YETKI ASKISI =============================== #
def test_ASKI_bildirimi_KESER_ama_SATIR_YAZILIR(client, world):
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])
    sakin_id = _uid(client, sakin)

    bitis = (dt.datetime.now(dt.timezone.utc) + dt.timedelta(hours=2)).isoformat()
    r = client.patch(
        f"/users/{sakin_id}/panik-aski", headers=admin,
        json={"bitis": bitis, "neden": "Gunde on kez basiyor"},
    )
    assert r.status_code == 200, r.text

    alarm = client.post("/panik", headers=sakin, json={"tip": "sakin"}).json()
    # Satir YAZILDI (denetim) ama yayin YAPILMADI.
    assert alarm["durum"] == "iptal"
    _yayinla(alarm["id"], world["slug_a"], client, admin)
    d = client.get(f"/panik/{alarm['id']}", headers=admin).json()
    assert d["alicilar"] == []

    # ASKI KALKINCA yeniden calisir.
    assert client.delete(f"/users/{sakin_id}/panik-aski", headers=admin).status_code == 200
    yeni = client.post("/panik", headers=sakin, json={"tip": "sakin"}).json()
    assert yeni["durum"] == "beklemede"


def test_ASKI_GECMIS_TARIH_ve_KENDINE_REDDEDILIR(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    admin_id = _uid(client, admin)
    sakin_id = _uid(client, _headers(client, world["slug_a"], world["resident_a"]))

    gecmis = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=1)).isoformat()
    r = client.patch(
        f"/users/{sakin_id}/panik-aski", headers=admin,
        json={"bitis": gecmis, "neden": "test"},
    )
    assert r.status_code == 422, "gecmis tarih 'askiyi kaldir'in yanlis yazimi olurdu"

    ileri = (dt.datetime.now(dt.timezone.utc) + dt.timedelta(hours=1)).isoformat()
    r = client.patch(
        f"/users/{admin_id}/panik-aski", headers=admin,
        json={"bitis": ileri, "neden": "test"},
    )
    assert r.status_code == 422, "kendi panik yetkisini kapatamaz"


def test_ASKI_YALNIZ_YONETIM(client, world):
    guard = _headers(client, world["slug_a"], world["guard_a"])
    sakin_id = _uid(client, _headers(client, world["slug_a"], world["resident_a"]))
    ileri = (dt.datetime.now(dt.timezone.utc) + dt.timedelta(hours=1)).isoformat()
    r = client.patch(
        f"/users/{sakin_id}/panik-aski", headers=guard,
        json={"bitis": ileri, "neden": "test"},
    )
    assert r.status_code == 403


# ============================ KONUM ======================================= #
def test_GPS_TEK_BASINA_ENLEM_REDDEDILIR(client, world):
    guard = _headers(client, world["slug_a"], world["guard_a"])
    r = client.post(
        "/panik", headers=guard, json={"tip": "guvenlik", "gps_lat": 41.0}
    )
    assert r.status_code == 422, "tek basina enlem bir KONUM DEGILDIR"


def test_KONUMSUZ_alarm_YINE_DE_GIDER(client, world):
    # Konumu zorunlu kilmak, konum alinamadigi icin alarmin HIC
    # gitmemesi demekti.
    guard = _headers(client, world["slug_a"], world["guard_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post("/panik", headers=guard, json={"tip": "guvenlik"})
    assert r.status_code == 201
    _yayinla(r.json()["id"], world["slug_a"], client, admin)
    assert client.get(f"/panik/{r.json()['id']}", headers=admin).json()["alicilar"]


# ===================== KAYNAK TARAMASI: GECIKME SABITI ==================== #
def test_ILK_YAYIN_SABITLE_PLANLANIR_ciplak_sayiyla_DEGIL():
    """(P240 §1) Iptal penceresinin SURESI otomatik olarak olculemiyor.

    Testler CANLI sunucuya gidiyor (monkeypatch yok) ve Celery worker
    kosmuyor; yani `send_task(..., countdown=N)` cagrisindaki N'i bir
    akis testiyle GOZLEMEK mumkun degil. Bunu "olculuyor" gibi
    gostermektense SINIRI yaziyoruz ve yerine KAYNAK duzeyinde bir
    kilit koyuyoruz:

    ilk yayin `IPTAL_PENCERESI_SN` ile planlanmali — ciplak bir sayi
    (orn. `0`) yazan bir degisiklik, iptal penceresini sessizce yok
    ederdi ve akis testleri bunu GOREMEZDI.
    """
    from pathlib import Path

    kaynak = Path(__file__).resolve().parents[1] / "app" / "routers" / "panik.py"
    metin = kaynak.read_text(encoding="utf-8")
    imza = "_yayin_planla(alarm.id, user.tenant_id, IPTAL_PENCERESI_SN)"
    assert imza in metin, "ilk yayin sabitle planlanmali"


def test_TEKRAR_DUYURU_GECIKMESIZ_olmali():
    """Tekrar basan kisi BEKLEMEMELI: var olan alarm HEMEN yeniden duyurulur."""
    from pathlib import Path

    kaynak = Path(__file__).resolve().parents[1] / "app" / "routers" / "panik.py"
    assert "_yayin_planla(acik.id, user.tenant_id, 0)" in kaynak.read_text(
        encoding="utf-8"
    )
