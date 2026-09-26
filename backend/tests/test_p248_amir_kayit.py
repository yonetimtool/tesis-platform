"""(P248 §1) GUVENLIK AMIRI — DOGRUDAN KULLANICI OLARAK.

OLCULEN KUSUR (canli, `YENI_KAYIT_AKISI=true`): yonetici amiri DOGRUDAN
ekliyordu (P213 §6) ve davet e-postasi Tesis ID ile gidiyordu; ama amir
mobilde kaydolamiyordu:

  * e-posta yolu, beyan `guvenlik_amiri`  -> 422 (`kayit._ROLLER`da yok),
  * e-posta yolu, beyan `security`        -> `rol_uyusmuyor` -> KUYRUK, kod
                                             HIC gonderilmez,
  * SSO, beyan `security`                 -> `onay_bekliyor`,
  * SSO, beyansiz (giriste tamamlama)     -> `onay_bekliyor`
                                             (`oauth._TAMAMLA_ROLLERI`da yok).

KURAL (degismedi): davet edilmis kisi onay BEKLEMEZ; davet edilmemis kisi
Tesis ID ile amir olamaz (`liste_disi` -> kuyruk). YENI: beyan guvenlik
ailesinde (security <-> guvenlik_amiri) eslesir ve rol HER ZAMAN listedeki
hesaptan gelir — beyan hicbir zaman yetki YUKSELTMEZ.

Testler CANLI sunucuya vurur; kayit uclari bayrak kapaliysa 503 doner ve
o testler ATLANIR (`test_p177_kayit_akisi` ile ayni desen; tesis de o
akisla kurulur). Bayraktan BAGIMSIZ olan yalniz rol ailesi birim testidir.
"""
from __future__ import annotations

import uuid

import jwt
import pytest

from app.roller import kayit_beyani_eslesir
from app.security import hash_password

KOD = "424242"
ALAN = "p248ornek.com"
PAROLA = "GucluParola123!"


def _eposta(on: str = "p248") -> str:
    return f"{on}-{uuid.uuid4().hex[:12]}@{ALAN}"


def _kodu_ayarla(owner_conn, eposta: str) -> None:
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE kayit_dogrulama SET kod_hash = %s WHERE eposta = %s "
            "AND amac = 'kayit' AND kod_hash IS NOT NULL",
            (hash_password(KOD), eposta),
        )
        assert cur.rowcount >= 1, "kayit kodu uretilmemis (kod gonderilmedi)"
    owner_conn.commit()


def _sso_jeton(eposta: str, *, email_verified: bool = True) -> str:
    from app.routers.oauth import _baglama_jetonu

    return _baglama_jetonu(
        {
            "saglayici": "google",
            "subject": f"sub-{uuid.uuid4().hex}",
            "eposta": eposta,
            "email_verified": email_verified,
            "ad": "SSO Amir",
            "onaylar": None,
        }
    )


def _rol(jeton: str) -> str:
    return jwt.decode(jeton, options={"verify_signature": False})["role"]


def _kuyruk(owner_conn, eposta: str):
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT rol, sebep FROM kayit_onay_kuyrugu "
            "WHERE eposta = %s AND durum = 'bekliyor'",
            (eposta,),
        )
        return cur.fetchall()


# --------------------------------------------------------------------------- #
# Birim: rol ailesi
# --------------------------------------------------------------------------- #
@pytest.mark.parametrize(
    ("beyan", "liste", "beklenen"),
    [
        ("security", "security", True),
        ("guvenlik_amiri", "guvenlik_amiri", True),
        # AILE ICI — iki yon.
        ("security", "guvenlik_amiri", True),
        ("guvenlik_amiri", "security", True),
        # AILE DISI — eskisi gibi uyusmuyor.
        ("guvenlik_amiri", "tesis_gorevlisi", False),
        ("guvenlik_amiri", "resident", False),
        ("guvenlik_amiri", "yonetici", False),
        ("security", "yonetici", False),
        ("resident", "security", False),
        ("tesis_gorevlisi", "security", False),
    ],
)
def test_kayit_beyani_rol_ailesi(beyan, liste, beklenen):
    assert kayit_beyani_eslesir(beyan, liste) is beklenen


# --------------------------------------------------------------------------- #
# Tesis + yonetici (yeni akisla) — bayrak ACIK gerekir
# --------------------------------------------------------------------------- #
@pytest.fixture
def akis_acik(client) -> bool:
    r = client.post(
        "/auth/kayit/yonetici-dogrula",
        json={"eposta": f"probe@{ALAN}", "kod": "000000"},
    )
    return r.status_code != 503


