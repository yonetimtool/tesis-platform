"""(P177 §4-§6 + §9) YENI KAYIT AKISI — bayrak, uc sart kurali, SMS yasagi.

===========================================================================
BU DOSYA IKI KIPTE KOSAR VE IKISINI DE OLCER
===========================================================================
`YENI_KAYIT_AKISI` bir BAYRAKTIR ve iki durumu da kabul kriteridir:

  * KAPALI (varsayilan, §9.2): dort yeni uc da 503 doner ve MEVCUT kimlik
    sistemi birebir bugunku gibi calisir.
  * ACIK (§9.9, §9.10): uc sart kurali isler.

Testler CANLI sunucuya vurur (bu depoda `client` fixture'i httpx'tir,
monkeypatch YOKTUR) — yani bayragin o anki degeri sunucudadir. Bu yuzden
dosya once bir PROBE atar ve hangi kipte oldugunu OLCER; her testin
kendisi gecerli olmadigi kipte ATLANIR.

Boylece tam kapsam icin iki kosum gerekir ve `docs/P177-dagitim.md`
ikisini de yaziyor:
    docker compose up -d api                       # kapali
    YENI_KAYIT_AKISI=true docker compose up -d api # acik

TEK KOSUMDA "hepsi yesil" gorunup yarisini olcmemektense, atlananin
sayilmasi dogru: `-rs` ile atlananlar raporda gorunur.
"""
from __future__ import annotations

import uuid

import pytest

from app.security import hash_password

KOD = "424242"


# --------------------------------------------------------------------------- #
# Yardimcilar
# --------------------------------------------------------------------------- #
#: E-posta alan adi. `.test`/`.invalid`/`.example` KULLANILAMAZ:
#: `email-validator` bunlari "special-use" diye REDDEDER ve testler
#: olcmek istedikleri seyden once 422'ye carpar (olculdu).
EPOSTA_ALANI = "p177ornek.com"


def _eposta() -> str:
    return f"p177-{uuid.uuid4().hex[:12]}@{EPOSTA_ALANI}"


def _telefon() -> str:
    return "+90" + str(uuid.uuid4().int)[:10]


@pytest.fixture
def akis_acik(client) -> bool:
    """Sunucudaki bayragin GERCEK durumu — ayardan degil, DAVRANISTAN.

    `settings`i import edip okumak YANLIS OLURDU: testler baska bir
    surecte (konteynerde) kosan sunucuya vuruyor ve oradaki ortam
    degiskeni bu surecinkiyle ayni olmak zorunda degil. Olcum, ucun
    KENDI yanitindan gelir.

    FONKSIYON KAPSAMLI (`module` DEGIL): `client` fixture'i fonksiyon
    kapsamlidir ve daha genis kapsamli bir fixture ondan besleneMEZ
    (pytest ScopeMismatch). Probe tek bir HTTP istegidir; her testte
    yeniden atmanin olculebilir bir bedeli yok.
    """
    r = client.post(
        "/auth/kayit/yonetici-dogrula",
        json={"eposta": f"probe@{EPOSTA_ALANI}", "kod": "000000"},
    )
    return r.status_code != 503


def _basvur(client, eposta: str, telefon: str, **ez):
    govde = {
        "ad": "Ayşe",
        "soyad": "Yılmaz",
        "eposta": eposta,
        "telefon": telefon,
        "parola": "GucluParola123!",
        "onay_sozlesme": True,
        "onay_kvkk": True,
        "onay_ticari": False,
    }
    govde.update(ez)
    return client.post("/auth/kayit/yonetici-basvuru", json=govde)


def _kodu_ayarla(owner_conn, tablo: str, kosul_sutun: str, deger: str, kod=KOD):
    """Uretilen kodu BILINEN bir degere cevirir (deponun mevcut deseni).

    Kod e-postayla gidiyor ve dev'de SMTP yapilandirilmamis; testin kodu
    ogrenmesinin baska bir yolu YOK. Alternatif — kodu yanitta dondurmek —
    uretimde bir guvenlik acigi olurdu.
    """
    with owner_conn.cursor() as cur:
        cur.execute(
            f"UPDATE {tablo} SET kod_hash = %s WHERE {kosul_sutun} = %s "
            "AND kod_hash IS NOT NULL",
            (hash_password(kod), deger),
        )
        assert cur.rowcount >= 1, f"{tablo} kod satiri uretilmemis"
    owner_conn.commit()


