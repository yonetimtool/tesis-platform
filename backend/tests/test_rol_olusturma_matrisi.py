"""(P130) KIM KIMI ACABILIR — yetki yukseltme sinirinin TAM matrisi.

NEDEN AYRI DOSYA: `test_users.py` tek tek ornekler olcuyordu (yonetici admin
acamaz, amir yalniz guvenlik acar). Ornek testi bir KURALI yazmaz: matrise yeni
bir rol eklendiginde (P128 `denetci`) hicbir test dusmez ve yeni rol SESSIZCE
herkese acik gelir. Burada matrisin HER HUCRESI olculur — izinliler 201, yasak
olanlar 403 — ve yeni bir rol eklendiginde bu dosya derlenmez bile
(`_HEDEFLER` eksik kalir, `test_matris_tam` duser).

IKI YON SART: yalniz "yasaklar 403" olculseydi TUM olusturmayi kapatmak da
testi gecerdi; yalniz "izinliler 201" olculseydi hicbir sinir olmayan bir
sistem de gecerdi.
"""
from __future__ import annotations

import uuid

import pytest

# Sistemdeki TUM roller (models.USER_ROLE). Bir rol eklenip buraya
# yazilmazsa `test_matris_tam` duser.
TUM_ROLLER = (
    "admin",
    "yonetici",
    "security",
    "tesis_gorevlisi",
    "resident",
    "guvenlik_amiri",
    # (P128) Yedinci rol — salt-okuma mali denetci.
    "denetci",
)

#: Kimin hangi rolu YONETEBILDIGI (olustur + duzenle + pasiflestir +
#: parola sifirla). Anahtar = yoneten, deger = yonetilen roller. Listede
#: olmayan her cift 403 BEKLER.
#:
#: (Duzeltme turu) `yonetici` icin `resident` EKLENDI. Onceki tur onu
#: olusturma gerekcesiyle disarida birakmisti ("sakin `/residents`ten
#: acilir"); ama ayni tablo DUZENLEMEYI de yonettigi icin yan etkisi
#: yoneticinin kendi tesisindeki sakinin adini bile duzeltememesiydi
#: (canli olculdu: 403 "yalniz saha personelini duzenleyebilirsiniz").
#:
#: (P185) `yonetici` icin `yonetici` EKLENDI — es-yonetici ekleme. Bu bir
#: yetki YUKSELTMESI degil, ayni yetki duzeyinin cogaltilmasidir; site
#: yonetimi birden fazla yonetici tanimlar (manager-join).
YONETILEN = {
    "admin": {"admin", "yonetici", "security", "tesis_gorevlisi", "resident",
              "guvenlik_amiri", "denetci"},
    # (P128/P130b) Denetciyi ATAYAN denetlenen tesisin kendi yonetimidir.
    # `resident`: yonetici kendi tesisinin sakinini yonetir.
    # (P185) `yonetici`: es-yonetici ekleme.
    "yonetici": {"resident", "security", "tesis_gorevlisi", "denetci", "yonetici"},
    "guvenlik_amiri": {"security"},
    "security": set(),
    "tesis_gorevlisi": set(),
    "resident": set(),
    # Salt-okuma rol hesap ACMAZ.
    "denetci": set(),
}



def _p197_mail() -> str:
    """(P197) Kullanici/sakin olusturmada e-posta ZORUNLU oldu.

    `app_user.email` NOT NULL (goc 0089): davet, dogrulama kodu ve parola
    sifirlama YALNIZ e-postadan gidiyor, yani e-postasiz acilan hesap
    sahiplenilemez. Test govdelerine BENZERSIZ adres verilir —
    `uq_app_user_tenant_email` ayni tesiste tekrari reddeder.
    """
    return f"p197-{uuid.uuid4().hex[:12]}@ornek.com"

def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _uphone() -> str:
    return "+90" + str(uuid.uuid4().int)[:10]


def _acan(client, world, rol: str) -> dict[str, str]:
    anahtar = {
        "admin": "admin_a",
        "yonetici": "yonetici_a",
        "security": "guard_a",
        "tesis_gorevlisi": "gorevli_a",
        "resident": "resident_a",
        "guvenlik_amiri": "amir_a",
        "denetci": "denetci_a",
    }[rol]
    return _headers(client, world["slug_a"], world[anahtar])


def test_matris_tam():
    """Matris TUM rolleri kapsiyor — yeni bir rol sessizce kacamaz."""
    assert set(YONETILEN) == set(TUM_ROLLER), "her rol ACAN olarak da olculmeli"
    for acan, hedefler in YONETILEN.items():
        assert hedefler <= set(TUM_ROLLER), hedefler


