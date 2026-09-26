"""(P248 §2 bulgusu) Acilis bakiyesi BOS birakilinca firma/kasa eklenebilmeli.

Web'in ortak tanim formu bos tutar alanini `null` gonderiyor; alan `int`
oldugu icin `/tanimlar`da bakiye yazilmadan firma/kasa EKLENEMIYORDU (422).
"""
from __future__ import annotations

import uuid


def _h(client, world):
    cred = world["yonetici_a"]
    r = client.post("/auth/login", json={
        "tenant_slug": world["slug_a"], "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_FIRMA_BOS_ACILIS_BAKIYESIYLE_EKLENIR(client, world):
    r = client.post("/firmalar", headers=_h(client, world), json={
        "ad": f"Firma {uuid.uuid4().hex[:6]}", "acilis_bakiye_kurus": None})
    assert r.status_code == 201, r.text
    assert r.json()["acilis_bakiye_kurus"] == 0


def test_KASA_BOS_ACILIS_BAKIYESIYLE_EKLENIR(client, world):
    r = client.post("/kasalar", headers=_h(client, world), json={
        "kod": f"K{uuid.uuid4().hex[:6]}", "ad": "Kasa", "acilis_bakiye_kurus": None})
    assert r.status_code == 201, r.text
    assert r.json()["acilis_bakiye_kurus"] == 0


def test_EKSI_BAKIYE_HALA_REDDEDILIR(client, world):
    r = client.post("/firmalar", headers=_h(client, world), json={
        "ad": "Eksi", "acilis_bakiye_kurus": -5})
    assert r.status_code == 422