# =========================================================================== #
# 1) BAYRAK KAPALI — §9.2
# =========================================================================== #
#: GOVDELER GECERLI ve bu bilincli. Bos govde gondermek daha kisa olurdu
#: ama OLCUMU BOZARDI: FastAPI govdeyi HANDLER CALISMADAN once dogrular,
#: yani bos govde 422 doner ve bayrak kapisina HIC ULASILMAZ. O testi
#: yazip yesil gormek, kapiyi olctugunu SANMAK olurdu.
#:
#: (Kapinin dogrulamadan ONCE calismasi da tasarlanabilirdi — bir
#: `Depends` ile. Yapilmadi: FastAPI govde ile bagimliliklari birlikte
#: cozer ve siralama garanti degildir; garanti eden tek sey burada
#: olculen davranistir.)
YENI_UCLAR = [
    (
        "/auth/kayit/yonetici-basvuru",
        {
            "ad": "Ayşe",
            "soyad": "Yılmaz",
            "eposta": "kapali@p177ornek.com",
            "telefon": "+905321119999",
            "parola": "GucluParola123!",
            "onay_sozlesme": True,
            "onay_kvkk": True,
        },
    ),
    ("/auth/kayit/yonetici-dogrula", {"eposta": "kapali@p177ornek.com", "kod": "000000"}),
    ("/auth/kayit/yonetici-tesis", {"kurulum_jetonu": "x.y.z", "tesis_ad": "Kapali Site"}),
    (
        "/auth/kayit/rol-eposta-basla",
        {"tesis_kodu": "KAPA-260101", "eposta": "kapali@p177ornek.com", "rol": "resident"},
    ),
    (
        "/auth/kayit/rol-eposta-dogrula",
        {"tesis_kodu": "KAPA-260101", "eposta": "kapali@p177ornek.com", "kod": "000000"},
    ),
    # (P184) SSO tamamlama uclari da bayraga tabi (`_kapi()` ilk satir).
    (
        "/auth/oauth/rol-tamamla",
        {"baglama_jetonu": "x.y.z", "tesis_kodu": "KAPA-260101", "rol": "resident"},
    ),
    (
        "/auth/oauth/rol-tamamla-dogrula",
        {
            "baglama_jetonu": "x.y.z",
            "tesis_kodu": "KAPA-260101",
            "rol": "resident",
            "kod": "000000",
        },
    ),
]


@pytest.mark.parametrize("yol,govde", YENI_UCLAR)
def test_bayrak_kapaliyken_yeni_uclar_503(client, akis_acik, yol, govde):
    """Kapaliyken 503 — ve 404 DEGIL.

    404 "boyle bir sey yok" der ve istemciyi yanlis teshise gonderirdi;
    uc VAR, gecici olarak KAPALI.

    GOVDELER GECERLI: bos govde 422'ye takilir ve kapiya hic ulasmaz
    (bkz. `YENI_UCLAR` notu). Olculen sey, DOGRU BICIMDE gelen bir
    istegin bile reddedildigi.
    """
    if akis_acik:
        pytest.skip("bayrak ACIK — bu olcum yalniz kapali kipte anlamli")
    r = client.post(yol, json=govde)
    assert r.status_code == 503, r.text
    # HATA ZARFI: `{"error": {"code", "message"}}` — depodaki tek bicim.
    # `code` "unavailable"dir; kimlik (`kayit_akisi_kapali`) `message`
    # uretiminde kullanilir ve 7 dile cevrilir.
    assert r.json()["error"]["code"] == "unavailable", r.text


def test_bayrak_kapaliyken_mevcut_kayit_yolu_CALISIYOR(client, akis_acik):
    """§9.2 — "mevcut davranis birebir surer".

    Olculen sey `tesis-olustur`un HALA CALISMASI: bayragi okumadigi icin
    kapali kipte de tesis acabilmeli. Bu, "yeni akis eklerken eskisini
    kirdik mi" sorusunun tek dogrudan olcumu.

    (P197) KIMLIK YONTEMI PAROLADAN SSO'YA CEVRILDI. Ucun e-posta kaynagi
    saglayicidir; parola yolunda hicbir adres yok ve `app_user.email` NOT
    NULL oldu (goc 0089), yani o yol 422 doner. URUNDE DE KULLANILMIYORDU:
    web kayit sayfasi bu ucu YALNIZ sosyal yolda cagiriyor, mobilde
    hicbir ekran cagirmiyor. Olculen sey (bayrak kapaliyken uc CALISIR)
    aynen duruyor.
    """
    if akis_acik:
        pytest.skip("bayrak ACIK — kapali kip olcumu")
    r = client.post(
        "/auth/kayit/tesis-olustur",
        json={
            "tesis_ad": f"P177 Kapali {uuid.uuid4().hex[:6]}",
            "ad": "Mevcut Yol",
            "telefon": _telefon(),
            "baglama_jetonu": _sso_jeton(
                f"p197-p177-{uuid.uuid4().hex[:10]}@{EPOSTA_ALANI}"),
        },
    )
    assert r.status_code == 201, r.text
    assert r.json()["tesis_kodu"], r.text


