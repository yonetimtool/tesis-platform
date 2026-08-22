"""KVKK aydinlatma + onay + pazarlama izinleri (P36)."""
from __future__ import annotations

import uuid

import pytest


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def rol(client, world):
    return {
        "admin": _h(client, world["slug_a"], world["admin_a"]),
        "yonetici": _h(client, world["slug_a"], world["yonetici_a"]),
        "sakin": _h(client, world["slug_a"], world["resident_a"]),
        "guard": _h(client, world["slug_a"], world["guard_a"]),
    }


def _yayinla(client, h, govde=None, tenant=None):
    """(P170 §2) YAYIN PLATFORM YOLUNDAN — hedef tenant YOLDA tasinir.

    Tesis yuzeyindeki `POST /kvkk/metin` kaldirildi: metinleri platform
    yonetiyor. `h` bir PLATFORM ADMIN basligi olmali.
    """
    return client.post(f"/tenants/{tenant}/kvkk", headers=h, json={
        "baslik": "Aydınlatma Metni",
        "govde": govde or f"Kişisel verileriniz... {uuid.uuid4().hex}"})


# ============================== METIN ======================================= #
def test_metin_YOKKEN_kapi_KURULMAZ(client, rol):
    """Metinsiz bir kapi, kullaniciya OKUMADAN onaylatmak olurdu."""
    d = client.get("/kvkk/durum", headers=rol["sakin"]).json()
    assert d["metin_var"] is False
    assert d["onay_gerekli"] is False
    assert client.get("/kvkk/metin", headers=rol["sakin"]).status_code == 404


def test_yayinla_ve_SURUM_BIRDEN_baslar(client, rol, world):
    r = _yayinla(client, rol["admin"], tenant=world["a"])
    assert r.status_code == 201, r.text
    assert r.json()["surum"] == 1
    # Ikinci (FARKLI) metin -> surum 2
    assert _yayinla(client, rol["admin"], tenant=world["a"]).json()["surum"] == 2


def test_AYNI_GOVDE_yeniden_yayinlanamaz(client, rol, world):
    """Degismemis bir metin icin herkesi yeniden onaya zorlamak, onayi
    anlamsiz bir tikla dondururdu."""
    govde = f"Ayni metin {uuid.uuid4().hex}"
    assert _yayinla(client, rol["admin"], govde, tenant=world["a"]).status_code == 201
    r = _yayinla(client, rol["admin"], govde, tenant=world["a"])
    assert r.status_code == 409, r.text
    assert r.json()["error"]["code"] == "conflict"


def test_metin_DUZENLEME_UCU_YOK(client, rol, world):
    """Yerinde duzenleme, dun verilen onayi bugun BASKA BIR METNE ait
    gosterirdi — bu yuzden PATCH/PUT/DELETE hic tanimlanmadi."""
    m = _yayinla(client, rol["admin"], tenant=world["a"]).json()
    for metot in ("patch", "put", "delete"):
        r = getattr(client, metot)(f"/kvkk/metin/{m['id']}", headers=rol["yonetici"])
        assert r.status_code in (404, 405), (metot, r.status_code)


def test_metni_HERKES_okur_ama_YAYINI_yonetim_yapar(client, rol, world):
    _yayinla(client, rol["admin"], tenant=world["a"])
    # Metin kullanicinin KENDI verisi hakkindadir: okuyamamak aydinlatmayi
    # imkansiz kilardi.
    for kim in ("sakin", "guard", "admin"):
        assert client.get("/kvkk/metin", headers=rol[kim]).status_code == 200
    # (P170 §2) YAYIN TESIS ROLLERINE KAPALI — YONETICI DAHIL.
    assert _yayinla(client, rol["sakin"], tenant=world["a"]).status_code == 403
    assert _yayinla(client, rol["yonetici"], tenant=world["a"]).status_code == 403


