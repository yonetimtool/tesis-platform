"""(P218) MALIK / KIRACI AYRIMI — UCTAN UCA.

===========================================================================
NE COZULDU
===========================================================================
Kat Mulkiyeti Kanunu md. 20 gider sorumlulugunu IKI AYRI gercege
baglar: isletme gideri KULLANANIN, bakim/onarim gideri MALIKIN.

Model bugune kadar yalnizca `rol_tipi` tasiyordu ve UC DURUMDAN BIRINI
temsil edemiyordu:
  1. Malik oturmuyor (kiraya vermis)  -> edilebiliyordu
  2. Kiraci oturuyor                  -> edilebiliyordu
  3. MALIK OTURUYOR                   -> EDILEMIYORDU (olculdu: ayni
     kisi ayni daireye ikinci rolle baglanamiyor, 409)

`unit_resident.oturuyor` (goc 0109) MULKIYET ile KULLANIMI ayirdi.

Bu dosya UC DURUMU DA gercek uclarla surer; cekirdek (saf fonksiyon)
ayrica `test_borclandirma_cekirdek.py`de olculuyor.
"""
from __future__ import annotations

import uuid

import pytest


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _daire(client, h) -> str:
    r = client.post("/units", headers=h, json={
        "no": f"P218-{uuid.uuid4().hex[:6]}", "blok": "P", "aktif": True})
    assert r.status_code in (200, 201), r.text
    return r.json()["id"]


def _kisi(client, h, ad: str) -> str:
    r = client.post("/users", headers=h, json={
        "ad": ad, "email": f"p218-{uuid.uuid4().hex[:10]}@ornek.com",
        "role": "resident", "password": "Parola123!"})
    assert r.status_code == 201, r.text
    return r.json()["id"]


def _tanim(client, h, kural: str) -> str:
    r = client.post("/gelir-gider-tanimlari", headers=h, json={
        "ad": f"P218 {kural} {uuid.uuid4().hex[:5]}", "tip": "gider",
        "hedef_kurali": kural})
    assert r.status_code in (200, 201), r.text
    return r.json()["id"]


def _hedef(client, h, unit_id: str, tanim_id: str, donem: str) -> str | None:
    r = client.post("/dues/assessments", headers=h, json={
        "unit_id": unit_id, "donem": donem, "tutar_kurus": 1234,
        "gelir_gider_tanim_id": tanim_id})
    assert r.status_code in (200, 201), r.text
    return r.json()["created"][0]["hedef_user_id"]


@pytest.fixture
def yon(client, world):
    return _h(client, world["slug_a"], world["yonetici_a"])


def _donem() -> str:
    return f"20{uuid.uuid4().int % 80 + 19}-{uuid.uuid4().int % 12 + 1:02d}"


# ==================== UC DURUM ========================================== #

def test_DURUM1_malik_oturmuyor_kiraci_oturuyor(client, yon):
    """Isletme gideri KIRACIYA, bakim gideri MALIGE."""
    u = _daire(client, yon)
    m, k = _kisi(client, yon, "Malik"), _kisi(client, yon, "Kiraci")
    client.post(f"/units/{u}/residents", headers=yon,
                json={"user_id": m, "rol_tipi": "malik", "oturuyor": False})
    client.post(f"/units/{u}/residents", headers=yon,
                json={"user_id": k, "rol_tipi": "kiraci"})

    assert _hedef(client, yon, u, _tanim(client, yon, "kiraci_oncelikli"), _donem()) == k
    assert _hedef(client, yon, u, _tanim(client, yon, "malik"), _donem()) == m


def test_DURUM3_MALIK_OTURUYOR_her_iki_giderden_sorumlu(client, yon):
    """ESKIDEN TEMSIL EDILEMEYEN DURUM.

    Ayni kisi hem malik hem kiraci olarak baglanamiyordu (409); yonetici
    ya `malik` yazip oturdugu bilgisini kaybediyor ya `kiraci` yazip
    mulkiyeti yanlis gosteriyordu.
    """
    u = _daire(client, yon)
    mo = _kisi(client, yon, "Malik Oturan")
    r = client.post(f"/units/{u}/residents", headers=yon,
                    json={"user_id": mo, "rol_tipi": "malik", "oturuyor": True})
    assert r.status_code in (200, 201), r.text
    assert r.json()["oturuyor"] is True

    # Kullanan kurali ONA yazar (oturuyor), malik kurali da ONA (malik).
    assert _hedef(client, yon, u, _tanim(client, yon, "kiraci_oncelikli"), _donem()) == mo
    assert _hedef(client, yon, u, _tanim(client, yon, "malik"), _donem()) == mo


