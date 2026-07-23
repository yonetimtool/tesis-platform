"""Gercek odeme saglayici iskeleti: provider secimi + init (mock HTTP) + webhook guvenligi.

In-process testler (provider mantigi/imza) + canli API testleri (webhook uctan uca).
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import uuid
from urllib.parse import urlencode

import pytest

from app import payments
from app.config import settings
from app.errors import APIError
from app.payments import (
    IyzicoProvider,
    ManualPaymentProvider,
    PaytrProvider,
    get_payment_provider,
)


def _hmac_b64(key: str, msg: str) -> str:
    return base64.b64encode(hmac.new(key.encode(), msg.encode(), hashlib.sha256).digest()).decode()


# ----------------------- provider secimi (in-process) ---------------------- #
def test_provider_selection_by_env(monkeypatch):
    monkeypatch.setattr(settings, "payment_provider", "manual")
    assert isinstance(get_payment_provider(), ManualPaymentProvider)
    monkeypatch.setattr(settings, "payment_provider", "iyzico")
    assert isinstance(get_payment_provider(), IyzicoProvider)
    monkeypatch.setattr(settings, "payment_provider", "paytr")
    assert isinstance(get_payment_provider(), PaytrProvider)
    monkeypatch.setattr(settings, "payment_provider", "bilinmeyen")
    assert isinstance(get_payment_provider(), ManualPaymentProvider)  # guvenli varsayilan


# ----------------------- init_payment (mock HTTP) -------------------------- #
def test_iyzico_init_builds_signed_request(monkeypatch):
    captured = {}

    def fake_json(url, headers, body, timeout=20.0):
        captured.update(url=url, headers=headers, body=body)
        return {"status": "success", "token": "TKN", "paymentPageUrl": "https://iyz/pay/abc"}

    monkeypatch.setattr(payments, "_http_post_json", fake_json)
    init = IyzicoProvider().init_payment(tutar_kurus=75000, unit_id="u1", idempotency_key="key-123")

    assert init.durum == "bekliyor"
    assert init.redirect_url == "https://iyz/pay/abc"
    assert init.provider_ref == "key123"  # _oid: alnum
    assert "/payment/iyzipos/checkoutform/initialize" in captured["url"]
    assert captured["headers"]["Authorization"].startswith("IYZWS ")
    assert captured["headers"]["x-iyzi-rnd"]
    assert captured["body"]["price"] == "750.00" and captured["body"]["currency"] == "TRY"


def test_paytr_init_builds_signed_request(monkeypatch):
    captured = {}

    def fake_form(url, data, timeout=20.0):
        captured.update(url=url, data=data)
        return {"status": "success", "token": "PTKN"}

    monkeypatch.setattr(payments, "_http_post_form", fake_form)
    init = PaytrProvider().init_payment(tutar_kurus=50000, unit_id="u1", idempotency_key="oid-9")

    assert init.durum == "bekliyor"
    assert init.redirect_url.endswith("/odeme/guvenli/PTKN")
    assert init.provider_ref == "oid9"
    assert "get-token" in captured["url"]
    assert captured["data"]["payment_amount"] == "50000"
    assert "paytr_token" in captured["data"] and captured["data"]["merchant_oid"] == "oid9"


def test_missing_keys_raises(monkeypatch):
    monkeypatch.setattr(settings, "iyzico_api_key", "")
    with pytest.raises(APIError) as e:
        IyzicoProvider().init_payment(tutar_kurus=1, unit_id="u", idempotency_key="k")
    assert e.value.status_code == 503


# ----------------------- webhook imza (in-process) ------------------------- #
def test_paytr_webhook_signature(monkeypatch):
    oid, status, amount = "ORDER1", "success", "50000"
    h = _hmac_b64(settings.paytr_merchant_key, f"{oid}{settings.paytr_merchant_salt}{status}{amount}")
    body = urlencode({"merchant_oid": oid, "status": status, "total_amount": amount, "hash": h}).encode()
    ev = PaytrProvider().parse_and_verify_webhook(body, {})
    assert ev.durum == "basarili" and ev.tutar_kurus == 50000 and ev.provider_ref == oid

    # bozulmus hash -> reddedilir
    bad = urlencode({"merchant_oid": oid, "status": status, "total_amount": amount, "hash": "XXX"}).encode()
    with pytest.raises(APIError) as e:
        PaytrProvider().parse_and_verify_webhook(bad, {})
    assert e.value.status_code == 401


def test_iyzico_webhook_signature():
    conv, eid, status, price = "CONV1", "EV1", "SUCCESS", "750.00"
    sig = _hmac_b64(settings.iyzico_secret, f"{eid}{conv}{status}{price}")
    body = json.dumps({"conversationId": conv, "eventId": eid, "status": status, "price": price}).encode()
    ev = IyzicoProvider().parse_and_verify_webhook(body, {"x-iyz-signature": sig})
    assert ev.durum == "basarili" and ev.tutar_kurus == 75000 and ev.provider_ref == conv
    with pytest.raises(APIError):
        IyzicoProvider().parse_and_verify_webhook(body, {"x-iyz-signature": "bad"})


# --------------------- webhook uctan uca (canli API) ----------------------- #
def _headers(client, slug, cred):
    r = client.post("/auth/login", json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _seed_pending(owner_conn, client, world, cred, ref, tutar=50000):
    """Bir unit + 'bekliyor' paytr odeme (provider_ref=ref) olusturur; (unit_id) doner."""
    admin = _headers(client, world["slug_a"] if cred is world["admin_a"] else world["slug_b"], cred)
    admin_id = client.get("/me", headers=admin).json()["id"]
    u = client.post("/units", headers=admin, json={"no": f"P-{uuid.uuid4().hex[:6]}", "blok": "A"}).json()
    tenant_id = world["a"] if cred is world["admin_a"] else world["b"]
    owner_conn.execute(
        "INSERT INTO dues_payment (tenant_id, unit_id, tutar_kurus, yontem, durum, provider, provider_ref, kaydeden_user_id, idempotency_key) "
        "VALUES (%s,%s,%s,'kart'::dues_yontem,'bekliyor'::dues_durum,'paytr',%s,%s,%s)",
        (tenant_id, u["id"], tutar, ref, admin_id, uuid.uuid4().hex),
    )
    return u["id"], admin


def _paytr_form(ref, status, amount):
    h = _hmac_b64(settings.paytr_merchant_key, f"{ref}{settings.paytr_merchant_salt}{status}{amount}")
    return {"merchant_oid": ref, "status": status, "total_amount": str(amount), "hash": h}


def _durum(owner_conn, ref):
    return owner_conn.execute(
        "SELECT durum FROM dues_payment WHERE provider='paytr' AND provider_ref=%s", (ref,)
    ).fetchone()[0]


def test_webhook_valid_marks_paid_and_balance(client, world, owner_conn):
    ref = f"OID-{uuid.uuid4().hex[:10]}"
    unit_id, admin = _seed_pending(owner_conn, client, world, world["admin_a"], ref, tutar=50000)
    # tahakkuk 50000 -> bekleyen odeme bakiyeyi henuz dusurmez
    client.post("/dues/assessments", headers=admin, json={"unit_id": unit_id, "donem": "2027-05", "tutar_kurus": 50000})
    assert client.get(f"/units/{unit_id}/dues", headers=admin).json()["bakiye_kurus"] == 50000

    r = client.post("/webhooks/payments/paytr", data=_paytr_form(ref, "success", 50000))
    assert r.status_code == 200 and r.json()["durum"] == "basarili"
    assert _durum(owner_conn, ref) == "basarili"
    # basarili odeme bakiyeye yansir
    assert client.get(f"/units/{unit_id}/dues", headers=admin).json()["bakiye_kurus"] == 0


def test_webhook_invalid_signature_rejected(client, world, owner_conn):
    ref = f"OID-{uuid.uuid4().hex[:10]}"
    _seed_pending(owner_conn, client, world, world["admin_a"], ref)
    form = _paytr_form(ref, "success", 50000)
    form["hash"] = "TAMPERED"
    r = client.post("/webhooks/payments/paytr", data=form)
    assert r.status_code == 401
    assert _durum(owner_conn, ref) == "bekliyor"  # degismedi


def test_webhook_idempotent(client, world, owner_conn):
    ref = f"OID-{uuid.uuid4().hex[:10]}"
    _seed_pending(owner_conn, client, world, world["admin_a"], ref)
    form = _paytr_form(ref, "success", 50000)
    assert client.post("/webhooks/payments/paytr", data=form).status_code == 200
    second = client.post("/webhooks/payments/paytr", data=form)
    assert second.status_code == 200 and second.json()["status"] == "already_processed"
    assert _durum(owner_conn, ref) == "basarili"


def test_webhook_amount_mismatch_rejected(client, world, owner_conn):
    ref = f"OID-{uuid.uuid4().hex[:10]}"
    _seed_pending(owner_conn, client, world, world["admin_a"], ref, tutar=50000)
    r = client.post("/webhooks/payments/paytr", data=_paytr_form(ref, "success", 99999))
    assert r.status_code == 400 and r.json()["error"]["code"] == "amount_mismatch"
    assert _durum(owner_conn, ref) == "bekliyor"  # manipulasyon engellendi


def test_webhook_unknown_ref_404(client, world):
    r = client.post("/webhooks/payments/paytr", data=_paytr_form("YOK-REF", "success", 1))
    assert r.status_code == 404


def test_webhook_tenant_isolation(client, world, owner_conn):
    ref_a = f"OID-{uuid.uuid4().hex[:10]}"
    ref_b = f"OID-{uuid.uuid4().hex[:10]}"
    _seed_pending(owner_conn, client, world, world["admin_a"], ref_a)
    _seed_pending(owner_conn, client, world, world["admin_b"], ref_b)
    # A'nin webhook'u yalniz A'nin odemesini etkiler
    assert client.post("/webhooks/payments/paytr", data=_paytr_form(ref_a, "success", 50000)).status_code == 200
    assert _durum(owner_conn, ref_a) == "basarili"
    assert _durum(owner_conn, ref_b) == "bekliyor"  # B etkilenmedi