# ============================== ONAY ======================================== #
def test_onay_akisi(client, rol, world):
    m = _yayinla(client, rol["admin"], tenant=world["a"]).json()
    d = client.get("/kvkk/durum", headers=rol["sakin"]).json()
    assert d["onay_gerekli"] is True and d["guncel_surum"] == m["surum"]

    r = client.post("/kvkk/onay", headers=rol["sakin"], json={"surum": m["surum"]})
    assert r.status_code == 201, r.text
    assert r.json()["onay_gerekli"] is False
    assert r.json()["onayladigi_surum"] == m["surum"]
    assert r.json()["onay_at"]


def test_SURUM_ARTINCA_yeniden_onay_gerekir(client, rol, world):
    """Surum artmasi, METNIN DEGISTIGINI kullaniciya soylemenin tek durust
    yoludur."""
    m1 = _yayinla(client, rol["admin"], tenant=world["a"]).json()
    client.post("/kvkk/onay", headers=rol["sakin"], json={"surum": m1["surum"]})
    assert client.get("/kvkk/durum", headers=rol["sakin"]).json()[
        "onay_gerekli"] is False

    _yayinla(client, rol["admin"], tenant=world["a"])  # surum 2
    d = client.get("/kvkk/durum", headers=rol["sakin"]).json()
    assert d["onay_gerekli"] is True
    # (P168 §5) `onayladigi_surum` ARTIK KULLANICININ SON ONAYINI doner
    # (burada 1); eskiden `None` donuyordu.
    #
    # ESKI DAVRANIS DAHA AZ DURUSTTU: alanin adi "onayladigi surum" ve
    # kullanici GERCEKTEN 1. surumu onaylamisti — `None`, "hicbir sey
    # onaylamadi" demekti ve bu YANLISTI.
    #
    # Yeni deger ayrica GEREKLI: "yeniden onay gerekmez" bayragi tam
    # olarak "onayladigi surum < guncel surum" farkini kullaniyor.
    assert d["onayladigi_surum"] == m1["surum"]
    assert d["onayladigi_surum"] < d["guncel_surum"]


def test_ESKI_SURUME_onay_409(client, rol, world):
    """Kullanici okurken yeni surum ciktiysa, onayi ESKI METNE aitti;
    sessizce yeni surume yazmak okumadigi metni onaylatmak olurdu."""
    m1 = _yayinla(client, rol["admin"], tenant=world["a"]).json()
    _yayinla(client, rol["admin"], tenant=world["a"])  # surum 2
    r = client.post("/kvkk/onay", headers=rol["sakin"], json={"surum": m1["surum"]})
    assert r.status_code == 409, r.text


def test_onay_IDEMPOTENT(client, rol, owner_conn, world):
    m = _yayinla(client, rol["admin"], tenant=world["a"]).json()
    for _ in range(3):
        assert client.post("/kvkk/onay", headers=rol["sakin"],
                           json={"surum": m["surum"]}).status_code == 201
    sayi = owner_conn.execute(
        "SELECT count(*) FROM kvkk_onay WHERE tenant_id = %s AND surum = %s",
        (world["a"], m["surum"])).fetchone()[0]
    assert sayi == 1


def test_onay_KISI_BAZLI(client, rol, world):
    m = _yayinla(client, rol["admin"], tenant=world["a"]).json()
    client.post("/kvkk/onay", headers=rol["sakin"], json={"surum": m["surum"]})
    # Baskasinin onayi benim onayim degildir.
    assert client.get("/kvkk/durum", headers=rol["guard"]).json()[
        "onay_gerekli"] is True


def test_tenant_izolasyonu(client, world):
    """(P170 §2) YONETIM PLATFORMA GECTI AMA VERI TENANT'A BAGLI KALDI.

    Platform yoneticisi A tesisine yayin yapiyor; B tesisi bunu GORMUYOR.
    Yetkinin tasinmasi, metinlerin ortaklastigi anlamina GELMEZ — her
    tesisin veri sorumlusu kendisidir.
    """
    a = _h(client, world["slug_a"], world["admin_a"])
    b = _h(client, world["slug_b"], world["yonetici_b"])
    r = client.post(f"/tenants/{world['a']}/kvkk", headers=a, json={
        "baslik": "A metni", "govde": "A tesisinin metni"})
    assert r.status_code == 201, r.text
    assert client.get("/kvkk/metin", headers=b).status_code == 404


