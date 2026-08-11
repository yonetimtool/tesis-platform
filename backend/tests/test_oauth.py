"""(P154 / Asama 4) SOSYAL GIRIS — Google / Microsoft / Apple.

===========================================================================
BU DOSYA NEYI OLCUYOR, NEYI OLCMUYOR
===========================================================================
Olculen:
  A. JETON DOGRULAMASI — GERCEK kripto ile. Testte bir RSA cifti uretilir,
     ondan bir JWKS kurulur ve `app.oauth`un onbellegine ENJEKTE EDILIR.
     Boylece imza/`iss`/`aud`/`exp`/`nonce` kontrollerinin ASIL KODU kosar
     ve tek sahtelenen sey saglayicinin anahtar listesi olur.

     `kimlik_dogrula`yi mock'lamak, bu asamanin EN RISKLI kodunu hic
     olcmemek olurdu — `aud` kontrolu atlanmis bir dogrulayici, baska bir
     uygulamaya kesilmis gecerli bir Google jetonunu kabul eder.

  B. UC YUZEYI — saglayici yapilandirilmamisken davranis. Brief'in sarti
     bu: "tikanirsa Asama 3 tek basina calissin".

  C. BAGLAMA IS KURALLARI — UCTAN UCA, HTTP uzerinden. Test, callback'in
     urettigi `baglama_jetonu`nu KENDISI uretir (kendi `jwt_secret`imizle
     imzali). Bu bir kestirme degil, DOGRU SINIR: (A) saglayicinin
     jetonunu dogrulamayi olcer, (C) dogrulanmis bir kimligin hesaba nasil
     baglandigini olcer. Ikisini tek teste sikistirmak, gercek bir
     saglayici hesabi gerektirirdi.

Olculmeyen (bilincli): saglayiciya yapilan GERCEK ag cagrilari (kod
takasi, JWKS indirme). Ag bagimli, kimlik bilgisi gerektirir ve
`docs/test-sunucusu-kurulum.md` §8'deki kurulum adimlarina baglidir.
"""
from __future__ import annotations

import time
import uuid

import pytest

TENANT_YOK = object()


# ============================ A. JETON DOGRULAMA ============================ #


@pytest.fixture
def rsa_cifti():
    from cryptography.hazmat.primitives.asymmetric import rsa

    return rsa.generate_private_key(public_exponent=65537, key_size=2048)


def _jwks(ozel_anahtar, kid: str = "test-kid") -> dict:
    """Ozel anahtardan bir JWKS uretir (saglayicinin `/certs` yaniti)."""
    import base64

    from cryptography.hazmat.primitives.asymmetric import rsa

    sayilar: rsa.RSAPublicNumbers = ozel_anahtar.public_key().public_numbers()

    def b64(n: int) -> str:
        ham = n.to_bytes((n.bit_length() + 7) // 8, "big")
        return base64.urlsafe_b64encode(ham).rstrip(b"=").decode()

    return {
        "keys": [
            {
                "kty": "RSA",
                "kid": kid,
                "use": "sig",
                "alg": "RS256",
                "n": b64(sayilar.n),
                "e": b64(sayilar.e),
            }
        ]
    }


def _pem(ozel_anahtar) -> bytes:
    from cryptography.hazmat.primitives import serialization

    return ozel_anahtar.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )


def _jeton(ozel_anahtar, **iddialar) -> str:
    import jwt

    govde = {
        "iss": "https://accounts.google.com",
        "aud": "web-istemci.apps.googleusercontent.com",
        "sub": "google-sub-1",
        "email": "biri@ornek.com",
        "exp": int(time.time()) + 600,
        "iat": int(time.time()),
    }
    govde.update(iddialar)
    return jwt.encode(
        govde, _pem(ozel_anahtar), algorithm="RS256", headers={"kid": "test-kid"}
    )


