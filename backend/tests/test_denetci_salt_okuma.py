"""(P128) DENETCI SALT-OKUR — kural yapisal olarak yazilir, ornekle degil.

IKI KATMAN, IKISI DE GEREKLI:

1. YAPISAL (`test_denetci_hicbir_mutasyon_ucunda_YOK`): uygulamanin ROTA
   AGACI gezilir; `denetci`ye acik her uc ya GET'tir ya da gerekcesi
   ASAGIDA YAZILI bir istisnadir. Ornek testi yazmak yetmezdi: yarin
   eklenen `POST /finans/bir-sey` ucuna `denetci` konursa hicbir ornek
   test dusmez. Bu test duser.

2. DAVRANISSAL (`test_okuma_200_mutasyon_403`): kural gercek istekte de
   tutuyor mu. Yalniz yapisal olcum, rotaya dogru bagimliligi koyup
   handler'in icinde baska bir sey yapan bir kodu goremezdi.

IKI YON SART: yalniz "mutasyon 403" olculseydi denetciye HIC yetki
vermemek de testi gecerdi (ve rol ise yaramazdi); o yuzden okuma uclarinin
200 dondugu de olculur.
"""
from __future__ import annotations

from datetime import date, timedelta

import pytest

#: Denetciye acik olup GET OLMAYAN uclar — her biri GEREKCELI.
#:
#: `POST /raporlar/{kod}`: rapor URETIMI bir okumadir; `rapor_motoru.py`de
#: tek bir `db.add` yoktur. POST secilmesinin sebebi rapor parametrelerinin
#: bir govde istemesidir. Kural "fiil GET olsun" degil "MUTASYON olmasin".
MUTASYON_OLMAYAN_POSTLAR: frozenset[tuple[str, str]] = frozenset({
    ("POST", "/raporlar/{kod}"),
})

