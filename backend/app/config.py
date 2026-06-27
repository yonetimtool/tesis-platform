"""Uygulama ayarlari — env'den okunur (pydantic-settings).

Uygulama DB'ye DUSUK YETKILI `app_rw` rolu ile (async) baglanir; bu rol RLS'e
tabidir. Owner/superuser baglantisi sadece migration ve testlerde kullanilir
(uygulama kodu owner ile baglanmaz).
"""
from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Async SQLAlchemy URL (app_rw, asyncpg suruculu).
    # Ornek: postgresql+asyncpg://app_rw:***@db:5432/tesis
    database_url: str = "postgresql+asyncpg://app_rw:app_rw_secret_change_me@localhost:5432/tesis"

    # Redis (cache / Celery broker+backend).
    redis_url: str = "redis://localhost:6379/0"

    # JWT (token uretimi Prompt 2'de; burada sadece ayar iskeleti).
    jwt_secret: str = "change-me-please-use-32+chars-secret"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 30

    # SQLAlchemy engine echo (debug).
    sql_echo: bool = False

    # --- Scheduler (Celery beat) ---
    # OWNER (superuser) libpq DSN — tenant enumerasyonu (RLS bootstrap) icin.
    owner_dsn: str = "postgresql://tesis_owner:owner_secret_change_me@localhost:5432/tesis"
    # app_rw libpq DSN (SYNC) — tenant-scoped pencere uretimi/tespiti icin.
    app_dsn: str = "postgresql://app_rw:app_rw_secret_change_me@localhost:5432/tesis"
    # Pencereler kac gun ileri uretilsin (bugun + ... => varsayilan bugun+yarin).
    scheduler_horizon_days: int = 2
    # Beat periyotlari (saniye).
    scheduler_generate_interval_seconds: int = 3600   # saat basi
    scheduler_detect_interval_seconds: int = 300      # 5 dk


settings = Settings()
