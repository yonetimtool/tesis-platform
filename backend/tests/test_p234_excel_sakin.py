"""(P234 §2) EXCEL ILE SAKIN AKTARIMI — olculen eksikler.

P193'te cati ZATEN vardi: onizleme, satir numarali hata raporu, "sorunlu
satir varsa DURDUR" varsayilani, ozet ve geri alma. Bu dosya o cerceveye
EKLENEN dort seyi olcuyor:

  1. TELEFON ZORUNLULUGU KALKTI — olculen CELISKI: tekil ekleme ucu
     P212-ek §2'de telefonu opsiyonel yapmisti, Excel yolu haberi
     olmadigi icin ayni veriyi iki farkli kuralla aliyordu.
  2. BLOK sutunu (P220) — ayni numarali daire iki blokta olabilir.
  3. `malik_oturan` (P218) — ucuncu bir rol DEGIL, malik + oturuyor.
  4. MUKERRER kontrolu telefon YOKKEN de calisiyor.
"""
from __future__ import annotations

import uuid


def _giris(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"],
              "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _satir(no, **degerler):
    return {"satir_no": no, "degerler": degerler}


def _aktar(client, h, tur, satirlar, dogrula=False, atla=False):
    govde = {"satirlar": satirlar, "yalniz_dogrula": dogrula,
             "dosya_adi": "sakinler.xlsx"}
    if atla:
        govde["sorunlulari_atla"] = True
    r = client.post(f"/ice-aktarim/{tur}", headers=h, json=govde)
    assert r.status_code == 201, r.text
    return r.json()


def _eposta() -> str:
    return f"p234-{uuid.uuid4().hex[:10]}@ornek.com"


# =================== 1) TELEFON OPSIYONEL — ASIL DUZELTME ================== #

def test_TELEFONSUZ_SATIR_ARTIK_GECERLI(client, world):
    """OLCULEN CELISKI: tekil ekleme telefonu opsiyonel yapmisti
    (P212-ek §2), Excel yolu hala zorunlu tutuyordu. Telefonsuz bir sakin
    listesi yukleyen yonetici HER SATIRDA hata aliyordu."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    r = _aktar(client, h, "kisi", [_satir(1, ad="Telefonsuz", eposta=_eposta())])
    assert r["olusan"] == 1, r
    assert r["hatali"] == 0, r


def test_TELEFON_ZORUNLU_ALAN_OLARAK_BILDIRILMIYOR(client, world):
    """Sozlesme de degismeli: arayuz "zorunlu" yazmayi surdurseydi
    kullanici yine doldurmak zorunda sanirdi."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    r = client.get("/ice-aktarim/turler", headers=h)
    kisi = next(t for t in r.json() if t["kod"] == "kisi")
    zorunlular = {a["kod"] for a in kisi["alanlar"] if a["zorunlu"]}
    assert "telefon" not in zorunlular
    # E-POSTA ZORUNLU KALIYOR (P197): kimlik odur.
    assert "eposta" in zorunlular
    assert "ad" in zorunlular


def test_BOZUK_TELEFON_HALA_HATA(client, world):
    """Opsiyonel olmak "bicimsiz kabul" demek degil: sessizce bozuk numara
    yazmak, sonradan hicbir kanaldan ulasilamayan kayit birakirdi."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    r = _aktar(client, h, "kisi",
               [_satir(1, ad="Bozuk", telefon="abc", eposta=_eposta())],
               dogrula=True)
    assert r["hatali"] == 1, r
    assert r["hatalar"][0]["alan"] == "telefon"


# ======================= 2) BLOK SUTUNU (P220) ============================= #

def test_BLOK_SUTUNU_BILDIRILIYOR(client, world):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    r = client.get("/ice-aktarim/turler", headers=h)
    kisi = next(t for t in r.json() if t["kod"] == "kisi")
    kodlar = [a["kod"] for a in kisi["alanlar"]]
    assert "blok" in kodlar


def test_BLOK_TUTARLILIK_DENETIMI(client, world, owner_conn):
    """Blok sutununun isi AYIRT ETMEK DEGIL, DOGRULAMAK.

    ILK YAZIMDA GEREKCEYI YANLIS KURDUM: "iki blokta ayni numarali daire
    olabilir" diye test yazdim ve `uq_unit_tenant_no` dustu — daire
    numarasi tesis icinde ZATEN benzersiz. Sema varsayimimi curuttu.

    Sutunun gercek isi: dosyada `blok=B, daire=A-3` gibi bir tutarsizlik
    varsa dosyanin kendisi yanlistir ve bu SOYLENMELIDIR. Sessizce
    numaraya bakip "buldum" demek, yanlis yazilmis bir dosyayi dogru
    sanip uygulamak olurdu.
    """
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    no = f"D{uuid.uuid4().hex[:4]}"
    with owner_conn.cursor() as c:
        c.execute(
            "INSERT INTO unit (id, tenant_id, no, blok) "
            "VALUES (gen_random_uuid(), %s, %s, 'A')",
            (world["a"], no),
        )
        c.execute(
            "SELECT id FROM unit WHERE tenant_id=%s AND no=%s", (world["a"], no)
        )
        a_id = c.fetchone()[0]

    # 1) DOGRU blok -> baglanir.
    eposta = _eposta()
    r = _aktar(client, h, "kisi",
               [_satir(1, ad="Blok A Sakini", eposta=eposta, blok="A",
                       daire_no=no, rol_tipi="malik")])
    assert r["olusan"] == 1, r
    with owner_conn.cursor() as c:
        c.execute(
            "SELECT ur.unit_id FROM unit_resident ur "
            "JOIN app_user u ON u.id = ur.user_id WHERE u.email = %s",
            (eposta,),
        )
        assert c.fetchone()[0] == a_id

    # 2) YANLIS blok -> SESSIZCE GECMEZ, satir hatasi.
    y = _aktar(client, h, "kisi",
               [_satir(1, ad="Yanlis Blok", eposta=_eposta(), blok="Z",
                       daire_no=no, rol_tipi="kiraci")],
               dogrula=True)
    assert y["hatali"] == 1, y
    assert y["hatalar"][0]["alan"] == "daire_no"


# ================== 3) malik_oturan (P218) — IKI ALANA AYRILIR ============= #

def test_MALIK_OTURAN_rol_ve_oturuyor_ALANLARINA_AYRILIR(
    client, world, owner_conn
):
    """P218: ucuncu bir ROL DEGIL, malikin oturuyor olmasi. Enum'a ucuncu
    deger eklemek "malikler" sorgusunu iki degeri birden aramaya zorlardi."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    no = f"D{uuid.uuid4().hex[:4]}"
    with owner_conn.cursor() as c:
        c.execute(
            "INSERT INTO unit (id, tenant_id, no, blok) "
            "VALUES (gen_random_uuid(), %s, %s, 'A')",
            (world["a"], no),
        )
    eposta = _eposta()
    r = _aktar(client, h, "kisi",
               [_satir(1, ad="Malik Oturan", eposta=eposta, daire_no=no,
                       rol_tipi="malik_oturan")])
    assert r["olusan"] == 1, r
    with owner_conn.cursor() as c:
        c.execute(
            "SELECT ur.rol_tipi, ur.oturuyor FROM unit_resident ur "
            "JOIN app_user u ON u.id = ur.user_id WHERE u.email = %s",
            (eposta,),
        )
        assert c.fetchone() == ("malik", True)


def test_MALIK_TIRE_OTURAN_da_KABUL_EDILIR(client, world, owner_conn):
    """Kullanici Excel'e "malik-oturan" yazar. Tire yuzunden hata vermek,
    sutunun kendisini kullanilmaz kilardi."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    r = _aktar(client, h, "kisi",
               [_satir(1, ad="X", eposta=_eposta(), rol_tipi="malik-oturan")],
               dogrula=True)
    assert r["hatali"] == 0, r


def test_DUZ_MALIK_oturuyor_YAZMAZ(client, world, owner_conn):
    """Ayrim korunmali: her malik oturuyor DEGILDIR."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    no = f"D{uuid.uuid4().hex[:4]}"
    with owner_conn.cursor() as c:
        c.execute(
            "INSERT INTO unit (id, tenant_id, no, blok) "
            "VALUES (gen_random_uuid(), %s, %s, 'A')",
            (world["a"], no),
        )
    eposta = _eposta()
    _aktar(client, h, "kisi",
           [_satir(1, ad="Sadece Malik", eposta=eposta, daire_no=no,
                   rol_tipi="malik")])
    with owner_conn.cursor() as c:
        c.execute(
            "SELECT ur.oturuyor FROM unit_resident ur "
            "JOIN app_user u ON u.id = ur.user_id WHERE u.email = %s",
            (eposta,),
        )
        assert c.fetchone()[0] is False


def test_GECERSIZ_ROL_HALA_HATA(client, world):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    r = _aktar(client, h, "kisi",
               [_satir(1, ad="X", eposta=_eposta(), rol_tipi="komsu")],
               dogrula=True)
    assert r["hatali"] == 1
    assert r["hatalar"][0]["alan"] == "rol_tipi"


# ============ 4) MUKERRER — TELEFON YOKKEN DE CALISMALI ==================== #

def test_AYNI_EPOSTA_IKINCI_KEZ_ATLANIR_telefon_olmasa_da(client, world):
    """Once mukerrer kontrolu YALNIZ telefona bakiyordu. Telefon opsiyonel
    olunca telefonsuz satirlarda kontrol HIC CALISMAZDI: ayni dosya iki
    kez yuklenince ayni kisi iki kez acilir ve "idempotent" sozu sessizce
    bozulurdu."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    eposta = _eposta()
    satir = [_satir(1, ad="Tekrarli", eposta=eposta)]

    ilk = _aktar(client, h, "kisi", satir)
    assert ilk["olusan"] == 1, ilk

    ikinci = _aktar(client, h, "kisi", satir)
    assert ikinci["olusan"] == 0, ikinci
    assert ikinci["atlanan"] == 1, ikinci
