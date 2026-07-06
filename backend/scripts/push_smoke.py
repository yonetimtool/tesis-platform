"""FCM kimlik DUMAN testi — OAuth2 token alir; PUSH ATMAZ, TOKEN'I YAZDIRMAZ.

Kullanim (kimlik mount'lu container'da):
    docker compose -f docker-compose.yml -f docker-compose.push.yml exec api \
        python -m scripts.push_smoke

Yaptigi tek sey: service account'i yuklemek ve Google token ucundan gercek bir
access token almak (kimligin gecerliligini kanitlar). FCM messages:send'e
istek YAPMAZ — hicbir cihaza push gitmez. Cikti yalniz project_id + expiry;
token ve dosya icerigi ASLA yazdirilmaz.
"""
from __future__ import annotations

import sys
from datetime import datetime, timedelta, timezone

from app import push
from app.config import settings


def main() -> int:
    yol = settings.fcm_service_account_path or "(inline FCM_SERVICE_ACCOUNT_JSON)"
    sa = push._load_service_account()
    if sa is None:
        print(f"HATA: service account yuklenemedi ({yol}). FCM_SERVICE_ACCOUNT_PATH/mount'u kontrol edin.")
        return 1
    project = settings.fcm_project_id or sa.get("project_id") or "?"
    eksik = [a for a in ("client_email", "private_key") if not sa.get(a)]
    if eksik:
        print(f"HATA: service account eksik alan(lar): {', '.join(eksik)}")
        return 1
    try:
        resp = push._fetch_token_response(sa)
    except Exception as exc:  # token/imza/ag hatasi — icerik degil tur+mesaj
        print(f"HATA: OAuth2 token alinamadi: {type(exc).__name__}: {exc}")
        return 1
    if not resp.get("access_token"):
        print(f"HATA: cevapta access_token yok (alanlar: {sorted(resp.keys())})")
        return 1
    expires_in = int(resp.get("expires_in", 0))
    expiry = (datetime.now(tz=timezone.utc) + timedelta(seconds=expires_in)).isoformat(timespec="seconds")
    print(f"token alindi, project={project}, expiry={expiry} (+{expires_in}s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
