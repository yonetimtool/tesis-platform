"""(P247-bekleyen) Kullanicinin iki karari — sunucu tarafinda suzme.

1.1 IZIN NOTU: tarih ve tur ekipte gorunur; `not_metni` yalniz izni alan
    kisiye, amirine ve yonetime. Digerlerine ANAHTAR HIC DONMEZ.
1.2 DAIRE NOTLARI: "saha personeli gorebilir" isareti — varsayilan kapali,
    yalniz yonetim koyar/kaldirir, isaretsiz not saha rolune hic donmez.
"""
from __future__ import annotations

import datetime as dt
import uuid

NOT = "doktor raporu — ameliyat"


def _giris(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _id(client, h):
    return client.get("/me", headers=h).json()["id"]


# ============================ 1.1 IZIN NOTU ================================ #
def _izin(client, yon, user_id, gun):
    r = client.post("/vardiya-izin", headers=yon, json={
        "user_id": user_id, "tur": "yillik", "baslangic": str(gun), "bitis": str(gun),
        "not_metni": NOT})
    assert r.status_code == 201, r.text
    return r.json()["id"]


def _satir(client, h, izin_id, gun):
    r = client.get("/vardiya-izin", headers=h,
                   params={"baslangic": str(gun), "bitis": str(gun), "limit": 500})
    assert r.status_code == 200, r.text
    return next((i for i in r.json()["items"] if i["id"] == izin_id), None)


def test_IZIN_NOTU_YALNIZ_SAHIBI_AMIRI_YONETIM(client, world):
    slug = world["slug_a"]
    yon = _giris(client, slug, world["yonetici_a"])
    guard = _giris(client, slug, world["guard_a"])
    gorevli = _giris(client, slug, world["gorevli_a"])
    amir = _giris(client, slug, world["amir_a"])
    gun = dt.date.today() + dt.timedelta(days=40 + uuid.uuid4().int % 200)
    izin_id = _izin(client, yon, _id(client, guard), gun)

    # Olusturan yonetim, yanitta notu gorur.
    assert _satir(client, yon, izin_id, gun)["not_metni"] == NOT
    # Izni alan kisi ve amiri (guvenlik ekibi) gorur.
    assert _satir(client, guard, izin_id, gun)["not_metni"] == NOT
    assert _satir(client, amir, izin_id, gun)["not_metni"] == NOT
    # Ekipten baska biri: tarih ve tur GORUNUR, not ANAHTARI HIC YOK.
    s = _satir(client, gorevli, izin_id, gun)
    assert s is not None and s["tur"] == "yillik" and s["baslangic"] == str(gun)
    assert "not_metni" not in s, s
    # Ham yanitta da metin gecmiyor (baska bir alana sizmadi).
    ham = client.get("/vardiya-izin", headers=gorevli,
                     params={"baslangic": str(gun), "bitis": str(gun)}).text
    assert NOT not in ham


def test_IZIN_NOTU_TESIS_GOREVLISININ_IZNI_GUVENLIGE_DONMEZ(client, world):
    slug = world["slug_a"]
    yon = _giris(client, slug, world["yonetici_a"])
    guard = _giris(client, slug, world["guard_a"])
    gorevli = _giris(client, slug, world["gorevli_a"])
    gun = dt.date.today() + dt.timedelta(days=260 + uuid.uuid4().int % 90)
    izin_id = _izin(client, yon, _id(client, gorevli), gun)
    s = _satir(client, guard, izin_id, gun)
    assert s is not None and "not_metni" not in s
    assert _satir(client, gorevli, izin_id, gun)["not_metni"] == NOT


# =========================== 1.2 DAIRE NOTLARI ============================= #
def _daire(owner_conn, slug) -> str:
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO unit (tenant_id, blok, no) "
            "SELECT id, 'A', %s FROM tenant WHERE slug = %s RETURNING id",
            (f"S-{uuid.uuid4().hex[:5]}", slug),
        )
        return str(cur.fetchone()[0])


def _notlar(client, h, unit_id):
    r = client.get("/ekler", headers=h, params={"varlik_tipi": "unit", "varlik_id": unit_id})
    assert r.status_code == 200, r.text
    return r.json()["items"]


