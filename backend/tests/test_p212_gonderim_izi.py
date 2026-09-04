"""(P212-ek §1) KOD GONDEREN HER AKIS `mesaj_gonderim`E IZ BIRAKIR.

===========================================================================
OLCULEN KUSUR (prod)
===========================================================================
Kullanici profilden e-postasini degistirdi; ekran "dogrulama bekliyor"
dedi ve kod girme alani acildi. `mesaj_gonderim` tablosunda O ADRESE AIT
HICBIR KAYIT YOKTU — yani sorun SMTP degildi, AKIS GONDERIMI HIC
TETIKLEMEMISTI.

Sebep: adres BASKA bir kullanicida kayitliydi ve uc, sizdirmama adina
kod URETMEDEN `{"durum": "gonderildi"}` donuyordu (P184-ek §9 karari).
Kullanici acisindan sonuc: kendi e-postasini duzeltemiyor ve NEDENINI
ogrenemiyor.

===========================================================================
NEDEN P196 BU AKISI KAPSAMADI
===========================================================================
P196 "gonderim DENENDI ama BASARISIZ oldu, yine de basarili dendi"
halini kapatti: `eposta_kodu_uret_ve_gonder`in sonucunu okuyup 502
donmeye basladi. Buradaki hal ise "gonderim HIC DENENMEDI" idi ve akis
o kontrolden ONCE `return` ediyordu. P196'nin kapisi dogru yerdeydi ama
KAPININ ONUNDEN GECEN bir yol vardi.

Bu dosya kapiyi IZE bagliyor: gonderim denendiyse `telefon_kodu` AYRI
OTURUMDA bir `mesaj_gonderim` satiri yazar (basarili ya da basarisiz).
Satir yoksa akis gonderimi tetiklememistir — hangi yeni erken-donusun
eklendiginden BAGIMSIZ olarak yakalanir.

===========================================================================
IKI SINIF AKIS, IKI FARKLI KURAL
===========================================================================
KIMLIK DOGRULANMIS self-servis (profil e-postasi, hesap silme kodu):
  gonderilmediyse KULLANICIYA HATA doner. Sizinti yok — kisi zaten
  kendi hesabinda.

KIMLIKSIZ akislar (giris kodu, parola sifirlama, kayit OTP): yanit TEK
  BICIMDIR ve hata YANSITILMAZ; aksi halde "hata = adres kayitli" bir
  sorgu olurdu. Kural burada "hedef VARSA iz birakilmali" seklinde
  olculur — yaniti degil DAVRANISI kilitler.
"""
from __future__ import annotations

import uuid


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _iz(owner_conn, eposta: str) -> int:
    """Bu adrese ait `mesaj_gonderim` satir sayisi (durum ne olursa olsun)."""
    owner_conn.commit()  # baska oturumun yazdigini gormek icin
    return owner_conn.execute(
        "SELECT count(*) FROM mesaj_gonderim WHERE lower(hedef)=lower(%s)",
        (eposta,),
    ).fetchone()[0]


def _yeni_adres() -> str:
    return f"p212-{uuid.uuid4().hex[:10]}@ornek.com"


def _dogrulanmis_kullanici(owner_conn, tenant_id) -> str:
    """DOGRULANMIS e-postali TAZE kullanici; adresini doner.

    HER KOSUMDA YENI ADRES sart: hiz siniri (`kod_istegi_say`) ADRES
    BASINA sayiyor. Sabit bir adres kullanmak, tekrarlanan kosumlarda
    429 uretip testi ANLAMSIZ yere kiriyordu (olculdu — ilk yazimda tam
    olarak bu oldu).
    """
    from app.security import hash_password

    adres = _yeni_adres()
    owner_conn.execute(
        "INSERT INTO app_user (tenant_id, ad, email, telefon, password_hash, "
        "password_set, eposta_dogrulandi, role) "
        "VALUES (%s,%s,%s,%s,%s,true,true,'resident'::user_role)",
        (tenant_id, "P212 Dogrulanmis", adres,
         f"+9056{uuid.uuid4().int % 10**8:08d}", hash_password("Parola123!")))
    owner_conn.commit()
    return adres


# ============ 1) PROFIL E-POSTASI — OLCULEN KUSURUN TA KENDISI =========== #

def test_PROFIL_eposta_SERBEST_adres_IZ_BIRAKIR(client, world, owner_conn):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    adres = _yeni_adres()
    assert _iz(owner_conn, adres) == 0

    r = client.post("/me/eposta/kod-iste", headers=h, json={"eposta": adres})
    # Dev'de SMTP yok -> 502 (P196 kapisi). Olculen sey YANIT DEGIL, IZ:
    # gonderim GERCEKTEN denendi mi?
    assert r.status_code in (200, 502), r.text
    assert _iz(owner_conn, adres) == 1, "gonderim kaydi OLUSMADI"


