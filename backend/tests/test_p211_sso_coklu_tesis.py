"""(P211 §1) SSO ILE GIREN COK TESISLI YONETICI: TESIS ID DEGIL, SECIM.

===========================================================================
OLCULEN KUSUR
===========================================================================
`_yoneticiyi_epostayla_bul` eslesme BIRDEN COKSA `None` donuyordu; akis
"baglama_gerekli"ye dusuyor ve mobil ekran TESIS ID soruyordu. Yani iki
tesise bakan bir yonetici, SSO ile girmeye calistiginda ezberlemesi
gerekmeyen bir kodu ezberlemek zorundaydi — P205'te parola yolunda
kaldirdigimiz sartin ta kendisi.

P205'te olculmustu (`test_p205_sso_coklu_tesis`): SSO girisi daima
BAGLANTININ KURULDUGU tesise duser ve ikinci tesise SSO ile
ULASILAMIYOR. Bu tur o bosuglu, kimligi HENUZ BAGLI OLMAYAN kullanici
icin kapatiyor: hangi tesis oldugu bilinmiyorsa KULLANICIYA SORULUR.

===========================================================================
GUVENLIK SARTLARI DEGISMEDI
===========================================================================
  * adres SAGLAYICI TARAFINDAN DOGRULANMIS olmali,
  * secilebilecek tesisler YALNIZCA o adresin YONETICI oldugu tesisler,
  * secim jetonu TEK KULLANIMLIK ve hicbir tesise yetki VERMEZ,
  * listede olmayan `tenant_id` -> 403 (uc "istedigim tesisin jetonunu
    al" ucuna donusemez).
"""
from __future__ import annotations

import uuid

import pytest

from .test_p194_mobil_yonetici_sso import _kendi_dongusunde
from .test_p177_kayit_akisi import EPOSTA_ALANI, akis_acik, hazir_tesis  # noqa: F401


def _yonetici(owner_conn, tenant_id, eposta) -> uuid.UUID:
    uid = uuid.uuid4()
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO app_user (id, tenant_id, ad, email, role, is_active, "
            "password_set, eposta_dogrulandi) "
            "VALUES (%s,%s,%s,%s,'yonetici',true,true,true)",
            (uid, tenant_id, "P211 Yonetici", eposta))
    owner_conn.commit()
    return uid


@pytest.fixture
def iki_tesiste_yonetici(world, owner_conn):
    """AYNI e-posta ile A ve B tesislerinde yonetici."""
    eposta = f"p211-{uuid.uuid4().hex[:10]}@{EPOSTA_ALANI}"
    a = _yonetici(owner_conn, world["a"], eposta)
    b = _yonetici(owner_conn, world["b"], eposta)
    yield eposta, a, b
    with owner_conn.cursor() as cur:
        cur.execute("DELETE FROM app_user WHERE id IN (%s,%s)", (a, b))
    owner_conn.commit()


def _kimlik(eposta: str, *, dogrulanmis: bool = True):
    from app.routers.oauth import Kimlik

    return Kimlik(
        saglayici="google", subject=f"sub-{uuid.uuid4().hex}",
        eposta=eposta, email_verified=dogrulanmis, ad="P211",
    )


# ==================== 1) COZUMLEME: TESIS SECIMI ========================== #

def test_IKI_TESIS_eslesirse_TESIS_SECIMI_doner(client, iki_tesiste_yonetici):
    """Eskiden `None` donuyordu (=> Tesis ID soruluyordu)."""
    from app.routers.oauth import _yoneticiyi_epostayla_bul

    eposta, a, b = iki_tesiste_yonetici
    sonuc = _kendi_dongusunde(lambda: _yoneticiyi_epostayla_bul(_kimlik(eposta)))
    assert sonuc is not None, "cok tesiste eslesme HÂLÂ None donuyor"
    assert sonuc["tur"] == "tesis_secimi"
    assert {x["user_id"] for x in sonuc["adaylar"]} == {str(a), str(b)}