def test_OTURMAYAN_MALIK_isletme_giderini_ALIR_ama_bu_SON_CAREDIR(client, yon):
    """Dairede oturan kimse yoksa isletme gideri yine malige yazilir —
    bos daire de gider uretir ve borcun sahipsiz kalmasi daha kotudur."""
    u = _daire(client, yon)
    m = _kisi(client, yon, "Yalniz Malik")
    client.post(f"/units/{u}/residents", headers=yon,
                json={"user_id": m, "rol_tipi": "malik", "oturuyor": False})
    assert _hedef(client, yon, u, _tanim(client, yon, "kiraci_oncelikli"), _donem()) == m


# ==================== `oturuyor` VARSAYILANI ============================ #

def test_KIRACIYA_oturuyor_SORULMAZ_sunucu_True_varsayar(client, yon):
    """Kiraci tanimi geregi oturur; ayrica sormak yoneticiye bilgi
    degeri olmayan bir soru sormakti."""
    u = _daire(client, yon)
    k = _kisi(client, yon, "Kiraci")
    r = client.post(f"/units/{u}/residents", headers=yon,
                    json={"user_id": k, "rol_tipi": "kiraci"})
    assert r.json()["oturuyor"] is True


def test_MALIGE_oturuyor_SORULMAZSA_False(client, yon):
    """"Bilinmiyor"u "oturuyor" saymak, isletme giderini oturmayan
    malige yazardi."""
    u = _daire(client, yon)
    m = _kisi(client, yon, "Malik")
    r = client.post(f"/units/{u}/residents", headers=yon,
                    json={"user_id": m, "rol_tipi": "malik"})
    assert r.json()["oturuyor"] is False


def test_ROLSUZ_bag_oturuyor_FALSE(client, yon):
    """Kullanici ekleme ekraninin (bugunku hâliyle) actigi bag."""
    u = _daire(client, yon)
    x = _kisi(client, yon, "Rolsuz")
    r = client.post(f"/units/{u}/residents", headers=yon, json={"user_id": x})
    assert r.json()["oturuyor"] is False


# ==================== SINIRLAR ========================================== #

def test_MALIK_OTURUYORKEN_KIRACI_da_eklenebilir(client, yon):
    """URUN KARARI: engellenmiyor. Malik bir odayi kiraya vermis
    olabilir; devir doneminde ikisi bir arada gorunebilir."""
    u = _daire(client, yon)
    mo, k = _kisi(client, yon, "Malik Oturan"), _kisi(client, yon, "Kiraci")
    client.post(f"/units/{u}/residents", headers=yon,
                json={"user_id": mo, "rol_tipi": "malik", "oturuyor": True})
    r = client.post(f"/units/{u}/residents", headers=yon,
                    json={"user_id": k, "rol_tipi": "kiraci"})
    assert r.status_code in (200, 201), r.text


def test_LISTE_oturuyor_alanini_DONER(client, yon):
    u = _daire(client, yon)
    mo = _kisi(client, yon, "Malik Oturan")
    client.post(f"/units/{u}/residents", headers=yon,
                json={"user_id": mo, "rol_tipi": "malik", "oturuyor": True})
    r = client.get(f"/units/{u}/residents", headers=yon)
    assert r.status_code == 200, r.text
    kayit = [x for x in r.json() if x["user_id"] == mo][0]
    assert kayit["oturuyor"] is True
    assert kayit["rol_tipi"] == "malik"


# ==================== (§C) TESIS VARSAYILANI ============================ #

def _ayar(client, h, kural: str) -> None:
    r = client.patch("/tenant/settings", headers=h,
                     json={"varsayilan_hedef_kurali": kural})
    assert r.status_code == 200, r.text


def test_YENI_TANIM_tesis_varsayilanini_ALIR(client, yon):
    """Bazi siteler HER SEYI malige yaziyor; her tanimda ayni secimi
    tekrarlatmak gereksiz."""
    onceki = client.get("/tenant/settings", headers=yon).json()[
        "varsayilan_hedef_kurali"]
    try:
        _ayar(client, yon, "malik")
        r = client.post("/gelir-gider-tanimlari", headers=yon, json={
            "ad": f"P218 vars {uuid.uuid4().hex[:5]}", "tip": "gider"})
        assert r.status_code in (200, 201), r.text
        assert r.json()["hedef_kurali"] == "malik"
    finally:
        _ayar(client, yon, onceki)


