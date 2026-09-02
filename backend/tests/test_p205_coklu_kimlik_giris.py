"""(P205 §1) COK YONLU GIRIS — e-posta VEYA telefon, tek alan.

===========================================================================
OLCULEN KUSUR
===========================================================================
Mobilde e-posta ile giris HIC YOKTU (yalniz telefon + SSO). P197'den beri
e-posta ZORUNLU, telefon OPSIYONEL — yani web'den e-posta+parolayla
kaydolmus, telefon girmemis bir yonetici mobile HIC GIREMIYORDU.

===========================================================================
SIZDIRMAMA — BU DOSYANIN YARISI
===========================================================================
Gecersiz e-posta, gecersiz telefon, bilinmeyen kimlik, yanlis parola ve
cozulemeyen girdi HEPSI AYNI 401'i almali. Aksi hâlde uc, "bu adres
kayitli mi" sorgusuna donusur.
"""
from __future__ import annotations

import uuid

import pytest


def _giris(client, **govde):
    return client.post("/auth/login", json=govde)


@pytest.fixture(autouse=True)
def _hiz_sinirini_sifirla(redis_client):
    if redis_client is None:
        yield
        return
    for a in redis_client.scan_iter("hiz:tesislerim:*"):
        redis_client.delete(a)
    yield


@pytest.fixture
def cift_tesis(world, owner_conn):
    """Ayni e-posta+parola A ve B'de. Rol B'de SAKIN."""
    eposta = world["yonetici_a"]["email"]
    with owner_conn.cursor() as cur:
        cur.execute("SELECT password_hash FROM app_user WHERE tenant_id=%s AND email=%s",
                    (world["a"], eposta))
        h = cur.fetchone()[0]
        cur.execute("UPDATE app_user SET password_hash=%s, role='resident'::user_role "
                    "WHERE tenant_id=%s AND email=%s", (h, world["b"], eposta))
    return eposta, world["yonetici_a"]["password"]


# ======================= 1) IKI KIMLIK DE CALISIR ========================= #

def test_EPOSTA_ile_giris(client, world):
    r = _giris(client, kimlik=world["guard_a"]["email"],
               password=world["guard_a"]["password"])
    assert r.status_code == 200, r.text
    assert "access_token" in r.json()


def test_TELEFON_ile_giris(client, world):
    """Ayni uc, ayni alan — kullaniciya "hangisini yaziyorsun" diye
    SORULMAZ."""
    r = _giris(client, kimlik=world["guard_a"]["phone"],
               password=world["guard_a"]["password"])
    assert r.status_code == 200, r.text


@pytest.mark.parametrize("bicim", ["0{}", "+90{}", "0{} ", " 0{}"])
def test_TELEFON_YAZIMI_serbest(client, world, bicim):
    """Bes farkli yazim AYNI kisi. Normalize etmeden aramak,
    kullanicinin bosluk koyup koymamasina gore giris yaptirmakti."""
    ham = world["guard_a"]["phone"]           # +90532...
    govde = ham[3:]                            # 532...
    r = _giris(client, kimlik=bicim.format(govde),
               password=world["guard_a"]["password"])
    assert r.status_code == 200, f"{bicim}: {r.text}"


def test_ESKI_ISTEMCI_email_alani_CALISMAYA_DEVAM_EDER(client, world):
    """Mobil uygulama magazadadir; eski surumler bir sure daha `email`
    gonderecek. Alani zorunlu kilmak, guncellemeyen kullanicilarin
    girisini KIRMAK olurdu."""
    r = _giris(client, email=world["guard_a"]["email"],
               password=world["guard_a"]["password"])
    assert r.status_code == 200, r.text


# ==================== 2) SIZDIRMAMA — HEPSI AYNI 401 ====================== #

def _yanit_imzasi(r):
    """Durum + hata kodu + metin. Ucu de AYNI olmali."""
    govde = r.json()
    return (r.status_code, govde["error"]["code"], govde["error"]["message"])


def test_TUM_BASARISIZ_DURUMLAR_AYNI_YANIT(client, world):
    parola = world["guard_a"]["password"]
    imzalar = {
        "yanlis parola": _yanit_imzasi(
            _giris(client, kimlik=world["guard_a"]["email"], password="Yanlis1!x")),
        "bilinmeyen eposta": _yanit_imzasi(
            _giris(client, kimlik=f"yok-{uuid.uuid4().hex[:8]}@ornek.com",
                   password=parola)),
        "bilinmeyen telefon": _yanit_imzasi(
            _giris(client, kimlik="+905550000000", password=parola)),
        "cozulemeyen girdi": _yanit_imzasi(
            _giris(client, kimlik="cop-girdi", password=parola)),
        "bos gibi girdi": _yanit_imzasi(
            _giris(client, kimlik="123", password=parola)),
    }
    benzersiz = set(imzalar.values())
    assert len(benzersiz) == 1, (
        "basarisiz durumlar AYIRT EDILEBILIYOR — uc 'bu adres kayitli mi' "
        f"sorgusuna donusur: {imzalar}"
    )
    assert benzersiz.pop()[0] == 401


def test_METIN_KIMLIK_TURUNU_SOYLEMEZ(client, world):
    """"E-posta hatali" demek, saldirgana girdisinin hangi dala
    girdigini soylerdi."""
    r = _giris(client, kimlik="cop", password="Herhangi1!")
    mesaj = r.json()["error"]["message"].lower()
    assert "posta" not in mesaj and "telefon" not in mesaj, mesaj


