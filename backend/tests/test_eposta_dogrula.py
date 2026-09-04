"""(P181 Bölüm 1) Mevcut kullanicinin e-posta ekleme/dogrulama uclari.

client -> CALISAN API (ayri surec): kod HASH'li saklandigi icin tam dogrulama
akisi (kod okuma) burada test edilmez — kod uretimi/dogrulamasi mevcut
`eposta_kodu_uret_ve_gonder`/`eposta_kodunu_dogrula` yardimcilariyla (kayit
akislarinda) zaten test kapsaminda. Burada UCUN kapisi test edilir: auth,
dogrulama, cakisma ve /me bayragi.
"""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_me_eposta_dogrulandi_alani_var(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.get("/me", headers=admin)
    assert r.status_code == 200, r.text
    # (P181) Alan HER kullanicida bulunur (bool).
    assert "eposta_dogrulandi" in r.json()
    assert isinstance(r.json()["eposta_dogrulandi"], bool)


def test_eposta_kod_iste_AUTH_ister(client):
    r = client.post("/me/eposta/kod-iste", json={"eposta": "x@ornek.test"})
    assert r.status_code == 401


def test_eposta_kod_iste_GECERSIZ_adres_422(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post("/me/eposta/kod-iste", headers=admin, json={"eposta": "gecersiz"})
    assert r.status_code == 422


def test_eposta_kod_iste_TAZE_adres_gonderir(client, world, konsol_eposta):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    taze = f"p181-{uuid.uuid4().hex[:10]}@ornek.test"
    r = client.post("/me/eposta/kod-iste", headers=admin, json={"eposta": taze})
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "gonderildi"


def test_eposta_kod_iste_BASKASININ_adresi_409_ve_KOD_YAZILMAZ(
    client, world, owner_conn
):
    """(P212-ek §1) Adres BAŞKA kullanıcıdaysa AÇIK 409 döner.

    ===================================================================
    KARAR DEĞİŞTİ — VE NEDENİ
    ===================================================================
    P184-ek §9 burada 409'u kaldırıp tek biçimli `gonderildi` yanıtına
    geçmişti (gerekçe: 409 bir "bu adres kimde" sorgusudur). Prod'da
    ölçülen sonuç şuydu: kullanıcı profilden e-postasını değiştiriyor,
    ekran "doğrulama bekliyor" diyor, `mesaj_gonderim` tablosunda O
    ADRESE AİT HİÇBİR KAYIT OLUŞMUYOR ve kullanıcı NEDENİNİ
    ÖĞRENEMİYOR. Bilgi sızdırmayan ama KULLANILAMAZ bir akış.

    Bu uç KİMLİK DOĞRULANMIŞ ve tenant'a kapalıdır; soran kişi zaten o
    tesisin üyesi (sakin/personel listeleri ona görünüyor).
    `auth.py`deki KİMLİKSİZ uçlar (giriş kodu, parola sıfırlama) tek
    biçimli yanıtlarını KORUYOR — orada sızdırmama hâlâ zorunlu.

    KORUNAN YARI: başkasının adresine KOD YAZILMAZ. İsteyen,
    doğrulanabilir bir kod elde edemez.
    """
    guard = _headers(client, world["slug_a"], world["guard_a"])
    admin_eposta = world["admin_a"]["email"]
    r = client.post("/me/eposta/kod-iste", headers=guard, json={"eposta": admin_eposta})
    assert r.status_code == 409, r.text
    assert r.json()["error"]["code"] == "conflict"
    # KİM OLDUĞU SIZMAZ: mesaj kullanıcıyı adlandırmaz.
    assert "admin" not in r.json()["error"]["message"].lower()
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM kayit_dogrulama WHERE eposta = %s "
            "AND amac = 'eposta_ekle' AND durum = 'telefon_bekliyor'",
            (admin_eposta,),
        )
        assert cur.fetchone()[0] == 0, "başkasının adresine kod YAZILMAMALI"



def test_dogrulanmis_epostayi_DEGISTIR_gonderildi_doner(client, world, owner_conn, konsol_eposta):
    """(P184-ek §9) Doğrulanmış e-postası olan kullanıcı YENİ adres isteyince
    akış çalışır (eski adrese bildirim gider; yanıt generic `gonderildi`)."""
    from app.security import hash_password

    guard = _headers(client, world["slug_a"], world["guard_a"])
    ilk = f"p184a-{uuid.uuid4().hex[:8]}@ornek.test"
    assert (
        client.post("/me/eposta/kod-iste", headers=guard, json={"eposta": ilk})
        .status_code
        == 200
    )
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE kayit_dogrulama SET kod_hash = %s WHERE eposta = %s "
            "AND amac = 'eposta_ekle' AND durum = 'telefon_bekliyor'",
            (hash_password("123456"), ilk),
        )
    owner_conn.commit()
    assert (
        client.post(
            "/me/eposta/dogrula", headers=guard, json={"eposta": ilk, "kod": "123456"}
        ).status_code
        == 200
    )
    # DEĞİŞTİR: yeni adres iste -> eski (doğrulanmış) adrese bildirim branch'i
    # çalışır; yanıt generic `gonderildi`.
    yeni = f"p184b-{uuid.uuid4().hex[:8]}@ornek.test"
    r = client.post("/me/eposta/kod-iste", headers=guard, json={"eposta": yeni})
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "gonderildi"


def test_eposta_dogrula_KOD_OKUR_ve_bayragi_ACAR(client, world, owner_conn, konsol_eposta):
    """(P181) DOGRULAMA (kod okuma) yolu — 'eposta_ekle' ENUM'u ORM'de TANIMLI
    olmali. Değilse okuma 500 verir (kod_amaci model listesi eksikti — bu test o
    boşluğu kapatır). guard'ın login e-postası SHARED değil kendine ait olmalı;
    guard için TAZE bir adres doğrulatıp `eposta_dogrulandi=true` bekliyoruz.
    """
    guard = _headers(client, world["slug_a"], world["guard_a"])
    taze = f"p181d-{uuid.uuid4().hex[:10]}@ornek.test"
    r = client.post("/me/eposta/kod-iste", headers=guard, json={"eposta": taze})
    assert r.status_code == 200, r.text

    # Kod HASH'li saklanir; bilinen bir kodla degistir (test_eposta_kanali deseni).
    from app.security import hash_password

    owner_conn.execute(
        "UPDATE kayit_dogrulama SET kod_hash = %s WHERE tenant_id = %s "
        "AND eposta = %s AND amac = 'eposta_ekle' AND durum = 'telefon_bekliyor'",
        (hash_password("123456"), world["a"], taze),
    )
    owner_conn.commit()

    r = client.post(
        "/me/eposta/dogrula", headers=guard, json={"eposta": taze, "kod": "123456"}
    )
    assert r.status_code == 200, r.text          # 500 DEGIL (enum okuma)
    assert r.json()["email"] == taze
    assert r.json()["eposta_dogrulandi"] is True