def test_kod_tablosu_beklenenle_AYNI():
    """`app/roller.py` tablosu bu dosyadaki BEKLENTIYLE birebir ayni.

    Bu bir kopya degil KILIT: yukaridaki davranis testleri tabloyu uctan
    olcer, bu test tablonun KENDISINI okur. Biri degisip digeri kalirsa
    ikisinden en az biri duser — tabloyu tek satirla gevsetip davranis
    testlerini de birlikte guncelleyen bir degisiklik gozden kacamaz.
    """
    from app.roller import YONETILEBILIR_ROLLER, TUM_ROLLER as KOD_ROLLERI

    assert set(KOD_ROLLERI) == set(TUM_ROLLER)
    assert {k: set(v) for k, v in YONETILEBILIR_ROLLER.items()} == YONETILEN


def test_taninmayan_rol_HICBIR_SEY_acamaz():
    """Fail-closed: tabloda olmayan rol bos kume alir.

    Varsayilan "her sey" olsaydi, tabloya yazilmayi unutulan yeni bir rol
    sistemin EN YETKILI rolu olarak dogardi.
    """
    from app.roller import yonetilebilir as _yonetilebilir

    assert _yonetilebilir("olmayan_rol") == frozenset()


@pytest.mark.parametrize("acan_rol", sorted(YONETILEN))
def test_acilabilir_roller_ucu_matrisle_AYNI(client, world, acan_rol):
    """Panelin acilir listesi sunucudan gelir — gosterilen = yapilabilen.

    Bu ucun VARLIK SEBEBI: liste istemcide sabitti ve alti rolu de
    gosteriyordu; site yoneticisi "Platform Admin"i secip 403 aliyordu.
    """
    h = _acan(client, world, acan_rol)
    r = client.get("/users/acilabilir-roller", headers=h)
    if not YONETILEN[acan_rol]:
        # Hic hesap acamayan rol ucu de GORMEZ (require_role kapisi).
        assert r.status_code == 403, r.text
        return
    assert r.status_code == 200, r.text
    assert set(r.json()["roller"]) == YONETILEN[acan_rol]


@pytest.mark.parametrize("acan_rol", sorted(YONETILEN))
@pytest.mark.parametrize("hedef_rol", TUM_ROLLER)
def test_kim_kimi_acar(client, world, acan_rol, hedef_rol):
    h = _acan(client, world, acan_rol)
    r = client.post(
        "/users",
        headers=h,
        json={
            "ad": f"{acan_rol}->{hedef_rol}",
            "email": f"m-{uuid.uuid4().hex[:8]}@acme.com",
            "telefon": _uphone(),
            "role": hedef_rol,
            "password": "GecerliParola1!",
        },
    )
    bekleniyor = 201 if hedef_rol in YONETILEN[acan_rol] else 403
    assert r.status_code == bekleniyor, (
        f"{acan_rol} -> {hedef_rol}: {r.status_code} beklenen {bekleniyor} · {r.text}"
    )


# --------------------------------------------------------------------------- #
# DUZENLEME MATRISI — "kim kimin KAYDINA dokunabilir".
#
# Bu bolum bir DUZELTME turunda eklendi: olusturma tablodan, duzenleme ise
# router icindeki ayri bir `if` zincirinden okunuyordu ve ikisi ayrismisti.
# Canli olcum: yonetici bir SAKININ adini degistirmeye calisinca 403
# ("yalniz saha personelini duzenleyebilirsiniz") — oysa ayni yonetici o
# sakini `/residents` ile ACABILIYORDU.
# --------------------------------------------------------------------------- #
def _kayit_ac(client, admin, rol: str) -> str:
    """Hedef rolde bir kayit acar (admin her rolu acabilir) ve id doner."""
    r = client.post(
        "/users",
        headers=admin,
        json={"ad": f"Hedef {rol}", "email": f"m-{uuid.uuid4().hex[:8]}@acme.com",
              "telefon": _uphone(), "role": rol,
              "password": "GecerliParola1!"},
    )
    assert r.status_code == 201, r.text
    return r.json()["id"]


@pytest.mark.parametrize("yoneten_rol", sorted(YONETILEN))
@pytest.mark.parametrize("hedef_rol", TUM_ROLLER)
def test_kim_kimin_kaydini_DUZENLER(client, world, yoneten_rol, hedef_rol):
    """HER CIFT: yonetilen kumedeyse 200, degilse 403."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    uid = _kayit_ac(client, admin, hedef_rol)

    h = _acan(client, world, yoneten_rol)
    r = client.patch(f"/users/{uid}", headers=h, json={"ad": "Yeni Ad"})
    bekleniyor = 200 if hedef_rol in YONETILEN[yoneten_rol] else 403
    assert r.status_code == bekleniyor, (
        f"{yoneten_rol} -> {hedef_rol} duzenleme: {r.status_code} "
        f"beklenen {bekleniyor} · {r.text}"
    )


@pytest.mark.parametrize("hedef_rol", TUM_ROLLER)
def test_yonetici_PASIFLESTIRME_ayni_kurala_tabi(client, world, hedef_rol):
    """Pasiflestirme de duzenlemedir — ayri bir kapisi YOKTUR."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    uid = _kayit_ac(client, admin, hedef_rol)
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.patch(f"/users/{uid}", headers=yonetici, json={"is_active": False})
    bekleniyor = 200 if hedef_rol in YONETILEN["yonetici"] else 403
    assert r.status_code == bekleniyor, f"{hedef_rol}: {r.status_code} · {r.text}"


