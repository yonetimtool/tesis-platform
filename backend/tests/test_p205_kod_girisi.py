"""(P205 §1) KOD ILE GIRIS — her iki kimlikle, slug'siz.

Kabul kriteri 3: "Parola ve kod ile giris, her iki kimlikle de
calisiyor."

TELEFON yolu zaten slug'sizdi (`tenant_id_by_phone`). E-POSTA yolu
tesis kodu ISTIYORDU — P205'te opsiyonel yapildi: slug verilmezse kod,
adresin TUM uyelik tesislerine AYNI degerle yazilir ve dogrulamada
eslesen tesis tek ise giris, cok ise SECIM istenir.
"""
from __future__ import annotations

import pytest


@pytest.fixture(autouse=True)
def _hiz_sinirini_sifirla(redis_client):
    if redis_client is None:
        yield
        return
    for kalip in ("hiz:giris_eposta:*", "hiz:giris:*", "hiz:tesislerim:*"):
        for a in redis_client.scan_iter(kalip):
            redis_client.delete(a)
    yield


def _kodu_oku(owner_conn, tenant_id, eposta):
    """Kod hash'li saklanir; testte BILINEN bir degere cevrilir."""
    from app.security import hash_password

    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE kayit_dogrulama SET kod_hash=%s WHERE tenant_id=%s "
            "AND eposta=%s AND amac='giris' AND durum='telefon_bekliyor'",
            (hash_password("424242"), tenant_id, eposta))
    return "424242"


def test_EPOSTA_KODUYLA_giris_SLUGSIZ(client, world, owner_conn):
    eposta = world["guard_a"]["email"]
    r = client.post("/auth/giris/eposta-kod-iste", json={"eposta": eposta})
    assert r.status_code == 200, r.text
    kod = _kodu_oku(owner_conn, world["a"], eposta)
    r = client.post("/auth/giris/eposta-kod-dogrula",
                    json={"eposta": eposta, "kod": kod})
    assert r.status_code == 200, r.text
    assert "access_token" in r.json()


def test_TELEFON_KODUYLA_giris_DEGISMEDI(client, world, owner_conn):
    """Telefon yolu zaten slug'sizdi; P205 onu KIRMADI."""
    r = client.post("/auth/giris/kod-iste",
                    json={"telefon": world["guard_a"]["phone"]})
    assert r.status_code == 200, r.text


def test_BILINMEYEN_ADRES_de_AYNI_yanit(client):
    """Adres varligini SIZDIRMAZ — kayitli olmayan adres icin de ayni
    yanit."""
    r = client.post("/auth/giris/eposta-kod-iste",
                    json={"eposta": "yok-p205@ornek.com"})
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "onay_bekliyor"


def test_COK_TESISTE_kod_SECIM_ISTER(client, world, owner_conn):
    """Ayni kod iki tesise de yazilir; dogrulamada SECIM istenir —
    parola yolundaki davranisin AYNISI."""
    eposta = world["yonetici_a"]["email"]
    r = client.post("/auth/giris/eposta-kod-iste", json={"eposta": eposta})
    assert r.status_code == 200, r.text
    for tid in (world["a"], world["b"]):
        _kodu_oku(owner_conn, tid, eposta)
    r = client.post("/auth/giris/eposta-kod-dogrula",
                    json={"eposta": eposta, "kod": "424242"})
    assert r.status_code == 409, r.text
    assert r.json()["error"]["code"] == "tesis_secimi_gerekli"
    assert "access_token" not in r.text


def test_SLUG_VERILINCE_o_tesise_girer(client, world, owner_conn):
    eposta = world["yonetici_a"]["email"]
    client.post("/auth/giris/eposta-kod-iste",
                json={"eposta": eposta, "tenant_slug": world["slug_b"]})
    _kodu_oku(owner_conn, world["b"], eposta)
    r = client.post("/auth/giris/eposta-kod-dogrula", json={
        "eposta": eposta, "kod": "424242", "tenant_slug": world["slug_b"]})
    assert r.status_code == 200, r.text


def test_YANLIS_KOD_reddedilir(client, world, owner_conn):
    eposta = world["guard_a"]["email"]
    client.post("/auth/giris/eposta-kod-iste", json={"eposta": eposta})
    _kodu_oku(owner_conn, world["a"], eposta)
    r = client.post("/auth/giris/eposta-kod-dogrula",
                    json={"eposta": eposta, "kod": "000000"})
    assert r.status_code in (401, 422), r.text
    assert "access_token" not in r.text