# =========================================================================== #
# 2) YONETICI KAYDI — §9.5, §9.7
# =========================================================================== #
def test_zorunlu_onaylar_olmadan_basvuru_REDDEDILIR(client, akis_acik):
    """§9.5 — iki zorunlu onay isaretlenmeden gonderim engelleniyor.

    ARAYUZ DE ENGELLIYOR ama olculen sey SUNUCU: istemci dogrulamasi
    atlanabilir ve onay bir HUKUKI kayittir.
    """
    if not akis_acik:
        pytest.skip("bayrak KAPALI")
    for ez in ({"onay_sozlesme": False}, {"onay_kvkk": False}):
        r = _basvur(client, _eposta(), _telefon(), **ez)
        assert r.status_code == 422, f"{ez} -> {r.status_code} {r.text}"


def test_yonetici_kaydi_ucten_uce(client, owner_conn, akis_acik):
    """§9.7 — basvuru -> kod -> site adi -> Tesis ID + oturum."""
    if not akis_acik:
        pytest.skip("bayrak KAPALI")
    eposta, telefon = _eposta(), _telefon()

    assert _basvur(client, eposta, telefon).status_code == 201

    _kodu_ayarla(owner_conn, "yonetici_basvuru", "eposta", eposta)
    r = client.post(
        "/auth/kayit/yonetici-dogrula", json={"eposta": eposta, "kod": KOD}
    )
    assert r.status_code == 200, r.text
    jeton = r.json()["kurulum_jetonu"]

    tesis_ad = f"P177 Site {uuid.uuid4().hex[:6]}"
    r = client.post(
        "/auth/kayit/yonetici-tesis",
        json={"kurulum_jetonu": jeton, "tesis_ad": tesis_ad},
    )
    assert r.status_code == 201, r.text
    govde = r.json()
    assert govde["tesis_kodu"], "Tesis ID donmedi"
    assert govde["jetonlar"]["access_token"], "oturum acilmadi"

    # E-POSTA `app_user`A YAZILDI MI: `create_tenant_with_yoneticis` onu
    # almiyor; router sonradan yaziyor. Yazilmazsa yonetici e-postayla
    # GIRIS YAPAMAZDI ve bu ancak canli kullanimda fark edilirdi.
    with owner_conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM app_user WHERE lower(email) = %s", (eposta,))
        assert cur.fetchone()[0] == 1

    # (§6) COK TESISLI UYELIK SATIRI YAZILDI MI.
    with owner_conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM tesis_uyelik WHERE lower(eposta) = %s", (eposta,))
        assert cur.fetchone()[0] == 1


def test_kurulum_jetonu_TEK_KULLANIMLIK(client, owner_conn, akis_acik):
    """Ayni jetonla ikinci bir tesis acilamaz.

    Cift tiklama ya da iki sekme, bir yoneticiye iki tesis acmamali —
    ikincisi sahipsiz kalirdi.
    """
    if not akis_acik:
        pytest.skip("bayrak KAPALI")
    eposta, telefon = _eposta(), _telefon()
    assert _basvur(client, eposta, telefon).status_code == 201
    _kodu_ayarla(owner_conn, "yonetici_basvuru", "eposta", eposta)
    jeton = client.post(
        "/auth/kayit/yonetici-dogrula", json={"eposta": eposta, "kod": KOD}
    ).json()["kurulum_jetonu"]

    ilk = client.post(
        "/auth/kayit/yonetici-tesis",
        json={"kurulum_jetonu": jeton, "tesis_ad": f"P177 Bir {uuid.uuid4().hex[:6]}"},
    )
    assert ilk.status_code == 201, ilk.text
    ikinci = client.post(
        "/auth/kayit/yonetici-tesis",
        json={"kurulum_jetonu": jeton, "tesis_ad": f"P177 Iki {uuid.uuid4().hex[:6]}"},
    )
    assert ikinci.status_code == 401, ikinci.text


