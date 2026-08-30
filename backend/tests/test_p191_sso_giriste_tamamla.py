"""(P191 §1) SSO ile GIRISTE TESIS ID ILE TAMAMLAMA — `rol` OPSIYONEL.

===========================================================================
OLCULEN KUSUR
===========================================================================
Yonetici panelden bir kullanici olusturdu ve kisi tesis kodlu davet
e-postasini aldi. Kisi Google ile giris yaptiginda "Bu hesap henuz bir
tesise bagli degil" gorup KAYIT cikmazina dusuyordu — oysa hesabi VAR.

Iki neden vardi:
  1. Giris akisinda `sonuc` yalniz `baglama_gerekli` donuyor, web arayuzu
     de kullaniciyi `/kayit`a atiyordu (bkz. web tarafi).
  2. `rol-tamamla` (P184) ROL BEYANI ZORUNLU kiliyordu: davet edilen kisi
     kendi rolunu bilmek zorunda degil ve `password_set=true` hesap
     "hesap_kullanimda" ile reddediliyordu.

Bu dosya (2)'yi olcer: `rol` GONDERILMEDIGINDE rol HESAPTAN okunur,
parolasi belirlenmis hesap da baglanir (mevcut hesaba SSO YONTEMI
eklemek — kayit degil), ama TESIS ID ve E-POSTA SAHIPLIGI sartlari
AYNEN durur.
"""
from __future__ import annotations

import uuid

import pytest

from .test_p177_kayit_akisi import (  # noqa: F401 — fixture'lar
    EPOSTA_ALANI,
    KOD,
    _kodu_ayarla,
    _sso_jeton,
    akis_acik,
    hazir_tesis,
)


def _kullanici_ekle(owner_conn, tenant_id, *, rol: str, password_set: bool) -> str:
    eposta = f"p191-{uuid.uuid4().hex[:10]}@{EPOSTA_ALANI}"
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, email, role, is_active, "
            "password_set) VALUES (%s, %s, %s, %s, true, %s)",
            (tenant_id, "P191 Davetli", eposta, rol, password_set),
        )
    owner_conn.commit()
    return eposta


def test_rol_GONDERILMEDEN_baglanir_ve_oturum_acar(client, owner_conn, hazir_tesis):
    """Davet edilen kisi ROL SORULMADAN girer — rol hesaptan okunur."""
    sakin = hazir_tesis["sakin"]
    subject = f"sub-{uuid.uuid4().hex}"
    r = client.post(
        "/auth/oauth/rol-tamamla",
        json={
            "baglama_jetonu": _sso_jeton(sakin, email_verified=True, subject=subject),
            "tesis_kodu": hazir_tesis["tesis_kodu"],
            # `rol` YOK.
        },
    )
    assert r.status_code == 200, r.text
    govde = r.json()
    assert govde["durum"] == "giris", govde
    assert govde["jetonlar"]["access_token"], govde
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM oauth_kimlik WHERE saglayici='google' AND subject=%s",
            (subject,),
        )
        assert cur.fetchone()[0] == 1


@pytest.mark.parametrize("rol", ["resident", "security", "tesis_gorevlisi", "yonetici", "denetci"])
def test_HER_TESIS_ROLU_rolsuz_tamamlayabilir(client, owner_conn, hazir_tesis, rol):
    """Rol hesaptan okundugu icin BEYAN-UYUSMAZLIGI diye bir sey kalmaz."""
    eposta = _kullanici_ekle(
        owner_conn, hazir_tesis["tenant_id"], rol=rol, password_set=False
    )
    r = client.post(
        "/auth/oauth/rol-tamamla",
        json={
            "baglama_jetonu": _sso_jeton(eposta, email_verified=True),
            "tesis_kodu": hazir_tesis["tesis_kodu"],
        },
    )
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "giris", r.json()


