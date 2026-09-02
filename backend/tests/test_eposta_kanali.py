"""(P172) E-POSTA KANALI — oncelik sirasi, OTP, davet, yapilandirma yoklugu.

===========================================================================
BU TURUN KURULUMU
===========================================================================
E-posta Resend uzerinden (587/STARTTLS) GENEL AYAR olarak `.env`de; SMS
gecidi HENUZ YAPILANDIRILMADI. Yani bugun e-posta CALISAN tek kanal ve
asagidaki iddialarin cogu tam olarak bu durumun sonuclarini olcuyor.

EN PAHALI SONUCLAR:
 1. Tesis kendi SMS'ini girdiginde e-postanin SESSIZCE kaybolmasi
    (oncelik KAYIT BASINA olsaydi olurdu — ve oyleydi).
 2. Yapilandirma yokken "gonderildi" denmesi: yonetici yesil bir satir
    gorur, kimseye bir sey ulasmaz.
 3. Davetin e-postayla ULASMASINA ragmen panelde "gitmedi" gorunmesi
    (ozet SMS'e sabitlenmisti).
"""
from __future__ import annotations

import pytest

import uuid

from app.mesajlasma import SaglayiciAyari, _ayardan_veya_env




@pytest.fixture(autouse=True)
def _giris_kod_hizini_sifirla(redis_client):
    """(P205 §1) HIZ SINIRI ARTIK ADRESE BAGLI, tesise DEGIL.

    Slug opsiyonel oldugu icin "tesis:eposta" anahtari her zaman
    kurulamiyor; sayac adres basina isliyor ve DOGRUSU bu (kotuye
    kullanan kisi ADRESI deniyor). Bedeli TESTTE: bu dosyadaki testler
    AYNI adresi paylasiyor ve sayac sifirlanmazsa birbirinin butcesini
    tuketiyorlar — kodla ilgisi olmayan 429'lar. (P203'te
    `hiz:tesislerim:*` icin alinan onlemin aynisi.)

    Sinirin KENDISI ayrica olculuyor: `test_p205_kod_girisi.py`.
    """
    if redis_client is None:
        yield
        return
    for anahtar in redis_client.scan_iter("hiz:giris_eposta:*"):
        redis_client.delete(anahtar)
    yield

def _p197_mail() -> str:
    """(P197) Kullanici/sakin olusturmada e-posta ZORUNLU oldu.

    `app_user.email` NOT NULL (goc 0089): davet, dogrulama kodu ve parola
    sifirlama YALNIZ e-postadan gidiyor, yani e-postasiz acilan hesap
    sahiplenilemez. Test govdelerine BENZERSIZ adres verilir —
    `uq_app_user_tenant_email` ayni tesiste tekrari reddeder.
    """
    return f"p197-{uuid.uuid4().hex[:12]}@ornek.com"

def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


# --------------------------------------------------------------------------- #
# 1. ONCELIK SIRASI — KANAL BASINA
# --------------------------------------------------------------------------- #
class _SahteAyar:
    """`settings` yerine gecen asgari nesne (ENV tarafi)."""

    sms_saglayici = "netgsm"
    sms_kullanici = "env-kullanici"
    sms_parola = "env-parola"
    sms_baslik = "ENVBASLIK"
    smtp_host = "smtp.resend.com"
    smtp_port = 587
    smtp_user = "resend"
    smtp_password = "env-anahtar"
    smtp_from = "noreply@yonetio.site"


def test_TESIS_AYARI_YOKSA_ENV_kullanilir(monkeypatch):
    import app.mesajlasma as m

    monkeypatch.setattr(m, "settings", _SahteAyar, raising=False)
    import app.config as c

    monkeypatch.setattr(c, "settings", _SahteAyar, raising=False)

    a = _ayardan_veya_env(None)
    assert a.smtp_host == "smtp.resend.com"
    assert a.sms_saglayici == "netgsm"


def test_TESIS_SMTPSI_VARSA_ONCELIKLIDIR(monkeypatch):
    import app.config as c

    monkeypatch.setattr(c, "settings", _SahteAyar, raising=False)

    a = _ayardan_veya_env(
        SaglayiciAyari(smtp_host="mail.tesis.test", smtp_gonderen="k@tesis.test")
    )
    assert a.smtp_host == "mail.tesis.test"
    assert a.smtp_gonderen == "k@tesis.test"


