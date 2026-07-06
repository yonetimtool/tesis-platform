"""Push saglayicilari — soyut arayuz + noop + FCM (gercek HTTP v1 + OAuth2).

app/payments.py deseninin AYNISI: soyut PushProvider -> somut NoopPushProvider /
FcmProvider. HTTP + OAuth token cagrilari mock'lanabilir modul-duzeyi yardimcilar
(_http_post_json / _http_post_form / _fetch_token_response) arkasinda.

Kimlik: service account JSON'u ONCE dosyadan (env FCM_SERVICE_ACCOUNT_PATH —
compose read-only mount, onerilen), yoksa inline env'den (FCM_SERVICE_ACCOUNT_JSON)
yuklenir. project_id dosyadan gelir (FCM_PROJECT_ID ile override edilebilir).
Dosya yok/bozuksa "push_unconfigured" (no-op + log; COKME YOK). Dosya ICERIGI
hicbir zaman loglanmaz/yazdirilmaz — yalniz yol loglanir.

OAuth2 (google-auth YOK — bilincli): service account JWT'si PyJWT (RS256,
cryptography backend) ile imzalanir ve token ucuna httpx ile POST edilir.
Gerekce: uc bagimliligin ucu de (PyJWT/cryptography/httpx) zaten requirements'ta
— yeni paket agaci yok; HTTP katmani mevcut mock desenine uygun kalir. Token
expiry'ye 60 sn kala yenilenir (_token_cache).
"""
from __future__ import annotations

import json
import logging
import time
from abc import ABC, abstractmethod
from collections.abc import Mapping, Sequence
from dataclasses import dataclass

import httpx
import jwt

from .config import settings

logger = logging.getLogger("push")

_TOKEN_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
_DEFAULT_TOKEN_URI = "https://oauth2.googleapis.com/token"
_TOKEN_YENILEME_MARJI_S = 60.0


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


def _http_post_form(url: str, data: dict, timeout: float = 20.0) -> dict:
    """OAuth token ucu form-encoded ister; hata durumunda raise (govde loglanmaz)."""
    with httpx.Client(timeout=timeout) as c:
        r = c.post(url, data=data)
        r.raise_for_status()
        return r.json()


def _now() -> float:
    return time.time()


def _load_service_account() -> dict | None:
    """Service account'i yukle: ONCE dosya (path), yoksa inline JSON env.

    Dosya yok/bozuk -> None (unconfigured; COKME YOK). Icerik ASLA loglanmaz.
    Path VERILMIS ama okunamiyorsa inline'a dusulmez — yanlis yapilandirma
    gizlenmesin (log'daki yol ile teshis edilir).
    """
    path = settings.fcm_service_account_path
    if path:
        try:
            with open(path, encoding="utf-8") as f:
                sa = json.load(f)
            if isinstance(sa, dict):
                return sa
            logger.warning("PUSH fcm: service account dosyasi obje degil (%s) -> unconfigured", path)
        except (OSError, ValueError):
            logger.warning("PUSH fcm: service account dosyasi yok/okunamadi/bozuk (%s) -> unconfigured", path)
        return None
    if settings.fcm_service_account_json:
        try:
            sa = json.loads(settings.fcm_service_account_json)
            if isinstance(sa, dict):
                return sa
        except ValueError:
            pass
        logger.warning("PUSH fcm: FCM_SERVICE_ACCOUNT_JSON bozuk -> unconfigured")
        return None
    return None


def _fetch_token_response(sa: dict) -> dict:
    """Service account -> Google OAuth2 token cevabi (mock'lanabilir ham yol).

    JWT (RS256, PyJWT+cryptography) imzalanir, token ucuna jwt-bearer grant'iyla
    POST edilir. Cevap: {"access_token": ..., "expires_in": ...}.
    """
    now = int(_now())
    token_uri = sa.get("token_uri") or _DEFAULT_TOKEN_URI
    assertion = jwt.encode(
        {
            "iss": sa["client_email"],
            "scope": _TOKEN_SCOPE,
            "aud": token_uri,
            "iat": now,
            "exp": now + 3600,
        },
        sa["private_key"],
        algorithm="RS256",
    )
    return _http_post_form(
        token_uri,
        {"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion},
    )


# client_email -> (access_token, yenileme_zamani_epoch)
_token_cache: dict[str, tuple[str, float]] = {}


def _fetch_access_token(sa: dict) -> str:
    """Onbellekli access token — expiry'ye 60 sn kala yeniden alinir."""
    key = str(sa.get("client_email", ""))
    cached = _token_cache.get(key)
    if cached is not None and cached[1] > _now():
        return cached[0]
    resp = _fetch_token_response(sa)
    token = str(resp["access_token"])
    expiry = _now() + float(resp.get("expires_in", 3600)) - _TOKEN_YENILEME_MARJI_S
    _token_cache[key] = (token, expiry)
    return token


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

    def send(self, tokens, *, title, body, data=None) -> PushResult:
        sa = _load_service_account()
        # project_id oncelik: env override > service account dosyasindaki deger.
        project_id = settings.fcm_project_id or (sa or {}).get("project_id") or None
        if sa is None or not project_id:
            logger.warning("PUSH fcm unconfigured (kimlik/proje yok) -> no-op")
            return PushResult(provider="fcm", sent=0, status="push_unconfigured")

        access_token = _fetch_access_token(sa)
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