@pytest.fixture
def tesis(client, owner_conn, akis_acik):
    if not akis_acik:
        pytest.skip("YENI_KAYIT_AKISI kapali")
    eposta = _eposta("yon")
    r = client.post(
        "/auth/kayit/yonetici-basvuru",
        json={
            "ad": "Ayşe", "soyad": "Yılmaz", "eposta": eposta,
            "telefon": "+90" + str(uuid.uuid4().int)[:10], "parola": PAROLA,
            "onay_sozlesme": True, "onay_kvkk": True, "onay_ticari": False,
        },
    )
    assert r.status_code == 201, r.text
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE yonetici_basvuru SET kod_hash = %s WHERE eposta = %s",
            (hash_password(KOD), eposta),
        )
    owner_conn.commit()
    jeton = client.post(
        "/auth/kayit/yonetici-dogrula", json={"eposta": eposta, "kod": KOD}
    ).json()["kurulum_jetonu"]
    r = client.post(
        "/auth/kayit/yonetici-tesis",
        json={"kurulum_jetonu": jeton, "tesis_ad": f"P248 Amir {uuid.uuid4().hex[:6]}"},
    )
    assert r.status_code == 201, r.text
    j = r.json()
    return {
        "tesis_kodu": j["tesis_kodu"],
        "yh": {"Authorization": f"Bearer {j['jetonlar']['access_token']}"},
    }


def _ekle(client, t, rol: str) -> tuple[str, str]:
    """Yonetici `POST /users` ile ekler — gercek davet yolu."""
    e = _eposta(rol)
    r = client.post(
        "/users", headers=t["yh"], json={"ad": "P248 Kişi", "email": e, "role": rol}
    )
    assert r.status_code == 201, r.text
    assert r.json()["role"] == rol
    return e, r.json()["id"]


def _eposta_kaydi(client, owner_conn, t, eposta: str, beyan: str):
    """rol-eposta-basla -> kod -> rol-eposta-dogrula -> set-password."""
    r = client.post(
        "/auth/kayit/rol-eposta-basla",
        json={"tesis_kodu": t["tesis_kodu"], "eposta": eposta, "rol": beyan},
    )
    assert r.status_code == 200, r.text
    _kodu_ayarla(owner_conn, eposta)
    r = client.post(
        "/auth/kayit/rol-eposta-dogrula",
        json={"tesis_kodu": t["tesis_kodu"], "eposta": eposta, "kod": KOD},
    )
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "hazir", r.text
    r = client.post(
        "/auth/set-password",
        json={"setup_token": r.json()["setup_token"], "new_password": PAROLA},
    )
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


# --------------------------------------------------------------------------- #
# Kabul 1: yonetici DOGRUDAN amir ekler; davet Tesis ID tasir
# --------------------------------------------------------------------------- #
def test_yonetici_dogrudan_amir_ekler_ve_davet_tesis_id_tasir(client, owner_conn, tesis):
    r = client.get("/users/acilabilir-roller", headers=tesis["yh"])
    assert r.status_code == 200
    assert "guvenlik_amiri" in r.json()["roller"]

    e, uid = _ekle(client, tesis, "guvenlik_amiri")
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT govde FROM mesaj_gonderim WHERE user_id = %s AND kanal = 'eposta' "
            "ORDER BY created_at DESC LIMIT 1",
            (uid,),
        )
        satir = cur.fetchone()
    assert satir is not None, "amir icin davet e-postasi yazilmadi"
    assert tesis["tesis_kodu"] in satir[0], "davet e-postasinda Tesis ID yok"


# --------------------------------------------------------------------------- #
# Kabul 2: davet edilen amir ONAYSIZ girer — her yol, rol HESAPTAN
# --------------------------------------------------------------------------- #
@pytest.mark.parametrize("beyan", ["guvenlik_amiri", "security"])
def test_davet_edilen_amir_eposta_ile_onaysiz_girer(client, owner_conn, tesis, beyan):
    """Beyan `security` iken de: eskiden `rol_uyusmuyor` + kod gonderilmiyordu."""
    e, _ = _ekle(client, tesis, "guvenlik_amiri")
    erisim = _eposta_kaydi(client, owner_conn, tesis, e, beyan)
    assert _rol(erisim) == "guvenlik_amiri"
    assert _kuyruk(owner_conn, e) == []