def test_PAROLASI_BELIRLENMIS_hesap_da_baglanir(client, owner_conn, hazir_tesis):
    """(P191) `password_set=true` ENGEL DEGIL — bu bir kayit degil, mevcut
    hesaba SSO yontemi eklemektir. Kanit sinifi e-posta koduyla ayni.

    ROL BEYANLI (kayit) yolda ESKI kural aynen durur: bkz. asagidaki test.
    """
    eposta = _kullanici_ekle(
        owner_conn, hazir_tesis["tenant_id"], rol="resident", password_set=True
    )
    r = client.post(
        "/auth/oauth/rol-tamamla",
        json={
            "baglama_jetonu": _sso_jeton(eposta, email_verified=True),
            "tesis_kodu": hazir_tesis["tesis_kodu"],
        },
    )
    assert r.json()["durum"] == "giris", r.json()


def test_ROL_BEYANLI_yolda_ESKI_kural_korunur(client, owner_conn, hazir_tesis):
    """Kayit akisi (mobil) DEGISMEDI: parolasi olan hesap `onay_bekliyor`."""
    eposta = _kullanici_ekle(
        owner_conn, hazir_tesis["tenant_id"], rol="resident", password_set=True
    )
    r = client.post(
        "/auth/oauth/rol-tamamla",
        json={
            "baglama_jetonu": _sso_jeton(eposta, email_verified=True),
            "tesis_kodu": hazir_tesis["tesis_kodu"],
            "rol": "resident",
        },
    )
    assert r.json()["durum"] == "onay_bekliyor", r.json()


def test_TESIS_ID_SARTI_KALKMADI(client, owner_conn, hazir_tesis):
    """(a) Gecersiz Tesis ID -> ayni notr yanit; kimlik BAGLANMAZ."""
    subject = f"sub-{uuid.uuid4().hex}"
    r = client.post(
        "/auth/oauth/rol-tamamla",
        json={
            "baglama_jetonu": _sso_jeton(
                hazir_tesis["sakin"], email_verified=True, subject=subject
            ),
            "tesis_kodu": "YOK-000000",
        },
    )
    assert r.json()["durum"] == "onay_bekliyor", r.json()
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM oauth_kimlik WHERE subject=%s", (subject,)
        )
        assert cur.fetchone()[0] == 0


def test_LISTE_DISI_eposta_yine_ONAY_BEKLIYOR(client, hazir_tesis):
    """(b) Tesiste boyle bir kullanici yoksa hesap ACILMAZ."""
    yabanci = f"p191-yabanci-{uuid.uuid4().hex[:10]}@{EPOSTA_ALANI}"
    r = client.post(
        "/auth/oauth/rol-tamamla",
        json={
            "baglama_jetonu": _sso_jeton(yabanci, email_verified=True),
            "tesis_kodu": hazir_tesis["tesis_kodu"],
        },
    )
    assert r.json()["durum"] == "onay_bekliyor", r.json()


def test_DOGRULANMAMIS_eposta_yine_OTP_ISTER(client, owner_conn, hazir_tesis):
    """(c) `email_verified=false` -> once OTP; rolsuz yolda da AYNI."""
    eposta = _kullanici_ekle(
        owner_conn, hazir_tesis["tenant_id"], rol="resident", password_set=False
    )
    jeton = _sso_jeton(eposta, email_verified=False)
    govde = {"baglama_jetonu": jeton, "tesis_kodu": hazir_tesis["tesis_kodu"]}
    r = client.post("/auth/oauth/rol-tamamla", json=govde)
    assert r.json()["durum"] == "otp_gerekli", r.json()

    _kodu_ayarla(owner_conn, "kayit_dogrulama", "eposta", eposta)
    r2 = client.post(
        "/auth/oauth/rol-tamamla-dogrula", json={**govde, "kod": KOD}
    )
    assert r2.status_code == 200, r2.text
    assert r2.json()["durum"] == "giris", r2.json()
