"""(P205 §1) SSO ILE GIREN COK TESISLI YONETICI HANGI TESISE DUSUYOR?

===========================================================================
SORU BIR OLCUM SORUSUYDU, TAHMIN DEGIL
===========================================================================
Parola yolunda kimlik E-POSTADIR ve e-posta tesis icinde benzersizdir —
ayni e-posta N tesiste N satir demektir, bu yuzden parola girisi 409 verip
SECIM sorar. SSO yolu BASKA bir anahtar kullanir:

    uq_oauth_kimlik_subject   UNIQUE (saglayici, subject)   <-- GLOBAL

Yani bir Google hesabi PLATFORM GENELINDE tek bir kullaniciya baglanir.
Bunun iki sonucu var ve ikisi de burada OLCULUYOR:

  1. SSO girisi DAIMA baglantinin kuruldugu tesise duser. "Rastgele/yanlis
     tesis" DIYE BIR SEY YOK — belirsizlik yok, cunku eslesme tektir.
  2. Ayni Google hesabi IKINCI tesisteki hesaba BAGLANAMAZ (benzersiz
     indeks reddeder). Yani SSO'yla giren cok tesisli yonetici, oteki
     tesisine SSO ILE ULASAMAZ.

(2) bir cikmaz DEGIL: giristen sonra `/me/tesislerim` + `/me/tesis-degistir`
(P203 §2) o kisiyi oteki tesise gecirir — PAROLA SORMADAN. Son test bunu
ucdan uca surer. Karar `docs/P205-kararlar.md` K1.7'de.
"""
from __future__ import annotations

import uuid

import psycopg
import pytest

from .test_p203_coklu_tesis import _giris, cift_uyelik  # noqa: F401
from .test_p194_mobil_yonetici_sso import _kendi_dongusunde


def _oauth_bagla(owner_conn, tenant_id, eposta, subject):
    """Kisinin O TESISTEKI satirina bir Google kimligi baglar."""
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND email=%s",
            (tenant_id, eposta),
        )
        user_id = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO oauth_kimlik (tenant_id, user_id, saglayici, subject, "
            "eposta) VALUES (%s, %s, 'google', %s, %s)",
            (tenant_id, user_id, subject, eposta),
        )
    owner_conn.commit()
    return user_id


def test_SSO_girisi_BAGLANTININ_kuruldugu_tesise_duser(
    client, world, cift_uyelik, owner_conn
):
    """A'ya bagli kimlik A'ya duser — B'ye DEGIL."""
    eposta, _ = cift_uyelik
    subject = f"p205-{uuid.uuid4().hex}"
    user_id = _oauth_bagla(owner_conn, world["a"], eposta, subject)

    from app.routers.oauth import Kimlik, _kimligi_coz

    sonuc = _kendi_dongusunde(
        lambda: _kimligi_coz(
            Kimlik(saglayici="google", subject=subject, eposta=eposta,
                   email_verified=True, ad="P205 SSO")
        )
    )
    assert sonuc["tur"] == "giris", sonuc
    assert str(sonuc["tenant_id"]) == str(world["a"]), (
        "SSO girisi BASKA bir tesise dustu"
    )
    assert str(sonuc["user_id"]) == str(user_id)


def test_AYNI_GOOGLE_HESABI_IKINCI_tesise_BAGLANAMAZ(
    client, world, cift_uyelik, owner_conn
):
    """Kisitin KENDISI olculuyor: bilinen SINIR, sessiz bir varsayim degil."""
    eposta, _ = cift_uyelik
    subject = f"p205-{uuid.uuid4().hex}"
    _oauth_bagla(owner_conn, world["a"], eposta, subject)
    with pytest.raises(psycopg.errors.UniqueViolation):
        _oauth_bagla(owner_conn, world["b"], eposta, subject)
    owner_conn.rollback()


def test_SSO_ile_girenin_OTEKI_tesise_GECISI_calisir(
    client, world, cift_uyelik, owner_conn
):
    """CIKMAZ YOK: SSO A'ya dusurur, uygulama ici gecis B'ye tasir.

    Olculen sey UCTAN UCA: A jetonu -> `/me/tesislerim` -> `/me/tesis-
    degistir` -> B jetonuyla B verisi. Gecisin PAROLA SORMAMASI bilincli
    (bkz. `me.py` COKLU TESIS basligi).
    """
    eposta, parola = cift_uyelik
    subject = f"p205-{uuid.uuid4().hex}"
    _oauth_bagla(owner_conn, world["a"], eposta, subject)

    # SSO oturumunun DENGI: kimlik A'ya cozuldugu icin A jetonu.
    h = _giris(client, world["slug_a"], {"email": eposta, "password": parola})

    r = client.get("/me/tesislerim", headers=h)
    assert r.status_code == 200, r.text
    hedef = next(t for t in r.json()["tesisler"] if t["slug"] == world["slug_b"])
    # HER TESISTE KENDI ROLU: A'da yonetici, B'de sakin.
    assert hedef["rol"] == "resident"

    r = client.post("/me/tesis-degistir", json={"tenant_id": hedef["tenant_id"]},
                    headers=h)
    assert r.status_code == 200, r.text
    yeni = {"Authorization": f"Bearer {r.json()['access_token']}"}

    # YENI JETON GERCEKTEN B'YI TASIYOR (izolasyon: tek tenant).
    r = client.get("/me", headers=yeni)
    assert r.status_code == 200, r.text
    assert str(r.json()["tenant_id"]) == str(world["b"])
