"""(P253 acil) DAVET AKISI — ISTEGE BAGLI ALANLAR BOSKEN UCTAN UCA.

OLCULEN KUSUR (prod): telefonsuz davetli `POST /davet/coz`ta 500 aliyordu
(`len(None)` maskelemede). Kisi kaydini tamamlayamiyor, parola hic
atanmiyor, giris yapamiyor ve "beni tanimiyor" saniyordu.

NEDEN TESTTEN GECTI: `test_davet._davet_yaz` telefon verilmezse KENDISI
uyduruyordu (`telefon or _tel()`) ve API uzerinden davet kuran her test
telefon gonderiyordu — telefonsuz davetli testlerde HIC VAR OLMADI.

Bu kilit davet akisini telefon, soyad, daire ve blok BOS iken her rolde
surer: coz -> parola -> e-postayla giris; ayrica GERCEK kullanici ekleme
yolundan (telefonsuz) olusan daveti, yonetici listesini ve yeniden
gondermeyi.
"""
from __future__ import annotations

import hashlib
import uuid
from datetime import datetime, timedelta, timezone

import pytest


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _hash(jeton: str) -> str:
    return hashlib.sha256(jeton.encode()).hexdigest()


def _bos_davetli(owner_conn, slug, rol, jeton):
    """Telefon, soyad, daire, blok YOK — yalniz ad + e-posta."""
    eposta = f"bos-{uuid.uuid4().hex[:10]}@ornek.com"
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, soyad, telefon, email, "
            "  password_hash, password_set, role, is_active) "
            "SELECT id, %s, NULL, NULL, %s, NULL, false, %s::user_role, true "
            "FROM tenant WHERE slug = %s RETURNING id, tenant_id",
            (f"Bos {rol}", eposta, rol, slug),
        )
        uid, tid = cur.fetchone()
        cur.execute(
            "INSERT INTO davet (tenant_id, user_id, jeton_hash, son_gecerlilik) "
            "VALUES (%s, %s, %s, %s)",
            (tid, uid, _hash(jeton), datetime.now(timezone.utc) + timedelta(days=7)),
        )
    return uid, eposta


@pytest.mark.parametrize("rol", ["resident", "tesis_gorevlisi", "security", "yonetici"])
def test_TELEFONSUZ_SOYADSIZ_DAIRESIZ_davetli_kaydi_TAMAMLAR(client, world, owner_conn, rol):
    jeton = f"bos-{rol}-{uuid.uuid4().hex[:8]}"
    _, eposta = _bos_davetli(owner_conn, world["slug_a"], rol, jeton)

    coz = client.post("/davet/coz", json={"jeton": jeton})
    assert coz.status_code == 200, coz.text
    d = coz.json()
    # Telefon yok -> BOS dize (None degil: eski mobil surumler String bekler).
    assert d["telefon_maskeli"] == ""
    assert d["daire_no"] is None and d["soyad"] is None

    r = client.post("/davet/parola", json={"jeton": jeton, "new_password": "BosDavet1!"})
    assert r.status_code == 200, r.text
    giris = client.post("/auth/login", json={
        "tenant_slug": world["slug_a"], "email": eposta, "password": "BosDavet1!"})
    assert giris.status_code == 200, giris.text


def test_GERCEK_YOL_telefonsuz_kullanici_ekle_davet_coz_tamamla(client, world, owner_conn):
    """Yonetici ekranindan telefon OLMADAN eklenen kisi: davet olusur,
    listede gorunur, yeniden gonderilir, cozulur ve tamamlanir."""
    yon = _h(client, world["slug_a"], world["yonetici_a"])
    eposta = f"gercek-{uuid.uuid4().hex[:10]}@ornek.com"
    r = client.post("/users", headers=yon, json={
        "ad": "Telefonsuz", "soyad": None, "email": eposta, "role": "tesis_gorevlisi"})
    assert r.status_code == 201, r.text
    uid = r.json()["id"]

    liste = client.get("/davet", headers=yon)
    assert liste.status_code == 200, liste.text
    assert any(str(k["user_id"]) == str(uid) for k in liste.json()["items"])
    yeniden = client.post(f"/davet/{uid}/yeniden", headers=yon)
    assert yeniden.status_code == 200, yeniden.text

    # Jeton e-postada gider; test bilinen bir jetonu bu davete yazar.
    jeton = f"gercek-{uuid.uuid4().hex[:8]}"
    owner_conn.execute(
        "UPDATE davet SET jeton_hash = %s WHERE user_id = %s AND used_at IS NULL",
        (_hash(jeton), uid))
    coz = client.post("/davet/coz", json={"jeton": jeton})
    assert coz.status_code == 200, coz.text
    assert coz.json()["telefon_maskeli"] == ""
    tamam = client.post("/davet/parola", json={
        "jeton": jeton, "ad": "Telefonsuz", "soyad": "Kisi", "new_password": "GercekYol1!"})
    assert tamam.status_code == 200, tamam.text


def test_MASKE_bos_ve_dolu():
    from app.telefon_maskesi import telefon_maskele

    assert telefon_maskele(None) == ""
    assert telefon_maskele("") == ""
    assert telefon_maskele("   ") == ""
    assert telefon_maskele("12345") == "*****"
    assert telefon_maskele("+905321234567") == "+9053***567"
