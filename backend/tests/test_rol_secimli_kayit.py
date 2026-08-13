"""(P154 / Asama 3) ROL SECIMLI KAYIT — rol + tesis ID + telefon -> parola.

Kural: "Tesis ID + telefon ONCEDEN TANIMLI kayitla eslesmiyorsa
kaydolamaz." Yani bu akis hesap ACMAZ; yoneticinin ZATEN ACTIGI hesabi
kisiye SAHIPLENDIRIR.

BU DOSYANIN ASIL ISI SIZDIRMAMAYI OLCMEK. Uc, bir numaranin bir tesiste
hangi rolde kayitli oldugunu soyleyen bir SORGULAMA ARACINA donusmemeli;
bu yuzden testlerin cogu "yanit AYNI mi" diye bakar, "hata dogru mu"
diye degil.
"""
from __future__ import annotations

import uuid


def _kod(owner_conn, slug: str) -> str:
    with owner_conn.cursor() as cur:
        cur.execute("SELECT kayit_kodu FROM tenant WHERE slug = %s", (slug,))
        return cur.fetchone()[0]


def _tel() -> str:
    return "+9059" + str(uuid.uuid4().int)[:8]


def _parolasiz_kullanici(owner_conn, slug: str, rol: str, telefon: str) -> uuid.UUID:
    """Yoneticinin actigi gibi bir hesap: parola YOK, gecici kod YOK."""
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, email, telefon, password_hash, "
            "                      password_set, role, is_active) "
            "SELECT id, %s, %s, %s, NULL, false, %s::user_role, true "
            "FROM tenant WHERE slug = %s RETURNING id",
            (f"Test {rol}", f"{uuid.uuid4().hex[:10]}@test.local", telefon, rol, slug),
        )
        return cur.fetchone()[0]


def _kodu_al(owner_conn, telefon: str) -> str:
    """Kod SMS ile gider ve hash tutulur; testte DUZ METIN okunamaz.

    Bu yuzden dogrulama testlerinde kaydin hash'ini BILDIGIMIZ bir kodun
    hash'iyle degistiriyoruz. Olculen sey kod uretimi degil, AKISIN
    KENDISI (rol/daire/parola kontrolleri + jeton).
    """
    from app.security import hash_password

    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE kayit_dogrulama SET kod_hash = %s "
            "WHERE telefon = %s AND durum = 'telefon_bekliyor' RETURNING id",
            (hash_password("424242"), telefon),
        )
        assert cur.fetchone() is not None, "bekleyen kod satiri YOK"
    return "424242"


# ===================== 1) MUTLU YOL — UCTAN UCA ============================ #

def test_yonetici_rolüyle_kaydolur_ve_parola_belirler(client, world, owner_conn):
    tel = _tel()
    _parolasiz_kullanici(owner_conn, world["slug_a"], "yonetici", tel)

    r = client.post("/auth/kayit/rol-basla", json={
        "rol": "yonetici",
        "tesis_kodu": _kod(owner_conn, world["slug_a"]),
        "telefon": tel,
    })
    assert r.status_code == 200, r.text
    assert "***" in r.json()["telefon_maskeli"]

    kod = _kodu_al(owner_conn, tel)
    d = client.post("/auth/kayit/rol-dogrula", json={"telefon": tel, "kod": kod})
    assert d.status_code == 200, d.text
    jeton = d.json()["setup_token"]

    sp = client.post("/auth/set-password", json={
        "setup_token": jeton, "new_password": "YeniParola1!"})
    assert sp.status_code == 200, sp.text
    assert sp.json()["access_token"]

    # Ve artik parolayla girebiliyor.
    lp = client.post("/auth/login-phone",
                     json={"phone": tel, "password": "YeniParola1!"})
    assert lp.status_code == 200 and lp.json()["password_setup_required"] is False


def test_sakin_DAIRE_NO_ile_kaydolur(client, world, owner_conn):
    """Yoneticiden daire istenmez, sakinden istenir (brief)."""
    tel = _tel()
    uid = _parolasiz_kullanici(owner_conn, world["slug_a"], "resident", tel)
    with owner_conn.cursor() as cur:
        no = f"S-{uuid.uuid4().hex[:4]}"
        cur.execute(
            "INSERT INTO unit (tenant_id, blok, no) "
            "SELECT id, 'A', %s FROM tenant WHERE slug = %s RETURNING id",
            (no, world["slug_a"]),
        )
        unit_id = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO unit_resident (tenant_id, unit_id, user_id) "
            "SELECT id, %s, %s FROM tenant WHERE slug = %s",
            (unit_id, uid, world["slug_a"]),
        )

    r = client.post("/auth/kayit/rol-basla", json={
        "rol": "resident",
        "tesis_kodu": _kod(owner_conn, world["slug_a"]),
        "telefon": tel,
        "daire_no": no,
    })
    assert r.status_code == 200, r.text
    kod = _kodu_al(owner_conn, tel)
    assert client.post("/auth/kayit/rol-dogrula",
                       json={"telefon": tel, "kod": kod}).status_code == 200


