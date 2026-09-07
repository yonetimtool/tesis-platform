"""(DUKKAN F2) IDOR — bir isletme sahibi BASKASININ isletmesine ULASAMAZ.

===========================================================================
BU DOSYA NEDEN VAR
===========================================================================
Dukkan cok-kiracili DEGIL ve RLS YOK (docs/dukkan/00-mimari.md K4).
Izolasyon sinirI `isletme.sahip_kullanici_id` ve TEK bir yardimcidan
gecer (`_sahiplik_dogrula`). RLS'in "son savunma hatti" konforu burada
YOK — dolayisiyla kilit TESTTE olmak zorunda.

Bu, tasarimda alinan bilincli riskin karsiligi: RLS yerine acik kontrol
sectik, cunku Dukkan verisinin cogu tasarim geregi HERKESE ACIK (isletme
profilleri, yorumlar) ve ozel yuzey DAR. Dar ve sayilabilir bir yuzeyde
acik kontrol daha okunur — AMA ancak her uc icin bir test varsa.

===========================================================================
IKI KATMANLI OLCUM
===========================================================================
1. DAVRANIS: her ozel uc, BASKA bir isletmenin sahibiyle cagrilinca 403.
2. TARAMA:  yeni bir `/isletme/{id}/...` ucu eklenip buraya yazilmazsa
   `test_HER_ISLETME_UCUNUN_IDOR_TESTI_VAR` DUSER.

Ikinci katman olmadan birincisi zamanla eskir: kimse yeni ucun testini
yazmayi hatirlamak zorunda kalmamali.
"""
from __future__ import annotations

import uuid

import pytest


def _kullanici(client, telefon_son: int) -> dict:
    """Telefon OTP akisini GERCEKTEN surerek bir Dukkan kullanicisi acar.

    Repo katmanini taklit ETMIYORUZ: P198/P200'de ayni dikisten kirildik.
    Kod, uctan gelen `dev_kod` ile okunuyor (dev'de acik bir ayar).
    """
    # SIFIR DOLGUSU SART: `uuid.int % 10**8` kisa sayi uretebilir ve
    # `telefon_normalize` bunu (hakli olarak) 422 ile reddeder — ilk
    # yazimda tam bu yuzden 6 test hata verdi. Kusur URUNDE degil
    # TESTTEYDI; normalize'in bozuk numarayi reddetmesi DOGRU davranis.
    telefon = f"+9053{int(telefon_son):08d}"
    r = client.post("/dukkan/auth/telefon/kod", json={"telefon": telefon})
    assert r.status_code == 200, r.text
    kod = r.json().get("dev_kod")
    assert kod, "dev_kod donmedi — DUKKAN_OTP_YANITTA acik degil mi?"
    r = client.post(
        "/dukkan/auth/telefon/dogrula",
        json={"telefon": telefon, "kod": kod, "ad_soyad": "Test"},
    )
    assert r.status_code == 200, r.text
    d = r.json()
    return {
        "telefon": telefon,
        "h": {"Authorization": f"Bearer {d['access_token']}"},
        "id": d["kullanici"]["id"],
    }


def _isletme(client, sahip: dict, ad: str) -> str:
    r = client.post(
        "/dukkan/isletme",
        headers=sahip["h"],
        json={"ad": ad, "telefon": "+905321112233"},
    )
    assert r.status_code == 201, r.text
    return r.json()["id"]


@pytest.fixture
def iki_sahip(client):
    """Iki AYRI isletme sahibi ve birer isletme."""
    a = _kullanici(client, uuid.uuid4().int % 10**8)
    b = _kullanici(client, uuid.uuid4().int % 10**8)
    return {
        "a": a, "b": b,
        "a_isletme": _isletme(client, a, f"A-{uuid.uuid4().hex[:6]}"),
        "b_isletme": _isletme(client, b, f"B-{uuid.uuid4().hex[:6]}"),
    }


# --------------------------------------------------------------------- #
# HER UC ICIN BIR OLCUM
# --------------------------------------------------------------------- #
# (metot, yol_sablonu, govde) — `{id}` cagri aninda doldurulur.
# YENI BIR `/isletme/{id}/...` UCU EKLERKEN BURAYA DA SATIR EKLE;
# eklemezsen asagidaki tarama testi duser.
OZEL_UCLAR = [
    ("get", "/dukkan/isletme/{id}", None),
    ("patch", "/dukkan/isletme/{id}", {"aciklama": "sizma denemesi"}),
    ("put", "/dukkan/isletme/{id}/kategoriler", {"slugler": []}),
    ("put", "/dukkan/isletme/{id}/hizmet-alanlari", {"mahalle_idler": []}),
    ("post", "/dukkan/isletme/{id}/basvur", None),
    ("post", "/dukkan/isletme/{id}/belge/presign",
     {"tip": "vergi_levhasi", "content_type": "image/jpeg"}),
    ("get", "/dukkan/isletme/{id}/belge", None),
    ("post", "/dukkan/isletme/{id}/telefon/kod", None),
    ("post", "/dukkan/isletme/{id}/telefon/dogrula", {"kod": "000000"}),
]


