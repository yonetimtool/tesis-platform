"""(P212-ek §2) KIMLIK (e-posta) ile UYELIK (tesis+rol) AYRIMI.

===========================================================================
OLCULEN ENGEL
===========================================================================
Ayni kisiyi IKINCI bir tesise yonetici eklemek IMKANSIZDI. Sema coklu
uyeligi ZATEN destekliyor (goc 0092: e-posta TESIS ICINDE benzersiz) ama
`POST /users` telefonu ZORUNLU tutuyordu ve `uq_app_user_telefon`
telefonu PLATFORM GENELINDE benzersiz kiliyor:

    telefonsuz gonder -> 422 "telefon: Field required"
    gercek numarayla  -> 409 "Bu telefon veya e-posta zaten kayitli"

Yani ikinci uyelik ancak UYDURMA bir numarayla acilabiliyordu. P197'den
beri KIMLIK E-POSTADIR; telefon bir iletisim alanidir ve artik
OPSIYONELDIR. Benzersizligi KORUNUR (verilirse global benzersiz).

===========================================================================
KURAL: BIR KISI AYNI TESISTE TEK ROLDE
===========================================================================
Bu kural `uq_app_user_tenant_email` ile SEMADA duruyor: ayni tesiste ayni
e-posta ikinci kez ACILAMAZ. Testi buraya yaziyoruz cunku kuralin
kendisi bir URUN kararidir, kisitin varligi tesadufi degildir.

SINIR — DURUSTCE: sistem kisiyi E-POSTASIYLA tanir. Ayni insan FARKLI
iki e-postayla ayni tesiste iki hesap acabilir ve yazilim bunu
ANLAYAMAZ (telefon opsiyonel oldugu icin ikinci bir kimlik anahtari da
yok). Kullanicinin yasadigi durum tam olarak buydu: yonetici hesabinin
e-postasini, KENDI guvenlik hesabinda duran adrese cevirmek istedi ve
409 aldi. Kilit, sistemin GOREBILDIGI cakismayi kapsar.
"""
from __future__ import annotations

import base64
import json
import uuid


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _tenant_of(token: str) -> str:
    g = token.split(".")[1]
    g += "=" * (-len(g) % 4)
    return json.loads(base64.urlsafe_b64decode(g))["tenant_id"]


def _eposta() -> str:
    return f"coklu-{uuid.uuid4().hex[:10]}@ornek.com"


def _tel() -> str:
    return f"+9059{uuid.uuid4().int % 10**8:08d}"


# ==================== 1) TELEFON OPSIYONEL ============================== #

def test_TELEFONSUZ_kullanici_ACILIR(client, world):
    """Engelin ta kendisi: eskiden 422 'telefon: Field required'."""
    a = _h(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/users", headers=a, json={
        "ad": "Telefonsuz Kisi", "email": _eposta(), "role": "resident"})
    assert r.status_code == 201, r.text
    assert r.json()["telefon"] in (None, "")


def test_BOS_telefon_NULL_olur_gecersiz_numara_SAYILMAZ(client, world):
    a = _h(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/users", headers=a, json={
        "ad": "Bos Telefon", "email": _eposta(), "role": "resident",
        "telefon": "   "})
    assert r.status_code == 201, r.text
    assert r.json()["telefon"] is None


def test_TELEFON_VERILIRSE_hala_GLOBAL_BENZERSIZ(client, world):
    """Opsiyonel olmak, benzersizligi kaldirmaz."""
    a = _h(client, world["slug_a"], world["yonetici_a"])
    b = _h(client, world["slug_b"], world["admin_b"])
    tel = _tel()
    assert client.post("/users", headers=a, json={
        "ad": "Numarali", "email": _eposta(), "role": "resident",
        "telefon": tel}).status_code == 201
    r = client.post("/users", headers=b, json={
        "ad": "Ayni Numara", "email": _eposta(), "role": "resident",
        "telefon": tel})
    assert r.status_code == 409, r.text


# ============ 2) AYNI TESISTE TEK ROL / FARKLI TESISTE AYNI KISI ======== #

def test_AYNI_TESISTE_ayni_eposta_IKINCI_KEZ_ACILAMAZ(client, world):
    """KURAL: bir kisi ayni tesiste TEK ROLDE olur."""
    a = _h(client, world["slug_a"], world["yonetici_a"])
    eposta = _eposta()
    assert client.post("/users", headers=a, json={
        "ad": "Tek Rol", "email": eposta, "role": "resident"}).status_code == 201
    # Ayni tesis, ayni e-posta, BASKA rol -> REDDEDILIR.
    r = client.post("/users", headers=a, json={
        "ad": "Tek Rol", "email": eposta, "role": "security"})
    assert r.status_code == 409, r.text
    assert r.json()["error"]["code"] == "conflict"


def test_FARKLI_TESISTE_ayni_eposta_ACILIR(client, world):
    a = _h(client, world["slug_a"], world["yonetici_a"])
    b = _h(client, world["slug_b"], world["admin_b"])
    eposta = _eposta()
    assert client.post("/users", headers=a, json={
        "ad": "Coklu", "email": eposta, "role": "yonetici"}).status_code == 201
    r = client.post("/users", headers=b, json={
        "ad": "Coklu", "email": eposta, "role": "yonetici"})
    assert r.status_code == 201, r.text
    # IKI AYRI SATIR, IKI AYRI ROL TASIYABILIR (ayni tesiste degil).
    assert r.json()["id"] != eposta


