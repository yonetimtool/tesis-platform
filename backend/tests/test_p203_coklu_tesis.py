"""(P203 §2) COKLU TESIS — uyelik, gecis ve IZOLASYON.

===========================================================================
ONCE OLCUM: MODEL BUNU ZATEN DESTEKLIYOR
===========================================================================
Olculen kisitlar:

    uq_app_user_tenant_email        UNIQUE (tenant_id, email)
    uq_app_user_telefon             UNIQUE (telefon) WHERE telefon NOT NULL

E-posta TESIS ICINDE benzersiz, platform genelinde DEGIL — yani ayni kisi
N tesiste N AYRI satir olarak durur ve HER SATIRIN KENDI ROLU vardir.
Sema degisikligi GEREKMEDI; eksik olan sey kullanicinin bu satirlari
gorebilmesi ve arasinda gecebilmesiydi.

TELEFON GLOBAL BENZERSIZ: ayni kisi iki tesiste ayni telefonu tasiyamaz.
Akisi engellemiyor (P197'den beri kimlik e-postadir) ama BILINEN bir
sinirdir ve `test_TELEFON_GLOBAL_BENZERSIZ` bunu kayit altina alir.

===========================================================================
EN KRITIK KISIM: IZOLASYON
===========================================================================
Jeton TEK bir `tenant_id` tasir ve RLS onu kullanir. Gecis = HEDEF TESIS
ICIN YENI JETON. Bu dosyanin yarisi, gecisin bu siniri delmedigini olcer.
"""
from __future__ import annotations

import uuid

import pytest


@pytest.fixture(autouse=True)
def _hiz_sinirini_sifirla(redis_client):
    """`/auth/tesislerim` bir PAROLA DENEME yuzeyidir ve hiz sinirlidir
    (e-posta basina 10/15dk). Bu dosyadaki testler AYNI e-postayi
    paylasiyor; sayaci sifirlamazsak testler birbirinin butcesini
    tuketir ve dosya SIRA BAGIMLI hâle gelir — kodla ilgisi olmayan
    kirmizi. Sinirin KENDISI ayrica olculuyor (asagida).
    """
    if redis_client is None:
        yield
        return
    for anahtar in redis_client.scan_iter("hiz:tesislerim:*"):
        redis_client.delete(anahtar)
    yield


def _giris(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def cift_uyelik(world, owner_conn):
    """A'da YONETICI olan kisiyi B'ye SAKIN olarak da ekler.

    `world` fixture'i B'de ayni e-postayla bir YONETICI zaten aciyor;
    rolu SAKINE cevirmek, "her tesiste kendi rolu" kuralini olculebilir
    kilar (aksi hâlde iki tarafta da yonetici olurdu ve rol tasindi mi
    tasinmadi mi anlasilmazdi).
    """
    eposta = world["yonetici_a"]["email"]
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT password_hash FROM app_user WHERE tenant_id=%s AND email=%s",
            (world["a"], eposta),
        )
        hash_a = cur.fetchone()[0]
        cur.execute(
            "UPDATE app_user SET role='resident'::user_role, password_hash=%s "
            "WHERE tenant_id=%s AND email=%s",
            (hash_a, world["b"], eposta),
        )
    return eposta, world["yonetici_a"]["password"]


# ======================= 1) UYELIK LISTESI ================================ #

def test_GIRIS_ONCESI_uyelikler_PAROLAYLA_listelenir(client, world, cift_uyelik):
    eposta, parola = cift_uyelik
    r = client.post("/auth/tesislerim", json={"email": eposta, "password": parola})
    assert r.status_code == 200, r.text
    tesisler = {t["slug"]: t for t in r.json()["tesisler"]}
    assert world["slug_a"] in tesisler and world["slug_b"] in tesisler
    # HER TESISTE KENDI ROLU.
    assert tesisler[world["slug_a"]]["rol"] == "yonetici"
    assert tesisler[world["slug_b"]]["rol"] == "resident"