@pytest.mark.parametrize(
    "metot,sablon,govde", OZEL_UCLAR, ids=[f"{m}:{y}" for m, y, _ in OZEL_UCLAR]
)
def test_BASKASININ_ISLETMESINE_403(iki_sahip, client, metot, sablon, govde):
    """A'nin sahibi B'nin isletmesine dokunamaz."""
    yol = sablon.format(id=iki_sahip["b_isletme"])
    cagri = getattr(client, metot)
    r = cagri(yol, headers=iki_sahip["a"]["h"], **({"json": govde} if govde else {}))
    assert r.status_code == 403, (
        f"{metot.upper()} {yol} -> {r.status_code} (403 bekleniyordu). "
        f"IDOR: baska bir isletmenin verisine erisilebiliyor. {r.text[:200]}"
    )


@pytest.mark.parametrize(
    "metot,sablon,govde", OZEL_UCLAR, ids=[f"{m}:{y}" for m, y, _ in OZEL_UCLAR]
)
def test_KENDI_ISLETMESI_403_DEGIL(iki_sahip, client, metot, sablon, govde):
    """TERS YONLU KANIT.

    Yukaridaki testler, uc HERKESE 403 donse de gecerdi — yani bozuk bir
    uc "guvenli" gorunurdu. Bu test sahibin KENDI isletmesine
    erisebildigini olcer: 403 DISINDA herhangi bir yanit (200, 422, 409
    dahil) kabul.
    """
    yol = sablon.format(id=iki_sahip["a_isletme"])
    cagri = getattr(client, metot)
    r = cagri(yol, headers=iki_sahip["a"]["h"], **({"json": govde} if govde else {}))
    assert r.status_code != 403, (
        f"{metot.upper()} {yol} sahibine 403 donuyor — sahiplik kontrolu ters."
    )


def test_JETONSUZ_401(iki_sahip, client):
    """Kimliksiz istek 403 degil 401 almali: fark, istemcinin ne yapacagini
    belirler (giris ekranina git vs. yetkin yok)."""
    for metot, sablon, govde in OZEL_UCLAR:
        yol = sablon.format(id=iki_sahip["a_isletme"])
        r = getattr(client, metot)(yol, **({"json": govde} if govde else {}))
        assert r.status_code == 401, f"{metot.upper()} {yol} -> {r.status_code}"


def test_OLMAYAN_ISLETME_404(iki_sahip, client):
    """Var olmayan kimlige 404 — 403 DEGIL.

    Var olmayan bir kimlige 403 demek, "bu kimlik var ama senin degil"
    bilgisini sizdirirdi ve kimlik taramasina kapi acardi.
    """
    yok = uuid.uuid4()
    r = client.get(f"/dukkan/isletme/{yok}", headers=iki_sahip["a"]["h"])
    assert r.status_code == 404, r.text


# --------------------------------------------------------------------- #
# TARAMA — testsiz uc eklenemez
# --------------------------------------------------------------------- #

def test_HER_ISLETME_UCUNUN_IDOR_TESTI_VAR(client):
    """ASIL KILIT.

    Uygulamadaki her `/dukkan/isletme/{...}` ucu `OZEL_UCLAR` listesinde
    olmali. Olmazsa bu test duser ve yeni uc IDOR olcumu OLMADAN
    birlestirilemez.

    Bu kural bir sureç kurali degil MAKINE kurali olmak zorunda: "insan
    hatirlar" varsayimi bu depoda P173/P189'da iki kez tutmadi.
    """
    spec = client.get("/openapi.json").json()
    uygulamada: set[tuple[str, str]] = set()
    for yol, islemler in spec["paths"].items():
        if not yol.startswith("/dukkan/isletme/{"):
            continue
        for metot in ("get", "post", "put", "patch", "delete"):
            if metot in islemler:
                uygulamada.add((metot, yol))

    # Listeyi ayni bicime getir: `{id}` -> gercek parametre adi.
    kapsanan = set()
    for metot, sablon, _ in OZEL_UCLAR:
        kapsanan.add((metot, sablon.replace("{id}", "{isletme_id}")))

    eksik = sorted(uygulamada - kapsanan)
    assert not eksik, (
        f"Su uclarin IDOR testi YOK: {eksik}. "
        "`OZEL_UCLAR` listesine ekleyin — sahiplik kontrolu olmayan bir uc, "
        "baska bir isletmenin verisini acar."
    )
    assert uygulamada, "hic /dukkan/isletme/{...} ucu bulunamadi — tarama bos"