def test_sakin_daire_no_VERMEDEN_istek_gonderemez(client, world, owner_conn):
    """Sozlesme kurali: `resident` icin `daire_no` zorunlu -> 422."""
    r = client.post("/auth/kayit/rol-basla", json={
        "rol": "resident",
        "tesis_kodu": _kod(owner_conn, world["slug_a"]),
        "telefon": _tel(),
    })
    assert r.status_code == 422, r.text


# ===================== 2) SIZDIRMAMA — ASIL OLCUM ========================== #

def test_ESLESMEYEN_numara_AYNI_yaniti_alir(client, world, owner_conn):
    """Kayitli numara ile HIC KAYITLI OLMAYAN numara ayni yaniti almali.

    Fark olsaydi uc, "bu numara bu tesiste var mi" sorusunu yanitlayan bir
    tarama araci olurdu.
    """
    tesis = _kod(owner_conn, world["slug_a"])
    kayitli = _tel()
    _parolasiz_kullanici(owner_conn, world["slug_a"], "yonetici", kayitli)
    yabanci = _tel()

    a = client.post("/auth/kayit/rol-basla", json={
        "rol": "yonetici", "tesis_kodu": tesis, "telefon": kayitli})
    b = client.post("/auth/kayit/rol-basla", json={
        "rol": "yonetici", "tesis_kodu": tesis, "telefon": yabanci})

    assert a.status_code == b.status_code == 200
    assert a.json()["tesis_ad"] == b.json()["tesis_ad"]
    # Yalniz maske farkli olabilir (kullanicinin YAZDIGI numaradan uretilir).
    assert set(a.json().keys()) == set(b.json().keys())

    # ... ve SMS yalniz eslesende yazildi.
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT telefon FROM kayit_dogrulama WHERE telefon IN (%s, %s) "
            "AND durum = 'telefon_bekliyor'", (kayitli, yabanci),
        )
        yazilanlar = [r[0] for r in cur.fetchall()]
    assert yazilanlar == [kayitli]


def test_YANLIS_ROL_secen_kaydolamaz(client, world, owner_conn):
    """Sakin kendini yonetici ilan edemez — yanit ayni, kod GITMEZ."""
    tel = _tel()
    _parolasiz_kullanici(owner_conn, world["slug_a"], "resident", tel)
    r = client.post("/auth/kayit/rol-basla", json={
        "rol": "yonetici",
        "tesis_kodu": _kod(owner_conn, world["slug_a"]),
        "telefon": tel,
    })
    assert r.status_code == 200
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM kayit_dogrulama WHERE telefon = %s "
            "AND durum = 'telefon_bekliyor'", (tel,))
        assert cur.fetchone()[0] == 0, "yanlis rolde kod URETILDI"


def test_BASKA_TESISIN_kodu_ile_kaydolamaz(client, world, owner_conn):
    """Numara A'da kayitli; B'nin tesis kodu ile denenirse kod gitmez."""
    tel = _tel()
    _parolasiz_kullanici(owner_conn, world["slug_a"], "yonetici", tel)
    r = client.post("/auth/kayit/rol-basla", json={
        "rol": "yonetici",
        "tesis_kodu": _kod(owner_conn, world["slug_b"]),
        "telefon": tel,
    })
    assert r.status_code == 200
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM kayit_dogrulama WHERE telefon = %s "
            "AND durum = 'telefon_bekliyor'", (tel,))
        assert cur.fetchone()[0] == 0


def test_BILINMEYEN_tesis_kodu_422(client):
    """Tesis kodu KAMUYA ACIKTIR (P148.1); en sik yazim hatasi orada olur
    ve geri bildirim vermek bir sey sizdirmaz."""
    r = client.post("/auth/kayit/rol-basla", json={
        "rol": "yonetici", "tesis_kodu": "YOKBOYLE-000000", "telefon": _tel()})
    assert r.status_code == 422


def test_PAROLASI_OLAN_hesap_bu_yoldan_gecemez(client, world, owner_conn):
    """Kayit, parola BELIRLENMEMIS hesabi sahiplenmektir.

    Aksi hâlde uc ikinci bir parola SIFIRLAMA yuzeyi olurdu; parolasini
    unutanin yolu `/auth/giris/kod-iste`tir.
    """
    tel = world["yonetici_a"]["phone"]      # parolasi ZATEN belirlenmis
    r = client.post("/auth/kayit/rol-basla", json={
        "rol": "yonetici",
        "tesis_kodu": _kod(owner_conn, world["slug_a"]),
        "telefon": tel,
    })
    assert r.status_code == 200
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM kayit_dogrulama WHERE telefon = %s "
            "AND durum = 'telefon_bekliyor'", (tel,))
        assert cur.fetchone()[0] == 0


# ===================== 4) HIZ SINIRI ======================================= #

