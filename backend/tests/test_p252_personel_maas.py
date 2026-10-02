"""(P252 §1–§2) Personel eklerken maas, otomatik maas gideri.

Olculen:
  * saf kurallar: odeme gunu ayda yoksa AYIN SON GUNU; ilk donem gecmise
    yazmaz; kismi ay gun orani;
  * `POST /users` + `calisma`: hesap ve maas karti TEK islemde, bagli;
    gecersiz kasada IKISI de yazilmaz; amir ucret yazamaz (403) ve hesap
    da acilmaz;
  * amir maas kartlarini ve maas ayarini goremez (sunucuda 403); `/users`
    listesinde ucret alani yok;
  * personel kendi ucretini gorur (`/me/calisma`), TC/IBAN/kasa YOK;
  * otomasyon: odeme gunu bugun -> gider olusur, secilen kasadan, kalem
    "Personel maasi", aciklama "Ad — Ay Yil maasi", yonetime bildirim;
    IKINCI tetik yazmaz;
  * kismi ay ONAY BEKLEYEN; cikistan sonra gider yok; otomatik onay
    kapaliyken onay bekleyen.
"""
from __future__ import annotations

import calendar
import uuid
from datetime import date, timedelta

from app import maas


def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


# ------------------------------------------------------------- saf kurallar
def test_odeme_gunu_ayda_yoksa_AYIN_SON_GUNU():
    assert maas.odeme_tarihi("2026-02", 31) == date(2026, 2, 28)
    assert maas.odeme_tarihi("2028-02", 30) == date(2028, 2, 29)
    assert maas.odeme_tarihi("2026-04", 31) == date(2026, 4, 30)
    assert maas.odeme_tarihi("2026-10", 5) == date(2026, 10, 5)


def test_ilk_donem_GECMISE_yazmaz():
    # Bugun 20'si, odeme gunu 5: bu ayin odemesi gecti -> ilk donem gelecek ay.
    assert maas.ilk_donem(date(2026, 10, 20), 5) == "2026-11"
    # Odeme gunu bugun -> BU AY.
    assert maas.ilk_donem(date(2026, 10, 5), 5) == "2026-10"
    assert maas.ilk_donem(date(2026, 12, 31), 15) == "2027-01"


def test_kismi_ay_gun_orani():
    tam = maas.donem_tutari(3_000_000, "2026-10", None, None)
    assert tam.tutar_kurus == 3_000_000 and not tam.kismi
    # 22 Ekim'de giris: 22..31 = 10 gun / 31.
    giris = maas.donem_tutari(3_100_000, "2026-10", date(2026, 10, 22), None)
    assert giris.kismi and giris.calisilan_gun == 10 and giris.tutar_kurus == 1_000_000
    # 10 Ekim'de cikis: 1..10 = 10 gun.
    cikis = maas.donem_tutari(3_100_000, "2026-10", None, date(2026, 10, 10))
    assert cikis.kismi and cikis.tutar_kurus == 1_000_000
    # Cikistan sonraki ay: calisma yok.
    assert maas.donem_tutari(3_100_000, "2026-11", None, date(2026, 10, 10)) is None
    assert maas.maas_aciklamasi("Ahmet YILMAZ", "2026-10") == "Ahmet YILMAZ — Ekim 2026 maaşı"


# ------------------------------------------------------------------ API
def _kasa(client, y, ad="Merkez Kasa"):
    r = client.post("/kasalar", headers=y, json={"kod": f"K{uuid.uuid4().hex[:5]}", "ad": ad})
    assert r.status_code == 201, r.text
    return r.json()["id"]


def _personel(client, y, *, kasa_id, maas_kurus=2_500_000, gun=None, giris=None, rol="security"):
    eposta = f"p252-{uuid.uuid4().hex[:8]}@ornek.com"
    calisma = {"maas_kurus": maas_kurus, "odeme_gunu": gun or date.today().day,
               "kasa_id": kasa_id, "gorev": "Güvenlik"}
    if giris:
        calisma["giris_tarihi"] = giris.isoformat()
    r = client.post("/users", headers=y, json={
        "ad": "Test", "soyad": f"Personel{uuid.uuid4().hex[:4]}", "email": eposta,
        "role": rol, "calisma": calisma,
    })
    assert r.status_code == 201, r.text
    return r.json(), eposta