def test_YANLIS_PAROLA_bos_liste_doner_SIZDIRMAZ(client, cift_uyelik):
    """"Yanlis parola" ile "hic uyelik yok" AYIRT EDILMEZ: ikisi de bos
    liste. Aksi hâlde uc, "bu e-posta hangi sitelerde oturuyor" sorgusuna
    donusurdu."""
    eposta, _ = cift_uyelik
    r = client.post("/auth/tesislerim",
                    json={"email": eposta, "password": "TamamenYanlis1!"})
    assert r.status_code == 200, r.text
    assert r.json()["tesisler"] == []


def test_BILINMEYEN_EPOSTA_da_bos_liste(client):
    r = client.post("/auth/tesislerim", json={
        "email": f"yok-{uuid.uuid4().hex[:8]}@ornek.com", "password": "HerhangiBir1!"})
    assert r.status_code == 200, r.text
    assert r.json()["tesisler"] == []


def test_TEK_TESISLI_kullanicida_liste_TEK_eleman(client, world):
    """Tek tesise bagliysa secim EKRANI CIKMAMALI — istemci bunu liste
    uzunlugundan anlar, o yuzden uzunluk kilitlenir."""
    r = client.post("/auth/tesislerim", json={
        "email": world["guard_a"]["email"], "password": world["guard_a"]["password"]})
    assert r.status_code == 200, r.text
    assert len(r.json()["tesisler"]) == 1


# ==================== 2) UYGULAMA ICI GECIS =============================== #

def test_OTURUMDAN_uyelikler_PAROLASIZ_okunur(client, world, cift_uyelik):
    eposta, parola = cift_uyelik
    h = _giris(client, world["slug_a"], {"email": eposta, "password": parola})
    r = client.get("/me/tesislerim", headers=h)
    assert r.status_code == 200, r.text
    assert {t["slug"] for t in r.json()["tesisler"]} >= {
        world["slug_a"], world["slug_b"]
    }


def test_GECIS_yeni_jeton_verir_ve_ROL_HEDEFIN_ROLUDUR(client, world, cift_uyelik):
    """Ozelligin kalbi: ayni kisi A'da yonetici, B'de sakin gorunmeli."""
    eposta, parola = cift_uyelik
    h = _giris(client, world["slug_a"], {"email": eposta, "password": parola})
    assert client.get("/me", headers=h).json()["role"] == "yonetici"

    hedef = next(
        t for t in client.get("/me/tesislerim", headers=h).json()["tesisler"]
        if t["slug"] == world["slug_b"]
    )
    r = client.post("/me/tesis-degistir", headers=h,
                    json={"tenant_id": hedef["tenant_id"]})
    assert r.status_code == 200, r.text
    h2 = {"Authorization": f"Bearer {r.json()['access_token']}"}
    assert client.get("/me", headers=h2).json()["role"] == "resident"


def test_GECIS_YENIDEN_GIRIS_ISTEMEZ(client, world, cift_uyelik):
    """Istegin acik sarti. Gecis govdesinde PAROLA ALANI YOKTUR."""
    eposta, parola = cift_uyelik
    h = _giris(client, world["slug_a"], {"email": eposta, "password": parola})
    hedef = next(
        t for t in client.get("/me/tesislerim", headers=h).json()["tesisler"]
        if t["slug"] == world["slug_b"]
    )
    # Yalnizca tenant_id — baska hicbir sey.
    r = client.post("/me/tesis-degistir", headers=h,
                    json={"tenant_id": hedef["tenant_id"]})
    assert r.status_code == 200, r.text


def test_GERI_DONULEBILIR(client, world, cift_uyelik):
    """Eski jeton kaynak tesiste GECERLI KALIR; kullanici geri donebilmeli."""
    eposta, parola = cift_uyelik
    h = _giris(client, world["slug_a"], {"email": eposta, "password": parola})
    hedef = next(
        t for t in client.get("/me/tesislerim", headers=h).json()["tesisler"]
        if t["slug"] == world["slug_b"]
    )
    client.post("/me/tesis-degistir", headers=h, json={"tenant_id": hedef["tenant_id"]})
    assert client.get("/me", headers=h).json()["role"] == "yonetici"


