"""(P194) MOBILDE YONETICI SSO ILE GIRIS.

===========================================================================
OLCULEN KUSUR
===========================================================================
Web'de kaydolmus bir YONETICI mobilde "Google ile devam" dediginde giris
yapamiyordu. Iki ayri yerde iki ayri sebep vardi:

  1. ISTEMCI (mobil): giris ekrani SSO donusunde bir ROL ACILIR LISTESI
     ciziyor ve listeyi KAYIT ekranindan aliyordu — yonetici mobilden
     kaydolamadigi icin listede YOK. Kullanici mecburen "Sakin" seciyor,
     `_liste_kontrolu` "rol_uyusmuyor" deyip `onay_bekliyor` donuyordu.
     Bu dosya (1)'in SUNUCU tarafini kilitler: rol GONDERILMEDIGINDE
     yonetici de baglanabilmeli.

  2. SUNUCU: `niyet=giris`te kimlik bagli degilse DAIMA `baglama_gerekli`
     donuyordu. Oysa AYNI kimlik `niyet=kayit` ile gelseydi (web kayit
     ekrani) dogrulanmis e-posta TEK bir yonetici hesabiyla eslesir ve
     GIRIS YAPTIRIRDI. Yani kural vardi, giris yolunda uygulanmiyordu.

     OLCULDU (dev API, ayni kimlik):
         niyet=kayit -> 'mevcut_hesap'   ·   niyet=giris -> 'baglama'
"""
from __future__ import annotations

import uuid

import pytest

from .test_p177_kayit_akisi import (  # noqa: F401 — fixture'lar
    EPOSTA_ALANI,
    _sso_jeton,
    akis_acik,
    hazir_tesis,
)


def _kendi_dongusunde(coro_fabrika):
    """(P187 dersi) PAYLASILAN MOTORU KENDI DONGUNDE GUVENLE KULLAN.

    Olculen kusur: bu iki test IZOLASYONDA geciyor, TAM TAKIMDA duyuyordu:

        RuntimeError: ... got Future ... attached to a different loop

    Sebep P187'de Celery tarafinda duzeltilen tuzagin AYNISI: asyncpg
    baglantilari OLUSTURULDUKLARI event loop'a baglidir. Daha once kosan
    bir test `asyncio.run` ile bir dongu acip kapatmis ve `app.db.engine`
    havuzunda O OLU DONGUYE bagli baglantilar birakmistir; bizim yeni
    dongumuz onlardan birini alinca patlar.

    IKI ADIM, IKISI DE GEREKLI:
      * BASTA `dispose(close=False)` — olu donguye bagli havuzu ELLEMEDEN
        birakir. `close=True` olsaydi SQLAlchemy o baglantilari kapatmaya
        calisir ve kapali dongude "Event loop is closed" atardi.
      * SONDA `dispose()` — bizim actigimiz baglantilari, dongu KAPANMADAN
        duzgun kapatir; yoksa ayni tuzagi bir sonraki teste biz kurardik.

    `test_p191ek_cihaz_hijyeni` ayni dersi kendi motorunu kurarak cozer; o
    yol burada YOK, cunku olculen fonksiyon `SessionLocal`i kendi icinde
    kullaniyor ve disaridan oturum almiyor.
    """
    import asyncio

    from app.db import engine

    async def _kos():
        await engine.dispose(close=False)
        try:
            return await coro_fabrika()
        finally:
            await engine.dispose()

    return asyncio.run(_kos())


def _yonetici_ekle(owner_conn, tenant_id) -> str:
    """Web'de kaydolmus bir yonetici: parolasi VAR, SSO kimligi YOK."""
    eposta = f"p194-{uuid.uuid4().hex[:10]}@{EPOSTA_ALANI}"
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, email, role, is_active, "
            "password_set) VALUES (%s, %s, %s, 'yonetici', true, true)",
            (tenant_id, "P194 Yonetici", eposta),
        )
    owner_conn.commit()
    return eposta


# ============ 1) ROL BEYAN EDILMEDIGINDE YONETICI DE BAGLANIR ============= #

