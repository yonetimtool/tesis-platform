"""Odeme saglayicilari — soyut arayuz + manual + iyzico + paytr (somut iskelet).

GUVENLIK:
  * Odeme durumu otoriteyi SAGLAYICIDAN/WEBHOOK'tan alir; istemci "odedim" diyemez.
  * Webhook imzasi (HMAC) DOGRULANIR; gecersizse islem yok.
  * Tutarlar KURUS (integer); webhook tutari beklenen odeme ile karsilastirilir.

GERCEK ANAHTAR YOK: iyzico/paytr somut siniflari gercek API yapisina gore yazildi
(endpoint, imza/hash, alanlar) ama HTTP cagrisi mock'lanabilir yardimcilar arkasinda.
Sandbox denemesi anahtarlar gelince yapilacak. Anahtar yoksa init/webhook anlamli
hata (503 payment_unconfigured) verir — sessiz cokme degil.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import re
from abc import ABC, abstractmethod
from collections.abc import Mapping
from dataclasses import dataclass
from decimal import Decimal
from urllib.parse import parse_qs

import httpx

from .config import settings
from .errors import APIError


@dataclass
class PaymentInit:
    provider_ref: str | None  # manuel: None (webhook yok); kart: saglayici referansi
    durum: str  # 'basarili' (manuel anlik) | 'bekliyor' (kart, webhook bekler)
    redirect_url: str | None = None


@dataclass
class WebhookEvent:
    provider_ref: str
    event_id: str
    durum: str  # 'basarili' | 'iptal'
    tutar_kurus: int


# --------------------------------------------------------------------------- #
# Mock'lanabilir HTTP yardimcilari (test bunlari monkeypatch eder).
# --------------------------------------------------------------------------- #
def _http_post_json(url: str, headers: dict, body: dict, timeout: float = 20.0) -> dict:
    with httpx.Client(timeout=timeout) as c:
        r = c.post(url, headers=headers, json=body)
        return r.json()


def _http_post_form(url: str, data: dict, timeout: float = 20.0) -> dict:
    with httpx.Client(timeout=timeout) as c:
        r = c.post(url, data=data)
        return r.json()


def _b64_hmac_sha256(key: str, message: str) -> str:
    return base64.b64encode(
        hmac.new(key.encode(), message.encode(), hashlib.sha256).digest()
    ).decode()


def _oid(idempotency_key: str) -> str:
    """Saglayici referansi (provider_ref) — idempotency_key'ten deterministik alnum."""
    return re.sub(r"[^A-Za-z0-9]", "", idempotency_key)[:64] or "ref"


# --------------------------------------------------------------------------- #
class PaymentProvider(ABC):
    name: str

    @abstractmethod
    def init_payment(self, *, tutar_kurus: int, unit_id, idempotency_key: str) -> PaymentInit: ...

    @abstractmethod
    def verify(self, provider_ref: str) -> bool: ...

    def parse_and_verify_webhook(self, raw: bytes, headers: Mapping[str, str]) -> WebhookEvent:
        raise APIError(400, "webhook_unsupported", f"{self.name} webhook desteklemiyor.")


# ------------------------------- manual ------------------------------------ #
class ManualPaymentProvider(PaymentProvider):
    name = "manual"

    def init_payment(self, *, tutar_kurus: int, unit_id, idempotency_key: str) -> PaymentInit:
        # Elden/havale: gercek tahsilat yok, admin beyani -> anlik basarili.
        # provider_ref None: manuel'in webhook'u yok (global unique'e girmez).
        return PaymentInit(provider_ref=None, durum="basarili")

    def verify(self, provider_ref: str) -> bool:
        return True


# ------------------------------- iyzico ------------------------------------ #
class IyzicoProvider(PaymentProvider):
    name = "iyzico"

    def _require(self) -> tuple[str, str]:
        if not settings.iyzico_api_key or not settings.iyzico_secret:
            raise APIError(503, "payment_unconfigured", "iyzico anahtarlari eksik.")
        return settings.iyzico_api_key, settings.iyzico_secret

    def _auth_header(self, api_key: str, secret: str, rnd: str, body_str: str) -> str:
        # iyzico IYZWS: pkiHash = base64(sha1(apiKey + rnd + secret + requestBody))
        digest = hashlib.sha1(f"{api_key}{rnd}{secret}{body_str}".encode()).digest()
        return f"IYZWS {api_key}:{base64.b64encode(digest).decode()}"

    def init_payment(self, *, tutar_kurus: int, unit_id, idempotency_key: str) -> PaymentInit:
        api_key, secret = self._require()
        conversation_id = _oid(idempotency_key)
        price = f"{Decimal(tutar_kurus) / 100:.2f}"
        body = {
            "locale": "tr",
            "conversationId": conversation_id,
            "price": price,
            "paidPrice": price,
            "currency": "TRY",
            "basketId": str(unit_id),
            "paymentGroup": "SUBSCRIPTION",
            "callbackUrl": f"{settings.iyzico_base_url}/callback",
            "enabledInstallments": [1],
        }
        body_str = json.dumps(body, separators=(",", ":"))
        rnd = conversation_id  # deterministik (test); gercekte rastgele
        headers = {
            "Authorization": self._auth_header(api_key, secret, rnd, body_str),
            "x-iyzi-rnd": rnd,
            "Content-Type": "application/json",
        }
        url = f"{settings.iyzico_base_url}/payment/iyzipos/checkoutform/initialize/auth/ecom"
        resp = _http_post_json(url, headers, body)
        if resp.get("status") != "success":
            raise APIError(502, "payment_provider_error", f"iyzico: {resp.get('errorMessage')}")
        return PaymentInit(
            provider_ref=conversation_id,
            durum="bekliyor",
            redirect_url=resp.get("paymentPageUrl"),
        )

    def verify(self, provider_ref: str) -> bool:
        return False  # otorite webhook'tan

    def parse_and_verify_webhook(self, raw: bytes, headers: Mapping[str, str]) -> WebhookEvent:
        _, secret = self._require()
        data = json.loads(raw or b"{}")
        conversation_id = str(data.get("conversationId", ""))
        event_id = str(data.get("eventId", ""))
        status = str(data.get("status", ""))
        price = str(data.get("price", "0"))
        expected = _b64_hmac_sha256(secret, f"{event_id}{conversation_id}{status}{price}")
        got = headers.get("x-iyz-signature", "")
        if not got or not hmac.compare_digest(expected, got):
            raise APIError(401, "invalid_signature", "iyzico webhook imzasi gecersiz.")
        return WebhookEvent(
            provider_ref=conversation_id,
            event_id=event_id,
            durum="basarili" if status.upper() == "SUCCESS" else "iptal",
            tutar_kurus=int((Decimal(price) * 100).to_integral_value()),
        )


