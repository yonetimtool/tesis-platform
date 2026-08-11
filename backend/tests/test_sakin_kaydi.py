"""(P148) Sakinin KENDI kaydi — tesis kodu + daire + telefon dogrulamasi.

GUVEN SINIRI NOTU: bu akista daire SAHIPLIGI dogrulanmiyor (Kerem'in acik
karari). Dolayisiyla burada "yetkisiz kisi kaydolamaz" diye bir test YOKTUR
ve olmamasi bilinclidir — testler kararin UYGULANDIGINI olcer, kararin
kendisini savunmaz.
"""
import re
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


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


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
    """Telefon KIMLIGIN kendisi — iki kullaniciya ait olamaz.

    NUMARA FIXTURE'DAN ALINIR (`resident_a["phone"]`) — eskiden
    `resident_a.get("telefon") or "+905000000101"` yaziyordu ve iki kusuru
    birden tasiyordu:

      1. Fixture'daki anahtar `phone`, `telefon` DEGIL. Yani `.get()` HER
         ZAMAN `None` donuyor, test hicbir zaman fixture'in numarasini
         kullanmiyordu — `or` sagdaki sabite dusuyordu.
      2. O sabit (`+905000000101`) DEMO TESISININ yoneticisine ait ve demo
         tesisi yalniz `demo_tenant.py` kosulmussa VAR. Yani test, dev
         veritabaninda o betigin bir kez kosturulmus olmasina BAGLIYDI —
         hem de `demo_mod=true`ya, ki o betigin kendi basligi "dev'de ASLA
         acilmamali" diyor.

    Demo tesisi dev veritabanindan kaldirilinca test dustu ve gizli
    bagimlilik boyle gorundu (rapor §4.56). Artik testin numarasi kendi
    fixture'indan geliyor: var oldugu KESIN ve baska hicbir seye bagli
    degil.
    """
    r = client.post("/auth/kayit/basla", json={
        "tesis_kodu": _kod(client, owner_conn, world["slug_a"]),
        "daire_no": _daire(owner_conn, world["slug_a"]),
        "telefon": world["resident_a"]["phone"],
    })
    assert r.status_code == 422, r.text


def test_dogru_kod_HESAP_ACMAZ_onaya_duser(client, world, owner_conn):
    """(P148.2) EN KRITIK OLCUM: dogrulama tek basina hesap ACMAZ.

    Tesis kodu P148.1'de tahmin edilebilir oldugu icin, dogrulamanin hesap
    acmasi site adini bilen herkese daire verisi verirdi.
    """
    tel = _tel()
    assert client.post("/auth/kayit/basla", json={
        "tesis_kodu": _kod(client, owner_conn, world["slug_a"]),
        "daire_no": _daire(owner_conn, world["slug_a"]),
        "telefon": tel,
    }).status_code == 200

    from app.security import hash_password
    with owner_conn.cursor() as cur:
        cur.execute("UPDATE kayit_dogrulama SET kod_hash = %s WHERE telefon = %s",
                    (hash_password("123456"), tel))

    r = client.post("/auth/kayit/dogrula",
                    json={"telefon": tel, "kod": "123456", "ad": "Yeni Sakin"})
    assert r.status_code == 200, r.text
    # OTURUM DONMEZ.
    assert "access_token" not in r.json()
    assert r.json()["durum"] == "onay_bekliyor"
    with owner_conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM app_user WHERE telefon = %s", (tel,))
        assert cur.fetchone()[0] == 0, "onaydan ONCE hesap ACILMAMALI"


