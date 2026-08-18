"""(P171) ZENGIN METIN TEMIZLEME — BEYAZ LISTE, YAZMA ANINDA.

===========================================================================
NEDEN SUNUCUDA VE NEDEN YAZMA ANINDA
===========================================================================
P170'te ayni kusur ISTEMCIDE kapatilmisti: govde duz metne cevriliyordu.
Guvenliydi ama bedeli agirdi — KVKK metinleri baslikli ve maddeli
BELGELERDIR; bicimlendirmeyi atmak okunabilirligi dusurdu. Ustelik cozum
tek bir istemciye aitti: mobil ayni govdeyi BAGIMSIZ ciziyor ve orada
ayni korumayi ikinci kez yazmak gerekirdi.

Temizlik YAZMA aninda yapilir, OKUMA aninda degil:

  * Veritabaninda TEMIZ veri durur. Okuma anindaki temizlik, kirli veriyi
    saklayip her okuyanin dogru davranmasina GUVENMEK olurdu — yeni bir
    istemci (mobil, rapor, e-posta) o adimi atladiginda korumasiz kalirdi.
  * Maliyeti bir kez odenir. Bir metin bir kez yazilir, binlerce kez
    okunur.
  * Kayit denetlenebilir olur: veri tabanindaki deger, kullaniciya
    gosterilen degerdir.

===========================================================================
BEYAZ LISTE — KARA LISTE DEGIL
===========================================================================
Kara liste ("sunlari at") kaybetmeye mahkumdur: yarin cikacak bir
oznitelik ya da bir ayristirici tuhafligi listede olmaz. Beyaz liste
("yalniz sunlara izin") bilinmeyen her seyi kapatir.

`on*` oznitelikleri, `style`, `script`, `iframe`, `svg`, `img`, `object`,
`embed` LISTEDE YOK — dolayisiyla atilirlar. `javascript:` ve `data:`
semalari da listede degil.

`img` BILINCLI OLARAK YOK: `onerror` en yaygin vektor ve bir yasal metnin
gorsele ihtiyaci yok. Gerekirse ayri bir karar olarak, `src` sema
kisitiyla acilir.

===========================================================================
ELLE TEMIZLEYICI YAZILMADI
===========================================================================
HTML ayristirmanin koseleri (mutasyon XSS, ic ice yorumlar, eksik
kapanis etiketleri, `<svg><style>` gecisleri) tam olarak bu tur
kutuphanelerin varlik sebebi. `nh3` Rust `ammonia`nin baglayicisidir ve
`bleach`in yerini almistir (bleach 2023'te bakimdan cikti ve kendi
belgesinde nh3'e yonlendiriyor).

===========================================================================
DUZ METIN ALANLARI BURADAN GECMEZ — VE BU BILINCLI
===========================================================================
Duyuru govdesi, etkinlik aciklamasi, karar defteri metni gibi alanlar
HTML DEGILDIR: duz metin girdisiyle yazilir, duz metin olarak cizilir.
Onlari bir HTML temizleyicisinden gecirmek KORUMAZ, BOZAR — "5 < 10"
yazan bir duyuru `5 &lt; 10` olarak saklanir ve kullaniciya oyle gorunur.

Duz metin alanlarinin korumasi baska bir yerdedir ve zaten kuruludur:
HICBIR istemci onlari HTML olarak cizmez. Bu, `tests/test_temizleme.py`
ve web'deki `duz-metin-alanlari` kilidiyle olculuyor.
"""
from __future__ import annotations

import nh3

#: Izin verilen etiketler. `img`/`svg`/`iframe` YOK (bkz. modul basligi).
IZINLI_ETIKETLER: set[str] = {
    "p", "br", "strong", "em", "u", "s",
    "h1", "h2", "h3", "h4",
    "ul", "ol", "li",
    "a",
    "blockquote", "hr",
}

#: Etiket -> izinli oznitelikler. `a` disinda HICBIR etikette oznitelik yok.
IZINLI_OZNITELIKLER: dict[str, set[str]] = {"a": {"href", "title"}}

#: Izinli URL semalari. `javascript:` ve `data:` LISTEDE DEGIL, yani
#: reddedilir — `data:text/html;base64,...` de bir betik tasiyicisidir.
IZINLI_SEMALAR: set[str] = {"http", "https", "mailto"}


def zengin_temizle(govde: str) -> str:
    """Zengin metin govdesini beyaz listeyle temizler.

    `link_rel="noopener noreferrer"`: temizlenmis bir baglanti hala
    `target="_blank"` ile acilabilir ve acilan sayfa `window.opener`
    uzerinden bizi yonlendirebilirdi (tabnabbing). Oznitelik listemizde
    `target` yok, ama `rel` bedava bir siki sikilastirma.
    """
    return nh3.clean(
        govde,
        tags=IZINLI_ETIKETLER,
        attributes={k: set(v) for k, v in IZINLI_OZNITELIKLER.items()},
        url_schemes=IZINLI_SEMALAR,
        link_rel="noopener noreferrer",
        # Yorumlar ATILIR: `<!--[if IE]><script>` gibi kosullu yorumlar
        # bazi ayristiricilarda CALISIR.
        strip_comments=True,
    )