# ------------------------------- paytr ------------------------------------- #
class PaytrProvider(PaymentProvider):
    name = "paytr"

    def _require(self) -> tuple[str, str, str]:
        if not (settings.paytr_merchant_id and settings.paytr_merchant_key and settings.paytr_merchant_salt):
            raise APIError(503, "payment_unconfigured", "paytr anahtarlari eksik.")
        return settings.paytr_merchant_id, settings.paytr_merchant_key, settings.paytr_merchant_salt

    def init_payment(self, *, tutar_kurus: int, unit_id, idempotency_key: str) -> PaymentInit:
        mid, key, salt = self._require()
        merchant_oid = _oid(idempotency_key)
        user_basket = base64.b64encode(
            json.dumps([["Aidat", f"{tutar_kurus}", 1]]).encode()
        ).decode()
        # PayTR token: base64(hmac_sha256(key, merchant_id+user_ip+merchant_oid+email+
        #   payment_amount+user_basket+no_installment+max_installment+currency+test_mode+salt))
        no_installment, max_installment, currency, test_mode, user_ip, email = "0", "0", "TL", "1", "0.0.0.0", "aidat@tesis"
        hash_str = (
            f"{mid}{user_ip}{merchant_oid}{email}{tutar_kurus}{user_basket}"
            f"{no_installment}{max_installment}{currency}{test_mode}{salt}"
        )
        paytr_token = _b64_hmac_sha256(key, hash_str)
        data = {
            "merchant_id": mid,
            "user_ip": user_ip,
            "merchant_oid": merchant_oid,
            "email": email,
            "payment_amount": str(tutar_kurus),
            "user_basket": user_basket,
            "no_installment": no_installment,
            "max_installment": max_installment,
            "currency": currency,
            "test_mode": test_mode,
            "paytr_token": paytr_token,
        }
        resp = _http_post_form(f"{settings.paytr_base_url}/odeme/api/get-token", data)
        if resp.get("status") != "success":
            raise APIError(502, "payment_provider_error", f"paytr: {resp.get('reason')}")
        token = resp.get("token")
        return PaymentInit(
            provider_ref=merchant_oid,
            durum="bekliyor",
            redirect_url=f"{settings.paytr_base_url}/odeme/guvenli/{token}",
        )

    def verify(self, provider_ref: str) -> bool:
        return False

    def parse_and_verify_webhook(self, raw: bytes, headers: Mapping[str, str]) -> WebhookEvent:
        _, key, salt = self._require()
        form = {k: v[0] for k, v in parse_qs(raw.decode()).items()}
        merchant_oid = form.get("merchant_oid", "")
        status = form.get("status", "")
        total_amount = form.get("total_amount", "0")
        got = form.get("hash", "")
        expected = _b64_hmac_sha256(key, f"{merchant_oid}{salt}{status}{total_amount}")
        if not got or not hmac.compare_digest(expected, got):
            raise APIError(401, "invalid_signature", "paytr webhook hash gecersiz.")
        return WebhookEvent(
            provider_ref=merchant_oid,
            event_id=merchant_oid,  # PayTR order basina tek callback
            durum="basarili" if status == "success" else "iptal",
            tutar_kurus=int(total_amount),
        )


_PROVIDERS = {
    "manual": ManualPaymentProvider,
    "iyzico": IyzicoProvider,
    "paytr": PaytrProvider,
}


def get_payment_provider(yontem: str | None = None) -> PaymentProvider:
    """env PAYMENT_PROVIDER'a gore aktif saglayici (varsayilan manual)."""
    return _PROVIDERS.get(settings.payment_provider, ManualPaymentProvider)()


def get_named_provider(name: str) -> PaymentProvider:
    """Webhook icin URL'deki provider adina gore (manual webhook desteklemez)."""
    cls = _PROVIDERS.get(name)
    if cls is None:
        raise APIError(404, "not_found", f"Bilinmeyen saglayici: {name}")
    return cls()
