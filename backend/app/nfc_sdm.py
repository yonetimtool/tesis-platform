"""NTAG424 DNA SDM/SUN kripto dogrulamasi — saf, IO'suz cekirdek (AN12196).

Etiket her okumada sifreli PICC verisi (UID + 3B okuma sayaci) + CMAC uretir;
sunucu bunlari cozer ve dogrular:

  1. ENCPICCData: AES-128-CBC (IV=0) ile 16B cozulur -> 0xC7 tag'i (UID + sayac
     aynali) + UID(7B) + SDMReadCtr(3B, little-endian).
  2. SV2 = 3CC3 0001 0080 || UID || SDMReadCtr  ->  KSes = AES-CMAC(K, SV2)
  3. SDMMAC = AES-CMAC(KSes, "") ciktisinin TEK indisli baytlari (8B);
     sabit-zaman karsilastirma (hmac.compare_digest).
  4. Sayac monotonlugu: sayac > son_sayac degilse replay.

Dogruluk kaniti: tests/test_nfc_sdm.py, NXP AN12196 s.12 YAYINLI vektoruyle.
v0 varsayimi (tasarim notu): SDMMAC girdisi bos mesaj — AN12196 ornek
konfigurasyonu (UID+CTR aynali, ENCPICCData'li); farkli SDMMACInputOffset
konfigurasyonu gerekirse fonksiyon parametrik genisletilir.

Anahtar saklama: checkpoint-basina AES-128 anahtari, env SDM_KEK'ten turetilen
KEK ile AES-GCM sifreli (base64(nonce||ct+tag)) — DB dokumu tek basina anahtar
sizdirmaz.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import os
from dataclasses import dataclass
from typing import Literal

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.cmac import CMAC

SdmNeden = Literal["ok", "cmac", "uid", "format", "replay"]

_SV2_ONEK = bytes.fromhex("3CC300010080")
_PICC_TAG = 0xC7  # UID aynali + SDMReadCtr aynali (AN12196 ornek konfig)
_KEK_MIN_LEN = 32


@dataclass(frozen=True)
class SdmResult:
    ok: bool
    sayac: int | None
    neden: SdmNeden


def _aes_cmac(key: bytes, data: bytes) -> bytes:
    c = CMAC(algorithms.AES(key))
    c.update(data)
    return c.finalize()


def _norm_uid(uid: str) -> str:
    return uid.replace(":", "").replace("-", "").strip().lower()


def verify_sdm(
    key: bytes,
    expected_uid: str,
    picc_data_hex: str,
    cmac_hex: str,
    son_sayac: int,
) -> SdmResult:
    """SDM/SUN mesajini dogrula. Siralama: format -> cmac -> uid -> replay."""
    try:
        enc = bytes.fromhex(picc_data_hex)
        mac = bytes.fromhex(cmac_hex)
    except ValueError:
        return SdmResult(False, None, "format")
    if len(enc) != 16 or len(mac) != 8:
        return SdmResult(False, None, "format")

    dec = Cipher(algorithms.AES(key), modes.CBC(bytes(16))).decryptor()
    plain = dec.update(enc) + dec.finalize()
    if plain[0] != _PICC_TAG:
        return SdmResult(False, None, "format")
    uid = plain[1:8]
    ctr_bytes = plain[8:11]
    sayac = int.from_bytes(ctr_bytes, "little")

    # CMAC once: yanlis anahtar/sahte veri UID'den once burada duser.
    kses = _aes_cmac(key, _SV2_ONEK + uid + ctr_bytes)
    sdmmac = _aes_cmac(kses, b"")[1::2]  # tek indisli 8 bayt
    if not hmac.compare_digest(sdmmac, mac):
        return SdmResult(False, None, "cmac")

    if uid.hex() != _norm_uid(expected_uid):
        return SdmResult(False, None, "uid")

    if sayac <= son_sayac:
        return SdmResult(False, sayac, "replay")
    return SdmResult(True, sayac, "ok")


# --------------------- anahtar sifreleme (SDM_KEK) -------------------------- #
def _kek_aes(kek: str) -> AESGCM:
    if not kek or len(kek) < _KEK_MIN_LEN:
        raise ValueError(f"SDM_KEK en az {_KEK_MIN_LEN} karakter olmali.")
    return AESGCM(hashlib.sha256(kek.encode("utf-8")).digest())


def encrypt_key(key: bytes, kek: str) -> str:
    """AES-128 etiket anahtarini AES-GCM ile sifrele -> base64(nonce||ct+tag)."""
    nonce = os.urandom(12)
    return base64.b64encode(nonce + _kek_aes(kek).encrypt(nonce, key, None)).decode("ascii")


def decrypt_key(blob: str, kek: str) -> bytes:
    raw = base64.b64decode(blob)
    return _kek_aes(kek).decrypt(raw[:12], raw[12:], None)