@pytest.fixture
def google_hazir(rsa_cifti, monkeypatch):
    """Google'i yapilandirir ve JWKS'i onbellege koyar (AG YOK)."""
    from app import oauth as oauth_mod
    from app.config import settings

    monkeypatch.setattr(
        settings, "oauth_google_client_id", "web-istemci.apps.googleusercontent.com"
    )
    monkeypatch.setattr(settings, "oauth_google_client_secret", "sir")
    monkeypatch.setattr(settings, "oauth_google_aud", "")
    oauth_mod.jwks_onbellegi_temizle()
    oauth_mod.jwks_onbellege_koy(
        "https://www.googleapis.com/oauth2/v3/certs", _jwks(rsa_cifti)
    )
    yield
    oauth_mod.jwks_onbellegi_temizle()


def _coz(kod: str, jeton: str, **kw):
    import asyncio

    from app.oauth import kimlik_dogrula

    return asyncio.run(kimlik_dogrula(kod, jeton, **kw))


def test_GECERLI_jeton_kimlik_dondurur(rsa_cifti, google_hazir):
    kimlik = _coz("google", _jeton(rsa_cifti))
    assert kimlik.saglayici == "google"
    assert kimlik.subject == "google-sub-1"
    assert kimlik.eposta == "biri@ornek.com"
    assert kimlik.relay is False


def test_BASKA_UYGULAMAYA_kesilmis_jeton_REDDEDILIR(rsa_cifti, google_hazir):
    """`aud` kontrolu — bu asamanin en onemli tek kontrolu.

    Gecerli imzali, gecerli `iss`li ama BASKA bir istemciye kesilmis bir
    Google jetonu kabul edilseydi, o uygulamaya giris yapabilen herkes
    bizde de giris yapardi ("karisik vekil").
    """
    from app.errors import APIError

    with pytest.raises(APIError) as hata:
        _coz("google", _jeton(rsa_cifti, aud="baska-uygulama.apps.googleusercontent.com"))
    assert hata.value.status_code == 401


def test_YANLIS_ISSUER_reddedilir(rsa_cifti, google_hazir):
    from app.errors import APIError

    with pytest.raises(APIError):
        _coz("google", _jeton(rsa_cifti, iss="https://kotu.ornek.com"))


def test_SURESI_DOLMUS_jeton_reddedilir(rsa_cifti, google_hazir):
    from app.errors import APIError

    with pytest.raises(APIError):
        _coz("google", _jeton(rsa_cifti, exp=int(time.time()) - 10))


def test_BASKA_ANAHTARLA_imzalanmis_jeton_reddedilir(google_hazir):
    """Onbellekteki anahtar A, jeton B ile imzali -> imza tutmaz.

    `kid` AYNI birakildi (bkz. `_jeton`): boylece test "anahtar
    bulunamadi" degil GERCEKTEN IMZA DOGRULAMASI olcer.
    """
    from cryptography.hazmat.primitives.asymmetric import rsa

    from app.errors import APIError

    sahte = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    with pytest.raises(APIError):
        _coz("google", _jeton(sahte))


def test_NONCE_UYUSMAZLIGI_reddedilir(rsa_cifti, google_hazir):
    """Web akisinda nonce, jetonun BIZIM baslattigimiz oturuma ait
    oldugunu kanitlar; yoksa yakalanan bir jeton yeniden oynatilabilirdi."""
    from app.errors import APIError

    jeton = _jeton(rsa_cifti, nonce="dogru-nonce")
    assert _coz("google", jeton, nonce="dogru-nonce").subject == "google-sub-1"
    with pytest.raises(APIError):
        _coz("google", jeton, nonce="baska-nonce")


def test_SUB_YOKSA_reddedilir(rsa_cifti, google_hazir):
    from app.errors import APIError

    with pytest.raises(APIError):
        _coz("google", _jeton(rsa_cifti, sub=""))


