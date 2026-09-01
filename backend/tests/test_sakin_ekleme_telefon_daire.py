"""(P154 / Asama 5+6) SAKIN EKLEME — telefon + daire no, ve DAIRE TEKILLIGI.

IKI KURAL, TEK UC (`POST /residents`) — bu yuzden tek dosya:

  §5.2  "MOBIL: 'Site sakini' sekmesinden TEKLI ekler; eklerken YALNIZ
        TELEFON girer." (Kerem netlestirdi: telefon + daire no; ad ve
        parola formdan kalkti.)
  §6.1  "Bir daire icin en fazla 1 hesap." Kerem'in kararina gore
        "her daire tek malik tek kiraci" — yani kural ROL BASINA
        uygulanir (goc 0049).

NEDEN BU DOSYA VAR: kontrol `units.assign_resident` ve ICE AKTARIMDA
vardi, ama sakin acmanin ASIL kapisi olan `POST /residents`te YOKTU.
Veritabani indeksi (unit_id, rol_tipi) ikinci bir MALIKI yakalar; ama
PostgreSQL benzersiz indekslerde NULL'lari catistirmaz — rol tipi
verilmeden acilan sakinler ayni daireye SINIRSIZ eklenebiliyordu. Mobil
form artik rol tipi sormadigi icin o dal VARSAYILAN yol hâline geldi.
"""
from __future__ import annotations

import uuid



def _p197_mail() -> str:
    """(P197) Kullanici/sakin olusturmada e-posta ZORUNLU oldu.

    `app_user.email` NOT NULL (goc 0089): davet, dogrulama kodu ve parola
    sifirlama YALNIZ e-postadan gidiyor, yani e-postasiz acilan hesap
    sahiplenilemez. Test govdelerine BENZERSIZ adres verilir —
    `uq_app_user_tenant_email` ayni tesiste tekrari reddeder.
    """
    return f"p197-{uuid.uuid4().hex[:12]}@ornek.com"

def _headers(client, slug, cred) -> dict:
    r = client.post(
        "/auth/login",
        json={
            "tenant_slug": slug,
            "email": cred["email"],
            "password": cred["password"],
        },
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _tel() -> str:
    return "+9058" + str(uuid.uuid4().int)[:8]


def _daire() -> str:
    return f"T{uuid.uuid4().hex[:5]}"


# ===================== §5.2 — AD VE PAROLA ISTENMEZ ======================== #

def test_YALNIZ_telefon_ve_daire_ile_sakin_acilir(client, world):
    """Govdede `ad` YOK — 201 doner ve hesap gercekten acilir."""
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    daire = _daire()

    r = client.post(
        "/residents",
        headers=yon,
        json={"telefon": _tel(), "unit_no": daire, "email": _p197_mail()},
    )
    assert r.status_code == 201, r.text
    govde = r.json()
    assert govde["unit_no"] == daire
    # (P186) Hesap PAROLASIZ acilir; gecici kod URETILMEZ, davet gonderilir.
    assert "temp_code" not in govde
    assert govde.get("davet") is not None


def test_ad_verilmezse_DAIREDEN_turetilir(client, world):
    """Ad bos kalmaz: listede anlamli, gecici oldugu okunan bir ad.

    `app_user.ad` NOT NULL ve 87 yerde okunuyor; sutunu global nullable
    yapmak brief'in dokunmadigi her ekrani ilgilendirirdi. Bunun yerine
    uc daireden turetilen bir ad yazar ve kisi kaydolunca profilinden
    duzeltir.
    """
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    daire = _daire()

    r = client.post(
        "/residents", headers=yon, json={"telefon": _tel(), "unit_no": daire, "email": _p197_mail()}
    )
    assert r.status_code == 201, r.text
    assert r.json()["ad"] == f"{daire} sakini"


def test_ad_VERILIRSE_aynen_korunur(client, world):
    """Web/Excel yolu adi biliyor: turetilen ad onu EZMEZ."""
    yon = _headers(client, world["slug_a"], world["yonetici_a"])

    r = client.post(
        "/residents",
        headers=yon,
        json={"telefon": _tel(), "unit_no": _daire(), "ad": "Ayşe Yılmaz", "email": _p197_mail()},
    )
    assert r.status_code == 201, r.text
    assert r.json()["ad"] == "Ayşe Yılmaz"


# ============ §6.1 — DAIRE BASINA HER ROLDEN BIR AKTIF HESAP =============== #

def test_ayni_daireye_IKINCI_malik_eklenemez(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    daire = _daire()

    ilk = client.post("/residents", headers=yon, json={
        "telefon": _tel(), "unit_no": daire, "rol_tipi": "malik", "email": _p197_mail()})
    assert ilk.status_code == 201, ilk.text

    ikinci = client.post("/residents", headers=yon, json={
        "telefon": _tel(), "unit_no": daire, "rol_tipi": "malik", "email": _p197_mail()})
    assert ikinci.status_code == 409, ikinci.text
    assert ikinci.json()["error"]["code"] == "conflict"


def test_MALIK_ve_KIRACI_ayni_dairede_BIRLIKTE_durur(client, world):
    """Kerem'in karari: "her daire tek malik tek kiraci".

    Kuralin HARFI (rol'e bakmadan tek sakin) `borclandirma.hedef_sec`in
    `kiraci_oncelikli` kuralini secece bir sey birakmazdi — o kural bir
    dairede malik VE kiraci bulunabilmesi uzerine kurulu.
    """
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    daire = _daire()

    m = client.post("/residents", headers=yon, json={
        "telefon": _tel(), "unit_no": daire, "rol_tipi": "malik", "email": _p197_mail()})
    assert m.status_code == 201, m.text

    k = client.post("/residents", headers=yon, json={
        "telefon": _tel(), "unit_no": daire, "rol_tipi": "kiraci", "email": _p197_mail()})
    assert k.status_code == 201, k.text
    # AYNI daire — ikisi de aktif.
    assert k.json()["unit_id"] == m.json()["unit_id"]


def test_ROL_TIPI_VERILMEDEN_ikinci_sakin_de_reddedilir(client, world):
    """NULL BOSLUGU — bu turun kapattigi asil kusur.

    Mobil form rol tipi sormuyor; iki eklemede de `rol_tipi` NULL olur.
    Veritabani indeksi NULL'lari catistirmadigi icin bu dal sinirsizdi.
    """
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    daire = _daire()

    ilk = client.post(
        "/residents", headers=yon, json={"telefon": _tel(), "unit_no": daire, "email": _p197_mail()}
    )
    assert ilk.status_code == 201, ilk.text

    ikinci = client.post(
        "/residents", headers=yon, json={"telefon": _tel(), "unit_no": daire, "email": _p197_mail()}
    )
    assert ikinci.status_code == 409, ikinci.text
