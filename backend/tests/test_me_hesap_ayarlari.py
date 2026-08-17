"""(P167 §1.7) "Guvenlik ve giris" + "Bildirim ayarlari" + self-servis ad.

NE OLCULUYOR ve NEDEN — dordu de sessizce yanlis olabilecek cinsten:

 1. YETKI SINIRI. `/me/cihazlar` ve `/me/etkinlik` HER ROLE aciktir ama
    YALNIZ kisinin KENDI satirlarini dondurmelidir. Suzgec sunucudaki
    sorgunun icinde; bir gun `where` dusseydi uc "calisir" gorunmeye
    devam ederdi ve sizinti kimsenin sikayet etmeyecegi cinsten olurdu.
 2. CIHAZ SILINMEZ, PASIFLESIR. Satir silinseydi ayni telefon yeniden
    giris yaptiginda yeni bir kayit acilir ve gecmis her seferinde
    sifirlanirdi.
 3. BILDIRIM TERCIHI PAZARLAMA RIZASI DEGILDIR. Ikisi ayri kolonlar;
    birini degistirmek otekini KIMILDATMAMALI. Tek bayrakta birlestirmek,
    pazarlamayi kapatan kullanicinin aidat bildirimini de kaybetmesi
    (ya da tersi, KVKK ihlali) demekti.
 4. AD SELF-SERVIS, E-POSTA DEGIL. `PATCH /me/contact` `ad` alir; `email`
    almaz ve almamalidir (login anahtari, dogrulama akisi yok).
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


def _cihaz_kaydet(client, headers, token: str, platform: str = "android"):
    r = client.post(
        "/devices",
        headers=headers,
        json={"fcm_token": token, "platform": platform},
    )
    assert r.status_code == 201, r.text
    return r.json()


# --------------------------------------------------------------------------- #
# 1. CIHAZLAR
# --------------------------------------------------------------------------- #
def test_kendi_cihazlarimi_gorurum_baskasininkini_gormem(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    sakin = _headers(client, world["slug_a"], world["resident_a"])

    y_token = f"tok-y-{uuid.uuid4().hex}"
    s_token = f"tok-s-{uuid.uuid4().hex}"
    _cihaz_kaydet(client, yonetici, y_token)
    _cihaz_kaydet(client, sakin, s_token, platform="ios")

    r = client.get("/me/cihazlar", headers=yonetici)
    assert r.status_code == 200, r.text
    platformlar = [c["platform"] for c in r.json()]
    assert "android" in platformlar
    # Sakinin `ios` cihazi AYNI tenant'ta ama BASKA kullanicida — listede
    # gorunmesi, ucun "kendi" sozunu tutmadigi anlamina gelirdi.
    assert "ios" not in platformlar


def test_cihaz_yanitinda_FCM_TOKEN_YOK(client, world):
    # Token push ADRESIDIR: disari verilmesi, o kullaniciya bildirim
    # gondermenin anahtarini vermek olurdu.
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    _cihaz_kaydet(client, sakin, f"tok-{uuid.uuid4().hex}")
    r = client.get("/me/cihazlar", headers=sakin)
    assert r.status_code == 200
    assert r.json(), "cihaz listesi bos — olcum bosa gecti"
    for c in r.json():
        assert "fcm_token" not in c


def test_cihaz_kaldirilinca_SILINMEZ_pasiflesir(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    cihaz = _cihaz_kaydet(client, yonetici, f"tok-{uuid.uuid4().hex}")
    # `/devices` yaniti id tasiyor; listeden de bulunabilir.
    hedef = next(
        c for c in client.get("/me/cihazlar", headers=yonetici).json()
        if c["id"] == cihaz["id"]
    )
    assert hedef["aktif"] is True

    r = client.delete(f"/me/cihazlar/{cihaz['id']}", headers=yonetici)
    assert r.status_code == 204, r.text

    sonra = client.get("/me/cihazlar", headers=yonetici).json()
    kalan = [c for c in sonra if c["id"] == cihaz["id"]]
    assert kalan, "satir SILINMIS — gecmis her giriste sifirlanir"
    assert kalan[0]["aktif"] is False


def test_baskasinin_cihazi_kaldirilamaz(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    cihaz = _cihaz_kaydet(client, sakin, f"tok-{uuid.uuid4().hex}")

    # Yonetici, TENANT'in yoneticisidir — ama bu uc "kendi" ucudur.
    r = client.delete(f"/me/cihazlar/{cihaz['id']}", headers=yonetici)
    assert r.status_code == 404, r.text
    # Sakinin cihazi HALA aktif.
    kendi = client.get("/me/cihazlar", headers=sakin).json()
    assert any(c["id"] == cihaz["id"] and c["aktif"] for c in kendi)


def test_tumunden_cik_yalniz_kendi_cihazlarini_kapatir(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    _cihaz_kaydet(client, yonetici, f"tok-{uuid.uuid4().hex}")
    _cihaz_kaydet(client, yonetici, f"tok-{uuid.uuid4().hex}", platform="web")
    sakin_cihaz = _cihaz_kaydet(client, sakin, f"tok-{uuid.uuid4().hex}")

    r = client.post("/me/cihazlar/tumunden-cik", headers=yonetici)
    assert r.status_code == 200, r.text
    assert r.json()["kaldirilan"] >= 2

    assert all(not c["aktif"] for c in client.get("/me/cihazlar", headers=yonetici).json())
    # Sakinin cihazi DOKUNULMAMIS.
    assert any(
        c["id"] == sakin_cihaz["id"] and c["aktif"]
        for c in client.get("/me/cihazlar", headers=sakin).json()
    )


# --------------------------------------------------------------------------- #
# 2. HESAP ETKINLIGI
# --------------------------------------------------------------------------- #
def test_etkinlik_yalniz_kendi_satirlarim(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    sakin = _headers(client, world["slug_a"], world["resident_a"])

    # Denetime yazan bir islem uret (bildirim tercihi degisimi).
    assert client.patch(
        "/me/bildirim-tercihleri", headers=sakin, json={"bildirim_sms": False}
    ).status_code == 200

    # Kendi listesinde VAR (olcum bosa gecmesin).
    kendi = client.get("/me/etkinlik", headers=sakin).json()
    assert any(s["action"] == "notification_prefs_update" for s in kendi)

    # Yoneticinin listesinde YOK. `world` her test icin YENI kullanicilar
    # aciyor; yonetici bu testte hicbir bildirim tercihi degistirmedi,
    # dolayisiyla tek bir satir bile gorunuyorsa suzgec baskasinin
    # kaydini siziyor demektir.
    r = client.get("/me/etkinlik", headers=yonetici)
    assert r.status_code == 200, r.text
    assert not [s for s in r.json() if s["action"] == "notification_prefs_update"]


def test_etkinlik_limiti_uygulanir_ve_tavani_var(client, world):
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    for i in range(3):
        client.patch(
            "/me/bildirim-tercihleri",
            headers=sakin,
            json={"bildirim_sms": bool(i % 2)},
        )
    assert len(client.get("/me/etkinlik?limit=2", headers=sakin).json()) <= 2
    # Sinirsiz `limit`, tek istekle tabloyu suzduren bir yol acardi.
    assert len(client.get("/me/etkinlik?limit=9999", headers=sakin).json()) <= 100


def test_etkinlik_her_role_acik(client, world):
    # Kendi hesabinda ne olup bittigini gormek bir YONETIM yetkisi degil.
    for kim in ("guard_a", "gorevli_a", "resident_a", "denetci_a"):
        h = _headers(client, world["slug_a"], world[kim])
        assert client.get("/me/etkinlik", headers=h).status_code == 200, kim


# --------------------------------------------------------------------------- #
# 3. BILDIRIM TERCIHLERI
# --------------------------------------------------------------------------- #
def test_bildirim_varsayilani_ACIK(client, world):
    # Pazarlama rizasinin TERSI: isleyis bildirimi riza gerektirmez ve
    # kapali baslarsa kullanici aidat/gorev bildirimini HIC almaz.
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    r = client.get("/me/bildirim-tercihleri", headers=sakin)
    assert r.status_code == 200, r.text
    assert r.json() == {
        "bildirim_eposta": True,
        "bildirim_sms": True,
        "bildirim_mobil": True,
    }


def test_bildirim_KISMI_guncelleme_otekileri_kimildatmaz(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.patch(
        "/me/bildirim-tercihleri", headers=yonetici, json={"bildirim_sms": False}
    )
    assert r.status_code == 200, r.text
    assert r.json() == {
        "bildirim_eposta": True,
        "bildirim_sms": False,
        "bildirim_mobil": True,
    }


def test_bildirim_tercihi_PAZARLAMA_RIZASINI_degistirmez(client, world):
    # Ikisi ayri kavram: biri KVKK rizasi (varsayilani kapali), oteki
    # kullanim tercihi (varsayilani acik). Tek kolonda birlesselerdi bu
    # test iki yonde birden kirmizi olurdu.
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    # NOT: pazarlama ucunun alan adlari ONEKSIZ (`eposta`) — bildirim ucu
    # ise `bildirim_` onekli. Iki ayri kavram, iki ayri sozlesme; ayni
    # govdeyi ikisine de gonderemezsiniz (`extra=forbid`).
    assert client.patch(
        "/me/pazarlama-tercihleri", headers=sakin, json={"eposta": True}
    ).status_code == 200

    client.patch(
        "/me/bildirim-tercihleri", headers=sakin, json={"bildirim_eposta": False}
    )

    pazarlama = client.get("/me/pazarlama-tercihleri", headers=sakin).json()
    assert pazarlama["eposta"] is True
    assert client.get("/me/bildirim-tercihleri", headers=sakin).json()[
        "bildirim_eposta"
    ] is False


# --------------------------------------------------------------------------- #
# 4. SELF-SERVIS AD + AVATAR URL
# --------------------------------------------------------------------------- #
def test_ad_self_servis_degisir(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.patch("/me/contact", headers=yonetici, json={"ad": "Yeni Ad"})
    assert r.status_code == 200, r.text
    assert r.json()["ad"] == "Yeni Ad"
    assert client.get("/me/profile", headers=yonetici).json()["ad"] == "Yeni Ad"


def test_BOS_ad_reddedilir(client, world):
    # `app_user.ad` NOT NULL ve her ekranda kisinin tek tanimi; bos ad
    # listelerde adsiz satirlar uretirdi. Telefondaki "bos = kaldir"
    # kurali burada GECERLI DEGIL.
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    assert client.patch(
        "/me/contact", headers=yonetici, json={"ad": "   "}
    ).status_code == 422


def test_EPOSTA_self_servis_DEGISMEZ(client, world):
    # E-posta login anahtaridir ve dogrulama akisi yoktur. Govdeye
    # konulan alan SESSIZCE yok sayilmali (Pydantic ekstra alani atar) —
    # asla yazilmamali.
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    once = client.get("/me/profile", headers=sakin).json()["email"]
    r = client.patch(
        "/me/contact", headers=sakin, json={"email": "yeni@ornek.com", "aranabilir": True}
    )
    assert r.status_code == 200, r.text
    assert r.json()["email"] == once


def test_profil_yanitinda_avatar_url_alani_var(client, world):
    # Sag ust kullanici menusu ile profil sayfasi AYNI kaydin iki
    # gorunumu; avatari ayri bir uctan cekmek iki onbellek demekti.
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    govde = client.get("/me/profile", headers=sakin).json()
    assert "avatar_url" in govde
