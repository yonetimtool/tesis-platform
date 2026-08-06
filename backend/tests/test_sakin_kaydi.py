"""(P148) Sakinin KENDI kaydi — tesis kodu + daire + telefon dogrulamasi.

GUVEN SINIRI NOTU: bu akista daire SAHIPLIGI dogrulanmiyor (Kerem'in acik
karari). Dolayisiyla burada "yetkisiz kisi kaydolamaz" diye bir test YOKTUR
ve olmamasi bilinclidir — testler kararin UYGULANDIGINI olcer, kararin
kendisini savunmaz.
"""
import uuid


def _kod(client, owner_conn, slug):
    with owner_conn.cursor() as cur:
        cur.execute("SELECT kayit_kodu FROM tenant WHERE slug = %s", (slug,))
        return cur.fetchone()[0]


def _daire(owner_conn, slug):
    """Tesiste daire YOKSA acar — `world` fixture'i daire kurmuyor."""
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT no FROM unit WHERE tenant_id = "
            "(SELECT id FROM tenant WHERE slug = %s) LIMIT 1", (slug,)
        )
        satir = cur.fetchone()
        if satir:
            return satir[0]
        no = f"A-{uuid.uuid4().hex[:4]}"
        cur.execute(
            "INSERT INTO unit (tenant_id, blok, no) SELECT id, 'A', %s "
            "FROM tenant WHERE slug = %s", (no, slug),
        )
        return no


def _tel():
    return "+9059" + str(uuid.uuid4().int)[:8]


def test_kayit_baslar_kod_DONMEZ(client, world, owner_conn):
    tel = _tel()
    r = client.post("/auth/kayit/basla", json={
        "tesis_kodu": _kod(client, owner_conn, world["slug_a"]),
        "daire_no": _daire(owner_conn, world["slug_a"]),
        "telefon": tel,
    })
    assert r.status_code == 200, r.text
    govde = r.json()
    assert "kod" not in str(govde).lower() or "tesis_kodu" not in govde
    # Telefon MASKELI doner — ekranda "kod nereye gitti" gosterilir.
    assert "***" in govde["telefon_maskeli"]


def test_yanlis_tesis_kodu_ve_yanlis_daire_AYNI_hatayi_verir(client, world, owner_conn):
    """Adimlar ayirt edilebilseydi tesisin daire listesi disariya sizardi."""
    dogru = _kod(client, owner_conn, world["slug_a"])
    a = client.post("/auth/kayit/basla", json={
        "tesis_kodu": "YOKBOYLE", "daire_no": "1", "telefon": _tel()})
    b = client.post("/auth/kayit/basla", json={
        "tesis_kodu": dogru, "daire_no": "yok-boyle-daire", "telefon": _tel()})
    assert a.status_code == b.status_code == 422
    assert a.json()["error"]["code"] == b.json()["error"]["code"]


def test_var_olan_telefon_ikinci_kez_kaydolamaz(client, world, owner_conn):
    """Telefon KIMLIGIN kendisi — iki kullaniciya ait olamaz."""
    r = client.post("/auth/kayit/basla", json={
        "tesis_kodu": _kod(client, owner_conn, world["slug_a"]),
        "daire_no": _daire(owner_conn, world["slug_a"]),
        "telefon": world["resident_a"].get("telefon") or "+905000000101",
    })
    assert r.status_code == 422, r.text


def test_dogru_kod_PAROLASIZ_kullanici_acar_ve_daireye_baglar(
    client, world, owner_conn
):
    tel = _tel()
    assert client.post("/auth/kayit/basla", json={
        "tesis_kodu": _kod(client, owner_conn, world["slug_a"]),
        "daire_no": _daire(owner_conn, world["slug_a"]),
        "telefon": tel,
    }).status_code == 200

    # Kod gunluge DUZ METIN yazilmaz (P134); testte bilinen bir hash konur.
    from app.security import hash_password
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE kayit_dogrulama SET kod_hash = %s WHERE telefon = %s",
            (hash_password("123456"), tel),
        )

    r = client.post("/auth/kayit/dogrula",
                    json={"telefon": tel, "kod": "123456", "ad": "Yeni Sakin"})
    assert r.status_code == 200, r.text
    assert r.json()["access_token"]

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT password_hash, password_set, role FROM app_user "
            "WHERE telefon = %s", (tel,)
        )
        ph, pset, role = cur.fetchone()
        # PAROLA YOK — kimlik dogrulanmis telefondur.
        assert ph is None and pset is False and role == "resident"
        cur.execute(
            "SELECT count(*) FROM unit_resident ur JOIN app_user u "
            "ON u.id = ur.user_id WHERE u.telefon = %s", (tel,)
        )
        assert cur.fetchone()[0] == 1, "kullanici daireye BAGLANMALI"
        # Bekleyen kayit TUKETILDI — kod tekrar kullanilamaz.
        cur.execute("SELECT count(*) FROM kayit_dogrulama WHERE telefon = %s", (tel,))
        assert cur.fetchone()[0] == 0


def test_yanlis_kod_DENEME_sayar_ve_besten_sonra_kapanir(client, world, owner_conn):
    """Kaba kuvvet: 6 haneli kod sayilmadan dakikalar icinde bulunur.

    BU TEST BIR KEZ BOSA GECTI ve dersi buraya yaziliyor: son cagriya
    `ad="X"` gonderiyordum, sema ise `min_length=2` istiyor. Donen 422
    kaba kuvvet korumasindan DEGIL Pydantic dogrulamasindan geliyordu —
    koruma tamamen kirikken (sayac her istekte geri sariliyordu) test
    yesildi. Artik (a) gecerli `ad` gonderiliyor, (b) sayacin GERCEKTEN
    arttigi VERITABANINDAN okunuyor.
    """
    tel = _tel()
    client.post("/auth/kayit/basla", json={
        "tesis_kodu": _kod(client, owner_conn, world["slug_a"]),
        "daire_no": _daire(owner_conn, world["slug_a"]),
        "telefon": tel,
    })
    from app.security import hash_password
    with owner_conn.cursor() as cur:
        cur.execute("UPDATE kayit_dogrulama SET kod_hash = %s WHERE telefon = %s",
                    (hash_password("123456"), tel))
    for i in range(5):
        assert client.post("/auth/kayit/dogrula", json={
            "telefon": tel, "kod": "000000", "ad": "Ali Veli"}).status_code == 422
        # Sayac KALICI olmali: ayni islemde tutulsaydi 422 onu geri sarardi.
        with owner_conn.cursor() as cur:
            cur.execute(
                "SELECT deneme FROM kayit_dogrulama WHERE telefon = %s", (tel,))
            assert cur.fetchone()[0] == i + 1, "deneme sayaci KALICI DEGIL"
    # DOGRU kod bile artik kabul edilmez.
    assert client.post("/auth/kayit/dogrula", json={
        "telefon": tel, "kod": "123456", "ad": "Ali Veli"}).status_code == 422
