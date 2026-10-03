"""(P253 §C) Finans islemleri kurali — sunucu tarafi kilitler.

  * §C-2: red ve iptalde (ters kayit) SEBEP ZORUNLU; bos/bosluk/kisa
    sebep 422 `sebep_zorunlu`. Web ve mobil AYNI uca gider, ayni kural.
  * §C-5: her denetim satirinda `meta.yuzey` — `X-Istemci-Yuzey`
    basligindan (web/mobil); basliksiz istek `bilinmiyor`, gecersiz deger
    de `bilinmiyor` (uydurulmaz).
"""
from __future__ import annotations

import uuid

import pytest

from app.hata_metinleri import METINLER


def _h(client, slug, cred, yuzey=None):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    h = {"Authorization": f"Bearer {r.json()['access_token']}"}
    if yuzey is not None:
        h["X-Istemci-Yuzey"] = yuzey
    return h


@pytest.fixture
def kasa(client, world):
    adm = _h(client, world["slug_a"], world["admin_a"])
    r = client.post("/kasalar", headers=adm, json={
        "kod": f"KC{uuid.uuid4().hex[:6]}", "ad": "P253 Kasa", "acilis_bakiye_kurus": 500000})
    assert r.status_code == 201, r.text
    return r.json()["id"]


def _gider(client, h, kasa_id, durum="onay_bekliyor"):
    r = client.post("/finans/hareketler", headers=h, json={"satirlar": [
        {"tip": "gider", "tutar_kurus": 12345, "kasa_id": kasa_id, "durum": durum}]})
    assert r.status_code == 201, r.text
    return r.json()["items"][0]["id"]


def _denetim(owner_conn, hid, eylem):
    satir = owner_conn.execute(
        "SELECT meta FROM audit_log WHERE resource_id = %s AND action = %s "
        "ORDER BY ts DESC LIMIT 1", (hid, eylem),
    ).fetchone()
    assert satir is not None, f"{eylem} denetimi yok"
    return satir[0]


@pytest.mark.parametrize("govde", [{}, {"aciklama": ""}, {"aciklama": "   "}, {"aciklama": "ab"}])
def test_RED_sebepsiz_GECMEZ(client, world, kasa, govde):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    hid = _gider(client, h, kasa)
    r = client.post(f"/finans/hareketler/{hid}/reddet", headers=h, json=govde)
    assert r.status_code == 422, r.text
    assert r.json()["error"]["message"] == METINLER["sebep_zorunlu"]["tr"]
    # Kayit DOKUNULMADAN durur.
    bekleyen = client.get("/finans/hareketler", headers=h, params={"limit": 200}).json()["items"]
    assert next(x for x in bekleyen if x["id"] == hid)["durum"] == "onay_bekliyor"


@pytest.mark.parametrize("govde", [{}, {"aciklama": "  "}])
def test_IPTAL_sebepsiz_GECMEZ(client, world, kasa, govde):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    hid = _gider(client, h, kasa, durum="odendi")
    r = client.post(f"/finans/hareketler/{hid}/iptal", headers=h, json=govde)
    assert r.status_code == 422, r.text
    assert r.json()["error"]["message"] == METINLER["sebep_zorunlu"]["tr"]


@pytest.mark.parametrize(
    ("baslik", "beklenen"),
    [("mobil", "mobil"), ("web", "web"), (None, "bilinmiyor"), ("baska", "bilinmiyor")],
)
def test_DENETIMDE_YUZEY(client, world, owner_conn, kasa, baslik, beklenen):
    h = _h(client, world["slug_a"], world["yonetici_a"], yuzey=baslik)
    hid = _gider(client, h, kasa)
    r = client.post(f"/finans/hareketler/{hid}/reddet", headers=h,
                    json={"aciklama": "Fatura eksik"})
    assert r.status_code == 200, r.text
    meta = _denetim(owner_conn, hid, "finans_hareket_red")
    assert meta["yuzey"] == beklenen
    assert meta["sebep"] == "Fatura eksik"


def test_IPTAL_sebep_ve_yuzey_denetimde(client, world, owner_conn, kasa):
    h = _h(client, world["slug_a"], world["yonetici_a"], yuzey="mobil")
    hid = _gider(client, h, kasa, durum="odendi")
    r = client.post(f"/finans/hareketler/{hid}/iptal", headers=h,
                    json={"aciklama": "Yanlis kasaya girildi"})
    assert r.status_code == 201, r.text
    meta = owner_conn.execute(
        "SELECT meta FROM audit_log WHERE meta->>'iptal_edilen' = %s", (hid,),
    ).fetchone()[0]
    assert meta["yuzey"] == "mobil" and meta["sebep"] == "Yanlis kasaya girildi"


@pytest.mark.parametrize("govde", [{}, {"aciklama": " "}])
def test_TAHAKKUK_TERS_KAYDI_sebepsiz_GECMEZ(client, world, govde):
    """(P253 A2) Borclandirma ters kaydinda da §C-2 sebep zorunlu."""
    h = _h(client, world["slug_a"], world["yonetici_a"])
    unit = client.post("/units", headers=h, json={"no": f"TK-{uuid.uuid4().hex[:5]}", "blok": "A"})
    assert unit.status_code == 201, unit.text
    t = client.post("/dues/assessments", headers=h, json={
        "unit_id": unit.json()["id"], "donem": "2026-09", "tutar_kurus": 50000})
    assert t.status_code == 201, t.text
    tid = t.json()["created"][0]["id"]
    r = client.post(f"/dues/assessments/{tid}/ters-kayit", headers=h, json=govde)
    assert r.status_code == 422, r.text
    assert r.json()["error"]["message"] == METINLER["sebep_zorunlu"]["tr"]
    ok = client.post(f"/dues/assessments/{tid}/ters-kayit", headers=h,
                     json={"aciklama": "Yanlis daireye yazildi"})
    assert ok.status_code == 201, ok.text