def test_VARSAYILAN_ZORLAYICI_DEGIL_tanim_bazinda_EZILIR(client, yon):
    """Kilit olsaydi, o siteye bir gun su faturasini kiraciya yazmak
    gerektiginde ayar TUM turleri birden etkilerdi."""
    onceki = client.get("/tenant/settings", headers=yon).json()[
        "varsayilan_hedef_kurali"]
    try:
        _ayar(client, yon, "malik")
        r = client.post("/gelir-gider-tanimlari", headers=yon, json={
            "ad": f"P218 ezme {uuid.uuid4().hex[:5]}", "tip": "gider",
            "hedef_kurali": "kiraci_oncelikli"})
        assert r.json()["hedef_kurali"] == "kiraci_oncelikli"
    finally:
        _ayar(client, yon, onceki)


def test_VARSAYILAN_MEVCUT_tanimlara_DOKUNMAZ(client, yon):
    """Calisan bir sitenin gecmis kurulumunu degistirmek, kimsenin
    istemedigi bir davranis degisimi olurdu."""
    onceki = client.get("/tenant/settings", headers=yon).json()[
        "varsayilan_hedef_kurali"]
    try:
        _ayar(client, yon, "kiraci_oncelikli")
        t = client.post("/gelir-gider-tanimlari", headers=yon, json={
            "ad": f"P218 eski {uuid.uuid4().hex[:5]}", "tip": "gider"}).json()
        assert t["hedef_kurali"] == "kiraci_oncelikli"
        _ayar(client, yon, "malik")
        hepsi = client.get("/gelir-gider-tanimlari?limit=200", headers=yon).json()
        ayni = [x for x in hepsi["items"] if x["id"] == t["id"]][0]
        assert ayni["hedef_kurali"] == "kiraci_oncelikli", "mevcut tanim DEGISMIS"
    finally:
        _ayar(client, yon, onceki)


def test_YONETICI_varsayilani_DEGISTIREBILIR(client, yon):
    """"Isletme gideri kime yazilir" karari SITE YONETIMININ isidir —
    kira sozlesmelerini ve site teamulunu bilen kisi odur."""
    onceki = client.get("/tenant/settings", headers=yon).json()[
        "varsayilan_hedef_kurali"]
    try:
        r = client.patch("/tenant/settings", headers=yon,
                         json={"varsayilan_hedef_kurali": "malik"})
        assert r.status_code == 200, f"yoneticiye kapali: {r.text}"
        assert r.json()["varsayilan_hedef_kurali"] == "malik"
    finally:
        _ayar(client, yon, onceki)


# ==================== (§D / B4) HEDEF COZULEMEZSE ======================= #

def test_ONIZLEME_hedefsiz_satirlari_SAYAR(client, yon):
    """(B4) VERI EKSIKLIGI SESSIZ KALMAZ.

    `hedef_kurali = malik` olan bir tanimda dairede MALIK KAYITLI
    DEGILSE hedef cozulemez ve borc DAIREYE yazilir. Bu bir ATLAMA
    DEGIL (satir islenir) ama yoneticinin bilmesi gereken bir eksiklik:
    borc kimseye ait olmaz ve sakin ekraninda yanlis kisiye gorunebilir.
    """
    u = _daire(client, yon)
    k = _kisi(client, yon, "Yalniz Kiraci")
    client.post(f"/units/{u}/residents", headers=yon,
                json={"user_id": k, "rol_tipi": "kiraci"})
    tanim = _tanim(client, yon, "malik")

    r = client.post("/borclandirma/toplu/onizleme", headers=yon, json={
        "donem": _donem(), "gelir_gider_tanim_id": tanim,
        "tutar_kurus": 1000}, timeout=60)
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["hedefsiz"] >= 1, "hedefi cozulemeyen satir SAYILMIYOR"
    # Satir DUZEYINDE de isaretli — arayuz hangi daire oldugunu soylesin.
    isaretli = [s for s in d["satirlar"] if s.get("hedef_cozulemedi")]
    assert any(s["unit_id"] == u for s in isaretli), "daire isaretlenmemis"
    # Ve bu bir ATLAMA DEGIL: satir islenecekler arasinda.
    bizim = [s for s in d["satirlar"] if s["unit_id"] == u][0]
    assert bizim["atlama_nedeni"] is None


