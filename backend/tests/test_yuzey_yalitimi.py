"""YUZEY YALITIMI — platform ucu tesis rolune KAPALI mi? (P126.7)

NEDEN AYRI BIR OLCUM: `test_yetki_kapsam.py` 318 satirlik matrisi kilitliyor
ama o bir DEGISIKLIK DEDEKTORUDUR — "bugun ne varsa yarin da o olsun" der,
"ne OLMASI gerektigini" soylemez. Kilit bir gun bilincsizce guncellenirse
(diff'e bakip "eh, olur" demek yeterlidir) urun kurali sessizce kaybolur.

Bu dosya KURALI yazar ve gerekcesiyle birlikte kilitler:

  panel.yönetiyor.com = platform sahibinin yuzeyi; app.yönetiyor.com = tesis
  rollerinin yuzeyi (docs/platform-tesis-ayrimi.md, Kerem'in urun karari).

Iddia: bir TESIS rolu (yonetici/security/tesis_gorevlisi/resident/
guvenlik_amiri) platform uclarinin HICBIRINE erisemez. Panel menusunu
gizlemek bunu saglamaz — menu bir yetkilendirme degildir; adres cubugu ve
`curl` menuye bakmaz. Zorlama SUNUCUDADIR ve olculen sey odur.

VERI KAYNAGI: `tests/yetki/rol-matrisi.txt` — 6 rolun her uca gercek istekle
surulmesiyle KODDAN uretilir. Yani burada okunan sey bir belge degil,
olculmus davranistir. (Uretimi: test_yetki_kapsam.py::test_rol_matrisi_kilidi)

WEB TARAFINDAKI IKIZI: `admin-web/tests/rol-menusu.test.ts` ayni dosyayi
okur ve menude gosterilen her rotanin o rolce ACILABILIR oldugunu dogrular.
Ikisi birlikte iki yonu kapatir: sunucu fazlasini VERMEZ, arayuz
acilamayacak olani GOSTERMEZ.
"""
from __future__ import annotations

from pathlib import Path

import pytest

KILIT = Path(__file__).resolve().parent / "yetki" / "rol-matrisi.txt"

#: PLATFORM uclari — docs/platform-tesis-ayrimi.md §1a'daki 14 uc.
#: Hepsi TESISLER-ARASI ya da platformun kendi isidir; tek bir tesisin
#: gunluk isi (aidat, vardiya, sayac) bu listede YOKTUR ve olmamalidir.
PLATFORM_UCLARI = [
    ("GET", "/admin/overview"),
    ("GET", "/audit"),
    ("GET", "/devices"),
    ("GET", "/support/all"),
    ("PATCH", "/support/{ticket_id}"),
    ("GET", "/integrations/anpr/keys"),
    ("POST", "/integrations/anpr/keys"),
    ("DELETE", "/integrations/anpr/keys/{key_id}"),
    ("GET", "/tenants"),
    ("POST", "/tenants"),
    ("GET", "/tenants/{tenant_id}"),
    ("PATCH", "/tenants/{tenant_id}"),
    ("DELETE", "/tenants/{tenant_id}"),
    ("PATCH", "/tenants/{tenant_id}/yonetici"),
    ("POST", "/tenants/{tenant_id}/yonetici/reset-credential"),
]

TESIS_ROLLERI = (
    "yonetici",
    "security",
    "tesis_gorevlisi",
    "resident",
    "guvenlik_amiri",
)


def _matris() -> tuple[list[str], dict[tuple[str, str], list[str]]]:
    satirlar = KILIT.read_text(encoding="utf-8").splitlines()
    baslik = next(s for s in satirlar if s.startswith("#"))
    roller = baslik.lstrip("#").split()
    tablo: dict[tuple[str, str], list[str]] = {}
    for s in satirlar:
        if not s.strip() or s.startswith("#"):
            continue
        p = s.split()
        tablo[(p[0], p[1])] = p[2:]
    return roller, tablo


ROLLER, TABLO = _matris()


def test_kilit_okunabiliyor() -> None:
    """Olcum bosa dusmesin: kilit gercekten dolu ve 6 rol tasiyor."""
    assert len(TABLO) > 300, f"kilit beklenenden kucuk: {len(TABLO)}"
    for rol in TESIS_ROLLERI + ("admin",):
        assert rol in ROLLER, rol


@pytest.mark.parametrize(("metot", "yol"), PLATFORM_UCLARI)
def test_platform_ucu_tesis_roluna_kapali(metot: str, yol: str) -> None:
    """Hicbir tesis rolu platform ucuna erisemez (403)."""
    satir = TABLO.get((metot, yol))
    assert satir is not None, (
        f"{metot} {yol} matriste YOK — uc yeniden adlandirildiysa bu liste "
        "guncellenmeli; sessizce atlanmasi olcumu bosa dusururdu."
    )
    for rol in TESIS_ROLLERI:
        sonuc = satir[ROLLER.index(rol)]
        assert sonuc == "RED", (
            f"{metot} {yol} icin {rol} = {sonuc} — TESIS rolu PLATFORM ucuna "
            "erisiyor. Bu bir yuzey sizintisidir: panel menusunu gizlemek "
            "yetmez, sunucu reddetmelidir."
        )


@pytest.mark.parametrize(("metot", "yol"), PLATFORM_UCLARI)
def test_platform_ucu_admine_acik(metot: str, yol: str) -> None:
    """Ters yon: kural 'herkese kapali' degil, 'yalniz platforma acik'.

    Bu olmadan yukaridaki test, ucu HERKESE kapatarak da yesillenirdi —
    yani platformun kendi ekranlarini kirmak testi gecirirdi.
    """
    satir = TABLO[(metot, yol)]
    assert satir[ROLLER.index("admin")] == "IZIN", f"{metot} {yol} admine kapali"


def test_tesis_ucu_matriste_tesis_rollerine_acik() -> None:
    """Tersine sizinti: tesisin gunluk isi platform-only'ye KAYMASIN.

    Ornek uclar bilincli olarak farkli modullerden secildi; hepsinin ortak
    ozelligi bir tesisin ICINDE calisan roller tarafindan kullanilmasidir.
    Biri bir gun `admin`e daraltilirsa o is panele geri tasinmis olur ve
    Kerem'in "tek bir sitenin islemleri panelde olmasin" karari bozulur.
    """
    beklenen = {
        ("GET", "/shifts"): "yonetici",
        ("GET", "/tasks"): "tesis_gorevlisi",
        ("GET", "/visitors"): "security",
        ("GET", "/me/dues"): "resident",
    }
    for (metot, yol), rol in beklenen.items():
        satir = TABLO[(metot, yol)]
        assert satir[ROLLER.index(rol)] == "IZIN", (
            f"{metot} {yol} artik {rol} rolune kapali — tesis isi platform "
            "tarafina kaymis olabilir."
        )