#: ROL KAPISI OLMAYAN mutasyon uclari — yani `denetci` DAHIL her kimlikli
#: kullaniciya acik olanlar. Rol matrisi kilidi (7. sutun) bunlari ACIKCA
#: gosterdi ve yapisal testin ILK hâli goremiyordu: test yalnizca
#: "`denetci` izinli_roller icinde mi" diye bakiyordu, kapisi HIC OLMAYAN
#: bir uc ise o kontrolden sessizce geciyordu.
#:
#: Hepsi KENDI hesabina ya da PUBLIC akisa aittir; hicbiri tesisin
#: kayitlarina yazmaz. Salt-okuma bir rol bile kendi parolasini
#: degistirebilmeli ve KVKK rizasini yonetebilmelidir (bunlar KISININ
#: haklaridir, yetki degil).
#:
#: Yeni bir uc rol kapisi KONMADAN eklenirse bu test duser — ki bu, "rol
#: kapisini koymayi unutmak" hata sinifinin ta kendisidir.
KAPISIZ_MUTASYONLAR: frozenset[tuple[str, str]] = frozenset({
    # --- public (kimlik gerektirmeyen) ---
    ("POST", "/auth/login"),
    ("POST", "/auth/login-phone"),
    ("POST", "/auth/refresh"),
    ("POST", "/auth/set-password"),
    ("POST", "/public/{slug}/iletisim"),
    ("POST", "/webhooks/payments/{provider}"),
    # --- (P148/P149) KIMLIK ONCESI kayit ve parolasiz giris ---
    # Dordunun de rol kapisi OLAMAZ: istegi atan kisinin henuz hesabi
    # (kayit) ya da oturumu (giris) yoktur. Tesisin kayitlarina yazmazlar:
    # `kayit/*` yalniz `kayit_dogrulama` tablosuna bekleyen bir basvuru
    # yazar ve HESAP ACMAZ — hesap yonetici onayindan sonra
    # `POST /kayit-basvurulari/{id}/onayla` ile acilir ve O UC rol
    # kapilidir (admin + yonetici). `giris/*` yalniz kod uretir/dogrular.
    #
    # SIZDIRMAMA: dordu de adimlari ayirt ETTIRMEYEN tek bir yanit doner
    # (kayitli olmayan numara ile kayitli olan AYNI cevabi alir), yani
    # kapisiz olmalari bir numara/daire sorgulama araci uretmez.
    #
    # (P154) Bu dort satir bu turda YAZILMADI, KAYDA GECIRILDI: uclar
    # P148/P149'da eklenmis ama kume guncellenmemisti ve test o gunden
    # beri kirmiziydi.
    ("POST", "/auth/kayit/basla"),
    ("POST", "/auth/kayit/dogrula"),
    # (P154 / Asama 3) Rol secimli kayit. Rol kapisi OLAMAZ: kisi henuz
    # oturum acmamistir — zaten acabilseydi kaydolmasina gerek kalmazdi.
    # Tesisin kayitlarina YAZMAZ: yalniz bekleyen bir kod satiri yazar ve
    # hesap ACMAZ (hesap yonetici tarafindan onceden acilmistir).
    ("POST", "/auth/kayit/rol-basla"),
    ("POST", "/auth/kayit/rol-dogrula"),
    ("POST", "/auth/giris/kod-iste"),
    ("POST", "/auth/giris/kod-dogrula"),
    # --- KENDI hesabi (kisinin haklari) ---
    ("PATCH", "/me/contact"),
    ("PATCH", "/me/password"),
    ("PATCH", "/me/pazarlama-tercihleri"),
    ("POST", "/me/hesap-sil"),
    # (P149) Parolasiz kullanicinin silme onay kodu. `/me/hesap-sil` ile
    # AYNI hakka aittir — kisi kendi hesabini silebilmelidir — ve
    # `get_current_user` kimligi zaten zorunlu kilar; eksik olan yalniz
    # ROL kapisidir ki burada anlamsizdir: her rol kendi hesabini siler.
    ("POST", "/me/hesap-sil/kod-iste"),
    ("POST", "/kvkk/onay"),
    # --- kendi cihazinin push kaydi ---
    ("POST", "/devices"),
    ("DELETE", "/devices/{fcm_token}"),
    # --- kimligi JWT DEGIL: kamera kutusu `X-ANPR-Key` ile yazar (P16).
    # Rol kapisi YOKTUR cunku istegi bir KULLANICI degil bir CIHAZ atar;
    # anahtar tenant basinadir. Denetcinin oturumu buradan gecmez —
    # anahtarsiz istek zaten reddedilir.
    ("POST", "/integrations/anpr/events"),
    # --- (P127.2) tanitim sitesi iletisim formu: PUBLIC, kimlik YOK.
    # Rol kapisi olamaz cunku yazan kisinin hesabi yoktur. Tesisin
    # kayitlarina DOKUNMAZ: satir tenant'siz bir tabloya gider ve
    # fonksiyon hicbir satir okutmaz (bkz. test_secdef_kapsam ENVANTER).
    ("POST", "/public/tanitim-iletisim"),
})

#: Denetcinin OKUYABILDIGI uclardan ornekler (davranissal olcum).
OKUMA_UCLARI = (
    "/reports/financial-summary",
    "/finans/hareketler",
    "/finans/kasa-bakiyeleri",
    "/finans/ozet",
    "/dues/assessments",
    "/dues/payments",
    "/budget/summary",
    "/budget/entries",
    "/budget/categories",
    "/kasalar",
    "/gelir-gider-tanimlari",
    "/raporlar/katalog",
)

#: Denetcinin ASLA yapamayacagi mutasyonlardan ornekler (govde gecerli
#: olmasa bile 403 ONCE gelir — yetki kapisi dogrulamadan oncedir).
MUTASYON_UCLARI = (
    ("post", "/finans/hareketler"),
    ("post", "/finans/tahsilat"),
    ("post", "/dues/assessments"),
    ("post", "/budget/entries"),
    ("post", "/kasalar"),
    ("post", "/announcements"),
    ("post", "/users"),
    ("post", "/residents"),
    ("post", "/tasks"),
)


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