def _kart(client, y, user_id):
    items = client.get("/personel-kayitlari", headers=y, params={"app_user_id": user_id}).json()["items"]
    assert len(items) == 1
    return items[0]


def _maas_giderleri(owner_conn, kart_id):
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT h.tutar_kurus, h.durum, h.kasa_id, h.aciklama, t.sistem_kodu, h.donem "
            "FROM finansal_hareket h LEFT JOIN gelir_gider_tanim t ON t.id = h.gelir_gider_tanim_id "
            "WHERE h.personel_kayit_id = %s ORDER BY h.tarih", (kart_id,),
        )
        return cur.fetchall()


def test_hesap_ve_maas_karti_TEK_islemde(client, world):
    y = _h(client, world["slug_a"], world["yonetici_a"])
    kasa = _kasa(client, y)
    u, _ = _personel(client, y, kasa_id=kasa)
    assert u["personel_kayit_id"]
    kart = _kart(client, y, u["id"])
    assert kart["id"] == u["personel_kayit_id"]
    assert kart["maas_kurus"] == 2_500_000 and kart["kasa_id"] == kasa
    assert kart["odeme_gunu"] == date.today().day
    assert kart["maas_ilk_donem"] == maas.donem(date.today())


def test_gecersiz_kasa_HICBIR_SEY_yazmaz(client, world):
    y = _h(client, world["slug_a"], world["yonetici_a"])
    eposta = f"p252-{uuid.uuid4().hex[:8]}@ornek.com"
    r = client.post("/users", headers=y, json={
        "ad": "Yarim", "soyad": "Kayit", "email": eposta, "role": "security",
        "calisma": {"maas_kurus": 100, "odeme_gunu": 5, "kasa_id": str(uuid.uuid4())},
    })
    assert r.status_code == 422, r.text
    bulunan = client.get("/users", headers=y, params={"q": eposta}).json()["items"]
    assert bulunan == [], "hesap acilmis ama kart yok — yarim kayit"


def test_amir_UCRET_YAZAMAZ_ve_GOREMEZ(client, world):
    y = _h(client, world["slug_a"], world["yonetici_a"])
    a = _h(client, world["slug_a"], world["amir_a"])
    eposta = f"p252-{uuid.uuid4().hex[:8]}@ornek.com"
    r = client.post("/users", headers=a, json={
        "ad": "Amir", "soyad": "Deneme", "email": eposta, "role": "security",
        "calisma": {"maas_kurus": 100, "odeme_gunu": 5},
    })
    assert r.status_code == 403, r.text
    assert r.json()["error"]["message"]
    assert client.get("/users", headers=y, params={"q": eposta}).json()["items"] == []
    # Ucret iceren uclar amire KAPALI; liste yanitinda ucret alani YOK.
    assert client.get("/personel-kayitlari", headers=a).status_code == 403
    assert client.get("/otomasyon/maas-ayari", headers=a).status_code == 403
    liste = client.get("/users", headers=a, params={"limit": 50}).json()["items"]
    assert liste and all("maas_kurus" not in u and "calisma" not in u for u in liste)


def test_personel_KENDI_ucretini_gorur_TC_IBAN_kasa_yok(client, world):
    y = _h(client, world["slug_a"], world["yonetici_a"])
    g = _h(client, world["slug_a"], world["guard_a"])
    guard_id = client.get("/users", headers=y, params={"q": world["guard_a"]["email"]}).json()["items"][0]["id"]
    for k in client.get("/personel-kayitlari", headers=y, params={"app_user_id": guard_id}).json()["items"]:
        client.delete(f"/personel-kayitlari/{k['id']}", headers=y)
    r = client.post("/personel-kayitlari", headers=y, json={
        "ad": "Guard A", "app_user_id": guard_id, "maas_kurus": 2_000_000, "odeme_gunu": 10,
        "tc": "12345678901", "iban": "TR330006100519786457841326",
    })
    assert r.status_code == 201, r.text
    me = client.get("/me/calisma", headers=g).json()["calisma"]
    assert me["maas_kurus"] == 2_000_000 and me["odeme_gunu"] == 10
    assert not {"tc", "iban", "kasa_id"} & set(me)
    client.delete(f"/personel-kayitlari/{r.json()['id']}", headers=y)
    assert client.get("/me/calisma", headers=g).json()["calisma"] is None