def test_yanlis_kod_denemesi_SAYILIYOR(client, owner_conn, akis_acik):
    """Deneme sayaci AYRI OTURUMDA artmali — P148'de bu koruma calismiyordu.

    Olcum davranistan degil VERIDEN yapiliyor: yanlis kod ayni 422'yi
    doner, sayacin arttigini yalnizca satir gosterir.
    """
    if not akis_acik:
        pytest.skip("bayrak KAPALI")
    eposta, telefon = _eposta(), _telefon()
    assert _basvur(client, eposta, telefon).status_code == 201
    r = client.post(
        "/auth/kayit/yonetici-dogrula", json={"eposta": eposta, "kod": "000001"}
    )
    assert r.status_code == 422, r.text
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT kod_deneme FROM yonetici_basvuru WHERE eposta = %s", (eposta,)
        )
        assert cur.fetchone()[0] == 1, "deneme sayaci geri sarildi (P148 kusuru)"


def test_ticari_onay_SAKLANIR(client, owner_conn, akis_acik):
    """Ucuncu onay saklanir — ama hicbir ticari ileti gonderilmez.

    Gonderimin kapali oldugu `test_p177_sms_ve_ileti.py`de ayrica
    olculuyor; burada olculen tek sey RIZANIN KAYDEDILDIGI.
    """
    if not akis_acik:
        pytest.skip("bayrak KAPALI")
    eposta, telefon = _eposta(), _telefon()
    assert _basvur(client, eposta, telefon, onay_ticari=True).status_code == 201
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT onay_ticari, onay_sozlesme, onay_kvkk, onay_at IS NOT NULL "
            "FROM yonetici_basvuru WHERE eposta = %s",
            (eposta,),
        )
        assert cur.fetchone() == (True, True, True, True)


def test_ikinci_basvuru_DUVARA_CARPMAZ(client, akis_acik):
    """Kodunu kaybeden kullanici bastan deneyebilmeli (basvuru TAZELENIR)."""
    if not akis_acik:
        pytest.skip("bayrak KAPALI")
    eposta, telefon = _eposta(), _telefon()
    assert _basvur(client, eposta, telefon).status_code == 201
    assert _basvur(client, eposta, telefon).status_code == 201


# =========================================================================== #
# 3) ROL KAYDI — UC SART BIRLIKTE (§9.9, §9.10)
# =========================================================================== #
@pytest.fixture
def hazir_tesis(client, owner_conn, akis_acik):
    """Yeni akisla acilmis bir tesis + icine EKLENMIS bir sakin.

    Tesis YENI AKISLA aciliyor (mevcut `tesis-olustur` ile degil) cunku
    olcum konusu tam olarak o yol; iki yolun urettigi tesisin ayni oldugunu
    varsaymak yerine olculeni kullanmak dogru.
    """
    if not akis_acik:
        pytest.skip("bayrak KAPALI")
    eposta, telefon = _eposta(), _telefon()
    assert _basvur(client, eposta, telefon).status_code == 201
    _kodu_ayarla(owner_conn, "yonetici_basvuru", "eposta", eposta)
    jeton = client.post(
        "/auth/kayit/yonetici-dogrula", json={"eposta": eposta, "kod": KOD}
    ).json()["kurulum_jetonu"]
    r = client.post(
        "/auth/kayit/yonetici-tesis",
        json={"kurulum_jetonu": jeton, "tesis_ad": f"P177 Rol {uuid.uuid4().hex[:6]}"},
    )
    assert r.status_code == 201, r.text
    tesis_kodu = r.json()["tesis_kodu"]

    with owner_conn.cursor() as cur:
        cur.execute("SELECT id FROM tenant WHERE kayit_kodu = %s", (tesis_kodu,))
        tenant_id = cur.fetchone()[0]
        # YONETICININ EKLEDIGI SAKIN — parolasi HENUZ BELIRLENMEMIS.
        sakin = f"sakin-{uuid.uuid4().hex[:10]}@{EPOSTA_ALANI}"
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, email, role, is_active, "
            "password_set) VALUES (%s, %s, %s, 'resident', true, false)",
            (tenant_id, "Listedeki Sakin", sakin),
        )
    owner_conn.commit()
    return {"tesis_kodu": tesis_kodu, "tenant_id": tenant_id, "sakin": sakin}


