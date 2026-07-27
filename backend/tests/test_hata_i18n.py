"""Sunucu hata metinleri 7 dilde (tur 14).

Tur 13'e kadar hata zarfindaki `message` SABIT Turkce cumleydi: mobil
istemci onu aynen gosterdigi icin Arapca arayuzdeki bir sakin 409'u Turkce
goruyordu. Tur 14'te `APIError` cumle degil KIMLIK tasir; metin
`Accept-Language`e gore hata isleyicisinde uretilir.

Bu dosya sozlesmenin dort ayagini kilitler:
  1. katalog TAM (her kimlik 7 dilde, bos/degismemis metin yok),
  2. cozumleyici RFC 9110 zincirini uygular ve daima bir metin dondurur,
  3. KOD (makine kanali) dilden BAGIMSIZ — istemci mantigi kodla kurulur,
  4. gercek uctan: ayni istek Accept-Language'e gore FARKLI metin dondurur.
"""
from __future__ import annotations

import re

import pytest

from app.hata_metinleri import (
    CEVRILMEYEN_KODLAR,
    METINLER,
    hata_metni,
    istek_dili,
)

DILLER = ("tr", "en", "ar", "ru", "de", "fr", "es")

# Turkce'ye OZGU harfler. `ç/ö/ü` KASITLI olarak disarida: Almanca ve
# Fransizca metinlerde de gecerler (mobil `ag_hatasi_i18n_test.dart` ile ayni
# gerekce — orada de "Zeitüberschreitung" yanlis alarm uretmisti).
TR_HARF = re.compile("[ğışĞİŞ]")


# --------------------------------------------------------------------------- #
# 1. Katalog butunlugu
# --------------------------------------------------------------------------- #
def test_katalog_tam():
    """Her kimlik 7 dilde ve bos degil."""
    assert METINLER, "katalog bos"
    for kimlik, diller in METINLER.items():
        assert set(diller) == set(DILLER), f"{kimlik}: eksik/fazla dil"
        for dil, metin in diller.items():
            assert metin.strip(), f"{kimlik}/{dil} bos"


def test_ceviri_gercekten_yapilmis():
    """Ceviri unutulup Turkce kopyalanmis kimlik YOK.

    Kopyala-yapistir en olasi hata: yeni kimlik eklenirken 6 dile ayni Turkce
    cumle yazilir ve testler "7 dil var" der. Iki bagimsiz kontrol:
    metin Turkce'nin AYNISI olmamali ve TR'ye ozgu harf tasimamali.
    """
    for kimlik, diller in METINLER.items():
        tr = diller["tr"]
        for dil in DILLER:
            if dil == "tr":
                continue
            assert diller[dil] != tr, f"{kimlik}/{dil} Turkce ile ayni"
            assert not TR_HARF.search(diller[dil]), f"{kimlik}/{dil}: {diller[dil]}"


def test_parametreli_kimliklerde_alanlar_tum_dillerde_ayni():
    """`{plaka}` gibi alanlar bir dilde dusurulmus olmamali.

    Dusen alan sessizdir: `format` patlamaz, metin eksik bilgiyle gosterilir.
    """
    alan = re.compile(r"\{(\w+)\}")
    for kimlik, diller in METINLER.items():
        beklenen = set(alan.findall(diller["tr"]))
        for dil in DILLER:
            assert set(alan.findall(diller[dil])) == beklenen, f"{kimlik}/{dil}"


# --------------------------------------------------------------------------- #
# 2. Cozumleyici
# --------------------------------------------------------------------------- #
@pytest.mark.parametrize(
    "header,beklenen",
    [
        (None, "tr"),
        ("", "tr"),
        ("ar", "ar"),
        ("ar-SA,ar;q=0.9,en;q=0.8", "ar"),
        # q sirasi: en once yazilmis olsa da ru daha yuksek q.
        ("en;q=0.3,ru;q=0.9", "ru"),
        # Desteklenmeyen dil atlanir, zincirdeki ilk DESTEKLENEN kazanir.
        ("zz,it;q=0.9,de;q=0.5", "de"),
        ("zz", "tr"),
        ("*", "tr"),
        # Bozuk header istegi dusurmez.
        (";;;q=", "tr"),
    ],
)
def test_istek_dili(header, beklenen):
    assert istek_dili(header) == beklenen


