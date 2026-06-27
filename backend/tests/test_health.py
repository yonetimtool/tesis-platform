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
