"""(P134) GUNLUK YAPILANDIRMASI — INFO satirlari GORUNSUN, ama KVKK'yi bozmadan.

SORUN (olculdu, varsayilmadi): uygulamada hicbir logging yapilandirmasi
yoktu. Python kok logger'inin varsayilani WARNING oldugu icin
`logger.info(...)` cagrilarinin HICBIRI cikmiyordu — canli konteynerde
`scheduler.notify` logger'i icin `isEnabledFor(INFO)` **False** donuyor ve
`/public/tanitim-iletisim`e atilan bir istek 201 dondugu hâlde yazdigi
INFO satiri docker gunluklerinde **0** kez goruunuyordu.

Bedeli davranis degil TESHIS: push gonderiminin ne yaptigini soyleyen tek
kayit (`EXTERNAL_NOTIFY`) gorunmuyordu ve "push gitti mi" sorusu
cevapsizdi. Ertelenmis isti (Kerem: "simdilik kalsin, not et").

--------------------------------------------------------------------------
ASIL MESELE — INFO'YU ACMAK, PII'YI DE ACIYORDU
--------------------------------------------------------------------------
Duzeltmeyi yazarken cikti: gorunur hâle gelecek INFO satirlarinin ucu
KISISEL VERI tasiyor.

    mesajlasma.py  [SMS/log] <telefon> <- <mesaj govdesi>
    mesajlasma.py  [E-POSTA/log] <e-posta> <- <konu> | <govde>
    notify.py      EXTERNAL_NOTIFY: <kimlik> {'ad': ..., 'daire': ...}

Yani "INFO'yu ac" isini duz yapmak, telefon numaralarini, e-posta
adreslerini, mesaj govdelerini ve daire/ad alanlarini konteyner
gunluklerine yazmaya baslardi. Bu depoda `audit_log`un gecelik saklama ve
anonimlestirme gorevi VAR (KVKK turu); konteyner gunlugunun boyle bir
gorevi YOK. Teshis kazanmak icin denetimsiz bir kisisel veri deposu
uretmek, kazanandan pahali olurdu.

KARAR: gorunurluk ACILIR, degerler MASKELENIR.
  * Alici kimligi (telefon/e-posta) maskelenir — operator "hangi kayda
    gitti"yi anlar, numarayi okuyamaz.
  * Mesaj GOVDESI varsayilan olarak YAZILMAZ; yerine uzunlugu yazilir.
  * Bildirim parametreleri ANAHTARLARIYLA yazilir, degerleriyle degil.

`LOG_PII=1` bunlarin hepsini acar. Yerel gelistirmede mesaj metnini
gormek gerekebilir; ama bu ACIK bir secim olmali ve varsayilan
GUVENLI taraf olmali.
"""
from __future__ import annotations

import logging
import os
import sys
from typing import Any, Mapping

#: Gunluk seviyesi (`LOG_LEVEL`). Varsayilan INFO — bu modulun varlik
#: sebebi zaten INFO satirlarinin gorunmemesiydi.
_VARSAYILAN_SEVIYE = "INFO"

#: Gurultulu kutuphaneler: kendi INFO'lari uygulamanin kaydini bogar.
#: WARNING'de tutulur; gerekirse `LOG_LEVEL=DEBUG` ile hepsi acilir.
_SESSIZ_KUTUPHANELER = (
    "httpx",
    "httpcore",
    "asyncio",
    "botocore",
    "urllib3",
    "sqlalchemy.engine",
)


def pii_acik() -> bool:
    """`LOG_PII=1` ise ham degerler yazilir (yerel gelistirme icin).

    Ortam degiskeni HER CAGRIDA okunur; testin degeri degistirip
    davranisi olcebilmesi icin onbelleklenmez.
    """
    return os.getenv("LOG_PII", "").strip().lower() in {"1", "true", "yes"}


