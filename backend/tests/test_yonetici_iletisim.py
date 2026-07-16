"""GET /yonetici-iletisim — yonetici iletisim dizini.

GIZLILIK ISTISNASI (contracts/auth.md): bu uc C1a'nin uc kapisini (YON + RIZA +
NUMARA VARLIGI) YALNIZ yonetici kartlari icin deler. Yonetici bir HIZMET
rolüdür; numarayi admin bilerek girer. C1a modeli baska her sey icin korunur.
"""
from __future__ import annotations


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={
            "tenant_slug": slug,
            "email": cred["email"],
            "password": cred["password"],
        },
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _yonetici_id(owner_conn, tenant_id, ad):
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM app_user WHERE tenant_id = %s AND ad = %s",
            (tenant_id, ad),
        )
        return str(cur.fetchone()[0])


def test_saha_rolleri_ve_sakin_yoneticileri_gorur(client, world):
    """Uc rol de (security / tesis_gorevlisi / resident) dizini gorur."""
    for cred in (world["guard_a"], world["gorevli_a"], world["resident_a"]):
        h = _headers(client, world["slug_a"], cred)
        r = client.get("/yonetici-iletisim", headers=h)
        assert r.status_code == 200, r.text
        body = r.json()
        assert len(body["yoneticiler"]) >= 1
        kart = body["yoneticiler"][0]
        assert kart["ad_soyad"] == "Yonetici A"
        assert kart["telefon"] == "+905000000002"
        assert "yonetim_email" in body


def test_yonetim_email_doner(client, world, owner_conn):
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE tenant SET yonetim_email = %s WHERE id = %s",
            ("yonetim@a.com", world["a"]),
        )
    h = _headers(client, world["slug_a"], world["guard_a"])
    r = client.get("/yonetici-iletisim", headers=h)
    assert r.status_code == 200, r.text
    assert r.json()["yonetim_email"] == "yonetim@a.com"


def test_birincil_listede_ilk(client, world, owner_conn):
    """Ikinci bir yonetici eklenir; BIRINCIL olan liste basinda gelmeli."""
    from app.security import hash_password

    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, email, telefon, password_hash, "
            "password_set, role) VALUES (%s,%s,%s,%s,%s,true,'yonetici'::user_role)",
            (world["a"], "Yonetici A2", "y2@a.com", "+905000000099",
             hash_password("Yonetici123!")),
        )
        # Yonetici A2'yi BIRINCIL yap (A degil) -> siralamayi gercekten test eder.
        cur.execute(
            "UPDATE app_user SET birincil = true WHERE tenant_id = %s AND ad = %s",
            (world["a"], "Yonetici A2"),
        )

    h = _headers(client, world["slug_a"], world["guard_a"])
    r = client.get("/yonetici-iletisim", headers=h)
    assert r.status_code == 200, r.text
    adlar = [y["ad_soyad"] for y in r.json()["yoneticiler"]]
    assert adlar[0] == "Yonetici A2", f"birincil ilk olmali, gelen: {adlar}"
    assert "Yonetici A" in adlar


def test_aranabilir_false_olsa_bile_listelenir(client, world, owner_conn):
    """BILINCLI ISTISNA: sekme aranabilir'i YOKSAYAR (hizmet-rolu dizini).

    C1a'da aranabilir=false => /call-target 404 verir; burada numara YINE doner.
    """
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE app_user SET aranabilir = false WHERE tenant_id = %s AND ad = %s",
            (world["a"], "Yonetici A"),
        )
    h = _headers(client, world["slug_a"], world["guard_a"])
    r = client.get("/yonetici-iletisim", headers=h)
    assert r.status_code == 200, r.text
    kart = [y for y in r.json()["yoneticiler"] if y["ad_soyad"] == "Yonetici A"]
    assert kart, "aranabilir=false yonetici listeden DUSMEMELI"
    assert kart[0]["telefon"] == "+905000000002", "numara riza olmadan da donmeli"


def test_pasif_yonetici_listelenmez(client, world, owner_conn):
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE app_user SET is_active = false WHERE tenant_id = %s AND ad = %s",
            (world["a"], "Yonetici A"),
        )
    h = _headers(client, world["slug_a"], world["guard_a"])
    r = client.get("/yonetici-iletisim", headers=h)
    assert r.status_code == 200, r.text
    adlar = [y["ad_soyad"] for y in r.json()["yoneticiler"]]
    assert "Yonetici A" not in adlar


def test_tenant_izolasyonu(client, world, owner_conn):
    """A'nin uyesi B'nin yoneticisini/mailini ASLA gormez."""
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE tenant SET yonetim_email = %s WHERE id = %s", ("a@a.com", world["a"])
        )
        cur.execute(
            "UPDATE tenant SET yonetim_email = %s WHERE id = %s", ("b@b.com", world["b"])
        )
    h = _headers(client, world["slug_a"], world["guard_a"])
    r = client.get("/yonetici-iletisim", headers=h)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["yonetim_email"] == "a@a.com"
    adlar = [y["ad_soyad"] for y in body["yoneticiler"]]
    assert "Yonetici B" not in adlar
    assert "+905000000007" not in [y["telefon"] for y in body["yoneticiler"]]


def test_kimliksiz_401(client):
    assert client.get("/yonetici-iletisim").status_code == 401


def test_yonetici_de_erisebilir(client, world):
    """Uc, tenant'in HERHANGI bir uyesine acik (rol kapisi yok) — sekme
    yonetici'ye gosterilmese de uc onu reddetmez."""
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    assert client.get("/yonetici-iletisim", headers=h).status_code == 200
