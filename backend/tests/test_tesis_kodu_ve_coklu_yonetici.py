"""(P154) Tesis kodu saglamlastirma + tesis basina COKLU YONETICI.

Iki kilitli kural olculuyor:
  * Kural 3 — kod = adin ilk 4 harfi + '-' + YYAAGG; cakismada RASTGELE sayi.
  * Asama 1 — "birden fazla yonetici olabilir" ve olusturulduktan SONRA
    ekleme/silme yapilabilmeli.
"""
from __future__ import annotations

import random
import re
import string
import uuid

from app.hata_metinleri import METINLER



def _umail() -> str:
    """(P197) Her yonetici satiri BENZERSIZ bir e-posta tasimali.

    `app_user.email` NOT NULL oldu (goc 0089) ve `uq_app_user_tenant_email`
    ayni tesiste iki ayni adrese izin vermez — coklu yonetici acan
    testlerde sabit bir adres catisirdi.
    """
    return f"p197-{uuid.uuid4().hex[:12]}@ornek.com"

def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _uphone() -> str:
    return "+90" + str(uuid.uuid4().int)[:10]


# ===================== 1) KOD URETICI — YEREL BAGIMSIZ ====================== #

def test_kod_ONEKI_daima_saf_ASCII_BUYUK_HARF(owner_conn):
    """Onek A-Z disinda HICBIR sey icermemeli.

    NEDEN BU BICIMDE OLCULUYOR: kusur `upper()`in veritabani ctype'ina bagli
    olmasindan gelirdi ve Turkce ctype'li bir kurulumda `upper('i')` = `İ`
    donup `[^A-Z]` suzgecine takilirdi ("istanbul" -> `STAN`). Testi
    "ISTA bekliyorum" diye yazmak kusuru YALNIZ bir girdide yakalardi;
    burada olculen sey KURALIN KENDISI: cikan onek her zaman dort tane
    A-Z harfidir ve girdideki ilk dort harfe karsilik gelir.
    """
    ornekler = {
        "İstanbul Konakları": "ISTA",
        "istanbul konakları": "ISTA",
        "ışık evleri": "ISIK",
        "ıırmak Sitesi": "IIRM",
        "ÇİĞDEM SİTESİ": "CIGD",
        "Öğretmenler Sitesi": "OGRE",
        "Şişli Güneş Apt.": "SISL",
        "Ünye Sitesi": "UNYE",
    }
    with owner_conn.cursor() as cur:
        for ad, beklenen in ornekler.items():
            cur.execute("SELECT public.kayit_kodu_uret(%s, '2026-07-15')", (ad,))
            kod = cur.fetchone()[0]
            onek = kod.split("-")[0]
            assert re.fullmatch(r"[A-Z]{4}", onek), f"{ad!r} -> {kod!r}"
            assert onek == beklenen, f"{ad!r} -> {kod!r}"


def test_kod_KENAR_DURUMLARI(owner_conn):
    """Dort harften kisa, harfsiz, rakamla baslayan, noktalamali adlar."""
    ornekler = {
        "As": "ASXX-260715",              # rpad
        "3. Etap Sitesi": "ETAP-260715",  # rakam atilir
        "123": "XXXX-260715",             # harf YOK -> tamamen dolgu
        "A B C D E": "ABCD-260715",       # bosluk atilir
        "Çamlıca-Ova Sitesi": "CAML-260715",
    }
    with owner_conn.cursor() as cur:
        for ad, beklenen in ornekler.items():
            cur.execute("SELECT public.kayit_kodu_uret(%s, '2026-07-15')", (ad,))
            assert cur.fetchone()[0] == beklenen, ad