def test_TESIS_YALNIZ_SMSINI_GIRDIYSE_EPOSTA_YINE_ENVDEN(monkeypatch):
    """BU TURUN ASIL KUSURU.

    Eski kural KAYIT BASINAYDI: tesis yalniz SMS'ini girdiyse kaydin
    tamami "tesisin ayari" sayiliyor, `smtp_host` bos oldugu icin e-posta
    LOG'a dusuyordu — ENV'de CALISAN bir SMTP dururken. Resend genel
    ayar olarak durdugu icin bu, ilk tesis kendi SMS bayiligini girer
    girmez butun e-postalarin sessizce durmasi demekti.
    """
    import app.config as c

    monkeypatch.setattr(c, "settings", _SahteAyar, raising=False)

    a = _ayardan_veya_env(
        SaglayiciAyari(
            sms_saglayici="netgsm", sms_kullanici="tesis", sms_parola="p",
            sms_baslik="TESIS",
        )
    )
    # SMS tesisin...
    assert a.sms_saglayici == "netgsm"
    assert a.sms_kullanici == "tesis"
    # ...E-POSTA ENV'in.
    assert a.smtp_host == "smtp.resend.com"
    assert a.smtp_gonderen == "noreply@yonetio.site"


def test_TESIS_YALNIZ_SMTPSINI_GIRDIYSE_SMS_YINE_ENVDEN(monkeypatch):
    """Ters yon de olculur — simetri iddia edilmiyorsa kanitlanmamistir."""
    import app.config as c

    monkeypatch.setattr(c, "settings", _SahteAyar, raising=False)

    a = _ayardan_veya_env(SaglayiciAyari(smtp_host="mail.tesis.test"))
    assert a.smtp_host == "mail.tesis.test"
    assert a.sms_kullanici == "env-kullanici"


# --------------------------------------------------------------------------- #
# 2. YAPILANDIRMA YOKKEN — "GONDERILDI" DEMEZ
# --------------------------------------------------------------------------- #
def test_YAPILANDIRMA_YOKKEN_test_gonderimi_YAPILANDIRILMADI_doner(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/mesaj-ayarlari/test", headers=y, json={
        "kanal": "eposta", "hedef": "deneme@example.com"})
    assert r.status_code == 200, r.text
    d = r.json()
    # Test ortaminda SMTP yok. "gonderildi" demek, dogrulamanin TEK
    # aracini yalanci yapardi.
    assert d["durum"] == "yapilandirilmadi"
    # SEBEP EKRANDA: "neden gitmedi" sorusu yanitsiz kalmamali.
    assert d["hata"]