# ==================== 3) GIRIS: SECIM VE IZOLASYON ====================== #

def _iki_tesiste_kullanici(client, world, owner_conn, parola="CokGizli123!"):
    from app.security import hash_password

    a = _h(client, world["slug_a"], world["yonetici_a"])
    b = _h(client, world["slug_b"], world["admin_b"])
    eposta = _eposta()
    for h in (a, b):
        r = client.post("/users", headers=h, json={
            "ad": "Coklu Giris", "email": eposta, "role": "yonetici"})
        assert r.status_code == 201, r.text
    owner_conn.execute(
        "UPDATE app_user SET password_hash=%s, password_set=true, "
        "eposta_dogrulandi=true WHERE lower(email)=lower(%s)",
        (hash_password(parola), eposta))
    owner_conn.commit()
    return eposta, parola


def test_COK_TESISLI_giriste_SECIM_istenir(client, world, owner_conn):
    eposta, parola = _iki_tesiste_kullanici(client, world, owner_conn)
    r = client.post("/auth/login", json={"kimlik": eposta, "password": parola})
    assert r.status_code == 409, r.text
    assert r.json()["error"]["code"] == "tesis_secimi_gerekli"

    r = client.post("/auth/tesislerim", json={"kimlik": eposta, "password": parola})
    assert r.status_code == 200, r.text
    slugs = {t["slug"] for t in r.json()["tesisler"]}
    assert {world["slug_a"], world["slug_b"]} <= slugs


def test_TEK_TESISLI_kullanici_SECIM_GORMEZ(client, world, owner_conn):
    from app.security import hash_password

    a = _h(client, world["slug_a"], world["yonetici_a"])
    eposta, parola = _eposta(), "CokGizli123!"
    assert client.post("/users", headers=a, json={
        "ad": "Tek Tesis", "email": eposta, "role": "yonetici"}).status_code == 201
    owner_conn.execute(
        "UPDATE app_user SET password_hash=%s, password_set=true "
        "WHERE lower(email)=lower(%s)", (hash_password(parola), eposta))
    owner_conn.commit()
    r = client.post("/auth/login", json={"kimlik": eposta, "password": parola})
    assert r.status_code == 200, r.text  # 409 DEGIL: secim sorulmaz


def test_SECILEN_TESIS_jetonu_ve_IZOLASYON(client, world, owner_conn):
    eposta, parola = _iki_tesiste_kullanici(client, world, owner_conn)
    r = client.post("/auth/login", json={
        "kimlik": eposta, "password": parola, "tenant_slug": world["slug_b"]})
    assert r.status_code == 200, r.text
    tok_b = r.json()["access_token"]
    assert _tenant_of(tok_b) == str(world["b"])

    # A'da bir daire olustur; B jetonuyla GORUNMEMELI.
    a = _h(client, world["slug_a"], world["yonetici_a"])
    blok = f"IZ{uuid.uuid4().hex[:3].upper()}"
    daire = client.post("/units", headers=a, json={
        "no": f"{blok}-1", "blok": blok}).json()
    liste = client.get("/units", headers={"Authorization": f"Bearer {tok_b}"},
                       params={"limit": 200}).json()
    assert daire["no"] not in {u["no"] for u in liste.get("items", [])}


def test_UYGULAMA_ICINDEN_tesis_degistirilebilir(client, world, owner_conn):
    eposta, parola = _iki_tesiste_kullanici(client, world, owner_conn)
    tok_b = client.post("/auth/login", json={
        "kimlik": eposta, "password": parola,
        "tenant_slug": world["slug_b"]}).json()["access_token"]

    r = client.post("/me/tesis-degistir",
                    headers={"Authorization": f"Bearer {tok_b}"},
                    json={"tenant_id": str(world["a"])})
    assert r.status_code == 200, r.text
    assert _tenant_of(r.json()["access_token"]) == str(world["a"])


def test_UYE_OLMADIGI_tesise_GECEMEZ(client, world, owner_conn):
    """Izolasyonun kalbi: jeton uretme ucu bir 'istedigim tesis' ucuna
    donusmemeli."""
    from app.security import hash_password

    a = _h(client, world["slug_a"], world["yonetici_a"])
    eposta, parola = _eposta(), "CokGizli123!"
    client.post("/users", headers=a, json={
        "ad": "Tek Tesis", "email": eposta, "role": "yonetici"})
    owner_conn.execute(
        "UPDATE app_user SET password_hash=%s, password_set=true "
        "WHERE lower(email)=lower(%s)", (hash_password(parola), eposta))
    owner_conn.commit()
    tok = client.post("/auth/login", json={
        "kimlik": eposta, "password": parola}).json()["access_token"]

    r = client.post("/me/tesis-degistir",
                    headers={"Authorization": f"Bearer {tok}"},
                    json={"tenant_id": str(world["b"])})
    assert r.status_code == 403, r.text
