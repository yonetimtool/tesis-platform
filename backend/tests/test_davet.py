"""(P155 / §7) DAVET JETONU — cozme, tamamlama (parola/sosyal), yasam dongusu.

Davet, yoneticinin ACTIGI parolasiz hesaba giden jetonlu kayit bagidir.
Jeton cozuldugunde tesis/rol/daire/telefon bellidir; kullanici yalniz
yontem secer. SMS YOK (jeton + saglayici kimligi SMS'in yerini tutar).

Jeton DUZ METIN saklanmaz (sha256). Test, `_kodu_al` desenini izler:
bilinen bir jetonun hash'ini davet satirina yazip ucu o duz jetonla
cagirir — olculen sey jeton uretimi degil, AKISIN kendisi.
"""
from __future__ import annotations

import hashlib
import uuid
from datetime import datetime, timedelta, timezone


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _tel() -> str:
    return "+9057" + str(uuid.uuid4().int)[:8]


def _hash(jeton: str) -> str:
    return hashlib.sha256(jeton.encode()).hexdigest()


def _davet_yaz(owner_conn, slug, *, rol="resident", telefon=None, daire=None,
               gecerlilik_gun=30, jeton="bilinen-davet-jetonu"):
    """Parolasiz hesap + (sakinse) daire + bilinen jetonlu davet olusturur.

    Doner: (user_id, jeton).
    """
    telefon = telefon or _tel()
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, telefon, password_hash, "
            "  password_set, role, is_active) "
            "SELECT id, %s, %s, NULL, false, %s::user_role, true "
            "FROM tenant WHERE slug = %s RETURNING id, tenant_id",
            (f"Davetli {rol}", telefon, rol, slug),
        )
        uid, tid = cur.fetchone()
        if daire is not None:
            cur.execute(
                "INSERT INTO unit (tenant_id, blok, no) VALUES (%s, 'A', %s) "
                "RETURNING id",
                (tid, daire),
            )
            unit_id = cur.fetchone()[0]
            cur.execute(
                "INSERT INTO unit_resident (tenant_id, unit_id, user_id, rol_tipi) "
                "VALUES (%s, %s, %s, 'malik')",
                (tid, unit_id, uid),
            )
        son = datetime.now(timezone.utc) + timedelta(days=gecerlilik_gun)
        cur.execute(
            "INSERT INTO davet (tenant_id, user_id, jeton_hash, son_gecerlilik) "
            "VALUES (%s, %s, %s, %s)",
            (tid, uid, _hash(jeton), son),
        )
    return uid, jeton


# ============================ COZME ======================================= #

def test_coz_sakin_daire_getirir(client, world, owner_conn):
    _, jeton = _davet_yaz(owner_conn, world["slug_a"], rol="resident",
                          daire=f"D-{uuid.uuid4().hex[:4]}")
    r = client.post("/davet/coz", json={"jeton": jeton})
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["rol"] == "resident"
    assert d["daire_no"]           # sakinde daire dolu
    assert "***" in d["telefon_maskeli"]
    assert d["tesis_ad"]


def test_coz_yonetici_daire_YOK(client, world, owner_conn):
    _davet_yaz(owner_conn, world["slug_a"], rol="yonetici",
               jeton="yonetici-daviti")
    r = client.post("/davet/coz", json={"jeton": "yonetici-daviti"})
    assert r.status_code == 200, r.text
    assert r.json()["daire_no"] is None


def test_BILINMEYEN_jeton_404(client):
    r = client.post("/davet/coz", json={"jeton": "hic-boyle-jeton-yok-xyz"})
    assert r.status_code == 404


def test_SURESI_DOLMUS_jeton_410(client, world, owner_conn):
    _davet_yaz(owner_conn, world["slug_a"], gecerlilik_gun=-1,
               jeton="bayat-jeton")
    r = client.post("/davet/coz", json={"jeton": "bayat-jeton"})
    assert r.status_code == 410
    assert r.json()["error"]["code"] == "gone"


# ========================= PAROLA TAMAMLAMA =============================== #