def test_TEST_GONDERIMI_GECMISE_YAZILMAZ(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    once = client.get("/mesajlar/gecmis?kanal=eposta", headers=y).json()["meta"]["total"]
    client.post("/mesaj-ayarlari/test", headers=y, json={
        "kanal": "eposta", "hedef": "deneme@example.com"})
    sonra = client.get("/mesajlar/gecmis?kanal=eposta", headers=y).json()["meta"]["total"]
    # Test bir bildirim degildir; gecmise dusmesi "kime ne gonderdik"
    # defterini kirletirdi.
    assert sonra == once


# --------------------------------------------------------------------------- #
# 3. E-POSTA OTP
# --------------------------------------------------------------------------- #
def test_EPOSTA_KODU_ISTEGI_ADRES_VARLIGINI_SIZDIRMAZ(client, world, konsol_eposta):
    kayitli = client.post("/auth/giris/eposta-kod-iste", json={
        "tenant_slug": world["slug_a"], "eposta": world["yonetici_a"]["email"]})
    yok = client.post("/auth/giris/eposta-kod-iste", json={
        "tenant_slug": world["slug_a"], "eposta": "olmayan@example.com"})
    bilinmeyen_tesis = client.post("/auth/giris/eposta-kod-iste", json={
        "tenant_slug": "olmayan-tesis", "eposta": "x@example.com"})

    # UCU DE AYNI: aksi halde uc, "hangi adresler kayitli" sorgusu olurdu.
    assert kayitli.status_code == yok.status_code == bilinmeyen_tesis.status_code == 200
    assert kayitli.json() == yok.json() == bilinmeyen_tesis.json()


def test_EPOSTA_KODU_TELEFON_KODUYLA_AYNI_MEKANIZMA(client, world, owner_conn):
    """Kod ayni tabloya, ayni sure ve ayni hash kurallariyla yazilir."""
    client.post("/auth/giris/eposta-kod-iste", json={
        "tenant_slug": world["slug_a"], "eposta": world["yonetici_a"]["email"]})

    satir = owner_conn.execute(
        "SELECT eposta, telefon, kod_hash, amac, durum, "
        "son_gecerlilik > now() AS gecerli "
        "FROM kayit_dogrulama WHERE tenant_id = %s AND eposta = %s",
        (world["a"], world["yonetici_a"]["email"].lower()),
    ).fetchone()
    assert satir is not None, "kod satiri yazilmadi"
    # TELEFON BOS: kimlik e-posta.
    assert satir[1] is None
    # KOD DUZ METIN DEGIL (bcrypt ozeti).
    assert satir[2].startswith("$2")
    assert satir[3] == "giris"
    assert satir[4] == "telefon_bekliyor"
    assert satir[5] is True


def test_EPOSTA_KODU_YANLIS_KOD_REDDEDER(client, world):
    client.post("/auth/giris/eposta-kod-iste", json={
        "tenant_slug": world["slug_a"], "eposta": world["yonetici_a"]["email"]})
    r = client.post("/auth/giris/eposta-kod-dogrula", json={
        "tenant_slug": world["slug_a"],
        "eposta": world["yonetici_a"]["email"], "kod": "000000"})
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "invalid_code"


def test_EPOSTA_KODU_DOGRU_KOD_OTURUM_ACAR(client, world, owner_conn):
    """Kod dogruysa PAROLASIZ oturum acilir — telefon yolunun esi."""
    from app.security import hash_password

    eposta = world["yonetici_a"]["email"].lower()
    client.post("/auth/giris/eposta-kod-iste", json={
        "tenant_slug": world["slug_a"], "eposta": eposta})
    # Kod hash'li saklandigi icin okunamaz; bilinen bir kodla degistiriyoruz.
    owner_conn.execute(
        "UPDATE kayit_dogrulama SET kod_hash = %s WHERE tenant_id = %s "
        "AND eposta = %s AND durum = 'telefon_bekliyor'",
        (hash_password("123456"), world["a"], eposta),
    )
    owner_conn.commit()

    r = client.post("/auth/giris/eposta-kod-dogrula", json={
        "tenant_slug": world["slug_a"], "eposta": eposta, "kod": "123456"})
    assert r.status_code == 200, r.text
    assert r.json()["access_token"]

    # KOD TUKETILIR: ikinci kez calismaz.
    r2 = client.post("/auth/giris/eposta-kod-dogrula", json={
        "tenant_slug": world["slug_a"], "eposta": eposta, "kod": "123456"})
    assert r2.status_code == 422


def test_EPOSTA_KODU_GIRISI_ADRESI_DOGRULAR(client, world, owner_conn):
    """(P181 Bölüm 4) Kodu girmek adresin kontrolunu kanitlar -> eposta_dogrulandi
    ACILIR. Boylece e-postali ama hic dogrulamamis MEVCUT kullanici OTP ile girip
    otomatik dogrulanir (parola sifirlama onlar icin de calisir)."""
    from app.security import hash_password

    eposta = world["yonetici_a"]["email"].lower()
    # ONCE: world kullanicisi dogrulanmamis baslar (Bölüm 1 varsayilani).
    onceki = owner_conn.execute(
        "SELECT eposta_dogrulandi FROM app_user WHERE tenant_id = %s "
        "AND lower(email) = %s",
        (world["a"], eposta),
    ).fetchone()
    assert onceki[0] is False

    client.post("/auth/giris/eposta-kod-iste", json={
        "tenant_slug": world["slug_a"], "eposta": eposta})
    owner_conn.execute(
        "UPDATE kayit_dogrulama SET kod_hash = %s WHERE tenant_id = %s "
        "AND eposta = %s AND amac = 'giris' AND durum = 'telefon_bekliyor'",
        (hash_password("123456"), world["a"], eposta),
    )
    owner_conn.commit()

    r = client.post("/auth/giris/eposta-kod-dogrula", json={
        "tenant_slug": world["slug_a"], "eposta": eposta, "kod": "123456"})
    assert r.status_code == 200, r.text

    sonraki = owner_conn.execute(
        "SELECT eposta_dogrulandi FROM app_user WHERE tenant_id = %s "
        "AND lower(email) = %s",
        (world["a"], eposta),
    ).fetchone()
    assert sonraki[0] is True, "OTP giris eposta_dogrulandi bayragini acmadi"


def test_EPOSTA_KODU_TESIS_SINIRINI_GECMEZ(client, world, owner_conn):
    """Ayni adres iki tesiste olabilir; kod BIRININ kodudur.

    E-posta telefon gibi global benzersiz DEGIL. Tesis kodu olmadan
    dogrulama, ayni adresi kullanan iki tesisin kodlarini karistirirdi.
    """
    from app.security import hash_password

    eposta = world["yonetici_a"]["email"].lower()
    client.post("/auth/giris/eposta-kod-iste", json={
        "tenant_slug": world["slug_a"], "eposta": eposta})
    owner_conn.execute(
        "UPDATE kayit_dogrulama SET kod_hash = %s WHERE tenant_id = %s "
        "AND eposta = %s AND durum = 'telefon_bekliyor'",
        (hash_password("123456"), world["a"], eposta),
    )
    owner_conn.commit()

    # B tesisinde ayni e-posta var (conftest: SHARED_EMAIL) ama kod A'nin.
    r = client.post("/auth/giris/eposta-kod-dogrula", json={
        "tenant_slug": world["slug_b"], "eposta": eposta, "kod": "123456"})
    assert r.status_code == 422


# --------------------------------------------------------------------------- #
# 4. DAVET
# --------------------------------------------------------------------------- #
def test_DAVET_JETONU_TEK_KULLANIMLIK_VE_SURELI(client, world, owner_conn):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    tel = f"+9053{uuid.uuid4().int % 10**8:08d}"
    r = client.post("/residents", headers=y, json={
        "telefon": tel, "unit_no": f"DV-{uuid.uuid4().hex[:4]}", "email": _p197_mail()})
    assert r.status_code == 201, r.text

    satir = owner_conn.execute(
        "SELECT jeton_hash, son_gecerlilik > now(), used_at FROM davet "
        "WHERE tenant_id = %s ORDER BY created_at DESC LIMIT 1", (world["a"],)
    ).fetchone()
    assert satir is not None
    # JETON DUZ METIN DEGIL: bagda bir kez uretilir, veritabaninda ozeti durur.
    assert len(satir[0]) == 64  # sha256 hex
    # SURELI ve HENUZ KULLANILMAMIS.
    assert satir[1] is True
    assert satir[2] is None


def test_DAVET_YAPILANDIRMA_YOKKEN_GONDERILDI_DEMEZ(client, world):
    """§7'nin davet yolundaki karsiligi.

    Test ortaminda ne SMS ne SMTP var; hicbir yere hicbir sey gitmedi.
    Eski kod `durum != "basarisiz"` diyordu ve `yapilandirilmadi`yi
    BASARI sayiyordu.
    """
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/residents", headers=y, json={
        "telefon": f"+9053{uuid.uuid4().int % 10**8:08d}",
        "unit_no": f"DV-{uuid.uuid4().hex[:4]}", "email": _p197_mail()})
    assert r.status_code == 201, r.text
    assert r.json()["davet"]["gonderildi"] is False