# (P186) parola-sifirlama ucu KALDIRILDI — yonetici parola atayamaz/sifirlayamaz.
# "Kaydina dokunamadigin kisinin parolasini da sifirlayamazsin" testi artik
# konusuz (uc yok); duzenleme/pasiflestirme kurali yukaridaki testlerde olculur.


def test_SAKIN_DUZENLEME_bu_turun_kusuru(client, world):
    """Bildirilen kusurun DOGRUDAN karsiligi (gerileme kilidi).

    Yonetici bir sakinin adini degistirebilmeli ve pasiflestirebilmeli.
    """
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])
    uid = _kayit_ac(client, admin, "resident")

    ad = client.patch(f"/users/{uid}", headers=yonetici, json={"ad": "Düzeltilmiş Ad"})
    assert ad.status_code == 200, ad.text
    assert ad.json()["ad"] == "Düzeltilmiş Ad"

    pasif = client.patch(f"/users/{uid}", headers=yonetici, json={"is_active": False})
    assert pasif.status_code == 200, pasif.text
    assert pasif.json()["is_active"] is False


def test_duzenleme_AUDIT_kaydinda_hedefin_rolu_var(client, world):
    """Denetim izi: kim, HANGI ROLDEKI kaydi, hangi alanlarda degistirdi."""
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])
    uid = _kayit_ac(client, admin, "resident")
    assert client.patch(
        f"/users/{uid}", headers=yonetici, json={"ad": "Denetimli Ad"}
    ).status_code == 200

    kayitlar = client.get(
        "/audit", headers=admin, params={"action": "user_update", "limit": 200}
    )
    assert kayitlar.status_code == 200, kayitlar.text
    satir = next(
        (k for k in kayitlar.json()["items"] if str(k.get("resource_id")) == str(uid)),
        None,
    )
    assert satir is not None, "duzenleme audit'e yazilmamis"
    assert satir["actor_rol"] == "yonetici"
    assert satir["meta"]["hedef_rol"] == "resident"
    assert "ad" in satir["meta"]["fields"]


@pytest.mark.parametrize("hedef_rol", TUM_ROLLER)
def test_rol_yukseltme_patch_ile_de_olmaz(client, world, hedef_rol):
    """PATCH ile rol degistirmek de ayni sinira tabi (acma yolu tek degil)."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/users",
        headers=admin,
        json={"ad": "Hedef", "email": f"m-{uuid.uuid4().hex[:8]}@acme.com",
              "telefon": _uphone(), "role": "security",
              "password": "GecerliParola1!"},
    )
    assert r.status_code == 201, r.text
    uid = r.json()["id"]

    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    p = client.patch(f"/users/{uid}", headers=yonetici, json={"role": hedef_rol})
    bekleniyor = 200 if hedef_rol in YONETILEN["yonetici"] else 403
    assert p.status_code == bekleniyor, (
        f"yonetici PATCH role={hedef_rol}: {p.status_code} beklenen {bekleniyor} · {p.text}"
    )


def test_olusturma_audit_kaydinda_ACANIN_rolu_var(client, world):
    """(P130) Denetim kaydi 'kim actigini' degil 'HANGI ROLLE actigini' da yazar.

    Kullanici sonradan rol degistirebilir; kaydin o anki rolu tasimamasi,
    aylar sonra "bu hesabi kim yetkilendirdi" sorusunu cevapsiz birakirdi.
    """
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post(
        "/users",
        headers=yonetici,
        json={"ad": "Denetimli", "email": f"m-{uuid.uuid4().hex[:8]}@acme.com",
              "telefon": _uphone(), "role": "security",
              "password": "GecerliParola1!"},
    )
    assert r.status_code == 201, r.text
    yeni_id = r.json()["id"]

    admin = _headers(client, world["slug_a"], world["admin_a"])
    kayitlar = client.get(
        "/audit", headers=admin, params={"action": "user_create", "limit": 200}
    )
    assert kayitlar.status_code == 200, kayitlar.text
    satir = next(
        (k for k in kayitlar.json()["items"] if str(k.get("resource_id")) == str(yeni_id)),
        None,
    )
    assert satir is not None, "olusturma audit'e yazilmamis"
    assert satir["meta"]["role"] == "security"   # ACILAN rol
    assert satir["actor_rol"] == "yonetici"      # ACANIN rolu