def test_APPLE_PRIVATE_RELAY_isaretlenir(rsa_cifti, monkeypatch):
    """Relay adresi eslesmede KULLANILMAZ; yalniz kullaniciya soylenir."""
    from app import oauth as oauth_mod
    from app.config import settings

    monkeypatch.setattr(settings, "oauth_apple_client_id", "com.app.yonetiyor.web")
    monkeypatch.setattr(settings, "oauth_apple_aud", "")
    oauth_mod.jwks_onbellegi_temizle()
    oauth_mod.jwks_onbellege_koy(
        "https://appleid.apple.com/auth/keys", _jwks(rsa_cifti)
    )
    jeton = _jeton(
        rsa_cifti,
        iss="https://appleid.apple.com",
        aud="com.app.yonetiyor.web",
        sub="apple-sub-1",
        email="abc123@privaterelay.appleid.com",
    )
    kimlik = _coz("apple", jeton)
    assert kimlik.relay is True
    assert kimlik.eposta == "abc123@privaterelay.appleid.com"
    oauth_mod.jwks_onbellegi_temizle()


def test_MICROSOFT_common_kiracisinda_ISSUER_ONEKLE_dogrulanir(rsa_cifti, monkeypatch):
    """`common`da `iss` HER KIRACIDA FARKLI (`.../{tid}/v2.0`).

    Tam esitlik istemek, kisisel hesap disinda herkesi reddederdi.
    """
    from app import oauth as oauth_mod
    from app.config import settings
    from app.errors import APIError

    monkeypatch.setattr(settings, "oauth_microsoft_client_id", "ms-istemci")
    monkeypatch.setattr(settings, "oauth_microsoft_aud", "")
    oauth_mod.jwks_onbellegi_temizle()
    oauth_mod.jwks_onbellege_koy(
        "https://login.microsoftonline.com/common/discovery/v2.0/keys",
        _jwks(rsa_cifti),
    )
    tid = uuid.uuid4()
    iyi = _jeton(
        rsa_cifti,
        iss=f"https://login.microsoftonline.com/{tid}/v2.0",
        aud="ms-istemci",
        sub="ms-sub-1",
    )
    assert _coz("microsoft", iyi).subject == "ms-sub-1"

    # Konak DOGRU ama `/v2.0` ile bitmiyor -> reddedilir. Onek kontrolunu
    # "startswith" ile birakmak, .../common/oauth2/authorize gibi baska
    # yollari da kabul ederdi.
    with pytest.raises(APIError):
        _coz(
            "microsoft",
            _jeton(
                rsa_cifti,
                iss=f"https://login.microsoftonline.com/{tid}/v1.0",
                aud="ms-istemci",
                sub="ms-sub-1",
            ),
        )
    oauth_mod.jwks_onbellegi_temizle()


def test_AUD_LISTESI_BOSSA_saglayici_KAPALI_sayilir(monkeypatch):
    """`aud` dogrulamasini atlamaktansa saglayiciyi kapatmak DOGRU.

    Bos liste ile `jwt.decode` cagirmak, `aud` kontrolunu fiilen
    devre disi birakirdi.
    """
    from app.config import settings
    from app.errors import APIError
    from app.oauth import acik_saglayicilar, saglayici_al

    monkeypatch.setattr(settings, "oauth_google_client_id", "")
    monkeypatch.setattr(settings, "oauth_google_aud", "")
    assert "google" not in acik_saglayicilar()
    with pytest.raises(APIError) as hata:
        saglayici_al("google")
    assert hata.value.status_code == 503


def test_MOBIL_ve_WEB_istemcileri_AYNI_ANDA_kabul_edilir(rsa_cifti, monkeypatch):
    """`aud` bir LISTE: ayni proje web ve mobil icin ayri kimlik uretir."""
    from app import oauth as oauth_mod
    from app.config import settings

    monkeypatch.setattr(settings, "oauth_google_client_id", "web-id")
    monkeypatch.setattr(settings, "oauth_google_aud", "web-id, mobil-id")
    oauth_mod.jwks_onbellegi_temizle()
    oauth_mod.jwks_onbellege_koy(
        "https://www.googleapis.com/oauth2/v3/certs", _jwks(rsa_cifti)
    )
    assert _coz("google", _jeton(rsa_cifti, aud="web-id")).subject == "google-sub-1"
    assert _coz("google", _jeton(rsa_cifti, aud="mobil-id")).subject == "google-sub-1"
    oauth_mod.jwks_onbellegi_temizle()


