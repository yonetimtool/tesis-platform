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
        # path-style adresleme (bucket URL yolunda, alt-alan adi DEGIL): presigned
        # URL `{endpoint}/{bucket}/{key}` olur. Prod'da MinIO bir alt-alan
        # (storage.yonetio.site) arkasinda ters-proxy'lenir; path-style, tek bir
        # sertifika ve host-korumali reverse_proxy ile s3v4 imzasini bozmadan
        # calisir (virtual-host style joker sertifika + `bucket.host` gerektirirdi).
        # Dev'de (localhost) botocore zaten path-style kullanir => davranis ayni.
        config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
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
    """(foto_key, presigned_put_url, expires_in) doner.

    content_type burada zaten guvenilir: cagiran router `PresignRequest`
    (schemas.py) uzerinden gecer, orada gorsel allow-list'ine (jpeg/png/webp/
    heic) ve 8MB boyut tavanina karsi dogrulanmistir — bu fonksiyon tekrar
    dogrulamaz. content_type imzalanan URL'e (`ContentType` param'i) baglanir,
    yani istemci PUT sirasinda farkli bir Content-Type header'i gonderirse
    imza uyusmaz ve MinIO reddeder. Boyut tavani ise yalnizca istemcinin
    BEYAN ETTIGI `boyut` alanina karsi (best-effort): gercek PUT govdesinin
    boyutunu bu fonksiyon (veya MinIO) ayrica dogrulamaz.
    """
    key = make_foto_key(tenant_id, content_type, dosya_adi)
    url = _client().generate_presigned_url(
        "put_object",
        Params={"Bucket": settings.minio_bucket, "Key": key, "ContentType": content_type},
        ExpiresIn=settings.minio_url_expire_seconds,
    )
    return key, url, settings.minio_url_expire_seconds


def delete_objects(keys: list[str]) -> int:
    """Verilen anahtarlari MinIO'dan siler (retention/imha). Kac obje silindigini
    doner. Presign'in aksine SUNUCU-TARAFI cagridir (MinIO ayakta olmali).

    Anahtarlar tenant ile namespace'lidir (make_foto_key), bu yuzden yanlislikla
    baska tenant'in objesi silinmez. Bos liste => 0. S3 batch API'si tek istekte
    en fazla 1000 anahtar kabul eder; buyuk listeler parcalanir."""
    keys = [k for k in keys if k]
    if not keys:
        return 0
    client = _client()
    deleted = 0
    for i in range(0, len(keys), 1000):
        chunk = keys[i : i + 1000]
        resp = client.delete_objects(
            Bucket=settings.minio_bucket,
            Delete={"Objects": [{"Key": k} for k in chunk], "Quiet": True},
        )
        # Quiet modda yalniz HATALAR doner; silinen = istek - hata.
        errors = resp.get("Errors", []) or []
        deleted += len(chunk) - len(errors)
    return deleted


def delete_prefix(prefix: str) -> int:
    """Bir anahtar ONEKI altindaki TUM objeleri siler (orn. tenant offboarding:
    '{tenant_id}/'). Listeler + batch siler. Onek BOS ise guvenlik icin hicbir
    sey yapmaz (tum bucket'i silmeyi onler)."""
    if not prefix:
        return 0
    client = _client()
    keys: list[str] = []
    paginator = client.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=settings.minio_bucket, Prefix=prefix):
        keys.extend(obj["Key"] for obj in page.get("Contents", []) or [])
    return delete_objects(keys)


def presign_get(key: str) -> str:
    """Goruntuleme icin presigned GET URL (opsiyonel kullanim)."""
    return _client().generate_presigned_url(
        "get_object",
        Params={"Bucket": settings.minio_bucket, "Key": key},
        ExpiresIn=settings.minio_url_expire_seconds,
    )