def test_YONETICI_rol_GONDERILMEDEN_baglanir_ve_oturum(
    client, owner_conn, hazir_tesis, akis_acik
):
    """Mobil giris ekraninin yeni davranisi: rol GONDERMEZ.

    Rol hesaptan okunur (P191 §1) ve `_TAMAMLA_ROLLERI` yoneticiyi de
    kapsar. `password_set=true` ENGEL DEGILDIR: bu bir kayit degil,
    MEVCUT hesaba SSO yontemi eklemektir.
    """
    if not akis_acik:
        pytest.skip("bayrak KAPALI")
    eposta = _yonetici_ekle(owner_conn, hazir_tesis["tenant_id"])
    r = client.post(
        "/auth/oauth/rol-tamamla",
        json={
            "baglama_jetonu": _sso_jeton(eposta, email_verified=True),
            "tesis_kodu": hazir_tesis["tesis_kodu"],
            # `rol` YOK — giris rol SORMAZ.
        },
    )
    assert r.status_code == 200, r.text
    govde = r.json()
    assert govde["durum"] == "giris", govde
    assert govde["jetonlar"]["access_token"]


def test_ROL_BEYANI_YONETICIYI_REDDEDER_kusurun_kendisi(
    client, owner_conn, hazir_tesis, akis_acik
):
    """KUSURUN OLCUMU: mobil "Sakin" beyan edince ne oluyordu.

    Bu testin yesil kalmasi, istemcinin rol beyan etmemesinin NEDEN
    gerekli oldugunu belgeler: sunucu HAKLI olarak reddediyor — rolu
    yanlis beyan eden bir istek kabul edilseydi asil kusur o olurdu.
    """
    if not akis_acik:
        pytest.skip("bayrak KAPALI")
    eposta = _yonetici_ekle(owner_conn, hazir_tesis["tenant_id"])
    r = client.post(
        "/auth/oauth/rol-tamamla",
        json={
            "baglama_jetonu": _sso_jeton(eposta, email_verified=True),
            "tesis_kodu": hazir_tesis["tesis_kodu"],
            "rol": "resident",  # mobilin ESKI davranisi
        },
    )
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "onay_bekliyor"
    assert r.json().get("jetonlar") is None


# ====== 2) GIRIS NIYETINDE E-POSTA ESLESMESI (Tesis ID sorulmadan) ======= #

def test_GIRISTE_dogrulanmis_eposta_TEK_yoneticiyle_eslesirse_GIRIS(
    client, owner_conn, hazir_tesis
):
    """`niyet=giris` + bagli olmayan kimlik + DOGRULANMIS e-posta.

    Web'le SIMETRI: ayni kimlik kayit niyetinde `mevcut_hesap` donup giris
    yaptiriyordu. Artik giris niyetinde de yapiyor ve kullaniciya Tesis ID
    SORULMUYOR — hangi tesis oldugu zaten biliniyor.
    """
    from app.oauth import Kimlik
    from app.routers.oauth import _yoneticiyi_epostayla_bul

    eposta = _yonetici_ekle(owner_conn, hazir_tesis["tenant_id"])
    kimlik = Kimlik(
        saglayici="google", subject=f"sub-{uuid.uuid4().hex}",
        eposta=eposta, email_verified=True, ad="P194", relay=False,
    )
    sonuc = _kendi_dongusunde(lambda: _yoneticiyi_epostayla_bul(kimlik))
    assert sonuc is not None, "dogrulanmis e-posta yoneticiyle eslesmedi"
    assert sonuc["tur"] == "mevcut_hesap"
    assert str(sonuc["tenant_id"]) == str(hazir_tesis["tenant_id"])


def test_DOGRULANMAMIS_eposta_ESLESMEZ_guvenlik_kapisi(
    client, owner_conn, hazir_tesis
):
    """Dogrulanmamis bir adresle mevcut hesaba baglanmak HESAP ELE
    GECIRMEDIR (P180 dersi). Kapi giris yolunda da AYNEN durur."""
    from app.oauth import Kimlik
    from app.routers.oauth import _yoneticiyi_epostayla_bul

    eposta = _yonetici_ekle(owner_conn, hazir_tesis["tenant_id"])
    kimlik = Kimlik(
        saglayici="google", subject=f"sub-{uuid.uuid4().hex}",
        eposta=eposta, email_verified=False, ad="P194", relay=False,
    )
    sonuc = _kendi_dongusunde(lambda: _yoneticiyi_epostayla_bul(kimlik))
    assert sonuc is None, "dogrulanmamis e-posta ESLESMEMELI"