def test_cakisma_eki_RASTGELE_iki_hane(owner_conn):
    """Kilitli kural 3: cakismada ikinci kayda RASTGELE sayi eklenir.

    P148.1 sirali sayac (`-2`, `-3`) koymustu; kural bunu degistirdi.
    Rastgeleligi TEK kosumda kanitlamak mumkun degil (bir zar atisi da `12`
    verebilir), bu yuzden olculen sey BICIMDIR: ek iki hanelidir.

    AD DORT RASTGELE HARFTEN URETILIYOR: ilk yazimda ad `uuid4().hex`ten
    turetiliyordu ve kod ureticisi RAKAMLARI ATTIGI icin geriye yalniz a-f
    kaliyordu — onceki kosumlarin birakti taban ile cakisip ikisi de ek
    aldi, test de "ilki taban olmali" varsayimiyla dustu. Testin kendi
    kusuruydu; kural degil.
    """
    harfler = "".join(random.choice(string.ascii_uppercase) for _ in range(4))
    ad = f"{harfler} Sitesi"
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT public.kayit_kodu_uret(%s, DATE '2026-07-15')", (ad,)
        )
        taban = cur.fetchone()[0]
        # Onceki kosumlardan kalinti VARSA temizle: bu testin olctugu sey
        # "ilk kayit ek ALMAZ, ikincisi ALIR" kuralidir ve kalinti onu
        # gorunmez kilardi.
        cur.execute("DELETE FROM tenant WHERE kayit_kodu LIKE %s", (taban + "%",))
        cur.execute(
            "INSERT INTO tenant (ad, slug, created_at) VALUES (%s, %s, '2026-07-15'), "
            "(%s, %s, '2026-07-15') RETURNING kayit_kodu",
            (ad, f"c-{uuid.uuid4().hex[:8]}", ad, f"c-{uuid.uuid4().hex[:8]}"),
        )
        kodlar = [r[0] for r in cur.fetchall()]
        cur.execute("DELETE FROM tenant WHERE kayit_kodu LIKE %s", (taban + "%",))
    assert len(set(kodlar)) == 2, "cakisma sessizce ayni kodu uretemez"
    assert taban in kodlar, f"ilk kayit ek ALMAMALI: {kodlar}"
    ekli = [k for k in kodlar if k != taban]
    assert len(ekli) == 1, kodlar
    ek = ekli[0][len(taban) + 1:]
    assert ekli[0].startswith(f"{taban}-")
    assert re.fullmatch(r"\d{2}", ek), (
        f"iki haneli rastgele sayi bekleniyordu, gelen: {ekli[0]!r}"
    )


def test_ad_DEGISINCE_kod_SABIT_kalir(owner_conn):
    """Tetikleyici yalniz BEFORE INSERT; yeniden adlandirma kodu bozmaz.

    Kod telefonda soylenen bir tanimlayicidir; adi duzeltmenin onu
    degistirmesi, dun verilen kodun bugun tutmamasi demek olurdu.
    """
    slug = f"c-{uuid.uuid4().hex[:8]}"
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO tenant (ad, slug, created_at) "
            "VALUES ('Oltu Sitesi', %s, '2026-07-15') RETURNING kayit_kodu",
            (slug,),
        )
        onceki = cur.fetchone()[0]
        cur.execute(
            "UPDATE tenant SET ad = 'Bambaska Bir Ad' WHERE slug = %s "
            "RETURNING kayit_kodu",
            (slug,),
        )
        sonraki = cur.fetchone()[0]
    assert sonraki == onceki


# ===================== 2) COKLU YONETICI — UC UZERINDEN ==================== #

def test_yonetici_EKLE_LISTELE_SIL_tam_tur(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])

    # tesis + BIRINCIL yonetici
    ilk = _uphone()
    r = client.post(
        "/tenants", headers=admin,
        json={"ad": "Coklu Yonetici Sitesi",
              "yoneticiler": [{"ad": "Birincil Yonetici", "phone": ilk, "email": _umail()}]},
    )
    assert r.status_code == 201, r.text
    tid = r.json()["tenant_id"]

    # tek yonetici goruluyor ve BIRINCIL
    r = client.get(f"/tenants/{tid}/yoneticiler", headers=admin)
    assert r.status_code == 200, r.text
    assert len(r.json()["items"]) == 1
    assert r.json()["items"][0]["birincil"] is True

    # SONRADAN ikinci yonetici
    ikinci = _uphone()
    r = client.post(
        f"/tenants/{tid}/yoneticiler", headers=admin,
        json={"ad": "Ikinci Yonetici", "phone": ikinci, "email": _umail()},
    )
    assert r.status_code == 201, r.text
    yeni_id = r.json()["user_id"]
    temp = r.json()["temp_code"]
    assert temp

    # liste iki kisi, BIRINCIL ONCE
    r = client.get(f"/tenants/{tid}/yoneticiler", headers=admin)
    items = r.json()["items"]
    assert len(items) == 2
    assert items[0]["birincil"] is True and items[1]["birincil"] is False

    # eklenen yonetici gecici kodla GERCEKTEN girebiliyor
    lp = client.post("/auth/login-phone", json={"phone": ikinci, "password": temp})
    assert lp.status_code == 200, lp.text
    assert lp.json()["password_setup_required"] is True

    # ve silinebiliyor
    assert client.delete(f"/tenants/{tid}/yoneticiler/{yeni_id}",
                         headers=admin).status_code == 204
    r = client.get(f"/tenants/{tid}/yoneticiler", headers=admin)
    assert len(r.json()["items"]) == 1