def test_DAVET_MESAJI_TESIS_KODUNU_TASIR(client, world, owner_conn):
    """Bag tek basina yetmez: kullanici tesis kodunu da bilmeli. (P188) Davet
    BIRINCIL kanal E-POSTA (SMS kapali); e-posta govdesi tesis kodunu tasir."""
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    client.post("/residents", headers=y, json={
        "telefon": f"+9053{uuid.uuid4().int % 10**8:08d}",
        "unit_no": f"DV-{uuid.uuid4().hex[:4]}",
        "email": f"kod-{uuid.uuid4().hex[:8]}@example.com"})

    kod = owner_conn.execute(
        "SELECT kayit_kodu FROM tenant WHERE id = %s", (world["a"],)
    ).fetchone()[0]
    govde = owner_conn.execute(
        "SELECT govde FROM mesaj_gonderim WHERE tenant_id = %s AND kanal = 'eposta' "
        "ORDER BY created_at DESC LIMIT 1", (world["a"],)
    ).fetchone()[0]
    assert kod in govde


def test_DAVET_KANALLARI_AYNI_DAVET_BAGINI_TASIR(client, world, owner_conn):
    """(P186) SMS ve e-posta davet sablonlari ARTIK AYRI: e-posta ZENGIN HTML
    (davet_eposta, 7 dil), SMS ise KISA metin (uzunluk). Eskiden byte-byte AYNI
    olmalari beklenirdi; artik degil. Anti-drift olcusu su: HER IKI kanal da
    ayni daveti tasir — kanonik davet BAGI (`/davet/<jeton>`) ikisinde de bulunur.
    """
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    tel = f"+9053{uuid.uuid4().int % 10**8:08d}"
    r = client.post("/residents", headers=y, json={
        "telefon": tel, "unit_no": f"DV-{uuid.uuid4().hex[:4]}",
        "email": f"d{uuid.uuid4().hex[:6]}@example.com"})
    assert r.status_code == 201, r.text

    satirlar = owner_conn.execute(
        "SELECT kanal, govde FROM mesaj_gonderim WHERE tenant_id = %s "
        "AND hedef IN (%s, %s)",
        (world["a"], tel, r.json().get("email") or ""),
    ).fetchall()
    govdeler = {k: g for k, g in satirlar}
    # Kaydedilen her kanal davet BAGINI icermeli (ikisi ayni icerigi tasir).
    for kanal, govde in govdeler.items():
        assert "/davet/" in govde, f"{kanal}: davet bagi tasinmiyor"