def test_PKCE_dogrulayicisi_ve_meydani_S256_uyumlu():
    import base64
    import hashlib

    from app.oauth import pkce_uret

    dogrulayici, meydan = pkce_uret()
    beklenen = (
        base64.urlsafe_b64encode(hashlib.sha256(dogrulayici.encode()).digest())
        .rstrip(b"=")
        .decode()
    )
    assert meydan == beklenen
    # RFC 7636: 43-128 karakter.
    assert 43 <= len(dogrulayici) <= 128


def test_YETKI_ADRESI_zorunlu_parametreleri_tasir(monkeypatch):
    from urllib.parse import parse_qs, urlsplit

    from app.config import settings
    from app.oauth import saglayici_al, yetki_adresi

    monkeypatch.setattr(settings, "oauth_apple_client_id", "com.app.yonetiyor.web")
    monkeypatch.setattr(settings, "oauth_apple_aud", "")
    sag = saglayici_al("apple")
    adres = yetki_adresi(
        sag,
        redirect_uri="https://api.ornek.com/auth/oauth/apple/callback",
        state="S",
        nonce="N",
        meydan="M",
    )
    q = parse_qs(urlsplit(adres).query)
    assert q["code_challenge_method"] == ["S256"]
    assert q["state"] == ["S"] and q["nonce"] == ["N"]
    # APPLE `form_post` ZORUNLU: `name`/`email` kapsamlarinda geri donus
    # POST edilir; olmazsa callback GET beklerken 405 alinirdi.
    assert q["response_mode"] == ["form_post"]


# ============================== B. UC YUZEYI ================================ #


def test_saglayici_listesi_KIMLIKSIZ_acilir(client):
    r = client.get("/auth/oauth/saglayicilar")
    assert r.status_code == 200, r.text
    assert isinstance(r.json()["saglayicilar"], list)


def test_YAPILANDIRILMAMIS_saglayici_503(client):
    """Test ortaminda hicbir saglayici yapilandirilmamis olmali."""
    if "google" in client.get("/auth/oauth/saglayicilar").json()["saglayicilar"]:
        pytest.skip("bu ortamda Google yapilandirilmis")
    r = client.post("/auth/oauth/baslat/google", json={"yuzey": "web"})
    assert r.status_code == 503, r.text


def test_BILINMEYEN_saglayici_404(client):
    r = client.post("/auth/oauth/baslat/facebook", json={"yuzey": "web"})
    assert r.status_code == 404


def test_SAHTE_sonuc_id_400(client):
    r = client.post("/auth/oauth/sonuc", json={"sonuc_id": "olmayan-bir-kimlik"})
    assert r.status_code == 400
    assert r.json()["error"]["message"]  # katalogdan cevrildi


def test_SAHTE_baglama_jetonu_400(client):
    r = client.post(
        "/auth/oauth/baglan/basla",
        json={"baglama_jetonu": "abc.def.ghi", "tesis_kodu": "X", "telefon": "+905551112233"},
    )
    assert r.status_code == 400


def test_ASAMA_3_SOSYAL_GIRIS_OLMADAN_CALISIR(client, world):
    """Brief'in sarti: "tikanirsa Asama 3 tek basina calissin".

    Hicbir saglayici yapilandirilmamisken parolali giris DEGISMEDEN
    islemeli — bu asamanin urune getirdigi tek zorunluluk yok.
    """
    r = client.post(
        "/auth/login",
        json={
            "tenant_slug": world["slug_a"],
            "email": world["yonetici_a"]["email"],
            "password": world["yonetici_a"]["password"],
        },
    )
    assert r.status_code == 200, r.text


# ========================= C. BAGLAMA IS KURALLARI ========================== #


def _kod(owner_conn, slug: str) -> str:
    with owner_conn.cursor() as cur:
        cur.execute("SELECT kayit_kodu FROM tenant WHERE slug = %s", (slug,))
        return cur.fetchone()[0]


