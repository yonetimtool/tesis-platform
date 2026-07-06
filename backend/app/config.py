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

    # --- NTAG424 SDM/SUN dogrulamasi ---
    # Checkpoint-basina AES-128 etiket anahtarlarini sifrelemekte kullanilan
    # KEK (key encryption key). 32+ karakter; bos = SDM anahtar kaydi kapali
    # (PUT /checkpoints/{id}/sdm-key -> 500 config_error). jwt_secret deseni.
    sdm_kek: str = ""

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
    # Peyzaj hatirlatma: "yaklasan" penceresi (saat) + beat periyodu (saniye).
    scheduler_landscape_lead_hours: int = 24
    scheduler_landscape_interval_seconds: int = 3600

    # --- MinIO (S3-uyumlu foto kanit deposu) ---
    # PUBLIC endpoint: presigned URL host'u (istemci buraya PUT'lar). dev: localhost.
    minio_endpoint: str = "http://localhost:9000"
    minio_access_key: str = "minioadmin"
    minio_secret_key: str = "minioadmin12345"  # compose varsayilani ile ayni (>=8)
    minio_bucket: str = "tesis-foto"
    minio_region: str = "us-east-1"
    minio_url_expire_seconds: int = 900

    # --- Odeme saglayici (kart) ---
    # manual | iyzico | paytr. GERCEK ANAHTAR YOK — placeholder'lar (sandbox sonra).
    payment_provider: str = "manual"
    iyzico_api_key: str = ""
    iyzico_secret: str = ""
    iyzico_base_url: str = "https://sandbox-api.iyzipay.com"
    paytr_merchant_id: str = ""
    paytr_merchant_key: str = ""
    paytr_merchant_salt: str = ""
    paytr_base_url: str = "https://www.paytr.com"

    # --- Push saglayici (FCM) ---
    # noop | fcm. GERCEK KIMLIK YOK — kimlik bossa FcmProvider unconfigured (no-op).
    push_provider: str = "noop"
    fcm_project_id: str = ""
    # Service account JSON (inline metin ya da dosya yolu); bossa unconfigured.
    fcm_service_account_json: str = ""
    fcm_base_url: str = "https://fcm.googleapis.com"


settings = Settings()
