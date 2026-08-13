"""(P155r2) KAYIT YENIDEN INSASININ KIRMAMASI GEREKENLER.

Sartname KISITLAR maddesi uc olcum daha istiyordu ve ucu de BU dosyada:

  1. "demo hesaplarin hâlâ giris yapabildigi"  — KILITLI KURAL 2. Iki
     magazanin incelemesi bes rolun telefon+parola ile girmesine bagli;
     kayit akisi yeniden yazilirken giris yolunun bozulmadigi
     KANITLANMALI.
  2. "sosyal hesap + parola birlestirme" — ayni telefon hem parolayla hem
     Google ile gelirse TEK hesap iki yontem olmali, iki ayri hesap degil.
  3. Davet SMS'inin ICERIGI (sartname §4): tesis kodu + indirme baglantisi.

NEDEN DEMO HESAPLARI BURADA URETILIYOR: gercek demo tenant'i
`scripts/demo_tenant.py` ayri bir komutla ve `DEMO_PAROLA` ile kuruyor;
test veritabaninda YOKTUR. Ona bagimli bir test, betik kosulmadigi her
ortamda kirmizi olurdu. Bunun yerine AYNI SEKILDE (parolasi belirlenmis,
telefonu olan) hesaplar uretilip giris yolu olculuyor — korunan sey
hesaplarin kendisi degil, GIRIS YOLUDUR.
"""
from __future__ import annotations

import uuid

import pytest

#: KILITLI KURAL 2'nin saydigi roller. `guvenlik_amiri` de eklendi:
#: demo tenant'inda var ve ayni giris yolunu kullaniyor.
DEMO_ROLLER = (
    "yonetici",
    "security",
    "tesis_gorevlisi",
    "resident",
    "denetci",
    "guvenlik_amiri",
)

PAROLA = "DemoParolasi1"


def _tel() -> str:
    return "+9059" + str(uuid.uuid4().int)[:8]


def _parolali_hesap(owner_conn, slug: str, rol: str, telefon: str) -> uuid.UUID:
    """Demo hesabinin AYNISI: parolasi belirlenmis, telefonu olan, aktif.

    `gorev_baslangic`/`gorev_bitis` NULL birakiliyor — ikisi de NULL ise
    pencere YOKTUR (`deps.gorev_penceresi_disinda`), yani denetci de
    girebilir. Demo denetcisinin durumu da budur.
    """
    from app.security import hash_password

    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, email, telefon, password_hash, "
            "                      password_set, role, is_active) "
            "SELECT id, %s, %s, %s, %s, true, %s::user_role, true "
            "FROM tenant WHERE slug = %s RETURNING id",
            (
                f"Demo {rol}",
                f"{uuid.uuid4().hex[:10]}@test.local",
                telefon,
                hash_password(PAROLA),
                rol,
                slug,
            ),
        )
        return cur.fetchone()[0]


# ============ 1) DEMO HESAPLARI HÂLÂ GIRIYOR (KILITLI KURAL 2) ============= #


@pytest.mark.parametrize("rol", DEMO_ROLLER)
def test_DEMO_rolu_telefon_parola_ile_GIRER(client, world, owner_conn, rol):
    """Kayit akisi yeniden yazildi; GIRIS yolu DEGISMEMELI.

    Bu test kirmiziya donerse iki magazanin incelemesi de duser — o yuzden
    rol basina ayri bir olcum (hangi rolun bozuldugu dogrudan gorunsun).
    """
    tel = _tel()
    _parolali_hesap(owner_conn, world["slug_a"], rol, tel)

    r = client.post("/auth/login-phone", json={"phone": tel, "password": PAROLA})
    assert r.status_code == 200, f"{rol} GIRIS YAPAMIYOR: {r.text}"
    govde = r.json()
    assert govde["password_setup_required"] is False
    assert govde["access_token"]


