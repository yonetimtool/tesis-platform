"""Soyut odeme arayuzu (PaymentProvider).

BU TURDA gercek tahsilat YOK. Manuel (elden/havale) odeme admin tarafindan
kaydedilir; para hareketi YAPILMAZ. Gercek iyzico/PayTR entegrasyonu SONRAKI
prompt — arayuz burada sabitlenir, kart vb. icin somut provider eklenecek.
"""
from __future__ import annotations

import uuid
from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass
class PaymentInit:
    provider_ref: str
    redirect_url: str | None = None


class PaymentProvider(ABC):
    """Odeme saglayici soyut arayuzu."""

    name: str

    @abstractmethod
    def init_payment(
        self, *, tutar_kurus: int, unit_id: uuid.UUID | str, idempotency_key: str
    ) -> PaymentInit:
        """Odemeyi baslat; provider referansi (+gerekiyorsa redirect) doner."""

    @abstractmethod
    def verify(self, provider_ref: str) -> bool:
        """Odemenin gerceklestigini dogrula (basarili mi?)."""


class ManualPaymentProvider(PaymentProvider):
    """Elden/havale: gercek tahsilat yok. init no-op, verify her zaman True
    (admin fiilen tahsil ettigini beyan eder)."""

    name = "manual"

    def init_payment(
        self, *, tutar_kurus: int, unit_id: uuid.UUID | str, idempotency_key: str
    ) -> PaymentInit:
        return PaymentInit(provider_ref=f"manual:{idempotency_key}", redirect_url=None)

    def verify(self, provider_ref: str) -> bool:
        return True


def get_payment_provider(yontem: str | None = None) -> PaymentProvider:
    """Yonteme gore provider sec. Simdilik hepsi manuel (soyut kanca).

    Sonraki prompt: yontem=='kart' -> iyzico/PayTR somut provider.
    """
    return ManualPaymentProvider()
