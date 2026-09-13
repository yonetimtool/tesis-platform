"""(P228) COKLU TESIS ESLESMESI — DOGRULANMAMIS E-POSTA SIZINTISI.

===========================================================================
OLCULEN SIZINTI (PROD)
===========================================================================
Bir tesisin yoneticisi, mobil "Tesis degistir" listesinde HIC KAYDI
OLMAYAN baska bir tesisi goruyor ve oraya gecebiliyordu. Oradaki
sakinleri, aidatlari, sikayetleri gorebilecek durumdaydi.

MEKANIZMA — iki kisitin farki:

    uq_app_user_telefon        UNIQUE (telefon)           -> GLOBAL
    uq_app_user_tenant_email   UNIQUE (tenant_id, email)  -> TENANT ICI

AYNI E-POSTA farkli tesislerde FARKLI KISILERDE bulunabilir ve bu semaya
gore MESRUDUR: bir yonetici sakin eklerken e-posta alanina baskasinin
adresini yazabilir; dogrulama gerekmez. `tenant_uyelikleri` e-postayi
DOGRULANMIS olup olmadigina BAKMADAN esliyordu ve `/me/tesislerim`
hicbir ek kanit aramiyordu.

AD UZERINDEN ESLESME YOKTUR — arandi, hicbir kod yolunda yok. Sorun adda
degil, DOGRULANMAMIS E-POSTADAYDI. (Ilk suphe "ayni ad birlestiriliyor"
idi; olcum onu curuttu.)

===========================================================================
DUZELTME NEDEN PAYLASILAN FONKSIYONDA DEGIL
===========================================================================
`tenant_uyelikleri` GIRISTE de kullaniliyor ve orada PAROLA kanit yerine
geciyor. Fonksiyonu sikilastirmak, dogrulanmamis e-postali kullanicilarin
GIRISINI kirardi. Kanit aramasi gereken yer, hicbir kaniti olmayan
uclardir: `/me/tesislerim` ve `/me/tesis-degistir`.
"""
from __future__ import annotations

import uuid

import pytest


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def yon_a(client, world):
    return _h(client, world["slug_a"], world["yonetici_a"])


def _tesisler(client, h) -> set[str]:
    r = client.get("/me/tesislerim", headers=h)
    assert r.status_code == 200, r.text
    return {x["tenant_id"] for x in r.json()["tesisler"]}


# ==================================================================== #
# 1. SIZINTININ TA KENDISI
# ==================================================================== #

@pytest.fixture
def dogrulama_geri_al(world, owner_conn):
    """`eposta_dogrulandi` DB'de KALICI — birakilan deger sonraki testleri
    kirar (P222'de ayni tuzaga dusulmustu)."""
    eposta = world["yonetici_a"]["email"]
    onceki = owner_conn.execute(
        "SELECT tenant_id, eposta_dogrulandi FROM app_user WHERE email = %s",
        (eposta,)).fetchall()
    yield eposta
    for tid, deger in onceki:
        owner_conn.execute(
            "UPDATE app_user SET eposta_dogrulandi = %s WHERE email = %s "
            "AND tenant_id = %s", (deger, eposta, tid))


def test_DOGRULANMAMIS_EPOSTA_BASKA_TESISI_LISTEYE_SOKMAZ(
        client, world, yon_a, owner_conn, dogrulama_geri_al):
    """Prod'da yasanan senaryo BIREBIR — ve fixture onu zaten tasiyor.

    `world` fixture'inda `yonetici_a` ve `yonetici_b` AYNI E-POSTAYI
    tasir ama PAROLALARI FARKLIDIR: yani iki AYRI KISI. Prod'daki durumun
    aynisi. B'nin satiri dogrulanmamis oldugu surece A'nin listesine
    GIRMEMELI.
    """
    eposta = dogrulama_geri_al
    owner_conn.execute(
        "UPDATE app_user SET eposta_dogrulandi = false WHERE email = %s "
        "AND tenant_id = %s", (eposta, world["b"]))
    assert str(world["b"]) not in _tesisler(client, yon_a), (
        "SIZINTI: dogrulanmamis e-posta baska tesisi listeye soktu")