# ========================== PAZARLAMA IZINLERI ============================== #
def test_tercihler_VARSAYILAN_KAPALI(client, rol):
    """KVKK: riza ACIK olmali, varsayilan olamaz."""
    t = client.get("/me/pazarlama-tercihleri", headers=rol["sakin"]).json()
    assert t == {"eposta": False, "sms": False, "arama": False,
                 "guncelleme_at": None}


def test_kanallar_BAGIMSIZ(client, rol):
    """Tek bir bayrak, kisiyi istemedigi kanaldan mesaj almak ile hic
    almamak arasinda secmeye zorlardi."""
    r = client.patch("/me/pazarlama-tercihleri", headers=rol["sakin"],
                     json={"eposta": True})
    assert r.status_code == 200, r.text
    assert r.json()["eposta"] is True
    assert r.json()["sms"] is False and r.json()["arama"] is False
    assert r.json()["guncelleme_at"]

    # Gonderilmeyen kanal DEGISMEZ.
    r2 = client.patch("/me/pazarlama-tercihleri", headers=rol["sakin"],
                      json={"sms": True})
    assert r2.json()["eposta"] is True and r2.json()["sms"] is True

    # Geri alinabilir (riza her an geri alinabilir).
    r3 = client.patch("/me/pazarlama-tercihleri", headers=rol["sakin"],
                      json={"eposta": False})
    assert r3.json()["eposta"] is False and r3.json()["sms"] is True


def test_bos_govde_422_ve_bilinmeyen_alan_422(client, rol):
    assert client.patch("/me/pazarlama-tercihleri", headers=rol["sakin"],
                        json={}).status_code == 422
    assert client.patch("/me/pazarlama-tercihleri", headers=rol["sakin"],
                        json={"hepsi": True}).status_code == 422


def test_riza_degisimi_DENETLENIR(client, rol, owner_conn, world):
    """KVKK'da ispat yukumlulugu VERI SORUMLUSUNDADIR."""
    client.patch("/me/pazarlama-tercihleri", headers=rol["sakin"],
                 json={"sms": True})
    satir = owner_conn.execute(
        "SELECT meta FROM audit_log WHERE tenant_id = %s AND action = "
        "'pazarlama_riza' ORDER BY ts DESC LIMIT 1", (world["a"],)).fetchone()
    assert satir is not None and satir[0]["sms"] == "True"


def test_tercih_HER_ZAMAN_KENDISI_icin(client, rol, world):
    """Baskasinin rizasini kimse veremez — bu yuzden /users/{id} altinda
    bir ikizi YOKTUR."""
    sakin_id = client.get("/me", headers=rol["sakin"]).json()["id"]
    r = client.patch(f"/users/{sakin_id}", headers=rol["yonetici"],
                     json={"pazarlama_sms": True})
    # Alan UserUpdate semasinda YOK -> ya 422 ya da sessizce yok sayilmaz.
    assert r.status_code in (403, 422), r.text
    assert client.get("/me/pazarlama-tercihleri",
                      headers=rol["sakin"]).json()["sms"] is False


