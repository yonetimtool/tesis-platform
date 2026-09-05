"""(P213 §6b) KAMERA ADRESINDEKI PAROLA — ADRESTEN AYRILDI ve SIFRELENDI.

===========================================================================
NE OLCULUYOR
===========================================================================
Bu bir GUVENLIK DUZELTMESIDIR ve iddiasi tek cumleyle: "kamera parolasi
artik ne veritabaninda duz durur, ne de bir yanitla disari cikar".

Olcum UCTAN UCA: gercek uc cagrilir, sonra ayni satir VERITABANINDAN
(owner_conn) okunur. Yanit govdesine bakmak yetmezdi — parolanin
saklandigi yeri degil, yalnizca gosterilmedigini olcerdi.
"""
from __future__ import annotations

import uuid

import pytest


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


# `#` YOK: kacissiz `#` adresi BELIRSIZ kilar ve artik 422 ile
# reddediliyor (asagida ayrica olculuyor). Buradaki parola, ozel
# karakter tasiyan ama adreste GECERLI bir parola.
PAROLA = "Gizli!Kamera42"


@pytest.fixture
def yon(client, world):
    return _h(client, world["slug_a"], world["yonetici_a"])


def _kamera(client, h, url: str, **ek) -> str:
    r = client.post("/cameras", headers=h, json={
        "ad": f"K-{uuid.uuid4().hex[:8]}", "stream_url": url, "tur": "rtsp", **ek})
    assert r.status_code == 201, r.text
    return r.json()["id"]


def _oku(client, h, kid: str) -> dict:
    """Tek-kayit GET ucu YOK (matris kilidi de boyle soyluyor): kamera
    listeden okunur."""
    r = client.get("/cameras?limit=100", headers=h)
    assert r.status_code == 200, r.text
    kayit = next((k for k in r.json()["items"] if k["id"] == kid), None)
    assert kayit is not None, "kamera listede yok"
    return kayit


def _db_satir(owner_conn, kid: str):
    return owner_conn.execute(
        "SELECT stream_url, stream_kullanici, stream_parola_sifreli "
        "FROM camera WHERE id = %s", (kid,)
    ).fetchone()


# ==================== ADRESTEN AYIRMA ===================================== #

def test_ADRESTEKI_parola_VERITABANINA_DUZ_YAZILMAZ(client, yon, owner_conn):
    """Kok iddia: `rtsp://kul:parola@...` yapistirildiginda parola
    satirin hicbir yerinde DUZ gorunmez."""
    kid = _kamera(client, yon, f"rtsp://kul:{PAROLA}@10.7.0.5:554/s1")
    try:
        url, kul, blob = _db_satir(owner_conn, kid)
        assert PAROLA not in url, "parola HÂLÂ adreste"
        assert "@" not in url.split("//", 1)[1].split("/", 1)[0], url
        assert kul == "kul"
        assert blob and PAROLA not in blob, "parola sifrelenmemis"
    finally:
        client.delete(f"/cameras/{kid}", headers=yon)


def test_SIFRELI_blob_GERI_COZULUR(client, yon, owner_conn):
    """Sifreleme tek yonlu bir kayip degil: sunucu kendi kullanimi icin
    parolayi geri cozebilmeli, yoksa kamera calismazdi."""
    from app.kamera_kimlik import parola_coz

    kid = _kamera(client, yon, f"rtsp://kul:{PAROLA}@10.7.0.6:554/s2")
    try:
        _, _, blob = _db_satir(owner_conn, kid)
        assert parola_coz(blob) == PAROLA
    finally:
        client.delete(f"/cameras/{kid}", headers=yon)


def test_AYRI_ALANLAR_da_kabul_edilir(client, yon, owner_conn):
    """Adresi elle temiz yazip kimligi forma girmek de calisir."""
    kid = _kamera(client, yon, "rtsp://10.7.0.7:554/s3",
                  stream_kullanici="admin", stream_parola=PAROLA)
    try:
        url, kul, blob = _db_satir(owner_conn, kid)
        assert url == "rtsp://10.7.0.7:554/s3"
        assert kul == "admin" and blob and PAROLA not in blob
    finally:
        client.delete(f"/cameras/{kid}", headers=yon)


def test_AYRI_ALAN_adresteki_kimligi_EZER(client, yon, owner_conn):
    """Iki kaynak catisirsa ONCELIK acik olmali: ayri alan kazanir.

    Belirsiz birakmak, kullanicinin parolayi degistirdigi ama eski
    adresi silmedigi durumda SESSIZCE eski parolayi saklamak olurdu.
    """
    from app.kamera_kimlik import parola_coz

    kid = _kamera(client, yon, "rtsp://eski:eskiparola@10.7.0.8:554/s4",
                  stream_parola="YeniParola9")
    try:
        _, _, blob = _db_satir(owner_conn, kid)
        assert parola_coz(blob) == "YeniParola9"
    finally:
        client.delete(f"/cameras/{kid}", headers=yon)


# ==================== YANITTAN SIZMAZ ===================================== #

def test_YANITTA_parola_HIC_gecmez(client, yon):
    """Yonetici bile parolayi GERI OKUYAMAZ (yazilir-okunmaz alan)."""
    kid = _kamera(client, yon, f"rtsp://kul:{PAROLA}@10.7.0.9:554/s5")
    try:
        for r in (client.get("/cameras?limit=100", headers=yon),):
            assert r.status_code == 200, r.text
            assert PAROLA not in r.text, "parola YANITTA sizdi"
            assert "stream_parola" not in r.text
    finally:
        client.delete(f"/cameras/{kid}", headers=yon)