def test_PROFIL_eposta_BASKASININ_adresi_409_ve_SESSIZ_DEGIL(
    client, world, owner_conn
):
    """Kullanicinin bildirdigi hâl: ekran 'bekliyor' diyor, hicbir sey
    gonderilmiyor. Artik ACIK bir 409 doner.

    ADRES HER KOSUMDA YENI: hiz siniri (`kod_istegi_say`) ADRES BASINA
    sayiyor ve sabit bir adres kullanmak, tekrarlanan kosumlarda 429
    uretip testi ANLAMSIZ yere kirmisti (olculdu).
    """
    from app.security import hash_password

    h = _h(client, world["slug_a"], world["yonetici_a"])
    baska = _yeni_adres()
    owner_conn.execute(
        "INSERT INTO app_user (tenant_id, ad, email, telefon, password_hash, "
        "password_set, role) VALUES (%s,%s,%s,%s,%s,true,'resident'::user_role)",
        (world["a"], "P212 Baskasi", baska,
         f"+9055{uuid.uuid4().int % 10**8:08d}", hash_password("Parola123!")))
    owner_conn.commit()
    once = _iz(owner_conn, baska)

    r = client.post("/me/eposta/kod-iste", headers=h, json={"eposta": baska})
    assert r.status_code == 409, r.text
    assert r.json()["error"]["code"] == "conflict"
    # Gonderim YOK — ve kullanici bunu BILIYOR (200 "gonderildi" degil).
    assert _iz(owner_conn, baska) == once
    # KIM OLDUGU SIZMAZ: mesaj kullaniciyi adlandirmaz.
    assert "admin" not in r.json()["error"]["message"].lower()


def test_PROFIL_eposta_AYNI_adres_tekrar_dogrulama_IZ_BIRAKIR(
    client, world, owner_conn
):
    """Kendi adresini yeniden dogrulatmak da bir GONDERIMDIR."""
    h = _h(client, world["slug_a"], world["yonetici_a"])
    adres = _yeni_adres()
    client.post("/me/eposta/kod-iste", headers=h, json={"eposta": adres})
    once = _iz(owner_conn, adres)
    client.post("/me/eposta/kod-iste", headers=h, json={"eposta": adres})
    assert _iz(owner_conn, adres) == once + 1


# ============ 2) HESAP SILME KODU (kimlik dogrulanmis) ================== #

def test_HESAP_SILME_kodu_IZ_BIRAKIR(client, world, owner_conn):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    me = client.get("/me", headers=h).json()
    if not me.get("eposta_dogrulandi"):
        # Dogrulanmamis e-postada uc 422 doner (kod uretilmez) — bu
        # DOGRU davranis ve sessiz DEGIL.
        r = client.post("/me/hesap-sil/eposta-kod-iste", headers=h)
        assert r.status_code == 422, r.text
        return
    adres = me["email"]
    once = _iz(owner_conn, adres)
    r = client.post("/me/hesap-sil/eposta-kod-iste", headers=h)
    assert r.status_code in (200, 502), r.text
    assert _iz(owner_conn, adres) == once + 1


# ============ 3) KIMLIKSIZ AKISLAR — HEDEF VARSA IZ ==================== #

def test_GIRIS_KODU_hedef_VARSA_iz_birakir(client, world, owner_conn):
    """Yanit TEK BICIM kalir (sizdirmama) ama gonderim GERCEKTEN denenir."""
    adres = _dogrulanmis_kullanici(owner_conn, world["a"])
    assert _iz(owner_conn, adres) == 0
    r = client.post("/auth/giris/eposta-kod-iste", json={"eposta": adres})
    assert r.status_code == 200, r.text
    assert _iz(owner_conn, adres) == 1, "gonderim denenmedi"


def test_GIRIS_KODU_hedef_YOKSA_ayni_yanit_ve_IZ_YOK(client, owner_conn):
    """Sizdirmama KORUNUR: olmayan adres icin de 200, ama gonderim yok."""
    adres = _yeni_adres()
    r = client.post("/auth/giris/eposta-kod-iste", json={"eposta": adres})
    assert r.status_code == 200, r.text
    assert _iz(owner_conn, adres) == 0


def test_PAROLA_SIFIRLAMA_hedef_VARSA_iz_birakir(client, world, owner_conn):
    adres = _dogrulanmis_kullanici(owner_conn, world["a"])
    assert _iz(owner_conn, adres) == 0
    r = client.post("/auth/sifre/kod-iste",
                    json={"tenant_slug": world["slug_a"], "eposta": adres})
    assert r.status_code == 200, r.text
    assert _iz(owner_conn, adres) == 1, "gonderim denenmedi"


# ============ 4) DAVET E-POSTASI ======================================== #

def test_DAVET_eposta_IZ_BIRAKIR(client, world, owner_conn):
    """Kullanici eklemede davet gonderiliyorsa iz DUSMELI."""
    h = _h(client, world["slug_a"], world["yonetici_a"])
    adres = _yeni_adres()
    once = _iz(owner_conn, adres)
    r = client.post("/users", headers=h, json={
        "ad": "P212 Davetli", "email": adres, "role": "resident",
        "davet_gonder": True,
    })
    if r.status_code not in (200, 201):
        # Uc davet gondermiyorsa (bayrak/rol) test bir sey iddia etmez;
        # sessiz basarisizlik ARAMIYORUZ, GONDERIM VAADI ariyoruz.
        return
    govde = r.json()
    if govde.get("davet", {}).get("gonderildi"):
        assert _iz(owner_conn, adres) >= once + 1, "davet izi YOK"