def test_HEDEFI_COZULEN_satir_ISARETLENMEZ(client, yon):
    """Isaret kor olmamali: malik kayitliyken uyari CIKMAMALI."""
    u = _daire(client, yon)
    m = _kisi(client, yon, "Malik")
    client.post(f"/units/{u}/residents", headers=yon,
                json={"user_id": m, "rol_tipi": "malik"})
    r = client.post("/borclandirma/toplu/onizleme", headers=yon, json={
        "donem": _donem(), "gelir_gider_tanim_id": _tanim(client, yon, "malik"),
        "tutar_kurus": 1000}, timeout=60)
    bizim = [s for s in r.json()["satirlar"] if s["unit_id"] == u][0]
    assert bizim["hedef_cozulemedi"] is False
    assert bizim["hedef_user_id"] is not None


def test_KIRACI_hedefsiz_MALIK_borcunu_GORMEZ(client, world, owner_conn):
    """(B4 ikinci yari) YANLIS KISIYE GOSTERME.

    Daireye yazilan her kalem o dairenin TUM sakinlerine gorunuyordu —
    yani malik icin kesilmis bir bakim borcunu KIRACI goruyordu. Hem
    yanlis bilgi hem gereksiz endise; ustelik kiraci onu odemekle
    yukumlu de degil.

    Sakinin KENDI borcu uzerinden olculuyor (`/me/odeme-bilgileri`):
    ekranda gordugu sayi budur.
    """
    from app.security import hash_password

    yon = _h(client, world["slug_a"], world["yonetici_a"])
    u = _daire(client, yon)
    # Kiraci hesabi — parola DOGRUDAN yazilir (yonetici parola atayamaz).
    eposta = f"p218k-{uuid.uuid4().hex[:10]}@ornek.com"
    kid = _kisi(client, yon, "Kiraci Gorunurluk")
    owner_conn.execute("UPDATE app_user SET email = %s, password_hash = %s WHERE id = %s",
                       (eposta, hash_password("KiraciPass1"), kid))
    client.post(f"/units/{u}/residents", headers=yon,
                json={"user_id": kid, "rol_tipi": "kiraci"})

    # 1) MALIK kalemi (dairede malik YOK -> hedefsiz, daireye yazilir)
    client.post("/dues/assessments", headers=yon, json={
        "unit_id": u, "donem": _donem(), "tutar_kurus": 50000,
        "gelir_gider_tanim_id": _tanim(client, yon, "malik")})
    # 2) KULLANAN kalemi -> kiraciya hedeflenir
    client.post("/dues/assessments", headers=yon, json={
        "unit_id": u, "donem": _donem(), "tutar_kurus": 7000,
        "gelir_gider_tanim_id": _tanim(client, yon, "kiraci_oncelikli")})

    kh = _h(client, world["slug_a"], {"email": eposta, "password": "KiraciPass1"})
    borc = client.get("/me/odeme-bilgileri", headers=kh).json()["borc_kurus"]
    assert borc == 7000, (
        f"kiraci {borc} kurus goruyor; MALIK kalemi (50000) sizmis olabilir"
    )


def test_MALIK_hedefsiz_kalemi_GORUR(client, world, owner_conn):
    """Kural fazla genis olmamali: kiraci OLMAYAN bir sakin (malik ya da
    rolsuz) daireye yazilmis kalemleri gormeye DEVAM etmeli — eski
    (P28 oncesi, tursuz) tahakkuklar oyle yaziliydi ve onlari gizlemek,
    odenmesi gereken borcu saklamak olurdu."""
    from app.security import hash_password

    yon = _h(client, world["slug_a"], world["yonetici_a"])
    u = _daire(client, yon)
    eposta = f"p218m-{uuid.uuid4().hex[:10]}@ornek.com"
    mid = _kisi(client, yon, "Malik Gorunurluk")
    owner_conn.execute("UPDATE app_user SET email = %s, password_hash = %s WHERE id = %s",
                       (eposta, hash_password("MalikPass1"), mid))
    client.post(f"/units/{u}/residents", headers=yon,
                json={"user_id": mid, "rol_tipi": "malik"})

    # TURSUZ tahakkuk -> hedefsiz, daireye yazilir.
    client.post("/dues/assessments", headers=yon, json={
        "unit_id": u, "donem": _donem(), "tutar_kurus": 3300})

    mh = _h(client, world["slug_a"], {"email": eposta, "password": "MalikPass1"})
    borc = client.get("/me/odeme-bilgileri", headers=mh).json()["borc_kurus"]
    assert borc == 3300, f"malik kendi dairesinin hedefsiz borcunu gormuyor: {borc}"


# ==================== (§E) HEDEF EZME ve SIFAT GORUNURLUGU ============== #

