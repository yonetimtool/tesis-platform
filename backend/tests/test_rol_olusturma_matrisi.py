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
)

#: POST /users ile kimin hangi rolu acabildigi. Anahtar = acan, deger =
#: acabildigi roller. Listede olmayan her cift 403 BEKLER.
#:
#: `resident` bilerek YOK: sakin hesabi `POST /residents` ile acilir (daire
#: baglantisini o uc kurar). Ikinci ve daha zayif bir sakin-acma yolu
#: eklemek, dairesiz sakin uretirdi.
#: `admin` icin `resident` VARDIR (olculdu: 201): platform operatoru destek
#: amaciyla dairesiz hesap acabilir. Tesis yoneticisi icin ayni gerekce yok.
IZINLI = {
    "admin": {"admin", "yonetici", "security", "tesis_gorevlisi", "resident",
              "guvenlik_amiri"},
    "yonetici": {"security", "tesis_gorevlisi"},
    "guvenlik_amiri": {"security"},
    "security": set(),
    "tesis_gorevlisi": set(),
    "resident": set(),
}


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
    }[rol]
    return _headers(client, world["slug_a"], world[anahtar])


def test_matris_tam():
    """Matris TUM rolleri kapsiyor — yeni bir rol sessizce kacamaz."""
    assert set(IZINLI) == set(TUM_ROLLER), "her rol ACAN olarak da olculmeli"
    for acan, hedefler in IZINLI.items():
        assert hedefler <= set(TUM_ROLLER), hedefler


def test_kod_tablosu_beklenenle_AYNI():
    """`app/roller.py` tablosu bu dosyadaki BEKLENTIYLE birebir ayni.

    Bu bir kopya degil KILIT: yukaridaki davranis testleri tabloyu uctan
    olcer, bu test tablonun KENDISINI okur. Biri degisip digeri kalirsa
    ikisinden en az biri duser — tabloyu tek satirla gevsetip davranis
    testlerini de birlikte guncelleyen bir degisiklik gozden kacamaz.
    """
    from app.roller import ACILABILIR_ROLLER, TUM_ROLLER as KOD_ROLLERI

    assert set(KOD_ROLLERI) == set(TUM_ROLLER)
    assert {k: set(v) for k, v in ACILABILIR_ROLLER.items()} == IZINLI


def test_taninmayan_rol_HICBIR_SEY_acamaz():
    """Fail-closed: tabloda olmayan rol bos kume alir.

    Varsayilan "her sey" olsaydi, tabloya yazilmayi unutulan yeni bir rol
    sistemin EN YETKILI rolu olarak dogardi.
    """
    from app.roller import acilabilir as _acilabilir

    assert _acilabilir("olmayan_rol") == frozenset()


@pytest.mark.parametrize("acan_rol", sorted(IZINLI))
def test_acilabilir_roller_ucu_matrisle_AYNI(client, world, acan_rol):
    """Panelin acilir listesi sunucudan gelir — gosterilen = yapilabilen.

    Bu ucun VARLIK SEBEBI: liste istemcide sabitti ve alti rolu de
    gosteriyordu; site yoneticisi "Platform Admin"i secip 403 aliyordu.
    """
    h = _acan(client, world, acan_rol)
    r = client.get("/users/acilabilir-roller", headers=h)
    if not IZINLI[acan_rol]:
        # Hic hesap acamayan rol ucu de GORMEZ (require_role kapisi).
        assert r.status_code == 403, r.text
        return
    assert r.status_code == 200, r.text
    assert set(r.json()["roller"]) == IZINLI[acan_rol]


@pytest.mark.parametrize("acan_rol", sorted(IZINLI))
@pytest.mark.parametrize("hedef_rol", TUM_ROLLER)
def test_kim_kimi_acar(client, world, acan_rol, hedef_rol):
    h = _acan(client, world, acan_rol)
    r = client.post(
        "/users",
        headers=h,
        json={
            "ad": f"{acan_rol}->{hedef_rol}",
            "telefon": _uphone(),
            "role": hedef_rol,
            "password": "GecerliParola1!",
        },
    )
    bekleniyor = 201 if hedef_rol in IZINLI[acan_rol] else 403
    assert r.status_code == bekleniyor, (
        f"{acan_rol} -> {hedef_rol}: {r.status_code} beklenen {bekleniyor} · {r.text}"
    )


@pytest.mark.parametrize("hedef_rol", TUM_ROLLER)
def test_rol_yukseltme_patch_ile_de_olmaz(client, world, hedef_rol):
    """PATCH ile rol degistirmek de ayni sinira tabi (acma yolu tek degil)."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/users",
        headers=admin,
        json={"ad": "Hedef", "telefon": _uphone(), "role": "security",
              "password": "GecerliParola1!"},
    )
    assert r.status_code == 201, r.text
    uid = r.json()["id"]

    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    p = client.patch(f"/users/{uid}", headers=yonetici, json={"role": hedef_rol})
    bekleniyor = 200 if hedef_rol in IZINLI["yonetici"] else 403
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
        json={"ad": "Denetimli", "telefon": _uphone(), "role": "security",
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