def test_parola_ile_TAMAMLA_ve_gir(client, world, owner_conn):
    tel = _tel()
    _davet_yaz(owner_conn, world["slug_a"], rol="resident", telefon=tel,
               daire=f"D-{uuid.uuid4().hex[:4]}", jeton="parola-daviti")

    r = client.post("/davet/parola", json={
        "jeton": "parola-daviti", "ad": "Gerçek Ad", "new_password": "DavetParola1!"})
    assert r.status_code == 200, r.text
    assert r.json()["access_token"]

    # Artik telefon + parola ile girebiliyor.
    lp = client.post("/auth/login-phone", json={"phone": tel, "password": "DavetParola1!"})
    assert lp.status_code == 200 and lp.json()["password_setup_required"] is False


def test_TEK_KULLANIM_ikinci_parola_410(client, world, owner_conn):
    _davet_yaz(owner_conn, world["slug_a"], jeton="tek-kullanim",
               daire=f"D-{uuid.uuid4().hex[:4]}")
    ilk = client.post("/davet/parola", json={
        "jeton": "tek-kullanim", "new_password": "DavetParola1!"})
    assert ilk.status_code == 200, ilk.text
    # Ayni jeton ikinci kez GECMEZ (used_at + password_set).
    ikinci = client.post("/davet/parola", json={
        "jeton": "tek-kullanim", "new_password": "BaskaParola2!"})
    assert ikinci.status_code == 410


def test_zayif_parola_422(client, world, owner_conn):
    _davet_yaz(owner_conn, world["slug_a"], jeton="zayif-parola",
               daire=f"D-{uuid.uuid4().hex[:4]}")
    r = client.post("/davet/parola", json={"jeton": "zayif-parola", "new_password": "kisa"})
    assert r.status_code == 422


# ===================== SAKIN EKLEME -> DAVET GONDER ======================= #

def test_sakin_eklemede_DAVET_gonderilir(client, world):
    """POST /residents parolasiz hesap acar VE davet gonderir (LogSms)."""
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/residents", headers=yon, json={
        "telefon": _tel(), "unit_no": f"DV-{uuid.uuid4().hex[:4]}"})
    assert r.status_code == 201, r.text
    davet = r.json()["davet"]
    assert davet is not None
    # LogSms saglayicisi "gonderildi" doner (gercek gecit yapilandirilirsa
    # yalniz ortam degisir).
    assert davet["gonderildi"] is True
    assert davet["kanal"] == "sms"


def test_parola_ILE_acilan_sakine_davet_YOK(client, world):
    """Parola verilirse hesap zaten girebilir; davet anlamsiz."""
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/residents", headers=yon, json={
        "telefon": _tel(), "unit_no": f"DV-{uuid.uuid4().hex[:4]}",
        "password": "DogrudanParola1!"})
    assert r.status_code == 201, r.text
    assert r.json()["davet"] is None


# ======================= YONETICI: DAVET PANELI ========================== #

def test_yonetici_davet_LISTELER_ve_yeniden_gonderir(client, world, owner_conn):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    uid, _ = _davet_yaz(owner_conn, world["slug_a"], rol="resident",
                        daire=f"D-{uuid.uuid4().hex[:4]}", jeton="panel-daviti")

    liste = client.get("/davet", headers=yon)
    assert liste.status_code == 200, liste.text
    kayitlar = liste.json()["items"]
    assert any(str(k["user_id"]) == str(uid) for k in kayitlar)

    # Yeniden gonder: taze jeton + gonderim.
    yeniden = client.post(f"/davet/{uid}/yeniden", headers=yon)
    assert yeniden.status_code == 200, yeniden.text
    assert yeniden.json()["son_kanal"] == "sms"


def test_davet_paneli_ROL_KAPISI(client, world, owner_conn):
    """Sakin davet panelini goremez (yalniz admin/yonetici)."""
    # Once bir sakin acalim ve onunla girelim.
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    tel = _tel()
    client.post("/residents", headers=yon, json={
        "telefon": tel, "unit_no": f"DV-{uuid.uuid4().hex[:4]}",
        "password": "SakinParola1!"})
    sakin = client.post("/auth/login-phone", json={"phone": tel, "password": "SakinParola1!"})
    assert sakin.status_code == 200, sakin.text
    h = {"Authorization": f"Bearer {sakin.json()['access_token']}"}
    assert client.get("/davet", headers=h).status_code == 403