def test_otomasyon_GIDER_yazar_KASADAN_duser_IKINCI_tetik_yazmaz(client, world, owner_conn):
    y = _h(client, world["slug_a"], world["yonetici_a"])
    kasa = _kasa(client, y)
    u, _ = _personel(client, y, kasa_id=kasa, maas_kurus=2_500_000)
    kart = _kart(client, y, u["id"])
    r = client.post("/otomasyon/maaslar/calistir", headers=y)
    assert r.status_code == 200, r.text
    assert r.json()["yazilan"] >= 1
    satirlar = _maas_giderleri(owner_conn, kart["id"])
    assert len(satirlar) == 1
    tutar, durum, kasa_id, aciklama, kod, donem = satirlar[0]
    assert tutar == 2_500_000 and durum == "odendi" and str(kasa_id) == kasa
    assert kod == maas.KOD_MAAS and donem == maas.donem(date.today())
    assert aciklama == maas.maas_aciklamasi(kart["ad"], donem)
    # Yonetime bildirim (uygulama ici satir).
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM notification WHERE tenant_id=%s AND tip='maas_yazildi'",
            (world["a"],),
        )
        assert cur.fetchone()[0] >= 1
    # IKINCI tetik: yeni satir yok.
    r2 = client.post("/otomasyon/maaslar/calistir", headers=y)
    assert r2.status_code == 200 and r2.json()["yazilan"] == 0
    assert len(_maas_giderleri(owner_conn, kart["id"])) == 1


def test_kismi_ay_ONAY_BEKLEYEN_ve_oranli(client, world, owner_conn):
    bugun = date.today()
    if bugun.day == 1:
        return  # bu ay kismi giris olusturulamaz (1'inde giris = tam ay)
    y = _h(client, world["slug_a"], world["yonetici_a"])
    kasa = _kasa(client, y)
    u, _ = _personel(client, y, kasa_id=kasa, maas_kurus=3_000_000, giris=bugun)
    kart = _kart(client, y, u["id"])
    client.post("/otomasyon/maaslar/calistir", headers=y)
    (tutar, durum, *_), = _maas_giderleri(owner_conn, kart["id"])
    ay_gun = calendar.monthrange(bugun.year, bugun.month)[1]
    beklenen = round(3_000_000 * (ay_gun - bugun.day + 1) / ay_gun)
    assert tutar == beklenen and durum == "onay_bekliyor"


def test_cikistan_sonra_gider_YOK_ve_otomatik_onay_kapali(client, world, owner_conn):
    y = _h(client, world["slug_a"], world["yonetici_a"])
    kasa = _kasa(client, y)
    # Cikis gecen ay: bu ay gider olusmaz.
    u, _ = _personel(client, y, kasa_id=kasa)
    kart = _kart(client, y, u["id"])
    gecen_ay_sonu = date.today().replace(day=1) - timedelta(days=1)
    r = client.patch(f"/personel-kayitlari/{kart['id']}", headers=y,
                     json={"cikis_tarihi": gecen_ay_sonu.isoformat(),
                           "giris_tarihi": (gecen_ay_sonu - timedelta(days=100)).isoformat()})
    assert r.status_code == 200, r.text
    # Otomatik onay KAPALI -> yeni personelin gideri onay bekler.
    assert client.patch("/otomasyon/maas-ayari", headers=y, json={"otomatik_onay": False}).status_code == 200
    u2, _ = _personel(client, y, kasa_id=kasa)
    kart2 = _kart(client, y, u2["id"])
    client.post("/otomasyon/maaslar/calistir", headers=y)
    assert _maas_giderleri(owner_conn, kart["id"]) == []
    (_, durum, *_), = _maas_giderleri(owner_conn, kart2["id"])
    assert durum == "onay_bekliyor"
    ayar = client.get("/otomasyon/maas-ayari", headers=y).json()
    assert ayar["otomatik_onay"] is False and ayar["personel_sayisi"] >= 2
    client.patch("/otomasyon/maas-ayari", headers=y, json={"otomatik_onay": True})