def maskele_kimlik(deger: str | None) -> str:
    """Telefon/e-posta gibi DOGRUDAN tanimlayicilari maskeler.

    Amac gunlugu ise yaramaz kilmak DEGIL, tanimlayiciyi okunamaz
    kilmaktir: operator iki satirin ayni kisiye mi gittigini goremez ama
    "hangi kanaldan, hangi bicimde" sorusunu yanitlayabilir.

        +905321234567     -> +90******4567
        ornek@site.com    -> o****@site.com

    E-postada ALAN ADI korunur: "hangi kuruma gitti" teshis icin gerekli
    ve alan adi tek basina bir kisiyi tanimlamaz.
    """
    if pii_acik():
        return deger or "-"
    if not deger:
        return "-"
    d = deger.strip()
    if "@" in d:
        yerel, _, alan = d.partition("@")
        bas = yerel[:1] if yerel else ""
        return f"{bas}{'*' * max(len(yerel) - 1, 1)}@{alan}"
    # Telefon/kimlik: bas 3 + son 4 gorunur, arasi maskeli.
    if len(d) <= 4:
        return "*" * len(d)
    bas, son = d[:3], d[-4:]
    return f"{bas}{'*' * max(len(d) - 7, 1)}{son}"


def govde_ozeti(govde: str | None) -> str:
    """Mesaj GOVDESI yerine uzunlugu — govde her seyi tasiyabilir.

    Bir SMS govdesi tahsilat tutari, daire numarasi ya da bir sikayet
    metni olabilir. Teshis icin gereken sey "gonderildi mi ve bos mu
    degil mi"dir; metnin kendisi degil.
    """
    if pii_acik():
        return govde or ""
    return f"<{len(govde or '')} karakter>"


def guvenli_alanlar(params: Mapping[str, Any] | None) -> Any:
    """Bildirim parametrelerini ANAHTARLARIYLA yazar, degerleriyle degil.

    `push_metinleri` sablonlarindaki alanlar arasinda `ad` ve `daire` var;
    ikisi de bir haneyi isaret eder. Operatorun ihtiyaci "hangi bildirim,
    hangi alanlarla kuruldu"dur — degerler kaydin kendisinde (`notification`
    tablosu) zaten duruyor ve orasi KVKK saklama gorevine BAGLI.
    """
    if pii_acik():
        return dict(params or {})
    return sorted((params or {}).keys())


def yapilandir(seviye: str | None = None) -> None:
    """Kok logger'i kur — uvicorn'un KENDI kaydini bozmadan.

    `force=True` bilincli: uvicorn (ve bazi kutuphaneler) ice aktarilirken
    kok logger'a handler takmis olabilir ve iki handler AYNI satiri iki kez
    yazar. Tek bir handler birakiliyor.

    UVICORN'UN KENDI LOGGER'LARINA DOKUNULMAZ (`uvicorn`, `uvicorn.access`):
    onlarin bicimi ve seviyesi uvicorn'un yapilandirmasindan gelir; ustune
    yazmak erisim gunlugunu sessizce degistirirdi.
    """
    ham = (seviye or os.getenv("LOG_LEVEL") or _VARSAYILAN_SEVIYE).upper()
    # Gecersiz bir deger gunlugu SESSIZCE kapatmasin: bilinmiyorsa
    # varsayilana dusulur ve durum bir kez soylenir.
    cozulen = getattr(logging, ham, None)
    gecersiz = not isinstance(cozulen, int)
    if gecersiz:
        cozulen = logging.INFO

    logging.basicConfig(
        level=cozulen,
        stream=sys.stdout,
        format="%(asctime)s %(levelname)-7s %(name)s | %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S",
        force=True,
    )
    for ad in _SESSIZ_KUTUPHANELER:
        logging.getLogger(ad).setLevel(max(cozulen, logging.WARNING))

    if gecersiz:
        logging.getLogger(__name__).warning(
            "LOG_LEVEL degeri taninmadi (%r) — INFO kullaniliyor", ham
        )
    if pii_acik():
        # Bu bir GELISTIRME anahtaridir; uretimde acik kalmasi kisisel
        # veriyi gunluge yazar. Acik oldugu her acilista SOYLENIR.
        logging.getLogger(__name__).warning(
            "LOG_PII ACIK — gunluklere ham kisisel veri yaziliyor. "
            "Uretimde KAPALI olmali."
        )