# ===================== P32 BAGLANTISI: GERCEK RIZA KAPISI =================== #
def test_pazarlama_gonderimi_RIZAYA_bagli(client, rol, world):
    """P32'de riza kapisi 'hepsini atla' idi; P36 ile GERCEK riza okunur."""
    sablon = client.post("/mesaj-sablonlari", headers=rol["yonetici"], json={
        "kanal": "sms", "ad": f"Kampanya {uuid.uuid4().hex[:6]}",
        "govde": "Sayın {adi_soyadi}, kampanyamız var.", "amac": "pazarlama"})
    assert sablon.status_code == 201, sablon.text
    sid = sablon.json()["id"]
    sakin_id = client.get("/me", headers=rol["sakin"]).json()["id"]

    # Riza YOKken: atlanir ve SAYILIR (sessiz dusurme yok).
    r = client.post("/mesajlar/gonder", headers=rol["yonetici"], json={
        "sablon_id": sid, "user_ids": [sakin_id]})
    assert r.status_code == 201, r.text
    assert r.json()["riza_yok"] == 1 and r.json()["gonderildi"] == 0

    # SMS rizasi verilince gider — AMA KANAL ACIKSA.
    #
    # (P177 §4) TICARI ILETI ANA SALTERI. `TICARI_ILETI_AKTIF=false`
    # (varsayilan) iken pazarlama gonderimi RIZA OLSA BILE yapilmaz:
    # sirket ve IYS kaydi yok, IYS'ye islenmemis bir rizayla ticari
    # ileti gondermek idari para cezasi sebebidir.
    #
    # TEST IKI KIPI DE KABUL EDER cunku bayrak ORTAMDAN gelir ve testler
    # ayri bir surecte kosan sunucuya vurur — `settings`i buradan okumak
    # yaniltici olurdu. Yine de GEVSEK DEGIL: iki kipten TAM BIRI
    # tutmali. Salterin kendisi (riza kontrolunden ONCE okundugu dahil)
    # `test_p177_sms_ve_ileti.py`de ayrica olculuyor.
    client.patch("/me/pazarlama-tercihleri", headers=rol["sakin"],
                 json={"sms": True})
    r2 = client.post("/mesajlar/gonder", headers=rol["yonetici"], json={
        "sablon_id": sid, "user_ids": [sakin_id]})
    ozet = r2.json()
    kanal_acik = ozet["gonderildi"] == 1 and ozet["riza_yok"] == 0
    kanal_kapali = ozet["gonderildi"] == 0 and ozet["riza_yok"] == 1
    assert kanal_acik != kanal_kapali, (
        "pazarlama gonderimi ne 'gitti' ne 'kanal kapali' dedi: "
        f"{ozet}"
    )


def test_riza_KANAL_BAZLI(client, rol):
    """E-postaya izin veren kisi SMS'e izin vermis SAYILMAZ."""
    client.patch("/me/pazarlama-tercihleri", headers=rol["sakin"],
                 json={"eposta": True, "sms": False})
    sid = client.post("/mesaj-sablonlari", headers=rol["yonetici"], json={
        "kanal": "sms", "ad": f"K {uuid.uuid4().hex[:6]}",
        "govde": "SMS kampanya", "amac": "pazarlama"}).json()["id"]
    sakin_id = client.get("/me", headers=rol["sakin"]).json()["id"]
    r = client.post("/mesajlar/gonder", headers=rol["yonetici"], json={
        "sablon_id": sid, "user_ids": [sakin_id]})
    assert r.json()["riza_yok"] == 1, r.text


def test_OPERASYONEL_mesaj_riza_ISTEMEZ(client, rol):
    """KMK yukumluluguyle gonderilen finansal bildirim AYRI bir hukuki
    dayanaktir — pazarlama rizasina baglanmasi yanlis olurdu."""
    sid = client.post("/mesaj-sablonlari", headers=rol["yonetici"], json={
        "kanal": "sms", "ad": f"Bildirim {uuid.uuid4().hex[:6]}",
        "govde": "Bakiyeniz {bakiye} TL.", "amac": "operasyonel"}).json()["id"]
    sakin_id = client.get("/me", headers=rol["sakin"]).json()["id"]
    r = client.post("/mesajlar/gonder", headers=rol["yonetici"], json={
        "sablon_id": sid, "user_ids": [sakin_id]})
    assert r.json()["gonderildi"] == 1 and r.json()["riza_yok"] == 0
