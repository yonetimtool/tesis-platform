"""(P197) E-POSTASIZ HESAP OLUSAMAZ — HICBIR YOLDAN.

===========================================================================
NEDEN
===========================================================================
E-posta bu urunde ILETISIM ALANI degil, KIMLIGIN TASIYICISIDIR: davet,
dogrulama kodu ve parola sifirlama YALNIZ oradan gider (SMS urun genelinde
kapali). E-postasiz acilan bir hesap:
  * daveti alamaz -> Tesis ID'yi ogrenemez -> HIC giremez,
  * parolasini sifirlayamaz,
  * hesabini silemez (P196'da olculdu).

Yani "e-postasiz kullanici" bir kullanim bicimi degil, SESSIZ BIR
CIKMAZDIR. Kural parca parca uygulanmisti (P186 tekil ekleme, P193 Excel);
veritabani hala izin veriyordu ve SECURITY DEFINER fonksiyonlar bu izni
FIILEN KULLANIYORDU (dev'de 952 e-postasiz yonetici satiri birikmisti).

Bu dosya kuralin HER KAPIDA durdugunu olcer. Yeni bir kullanici yaratma
yolu eklenirse ve e-postayi zorunlu tutmazsa, buradaki bir test duser.
"""
from __future__ import annotations

import uuid

import pytest


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _tel() -> str:
    return f"+9053{uuid.uuid4().int % 100000000:08d}"


def _mail() -> str:
    return f"p197-{uuid.uuid4().hex[:12]}@ornek.com"


# ==================== 1) VERITABANI SEVIYESI ==================== #

def test_SUTUN_NOT_NULL_ve_BOS_DIZGE_de_YASAK(owner_conn):
    """Kural once VERITABANINDA durur.

    Uygulama katmanindaki dogrulamalar atlanabilir (SECURITY DEFINER
    fonksiyon, elle SQL, ileride yazilacak bir betik). NOT NULL
    atlanamaz.

    BOS DIZGE de olculuyor: `NOT NULL` tek basina `''`e izin verir ve o,
    "adres var" gorunen bir adressizliktir.
    """
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT is_nullable FROM information_schema.columns "
            "WHERE table_name='app_user' AND column_name='email'"
        )
        assert cur.fetchone()[0] == "NO", "app_user.email NOT NULL olmali"
        cur.execute(
            "SELECT count(*) FROM pg_constraint "
            "WHERE conrelid='app_user'::regclass "
            "AND conname='ck_app_user_email_bos_degil'"
        )
        assert cur.fetchone()[0] == 1, "bos dizge kisiti YOK"


def test_VERITABANINDA_epostasiz_satir_KALMADI(owner_conn):
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM app_user WHERE email IS NULL OR btrim(email) = ''"
        )
        assert cur.fetchone()[0] == 0


def test_SECURITY_DEFINER_fonksiyonlar_EPOSTA_YAZIYOR(owner_conn):
    """(P197) ASIL SIZINTI BURADAYDI.

    `create_tenant_with_yoneticis` ve `add_tenant_yonetici` SECURITY
    DEFINER'dir: uygulama katmanindaki HER dogrulamayi atlarlar. Ikisi de
    `app_user`a e-postasiz yaziyordu — dev'deki 952 satirin kaynagi buydu.

    ESKI IMZA DA OLCULUYOR: dort parametreli `add_tenant_yonetici`
    dururken yeni imzayi eklemek yetmezdi; eski cagri cozulmeye devam
    eder ve deligi acik birakirdi.
    """
    with owner_conn.cursor() as cur:
        for fn in ("create_tenant_with_yoneticis", "add_tenant_yonetici"):
            cur.execute(
                "SELECT prosrc FROM pg_proc WHERE proname = %s", (fn,)
            )
            satirlar = cur.fetchall()
            assert satirlar, f"{fn} yok"
            for (kaynak,) in satirlar:
                assert "email" in kaynak, f"{fn} app_user.email YAZMIYOR"

        cur.execute(
            "SELECT count(*) FROM pg_proc "
            "WHERE proname = 'add_tenant_yonetici' "
            "AND pg_get_function_identity_arguments(oid) = "
            "'uuid, text, text, text'"
        )
        assert cur.fetchone()[0] == 0, (
            "ESKI (e-postasiz) imza hala cozulebiliyor — delik acik"
        )


# ==================== 2) API UCLARI ==================== #