def test_hata_metni_daima_metin_dondurur():
    # Bilinmeyen kimlik -> kimligin kendisi (bos ekran YOK, 500 YOK).
    assert hata_metni("boyle_bir_kimlik_yok", "en") == "boyle_bir_kimlik_yok"
    # Bilinmeyen dil -> Turkce'ye duser.
    assert hata_metni("kayit_bulunamadi", "zz") == METINLER["kayit_bulunamadi"]["tr"]
    # Parametre eksikse ham sablon doner (istek patlamaz).
    assert "{plaka}" in hata_metni("arac_acik_gecisi_var", "en")


def test_parametre_yerlesir():
    metin = hata_metni("arac_acik_gecisi_var", "en", {"plaka": "34ABC123"})
    assert "34ABC123" in metin and "{plaka}" not in metin


def test_cevrilmeyen_kodlar_kayitli():
    """Cevrilmeyen kodlar bilincli ve DAR bir kume olmali (operator hatalari)."""
    assert CEVRILMEYEN_KODLAR == frozenset(
        {
            "storage_unconfigured",
            "config_error",
            "payment_unconfigured",
            "payment_provider_error",
            "webhook_unsupported",
        }
    )


def test_apierror_kimligi_ceviriyor():
    from app.errors import APIError

    e = APIError(404, "not_found", "kayit_bulunamadi")
    assert e.metin("ar") == METINLER["kayit_bulunamadi"]["ar"]
    assert e.metin("tr") == METINLER["kayit_bulunamadi"]["tr"]
    # Duz metin (cevrilmeyen operator hatasi) AYNEN gecer.
    duz = APIError(503, "storage_unconfigured", "MinIO yapilandirmasi eksik: X")
    assert duz.metin("ar") == "MinIO yapilandirmasi eksik: X"


# --------------------------------------------------------------------------- #
# 3. Kaynak taramasi — yeni cumleler sizmasin
# --------------------------------------------------------------------------- #
def test_kaynakta_ham_cumle_kalmadi():
    """`APIError`e cumle geciren bir cagri yeri EKLENMESIN.

    AST ile taranir (duz metin grep DEGIL) cunku mesaj her zaman cagrinin
    icinde durmaz. Tur 14'te iki ornek bunu ogretti:
      * `reservations._REASON_ERRORS` — mesajlar bir ARAMA TABLOSUNDA duruyor,
        `APIError(*tuple)` ile aciliyordu; `APIError(` grep'i goremez.
      * `cameras._url_tur_dogrula` — cumle `schemas.py`de uretilip
        `str(exc)` ile geciriliyordu.
    Bu yuzden iki kural birlikte uygulanir: (1) dogrudan cagrilar,
    (2) `(4xx/5xx, "kod", "metin")` sekilli TUM ucluler (arama tablolari).
    """
    import ast
    import pathlib

    kok = pathlib.Path(__file__).resolve().parents[1] / "app"
    sizanlar: list[str] = []

    def uygun(kod: object, mesaj: str) -> bool:
        return mesaj in METINLER or kod in CEVRILMEYEN_KODLAR

    for yol in sorted(kok.rglob("*.py")):
        agac = ast.parse(yol.read_text(encoding="utf-8"))
        for d in ast.walk(agac):
            # (1) APIError(<status>, "<code>", "<mesaj>")
            if (
                isinstance(d, ast.Call)
                and getattr(d.func, "id", None) == "APIError"
                and len(d.args) >= 3
                and isinstance(d.args[2], ast.Constant)
                and isinstance(d.args[2].value, str)
            ):
                kod = getattr(d.args[1], "value", None)
                if not uygun(kod, d.args[2].value):
                    sizanlar.append(f"{yol.name}:{d.lineno} {kod} -> {d.args[2].value[:50]}")
            # (2) arama tablosu ucluleri
            if isinstance(d, ast.Tuple) and len(d.elts) == 3:
                a, b, c = d.elts
                sabit = all(isinstance(x, ast.Constant) for x in (a, b, c))
                if (
                    sabit
                    and isinstance(a.value, int)
                    and 400 <= a.value < 600
                    and isinstance(b.value, str)
                    and isinstance(c.value, str)
                    and not uygun(b.value, c.value)
                ):
                    sizanlar.append(f"{yol.name}:{d.lineno} [tablo] {b.value} -> {c.value[:50]}")

    assert not sizanlar, "katalogsuz hata metni:\n" + "\n".join(sizanlar)


