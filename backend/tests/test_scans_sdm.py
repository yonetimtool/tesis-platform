"""POST /scans SDM entegrasyonu + PUT /checkpoints/{id}/sdm-key testleri.

Karar tablosu (tasarim §4) satir satir + idempotency-replay etkilesimi (kritik:
ayni Idempotency-Key ile tekrar 200 doner, replay SANILMAZ).

Vektor uretimi: AN12196 algoritmasinin kendisiyle (AES-CBC + CMAC) test icinde
forge edilir; algoritmanin dogrulugu test_nfc_sdm.py'daki YAYINLI vektorle
kanitlanir — burada farkli sayac degerleri icin ayni ilkellerle veri uretilir.
"""
from __future__ import annotations

import uuid

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.cmac import CMAC

ZERO_KEY_HEX = "00000000000000000000000000000000"
VEKTOR_UID = "04DE5F1EACC040"


def _cmac(key: bytes, data: bytes) -> bytes:
    c = CMAC(algorithms.AES(key))
    c.update(data)
    return c.finalize()


def make_sdm(key_hex: str, uid_hex: str, ctr: int) -> tuple[str, str]:
    """(picc_data_hex, cmac_hex) uret — AN12196 SUN mesaji (UID+ctr aynali)."""
    key = bytes.fromhex(key_hex)
    uid = bytes.fromhex(uid_hex)
    plain = bytes([0xC7]) + uid + ctr.to_bytes(3, "little") + bytes(5)  # 16B blok
    enc = Cipher(algorithms.AES(key), modes.CBC(bytes(16))).encryptor()
    picc = enc.update(plain) + enc.finalize()
    sv2 = bytes.fromhex("3CC300010080") + uid + ctr.to_bytes(3, "little")
    kses = _cmac(key, sv2)
    sdmmac = _cmac(kses, b"")[1::2]
    return picc.hex().upper(), sdmmac.hex().upper()


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _checkpoint(client, admin, uid=VEKTOR_UID):
    r = client.post("/checkpoints", headers=admin, json={"ad": "SDM CP", "nfc_tag_uid": uid})
    assert r.status_code == 201, r.text
    return r.json()


def _set_key(client, admin, cp_id, key=ZERO_KEY_HEX):
    return client.put(f"/checkpoints/{cp_id}/sdm-key", headers=admin, json={"key": key})


def _scan(client, headers, uid, key=None, **extra):
    body = {"nfc_tag_uid": uid, "okutma_zamani": "2026-07-04T10:00:00Z", **extra}
    return client.post(
        "/scans", headers={**headers, "Idempotency-Key": key or uuid.uuid4().hex}, json=body
    )


# --------------------------- anahtar kaydi (RBAC) --------------------------- #
def test_sdm_key_admin_only_and_no_leak(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])
    cp = _checkpoint(client, admin)
    assert cp["sdm_aktif"] is False  # yeni checkpoint'te SDM kapali

    r = _set_key(client, admin, cp["id"])
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["sdm_aktif"] is True
    # anahtar (veya sifreli hali) HICBIR alanda donmez
    assert ZERO_KEY_HEX not in r.text
    assert "sdm_key_sifreli" not in body and "key" not in body

    # detay/list uclarinda da sdm_aktif gorunur, anahtar gorunmez
    det = client.get(f"/checkpoints/{cp['id']}", headers=guard).json()
    assert det["sdm_aktif"] is True and "sdm_key_sifreli" not in det

    for h in (guard, gorevli, resident):
        assert _set_key(client, h, cp["id"]).status_code == 403

    # null ile kapatma
    r = client.put(f"/checkpoints/{cp['id']}/sdm-key", headers=admin, json={"key": None})
    assert r.status_code == 200 and r.json()["sdm_aktif"] is False

    # gecersiz anahtar formati -> 422
    assert _set_key(client, admin, cp["id"], key="kisa").status_code == 422


def test_sdm_key_tenant_isolation(client, world):
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    cp = _checkpoint(client, admin_a)
    assert _set_key(client, admin_b, cp["id"]).status_code == 404


# --------------------------- karar tablosu (5 satir) ------------------------ #
def test_row1_no_key_scan_false(client, world):
    """Anahtar yok: SDM alanlari olsun olmasin kayit imza_dogrulandi=false."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    cp = _checkpoint(client, admin)

    r = _scan(client, guard, cp["nfc_tag_uid"])
    assert r.status_code == 201 and r.json()["imza_dogrulandi"] is False

    picc, cmac = make_sdm(ZERO_KEY_HEX, VEKTOR_UID, 5)
    r = _scan(client, guard, cp["nfc_tag_uid"], sdm_picc_data=picc, sdm_cmac=cmac)
    assert r.status_code == 201 and r.json()["imza_dogrulandi"] is False


def test_row2_key_but_no_sdm_fields_false(client, world):
    """Anahtar var + SDM alanlari yok: zorlama YOK, kayit false."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    cp = _checkpoint(client, admin)
    assert _set_key(client, admin, cp["id"]).status_code == 200

    r = _scan(client, guard, cp["nfc_tag_uid"])
    assert r.status_code == 201 and r.json()["imza_dogrulandi"] is False