# --------------------------- 1) yapisal olcum ------------------------------ #
def test_denetci_hicbir_mutasyon_ucunda_YOK():
    from fastapi.routing import APIRoute

    from app.main import app
    from app.routers.yetki_matrisi import _rol_kumesi

    ihlal: list[str] = []
    for route in app.routes:
        if not isinstance(route, APIRoute):
            continue
        roller, _mod = _rol_kumesi(route.dependant)
        if roller is None or "denetci" not in roller:
            continue
        for metot in route.methods:
            if metot in ("GET", "HEAD", "OPTIONS"):
                continue
            if (metot, route.path) in MUTASYON_OLMAYAN_POSTLAR:
                continue
            ihlal.append(f"{metot} {route.path}")
    assert not ihlal, (
        "denetci SALT-OKUR olmali; su uclarda yazma yetkisi var: " + ", ".join(ihlal)
    )


def test_ROL_KAPISI_OLMAYAN_mutasyon_uclari_BEKLENEN_KUME():
    """Kapisiz mutasyon uclari BEKLENEN kumeyle birebir ayni.

    Bu, denetci testinin ilk hâlindeki delikti: rol kapisi HIC olmayan bir
    uc `denetci`ye de aciktir ama "izinli_roller icinde denetci var mi"
    kontrolunden gecmez. Kume iki yonlu kilitlenir — yeni bir kapisiz uc
    eklenirse de, listedeki bir uc kaldirilirsa da test duser.
    """
    from fastapi.routing import APIRoute

    from app.main import app
    from app.routers.yetki_matrisi import _rol_kumesi

    olculen = set()
    for route in app.routes:
        if not isinstance(route, APIRoute):
            continue
        roller, _mod = _rol_kumesi(route.dependant)
        if roller is not None:
            continue
        for metot in route.methods:
            if metot in ("GET", "HEAD", "OPTIONS"):
                continue
            olculen.add((metot, route.path))
    assert olculen == set(KAPISIZ_MUTASYONLAR), (
        f"fazladan: {sorted(olculen - set(KAPISIZ_MUTASYONLAR))} · "
        f"eksik: {sorted(set(KAPISIZ_MUTASYONLAR) - olculen)}"
    )


def test_istisna_listesi_GERCEK_uclari_gosteriyor():
    """Istisna listesi olu satir tasimaz — kaldirilan bir uc listede kalirsa
    kural sessizce genis kalirdi."""
    from fastapi.routing import APIRoute

    from app.main import app

    mevcut = {
        (m, r.path)
        for r in app.routes
        if isinstance(r, APIRoute)
        for m in r.methods
    }
    assert MUTASYON_OLMAYAN_POSTLAR <= mevcut


# -------------------------- 2) davranissal olcum --------------------------- #
@pytest.mark.parametrize("yol", OKUMA_UCLARI)
def test_denetci_OKUR(client, world, yol):
    h = _headers(client, world["slug_a"], world["denetci_a"])
    r = client.get(yol, headers=h)
    assert r.status_code == 200, f"{yol}: {r.status_code} {r.text}"


@pytest.mark.parametrize("metot,yol", MUTASYON_UCLARI)
def test_denetci_YAZAMAZ(client, world, metot, yol):
    h = _headers(client, world["slug_a"], world["denetci_a"])
    r = client.request(metot.upper(), yol, headers=h, json={})
    assert r.status_code == 403, f"{metot} {yol}: {r.status_code} {r.text}"


def test_ayni_uclarda_YONETICI_yazabiliyor(client, world):
    """Kontrol grubu: 403'ler 'denetci oldugu icin' mi, yoksa uc zaten
    herkese kapali mi? Yonetici ayni uclarda yetki kapisini GECER
    (govde bos oldugu icin 422 alir — ama 403 ALMAZ)."""
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    for metot, yol in (("post", "/announcements"), ("post", "/budget/entries")):
        r = client.request(metot.upper(), yol, headers=h, json={})
        assert r.status_code != 403, f"{metot} {yol} yoneticiye de kapali: {r.text}"