def test_TEK_TESIS_eslesirse_DOGRUDAN_giris(client, world, owner_conn):
    """Tek eslesmede davranis DEGISMEDI: secim sorulmaz."""
    from app.routers.oauth import _yoneticiyi_epostayla_bul

    eposta = f"p211-tek-{uuid.uuid4().hex[:8]}@{EPOSTA_ALANI}"
    uid = _yonetici(owner_conn, world["a"], eposta)
    try:
        sonuc = _kendi_dongusunde(
            lambda: _yoneticiyi_epostayla_bul(_kimlik(eposta)))
        assert sonuc["tur"] == "mevcut_hesap"
        assert sonuc["user_id"] == str(uid)
    finally:
        with owner_conn.cursor() as cur:
            cur.execute("DELETE FROM app_user WHERE id=%s", (uid,))
        owner_conn.commit()


def test_DOGRULANMAMIS_eposta_hicbir_sey_dondurmez(client, iki_tesiste_yonetici):
    """Guvenlik sarti: dogrulanmamis adresle mevcut hesaba baglanmak
    HESAP ELE GECIRMEDIR (P180 D5) — cok tesiste de gecerli."""
    from app.routers.oauth import _yoneticiyi_epostayla_bul

    eposta, _, _ = iki_tesiste_yonetici
    sonuc = _kendi_dongusunde(
        lambda: _yoneticiyi_epostayla_bul(_kimlik(eposta, dogrulanmis=False)))
    assert sonuc is None


# ==================== 2) UC: SECIM -> OTURUM ============================== #

def _secim_kur(client, redis_client, eposta, adaylar, saglayici="google"):
    """`/auth/oauth/sonuc`un yazacagi secim kaydini DOGRUDAN kurar.

    Callback'i suremiyoruz (gercek bir saglayici gerekir); olculen sey
    SECIM UCUNUN davranisi.
    """
    import json

    jeton = uuid.uuid4().hex
    redis_client.set(
        f"oauth:secim:{jeton}",
        json.dumps({
            "adaylar": adaylar,
            "saglayici": saglayici,
            "subject": f"sub-{uuid.uuid4().hex}",
            "eposta": eposta,
        }),
        ex=600,
    )
    return jeton


def test_SECIM_UCU_JETON_URETIR_ve_KIMLIGI_BAGLAR(
    client, redis_client, world, iki_tesiste_yonetici, owner_conn
):
    eposta, a, b = iki_tesiste_yonetici
    adaylar = [
        {"tenant_id": str(world["a"]), "user_id": str(a)},
        {"tenant_id": str(world["b"]), "user_id": str(b)},
    ]
    jeton = _secim_kur(client, redis_client, eposta, adaylar)

    r = client.post("/auth/oauth/tesis-sec", json={
        "secim_jetonu": jeton, "tenant_id": str(world["b"])})
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "giris"
    assert r.json()["jetonlar"]["access_token"]

    # KIMLIK BAGLANDI: bir sonraki giriste secim SORULMAZ.
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT tenant_id FROM oauth_kimlik WHERE user_id=%s", (b,))
        satir = cur.fetchone()
    assert satir is not None and str(satir[0]) == str(world["b"])


def test_LISTEDE_OLMAYAN_TESIS_403(client, redis_client, world,
                                   iki_tesiste_yonetici):
    """Uc "istedigim tesisin jetonunu al" ucuna DONUSEMEZ."""
    eposta, a, _ = iki_tesiste_yonetici
    jeton = _secim_kur(client, redis_client, eposta, [
        {"tenant_id": str(world["a"]), "user_id": str(a)}])
    r = client.post("/auth/oauth/tesis-sec", json={
        "secim_jetonu": jeton, "tenant_id": str(world["b"])})
    assert r.status_code == 403, r.text


def test_SECIM_JETONU_TEK_KULLANIMLIK(client, redis_client, world,
                                      iki_tesiste_yonetici):
    eposta, a, _ = iki_tesiste_yonetici
    jeton = _secim_kur(client, redis_client, eposta, [
        {"tenant_id": str(world["a"]), "user_id": str(a)}])
    ilk = client.post("/auth/oauth/tesis-sec", json={
        "secim_jetonu": jeton, "tenant_id": str(world["a"])})
    assert ilk.status_code == 200, ilk.text
    ikinci = client.post("/auth/oauth/tesis-sec", json={
        "secim_jetonu": jeton, "tenant_id": str(world["a"])})
    assert ikinci.status_code in (400, 401, 403), ikinci.text


def test_GECERSIZ_JETON_REDDEDILIR(client):
    r = client.post("/auth/oauth/tesis-sec", json={
        "secim_jetonu": "olmayan-jeton-12345", "tenant_id": str(uuid.uuid4())})
    assert r.status_code in (400, 401, 403), r.text