def test_DAIRE_NOTU_VARSAYILAN_KAPALI_YALNIZ_YONETIM_ACAR(client, world, owner_conn):
    slug = world["slug_a"]
    yon = _giris(client, slug, world["yonetici_a"])
    guard = _giris(client, slug, world["guard_a"])
    gorevli = _giris(client, slug, world["gorevli_a"])
    unit_id = _daire(owner_conn, slug)

    gizli = "borc anlasmazligi — gizli"
    r = client.post("/ekler", headers=yon, json={
        "varlik_tipi": "unit", "varlik_id": unit_id, "tur": "not", "metin": gizli})
    assert r.status_code == 201 and r.json()["saha_gorebilir"] is False
    ek_id = r.json()["id"]

    # VARSAYILAN KAPALI: saha rolune hic donmez — metin agda bile yok.
    for h in (guard, gorevli):
        assert _notlar(client, h, unit_id) == []
        assert gizli not in client.get(
            "/ekler", headers=h, params={"varlik_tipi": "unit", "varlik_id": unit_id}).text
    assert [e["id"] for e in _notlar(client, yon, unit_id)] == [ek_id]

    # Saha isareti koyamaz/kaldiramaz.
    for h in (guard, gorevli):
        assert client.patch(f"/ekler/{ek_id}", headers=h,
                            json={"saha_gorebilir": True}).status_code == 403

    # Yonetim acar -> saha gorur; kapatir -> yine gormez.
    r = client.patch(f"/ekler/{ek_id}", headers=yon, json={"saha_gorebilir": True})
    assert r.status_code == 200 and r.json()["saha_gorebilir"] is True
    assert [e["metin"] for e in _notlar(client, guard, unit_id)] == [gizli]
    assert client.patch(f"/ekler/{ek_id}", headers=yon,
                        json={"saha_gorebilir": False}).status_code == 200
    assert _notlar(client, gorevli, unit_id) == []

    # Olustururken acik isaret: dogrudan gorunur.
    r = client.post("/ekler", headers=yon, json={
        "varlik_tipi": "unit", "varlik_id": unit_id, "tur": "not",
        "metin": "kapi kodu 1234", "saha_gorebilir": True})
    assert r.status_code == 201
    assert [e["metin"] for e in _notlar(client, guard, unit_id)] == ["kapi kodu 1234"]

    # Denetim izi.
    with owner_conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM audit_log WHERE action = 'ek_saha_gorunurlugu' "
                    "AND resource_id = %s", (ek_id,))
        assert cur.fetchone()[0] == 2


def test_SAHA_ISARETI_YALNIZ_DAIRE_EKINDE(client, world, owner_conn):
    slug = world["slug_a"]
    yon = _giris(client, slug, world["yonetici_a"])
    uid = _id(client, _giris(client, slug, world["guard_a"]))
    r = client.post("/ekler", headers=yon, json={
        "varlik_tipi": "app_user", "varlik_id": uid, "tur": "not",
        "metin": "x", "saha_gorebilir": True})
    assert r.status_code == 422, r.text
    assert r.json()["error"]["code"] == "validation_error"
    r = client.post("/ekler", headers=yon, json={
        "varlik_tipi": "app_user", "varlik_id": uid, "tur": "not", "metin": "x"})
    assert r.status_code == 201
    # Daire eki olmayan ek bu uctan ACILAMAZ — varligi da sizmaz.
    assert client.patch(f"/ekler/{r.json()['id']}", headers=yon,
                        json={"saha_gorebilir": True}).status_code == 404
    assert client.patch(f"/ekler/{uuid.uuid4()}", headers=yon,
                        json={"saha_gorebilir": True}).status_code == 404


def test_GOC_MEVCUT_NOTLARI_KAPALI_YAZAR(owner_conn):
    """Goc 0155 sonrasi isaretli bir eski not olamaz: kolon varsayilani
    false ve goc ayrica tum satirlari false yazar."""
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT column_default, is_nullable FROM information_schema.columns "
            "WHERE table_name = 'varlik_eki' AND column_name = 'saha_gorebilir'")
        varsayilan, bos = cur.fetchone()
    assert varsayilan == "false" and bos == "NO"