def test_kamera_url_hatasi_veri_tasir():
    """Dogrulayici METIN degil VERI firlatir; cumle katalogdan uretilir."""
    import pytest as _pytest

    from app.schemas import UrlTurUyusmazligi, dogrula_url_tur

    with _pytest.raises(UrlTurUyusmazligi) as ex:
        dogrula_url_tur("http://x/y.m3u8", "rtsp")
    assert ex.value.tur == "rtsp"
    assert ex.value.semalar  # sema listesi VERI olarak tasinir
    # Katalog metni istegin dilinde uretilebiliyor.
    metin = hata_metni(
        "kamera_url_semasi", "de", {"tur": ex.value.tur, "semalar": "rtsp://"}
    )
    assert "rtsp" in metin and "{" not in metin


# --------------------------------------------------------------------------- #
# 4. Gercek uctan (calisan API)
# --------------------------------------------------------------------------- #
def test_404_metni_dile_gore_degisir(client):
    """Ayni istek, farkli `Accept-Language` -> farkli metin, AYNI kod."""
    yol = "/units/00000000-0000-0000-0000-000000000000"
    metinler = {}
    for dil in DILLER:
        r = client.get(yol, headers={"Accept-Language": dil})
        # Token yok -> 401; hata zarfi yine dile gore uretilir.
        zarf = r.json()["error"]
        metinler[dil] = zarf["message"]
        assert zarf["code"] in {"unauthorized", "not_found"}
    # KOD dilden bagimsiz, METIN degil: 7 dilin en az 6'si birbirinden farkli.
    assert len(set(metinler.values())) >= 6, metinler
    for dil, metin in metinler.items():
        assert metin.strip(), dil
        if dil != "tr":
            assert not TR_HARF.search(metin), f"{dil}: {metin}"


def test_baslik_yoksa_turkce(client):
    r = client.get("/units/00000000-0000-0000-0000-000000000000")
    assert r.json()["error"]["message"] == METINLER["kimlik_dogrulama_gerekli"]["tr"]


def test_bolge_eki_ve_q_zinciri(client):
    """`ar-SA` -> `ar`; desteklenmeyen dil zincirde atlanir."""
    yol = "/units/00000000-0000-0000-0000-000000000000"
    ar = client.get(yol, headers={"Accept-Language": "ar-SA,ar;q=0.9"})
    assert ar.json()["error"]["message"] == METINLER["kimlik_dogrulama_gerekli"]["ar"]
    de = client.get(yol, headers={"Accept-Language": "it,de;q=0.7,tr;q=0.1"})
    assert de.json()["error"]["message"] == METINLER["kimlik_dogrulama_gerekli"]["de"]


def _giris(client, world) -> dict[str, str]:
    cred = world["admin_a"]
    r = client.post(
        "/auth/login",
        json={
            "tenant_slug": world["slug_a"],
            "email": cred["email"],
            "password": cred["password"],
        },
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_dogrulama_hatasi_ust_mesaji_cevrilir(client, world):
    """422 zarfinin UST mesaji cevrilir; `details` teknik kalir."""
    r = client.post(
        "/units",
        headers={**_giris(client, world), "Accept-Language": "ru"},
        json={"no": None},
    )
    assert r.status_code == 422
    zarf = r.json()["error"]
    assert zarf["code"] == "validation_error"
    assert zarf["message"] == METINLER["istek_govdesi_gecersiz"]["ru"]
    assert zarf["details"], "alan ayrintisi kayboldu"


def test_is_kurali_hatasi_cevrilir(client, world):
    """Gercek bir 409: ayni blok etiketi iki kez."""
    bas = _giris(client, world)
    ad = "I18NBLOK"
    client.post("/blocks", headers=bas, json={"ad": ad})
    r = client.post("/blocks", headers={**bas, "Accept-Language": "es"}, json={"ad": ad})
    assert r.status_code == 409
    assert r.json()["error"]["code"] == "conflict"
    assert (
        r.json()["error"]["message"]
        == METINLER["blok_etiketi_zaten_kayitli"]["es"]
    )