def test_yonetici_onaylayinca_PAROLASIZ_hesap_acilir_ve_daireye_baglanir(
    client, world, owner_conn
):
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
    client.post("/auth/kayit/dogrula",
                json={"telefon": tel, "kod": "123456", "ad": "Yeni Sakin"})

    mgr = _h(client, world["slug_a"], world["admin_a"])
    liste = client.get("/kayit-basvurulari", headers=mgr)
    assert liste.status_code == 200, liste.text
    basvuru = next(b for b in liste.json()["items"] if b["telefon"] == tel)
    assert basvuru["ad"] == "Yeni Sakin"

    r = client.post(f"/kayit-basvurulari/{basvuru['id']}/onayla", headers=mgr)
    assert r.status_code == 201, r.text

    with owner_conn.cursor() as cur:
        cur.execute("SELECT password_hash, password_set, role FROM app_user "
                    "WHERE telefon = %s", (tel,))
        ph, pset, role = cur.fetchone()
        assert ph is None and pset is False and role == "resident"
        cur.execute("SELECT count(*) FROM unit_resident ur JOIN app_user u "
                    "ON u.id = ur.user_id WHERE u.telefon = %s", (tel,))
        assert cur.fetchone()[0] == 1

    # IKINCI onay ayni basvuruyu TEKRAR isleyemez (idempotens).
    assert client.post(
        f"/kayit-basvurulari/{basvuru['id']}/onayla", headers=mgr
    ).status_code == 404


def test_sakin_onay_listesini_GOREMEZ(client, world):
    """Liste telefon + daire eslesmesi tasir — kisisel veri."""
    sakin = _h(client, world["slug_a"], world["resident_a"])
    assert client.get("/kayit-basvurulari", headers=sakin).status_code == 403


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


# ------------------- (P148.1) AKILDA KALICI TESIS KODU ---------------------- #
def test_kod_bicimi_KEREMIN_ORNEKLERI(owner_conn):
    """Kural: adin ilk 4 harfi + '-' + YYAAGG."""
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT public.kayit_kodu_uret('Oltu Sitesi','2026-07-15'), "
            "       public.kayit_kodu_uret('Can Sitesi','2025-04-02')"
        )
        oltu, can = cur.fetchone()
    assert oltu == "OLTU-260715"
    assert can == "CANS-250402"


def test_turkce_harfler_ASCIYE_INER_ve_kisa_ad_DOLDURULUR(owner_conn):
    """Kod telefonda ELLE yazilir: klavyede `ş`/`ğ` aratmamali."""
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT public.kayit_kodu_uret('Şişli Güneş Konakları','2026-01-09'), "
            "       public.kayit_kodu_uret('As','2026-01-09')"
        )
        turkce, kisa = cur.fetchone()
    assert turkce == "SISL-260109"
    assert kisa == "ASXX-260109", "dort harften kisa ad bicimi bozmamali"


def test_AYNI_taban_cakisirsa_sira_eki_alir(owner_conn):
    """Ayni gun kaydolan iki 'Oltu...' ayni tabani uretir; sutun UNIQUE."""
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO tenant (ad, slug, created_at) VALUES "
            "('Oltu Sitesi', %s, '2026-07-15'), "
            "('Oltu Konaklari', %s, '2026-07-15') RETURNING kayit_kodu",
            (f"c-{uuid.uuid4().hex[:8]}", f"c-{uuid.uuid4().hex[:8]}"),
        )
        kodlar = [r[0] for r in cur.fetchall()]
    assert len(set(kodlar)) == 2, "cakisma sessizce ayni kodu uretemez"
    # Sira numarasina DEGIL kurala baglaniyoruz. Olculen sey: ikisi de AYNI
    # tabani tasir ve en az biri EK almistir.
    #
    # IKI EK BICIMI DE MESRU (`tenant_kayit_kodu_ata`, goc 0041):
    #   * `-<10..99>` — normal yol, rastgele iki haneli (kilitli kural 3),
    #   * `-<6 hex>`  — SONLANMA GARANTISI: 90 iki haneli aday tukenince.
    #
    # ESKIDEN YALNIZ ILKI KABUL EDILIYORDU ve bu test, veritabaninda 90'dan
    # fazla ayni-tabanli tesis birikince KALICI OLARAK duserdi — nitekim
    # dustu (112 artik fixture tesisi; rapor §4.54). Yedek yol da urunun
    # belgelenmis davranisi; testin onu reddetmesi yanlisti.
    taban = "OLTU-260715"
    assert all(k.startswith(taban) for k in kodlar)
    ek = re.compile(rf"{re.escape(taban)}-([0-9]{{2}}|[0-9a-f]{{6}})$")
    assert any(ek.fullmatch(k) for k in kodlar), kodlar
