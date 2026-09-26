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


#: (P248 §3b) LIKE/ILIKE KACIS KARAKTERI — her cagri `escape=LIKE_KACIS`
#: (SQLAlchemy) ya da `ESCAPE '\'` (ham SQL) ile ACIKCA verir. PostgreSQL'in
#: varsayilani da ters bolu ama varsayilana dayanmak `standard_conforming_
#: strings` ya da baska bir surucu altinda sessizce degisebilir.
LIKE_KACIS = "\\"


def like_kacis(metin: str) -> str:
    """(P248 §3b) Kullanici metnini LIKE icin LITERAL yapar.

    `%` (her sey), `_` (tek karakter) ve kacis karakterinin kendisi
    kacislanir. Olculen kusur: `/users?q=%` ve `/users?q=_` TUM
    kullanicilari donduruyordu — arama "yuzde isareti gecen adlar" degil
    "hepsi" demekti. Ayni kusur dukkan isletme/mahalle aramasi ve panel
    tesis aramasinda da vardi.

    SQL ENJEKSIYONU ICIN DEGIL: deger zaten baglama degiskeni olarak gider
    (`' OR 1=1 --` duz metin olarak aranir). Bu yalniz JOKER anlamini
    kaldirir.
    """
    return (
        metin.replace(LIKE_KACIS, LIKE_KACIS * 2)
        .replace("%", LIKE_KACIS + "%")
        .replace("_", LIKE_KACIS + "_")
    )


def like_icerir(metin: str) -> str:
    """`%<kacisli metin>%` — "icinde gecer" kalibi."""
    return f"%{like_kacis(metin)}%"


def like_icerir_bos_degilse(metin: str | None) -> str | None:
    """(P248 §3b) KATLANMIS sorgu icin: bos ise `None` (kosul hic eslemez).

    Olculen kusur: slug'a katlanan sorgu (`slugla("%")`, `_ascii_katla("_")`)
    alfanumerik olmayan her seyi sildigi icin BOS kaliyordu ve `%%` kalibi
    TUM satirlari esliyordu — `%` kacislansa bile slug kolu her seyi
    donduruyordu (`/tenants?q=%` 4042 tesis, `/dukkan/isletme-ara?q=%`
    5286 isletme; canli olculdu). `NULL` ile `LIKE` NULL doner, yani o kol
    OR icinde hicbir satiri eklemez.
    """
    return like_icerir(metin) if metin else None


def tr_kalip(metin: str) -> str:
    """`LIKE` kalibi: katlanmis + `%`/`_` kacisli (kullanici `%` yazarsa
    her seyi eslestirmesin)."""
    return like_icerir(tr_katla(metin))