def test_KULLANICI_ADI_doner_formda_gosterilebilsin(client, yon):
    """Kullanici adi sir DEGIL ve formda gorunmezse yonetici onu her
    duzenlemede yeniden yazmak zorunda kalirdi."""
    kid = _kamera(client, yon, "rtsp://10.7.0.10:554/s6",
                  stream_kullanici="operator", stream_parola=PAROLA)
    try:
        assert _oku(client, yon, kid)["stream_kullanici"] == "operator"
    finally:
        client.delete(f"/cameras/{kid}", headers=yon)


def test_PATCH_parola_degistirir_ADRESI_bozmaz(client, yon, owner_conn):
    from app.kamera_kimlik import parola_coz

    kid = _kamera(client, yon, "rtsp://10.7.0.11:554/s7",
                  stream_kullanici="u", stream_parola=PAROLA)
    try:
        r = client.patch(f"/cameras/{kid}", headers=yon,
                         json={"stream_parola": "BaskaParola1"})
        assert r.status_code == 200, r.text
        url, kul, blob = _db_satir(owner_conn, kid)
        assert url == "rtsp://10.7.0.11:554/s7"
        assert kul == "u"
        assert parola_coz(blob) == "BaskaParola1"
    finally:
        client.delete(f"/cameras/{kid}", headers=yon)


# ==================== SUNUCU ICI KULLANIM ================================= #

def test_SUNUCU_kimligi_GERI_TAKAR(client, yon):
    """Ayirma ise yaramali: ffmpeg/MediaMTX'e giden adres kimlikli olmali.

    Fonksiyon DOGRUDAN cagriliyor cunku olculen sey ag degil, adresin
    kendisi. (Zincirin tamami ayrica test_p213_canli_yayin.py'de.)
    """
    from types import SimpleNamespace

    from app.kamera_kimlik import parola_sakla
    from app.routers.cameras import etkin_stream_url

    sahte = SimpleNamespace(
        stream_url="rtsp://10.7.0.12:554/s8",
        stream_kullanici="kul",
        stream_parola_sifreli=parola_sakla(PAROLA),
    )
    adres = etkin_stream_url(sahte)
    assert adres.startswith("rtsp://kul:")
    assert "10.7.0.12:554/s8" in adres
    # Ozel karakterler KACISLI gitmeli, yoksa adres bozulurdu.
    assert "#" not in adres.split("@")[0].split("//")[1] or "%23" in adres


def test_KIMLIKSIZ_kamera_bozulmaz(client, yon, owner_conn):
    """Parolasiz (acik) kamera akisi ETKILENMEZ — bos kimlik takilmaz."""
    from types import SimpleNamespace

    from app.routers.cameras import etkin_stream_url

    kid = _kamera(client, yon, "rtsp://10.7.0.13:554/s9")
    try:
        url, kul, blob = _db_satir(owner_conn, kid)
        assert (kul, blob) == (None, None)
        assert etkin_stream_url(
            SimpleNamespace(stream_url=url, stream_kullanici=kul,
                            stream_parola_sifreli=blob)
        ) == "rtsp://10.7.0.13:554/s9"
    finally:
        client.delete(f"/cameras/{kid}", headers=yon)


def test_BOZUK_blob_ISTISNA_ATMAZ(client, yon):
    """KEK degisirse kamera listesi CIZILEMEZ olmamali.

    Sessiz dusus bilincli: parolasiz denenir, kamera acikta calisir ya da
    ffmpeg'in kendi "401" teshisi gorunur — liste 500 vermez.
    """
    from app.kamera_kimlik import parola_coz

    assert parola_coz("bu-gecerli-bir-blob-degil") is None
    assert parola_coz(None) is None


def test_COZULEMEYEN_kimlik_SESSIZCE_saklanmaz(client, yon):
    """Eski davranis en tehlikeli haliydi: parolada kacissiz `#` varsa
    `urlsplit` konagi kaybediyor, ayirma sessizce atlaniyor ve adres
    parolayla birlikte DUZ saklaniyordu — yani tam olarak kapatmaya
    calistigimiz durum, hem de fark edilmeden.

    Artik 422: kullaniciya parolayi ayri alana yazmasi soyleniyor.
    """
    r = client.post("/cameras", headers=yon, json={
        "ad": f"K-{uuid.uuid4().hex[:8]}",
        "stream_url": "rtsp://kul:Par#ola@10.7.0.20:554/s", "tur": "rtsp"})
    assert r.status_code == 422, r.text
    assert r.json()["error"]["message"]


def test_AYRI_ALAN_ozel_karakterli_parolayi_KABUL_eder(client, yon, owner_conn):
    """422 bir cikmaz sokak degil: gosterilen yol GERCEKTEN calisiyor."""
    from app.kamera_kimlik import parola_coz

    kid = _kamera(client, yon, "rtsp://10.7.0.21:554/s",
                  stream_kullanici="kul", stream_parola="Par#ola/9@x")
    try:
        _, _, blob = _db_satir(owner_conn, kid)
        assert parola_coz(blob) == "Par#ola/9@x"
    finally:
        client.delete(f"/cameras/{kid}", headers=yon)