def test_onay_bekleyen_maaslar_LISTEDE_ve_TOPLU_onay_KASAYA_girer(client, world, owner_conn):
    """(P252 §2) Ayar kapaliyken yazilan maaslar ayar ucunda listelenir ve
    tek tikla onaylanir; ikinci onay (iki sekme) hata vermez, bir sey de
    yapmaz. Amir toplu onaylayamaz."""
    y = _h(client, world["slug_a"], world["yonetici_a"])
    kasa = _kasa(client, y)
    client.patch("/otomasyon/maas-ayari", headers=y, json={"otomatik_onay": False})
    try:
        u, _ = _personel(client, y, kasa_id=kasa, maas_kurus=1_800_000)
        kart = _kart(client, y, u["id"])
        client.post("/otomasyon/maaslar/calistir", headers=y)
    finally:
        client.patch("/otomasyon/maas-ayari", headers=y, json={"otomatik_onay": True})
    ayar = client.get("/otomasyon/maas-ayari", headers=y).json()
    bizim = [b for b in ayar["onay_bekleyenler"] if b["aciklama"].startswith(kart["ad"])]
    assert len(bizim) == 1 and bizim[0]["tutar_kurus"] == 1_800_000
    a = _h(client, world["slug_a"], world["amir_a"])
    assert client.post("/otomasyon/maaslar/onayla", headers=a,
                       json={"ids": [bizim[0]["id"]]}).status_code == 403
    r = client.post("/otomasyon/maaslar/onayla", headers=y, json={"ids": [bizim[0]["id"]]})
    assert r.status_code == 200, r.text
    assert r.json() == {"onaylanan": 1, "toplam_kurus": 1_800_000}
    (_, durum, *_), = _maas_giderleri(owner_conn, kart["id"])
    assert durum == "odendi"
    r2 = client.post("/otomasyon/maaslar/onayla", headers=y, json={"ids": [bizim[0]["id"]]})
    assert r2.json()["onaylanan"] == 0


def test_kismi_ay_TUTARI_DUZELTILEREK_onaylanir(client, world, owner_conn):
    """(P252 §2) Hesaplanmis (kismi) tutar onayda duzeltilir; denetimde eski
    tutar kalir. Onaylanmis satirin tutari degistirilemez (409)."""
    bugun = date.today()
    if bugun.day == 1:
        return
    y = _h(client, world["slug_a"], world["yonetici_a"])
    kasa = _kasa(client, y)
    u, _ = _personel(client, y, kasa_id=kasa, maas_kurus=3_000_000, giris=bugun)
    kart = _kart(client, y, u["id"])
    client.post("/otomasyon/maaslar/calistir", headers=y)
    bekleyen = [b for b in client.get("/otomasyon/maas-ayari", headers=y).json()["onay_bekleyenler"]
                if b["aciklama"].startswith(kart["ad"])]
    hid = bekleyen[0]["id"]
    r = client.post(f"/finans/hareketler/{hid}/onayla", headers=y, json={"tutar_kurus": 1_234_500})
    assert r.status_code == 200, r.text
    (tutar, durum, *_), = _maas_giderleri(owner_conn, kart["id"])
    assert tutar == 1_234_500 and durum == "odendi"
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT meta FROM audit_log WHERE resource_id=%s AND action='finans_hareket_onay'",
            (hid,),
        )
        meta = cur.fetchone()[0]
    assert meta["eski_tutar_kurus"] != 1_234_500 and meta["tutar_kurus"] == 1_234_500
    r2 = client.post(f"/finans/hareketler/{hid}/onayla", headers=y, json={"tutar_kurus": 1})
    assert r2.status_code == 409


def test_maas_GUNLUGU_otomasyon_gunlugunde_OKUNUR(client, world):
    """(P252 §2) Maas kosumu gunluge `tur='maas'` yazar ve gunluk listesi
    bu satirla 500 VERMEZ (yanit semasindaki tur listesi eksikti)."""
    y = _h(client, world["slug_a"], world["yonetici_a"])
    kasa = _kasa(client, y)
    _personel(client, y, kasa_id=kasa)
    client.post("/otomasyon/maaslar/calistir", headers=y)
    r = client.get("/otomasyon-gunlugu", headers=y, params={"tur": "maas", "limit": 5})
    assert r.status_code == 200, r.text
    assert r.json()["items"] and r.json()["items"][0]["tur"] == "maas"
    son = client.get("/otomasyon/son-calismalar", headers=y).json()["items"]
    assert any(s["kural"] == "maas" for s in son)
