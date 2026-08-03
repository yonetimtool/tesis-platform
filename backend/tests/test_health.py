"""/health smoke testi — calisan API'ye HTTP ile (opsiyonel).

API_URL erisilemezse atlanir (orn. sadece pytest, compose ayakta degil).
"""
from __future__ import annotations

import os

import httpx
import pytest

API_URL = os.getenv("API_URL", "http://api:8000")


def test_health_ok():
    try:
        resp = httpx.get(f"{API_URL}/health", timeout=5)
    except Exception as exc:  # pragma: no cover
        pytest.skip(f"API erisilemiyor ({API_URL}): {exc}")

    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "ok"
    assert body["checks"]["database"] is True
    assert body["checks"]["redis"] is True


def test_health_SEMA_SURUMUNU_bildirir():
    """(P124) "Kod yeni, sema eski" SESSIZ kalmamali.

    GERCEK ARIZA: `camera.snapshot_url` koda eklendi, prod'da `api` imaji
    yeniden derlendi ama goc KOSULMADI. SQLAlchemy her `SELECT camera`ya o
    kolonu koyuyor, Postgres "column does not exist" diyor ve
    `GET /cameras` **500** veriyor. Belirti kamera modulunun tamamen
    olmesiydi — liste bos, karo yok, oynatilacak bir sey yok — ama
    `/health` "ok" demeye devam ediyordu ve hicbir yerde ayrisma
    gorunmuyordu.

    Bu test alanin VARLIGINI ve dogru raporladigini olcer. Ayrismis
    durumun kendisi `goc-tersinir` kapisinda uretilebiliyor (downgrade ->
    500 -> upgrade) ve elle olculdu; burada surekli kosan sey, alanin
    kaybolmamasidir.
    """
    try:
        resp = httpx.get(f"{API_URL}/health", timeout=5)
    except Exception as exc:  # pragma: no cover
        pytest.skip(f"API erisilemiyor ({API_URL}): {exc}")

    sema = resp.json()["schema"]
    assert set(sema) == {"database", "beklenen", "uyumlu"}
    # Test ortaminda goc HEAD'de olmali; degilse kapi zaten kirmizi verir.
    assert sema["uyumlu"] is True, (
        f"sema ile kod AYRISMIS: db={sema['database']} "
        f"beklenen={sema['beklenen']} -> `migrate` kosun"
    )
    assert sema["database"] == sema["beklenen"]


def test_beklenen_revizyon_GOC_DOSYALARINDAN_hesaplanir():
    """Surum sabiti ELLE tutulmaz.

    Elle tutulan bir sabit, goc eklendiginde guncellenmeyi unutulur ve
    kontrol sessizce YALAN SOYLEMEYE baslar — yani kapinin kendisi bozulur
    ve kimse fark etmez.
    """
    from app.main import SEMA_BEKLENEN

    assert SEMA_BEKLENEN, "goc dosyalarindan HEAD hesaplanamadi"
    assert SEMA_BEKLENEN[0].isdigit(), SEMA_BEKLENEN