def test_MODERASYON_UCLARI_moderator_ISTER(iki_sahip, client):
    """Siradan bir isletme sahibi moderasyon kuyruguna GIREMEZ.

    Kuyruk her basvurunun telefonunu, vergi numarasini ve sahip
    bilgisini gosterir; siradan bir kullaniciya acilmasi dogrudan
    kisisel veri sizintisi olurdu.
    """
    for metot, yol, govde in [
        ("get", "/dukkan/moderasyon/kuyruk", None),
        ("post", f"/dukkan/moderasyon/isletme/{iki_sahip['b_isletme']}/karar",
         {"karar": "onayla"}),
        ("get", f"/dukkan/moderasyon/isletme/{iki_sahip['b_isletme']}/denetim",
         None),
    ]:
        r = getattr(client, metot)(
            yol, headers=iki_sahip["a"]["h"], **({"json": govde} if govde else {})
        )
        assert r.status_code == 403, f"{metot.upper()} {yol} -> {r.status_code}"


# --------------------------------------------------------------------- #
# DUKKAN'IN KENDI "KAPISIZ MUTASYON" KILIDI
# --------------------------------------------------------------------- #

def test_HER_DUKKAN_MUTASYONUNUN_KIMLIK_KAPISI_VAR():
    """Her Dukkan mutasyon ucu ya KAMU beyan edilmis ya kimlik istiyor.

    ==================================================================
    NEDEN BU TEST VAR
    ==================================================================
    Yonetiyor'un `test_denetci_salt_okuma.py` kilidi "rol kapisi olmayan
    mutasyon ucu" ariyor ve Dukkan uclari oraya dusuyordu — ama o
    kilidin onermesi ("kapisiz uc denetciye aciktir") Dukkan icin YANLIS:
    Dukkan'in kendi kimlik sistemi var ve Yonetiyor jetonu oraya HIC
    gecmiyor (401).

    Dukkan uclarini o kilitten muaf tuttuk. MUAFIYET BIR DELIK ACMASIN
    diye Dukkan'in KENDI esdegeri bu testtir: kimlik kapisi unutulmus
    bir mutasyon ucu, o ucu HERKESE acardi — ornegin kimliksiz birinin
    isletme olusturmasi ya da moderasyon karari vermesi.
    """
    from fastapi.routing import APIRoute

    from app.dukkan.kimlik import kimlik_zorunlu, moderator_zorunlu
    from app.main import app

    # ACIKCA KAMU olan mutasyon uclari — her biri GEREKCELI.
    KAMU = {
        # Kimlik ONCESI: istegi atanin henuz oturumu yok. Kapi OLAMAZ,
        # cunku uc tam olarak oturum acmaya yariyor. Hiz siniri var
        # (saatte 5) ve kod yanitta DONMEZ.
        ("POST", "/dukkan/auth/telefon/kod"),
        ("POST", "/dukkan/auth/telefon/dogrula"),
        # SSO koprusu: Dukkan jetonu YOK (zaten onu uretiyor). Kendi
        # kapisi var — YONETIYOR jetonu dogrulanir, gecersizse 401.
        ("POST", "/dukkan/auth/yonetiyor"),
    }

    kapisiz: list[str] = []
    for route in app.routes:
        if not isinstance(route, APIRoute):
            continue
        if not route.path.startswith("/dukkan"):
            continue
        metotlar = {m for m in route.methods if m not in ("GET", "HEAD", "OPTIONS")}
        if not metotlar:
            continue

        # Bagimlilik agacinda Dukkan kimlik kapisi var mi?
        cagrilar = {d.call for d in route.dependant.dependencies}
        # Ic ice bagimliliklar (moderator_zorunlu -> kimlik_zorunlu).
        yigin = list(route.dependant.dependencies)
        while yigin:
            d = yigin.pop()
            cagrilar.add(d.call)
            yigin.extend(d.dependencies)
        korumali = kimlik_zorunlu in cagrilar or moderator_zorunlu in cagrilar

        for metot in metotlar:
            if (metot, route.path) in KAMU:
                continue
            if not korumali:
                kapisiz.append(f"{metot} {route.path}")

    assert not kapisiz, (
        "Su Dukkan mutasyon uclarinda KIMLIK KAPISI YOK: "
        + ", ".join(sorted(kapisiz))
        + ". Kimliksiz biri bu ucu cagirabilir. Kasitliysa `KAMU` kumesine "
        "GEREKCESIYLE ekleyin."
    )


def test_KAMU_KUMESI_OLU_SATIR_TASIMAZ():
    """Kaldirilan bir uc `KAMU` kumesinde kalirsa kural sessizce genis
    kalirdi — ve o yol bir gun yeniden acildiginda kapisiz dogardi."""
    from fastapi.routing import APIRoute

    from app.main import app

    var = {
        (m, r.path)
        for r in app.routes
        if isinstance(r, APIRoute)
        for m in r.methods
    }
    KAMU = {
        ("POST", "/dukkan/auth/telefon/kod"),
        ("POST", "/dukkan/auth/telefon/dogrula"),
        ("POST", "/dukkan/auth/yonetiyor"),
    }
    olu = sorted(KAMU - var)
    assert not olu, f"KAMU kumesinde olu satir: {olu}"