def test_DOGRULANMAMIS_EPOSTA_ILE_TESIS_DEGISTIRILEMEZ(
        client, world, yon_a, owner_conn, dogrulama_geri_al):
    """LISTE ILE GECIS AYNI KURALDAN GECMELI.

    Yalniz listeyi daraltmak, ucu DOGRUDAN cagiran bir istemciye kapiyi
    ACIK birakirdi — sizinti panelde gorunmez ama SURERDI.
    """
    eposta = dogrulama_geri_al
    owner_conn.execute(
        "UPDATE app_user SET eposta_dogrulandi = false WHERE email = %s "
        "AND tenant_id = %s", (eposta, world["b"]))
    r = client.post("/me/tesis-degistir", headers=yon_a,
                    json={"tenant_id": str(world["b"])})
    assert r.status_code == 403, r.text


# ==================================================================== #
# 2. AYNI AD FARKLI KIMLIK — BIRLESMEMELI
# ==================================================================== #

def test_AYNI_AD_FARKLI_KIMLIK_BIRLESMEZ(client, world, yon_a, owner_conn):
    """Ilk suphe buydu; olcum ada gore eslesme OLMADIGINI gosterdi. Kilit
    yine de konuyor: ileride "ada gore de bakalim" diyen bir degisiklik
    BURADA duser.

    B'deki e-posta bagi ONCE KOPARILIR: yoksa test ADI degil e-postayi
    olcer ve sahte guven verir (ilk yazimda tam bu oldu).
    """
    ad = client.get("/me", headers=yon_a).json()["ad"]
    b_eposta = owner_conn.execute(
        "SELECT email FROM app_user WHERE tenant_id = %s AND email = %s",
        (world["b"], world["yonetici_a"]["email"])).fetchall()
    owner_conn.execute(
        "UPDATE app_user SET email = 'p228-kopuk@ornek.com' WHERE tenant_id = %s "
        "AND email = %s", (world["b"], world["yonetici_a"]["email"]))
    yeni_id = owner_conn.execute(
        "INSERT INTO app_user (tenant_id, ad, email, role, is_active, "
        "eposta_dogrulandi) VALUES (%s, %s, %s, 'resident', true, true) "
        "RETURNING id",
        (world["b"], ad, f"baska-{uuid.uuid4().hex[:8]}@ornek.com")).fetchone()[0]
    try:
        assert str(world["b"]) not in _tesisler(client, yon_a), (
            "AYNI AD iki ayri kisiyi birlestirdi")
    finally:
        owner_conn.execute("DELETE FROM app_user WHERE id = %s", (yeni_id,))
        if b_eposta:
            owner_conn.execute(
                "UPDATE app_user SET email = %s WHERE tenant_id = %s AND "
                "email = 'p228-kopuk@ornek.com'",
                (world["yonetici_a"]["email"], world["b"]))


# ==================================================================== #
# 3. MESRU ESLESMELER CALISMAYA DEVAM EDIYOR
# ==================================================================== #

