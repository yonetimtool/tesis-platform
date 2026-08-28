"""Telefonla giris (POST /auth/login-phone) + geçici parola ilk giriş akışı.

Kimlik modeli (contracts/auth.md §1): mobil roller telefon (global benzersiz) +
parola ile girer; tenant numaradan otomatik çözülür (tenant_slug YOK). İlk giriş
geçici kod → zorunlu parola belirleme (/auth/set-password). Admin paneli e-posta
ile /auth/login kullanır (bu dosya onu değiştirmez).
"""
from __future__ import annotations


def _yon_headers(client, world):
    r = client.post(
        "/auth/login",
        json={
            "tenant_slug": world["slug_a"],
            "email": world["yonetici_a"]["email"],
            "password": world["yonetici_a"]["password"],
        },
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


# ------------------------------ happy path -------------------------------- #
def test_phone_login_password_returns_tokens(client, world):
    r = client.post(
        "/auth/login-phone",
        json={"phone": world["yonetici_a"]["phone"], "password": world["yonetici_a"]["password"]},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["password_setup_required"] is False
    assert body["access_token"] and body["refresh_token"]


def test_phone_login_normalizes_local_format(client, world):
    # E.164 numaranin YEREL biçimi ("+9054…" -> "0 54…", araya boşluklarla)
    # aynı hesaba çözülmeli. Numara koşuma özel üretilir (tur 46).
    e164 = world["yonetici_a"]["phone"]           # +90XXXXXXXXXX
    yerel = "0" + e164[3:]                        # 0XXXXXXXXXX
    bosluklu = f"{yerel[:4]} {yerel[4:7]} {yerel[7:9]} {yerel[9:]}"
    r = client.post(
        "/auth/login-phone",
        json={"phone": bosluklu, "password": world["yonetici_a"]["password"]},
    )
    assert r.status_code == 200, r.text
    assert r.json()["access_token"]


def test_phone_login_wrong_password_401(client, world):
    r = client.post(
        "/auth/login-phone",
        json={"phone": world["yonetici_a"]["phone"], "password": "yanlisParola1"},
    )
    assert r.status_code == 401
    assert r.json()["error"]["code"] == "invalid_credentials"


def test_phone_login_unknown_phone_401(client, world):
    r = client.post(
        "/auth/login-phone",
        json={"phone": "+905999999999", "password": "herhangiParola1"},
    )
    assert r.status_code == 401


def test_phone_login_garbage_phone_401_not_422(client, world):
    # Geçersiz numara login'de 401 (adım sızmaz), 422 değil.
    r = client.post(
        "/auth/login-phone",
        json={"phone": "abc", "password": "herhangiParola1"},
    )
    assert r.status_code == 401


# ------------------------- ilk giriş (geçici kod) ------------------------- #
def test_first_login_temp_code_then_set_password(client, world, owner_conn):
    """(P186) POST /residents artik PAROLASIZ acar ve `temp_code` DONDURMEZ
    (davet linki gonderilir). Bu test yine de telefon-login'in tek-seferlik
    kod (temp_code_hash) -> set-password -> kalici parola akisini olcer; kod
    DB'ye dogrudan yazilarak (onboarding kodunun verilmis oldugunu taklit
    ederek) uretilir — davranis (backend) degismedi, yalniz kodun uretim yolu
    davet akisina tasindi."""
    from app.security import hash_password

    yon = _yon_headers(client, world)
    # Yönetici sakin açar -> PAROLASIZ hesap (temp_code DONMEZ).
    r = client.post(
        "/residents",
        headers=yon,
        json={"unit_no": "P-1", "ad": "Telefon Sakin", "telefon": world["bos_telefonlar"][0]},
    )
    assert r.status_code == 201, r.text
    assert "temp_code" not in r.json()  # (P186) gecici kod URETILMEZ
    uid = r.json()["user_id"]

    # Tek-seferlik kodu DB'ye yaz (onboarding kodunun verildigini taklit et).
    temp_code = "AB23CD45"
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE app_user SET temp_code_hash=%s, password_set=false WHERE id=%s",
            (hash_password(temp_code), uid),
        )

    # Geçici kod ile telefon-login -> oturum YOK, setup_token döner.
    r = client.post(
        "/auth/login-phone",
        json={"phone": world["bos_telefonlar"][0], "password": temp_code},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["password_setup_required"] is True
    assert body["setup_token"] and body["access_token"] is None

    # set-password -> tam oturum.
    r = client.post(
        "/auth/set-password",
        json={"setup_token": body["setup_token"], "new_password": "YeniSakin123!"},
    )
    assert r.status_code == 200, r.text
    assert r.json()["access_token"]

    # Artık kalıcı parola ile telefon-login çalışır; geçici kod geçmez.
    assert client.post(
        "/auth/login-phone",
        json={"phone": world["bos_telefonlar"][0], "password": "YeniSakin123!"},
    ).status_code == 200
    assert client.post(
        "/auth/login-phone",
        json={"phone": world["bos_telefonlar"][0], "password": temp_code},
    ).status_code == 401


# -------------------------- global benzersizlik --------------------------- #
def test_phone_globally_unique_across_tenants(client, world):
    # A tenant'ında bir numarayla sakin aç.
    yon_a = _yon_headers(client, world)
    phone = world["bos_telefonlar"][1]
    r = client.post(
        "/residents",
        headers=yon_a,
        json={"unit_no": "P-2", "ad": "A Sakin", "telefon": phone},
    )
    assert r.status_code == 201, r.text

    # B tenant'ında AYNI numarayla açmaya çalış -> global benzersizlik 409.
    rb = client.post(
        "/auth/login",
        json={
            "tenant_slug": world["slug_b"],
            "email": world["yonetici_b"]["email"],
            "password": world["yonetici_b"]["password"],
        },
    )
    yon_b = {"Authorization": f"Bearer {rb.json()['access_token']}"}
    r = client.post(
        "/residents",
        headers=yon_b,
        json={"unit_no": "P-2", "ad": "B Sakin", "telefon": phone},
    )
    assert r.status_code == 409, r.text
    assert r.json()["error"]["code"] == "conflict"
