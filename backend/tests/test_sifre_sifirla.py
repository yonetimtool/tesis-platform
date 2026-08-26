"""(P181 Bölüm 2) Parola sıfırlama — "şifremi unuttum". E-POSTA TABANLI, SMS YOK.

Kod `kayit_dogrulama`ya (amac='sifre_sifirla') bcrypt HASH'li yazılır; okunamaz.
Test, `test_eposta_kanali` deseniyle hash'i bilinen bir kodla değiştirip doğrular.

GATE: `eposta_dogrulandi=true` olmayan hesap sıfırlama yapamaz (Bölüm 1 ön koşulu);
uç adres/hesap varlığını SIZDIRMAZ (kayıtsız/pasif/doğrulanmamış için de aynı yanıt).
"""
from app.security import hash_password


def _dogrula_eposta(owner_conn, tenant_id, eposta):
    owner_conn.execute(
        "UPDATE app_user SET eposta_dogrulandi = true "
        "WHERE tenant_id = %s AND lower(email) = %s",
        (tenant_id, eposta.lower()),
    )
    owner_conn.commit()


def _kodu_bilinene_cevir(owner_conn, tenant_id, eposta, kod="123456"):
    owner_conn.execute(
        "UPDATE kayit_dogrulama SET kod_hash = %s WHERE tenant_id = %s "
        "AND eposta = %s AND amac = 'sifre_sifirla' AND durum = 'telefon_bekliyor'",
        (hash_password(kod), tenant_id, eposta.lower()),
    )
    owner_conn.commit()


def test_sifre_kod_iste_ADRES_VARLIGINI_SIZDIRMAZ(client, world, owner_conn):
    eposta = world["yonetici_a"]["email"]
    _dogrula_eposta(owner_conn, world["a"], eposta)  # kayıtlı+doğrulanmış
    kayitli = client.post("/auth/sifre/kod-iste", json={
        "tenant_slug": world["slug_a"], "eposta": eposta})
    yok = client.post("/auth/sifre/kod-iste", json={
        "tenant_slug": world["slug_a"], "eposta": "olmayan@example.com"})
    bilinmeyen_tesis = client.post("/auth/sifre/kod-iste", json={
        "tenant_slug": "olmayan-tesis", "eposta": "x@example.com"})
    # UCU DE AYNI: aksi halde uc "hangi adresler kayitli/dogrulanmis" sorgusu olurdu.
    assert kayitli.status_code == yok.status_code == bilinmeyen_tesis.status_code == 200
    assert kayitli.json() == yok.json() == bilinmeyen_tesis.json()


def test_sifre_kod_iste_DOGRULANMIS_kod_YAZAR(client, world, owner_conn):
    eposta = world["yonetici_a"]["email"].lower()
    _dogrula_eposta(owner_conn, world["a"], eposta)
    r = client.post("/auth/sifre/kod-iste", json={
        "tenant_slug": world["slug_a"], "eposta": eposta})
    assert r.status_code == 200
    satir = owner_conn.execute(
        "SELECT amac, durum, telefon, kod_hash FROM kayit_dogrulama "
        "WHERE tenant_id = %s AND eposta = %s AND amac = 'sifre_sifirla'",
        (world["a"], eposta),
    ).fetchone()
    assert satir is not None, "doğrulanmış e-postaya sıfırlama kodu yazılmadı"
    assert satir[0] == "sifre_sifirla"
    assert satir[1] == "telefon_bekliyor"
    assert satir[2] is None                 # kimlik e-posta, telefon boş
    assert satir[3].startswith("$2")        # bcrypt özeti, düz metin değil


def test_sifre_kod_iste_DOGRULANMAMIS_kod_YAZMAZ(client, world, owner_conn):
    """eposta_dogrulandi=false hesap: yanıt AYNI (200) ama kod satırı YAZILMAZ."""
    eposta = world["yonetici_a"]["email"].lower()
    # world kullanıcısı doğrulanmamış başlar (Bölüm 1 varsayılanı) — dokunma.
    r = client.post("/auth/sifre/kod-iste", json={
        "tenant_slug": world["slug_a"], "eposta": eposta})
    assert r.status_code == 200
    sayi = owner_conn.execute(
        "SELECT count(*) FROM kayit_dogrulama WHERE tenant_id = %s "
        "AND eposta = %s AND amac = 'sifre_sifirla'",
        (world["a"], eposta),
    ).fetchone()[0]
    assert sayi == 0, "doğrulanmamış e-postaya sıfırlama kodu yazıldı (kural ihlali)"