def test_PASIF_HESAP_da_AYNI_401(client, world, owner_conn):
    with owner_conn.cursor() as cur:
        cur.execute("UPDATE app_user SET is_active=false WHERE tenant_id=%s AND email=%s",
                    (world["a"], world["gorevli_a"]["email"]))
    try:
        r = _giris(client, kimlik=world["gorevli_a"]["email"],
                   password=world["gorevli_a"]["password"])
        assert r.status_code == 401, r.text
        assert r.json()["error"]["code"] == "invalid_credentials"
    finally:
        with owner_conn.cursor() as cur:
            cur.execute("UPDATE app_user SET is_active=true WHERE tenant_id=%s "
                        "AND email=%s", (world["a"], world["gorevli_a"]["email"]))


# ======================= 3) COK TESIS ===================================== #

def test_TEK_TESIS_dogrudan_girer_SECIM_YOK(client, world):
    """Tek tesisliye secim gostermek, olmayan bir karar sunmaktir."""
    r = _giris(client, kimlik=world["guard_a"]["email"],
               password=world["guard_a"]["password"])
    assert r.status_code == 200, r.text


def test_COK_TESIS_SECIM_ISTER_JETON_VERMEZ(client, cift_tesis):
    """Rastgele birini secmek, kullaniciyi bilmedigi bir tesise
    sokmak olurdu."""
    eposta, parola = cift_tesis
    r = _giris(client, kimlik=eposta, password=parola)
    assert r.status_code == 409, r.text
    assert r.json()["error"]["code"] == "tesis_secimi_gerekli"
    assert "access_token" not in r.text


def test_SLUG_VERILINCE_o_tesise_girer(client, world, cift_tesis):
    eposta, parola = cift_tesis
    r = _giris(client, kimlik=eposta, password=parola,
               tenant_slug=world["slug_b"])
    assert r.status_code == 200, r.text


def test_ROL_SECILEN_TESISIN_ROLUDUR(client, world, cift_tesis):
    """Ozelligin kalbi: ayni kisi A'da yonetici, B'de sakin."""
    eposta, parola = cift_tesis
    for slug, beklenen in ((world["slug_a"], "yonetici"), (world["slug_b"], "resident")):
        r = _giris(client, kimlik=eposta, password=parola, tenant_slug=slug)
        assert r.status_code == 200, r.text
        h = {"Authorization": f"Bearer {r.json()['access_token']}"}
        assert client.get("/me", headers=h).json()["role"] == beklenen, slug


def test_UYE_OLMADIGI_SLUG_401_ve_AYNI_metin(client, world):
    """Slug'i yanlis vermek, "bu tesiste yoksun" bilgisini
    SIZDIRMAMALI."""
    r = _giris(client, kimlik=world["guard_a"]["email"],
               password=world["guard_a"]["password"], tenant_slug=world["slug_b"])
    assert r.status_code == 401, r.text
    assert r.json()["error"]["code"] == "invalid_credentials"


# ==================== 4) TESISLERIM — IKI KIMLIK ========================== #

def test_TESISLERIM_EPOSTAYLA_coklu_TELEFONLA_tekli(client, world, cift_tesis):
    """Telefon GLOBAL BENZERSIZ (P204 karari: kisit KALDIRILMADI), yani
    telefonla eslesme en fazla BIR satir doner — tesis secimi o durumda
    zaten cikmaz."""
    eposta, parola = cift_tesis
    r = client.post("/auth/tesislerim", json={"kimlik": eposta, "password": parola})
    assert r.status_code == 200, r.text
    assert len(r.json()["tesisler"]) == 2

    r = client.post("/auth/tesislerim", json={
        "kimlik": world["yonetici_a"]["phone"], "password": parola})
    assert r.status_code == 200, r.text
    assert len(r.json()["tesisler"]) == 1


def test_TESISLERIM_COZULEMEYEN_girdi_BOS_LISTE(client):
    """Hata DEGIL: "bu bir e-posta degil" demek, girdinin hangi dala
    girdigini soylerdi."""
    r = client.post("/auth/tesislerim", json={"kimlik": "cop", "password": "Ax1!aaaa"})
    assert r.status_code == 200, r.text
    assert r.json()["tesisler"] == []


# ======================= 5) IZOLASYON ===================================== #

def test_SECILEN_TESIS_DISI_VERI_GORUNMEZ(client, world, cift_tesis, owner_conn):
    """IZOLASYON KILIDI — iki jeton ayni kisiye ait ama gordukleri
    kume KESISMEZ."""
    eposta, parola = cift_tesis
    isaret_a = f"A-{uuid.uuid4().hex[:8]}"
    isaret_b = f"B-{uuid.uuid4().hex[:8]}"
    with owner_conn.cursor() as cur:
        for tid, isaret in ((world["a"], isaret_a), (world["b"], isaret_b)):
            cur.execute("SELECT id FROM app_user WHERE tenant_id=%s LIMIT 1", (tid,))
            yazan = cur.fetchone()[0]
            cur.execute(
                "INSERT INTO announcement (tenant_id, baslik, govde, olusturan_user_id) "
                "VALUES (%s,%s,'g',%s)", (tid, isaret, yazan))

    def basliklar(slug):
        r = _giris(client, kimlik=eposta, password=parola, tenant_slug=slug)
        assert r.status_code == 200, r.text
        h = {"Authorization": f"Bearer {r.json()['access_token']}"}
        d = client.get("/announcements", headers=h)
        assert d.status_code == 200, d.text
        govde = d.json()
        ogeler = govde.get("items", govde) if isinstance(govde, dict) else govde
        return {o["baslik"] for o in ogeler}

    a = basliklar(world["slug_a"])
    b = basliklar(world["slug_b"])
    assert isaret_a in a and isaret_b in b
    assert isaret_b not in a, "A jetonu B'nin verisini GORUYOR"
    assert isaret_a not in b, "B jetonu A'nin verisini GORUYOR"
