"""Uygulama sirlari icin at-rest sifreleme — mevcut KEK/AES-GCM desenini
(nfc_sdm) yeniden kullanir. Entegrasyon auth sirri (C1b) bununla saklanir;
DB dokumu tek basina siri acmaz. GET yanitlarinda sir ASLA donmez (write-only).
"""
from __future__ import annotations

from .config import settings
from .nfc_sdm import decrypt_key, encrypt_key


def encrypt_secret(plaintext: str) -> str:
    """Duz sir -> KEK ile AES-GCM sifreli base64 (nonce||ct+tag)."""
    return encrypt_key(plaintext.encode("utf-8"), settings.sdm_kek)


def decrypt_secret(blob: str) -> str:
    return decrypt_key(blob, settings.sdm_kek).decode("utf-8")
