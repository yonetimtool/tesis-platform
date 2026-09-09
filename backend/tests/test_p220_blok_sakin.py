"""(P220 §4) BLOK BAZLI SAKIN DUZENI — gruplama, arama, ayrilma/yenisi.

===========================================================================
OLCULEN EKSIK
===========================================================================
`GET /residents` BLOK DONMUYORDU. Istegin iki maddesi de bu yuzden
istemcide karsilanamiyordu:

  * "sakinler BLOKLARA GORE gruplansin"
  * "yonetici bir sakini bulmak icin BLOKTA arayabilsin"

Daire numarasindan blok CIKARILAMAZ: blok `unit.blok` sutunudur,
numaranin bir parcasi degil (P193'te ikisi BILEREK ayrildi — `A-12`
numarali daire `B` blogunda olabilir).

===========================================================================
AYRILAN SAKIN AKISI — UCTAN UCA SURULUYOR
===========================================================================
Istegin gerekcesi: "bir sakin siteden ayrildiginda yonetici onu kolayca
bulup hesabini silsin, yerine yeni sakini eklesin."

Bu dosya o cumleyi UC OLCUME cevirip suruyor:
  1. Blokta bulunabiliyor mu,
  2. Silinince DAIRE BOSALIYOR mu,
  3. Yerine yeni sakin eklenebiliyor mu.

Ayrica P189 AKILLI SILME kuralinin gecerli oldugu dogrulaniyor:
gecmissiz sakin TAMAMEN silinir, gecmisi olan ANONIMLESTIRILIR.
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
def yon(client, world):
    return _h(client, world["slug_a"], world["yonetici_a"])


def _tel() -> str:
    return f"+9055{uuid.uuid4().int % 10**8:08d}"


def _sakin_ac(client, yon, *, unit_no, blok, ad, rol="malik"):
    r = client.post("/residents", headers=yon, json={
        "unit_no": unit_no, "blok": blok, "ad": ad,
        "email": f"{uuid.uuid4().hex[:10]}@ornek.com",
        "telefon": _tel(), "rol_tipi": rol})
    assert r.status_code in (200, 201), r.text
    return r.json()


def _liste(client, yon, **params):
    r = client.get("/residents", headers=yon, params=params)
    assert r.status_code == 200, r.text
    return r.json()["items"]


@pytest.fixture
def sahne(client, yon):
    """Iki blok, uc sakin."""
    ek = uuid.uuid4().hex[:5].upper()
    a_blok, b_blok = f"A{ek}", f"B{ek}"
    ayse = _sakin_ac(client, yon, unit_no=f"{a_blok}-1", blok=a_blok,
                     ad=f"Ayse {ek}")
    mehmet = _sakin_ac(client, yon, unit_no=f"{a_blok}-2", blok=a_blok,
                       ad=f"Mehmet {ek}")
    zeynep = _sakin_ac(client, yon, unit_no=f"{b_blok}-1", blok=b_blok,
                       ad=f"Zeynep {ek}")
    return {"a": a_blok, "b": b_blok, "ek": ek,
            "ayse": ayse, "mehmet": mehmet, "zeynep": zeynep}


# ==================================================================== #
# 1. BLOK DONUYOR (gruplamanin on kosulu)
# ==================================================================== #

def test_LISTE_BLOK_DONUYOR(client, yon, sahne):
    """Gruplama istemcide yapilacak; on kosul blogun DONMESI."""
    items = _liste(client, yon, q=sahne["ek"])
    assert items, "sahne sakinleri listede yok"
    for x in items:
        assert "blok" in x, x
    ayse = next(x for x in items if x["user_id"] == sahne["ayse"]["user_id"])
    assert ayse["blok"] == sahne["a"], ayse


def test_DAIRESIZ_SAKIN_BLOK_NULL(client, yon, world, owner_conn):
    """Dairesi olmayan sakinde blok `null` — ve sakin LISTEDE KALIR.

    Gizlemek, siteden ayrilmis ama hesabi duran bir sakini BULUNAMAZ
    yapardi; istegin gerekcesi tam olarak onu bulup silmek.
    """
    uid = uuid.uuid4()
    from app.security import hash_password
    owner_conn.execute(
        "INSERT INTO app_user (id, tenant_id, ad, email, telefon, "
        " password_hash, password_set, role) "
        "VALUES (%s,%s,%s,%s,%s,%s,true,'resident'::user_role)",
        (uid, world["a"], f"Dairesiz {uid.hex[:5]}",
         f"{uid.hex[:10]}@ornek.com", _tel(), hash_password("Parola123!")))
    try:
        items = _liste(client, yon, q=f"Dairesiz {uid.hex[:5]}")
        assert len(items) == 1, items
        assert items[0]["blok"] is None
        assert items[0]["unit_no"] is None
    finally:
        owner_conn.execute("DELETE FROM app_user WHERE id = %s", (uid,))


# ==================================================================== #
# 2. BLOKTA ARAMA
# ==================================================================== #

def test_BLOKTA_ARAMA_calisir(client, yon, sahne):
    """"Yonetici bir sakini bulmak icin BLOKTA arayabilsin" — birebir."""
    items = _liste(client, yon, q=sahne["a"])
    idler = {x["user_id"] for x in items}
    assert sahne["ayse"]["user_id"] in idler
    assert sahne["mehmet"]["user_id"] in idler
    assert sahne["zeynep"]["user_id"] not in idler, "baska blok sizdi"


def test_ADDA_ve_DAIREDE_de_arar(client, yon, sahne):
    """Yoneticinin elinde ad, daire ya da blok olabilir — ucu de."""
    adla = _liste(client, yon, q=f"Zeynep {sahne['ek']}")
    assert [x["user_id"] for x in adla] == [sahne["zeynep"]["user_id"]]

    daireyle = _liste(client, yon, q=f"{sahne['b']}-1")
    assert sahne["zeynep"]["user_id"] in {x["user_id"] for x in daireyle}


def test_BLOK_SUZGECI_TAM_ESLESIR(client, yon, sahne):
    """`blok=A` ile `q=A` AYRI SEY: biri blogu daraltir, oteki metin arar.

    Karistirilsaydi "A" blogunu daraltmak isterken "A-12" dairesindeki
    herkes gelirdi.
    """
    items = _liste(client, yon, blok=sahne["a"])
    idler = {x["user_id"] for x in items}
    assert sahne["ayse"]["user_id"] in idler
    assert sahne["zeynep"]["user_id"] not in idler


def test_KISA_SORGU_SUZMEZ(client, yon, sahne):
    """Tek harf neredeyse herkesle eslesir; arama sayilmaz."""
    hepsi = _liste(client, yon)
    tek_harf = _liste(client, yon, q="A")
    assert len(tek_harf) == len(hepsi)


# ==================================================================== #
# 3. AYRILAN SAKIN AKISI (istegin gerekcesi — UCTAN UCA)
# ==================================================================== #

def test_AYRILAN_SAKIN_BULUNUR_SILINIR_YERINE_YENISI_EKLENIR(
        client, yon, owner_conn):
    """Istegin gerekce cumlesinin tamami tek olcumde.

    "Bir sakin siteden ayrildiginda yonetici onu kolayca BULUP hesabini
    SILSIN, YERINE yeni sakini EKLESIN."
    """
    ek = uuid.uuid4().hex[:5].upper()
    blok = f"C{ek}"
    daire = f"{blok}-7"

    # 1) AYRILAN SAKIN
    ayrilan = _sakin_ac(client, yon, unit_no=daire, blok=blok,
                        ad=f"Ayrilan {ek}")

    # 2) BLOKTA BULUNUYOR
    bulunan = _liste(client, yon, blok=blok)
    assert ayrilan["user_id"] in {x["user_id"] for x in bulunan}

    # 3) SILINIYOR
    r = client.delete(f"/residents/{ayrilan['user_id']}", headers=yon)
    assert r.status_code == 200, r.text
    # (P189) AKILLI SILME: gecmissiz sakin TAMAMEN silinir.
    assert r.json()["deleted"] is True, r.json()

    # 4) DAIRE BOSALDI — aktif bag kapandi.
    acik_bag = owner_conn.execute(
        "SELECT count(*) FROM unit_resident r JOIN unit u ON u.id = r.unit_id "
        "WHERE u.no = %s AND r.bitis IS NULL", (daire,)).fetchone()[0]
    assert acik_bag == 0, "daire BOSALMADI — yeni sakin eklenemezdi"

    # 5) LISTEDEN DUSTU
    kalan = _liste(client, yon, blok=blok)
    assert ayrilan["user_id"] not in {x["user_id"] for x in kalan}

    # 6) YERINE YENI SAKIN — AYNI DAIREYE
    yeni = _sakin_ac(client, yon, unit_no=daire, blok=blok, ad=f"Yeni {ek}")
    sonrasi = _liste(client, yon, blok=blok)
    yeni_satir = next(
        x for x in sonrasi if x["user_id"] == yeni["user_id"])
    assert yeni_satir["unit_no"] == daire, yeni_satir
    assert yeni_satir["blok"] == blok, yeni_satir


def test_GECMISI_OLAN_SAKIN_ANONIMLESTIRILIR_ve_DAIRE_YINE_BOSALIR(
        client, yon, world, owner_conn):
    """(P189) Gecmisi olan sakin SILINMEZ, ANONIMLESTIRILIR — ama daire
    yine BOSALIR ve yerine yeni sakin eklenebilir.

    Ikisini karistirmak, "silinemedi" yanitini "daire hala dolu" diye
    okumak olurdu; yonetici yeni sakini ekleyemedigini sanirdi.
    """
    ek = uuid.uuid4().hex[:5].upper()
    blok = f"D{ek}"
    daire = f"{blok}-3"
    sakin = _sakin_ac(client, yon, unit_no=daire, blok=blok, ad=f"Gecmisli {ek}")

    # GECMIS URET: FK RESTRICT tasiyan bir satir (denetim kaydi).
    # GECMIS = FK RESTRICT tasiyan bir satir. `audit_log` DEGIL — o
    # RESTRICT tasimiyor (denedim, sakin yine TAMAMEN silindi).
    # Olculdu: `app_user`a RESTRICT ile bagli tablolar
    #   scan_event, task_completion, asset_checkout, dues_payment,
    #   budget_entry, announcement, complaint, visitor ...
    # `complaint` en ucuzu: tek satir, az sutun.
    #
    # NEDEN TAHMIN ETMEDIM: `hesap_silme.py` de tahmin etmiyor —
    # `DELETE`i bir savepoint icinde DENIYOR. Testin de denenen seyi
    # gercekten kurmasi gerekiyordu.
    owner_conn.execute(
        "INSERT INTO complaint (id, tenant_id, acan_user_id, baslik, mesaj, "
        " durum, oncelik, created_at, updated_at) "
        "VALUES (gen_random_uuid(), %s, %s, 'P220 gecmis', 'olcum', "
        " 'acik', 'normal', now(), now())",
        (world["a"], sakin["user_id"]))

    r = client.delete(f"/residents/{sakin['user_id']}", headers=yon)
    assert r.status_code == 200, r.text
    # Gecmisi var -> satir KALDI, kimlik alanlari temizlendi.
    assert r.json()["deleted"] is False, r.json()

    # DAIRE YINE BOSALDI.
    acik_bag = owner_conn.execute(
        "SELECT count(*) FROM unit_resident r JOIN unit u ON u.id = r.unit_id "
        "WHERE u.no = %s AND r.bitis IS NULL", (daire,)).fetchone()[0]
    assert acik_bag == 0, "anonimlestirmede daire BOSALMADI"

    # YERINE YENI SAKIN EKLENEBILIYOR.
    yeni = _sakin_ac(client, yon, unit_no=daire, blok=blok, ad=f"Yeni {ek}")
    assert yeni["user_id"]


def test_DOLU_DAIREYE_AYNI_ROLDEN_IKINCI_SAKIN_EKLENEMEZ(client, yon):
    """Ters yon: daire GERCEKTEN dolu iken ikinci malik reddedilmeli.

    Bu kural olmasaydi "daire bosaldi" olcumu bir sey kanitlamazdi —
    her durumda eklenebiliyor olurdu.
    """
    ek = uuid.uuid4().hex[:5].upper()
    blok = f"E{ek}"
    daire = f"{blok}-9"
    _sakin_ac(client, yon, unit_no=daire, blok=blok, ad=f"Ilk {ek}")

    r = client.post("/residents", headers=yon, json={
        "unit_no": daire, "blok": blok, "ad": f"Ikinci {ek}",
        "email": f"{uuid.uuid4().hex[:10]}@ornek.com",
        "telefon": _tel(), "rol_tipi": "malik"})
    assert r.status_code == 409, r.text
    # Kimlik `message`da: bu uc `APIError(409, "conflict", <kimlik>)`
    # kalibini kullaniyor ve zarf metni ISTEGIN DILINDE uretiyor. Kodun
    # kendisini beklemek, cevirinin varligini kusur saymak olurdu.
    assert r.json()["error"]["code"] == "conflict", r.text