def test_sifre_YANLIS_kod_REDDEDER(client, world, owner_conn):
    eposta = world["yonetici_a"]["email"].lower()
    _dogrula_eposta(owner_conn, world["a"], eposta)
    client.post("/auth/sifre/kod-iste", json={
        "tenant_slug": world["slug_a"], "eposta": eposta})
    r = client.post("/auth/sifre/dogrula-ve-ayarla", json={
        "tenant_slug": world["slug_a"], "eposta": eposta,
        "kod": "000000", "yeni_parola": "YeniParola123!"})
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "invalid_code"


def test_sifre_ZAYIF_parola_422(client, world, owner_conn):
    eposta = world["yonetici_a"]["email"].lower()
    _dogrula_eposta(owner_conn, world["a"], eposta)
    client.post("/auth/sifre/kod-iste", json={
        "tenant_slug": world["slug_a"], "eposta": eposta})
    _kodu_bilinene_cevir(owner_conn, world["a"], eposta)
    r = client.post("/auth/sifre/dogrula-ve-ayarla", json={
        "tenant_slug": world["slug_a"], "eposta": eposta,
        "kod": "123456", "yeni_parola": "kisa"})   # <8, zayıf
    assert r.status_code == 422


def test_sifre_DOGRU_kod_PAROLAYI_DEGISTIRIR(client, world, owner_conn):
    """Kod doğru → yeni parola kurulur; eski parola ölür, yenisi giriş yapar."""
    eposta = world["yonetici_a"]["email"].lower()
    eski = world["yonetici_a"]["password"]
    yeni = "YepyeniParola456!"
    _dogrula_eposta(owner_conn, world["a"], eposta)
    client.post("/auth/sifre/kod-iste", json={
        "tenant_slug": world["slug_a"], "eposta": eposta})
    _kodu_bilinene_cevir(owner_conn, world["a"], eposta)

    r = client.post("/auth/sifre/dogrula-ve-ayarla", json={
        "tenant_slug": world["slug_a"], "eposta": eposta,
        "kod": "123456", "yeni_parola": yeni})
    assert r.status_code == 200, r.text
    # OTURUM AÇMAZ: token dönmez, yalnız sızıntısız durum.
    assert "access_token" not in r.json()

    # Yeni parola giriş yapar.
    ok = client.post("/auth/login", json={
        "tenant_slug": world["slug_a"], "email": eposta, "password": yeni})
    assert ok.status_code == 200, ok.text
    assert ok.json()["access_token"]

    # Eski parola artık ÇALIŞMAZ.
    hata = client.post("/auth/login", json={
        "tenant_slug": world["slug_a"], "email": eposta, "password": eski})
    assert hata.status_code == 401

    # Kod TÜKETİLİR: ikinci sıfırlama denemesi 422.
    tekrar = client.post("/auth/sifre/dogrula-ve-ayarla", json={
        "tenant_slug": world["slug_a"], "eposta": eposta,
        "kod": "123456", "yeni_parola": "BaskaParola789!"})
    assert tekrar.status_code == 422


def test_sifre_dogrula_DOGRULANMAMIS_hesap_REDDEDER(client, world, owner_conn):
    """Kod satırı elle enjekte edilse bile doğrulanmamış hesap parola kuramaz."""
    eposta = world["yonetici_a"]["email"].lower()
    # ÖNCE doğrula (kod-iste satırı yazsın), SONRA bayrağı geri al.
    _dogrula_eposta(owner_conn, world["a"], eposta)
    client.post("/auth/sifre/kod-iste", json={
        "tenant_slug": world["slug_a"], "eposta": eposta})
    _kodu_bilinene_cevir(owner_conn, world["a"], eposta)
    owner_conn.execute(
        "UPDATE app_user SET eposta_dogrulandi = false "
        "WHERE tenant_id = %s AND lower(email) = %s",
        (world["a"], eposta),
    )
    owner_conn.commit()

    r = client.post("/auth/sifre/dogrula-ve-ayarla", json={
        "tenant_slug": world["slug_a"], "eposta": eposta,
        "kod": "123456", "yeni_parola": "YeniParola123!"})
    assert r.status_code == 422