def test_listede_OLMAYAN_eposta_hesap_ACMAZ_kuyruga_duser(
    client, owner_conn, hazir_tesis
):
    """§9.9 — dogru Tesis ID + listede OLMAYAN e-posta.

    IKI SEY BIRDEN olculuyor ve ikisi de gerekli:
      * hesap ACILMIYOR (`durum != 'hazir'`, `setup_token` yok),
      * deneme KAYBOLMUYOR (onay kuyrugunda bir satir var).
    Yalniz birincisini olcmek, sessizce yutulan bir denemeyi "dogru
    davranis" saymak olurdu.
    """
    yabanci = f"yabanci-{uuid.uuid4().hex[:10]}@{EPOSTA_ALANI}"
    r = client.post(
        "/auth/kayit/rol-eposta-basla",
        json={
            "tesis_kodu": hazir_tesis["tesis_kodu"],
            "eposta": yabanci,
            "rol": "resident",
            "ad": "Yabancı Deneme",
        },
    )
    assert r.status_code == 200, r.text
    # SIZINTI YOK: yanit, adresin listede olmadigini SOYLEMEZ.
    assert r.json()["durum"] == "kod_gonderildi"

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT sebep, durum FROM kayit_onay_kuyrugu "
            "WHERE tenant_id = %s AND eposta = %s",
            (hazir_tesis["tenant_id"], yabanci),
        )
        satir = cur.fetchone()
        assert satir is not None, "deneme onay kuyruguna dusmedi"
        assert satir == ("liste_disi", "bekliyor")

        # HESAP ACILMADI.
        cur.execute("SELECT count(*) FROM app_user WHERE lower(email) = %s", (yabanci,))
        assert cur.fetchone()[0] == 0

        # KOD DA URETILMEDI: uygun olmayan adrese kod gondermek, adresin
        # sistemde olup olmadigini e-posta kutusundan okutmak olurdu.
        cur.execute(
            "SELECT count(*) FROM kayit_dogrulama WHERE eposta = %s AND amac='kayit'",
            (yabanci,),
        )
        assert cur.fetchone()[0] == 0


def test_listedeki_eposta_dogru_kodla_kayit_TAMAMLANIR(
    client, owner_conn, hazir_tesis
):
    """§9.10 — uc sart da tuttu: hesap sahiplenilir ve parola belirlenir."""
    sakin = hazir_tesis["sakin"]
    r = client.post(
        "/auth/kayit/rol-eposta-basla",
        json={
            "tesis_kodu": hazir_tesis["tesis_kodu"],
            "eposta": sakin,
            "rol": "resident",
        },
    )
    assert r.status_code == 200, r.text

    _kodu_ayarla(owner_conn, "kayit_dogrulama", "eposta", sakin)
    r = client.post(
        "/auth/kayit/rol-eposta-dogrula",
        json={
            "tesis_kodu": hazir_tesis["tesis_kodu"],
            "eposta": sakin,
            "kod": KOD,
        },
    )
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "hazir", r.text
    setup = r.json()["setup_token"]
    assert setup

    # MEVCUT `set-password` KAPISI KULLANILIYOR — ikinci bir parola
    # belirleme yolu acilmadi.
    r = client.post(
        "/auth/set-password", json={"setup_token": setup, "new_password": "YeniParola123!"}
    )
    assert r.status_code == 200, r.text
    assert r.json()["access_token"]


def test_yanlis_tesis_kodu_ile_kayit_OLMAZ(client, hazir_tesis):
    """(a) sarti: Tesis ID gecersizse hicbir sey olmaz."""
    r = client.post(
        "/auth/kayit/rol-eposta-basla",
        json={
            "tesis_kodu": "YOKK-990101",
            "eposta": hazir_tesis["sakin"],
            "rol": "resident",
        },
    )
    assert r.status_code == 422, r.text


def test_rol_uyusmuyorsa_kuyruga_duser(client, owner_conn, hazir_tesis):
    """Kisi listede AMA baska rolde — sebep AYIRT EDILEBILIR olmali.

    Yoneticinin panelinde "liste_disi" ile "rol_uyusmuyor" FARKLI
    kararlar gerektirir: ilkinde kisiyi eklemek, ikincisinde rolu
    duzeltmek gerekir.
    """
    r = client.post(
        "/auth/kayit/rol-eposta-basla",
        json={
            "tesis_kodu": hazir_tesis["tesis_kodu"],
            "eposta": hazir_tesis["sakin"],
            "rol": "security",
        },
    )
    assert r.status_code == 200, r.text
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT sebep FROM kayit_onay_kuyrugu WHERE eposta = %s",
            (hazir_tesis["sakin"],),
        )
        assert cur.fetchone() == ("rol_uyusmuyor",)


