"""MinIO (S3-uyumlu) foto kanit deposu — presigned URL uretimi.

Presigned URL'ler boto3 ile YEREL imzalanir (sunucuya baglanmaz); bu yuzden
URL uretimi MinIO ayakta olmasa da calisir (test dostu). Foto_key tenant_id ile
namespace'lenir => capraz-tenant cakisma/erisim olmaz.

Onemli: presigned URL host'u `settings.minio_endpoint` olur — bu istemcinin
erisebilecegi PUBLIC adres olmali (dev: http://localhost:9000). Backend sunucu-tarafi
S3 cagrisi yapmaz (bucket'i infra/minio-init olusturur).
"""
from __future__ import annotations

import os
import uuid

import boto3
from botocore.client import Config

from .config import settings
from .errors import APIError

_EXT_BY_CT = {
    "image/jpeg": ".jpg",
    "image/jpg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/heic": ".heic",
}


def _require_config() -> None:
    """MinIO env eksikse sessiz 500 yerine anlamli hata ver."""
    missing = [
        name
        for name, value in (
            ("MINIO_ENDPOINT", settings.minio_endpoint),
            ("MINIO_ACCESS_KEY", settings.minio_access_key),
            ("MINIO_SECRET_KEY", settings.minio_secret_key),
            ("MINIO_BUCKET", settings.minio_bucket),
        )
        if not value or not str(value).strip()
    ]
    if missing:
        raise APIError(
            503,
            "storage_unconfigured",
            f"MinIO yapilandirmasi eksik: {', '.join(missing)}",
        )


def _client():
    _require_config()
    return boto3.client(
        "s3",
        endpoint_url=settings.minio_endpoint,
        aws_access_key_id=settings.minio_access_key,
        aws_secret_access_key=settings.minio_secret_key,
        region_name=settings.minio_region,
        config=Config(signature_version="s3v4"),
    )


def _ext(content_type: str, dosya_adi: str | None) -> str:
    if dosya_adi:
        _, e = os.path.splitext(dosya_adi)
        if e:
            return e.lower()
    return _EXT_BY_CT.get(content_type.lower(), "")


def make_foto_key(tenant_id: uuid.UUID | str, content_type: str, dosya_adi: str | None = None) -> str:
    """tenant ile namespace'li, cakismasiz obje anahtari."""
    return f"{tenant_id}/tasks/{uuid.uuid4().hex}{_ext(content_type, dosya_adi)}"


def presign_put(
    tenant_id: uuid.UUID | str, content_type: str, dosya_adi: str | None = None
) -> tuple[str, str, int]:
    """(foto_key, presigned_put_url, expires_in) doner."""
    key = make_foto_key(tenant_id, content_type, dosya_adi)
    url = _client().generate_presigned_url(
        "put_object",
        Params={"Bucket": settings.minio_bucket, "Key": key, "ContentType": content_type},
        ExpiresIn=settings.minio_url_expire_seconds,
    )
    return key, url, settings.minio_url_expire_seconds


def presign_get(key: str) -> str:
    """Goruntuleme icin presigned GET URL (opsiyonel kullanim)."""
    return _client().generate_presigned_url(
        "get_object",
        Params={"Bucket": settings.minio_bucket, "Key": key},
        ExpiresIn=settings.minio_url_expire_seconds,
    )