# ================== 3) IZOLASYON — EN KRITIK KISIM ======================== #

def test_UYE_OLMAYAN_TESISE_GECILEMEZ(client, world):
    """Uc, "istedigim tenant'in jetonunu al" ucuna DONUSMEMELI."""
    h = _giris(client, world["slug_a"], world["guard_a"])  # yalniz A'da uye
    r = client.post("/me/tesis-degistir", headers=h, json={"tenant_id": str(world["b"])})
    assert r.status_code == 403, r.text


def test_OLMAYAN_TENANT_da_403_AYIRT_ETTIRMEZ(client, world):
    """"Boyle bir tesis yok" ile "uye degilsin" AYNI yanit: aksi hâlde uc
    tenant kimligi sorgulama araci olurdu."""
    h = _giris(client, world["slug_a"], world["guard_a"])
    r = client.post("/me/tesis-degistir", headers=h,
                    json={"tenant_id": str(uuid.uuid4())})
    assert r.status_code == 403, r.text


def test_GECIS_SONRASI_JETON_YALNIZ_HEDEF_TESISI_GORUR(
    client, world, cift_uyelik, owner_conn
):
    """IZOLASYON KILIDI.

    Gecis, tenant sinirini delen bir arka kapi OLMAMALI. Iki jeton da
    ayni kisiye ait ama BASKA tenant'lara bakar ve gordukleri kume
    KESISMEZ.
    """
    eposta, parola = cift_uyelik
    # A'ya, B'de OLMAYAN benzersiz bir kayit yaz (blok adi isaret).
    # DUYURU secildi cunku ROL BAGIMSIZ okunur (rol matrisi: yonetici de
    # sakin de GET /announcements'i gorur). `/blocks` kullanilsaydi B
    # jetonu 403 alirdi ve test, izolasyonu degil ROL KAPISINI olcerdi.
    isaret_a = f"A-{uuid.uuid4().hex[:8]}"
    isaret_b = f"B-{uuid.uuid4().hex[:8]}"
    with owner_conn.cursor() as cur:
        for tid, isaret in ((world["a"], isaret_a), (world["b"], isaret_b)):
            cur.execute(
                "SELECT id FROM app_user WHERE tenant_id=%s LIMIT 1", (tid,)
            )
            yazan = cur.fetchone()[0]
            cur.execute(
                "INSERT INTO announcement (tenant_id, baslik, govde, olusturan_user_id) "
                "VALUES (%s,%s,'govde',%s)",
                (tid, isaret, yazan),
            )

    h_a = _giris(client, world["slug_a"], {"email": eposta, "password": parola})
    hedef = next(
        t for t in client.get("/me/tesislerim", headers=h_a).json()["tesisler"]
        if t["slug"] == world["slug_b"]
    )
    r = client.post("/me/tesis-degistir", headers=h_a,
                    json={"tenant_id": hedef["tenant_id"]})
    h_b = {"Authorization": f"Bearer {r.json()['access_token']}"}

    def basliklar(h):
        r = client.get("/announcements", headers=h)
        assert r.status_code == 200, r.text
        govde = r.json()
        ogeler = govde.get("items", govde) if isinstance(govde, dict) else govde
        return {o["baslik"] for o in ogeler}

    a_gorulen = basliklar(h_a)
    b_gorulen = basliklar(h_b)
    assert isaret_a in a_gorulen, "A jetonu A'nin verisini gormeli"
    assert isaret_b in b_gorulen, "B jetonu B'nin verisini gormeli"
    # ASIL KILIT: capraz gorunurluk YOK.
    assert isaret_b not in a_gorulen, "A jetonu B'nin verisini GORUYOR"
    assert isaret_a not in b_gorulen, "B jetonu A'nin verisini GORUYOR"