@pytest.mark.parametrize("beyan", ["guvenlik_amiri", "security", None])
def test_davet_edilen_amir_sso_ile_onaysiz_girer(client, owner_conn, tesis, beyan):
    """Beyansiz (giriste tamamlama) dahil — kullanicinin gordugu 'onay bekliyor'."""
    e, _ = _ekle(client, tesis, "guvenlik_amiri")
    govde = {"baglama_jetonu": _sso_jeton(e), "tesis_kodu": tesis["tesis_kodu"]}
    if beyan:
        govde["rol"] = beyan
    r = client.post("/auth/oauth/rol-tamamla", json=govde)
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "giris", r.text
    assert _rol(r.json()["jetonlar"]["access_token"]) == "guvenlik_amiri"
    assert _kuyruk(owner_conn, e) == []


# --------------------------------------------------------------------------- #
# Kabul 3: davet EDILMEMIS kisi amir olamaz — kuyruk KORUNDU
# --------------------------------------------------------------------------- #
def test_davet_edilmemis_amir_beyani_kuyruga_duser(client, owner_conn, tesis):
    yabanci = _eposta("yabanci")
    r = client.post(
        "/auth/kayit/rol-eposta-basla",
        json={"tesis_kodu": tesis["tesis_kodu"], "eposta": yabanci, "rol": "guvenlik_amiri"},
    )
    assert r.status_code == 200, r.text
    # SIZINTI YOK: yanit eslesmeyi soylemez.
    assert r.json()["durum"] == "kod_gonderildi"
    assert _kuyruk(owner_conn, yabanci) == [("guvenlik_amiri", "liste_disi")]
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM kayit_dogrulama WHERE eposta = %s AND amac = 'kayit'",
            (yabanci,),
        )
        assert cur.fetchone()[0] == 0, "listede olmayan adrese kod URETILDI"
        cur.execute("SELECT count(*) FROM app_user WHERE lower(email) = %s", (yabanci,))
        assert cur.fetchone()[0] == 0


def test_davet_edilmemis_amir_sso_onay_bekliyor(client, owner_conn, tesis):
    yabanci = _eposta("yabanci-sso")
    r = client.post(
        "/auth/oauth/rol-tamamla",
        json={
            "baglama_jetonu": _sso_jeton(yabanci),
            "tesis_kodu": tesis["tesis_kodu"],
            "rol": "guvenlik_amiri",
        },
    )
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "onay_bekliyor"
    assert r.json().get("jetonlar") is None
    assert _kuyruk(owner_conn, yabanci) == [("guvenlik_amiri", "liste_disi")]


# --------------------------------------------------------------------------- #
# Yetki yukseltmesi YOK
# --------------------------------------------------------------------------- #
def test_amir_beyan_eden_guvenlik_GUVENLIK_olarak_girer(client, owner_conn, tesis):
    e, _ = _ekle(client, tesis, "security")
    erisim = _eposta_kaydi(client, owner_conn, tesis, e, "guvenlik_amiri")
    assert _rol(erisim) == "security", "beyan rolu YUKSELTTI"
    with owner_conn.cursor() as cur:
        cur.execute("SELECT role FROM app_user WHERE lower(email) = %s", (e,))
        assert cur.fetchone()[0] == "security"


def test_amir_beyani_aile_disinda_hala_uyusmuyor(client, owner_conn, tesis):
    """Tesis gorevlisi 'amir' diyerek onaysiz giremez (aile disi)."""
    e, _ = _ekle(client, tesis, "tesis_gorevlisi")
    r = client.post(
        "/auth/kayit/rol-eposta-basla",
        json={"tesis_kodu": tesis["tesis_kodu"], "eposta": e, "rol": "guvenlik_amiri"},
    )
    assert r.status_code == 200, r.text
    assert _kuyruk(owner_conn, e) == [("guvenlik_amiri", "rol_uyusmuyor")]


# --------------------------------------------------------------------------- #
# Kabul 4 (backend payi): yonetici amiri web/mobilden YONETMEYE devam eder
# --------------------------------------------------------------------------- #
def test_yonetici_guvenligi_amir_yapar_ve_geri_dusurur(client, tesis):
    _, uid = _ekle(client, tesis, "security")
    for rol in ("guvenlik_amiri", "security"):
        r = client.patch(f"/users/{uid}", headers=tesis["yh"], json={"role": rol})
        assert r.status_code == 200, r.text
        assert r.json()["role"] == rol
    # Amir kaydi uzerinde duzenleme de acik.
    _, aid = _ekle(client, tesis, "guvenlik_amiri")
    r = client.patch(f"/users/{aid}", headers=tesis["yh"], json={"ad": "Yeni Ad"})
    assert r.status_code == 200, r.text
