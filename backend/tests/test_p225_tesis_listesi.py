"""(P225) Tesis listesi: arama, kurulum suzgeci, platform admin bayragi.

===========================================================================
NEDEN ARAMA SUNUCUDA
===========================================================================
Bugun 8 tesis var; istemcide suzmek de calisirdi. Sunucu secildi cunku:

  * Suzgec verinin yaninda durursa, SAYFALAMA eklendigi gun arama
    tasinmak zorunda kalmaz. Istemcide suzen liste ilk sayfalamada
    "yalniz bu sayfada ara" haline duser — SESSIZ bir gerileme.
  * TURKCE HARF KATLAMASI TEK KURAL olmali. Dukkan aramasi ayni sorunu
    `slug` uzerinden cozmustu; `tenant.slug` da ASCII katlanmis olarak
    ZATEN duruyor (`slugify_tenant`). Istemcide ikinci bir katlama
    yazmak, iki yerde iki farkli "cekmekoy" tanimi demekti.

===========================================================================
PLATFORM ADMIN BAYRAGI NIYE LISTEDE
===========================================================================
Panel, platform admini barindiran tesiste Sil dugmesini HIC cizmiyor.
Bunu ogrenmenin alternatifi satir basina `silme-ozeti` cagirmakti:
8 tesiste 8 istek, 200 tesiste 200.
"""
from __future__ import annotations

import uuid

import pytest


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def admin(client, world):
    return _h(client, world["slug_a"], world["admin_a"])


@pytest.fixture
def turkce_tesis(client, admin):
    """Adinda Turkce harf olan tesis — ASCII katlamayi olcmek icin."""
    ek = uuid.uuid4().hex[:5]
    ad = f"Arıköy Sitesi {ek}"
    r = client.post("/tenants", headers=admin, json={
        "ad": ad,
        "yoneticiler": [{
            "ad": "Yonetici Test",
            "phone": "+9053" + str(abs(hash(ek)) % 10**7).rjust(7, "0"),
            "email": f"p225-{ek}@ornek.com",
        }],
    })
    assert r.status_code == 201, r.text
    return r.json()["tenant_id"], ad, ek


def _ara(client, admin, q: str) -> list[dict]:
    r = client.get("/tenants", headers=admin, params={"q": q})
    assert r.status_code == 200, r.text
    return r.json()["items"]


# ==================================================================== #
# 1. TURKCE HARF DUYARSIZ ARAMA
# ==================================================================== #

def test_TURKCE_HARFSIZ_YAZIM_BULUR(client, admin, turkce_tesis):
    """"arikoy" yazan kullanici "Arıköy Sitesi"ni BULUR.

    Eslesme `slug` uzerinden: slug olusturulurken ASCII'ye katlanmis
    (`arikoy-sitesi-xxxxxx`) ve sorgu AYNI kuralla katlaniyor.
    """
    tid, ad, ek = turkce_tesis
    bulunan = {x["id"] for x in _ara(client, admin, f"arikoy sitesi {ek}")}
    assert tid in bulunan, "ASCII katlama calismadi"


def test_TURKCE_HARFLI_YAZIM_DA_BULUR(client, admin, turkce_tesis):
    """Turkce klavyesi olan kullanici da bulmali — `ad ILIKE` dali."""
    tid, ad, ek = turkce_tesis
    assert tid in {x["id"] for x in _ara(client, admin, f"Arıköy Sitesi {ek}")}


def test_BUYUK_KUCUK_HARF_FARKI_ETKILEMEZ(client, admin, turkce_tesis):
    tid, ad, ek = turkce_tesis
    for yazim in (f"ARIKOY SITESI {ek}", f"arikoy sitesi {ek}".upper()):
        assert tid in {x["id"] for x in _ara(client, admin, yazim)}