def test_YANLIS_parola_ile_girilemez(client, world, owner_conn):
    """Mutlu yolun karsiti olmadan yukaridaki test bir sey KANITLAMAZ."""
    tel = _tel()
    _parolali_hesap(owner_conn, world["slug_a"], "yonetici", tel)

    r = client.post("/auth/login-phone", json={"phone": tel, "password": "YanlisParola9"})
    assert r.status_code == 401, r.text


def test_DEMO_hesabi_ELLE_KAYIT_yolundan_GECEMEZ(client, world, owner_conn):
    """Parolasi olan hesap sahiplenilemez — kayit, PAROLASIZ hesabi
    sahiplenmektir.

    Aksi hâlde uc, ikinci bir parola SIFIRLAMA yuzeyi olurdu: tesis kodunu
    ve numarayi bilen biri demo hesabinin parolasini degistirebilirdi.
    """
    tel = _tel()
    _parolali_hesap(owner_conn, world["slug_a"], "yonetici", tel)

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT kayit_kodu FROM tenant WHERE slug = %s", (world["slug_a"],)
        )
        kod = cur.fetchone()[0]

    # Yanit SIZDIRMAZ (eslesme olsa da olmasa da ayni), bu yuzden olcum
    # yanitta degil ETKIDE: kod satiri YAZILMAMALI.
    r = client.post("/auth/kayit/rol-basla", json={
        "rol": "yonetici", "tesis_kodu": kod, "telefon": tel,
    })
    assert r.status_code == 200, r.text
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM kayit_dogrulama "
            "WHERE telefon = %s AND durum = 'telefon_bekliyor'", (tel,)
        )
        assert cur.fetchone()[0] == 0, (
            "parolali hesap icin kod URETILDI — kayit ucu bir parola "
            "sifirlama yuzeyine donusmus"
        )


# ============== 2) SOSYAL + PAROLA -> TEK HESAP, IKI YONTEM =============== #


def test_SOSYAL_kimlik_MEVCUT_hesaba_baglanir_YENI_hesap_ACMAZ(
    client, world, owner_conn
):
    """Sartname §2: "aynı telefon hem parolayla hem Google ile gelirse TEK
    hesap iki yöntem olmalı, iki ayrı hesap değil."

    Semadaki garanti: `oauth_kimlik` satiri her zaman VAR OLAN bir
    `app_user`a baglanir (goc 0048) ve `app_user.telefon` GLOBAL
    benzersizdir. Bu test o iki kuralin BIRLIKTE tuttugunu olcer.
    """
    tel = _tel()
    user_id = _parolali_hesap(owner_conn, world["slug_a"], "yonetici", tel)

    # Kullanici Google'ini bagliyor (baglama akisinin yazdigi satirin
    # AYNISI — tarayici akisini surmeden, semayi dogrudan olcuyoruz).
    subject = f"google-sub-{uuid.uuid4().hex[:12]}"
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO oauth_kimlik (tenant_id, user_id, saglayici, subject, eposta) "
            "SELECT tenant_id, id, 'google'::oauth_saglayici, %s, %s "
            "FROM app_user WHERE id = %s",
            (subject, "demo@ornek.com", str(user_id)),
        )

        # (a) TEK KULLANICI: telefon global benzersiz, ikinci hesap yok.
        cur.execute("SELECT count(*) FROM app_user WHERE telefon = %s", (tel,))
        assert cur.fetchone()[0] == 1, "ayni telefon icin IKI hesap olusmus"

        # (b) Sosyal kimlik O kullaniciya bagli.
        cur.execute(
            "SELECT user_id FROM oauth_kimlik WHERE saglayici = 'google' "
            "AND subject = %s", (subject,)
        )
        assert cur.fetchone()[0] == user_id

        # (c) IKI YONTEM birden acik: parola DA duruyor.
        cur.execute("SELECT password_set FROM app_user WHERE id = %s", (str(user_id),))
        assert cur.fetchone()[0] is True, "sosyal baglama parolayi SILMIS"

    # (d) Ve parolayla giris HÂLÂ calisiyor — yontem EKLENDI, DEGISMEDI.
    r = client.post("/auth/login-phone", json={"phone": tel, "password": PAROLA})
    assert r.status_code == 200, r.text


