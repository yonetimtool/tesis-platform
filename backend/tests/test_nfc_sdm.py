"""nfc_sdm birim testleri — NXP AN12196 YAYINLI test vektorleriyle.

Vektor kaynagi: AN12196 "NTAG 424 DNA ... features and hints" s.12 ornegi
(https://ntag.nxp.com/424?e=EF963FF7828658A599F3041510671E88&c=94EED9EE65337086):
sifir anahtar (16x00) ile ENCPICCData cozumu -> tag C7, UID 04DE5F1EACC040,
SDMReadCtr 61 (0x3D); SDMMAC 94EED9EE65337086.
"""
from __future__ import annotations

import pytest

from app.nfc_sdm import SdmResult, decrypt_key, encrypt_key, verify_sdm

ZERO_KEY = bytes(16)
AN12196_PICC = "EF963FF7828658A599F3041510671E88"
AN12196_CMAC = "94EED9EE65337086"
AN12196_UID = "04DE5F1EACC040"
AN12196_CTR = 61

KEK = "test-sdm-kek-en-az-32-karakter-uzunlugunda!"


# ------------------------------ verify_sdm --------------------------------- #
def test_an12196_published_vector_valid():
    res = verify_sdm(ZERO_KEY, AN12196_UID, AN12196_PICC, AN12196_CMAC, son_sayac=0)
    assert res == SdmResult(ok=True, sayac=AN12196_CTR, neden="ok")


def test_uid_case_and_separator_insensitive():
    # buyuk/kucuk harf ve ':' ayracli sozlesme formati esdegerdir
    assert verify_sdm(ZERO_KEY, AN12196_UID.lower(), AN12196_PICC, AN12196_CMAC, 0).ok
    assert verify_sdm(ZERO_KEY, "04:DE:5F:1E:AC:C0:40", AN12196_PICC, AN12196_CMAC, 0).ok


def test_tampered_cmac_rejected():
    bozuk = "0" + AN12196_CMAC[1:] if AN12196_CMAC[0] != "0" else "1" + AN12196_CMAC[1:]
    res = verify_sdm(ZERO_KEY, AN12196_UID, AN12196_PICC, bozuk, 0)
    assert res.ok is False and res.neden == "cmac"


def test_wrong_key_rejected():
    # Yanlis anahtar: cozum cop -> tag bayti (0xC7) tutmaz ("format") ya da
    # tesadufen tutarsa CMAC dusurur ("cmac"). Iki neden de invalid_signature'a
    # maplenir; onemli olan RED ve replay'e/uid'e siniflanMAmasi.
    res = verify_sdm(bytes.fromhex("00112233445566778899AABBCCDDEEFF"), AN12196_UID, AN12196_PICC, AN12196_CMAC, 0)
    assert res.ok is False and res.neden in ("format", "cmac")


def test_wrong_uid_rejected():
    res = verify_sdm(ZERO_KEY, "04AAAAAAAAAAAA", AN12196_PICC, AN12196_CMAC, 0)
    assert res.ok is False and res.neden == "uid"


def test_replay_counter_not_monotonic():
    # sayac esit -> replay; sayac kucuk -> replay
    esit = verify_sdm(ZERO_KEY, AN12196_UID, AN12196_PICC, AN12196_CMAC, son_sayac=AN12196_CTR)
    assert esit.ok is False and esit.neden == "replay" and esit.sayac == AN12196_CTR
    buyuk = verify_sdm(ZERO_KEY, AN12196_UID, AN12196_PICC, AN12196_CMAC, son_sayac=100)
    assert buyuk.ok is False and buyuk.neden == "replay"


@pytest.mark.parametrize(
    "picc,cmac",
    [
        ("zz" * 16, AN12196_CMAC),          # hex degil
        (AN12196_PICC, "zz" * 8),            # hex degil
        (AN12196_PICC[:-2], AN12196_CMAC),   # kisa picc (15B)
        (AN12196_PICC, AN12196_CMAC[:-2]),   # kisa cmac (7B)
        ("00" * 16, AN12196_CMAC),           # cozum tag != 0xC7 -> format
    ],
)
def test_malformed_input_is_format_error(picc, cmac):
    res = verify_sdm(ZERO_KEY, AN12196_UID, picc, cmac, 0)
    assert res.ok is False and res.neden == "format"


# --------------------------- anahtar sifreleme ----------------------------- #
def test_key_encrypt_decrypt_roundtrip():
    key = bytes.fromhex("000102030405060708090A0B0C0D0E0F")
    blob = encrypt_key(key, KEK)
    assert key.hex() not in blob.lower()  # duz metin sizmadi
    assert decrypt_key(blob, KEK) == key
    # ayni anahtar iki sifrelemede farkli blob (rastgele nonce)
    assert encrypt_key(key, KEK) != blob


def test_key_decrypt_wrong_kek_fails():
    blob = encrypt_key(bytes(16), KEK)
    with pytest.raises(Exception):
        decrypt_key(blob, "baska-kek-ama-yine-32-karakterden-uzun!!")


def test_short_kek_rejected():
    with pytest.raises(ValueError):
        encrypt_key(bytes(16), "kisa-kek")
    with pytest.raises(ValueError):
        encrypt_key(bytes(16), "")
