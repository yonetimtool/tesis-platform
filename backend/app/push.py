"""Push saglayicilari — soyut arayuz + noop + FCM (somut iskelet).

app/payments.py deseninin AYNISI: soyut PushProvider -> somut NoopPushProvider /
FcmProvider. HTTP + OAuth token cagrisi mock'lanabilir modul-duzeyi yardimcilar
(_http_post_json / _fetch_access_token) arkasinda.

GERCEK FIREBASE KIMLIGI YOK: FcmProvider gercek FCM HTTP v1 yapisina gore yazildi
(service-account -> OAuth2 access token -> POST /v1/projects/{pid}/messages:send,
message.token/notification.title/body/data). Kimlik (project_id + service account
json) env/config'ten gelir; YOKSA "push_unconfigured" (no-op + log, sessiz cokme
degil — mevcut no-op davranisi korunur).
"""
from __future__ import annotations

import logging
from abc import ABC, abstractmethod
from collections.abc import Mapping, Sequence
from dataclasses import dataclass

import httpx

from .config import settings

logger = logging.getLogger("push")


@dataclass
class PushResult:
    provider: str
    sent: int  # basariyla POST edilen token sayisi
    status: str  # 'sent' | 'noop' | 'push_unconfigured'


# --------------------------------------------------------------------------- #
# Mock'lanabilir HTTP / OAuth yardimcilari (test bunlari monkeypatch eder).
# --------------------------------------------------------------------------- #
def _http_post_json(url: str, headers: dict, body: dict, timeout: float = 20.0) -> dict:
    with httpx.Client(timeout=timeout) as c:
        r = c.post(url, headers=headers, json=body)
        return r.json()


def _fetch_access_token(service_account_json: str) -> str:
    """Service account JSON -> OAuth2 access token (googleapis token exchange).

    Gercekte: JWT imzala (RS256) + https://oauth2.googleapis.com/token degisimi.
    Burada mock'lanabilir tutulur; kimlik varken test bunu monkeypatch eder.
    """
    raise RuntimeError("FCM OAuth token exchange not implemented (mock in tests)")


# --------------------------------------------------------------------------- #
class PushProvider(ABC):
    name: str

    @abstractmethod
    def send(
        self,
        tokens: Sequence[str],
        *,
        title: str,
        body: str,
        data: Mapping[str, str] | None = None,
    ) -> PushResult: ...


# ------------------------------- noop -------------------------------------- #
class NoopPushProvider(PushProvider):
    name = "noop"

    def send(self, tokens, *, title, body, data=None) -> PushResult:
        logger.info("PUSH noop -> %d token (title=%r)", len(list(tokens)), title)
        return PushResult(provider="noop", sent=0, status="noop")


# -------------------------------- fcm -------------------------------------- #
class FcmProvider(PushProvider):
    name = "fcm"

    def _project_id(self) -> str | None:
        """Kimlik tamsa project_id, degilse None (unconfigured)."""
        if not settings.fcm_project_id or not settings.fcm_service_account_json:
            return None
        return settings.fcm_project_id

    def send(self, tokens, *, title, body, data=None) -> PushResult:
        project_id = self._project_id()
        if project_id is None:
            logger.warning("PUSH fcm unconfigured (kimlik yok) -> no-op")
            return PushResult(provider="fcm", sent=0, status="push_unconfigured")

        access_token = _fetch_access_token(settings.fcm_service_account_json)
        url = f"{settings.fcm_base_url}/v1/projects/{project_id}/messages:send"
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        }
        # FCM HTTP v1: her istek TEK token (message.token). data degerleri string olmali.
        str_data = {str(k): str(v) for k, v in (data or {}).items()}
        sent = 0
        for token in tokens:
            message = {
                "message": {
                    "token": token,
                    "notification": {"title": title, "body": body},
                    "data": str_data,
                }
            }
            _http_post_json(url, headers, message)
            sent += 1
        logger.info("PUSH fcm -> %d token gonderildi", sent)
        return PushResult(provider="fcm", sent=sent, status="sent")


_PROVIDERS = {
    "noop": NoopPushProvider,
    "fcm": FcmProvider,
}


def get_push_provider() -> PushProvider:
    """env PUSH_PROVIDER'a gore aktif saglayici (varsayilan noop)."""
    return _PROVIDERS.get(settings.push_provider, NoopPushProvider)()