def test_row3_invalid_sdm_422_no_record(client, world):
    """Gecersiz SDM (bozuk CMAC) -> 422 invalid_signature; kayit OLUSMAZ."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    cp = _checkpoint(client, admin)
    _set_key(client, admin, cp["id"])

    picc, _ = make_sdm(ZERO_KEY_HEX, VEKTOR_UID, 7)
    key = uuid.uuid4().hex
    r = _scan(client, guard, cp["nfc_tag_uid"], key=key, sdm_picc_data=picc, sdm_cmac="00" * 8)
    assert r.status_code == 422, r.text
    assert r.json()["error"]["code"] == "invalid_signature"

    # kayit olusmadi kaniti: AYNI idempotency key ile gecerli istek 201 (200 degil)
    picc2, cmac2 = make_sdm(ZERO_KEY_HEX, VEKTOR_UID, 7)
    r2 = _scan(client, guard, cp["nfc_tag_uid"], key=key, sdm_picc_data=picc2, sdm_cmac=cmac2)
    assert r2.status_code == 201, r2.text
    assert r2.json()["imza_dogrulandi"] is True


def test_row4_replay_422_no_record(client, world):
    """Sayac ilerlememis -> 422 replay_detected; kayit OLUSMAZ."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    cp = _checkpoint(client, admin)
    _set_key(client, admin, cp["id"])

    picc, cmac = make_sdm(ZERO_KEY_HEX, VEKTOR_UID, 10)
    assert _scan(client, guard, cp["nfc_tag_uid"], sdm_picc_data=picc, sdm_cmac=cmac).status_code == 201

    # ayni sayacla (10) YENI idempotency key -> replay
    key = uuid.uuid4().hex
    r = _scan(client, guard, cp["nfc_tag_uid"], key=key, sdm_picc_data=picc, sdm_cmac=cmac)
    assert r.status_code == 422, r.text
    assert r.json()["error"]["code"] == "replay_detected"

    # daha kucuk sayac da replay
    picc9, cmac9 = make_sdm(ZERO_KEY_HEX, VEKTOR_UID, 9)
    r = _scan(client, guard, cp["nfc_tag_uid"], sdm_picc_data=picc9, sdm_cmac=cmac9)
    assert r.status_code == 422 and r.json()["error"]["code"] == "replay_detected"

    # replay kayit birakmadi: ayni key ile sayaci ilerletilmis gecerli istek 201
    picc11, cmac11 = make_sdm(ZERO_KEY_HEX, VEKTOR_UID, 11)
    r = _scan(client, guard, cp["nfc_tag_uid"], key=key, sdm_picc_data=picc11, sdm_cmac=cmac11)
    assert r.status_code == 201


def test_row5_valid_sdm_true_and_counter_advances(client, world):
    """Gecerli SDM -> imza_dogrulandi=true; sayac gunceller (ardisik okutmalar)."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    cp = _checkpoint(client, admin)
    _set_key(client, admin, cp["id"])

    for ctr in (1, 2, 5):  # artan sayaclar kabul (bosluk olabilir)
        picc, cmac = make_sdm(ZERO_KEY_HEX, VEKTOR_UID, ctr)
        r = _scan(client, guard, cp["nfc_tag_uid"], sdm_picc_data=picc, sdm_cmac=cmac)
        assert r.status_code == 201, f"ctr={ctr}: {r.text}"
        assert r.json()["imza_dogrulandi"] is True

    # sayac 5'te: 5 tekrar -> replay
    picc, cmac = make_sdm(ZERO_KEY_HEX, VEKTOR_UID, 5)
    assert _scan(client, guard, cp["nfc_tag_uid"], sdm_picc_data=picc, sdm_cmac=cmac).status_code == 422


def test_imza_dogrulandi_body_input_ignored(client, world):
    """Govdedeki imza_dogrulandi=true YOK SAYILIR — deger sunucudan."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    cp = _checkpoint(client, admin)

    r = _scan(client, guard, cp["nfc_tag_uid"], imza_dogrulandi=True)
    assert r.status_code == 201 and r.json()["imza_dogrulandi"] is False


# ------------------- idempotency-replay etkilesimi (kritik) ----------------- #
def test_idempotent_repeat_200_not_replay(client, world):
    """Ayni Idempotency-Key + ayni govde tekrari 200 doner — replay SANILMAZ."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    cp = _checkpoint(client, admin)
    _set_key(client, admin, cp["id"])

    picc, cmac = make_sdm(ZERO_KEY_HEX, VEKTOR_UID, 42)
    key = uuid.uuid4().hex
    first = _scan(client, guard, cp["nfc_tag_uid"], key=key, sdm_picc_data=picc, sdm_cmac=cmac)
    assert first.status_code == 201 and first.json()["imza_dogrulandi"] is True

    # tekrar (offline outbox cift gonderimi): sayac zaten 42 ama 200 donmeli
    again = _scan(client, guard, cp["nfc_tag_uid"], key=key, sdm_picc_data=picc, sdm_cmac=cmac)
    assert again.status_code == 200, again.text
    assert again.json()["id"] == first.json()["id"]
    assert again.json()["imza_dogrulandi"] is True


def test_new_key_resets_counter(client, world):
    """Yeni anahtar yazilinca sayac 0'lanir — eski sayacli okutma yeniden gecer."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    cp = _checkpoint(client, admin)
    _set_key(client, admin, cp["id"])

    picc, cmac = make_sdm(ZERO_KEY_HEX, VEKTOR_UID, 3)
    assert _scan(client, guard, cp["nfc_tag_uid"], sdm_picc_data=picc, sdm_cmac=cmac).status_code == 201
    # ayni sayac tekrar -> replay
    assert _scan(client, guard, cp["nfc_tag_uid"], sdm_picc_data=picc, sdm_cmac=cmac).status_code == 422

    # yeniden provision (ayni anahtar da olsa sayac sifirlanir)
    assert _set_key(client, admin, cp["id"]).status_code == 200
    r = _scan(client, guard, cp["nfc_tag_uid"], sdm_picc_data=picc, sdm_cmac=cmac)
    assert r.status_code == 201 and r.json()["imza_dogrulandi"] is True