def test_KAYIT_KODUYLA_DA_ARANIR(client, admin, turkce_tesis):
    """Yonetici tesisi adindan degil KODUNDAN biliyor olabilir."""
    tid, ad, ek = turkce_tesis
    kod = next(
        x["kayit_kodu"] for x in client.get("/tenants", headers=admin).json()["items"]
        if x["id"] == tid
    )
    assert kod, "kayit kodu bos"
    assert tid in {x["id"] for x in _ara(client, admin, kod)}


def test_ESLESMEYEN_SORGU_BOS_LISTE_DONER(client, admin):
    """Bos liste HATA DEGIL: panel "eslesen tesis yok" yazar."""
    assert _ara(client, admin, f"yokboyle-{uuid.uuid4().hex}") == []


def test_BOS_SORGU_SUZGEC_UYGULAMAZ(client, admin, turkce_tesis):
    """Bos/bosluklu sorgu TUM listeyi dondurur — `%%` ile her satiri
    eslemek de ayni sonucu verirdi ama niyeti gizlerdi."""
    tid, ad, ek = turkce_tesis
    hepsi = client.get("/tenants", headers=admin).json()["items"]
    bos = client.get("/tenants", headers=admin, params={"q": "   "}).json()["items"]
    assert len(bos) == len(hepsi)
    assert tid in {x["id"] for x in bos}


# ==================================================================== #
# 2. KURULUM SUZGECI
# ==================================================================== #

def test_KURULUM_SUZGECI_AYIRIR(client, admin, turkce_tesis):
    """Yeni tesis kurulum BEKLIYOR olarak acilir; suzgec ikisini ayirir."""
    tid, ad, ek = turkce_tesis
    bekleyen = client.get("/tenants", headers=admin,
                          params={"kurulum": False}).json()["items"]
    tamam = client.get("/tenants", headers=admin,
                       params={"kurulum": True}).json()["items"]
    assert all(x["kurulum_tamamlandi"] is False for x in bekleyen)
    assert all(x["kurulum_tamamlandi"] is True for x in tamam)
    # Ikisinin kesisimi BOS olmali.
    assert not ({x["id"] for x in bekleyen} & {x["id"] for x in tamam})


# ==================================================================== #
# 3. PLATFORM ADMIN BAYRAGI
# ==================================================================== #

def test_PLATFORM_ADMIN_BAYRAGI_LISTEDE_DONER(client, world, admin):
    """Panel Sil dugmesini bu bayraga gore cizmiyor."""
    me = client.get("/me", headers=admin).json()
    hepsi = client.get("/tenants", headers=admin).json()["items"]
    benim = next((x for x in hepsi if x["id"] == me["tenant_id"]), None)
    assert benim is not None, "adminin kendi tesisi listede yok"
    assert benim["platform_admini_var"] is True


def test_ADMINSIZ_TESISTE_BAYRAK_KAPALI(client, admin, turkce_tesis):
    """Koruma FAZLA GENIS olmasin: sira bir tesiste bayrak KAPALI olmali,
    yoksa panel hicbir tesiste Sil gostermezdi."""
    tid, ad, ek = turkce_tesis
    hepsi = client.get("/tenants", headers=admin).json()["items"]
    bu = next(x for x in hepsi if x["id"] == tid)
    assert bu["platform_admini_var"] is False


# ==================================================================== #
# 4. ARSIV SUZGECI ARAMAYLA BIRLIKTE CALISIR
# ==================================================================== #

def test_ARSIVLI_TESIS_ARAMADA_DA_GORUNMEZ(client, admin, turkce_tesis):
    """Arsiv gorunurlugu aramaya DA uygulanir — aksi halde arama, ayri
    bir ekranda saklanan tesisi geri getiren arka kapi olurdu."""
    tid, ad, ek = turkce_tesis
    assert client.post(f"/tenants/{tid}/arsivle", headers=admin).status_code == 200
    assert tid not in {x["id"] for x in _ara(client, admin, f"arikoy sitesi {ek}")}
    # ARSIV gorunumunde ARANABILIR olmali.
    r = client.get("/tenants", headers=admin,
                   params={"arsivli": True, "q": f"arikoy sitesi {ek}"})
    assert tid in {x["id"] for x in r.json()["items"]}