# (P185) MANAGER-JOIN: ikinci yonetici de rol-eposta ile katilir. `_ROLLER`
# artik "yonetici"yi kabul eder; kural degismez (once eklenmis olmali).
def test_yonetici_listedekiyse_rol_eposta_ile_TAMAMLANIR(
    client, owner_conn, hazir_tesis
):
    """(P185) Onceden EKLENMIS bir yonetici, rol='yonetici' ile katilir."""
    eposta = f"esyon-{uuid.uuid4().hex[:10]}@{EPOSTA_ALANI}"
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, email, role, is_active, "
            "password_set) VALUES (%s, %s, %s, 'yonetici', true, false)",
            (hazir_tesis["tenant_id"], "Es Yonetici", eposta),
        )
    owner_conn.commit()

    r = client.post(
        "/auth/kayit/rol-eposta-basla",
        json={
            "tesis_kodu": hazir_tesis["tesis_kodu"],
            "eposta": eposta,
            "rol": "yonetici",
        },
    )
    assert r.status_code == 200, r.text

    _kodu_ayarla(owner_conn, "kayit_dogrulama", "eposta", eposta)
    r = client.post(
        "/auth/kayit/rol-eposta-dogrula",
        json={"tesis_kodu": hazir_tesis["tesis_kodu"], "eposta": eposta, "kod": KOD},
    )
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "hazir", r.text
    assert r.json()["setup_token"]


def test_yonetici_listede_YOKSA_kuyruga_duser(client, owner_conn, hazir_tesis):
    """(P185) rol='yonetici' kabul edilir AMA kural degismez: listede
    olmayan adres hesap ACMAZ, `liste_disi` sebebiyle kuyruga duser."""
    yabanci = f"yabanci-yon-{uuid.uuid4().hex[:10]}@{EPOSTA_ALANI}"
    r = client.post(
        "/auth/kayit/rol-eposta-basla",
        json={
            "tesis_kodu": hazir_tesis["tesis_kodu"],
            "eposta": yabanci,
            "rol": "yonetici",
            "ad": "Yabanci Yonetici",
        },
    )
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "kod_gonderildi"
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT sebep, durum FROM kayit_onay_kuyrugu "
            "WHERE tenant_id = %s AND eposta = %s",
            (hazir_tesis["tenant_id"], yabanci),
        )
        assert cur.fetchone() == ("liste_disi", "bekliyor")
        cur.execute("SELECT count(*) FROM app_user WHERE lower(email) = %s", (yabanci,))
        assert cur.fetchone()[0] == 0


def test_ayni_adresten_bes_deneme_TEK_kuyruk_satiri(client, owner_conn, hazir_tesis):
    """Kuyruk SISMEZ: `uq_kayit_onay_acik` ve tazeleme birlikte."""
    yabanci = f"israrci-{uuid.uuid4().hex[:10]}@{EPOSTA_ALANI}"
    for _ in range(5):
        client.post(
            "/auth/kayit/rol-eposta-basla",
            json={
                "tesis_kodu": hazir_tesis["tesis_kodu"],
                "eposta": yabanci,
                "rol": "resident",
            },
        )
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM kayit_onay_kuyrugu WHERE eposta = %s", (yabanci,)
        )
        assert cur.fetchone()[0] == 1


# =========================================================================== #
# 4) (P184) SSO ROL TAMAMLAMA — E-POSTA (SMS'SIZ)
# =========================================================================== #
#
# `/auth/oauth/rol-tamamla` uc sartin SSO karsiligi: (a) Tesis ID, (b) liste,
# (c) `email_verified=true` -> OTP ATLANIR / `false` -> e-posta OTP. Jeton
# TEST SURECINDE uretilir: testler ayni konteynerde kosar, `jwt_secret` ayni,
# yani burada imzalanan `baglama_jetonu` sunucuda dogrulanir.


def _sso_jeton(eposta: str, *, email_verified: bool = True, subject: str | None = None):
    """Callback'in urettigi `baglama_jetonu`nun aynisini test icin uretir."""
    from app.routers.oauth import _baglama_jetonu

    return _baglama_jetonu(
        {
            "saglayici": "google",
            "subject": subject or f"sub-{uuid.uuid4().hex}",
            "eposta": eposta,
            "email_verified": email_verified,
            "ad": "SSO Kişi",
            "onaylar": None,
        }
    )


