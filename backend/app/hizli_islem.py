"""(P250 §6) HIZLI ISLEMLER — Ozet sayfasindaki kartin ROL KATALOGU.

Kullanici kartta hangi islemlerin gorunecegini ve sirasini secer; secim
HESAPTA durur (`app_user.pano_tercihi.hizli_islemler`, P182'nin "paneli
duzenle" kaydi) ve web ile mobil AYNI listeyi okur.

KATALOG SUNUCUDA: bir rolun YETKISI OLMADIGI islem secenek listesinde
cikmamali. Rol karari istemcide olsaydi iki yuzey (web/mobil) ayri ayri
karar verir ve ayrisabilirdi. Istemci her kimligi KENDI rotasina ve
ikonuna esler; buradaki tek bilgi "bu rol bu islemi gorebilir mi".

Her islemin web VE mobil karsiligi var (parite): yalniz bir yuzeyde
olan bir islem kataloga girmez.
"""
from __future__ import annotations

_YONETIM = frozenset({"admin", "yonetici"})

#: kimlik -> o islemi gorebilen roller. SIRA ANLAMLI: secenek listesi bu
#: sirayla gosterilir.
KATALOG: dict[str, frozenset[str]] = {
    "aidat": _YONETIM,
    "talep": _YONETIM,
    "duyuru": _YONETIM,
    "personel": _YONETIM,
    "sakin": _YONETIM,
    "gorev": _YONETIM | {"guvenlik_amiri"},
    # (P253 §B) YONETIM CIKARILDI: sunucu /visitors'i yoneticiye KAPATIR
    # (yonetici kayitlari yalniz Goruntuleme izni ile gorur). Katalogda
    # durmasi, yoneticiye 403 alan bir ekran acan bir kisayol sunmakti.
    "ziyaretci": frozenset({"security", "guvenlik_amiri"}),
    "borclular": _YONETIM,
    "gider": _YONETIM,
    "rezervasyon": _YONETIM,
    "vardiya": _YONETIM | {"guvenlik_amiri"},
    "anket": _YONETIM,
    "rapor": _YONETIM | {"denetci"},
    "kurulum": _YONETIM,
}

#: Hic secim yapilmamissa (ya da "varsayilana don" sonrasi) gosterilen
#: liste — P250 oncesi kartin sabit dort islemi.
VARSAYILAN: tuple[str, ...] = ("aidat", "talep", "duyuru", "personel")

#: Kartta en fazla bu kadar islem: iki sutunlu kart dort satiri asinca
#: "hizli" olmaktan cikar.
UST_SINIR = 8


def secenekler(rol: str) -> list[str]:
    return [k for k, roller in KATALOG.items() if rol in roller]


def gecerli_secim(rol: str, secim: list[str] | None) -> list[str]:
    """Kaydedilmis secimden yalniz BU ROLUN gorebildikleri (rol sonradan
    degisebilir: yetkisi kalkan islem sessizce dusurulur, kart bos kalmaz).
    Secim yoksa varsayilan."""
    izinli = set(secenekler(rol))
    if secim is None:
        return [k for k in VARSAYILAN if k in izinli]
    return [k for k in dict.fromkeys(secim) if k in izinli][:UST_SINIR]