def test_kod_istegi_HIZ_SINIRINA_takilir(client, world, owner_conn):
    """Sinir DOGRULAMADAN ONCE sayar: eslesmeyen numara da sayilmali,
    yoksa uc sinirsiz denenebilen bir tarama araci olurdu."""
    from app.hiz_siniri import KOD_ISTEK_SINIRI

    tesis = _kod(owner_conn, world["slug_a"])
    yabanci = _tel()          # KASITLI olarak kayitli DEGIL
    govde = {"rol": "yonetici", "tesis_kodu": tesis, "telefon": yabanci}

    for i in range(KOD_ISTEK_SINIRI):
        assert client.post("/auth/kayit/rol-basla", json=govde).status_code == 200, i

    son = client.post("/auth/kayit/rol-basla", json=govde)
    assert son.status_code == 429, son.text
    assert son.json()["error"]["code"] == "rate_limited"


# ============ 5) (P154 duzeltme turu) HER ROL ICIN UCTAN UCA =============== #
#
# Brief: "Her rol icin uctan uca akisi test et: rol sec -> tesis ID ->
# telefon -> parola -> giris."
#
# Onceki testler yalniz `yonetici` ve `resident`i suruyordu; `security`,
# `tesis_gorevlisi` ve `denetci` icin akisin SONUNA (parola + giris) kadar
# giden hicbir olcum yoktu. Rol yolu her rolde AYNI kodu kosuyor ama
# "ayni kodu kosuyor" bir VARSAYIMDIR — daire kurali, gorev penceresi ve
# `login-phone` kapisi role gore ayrisan yerlerdir.

import pytest


def _daire_bagla(owner_conn, slug: str, user_id) -> str:
    """Sakin icin daire acar ve baglar; daire no doner."""
    no = f"E2E-{uuid.uuid4().hex[:5]}"
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO unit (tenant_id, blok, no) "
            "SELECT id, 'A', %s FROM tenant WHERE slug = %s RETURNING id",
            (no, slug),
        )
        unit_id = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO unit_resident (tenant_id, unit_id, user_id, rol_tipi) "
            "SELECT id, %s, %s, 'malik' FROM tenant WHERE slug = %s",
            (unit_id, user_id, slug),
        )
    return no


@pytest.mark.parametrize(
    "rol",
    ["yonetici", "resident", "security", "tesis_gorevlisi", "denetci"],
)
def test_UCTAN_UCA_her_rol_kaydolur_ve_girer(client, world, owner_conn, rol):
    """rol sec -> tesis ID -> telefon -> kod -> parola -> GIRIS."""
    tel = _tel()
    uid = _parolasiz_kullanici(owner_conn, world["slug_a"], rol, tel)

    govde = {
        "rol": rol,
        "tesis_kodu": _kod(owner_conn, world["slug_a"]),
        "telefon": tel,
    }
    # DAIRE YALNIZ SAKINDE: brief yoneticiden, saha rollerinden ve
    # denetciden daire ISTEMIYOR. Digerlerine daire eklemek sozlesmeyi
    # de bozardi (`RolKayitBaslaRequest` onu yalniz `resident`ta bekler).
    if rol == "resident":
        govde["daire_no"] = _daire_bagla(owner_conn, world["slug_a"], uid)

    r = client.post("/auth/kayit/rol-basla", json=govde)
    assert r.status_code == 200, r.text

    kod = _kodu_al(owner_conn, tel)
    d = client.post("/auth/kayit/rol-dogrula", json={"telefon": tel, "kod": kod})
    assert d.status_code == 200, d.text

    parola = "UctanUca1!"
    sp = client.post("/auth/set-password", json={
        "setup_token": d.json()["setup_token"], "new_password": parola})
    assert sp.status_code == 200, sp.text

    # SONRAKI GIRIS (brief §4): telefon + parola.
    lp = client.post("/auth/login-phone", json={"phone": tel, "password": parola})
    assert lp.status_code == 200, lp.text
    assert lp.json()["password_setup_required"] is False
    assert lp.json()["access_token"]


def test_DENETCI_kaydolabilir_mobil_liste_URUN_karari(client, world, owner_conn):
    """Denetcinin mobil YUZEYI yok; UCU kapali DEGIL — ve bu bilincli.

    Brief "denetcinin mobil yuzeyi yoktur, mobilde rol listesinde
    GORUNMEZ" diyor. Kapatilan sey LISTEDIR (istemci karari); ucu role
    gore kapatmak, denetcinin WEB kaydini da kirardi cunku iki yuzey
    AYNI ucu cagirir. Bu test o siniri yaziya dokuyor ki biri "denetci
    zaten kaydolamamali" diye ucu kapatmasin.
    """
    tel = _tel()
    _parolasiz_kullanici(owner_conn, world["slug_a"], "denetci", tel)
    r = client.post("/auth/kayit/rol-basla", json={
        "rol": "denetci",
        "tesis_kodu": _kod(owner_conn, world["slug_a"]),
        "telefon": tel,
    })
    assert r.status_code == 200, r.text
    # Ve kod GERCEKTEN uretildi (eslesme oldu) — sessiz dal degil.
    assert _kodu_al(owner_conn, tel)