def test_sso_email_verified_DOGRUDAN_baglar_ve_oturum(client, owner_conn, hazir_tesis):
    """(c) email_verified=true -> OTP YOK: kimlik baglanir, oturum acilir."""
    sakin = hazir_tesis["sakin"]
    subject = f"sub-{uuid.uuid4().hex}"
    r = client.post(
        "/auth/oauth/rol-tamamla",
        json={
            "baglama_jetonu": _sso_jeton(sakin, email_verified=True, subject=subject),
            "tesis_kodu": hazir_tesis["tesis_kodu"],
            "rol": "resident",
        },
    )
    assert r.status_code == 200, r.text
    govde = r.json()
    assert govde["durum"] == "giris", govde
    assert govde["jetonlar"]["access_token"], govde

    with owner_conn.cursor() as cur:
        # KIMLIK BAGLANDI.
        cur.execute(
            "SELECT count(*) FROM oauth_kimlik WHERE saglayici='google' AND subject=%s",
            (subject,),
        )
        assert cur.fetchone()[0] == 1
        # E-POSTA DOGRULANMIS ISARETLENDI.
        cur.execute(
            "SELECT eposta_dogrulandi FROM app_user WHERE lower(email)=%s", (sakin,)
        )
        assert cur.fetchone()[0] is True


def test_sso_liste_disi_eposta_ONAY_BEKLIYOR(client, owner_conn, hazir_tesis):
    """(b) liste disi -> hesap ACMAZ, kuyruga duser, kimlik BAGLANMAZ."""
    yabanci = f"sso-yabanci-{uuid.uuid4().hex[:10]}@{EPOSTA_ALANI}"
    subject = f"sub-{uuid.uuid4().hex}"
    r = client.post(
        "/auth/oauth/rol-tamamla",
        json={
            "baglama_jetonu": _sso_jeton(yabanci, email_verified=True, subject=subject),
            "tesis_kodu": hazir_tesis["tesis_kodu"],
            "rol": "resident",
        },
    )
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "onay_bekliyor", r.text
    assert r.json().get("jetonlar") is None

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT sebep, durum FROM kayit_onay_kuyrugu "
            "WHERE tenant_id=%s AND eposta=%s",
            (hazir_tesis["tenant_id"], yabanci),
        )
        assert cur.fetchone() == ("liste_disi", "bekliyor")
        # KIMLIK ACILMADI.
        cur.execute(
            "SELECT count(*) FROM oauth_kimlik WHERE subject=%s", (subject,)
        )
        assert cur.fetchone()[0] == 0


def test_sso_GECERSIZ_tesis_id_ayni_generic_yanit(client, owner_conn, hazir_tesis):
    """(K4) Gecersiz Tesis ID, LISTE DISI ile AYNI: onay_bekliyor (422 DEGIL).

    Listedeki gercek sakinin adresiyle ama YANLIS Tesis ID ile denenir:
    yanit, adresin bir yerde kayitli oldugunu SIZDIRMAMALI — liste disi
    denemeyle ayni `onay_bekliyor` gelmeli. Ve kuyruga da YAZILMAZ (tenant yok).
    """
    sakin = hazir_tesis["sakin"]
    r = client.post(
        "/auth/oauth/rol-tamamla",
        json={
            "baglama_jetonu": _sso_jeton(sakin, email_verified=True),
            "tesis_kodu": "YOKK-990101",
            "rol": "resident",
        },
    )
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "onay_bekliyor", r.text
    with owner_conn.cursor() as cur:
        # Tenant bilinmedigi icin kuyruga da yazilmadi.
        cur.execute(
            "SELECT count(*) FROM kayit_onay_kuyrugu WHERE eposta=%s AND durum='bekliyor'",
            (sakin,),
        )
        assert cur.fetchone()[0] == 0