def test_SON_yonetici_silinemez(client, world):
    """Tesisi yonetilemez birakmak sessiz bir veri kaybidir."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/tenants", headers=admin,
        json={"yoneticiler": [{"ad": "Tek Yonetici", "phone": _uphone(), "email": _umail()}]},
    )
    tid = r.json()["tenant_id"]
    uid = client.get(f"/tenants/{tid}/yoneticiler",
                     headers=admin).json()["items"][0]["id"]

    r = client.delete(f"/tenants/{tid}/yoneticiler/{uid}", headers=admin)
    assert r.status_code == 409, r.text
    # Yalniz "conflict" olcmek yetmez: uc ayri 409 var ve kullaniciya NE
    # yapacagini soyleyen sey METINDIR. Katalogdan okunuyor ki metin
    # degisirse test degil KATALOG tek kaynak kalsin.
    assert r.json()["error"]["message"] == METINLER["son_yonetici_silinemez"]["tr"]


def test_BIRINCIL_yonetici_silinemez(client, world):
    """`uq_app_user_birincil` yeni birincili kendiliginden atamaz; birincili
    silmek tesis detayini bos birakir ve panel 'yonetici yok' der."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/tenants", headers=admin,
        json={"yoneticiler": [{"ad": "Birincil", "phone": _uphone(), "email": _umail()}]},
    )
    tid = r.json()["tenant_id"]
    # ikinci yonetici ekle ki "son yonetici" kapisina takilmayalim
    client.post(f"/tenants/{tid}/yoneticiler", headers=admin,
                json={"ad": "Ikinci", "phone": _uphone(), "email": _umail()})
    birincil_id = [y for y in client.get(f"/tenants/{tid}/yoneticiler",
                                        headers=admin).json()["items"]
                   if y["birincil"]][0]["id"]

    r = client.delete(f"/tenants/{tid}/yoneticiler/{birincil_id}", headers=admin)
    assert r.status_code == 409, r.text
    assert r.json()["error"]["message"] == METINLER["birincil_yonetici_silinemez"]["tr"]


def test_ayni_telefon_ikinci_kez_EKLENEMEZ(client, world):
    """Telefon global benzersiz; ikinci ekleme 409."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/tenants", headers=admin,
        json={"yoneticiler": [{"ad": "Birincil", "phone": _uphone(), "email": _umail()}]},
    )
    tid = r.json()["tenant_id"]
    tel = _uphone()
    assert client.post(f"/tenants/{tid}/yoneticiler", headers=admin,
                       json={"ad": "Ali Bir", "phone": tel, "email": _umail()}).status_code == 201
    r = client.post(f"/tenants/{tid}/yoneticiler", headers=admin,
                    json={"ad": "Bes Iki", "phone": tel, "email": _umail()})
    assert r.status_code == 409, r.text


def test_bilinmeyen_tesise_yonetici_EKLENEMEZ(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post(
        f"/tenants/{uuid.uuid4()}/yoneticiler", headers=admin,
        json={"ad": "Hayalet", "phone": _uphone(), "email": _umail()},
    )
    assert r.status_code == 404, r.text


def test_yonetici_uclari_YALNIZ_admin(client, world):
    """Tesis yoneticisi baska bir tesisin yoneticisini goremez/ekleyemez."""
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    tid = uuid.uuid4()
    assert client.get(f"/tenants/{tid}/yoneticiler", headers=yon).status_code == 403
    assert client.post(f"/tenants/{tid}/yoneticiler", headers=yon,
                       json={"ad": "Iks Kisi", "phone": _uphone(), "email": _umail()}).status_code == 403
    assert client.delete(f"/tenants/{tid}/yoneticiler/{uuid.uuid4()}",
                         headers=yon).status_code == 403