def test_TEKIL_tahakkukta_hedef_kurali_EZILEBILIR(client, yon):
    """Varsayilan tanimdan gelir (her ay ayni karar, her ay yeni hata
    firsati) AMA istisnalar var: sozlesmeye gore devredilen bir kalem,
    bir kereye mahsus malige yazilan isletme gideri."""
    u = _daire(client, yon)
    m, k = _kisi(client, yon, "Malik"), _kisi(client, yon, "Kiraci")
    client.post(f"/units/{u}/residents", headers=yon,
                json={"user_id": m, "rol_tipi": "malik"})
    client.post(f"/units/{u}/residents", headers=yon,
                json={"user_id": k, "rol_tipi": "kiraci"})
    tanim = _tanim(client, yon, "kiraci_oncelikli")

    # Tanimin kurali: kullanan -> kiraci
    assert _hedef(client, yon, u, tanim, _donem()) == k

    # EZME: bu tahakkuk malige
    r = client.post("/dues/assessments", headers=yon, json={
        "unit_id": u, "donem": _donem(), "tutar_kurus": 999,
        "gelir_gider_tanim_id": tanim, "hedef_kurali": "malik"})
    assert r.json()["created"][0]["hedef_user_id"] == m


def test_EZME_TANIMI_DEGISTIRMEZ(client, yon):
    """Ezme O PARTIYE uygulanir; tanim bir sonraki ay yine kendi
    kuraliyla calismali."""
    u = _daire(client, yon)
    m = _kisi(client, yon, "Malik")
    client.post(f"/units/{u}/residents", headers=yon,
                json={"user_id": m, "rol_tipi": "malik"})
    tanim = _tanim(client, yon, "kiraci_oncelikli")
    client.post("/dues/assessments", headers=yon, json={
        "unit_id": u, "donem": _donem(), "tutar_kurus": 100,
        "gelir_gider_tanim_id": tanim, "hedef_kurali": "malik"})
    hepsi = client.get("/gelir-gider-tanimlari?limit=200", headers=yon).json()
    ayni = [x for x in hepsi["items"] if x["id"] == tanim][0]
    assert ayni["hedef_kurali"] == "kiraci_oncelikli", "tanim DEGISMIS"


def test_TOPLU_yolda_da_EZILEBILIR(client, yon):
    """Iki yol ayni ekrandan kullaniliyor; birinde ezme olup otekinde
    olmamasi, ayni islemin farkli sonuc vermesi demekti."""
    u = _daire(client, yon)
    m = _kisi(client, yon, "Malik Toplu")
    client.post(f"/units/{u}/residents", headers=yon,
                json={"user_id": m, "rol_tipi": "malik"})
    r = client.post("/borclandirma/toplu/onizleme", headers=yon, json={
        "donem": _donem(), "gelir_gider_tanim_id": _tanim(client, yon, "kiraci_oncelikli"),
        "tutar_kurus": 500, "hedef_kurali": "malik"}, timeout=60)
    assert r.status_code == 200, r.text
    bizim = [s for s in r.json()["satirlar"] if s["unit_id"] == u][0]
    assert bizim["hedef_user_id"] == m


def test_TAHAKKUK_hedefin_SIFATINI_doner(client, yon):
    """(B5) "Bu borc neden ona yazildi" sorusu EKRANDAN yanitlanabilmeli.
    Ad tek basina soylemiyordu: ayni isim bir dairede malik, otekinde
    kiraci olabilir."""
    u = _daire(client, yon)
    mo = _kisi(client, yon, "Malik Oturan")
    client.post(f"/units/{u}/residents", headers=yon,
                json={"user_id": mo, "rol_tipi": "malik", "oturuyor": True})
    r = client.post("/dues/assessments", headers=yon, json={
        "unit_id": u, "donem": _donem(), "tutar_kurus": 100,
        "gelir_gider_tanim_id": _tanim(client, yon, "malik")})
    kayit = r.json()["created"][0]
    assert kayit["hedef_ad"]
    # "malik" DEGIL "malik_oturan": yalnizca "malik" demek, ekranda
    # okunamayan bir ayrim birakirdi.
    assert kayit["hedef_sifat"] == "malik_oturan"


def test_HEDEFSIZ_tahakkukta_sifat_None(client, yon):
    u = _daire(client, yon)
    r = client.post("/dues/assessments", headers=yon, json={
        "unit_id": u, "donem": _donem(), "tutar_kurus": 100})
    assert r.json()["created"][0]["hedef_sifat"] is None