def test_POST_users_epostasiz_REDDEDER(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post("/users", headers=admin, json={
        "ad": "Epostasiz", "telefon": _tel(), "role": "security",
    })
    assert r.status_code == 422, r.text


def test_POST_residents_epostasiz_REDDEDER(client, world):
    """Sakin ekleme YOLU DA kapali.

    Bu uc P197'ye kadar e-postayi OPSIYONEL tutuyordu ("sakinde
    opsiyonel"). Sonucu: davet gonderilemeyen, hicbir zaman giris
    yapamayacak sakin kayitlari.
    """
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/residents", headers=yon, json={
        "ad": "Epostasiz Sakin", "unit_no": f"P197-{uuid.uuid4().hex[:5]}",
        "telefon": _tel(),
    })
    assert r.status_code == 422, r.text


def test_PATCH_residents_epostayi_TEMIZLEYEMEZ(client, world, owner_conn):
    """Acikca `null` gondermek adresi BOSALTIYORDU — artik dokunmuyor."""
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    eposta = _mail()
    r = client.post("/residents", headers=yon, json={
        "ad": "P197 Sakin", "unit_no": f"P197-{uuid.uuid4().hex[:5]}",
        "telefon": _tel(), "email": eposta,
    })
    assert r.status_code == 201, r.text
    uid = r.json()["user_id"]

    assert client.patch(f"/residents/{uid}", headers=yon,
                        json={"email": None}).status_code == 204
    with owner_conn.cursor() as cur:
        cur.execute("SELECT email FROM app_user WHERE id = %s", (uid,))
        assert cur.fetchone()[0] == eposta, "e-posta SILINMEMELI"


def test_POST_tenants_epostasiz_yonetici_REDDEDER(client, world):
    """Tesis acmanin kendisi de e-postasiz yonetici uretemez.

    Dev veritabanindaki 952 e-postasiz satirin kaynagi TAM OLARAK bu
    yoldu (test fixture'lari her kosumda tesis aciyordu).
    """
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post("/tenants", headers=admin, json={
        "yoneticiler": [{"ad": "Epostasiz Yonetici", "phone": _tel()}],
    })
    assert r.status_code == 422, r.text


def test_POST_tenant_yoneticiler_epostasiz_REDDEDER(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    olusan = client.post("/tenants", headers=admin, json={
        "ad": f"P197 Tesis {uuid.uuid4().hex[:6]}",
        "yoneticiler": [{"ad": "Ilk", "phone": _tel(), "email": _mail()}],
    })
    assert olusan.status_code == 201, olusan.text
    tid = olusan.json()["tenant_id"]

    r = client.post(f"/tenants/{tid}/yoneticiler", headers=admin, json={
        "ad": "Ikinci", "phone": _tel(),
    })
    assert r.status_code == 422, r.text


def test_ICE_AKTARIM_epostasiz_satir_REDDEDER(client, world):
    """(P193'te kapatilmisti) Excel yolu da e-posta ZORUNLU tutuyor."""
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/ice-aktarim/kisi", headers=yon, json={
        "yalniz_dogrula": True,
        "satirlar": [{"satir_no": 2, "degerler": {
            "ad": "Epostasiz", "telefon": _tel()}}],
    })
    assert r.status_code == 201, r.text
    govde = r.json()
    assert govde["hatali"] == 1, govde
    assert govde["hatalar"][0]["alan"] == "eposta"


# ==================== 3) ANONIMLESTIRME ==================== #

def test_ANONIMLESTIRME_epostayi_NULL_YAPMAZ(client, world, owner_conn):
    """KVKK anonimlestirmesi NOT NULL'i ihlal ETMEMELI.

    Ilk yazimda ediyordu: `hedef.email = None` ve hesap silme 500
    donuyordu (olculdu). Cozum, adresin SILINMESI degil KISISEL VERI
    TASIMAMASIDIR: `.invalid` TLD'si (RFC 2606) DNS'te asla cozulmez.
    """
    from app.hesap_silme import ANONYMIZED_NAME  # noqa: F401 — varlik kontrolu

    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/residents", headers=yon, json={
        "ad": "P197 Anonim", "unit_no": f"P197A-{uuid.uuid4().hex[:5]}",
        "telefon": _tel(), "email": _mail(),
    })
    assert r.status_code == 201, r.text
    uid = r.json()["user_id"]

    # Yonetim silmesi: gecmis yoksa sert siler, varsa anonimlestirir.
    silme = client.delete(f"/users/{uid}", headers=yon)
    assert silme.status_code == 200, silme.text
    with owner_conn.cursor() as cur:
        cur.execute("SELECT email FROM app_user WHERE id = %s", (uid,))
        satir = cur.fetchone()
    if satir is not None:  # anonimlestirildi (sert silinmediyse)
        assert satir[0] is not None, "anonimlestirme email'i NULL yapmamali"
        assert satir[0].endswith("@yonetiyor.invalid"), satir[0]