# ------------------------------ gorev penceresi ---------------------------- #
def _denetci_ac(client, world, **pencere):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    import uuid as _uuid

    tel = "+90" + str(_uuid.uuid4().int)[:10]
    r = client.post(
        "/users",
        headers=yonetici,
        json={
            "ad": "Gorevli Denetci",
            "telefon": tel,
            "role": "denetci",
            "password": "GecerliParola1!",
            **pencere,
        },
    )
    return r, tel


def test_yonetici_denetci_ACAR(client, world):
    r, _tel = _denetci_ac(client, world)
    assert r.status_code == 201, r.text
    assert r.json()["role"] == "denetci"


def test_gorev_suresi_dolmus_denetci_GIREMEZ(client, world):
    dun = date.today() - timedelta(days=1)
    onceki = dun - timedelta(days=30)
    r, tel = _denetci_ac(
        client, world,
        gorev_baslangic=onceki.isoformat(), gorev_bitis=dun.isoformat(),
    )
    assert r.status_code == 201, r.text
    giris = client.post(
        "/auth/login-phone", json={"phone": tel, "password": "GecerliParola1!"}
    )
    assert giris.status_code == 403, giris.text
    assert giris.json()["error"]["code"] == "forbidden"


def test_gorevi_BASLAMAMIS_denetci_GIREMEZ(client, world):
    yarin = date.today() + timedelta(days=1)
    r, tel = _denetci_ac(client, world, gorev_baslangic=yarin.isoformat())
    assert r.status_code == 201, r.text
    giris = client.post(
        "/auth/login-phone", json={"phone": tel, "password": "GecerliParola1!"}
    )
    assert giris.status_code == 403, giris.text


def test_gorevi_SUREN_denetci_GIRER(client, world):
    """Kontrol grubu: pencere kapiyi HERKESE kapatmiyor."""
    dun = date.today() - timedelta(days=1)
    yarin = date.today() + timedelta(days=1)
    r, tel = _denetci_ac(
        client, world,
        gorev_baslangic=dun.isoformat(), gorev_bitis=yarin.isoformat(),
    )
    assert r.status_code == 201, r.text
    giris = client.post(
        "/auth/login-phone", json={"phone": tel, "password": "GecerliParola1!"}
    )
    assert giris.status_code == 200, giris.text


def test_ters_pencere_REDDEDILIR(client, world):
    dun = (date.today() - timedelta(days=1)).isoformat()
    bugun = date.today().isoformat()
    r, _tel = _denetci_ac(client, world, gorev_baslangic=bugun, gorev_bitis=dun)
    assert r.status_code == 422, r.text


def test_gorev_bitisi_bugune_cekilince_ERISIM_KESILIR(client, world):
    """(P128) IPTAL YOLU: yonetici bitis tarihini gecmise ceker; ACIK oturum
    da kapanir — pencere HER istekte olculur, yalniz giriste degil."""
    yarin = (date.today() + timedelta(days=1)).isoformat()
    r, tel = _denetci_ac(client, world, gorev_bitis=yarin)
    assert r.status_code == 201, r.text
    uid = r.json()["id"]

    giris = client.post(
        "/auth/login-phone", json={"phone": tel, "password": "GecerliParola1!"}
    )
    assert giris.status_code == 200, giris.text
    h = {"Authorization": f"Bearer {giris.json()['access_token']}"}
    assert client.get("/finans/ozet", headers=h).status_code == 200

    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    dun = (date.today() - timedelta(days=1)).isoformat()
    p = client.patch(f"/users/{uid}", headers=yonetici, json={"gorev_bitis": dun})
    assert p.status_code == 200, p.text

    # AYNI token ile: oturum artik gecmiyor.
    assert client.get("/finans/ozet", headers=h).status_code == 403