def _link_jetonu(saglayici: str, subject: str, eposta: str | None = None) -> str:
    """Callback'in uretecegi `baglama_jetonu`nun AYNISI.

    Testin bunu kendi uretmesi dogru sinir (bkz. modul basligi): (A)
    saglayici jetonunu dogrulamayi olcer, (C) dogrulanmis kimligin hesaba
    baglanmasini.
    """
    import jwt

    from app.config import settings

    simdi = int(time.time())
    return jwt.encode(
        {
            "type": "oauth_link",
            "saglayici": saglayici,
            "subject": subject,
            "eposta": eposta,
            "iat": simdi,
            "exp": simdi + 600,
        },
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )


def _sms_kodu(owner_conn, telefon: str) -> str:
    """Kod hash'lenerek saklanir; testte BILDIGIMIZ bir hash ile degistirilir
    (`test_rol_secimli_kayit` ile ayni yontem)."""
    from app.security import hash_password

    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE kayit_dogrulama SET kod_hash = %s "
            "WHERE telefon = %s AND amac = 'oauth' AND durum = 'telefon_bekliyor' "
            "RETURNING id",
            (hash_password("424242"), telefon),
        )
        assert cur.fetchone() is not None, "bekleyen oauth kodu YOK"
    return "424242"


def _yonetici_girisi(client, world):
    r = client.post(
        "/auth/login",
        json={
            "tenant_slug": world["slug_a"],
            "email": world["yonetici_a"]["email"],
            "password": world["yonetici_a"]["password"],
        },
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _bagla(client, owner_conn, world, saglayici: str, subject: str) -> dict:
    """Tam baglama akisi: jeton -> tesis+telefon -> SMS -> baglandi."""
    telefon = world["yonetici_a"]["phone"]
    jeton = _link_jetonu(saglayici, subject, "biri@ornek.com")
    r = client.post(
        "/auth/oauth/baglan/basla",
        json={
            "baglama_jetonu": jeton,
            "tesis_kodu": _kod(owner_conn, world["slug_a"]),
            "telefon": telefon,
        },
    )
    assert r.status_code == 200, r.text
    kod = _sms_kodu(owner_conn, telefon)
    r = client.post(
        "/auth/oauth/baglan/dogrula",
        json={"baglama_jetonu": jeton, "telefon": telefon, "kod": kod},
    )
    return r


def test_BAGLAMA_akisi_SMS_ile_tamamlanir_ve_OTURUM_acar(client, world, owner_conn):
    r = _bagla(client, owner_conn, world, "google", f"g-{uuid.uuid4().hex[:12]}")
    assert r.status_code == 200, r.text
    assert r.json()["access_token"] and r.json()["refresh_token"]


def test_SMS_KODU_OLMADAN_baglanamaz(client, world, owner_conn):
    """ILK BAGLAMADA SMS ZORUNLU: saglayici "bu Google hesabinin
    sahibisin" der, "bu telefonun sahibisin" DEMEZ. Tesis kodu kamuya
    acik, telefon sir degil — ikisi birlikte kimlik kaniti degildir."""
    telefon = world["yonetici_a"]["phone"]
    jeton_subject = f"g-{uuid.uuid4().hex[:12]}"
    jeton = _link_jetonu("google", jeton_subject)
    r = client.post(
        "/auth/oauth/baglan/dogrula",
        json={"baglama_jetonu": jeton, "telefon": telefon, "kod": "000000"},
    )
    # 422 `kod_gecersiz` — bekleyen bir kod satiri YOK. Onemli olan durum
    # kodu degil, BAGLANMAMIS olmasi:
    assert r.status_code == 422, r.text
    with owner_conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM oauth_kimlik WHERE subject = %s",
                    (jeton_subject,))
        assert cur.fetchone()[0] == 0