def test_sso_email_verified_FALSE_once_OTP_sonra_baglar(client, owner_conn, hazir_tesis):
    """(c/K3) Dogrulanmamis e-posta -> OTP zorunlu, sonra baglanir.

    Iki adim: `rol-tamamla` `otp_gerekli` doner + kod satiri yazar;
    `rol-tamamla-dogrula` dogru kodla kimligi baglar ve oturum acar.
    """
    sakin = hazir_tesis["sakin"]
    subject = f"sub-{uuid.uuid4().hex}"
    jeton = _sso_jeton(sakin, email_verified=False, subject=subject)
    r = client.post(
        "/auth/oauth/rol-tamamla",
        json={
            "baglama_jetonu": jeton,
            "tesis_kodu": hazir_tesis["tesis_kodu"],
            "rol": "resident",
        },
    )
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "otp_gerekli", r.text
    # Kimlik HENUZ baglanmadi.
    with owner_conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM oauth_kimlik WHERE subject=%s", (subject,))
        assert cur.fetchone()[0] == 0

    _kodu_ayarla(owner_conn, "kayit_dogrulama", "eposta", sakin)
    r = client.post(
        "/auth/oauth/rol-tamamla-dogrula",
        json={
            "baglama_jetonu": jeton,
            "tesis_kodu": hazir_tesis["tesis_kodu"],
            "rol": "resident",
            "kod": KOD,
        },
    )
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "giris", r.text
    assert r.json()["jetonlar"]["access_token"]
    with owner_conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM oauth_kimlik WHERE subject=%s", (subject,))
        assert cur.fetchone()[0] == 1


def test_sso_kimlik_BASKA_hesaba_bagliysa_409(client, owner_conn, hazir_tesis):
    """(K6) Ayni sosyal kimlik baska bir kullaniciya bagliysa DEVRALINMAZ."""
    sakin = hazir_tesis["sakin"]
    subject = f"sub-{uuid.uuid4().hex}"
    with owner_conn.cursor() as cur:
        # AYNI tenant'ta BASKA bir kullaniciya bagli oauth_kimlik.
        baskasi = f"sso-baska-{uuid.uuid4().hex[:8]}@{EPOSTA_ALANI}"
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, email, role, is_active, password_set) "
            "VALUES (%s, %s, %s, 'resident', true, true) RETURNING id",
            (hazir_tesis["tenant_id"], "Baska Kisi", baskasi),
        )
        baska_id = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO oauth_kimlik (tenant_id, user_id, saglayici, subject, eposta) "
            "VALUES (%s, %s, 'google', %s, %s)",
            (hazir_tesis["tenant_id"], baska_id, subject, baskasi),
        )
    owner_conn.commit()

    r = client.post(
        "/auth/oauth/rol-tamamla",
        json={
            "baglama_jetonu": _sso_jeton(sakin, email_verified=True, subject=subject),
            "tesis_kodu": hazir_tesis["tesis_kodu"],
            "rol": "resident",
        },
    )
    assert r.status_code == 409, r.text
    assert r.json()["error"]["code"] == "conflict", r.text


def test_sso_TESIS_GOREVLISI_rolu_dogru_esler(client, owner_conn, akis_acik):
    """(K7) `tesis_gorevlisi` e-posta/SSO ile TAMAMLANIR (eski 'gorevli' hatasi).

    `_ROLLER` "gorevli" iken bir tesis gorevlisi HER ZAMAN `rol_uyusmuyor`
    ile kuyruga duserdi. Duzeltmeden sonra `durum='giris'` gelmeli.
    """
    if not akis_acik:
        pytest.skip("bayrak KAPALI")
    # Yeni akisla tesis ac + icine bir TESIS GOREVLISI ekle.
    eposta, telefon = _eposta(), _telefon()
    assert _basvur(client, eposta, telefon).status_code == 201
    _kodu_ayarla(owner_conn, "yonetici_basvuru", "eposta", eposta)
    jeton = client.post(
        "/auth/kayit/yonetici-dogrula", json={"eposta": eposta, "kod": KOD}
    ).json()["kurulum_jetonu"]
    tesis_kodu = client.post(
        "/auth/kayit/yonetici-tesis",
        json={"kurulum_jetonu": jeton, "tesis_ad": f"P184 Gör {uuid.uuid4().hex[:6]}"},
    ).json()["tesis_kodu"]

    gorevli = f"gorevli-{uuid.uuid4().hex[:10]}@{EPOSTA_ALANI}"
    with owner_conn.cursor() as cur:
        cur.execute("SELECT id FROM tenant WHERE kayit_kodu=%s", (tesis_kodu,))
        tenant_id = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, email, role, is_active, password_set) "
            "VALUES (%s, %s, %s, 'tesis_gorevlisi', true, false)",
            (tenant_id, "Listedeki Görevli", gorevli),
        )
    owner_conn.commit()

    r = client.post(
        "/auth/oauth/rol-tamamla",
        json={
            "baglama_jetonu": _sso_jeton(gorevli, email_verified=True),
            "tesis_kodu": tesis_kodu,
            "rol": "tesis_gorevlisi",
        },
    )
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "giris", r.text
