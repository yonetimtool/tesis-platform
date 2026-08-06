"""(P149) Parolasiz giris + parolasiz hesap silme — TEK kod mekanizmasi."""
import uuid

from app.security import hash_password


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _parolasiz_sakin(client, world, owner_conn):
    """P148 akisinin urettigi kullaniciyi TEMSIL eder: parolasiz + telefonlu."""
    tel = "+9059" + str(uuid.uuid4().int)[:8]
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, telefon, role, password_set) "
            "SELECT id, 'Parolasiz Sakin', %s, 'resident', false "
            "FROM tenant WHERE slug = %s RETURNING id",
            (tel, world["slug_a"]),
        )
        uid = cur.fetchone()[0]
    return tel, uid


def _kodu_ayarla(owner_conn, tel, amac, kod="123456"):
    """Kod gunluge DUZ METIN yazilmaz (P134) — testte bilinen hash konur."""
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE kayit_dogrulama SET kod_hash = %s "
            "WHERE telefon = %s AND amac = %s AND durum = 'telefon_bekliyor'",
            (hash_password(kod), tel, amac),
        )
        assert cur.rowcount == 1, "kod satiri uretilmemis"


def test_parolasiz_kullanici_KODLA_GIRIS_YAPAR(client, world, owner_conn):
    """P148 sakinleri parolasizdi ve HIC GIRIS YAPAMIYORDU."""
    tel, _ = _parolasiz_sakin(client, world, owner_conn)
    assert client.post("/auth/giris/kod-iste",
                       json={"telefon": tel}).status_code == 200
    _kodu_ayarla(owner_conn, tel, "giris")
    r = client.post("/auth/giris/kod-dogrula",
                    json={"telefon": tel, "kod": "123456"})
    assert r.status_code == 200, r.text
    assert r.json()["access_token"]


def test_KAYITSIZ_numara_ayni_yaniti_alir(client):
    """Numara varligi SIZDIRILMAZ — aksi halde bu uc numara sorgusu olurdu."""
    r = client.post("/auth/giris/kod-iste", json={"telefon": "+905999999998"})
    assert r.status_code == 200, r.text


def test_giris_kodu_HESAP_SILMEYI_onaylayamaz(client, world, owner_conn):
    """`amac` ayrimi: tek kod her kapiyi ACMAMALI."""
    tel, _ = _parolasiz_sakin(client, world, owner_conn)
    client.post("/auth/giris/kod-iste", json={"telefon": tel})
    _kodu_ayarla(owner_conn, tel, "giris")
    giris = client.post("/auth/giris/kod-dogrula",
                        json={"telefon": tel, "kod": "123456"})
    h = {"Authorization": f"Bearer {giris.json()['access_token']}"}
    # GIRIS kodu ile silme denemesi -> reddedilir.
    r = client.post("/me/hesap-sil", headers=h, json={"kod": "123456"})
    assert r.status_code == 422, r.text


def test_parolasiz_kullanici_HESABINI_SILEBILIR(client, world, owner_conn):
    """Once silemiyordu: uc kosulsuz parola ariyordu (Play sarti ihlali)."""
    tel, _ = _parolasiz_sakin(client, world, owner_conn)
    client.post("/auth/giris/kod-iste", json={"telefon": tel})
    _kodu_ayarla(owner_conn, tel, "giris")
    giris = client.post("/auth/giris/kod-dogrula",
                        json={"telefon": tel, "kod": "123456"})
    h = {"Authorization": f"Bearer {giris.json()['access_token']}"}

    assert client.post("/me/hesap-sil/kod-iste", headers=h).status_code == 200
    _kodu_ayarla(owner_conn, tel, "hesap_silme")
    r = client.post("/me/hesap-sil", headers=h, json={"kod": "123456"})
    assert r.status_code == 200, r.text

    with owner_conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM app_user WHERE telefon = %s", (tel,))
        assert cur.fetchone()[0] == 0


def test_KODSUZ_silme_reddedilir(client, world, owner_conn):
    """Token'i olan biri tek dokunusla silememeli (P112 kurali korunuyor)."""
    tel, _ = _parolasiz_sakin(client, world, owner_conn)
    client.post("/auth/giris/kod-iste", json={"telefon": tel})
    _kodu_ayarla(owner_conn, tel, "giris")
    giris = client.post("/auth/giris/kod-dogrula",
                        json={"telefon": tel, "kod": "123456"})
    h = {"Authorization": f"Bearer {giris.json()['access_token']}"}
    assert client.post("/me/hesap-sil", headers=h, json={}).status_code == 400


def test_PAROLALI_kullanici_hala_PAROLA_ile_siler(client, world):
    """Mevcut yol BOZULMADI: parolasi olanda kod degil parola gecerli."""
    h = _h(client, world["slug_a"], world["resident_a"])
    r = client.post("/me/hesap-sil", headers=h, json={"kod": "123456"})
    assert r.status_code == 400, r.text