def test_ESLESMEYEN_numara_AYNI_yaniti_alir(client, world, owner_conn):
    """Eslesme sonucu yanittan OKUNAMAZ — `rol_kayit_basla` ile ayni ilke.

    Aksi hâlde uc "bu numara bu sitede kayitli mi" sorgusuna donusurdu.
    """
    tesis = _kod(owner_conn, world["slug_a"])
    jeton = _link_jetonu("google", f"g-{uuid.uuid4().hex[:12]}")
    # `guard_a` KULLANILIYOR, `yonetici_a` DEGIL: hiz siniri TELEFON
    # BASINA sayar (`kod_istegi_say`) ve bu dosyadaki diger testler
    # yoneticinin numarasinin kotasini tuketip bu testi 429'a dusuruyordu
    # — OLCULDU. Hiz sinirini gevsetmek yanlis cozum olurdu.
    kayitli = client.post(
        "/auth/oauth/baglan/basla",
        json={
            "baglama_jetonu": jeton,
            "tesis_kodu": tesis,
            "telefon": world["guard_a"]["phone"],
        },
    )
    olmayan = client.post(
        "/auth/oauth/baglan/basla",
        json={
            "baglama_jetonu": jeton,
            "tesis_kodu": tesis,
            "telefon": f"+9059{uuid.uuid4().int % 10**8:08d}",
        },
    )
    assert kayitli.status_code == olmayan.status_code == 200
    assert kayitli.json()["tesis_ad"] == olmayan.json()["tesis_ad"]


def test_BAGLANTILARIM_kimlik_ISTER(client):
    assert client.get("/auth/oauth/baglantilarim").status_code == 401


def test_BAGLANTILARIM_baglandiktan_sonra_gorunur(client, world, owner_conn):
    subject = f"g-{uuid.uuid4().hex[:12]}"
    assert _bagla(client, owner_conn, world, "google", subject).status_code == 200
    r = client.get("/auth/oauth/baglantilarim", headers=_yonetici_girisi(client, world))
    assert r.status_code == 200, r.text
    kodlar = [x["saglayici"] for x in r.json()["items"]]
    assert "google" in kodlar


def test_AYNI_SAGLAYICIYI_yeniden_baglamak_ESKISININ_YERINE_gecer(
    client, world, owner_conn
):
    """`uq_oauth_kimlik_user_saglayici` kullanici basina tek kimlik birakir.

    Ikinci Google hesabini "hata" saymak yerine DEGISTIRMEK, en yaygin
    durumu (is hesabindan kisisel hesaba gecis) dogrudan karsilar.
    """
    assert _bagla(client, owner_conn, world, "google", f"g-{uuid.uuid4().hex[:12]}").status_code == 200
    ikinci = f"g-{uuid.uuid4().hex[:12]}"
    assert _bagla(client, owner_conn, world, "google", ikinci).status_code == 200

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT subject FROM oauth_kimlik WHERE saglayici = 'google' "
            "AND tenant_id = (SELECT id FROM tenant WHERE slug = %s)",
            (world["slug_a"],),
        )
        satirlar = [r[0] for r in cur.fetchall()]
    assert satirlar == [ikinci], "eski satir kalmis ya da ikisi birden var"


def test_BASKA_KULLANICIYA_bagli_kimlik_DEVRALINAMAZ(client, world, owner_conn):
    """Bir Google hesabi platformda TEK kullaniciyi acar.

    Devralmaya izin vermek, ayni sosyal hesabin iki kisiyi acmasi demekti.
    """
    subject = f"g-{uuid.uuid4().hex[:12]}"
    assert _bagla(client, owner_conn, world, "google", subject).status_code == 200

    # Ayni subject'i BASKA bir tenant'taki kullaniciya baglamaya calis.
    telefon_b = world["yonetici_b"]["phone"]
    jeton = _link_jetonu("google", subject)
    r = client.post(
        "/auth/oauth/baglan/basla",
        json={
            "baglama_jetonu": jeton,
            "tesis_kodu": _kod(owner_conn, world["slug_b"]),
            "telefon": telefon_b,
        },
    )
    assert r.status_code == 200
    kod = _sms_kodu(owner_conn, telefon_b)
    r = client.post(
        "/auth/oauth/baglan/dogrula",
        json={"baglama_jetonu": jeton, "telefon": telefon_b, "kod": kod},
    )
    assert r.status_code == 409, r.text
    assert r.json()["error"]["code"] == "conflict"


def test_BAGLANTI_SILINIR(client, world, owner_conn):
    assert _bagla(client, owner_conn, world, "google", f"g-{uuid.uuid4().hex[:12]}").status_code == 200
    basliklar = _yonetici_girisi(client, world)
    r = client.delete("/auth/oauth/baglantilarim/google", headers=basliklar)
    assert r.status_code == 204, r.text
    kalan = client.get("/auth/oauth/baglantilarim", headers=basliklar).json()["items"]
    assert [x for x in kalan if x["saglayici"] == "google"] == []


