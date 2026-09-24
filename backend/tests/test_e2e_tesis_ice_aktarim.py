"""(E2E 2026-09 / TESIS-10) Ice aktarimda sessiz atlama + onizleme != sonuc.

OLCULEN (kisi turu, 9 satir): baska sakinin telefonu/e-postasi olan
satirlar (farkli kisi, farkli daire) "zaten var" SAYACINA satir no'suz
dustu; dosya ici ayni telefon kuru kosumda gorulmedi. Onizleme
`olusan:3, atlanan:2`, gercek aktarim `olusan:2, atlanan:3`.
"""
from __future__ import annotations

import uuid


def _giris(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _satir(no, **degerler):
    return {"satir_no": no, "degerler": degerler}


def _aktar(client, h, tur, satirlar, dogrula=False, atla=False):
    govde = {"satirlar": satirlar, "yalniz_dogrula": dogrula,
             "dosya_adi": "e2e.xlsx", "sorunlulari_atla": atla}
    r = client.post(f"/ice-aktarim/{tur}", headers=h, json=govde)
    assert r.status_code == 201, r.text
    return r.json()


def _eposta():
    return f"e2e-ia-{uuid.uuid4().hex[:10]}@ornek.com"


def _tel():
    return f"+9053{uuid.uuid4().int % 10**8:08d}"


def _ozet(r):
    return (r["olusan"], r["atlanan"], r["hatali"],
            sorted((x["satir_no"], x["alan"]) for x in r["hatalar"]),
            sorted(x["satir_no"] for x in r.get("atlananlar", [])))


def test_dosya_ici_yinelenen_telefon_HATA_ve_onizleme_esit_sonuc(client, world):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    tel = _tel()
    satirlar = [
        _satir(1, ad="Bir", eposta=_eposta(), telefon=tel),
        _satir(2, ad="Iki", eposta=_eposta(), telefon=tel),
    ]
    on = _aktar(client, h, "kisi", satirlar, dogrula=True)
    assert on["hatali"] == 1, on
    assert on["hatalar"][0]["satir_no"] == 2
    assert on["hatalar"][0]["alan"] == "telefon"
    assert "1" in on["hatalar"][0]["hata"]  # ilk satiri soyler
    son = _aktar(client, h, "kisi", satirlar, atla=True)
    assert _ozet(on) == _ozet(son), (on, son)
    assert son["olusan"] == 1


def test_dosya_ici_yinelenen_eposta_buyuk_kucuk_harf(client, world):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    e = _eposta()
    r = _aktar(client, h, "kisi", [
        _satir(1, ad="Bir", eposta=e),
        _satir(2, ad="Iki", eposta=e.upper()),
    ], dogrula=True)
    assert r["hatali"] == 1 and r["hatalar"][0]["alan"] == "eposta", r


def test_baska_kisinin_epostasi_HATA_ayni_kisi_ATLANIR_satir_nosuyla(client, world):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    e = _eposta()
    ilk = _aktar(client, h, "kisi", [_satir(1, ad="Asil Kisi", eposta=e)])
    assert ilk["olusan"] == 1, ilk

    # Ayni kisi (ayni ad) -> idempotent atlama, SEBEBIYLE.
    tekrar = _aktar(client, h, "kisi", [_satir(7, ad="Asil Kisi", eposta=e)])
    assert tekrar["atlanan"] == 1 and tekrar["hatali"] == 0, tekrar
    assert tekrar["atlananlar"][0]["satir_no"] == 7
    assert tekrar["atlananlar"][0]["hata"]

    # Farkli ad, ayni e-posta -> HATA (eskiden sessiz "zaten var").
    baska = _aktar(client, h, "kisi", [_satir(9, ad="Baska Biri", eposta=e)],
                   dogrula=True)
    assert baska["hatali"] == 1 and baska["atlanan"] == 0, baska
    assert baska["hatalar"][0]["satir_no"] == 9
    assert baska["hatalar"][0]["alan"] == "eposta"


def test_daire_satirinda_ayni_yeni_blok_bir_kez_sayilir(client, world):
    """Kuru kosum yeni blogu her satirda "olusacak" sayiyordu."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    blok = "N" + uuid.uuid4().hex[:4].upper()
    satirlar = [
        _satir(1, blok=blok, daire_no=f"{blok}-1"),
        _satir(2, blok=blok, daire_no=f"{blok}-2"),
        _satir(3, blok=blok, daire_no=f"{blok}-2"),  # dosyada yinelenen daire
    ]
    on = _aktar(client, h, "daire", satirlar, dogrula=True)
    son = _aktar(client, h, "daire", satirlar)
    assert _ozet(on) == _ozet(son), (on, son)
    # 1 blok + 2 daire; 3. satir atlanan (satir no'suyla).
    assert son["olusan"] == 3, son
    assert [x["satir_no"] for x in son["atlananlar"]] == [3]


def test_daire_satirinda_ayni_daireye_iki_malik_onizlemede_de_hata(client, world):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    blok = "M" + uuid.uuid4().hex[:4].upper()
    satirlar = [
        _satir(1, blok=blok, daire_no=f"{blok}-1", sakin_ad="Malik Bir",
               sakin_eposta=_eposta(), rol_tipi="malik"),
        _satir(2, blok=blok, daire_no=f"{blok}-1", sakin_ad="Malik Iki",
               sakin_eposta=_eposta(), rol_tipi="malik"),
    ]
    on = _aktar(client, h, "daire", satirlar, dogrula=True)
    assert on["hatali"] == 1 and on["hatalar"][0]["satir_no"] == 2, on
    son = _aktar(client, h, "daire", satirlar, atla=True)
    assert _ozet(on) == _ozet(son), (on, son)
