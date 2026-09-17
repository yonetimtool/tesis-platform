"""(P240 §1) PANIK BUTONU — kim basabilir, kime gider, ne zaman gider.

===========================================================================
UC AYRI BUTON, CUNKU ALARM YANLIS KISIYE GIDERSE ISE YARAMAZ
===========================================================================
Tek bir "panik" dugmesi, uc farkli olayi tek bir alici kumesine
gonderirdi:

  * sakin           — evde acil durum/saglik/tehdit
  * guvenlik        — saldiri, yangin, izinsiz giris
  * yonetici_anons  — tahliye, gaz kacagi, deprem (TUM siteye)

Tahliye anonsunu guvenlik ekibine gondermek ya da bir sakinin saglik
acilini TUM siteye duyurmak, ikisi de kusur olurdu.

===========================================================================
KIM TETIKLEYEBILIR — ve neden yonetici (a)'yi tetikleyemez
===========================================================================
`sakin` tipi DAIRE bilgisiyle anlamlidir ("hangi daireye gidilecek").
Yoneticinin dairesi yoktur; onun tetikledigi bir "sakin panigi" alicilara
gidecek adresi OLMAYAN bir alarm olurdu. Yonetici sahada bir saldiri
gorurse dogru dugme `guvenlik`tir ve o ona ACIKTIR.

Yani "yonetici hepsini gorur mu" sorusunun yaniti: IKISINI gorur
(guvenlik + anons), ucunu degil. Gorunurluk YETKIDEN turer, ayri bir
liste tutulmaz.

===========================================================================
ALICI KUMELERI
===========================================================================
`sakin`          -> guvenlik ekibi + amir + yonetim
`guvenlik`       -> DIGER guvenlik + amir + yonetim (tetikleyen haric)
`yonetici_anons` -> TESISTEKI HERKES (denetci dahil degil: salt-okuma
                    mali gozetim rolu, sahada degil)

Tetikleyen kendi alarminin alicisi DEGILDIR: kendi telefonunda calan
alarm, ona yeni bir bilgi vermez ve "kim gordu" olcusunu kirletirdi.
"""
from __future__ import annotations

import datetime as dt
from typing import Final

#: Iptal penceresi — SANIYE.
#:
#: 5 sn: yanlislikla basan kisinin fark edip geri almasina yeter, gercek
#: acil durumda ise KAYBEDILEN sure kabul edilebilir siniri asmaz.
#: Daha uzun bir pencere (orn. 15 sn) alarmi gec baslatir; daha kisa
#: (2 sn) ise "basmadan once dusun" demenin baska yolu olur.
IPTAL_PENCERESI_SN: Final[int] = 5

#: Tetikleyebilen roller — tip basina.
TETIKLEYEBILIR: Final[dict[str, frozenset[str]]] = {
    "sakin": frozenset({"resident"}),
    "guvenlik": frozenset(
        {"security", "guvenlik_amiri", "tesis_gorevlisi", "yonetici", "admin"}
    ),
    "yonetici_anons": frozenset({"yonetici", "admin"}),
}

#: Alici ROLLERI — tip basina. `yonetici_anons` ozel: herkes.
ALICI_ROLLERI: Final[dict[str, frozenset[str]]] = {
    "sakin": frozenset({"security", "guvenlik_amiri", "yonetici", "admin"}),
    "guvenlik": frozenset({"security", "guvenlik_amiri", "yonetici", "admin"}),
    "yonetici_anons": frozenset(
        {"resident", "security", "guvenlik_amiri", "tesis_gorevlisi",
         "yonetici", "admin"}
    ),
}

#: Alarm LISTESINI gorebilen roller (takip ekrani).
#:
#: `resident` LISTEYI GORMEZ: baska dairelerin acil durumlari kisisel
#: veridir ve sakinin bilmesi gereken bir sey degildir. Sakin YALNIZ
#: kendi acmasi ve kendisine gonderilen anonslari gorur (uc ayri suzgec).
LISTE_ROLLERI: Final[frozenset[str]] = frozenset(
    {"security", "guvenlik_amiri", "yonetici", "admin"}
)


def tetikleyebilir_mi(rol: str, tip: str) -> bool:
    return rol in TETIKLEYEBILIR.get(tip, frozenset())


def tetiklenebilir_tipler(rol: str) -> list[str]:
    """Bu rolun GOREBILECEGI panik dugmeleri — arayuz bunu cizer."""
    return [t for t, roller in TETIKLEYEBILIR.items() if rol in roller]


def aski_aktif(bitis: dt.datetime | None, simdi: dt.datetime | None = None) -> bool:
    """Panik yetkisi ASKIDA mi?

    NULL ya da GECMIS = yetki acik. Askinin kendisi sureli; bu fonksiyon
    "suresi dolmus aski" ile "aski yok"u AYNI sayar — ikisi de aciktir ve
    ayirmak, bitmis bir askiyi elle temizlemeyi zorunlu kilardi.
    """
    if bitis is None:
        return False
    simdi = simdi or dt.datetime.now(dt.timezone.utc)
    if bitis.tzinfo is None:
        bitis = bitis.replace(tzinfo=dt.timezone.utc)
    return bitis > simdi


#: Ayni kisinin AYNI TIPTE acik alarmi varken tekrar basmasi YENI ALARM
#: URETMEZ — var olani yeniden duyurur.
#:
#: SUISTIMAL KISITI BOYLE KURULDU ve KASITLI olarak "reddetme" DEGIL:
#: gercek bir acil durumda ikinci kez basan kisi, ilkinin duyulmadigini
#: dusunuyordur. Istegi REDDETMEK ("cok sik bastiniz") tam da o anda
#: alarmi susturmak olurdu. Tekrar duyurmak hem kullanicinin niyetini
#: karsilar hem de yirmi ayri alarm satiri uretmez.
TEKRAR_DUYURU_ARALIGI_SN: Final[int] = 30