def test_BAGLI_OLMAYAN_saglayici_silinemez_404(client, world):
    r = client.delete(
        "/auth/oauth/baglantilarim/microsoft", headers=_yonetici_girisi(client, world)
    )
    assert r.status_code == 404


def test_SON_GIRIS_YONTEMI_kaldirilamaz(client, world, owner_conn):
    """Kullanicinin elinde parola, baska bir sosyal kimlik ya da telefon
    kalmali; yoksa kendi hesabina bir daha giremez.

    Test, yoneticinin parolasini VE telefonunu gecici olarak kaldirip
    tek yolu Google birakiyor — sonra silmeyi deniyor.
    """
    subject = f"g-{uuid.uuid4().hex[:12]}"
    assert _bagla(client, owner_conn, world, "google", subject).status_code == 200
    basliklar = _yonetici_girisi(client, world)

    with owner_conn.cursor() as cur:
        # TENANT SUZGECI SART: `email` YALNIZ TENANT ICINDE benzersiz
        # (`uq_app_user_tenant_email`). Suzgecsiz UPDATE, B tesisindeki
        # ayni adli yoneticinin de telefonunu silerdi ve geri yazarken
        # `uq_app_user_telefon` ihlali verirdi — OLCULDU.
        cur.execute(
            "UPDATE app_user SET password_set = false, telefon = NULL "
            "WHERE email = %s AND tenant_id = "
            "(SELECT id FROM tenant WHERE slug = %s) RETURNING id",
            (world["yonetici_a"]["email"], world["slug_a"]),
        )
        assert cur.fetchone() is not None
    try:
        r = client.delete("/auth/oauth/baglantilarim/google", headers=basliklar)
        assert r.status_code == 409, r.text
        assert r.json()["error"]["code"] == "conflict"
    finally:
        with owner_conn.cursor() as cur:
            cur.execute(
                "UPDATE app_user SET password_set = true, telefon = %s "
                "WHERE email = %s AND tenant_id = "
                "(SELECT id FROM tenant WHERE slug = %s)",
                (
                    world["yonetici_a"]["phone"],
                    world["yonetici_a"]["email"],
                    world["slug_a"],
                ),
            )


# ============================ SEMA GARANTILERI ============================== #


def test_SUBJECT_platform_capinda_TEKIL(owner_conn):
    """`uq_oauth_kimlik_subject` GLOBAL — tenant-uzeri.

    `app_user.telefon` icin zaten ayni kural var (`uq_app_user_telefon`)
    ve ayni sebeple: kimlik dogrulama anahtari iki kisiyi isaret edemez.
    """
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT indexdef FROM pg_indexes "
            "WHERE tablename = 'oauth_kimlik' AND indexname = 'uq_oauth_kimlik_subject'"
        )
        satir = cur.fetchone()
    assert satir is not None, "benzersizlik indeksi YOK"
    assert "UNIQUE" in satir[0]
    # Tenant kolonu indekste OLMAMALI: olsaydi ayni Google hesabi iki
    # sitede iki AYRI kisiyi acardi.
    assert "tenant_id" not in satir[0]


def test_RLS_acik_ve_FORCE(owner_conn):
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT relrowsecurity, relforcerowsecurity FROM pg_class "
            "WHERE relname = 'oauth_kimlik'"
        )
        assert cur.fetchone() == (True, True)


def test_SAGLAYICI_JETONU_SAKLANMIYOR(owner_conn):
    """Tabloda saglayici jetonu TASIYABILECEK bir sutun olmamali.

    Saklamak, hicbir isi olmayan bir sorumluluk olurdu: sizmasi hâlinde
    kullanicinin GOOGLE HESABINA erisim verir (goc 0048).
    """
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_name = 'oauth_kimlik'"
        )
        sutunlar = {r[0] for r in cur.fetchall()}
    assert not {"access_token", "refresh_token", "id_token"} & sutunlar
