"""Anket (P38) — sakinlerin karar araci.

(P154 / Asama 7.2) Bu dosya `test_portal_anket.py`den AYRILDI. Portal
uclari kaldirildi; anket testleri KAYBOLMADI, buraya tasindi. Yalnizca
PUBLIC portal uzerinden anket okuyan test dustu — cunku o yuzey artik
YOK, testin olctugu davranis da yok.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

import pytest

UTC = timezone.utc


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def p(client, world):
    from types import SimpleNamespace
    return SimpleNamespace(
        client=client, slug=world["slug_a"], world=world,
        yonetici=_h(client, world["slug_a"], world["yonetici_a"]),
        admin=_h(client, world["slug_a"], world["admin_a"]),
        sakin=_h(client, world["slug_a"], world["resident_a"]),
        guard=_h(client, world["slug_a"], world["guard_a"]),
    )


# ================================ ANKET ===================================== #
def _anket(p, **over):
    govde = {"baslik": f"Anket {uuid.uuid4().hex[:6]}",
             "secenekler": [{"metin": "Evet", "sira": 0},
                            {"metin": "Hayır", "sira": 1}]}
    govde.update(over)
    return p.client.post("/anketler", headers=p.yonetici, json=govde)


def test_anket_EN_AZ_IKI_secenek(p):
    """Tek secenekli bir anket oy toplamaz, ONAY toplar."""
    r = _anket(p, secenekler=[{"metin": "Tamam"}])
    assert r.status_code == 422, r.text


def test_TEK_OY_ve_DEGISTIRILEMEZ(p):
    """Degistirilebilir oy, kapanis anina kadar sonucun anlamsiz olmasi
    demekti."""
    a = _anket(p).json()
    sec = a["secenekler"]
    r = p.client.post(f"/anketler/{a['id']}/oy", headers=p.sakin,
                      json={"secenek_id": sec[0]["id"]})
    assert r.status_code == 201, r.text
    assert r.json()["oy_verdim"] is True

    ikinci = p.client.post(f"/anketler/{a['id']}/oy", headers=p.sakin,
                           json={"secenek_id": sec[1]["id"]})
    assert ikinci.status_code == 409, ikinci.text
    assert ikinci.json()["error"]["code"] == "conflict"


def test_ACIK_ANKETTE_sonuc_GIZLI_sakine(p):
    """Guncel dagilimi gostermek sonraki oy verenleri ETKILER (surusel
    etki) ve oylamanin kendisini bozardi."""
    a = _anket(p).json()
    p.client.post(f"/anketler/{a['id']}/oy", headers=p.sakin,
                  json={"secenek_id": a["secenekler"][0]["id"]})
    liste = p.client.get("/anketler", headers=p.sakin).json()["items"]
    benim = next(x for x in liste if x["id"] == a["id"])
    assert benim["acik"] is True
    assert benim["toplam_oy"] is None
    assert all(s["oy"] is None for s in benim["secenekler"])
    # Kendi oyunu verdigini BILIR (kendi oyunu gormek baskasininkini
    # gormek degildir).
    assert benim["oy_verdim"] is True


def test_YONETIM_sonucu_HER_ZAMAN_gorur(p):
    """Kararin sahibi yonetimdir."""
    a = _anket(p).json()
    p.client.post(f"/anketler/{a['id']}/oy", headers=p.sakin,
                  json={"secenek_id": a["secenekler"][0]["id"]})
    liste = p.client.get("/anketler", headers=p.yonetici).json()["items"]
    benim = next(x for x in liste if x["id"] == a["id"])
    assert benim["toplam_oy"] == 1
    assert sum(s["oy"] for s in benim["secenekler"]) == 1


def test_KAPANINCA_sonuc_HERKESE_acilir(p):
    a = _anket(p).json()
    p.client.post(f"/anketler/{a['id']}/oy", headers=p.sakin,
                  json={"secenek_id": a["secenekler"][0]["id"]})
    r = p.client.patch(f"/anketler/{a['id']}", headers=p.yonetici,
                       json={"aktif": False})
    assert r.status_code == 200, r.text
    liste = p.client.get("/anketler", headers=p.sakin).json()["items"]
    benim = next(x for x in liste if x["id"] == a["id"])
    assert benim["acik"] is False
    assert benim["toplam_oy"] == 1


def test_KAPANIS_TARIHI_gecince_oy_alinmaz(p):
    gecmis = (datetime.now(UTC) - timedelta(minutes=1)).isoformat()
    a = _anket(p, kapanis_at=gecmis).json()
    assert a["acik"] is False
    r = p.client.post(f"/anketler/{a['id']}/oy", headers=p.sakin,
                      json={"secenek_id": a["secenekler"][0]["id"]})
    assert r.status_code == 409, r.text


def test_BASKA_ANKETIN_secenegi_reddedilir(p):
    a1 = _anket(p).json()
    a2 = _anket(p).json()
    r = p.client.post(f"/anketler/{a1['id']}/oy", headers=p.sakin,
                      json={"secenek_id": a2["secenekler"][0]["id"]})
    assert r.status_code == 422, r.text


def test_OY_yalniz_SAKIN(p):
    """Anket sakinlerin karar aracidir; personelin oyu site kararina
    girmez."""
    a = _anket(p).json()
    sid = a["secenekler"][0]["id"]
    for h in (p.guard, p.yonetici, p.admin):
        r = p.client.post(f"/anketler/{a['id']}/oy", headers=h,
                          json={"secenek_id": sid})
        assert r.status_code == 403, r.status_code
    # Ama HERKES anketi OKUR.
    assert p.client.get("/anketler", headers=p.guard).status_code == 200


def test_SECENEKLER_degistirilemez(p):
    """Oy verilmis bir anketin seceneklerini degistirmek, verilmis oylari
    BASKA BIR SORUYA tasimak olurdu."""
    a = _anket(p).json()
    r = p.client.patch(f"/anketler/{a['id']}", headers=p.yonetici,
                       json={"secenekler": [{"metin": "Yeni"}]})
    assert r.status_code == 422, r.text


def test_tenant_izolasyonu(p, client, world):
    """A tesisinin anketi B'de GORUNMEZ.

    (P154 / Asama 7.2) Testin eski hâli ayni zamanda "A'nin portal yayini
    B'yi acmaz" iddiasini da olcuyordu; o yuzey kaldirildigi icin bu
    parca dustu. ANKET izolasyonu dusmedi — RLS'in isi ve olculmeye
    devam ediyor.
    """
    a = _anket(p).json()
    b = _h(client, world["slug_b"], world["yonetici_b"])
    gorunen = [x["id"] for x in client.get("/anketler", headers=b).json()["items"]]
    assert a["id"] not in gorunen