def test_AYNI_sosyal_kimlik_IKI_hesaba_baglanamaz(world, owner_conn):
    """Bir Google hesabi iki kisiyi acamaz.

    `uq_oauth_kimlik_saglayici_subject` (goc 0048) bunu VERITABANINDA
    kilitliyor; uygulama katmanindaki `_BASKASINA_BAGLI` kontrolu onun
    kullaniciya anlasilir hâlidir. Kilidin KENDISI olculmezse, uygulama
    kontrolu bir gun atlandiginda kimse fark etmezdi.
    """
    import psycopg

    subject = f"google-sub-{uuid.uuid4().hex[:12]}"
    a = _parolali_hesap(owner_conn, world["slug_a"], "yonetici", _tel())
    b = _parolali_hesap(owner_conn, world["slug_a"], "resident", _tel())

    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO oauth_kimlik (tenant_id, user_id, saglayici, subject) "
            "SELECT tenant_id, id, 'google'::oauth_saglayici, %s "
            "FROM app_user WHERE id = %s", (subject, str(a)),
        )
    with pytest.raises(psycopg.errors.UniqueViolation):
        with owner_conn.cursor() as cur:
            cur.execute(
                "INSERT INTO oauth_kimlik (tenant_id, user_id, saglayici, subject) "
                "SELECT tenant_id, id, 'google'::oauth_saglayici, %s "
                "FROM app_user WHERE id = %s", (subject, str(b)),
            )
    owner_conn.rollback()


# ================= 3) DAVET SMS ICERIGI (sartname §4) ===================== #


def test_davet_mesaji_TESIS_KODU_ve_INDIRME_BAGLANTISI_tasir():
    """Sartname §4: "SMS gitmeli: uygulama indirme bağlantıları
    (Android + iOS), TESİS KODU."

    Metin BIRIM olarak olculuyor (uctan uca degil): gonderim katmani
    saglayici olmadan `basarisiz` doner ve govde yine de `mesaj_gonderim`e
    yazilir — ama olculmek istenen sey METNIN KENDISI.
    """
    from app.config import settings
    from app.davet import davet_mesaji

    metin = davet_mesaji("Oltu Sitesi", "https://ornek/davet/abc", "OLTU-260715")

    assert "Oltu Sitesi" in metin
    assert "OLTU-260715" in metin, "TESIS KODU mesajda yok"
    assert "https://ornek/davet/abc" in metin, "davet bagi mesajda yok"
    assert settings.play_store_url in metin, "Android indirme baglantisi yok"


def test_davet_mesaji_YAPILANDIRILMAMIS_magazayi_EKLEMEZ(monkeypatch):
    """App Store id'si henuz yok; uydurma bir id ile KIRIK baglanti
    gondermek, hic gondermemekten kotudur."""
    from app import davet as davet_modulu
    from app.config import settings

    monkeypatch.setattr(settings, "app_store_url", "", raising=False)
    metin = davet_modulu.davet_mesaji("Oltu Sitesi", "https://ornek/davet/abc", "OLTU-1")
    assert "iOS" not in metin

    monkeypatch.setattr(
        settings, "app_store_url", "https://apps.apple.com/app/id123", raising=False
    )
    metin = davet_modulu.davet_mesaji("Oltu Sitesi", "https://ornek/davet/abc", "OLTU-1")
    assert "https://apps.apple.com/app/id123" in metin


def test_davet_mesaji_KOD_YOKSA_bosluk_birakmaz():
    """Kod cozulemezse (beklenmedik) metin yine de anlamli kalmali."""
    from app.davet import davet_mesaji

    metin = davet_mesaji("Oltu Sitesi", "https://ornek/davet/abc", None)
    assert "Tesis kodu" not in metin
    assert "https://ornek/davet/abc" in metin