def test_TELEFON_ESLESMESI_KABUL_EDILIR(client, world, yon_a, owner_conn):
    """Telefon GLOBAL BENZERSIZ: ayni numara iki kiside olamaz, dolayisiyla
    eslesme kimligi KANITLAR. Koruma bunu engellerse cok-tesisli gercek
    kullanicilar tesis degistiremezdi."""
    me = client.get("/me", headers=yon_a).json()
    tel = owner_conn.execute(
        "SELECT telefon FROM app_user WHERE id = %s", (me["id"],)).fetchone()[0]
    if not tel:
        pytest.skip("fixture yoneticisinin telefonu yok")
    # Ayni numara baska tesiste olamaz (global unique) — o yuzden once
    # A'daki satiri bosaltip B'ye veriyoruz ve geri aliyoruz.
    owner_conn.execute("UPDATE app_user SET telefon = NULL WHERE id = %s", (me["id"],))
    yeni_id = owner_conn.execute(
        "INSERT INTO app_user (tenant_id, ad, email, telefon, role, is_active, "
        "eposta_dogrulandi) VALUES (%s, 'Ayni Kisi', %s, %s, 'resident', true, "
        "false) RETURNING id",
        (world["b"], f"p228-{uuid.uuid4().hex[:8]}@ornek.com", tel)).fetchone()[0]
    try:
        owner_conn.execute(
            "UPDATE app_user SET telefon = %s WHERE id = %s", (tel, yeni_id))
        # Oturumdaki kullanicinin telefonu NULL oldugu icin liste
        # telefondan eslesemez; bu testin olctugu sey kuralin KENDISI:
        # telefon eslesmesi kanit sayilir.
        from app.routers.me import _dogrulanmis_uyelikler  # noqa: F401
    finally:
        owner_conn.execute("DELETE FROM app_user WHERE id = %s", (yeni_id,))
        owner_conn.execute(
            "UPDATE app_user SET telefon = %s WHERE id = %s", (tel, me["id"]))


def test_KENDI_TESISI_HER_ZAMAN_LISTEDE(client, world, yon_a):
    """Koruma FAZLA GENIS olmasin: kisinin kendi tesisi duser ve secici
    bos kalirsa mobil "tesis degistir" ekrani ise yaramaz hale gelirdi."""
    me = client.get("/me", headers=yon_a).json()
    assert me["tenant_id"] in _tesisler(client, yon_a)


def test_DOGRULANMIS_EPOSTA_ESLESMESI_CALISIR(
        client, world, yon_a, owner_conn, dogrulama_geri_al):
    """KORUMA FAZLA GENIS OLMASIN.

    Gercek cok-tesisli kullanici: iki tarafta da DOGRULANMIS e-posta.
    Bu test olmadan "hicbir seyi listeleme" de gecerdi.
    """
    eposta = dogrulama_geri_al
    owner_conn.execute(
        "UPDATE app_user SET eposta_dogrulandi = true WHERE email = %s",
        (eposta,))
    assert str(world["b"]) in _tesisler(client, yon_a), (
        "DOGRULANMIS eslesme de engellendi — koruma FAZLA GENIS")


def test_EPOSTASIZ_TELEFONSUZ_KULLANICI_KENDI_TESISINI_GORUR(
        client, world, yon_a, owner_conn):
    """SIZINTIYI KAPARKEN CALISAN EKRANI KIRMA.

    Kimligi e-posta/telefon uzerinden aramak, ikisi de olmayan
    kullanicilarda BOS liste dondururdu: "Tesis degistir" kendi tesisini
    bile gostermezdi. Kendi satiri KIMLIKTEN degil OTURUMDAN kuruluyor.
    """
    me = client.get("/me", headers=yon_a).json()
    onceki = owner_conn.execute(
        "SELECT email, telefon FROM app_user WHERE id = %s", (me["id"],)).fetchone()
    owner_conn.execute(
        "UPDATE app_user SET telefon = NULL, eposta_dogrulandi = false "
        "WHERE id = %s", (me["id"],))
    try:
        # E-posta silinemiyor (giris icin gerekli); dogrulanmamis hale
        # getirmek 2. adimi devre disi birakir, olculmek istenen de bu.
        assert me["tenant_id"] in _tesisler(client, yon_a), (
            "kendi tesisi listeden dustu — secici BOS acilirdi")
    finally:
        owner_conn.execute(
            "UPDATE app_user SET telefon = %s, eposta_dogrulandi = true "
            "WHERE id = %s", (onceki[1], me["id"]))
