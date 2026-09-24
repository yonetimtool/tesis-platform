"""(E2E 2026-09 / TESIS-09) TURKCE HARF KATLAMALI ARAMA.

===========================================================================
OLCULEN KUSUR
===========================================================================
`/units/ara?q=İkinci` bos donuyordu (`ikinci` buluyordu); `/residents?q=kiraci`
"Can Kiracı"yi bulmuyordu. Iki ayri kok neden:
  * Python `"İ".lower()` = `"i̇"` (i + BIRLESIK NOKTA, U+0307) — kalip
    hicbir DB degeriyle eslesmez.
  * Postgres `ilike`/`lower` ı<->i ve İ<->I'yi AYNI harf saymaz (Turkce
    buyuk/kucuk kurali yerel ayara bagli, DB `C`/`en_US` ile kurulu).

===========================================================================
KARAR: IKI YANI DA AYNI TABLOYLA KATLA
===========================================================================
Klavyesinde Turkce harf olmayan (ya da acele eden) kullanici "kiraci",
"ozturk", "sahin" yazar. Bu yuzden katlama yalniz buyuk/kucuk harf degil,
Turkce harfleri ASCII karsiligina indirir (ç->c, ğ->g, ı/İ/I->i, ö->o,
ş->s, ü->u). Ayni tablo hem sorguya (Python) hem sutuna (SQL `translate`)
uygulanir; boylece iki taraf asla farkli kurala gore katlanmaz.

`translate` LOWER'DAN ONCE calisir: `lower('İ')` yerel ayara gore `i̇`
ya da `İ` donebilir; once ASCII'ye indirmek bu belirsizligi ortadan kaldirir.
`unaccent` eklentisi KULLANILMADI: goc + eklenti yetkisi gerektirir ve
yalniz bu alti harf icin gereksiz.
"""
from __future__ import annotations

from sqlalchemy import func
from sqlalchemy.sql.elements import ColumnElement

_KAYNAK = "ÇçĞğİIıÖöŞşÜü"
_HEDEF = "ccggiiioossuu"
_TABLO = str.maketrans(_KAYNAK, _HEDEF)


def tr_katla(metin: str) -> str:
    """Python tarafi: Turkce harfleri ASCII'ye indir, sonra kucult."""
    return metin.translate(_TABLO).lower()


def tr_katla_sql(sutun) -> ColumnElement:
    """SQL tarafi: `lower(translate(sutun, ...))` — `tr_katla` ile AYNI tablo."""
    return func.lower(func.translate(sutun, _KAYNAK, _HEDEF))


def tr_kalip(metin: str) -> str:
    """`LIKE` kalibi: katlanmis + `%`/`_` kacisli (kullanici `%` yazarsa
    her seyi eslestirmesin)."""
    k = tr_katla(metin).replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"%{k}%"