def test_GECIS_DENETIME_YAZILIR(client, world, cift_uyelik, owner_conn):
    """Gecis PAROLA SORMAZ; bu yuzden "kim, ne zaman, nereden nereye"
    sorusu yanitlanabilir olmali."""
    eposta, parola = cift_uyelik
    h = _giris(client, world["slug_a"], {"email": eposta, "password": parola})
    hedef = next(
        t for t in client.get("/me/tesislerim", headers=h).json()["tesisler"]
        if t["slug"] == world["slug_b"]
    )
    client.post("/me/tesis-degistir", headers=h, json={"tenant_id": hedef["tenant_id"]})
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT meta FROM audit_log WHERE tenant_id=%s AND action='tesis_degistir' "
            "ORDER BY ts DESC LIMIT 1", (world["b"],))
        satir = cur.fetchone()
    assert satir is not None, "gecis denetime yazilmadi"
    assert str(world["a"]) in str(satir[0]), "kaynak tesis kaydedilmemis"


def test_PASIF_HESABA_GECILEMEZ(client, world, cift_uyelik, owner_conn):
    eposta, parola = cift_uyelik
    h = _giris(client, world["slug_a"], {"email": eposta, "password": parola})
    hedef = next(
        t for t in client.get("/me/tesislerim", headers=h).json()["tesisler"]
        if t["slug"] == world["slug_b"]
    )
    with owner_conn.cursor() as cur:
        cur.execute("UPDATE app_user SET is_active=false WHERE tenant_id=%s AND email=%s",
                    (world["b"], eposta))
    try:
        r = client.post("/me/tesis-degistir", headers=h,
                        json={"tenant_id": hedef["tenant_id"]})
        assert r.status_code == 403, r.text
        # Pasif uyelik LISTEDE DE gorunmemeli.
        kalanlar = {t["slug"] for t in client.get("/me/tesislerim", headers=h).json()["tesisler"]}
        assert world["slug_b"] not in kalanlar
    finally:
        with owner_conn.cursor() as cur:
            cur.execute("UPDATE app_user SET is_active=true WHERE tenant_id=%s AND email=%s",
                        (world["b"], eposta))


# ===================== 4) BILINEN SINIR ==================================== #

def test_TELEFON_GLOBAL_BENZERSIZ_bilinen_sinir(owner_conn):
    """Ayni kisi iki tesiste AYNI telefonu tasiyamaz.

    Akisi engellemiyor (kimlik e-postadir) ama KAYIT ALTINA ALINIYOR:
    biri bir gun "telefonla coklu tesis girisi" isterse, once bu kisit
    kaldirilmali.
    """
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT indexdef FROM pg_indexes WHERE indexname='uq_app_user_telefon'"
        )
        satir = cur.fetchone()
    assert satir is not None, "telefon benzersizligi kalkmis — not guncellenmeli"
    assert "tenant" not in satir[0].lower(), (
        "telefon artik tenant-kapsamli — coklu tesis telefon girisi ACILABILIR"
    )


def test_HIZ_SINIRI_uygulanir(client, cift_uyelik, redis_client):
    """Uc bir PAROLA DENEME yuzeyidir: sinirsiz birakmak, e-posta
    bilinen bir hesaba karsi sozluk saldirisini serbest birakmak olurdu.

    Mesaj da AYRI: "cok fazla kod istegi" demek, kullaniciya yapmadigi
    bir seyi yaptigini soylemekti (P203 §2'de duzeltildi).
    """
    if redis_client is None:
        pytest.skip("redis yok")
    eposta, _ = cift_uyelik
    from app.hiz_siniri import DENEME_SINIRI

    son = None
    for _ in range(DENEME_SINIRI + 1):
        son = client.post("/auth/tesislerim",
                          json={"email": eposta, "password": "YanlisParola1!"})
    assert son.status_code == 429, son.text
    assert son.json()["error"]["code"] == "rate_limited"
    assert "kod" not in son.json()["error"]["message"].lower()
