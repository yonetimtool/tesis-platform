"""(P241 §1) PERIYODIK BAKIM — periyot hesabi ve durum turetimi.

===========================================================================
DURUM SUTUN DEGIL, TURETILIR
===========================================================================
"Yaklasan / bugun / gecikmis" bir SUTUN olsaydi her gece bir isin onu
guncellemesi gerekirdi ve is kosmadigi gun liste YANLIS gorunurdu —
gecikmis bir asansor "tamam" diye durabilirdi. Tarih aritmetigi ucuz,
yanlis gosterilen bir yasal kontrol pahalidir.
"""
from __future__ import annotations

from datetime import date

#: Periyot -> gun. `gun` serbest deger tasir (`periyot_gun`).
#:
#: AY = 30 GUN DEGIL: "3 aylik" bakim, ayni ayin gunune gitmeli. Gun
#: sayisiyla carpmak, yilda dort kez yapilan bir bakimi 12 gun kaydirir
#: ve dorduncu ceyrekte ay atlatirdi.
AY_PERIYOT: dict[str, int] = {
    "aylik": 1,
    "uc_aylik": 3,
    "alti_aylik": 6,
    "yillik": 12,
}

#: Tesis varsayilani yoksa (eski kayit) kullanilacak deger.
VARSAYILAN_UYARI_GUN = 30

#: Gecikmis bakim kac gunde bir tekrar hatirlatilir.
#:
#: HER GUN DEGIL: gunluk hatirlatma bildirim yorgunlugu uretir ve yorgun
#: kullanici bildirimleri KAPATIR — panik alarmi dahil. Haftalik tekrar
#: unutulmayi onlemeye yetiyor, kapatmaya itmiyor.
GECIKME_TEKRAR_GUN = 7


def ay_ekle(t: date, ay: int) -> date:
    """Takvim ayi ekler; ayin son gunu tasarsa AYIN SONUNA kirpar.

    31 Ocak + 1 ay = 28/29 Subat. Kirpmasaydik `date` hata verirdi ve
    ayin 31'inde yapilan bir bakim kaydi 500 uretirdi.
    """
    yil = t.year + (t.month - 1 + ay) // 12
    ay_no = (t.month - 1 + ay) % 12 + 1
    if ay_no == 12:
        sonraki = date(yil + 1, 1, 1)
    else:
        sonraki = date(yil, ay_no + 1, 1)
    ayin_son_gunu = (sonraki - date.resolution).day
    return date(yil, ay_no, min(t.day, ayin_son_gunu))


def sonraki_tarih(baslangic: date, periyot: str, periyot_gun: int | None) -> date:
    """Bir bakim tarihinden sonraki bakim tarihi."""
    if periyot == "gun":
        return baslangic + (date.resolution * int(periyot_gun or 1))
    return ay_ekle(baslangic, AY_PERIYOT[periyot])


def durum(sonraki: date, uyari_gun: int, bugun: date) -> str:
    """`gecikti` | `bugun` | `yaklasti` | `planli`.

    SIRA ONEMLI: gecikmis bir kayit `uyari_gun` ne olursa olsun once
    "gecikti" sayilir.
    """
    if sonraki < bugun:
        return "gecikti"
    if sonraki == bugun:
        return "bugun"
    if (sonraki - bugun).days <= uyari_gun:
        return "yaklasti"
    return "planli"


def kalan_gun(sonraki: date, bugun: date) -> int:
    """Negatif = gecikme gunu. Arayuz RENGE DEGIL bu sayiya da yazar —
    renk tek basina anlam tasimamali (erisilebilirlik)."""
    return (sonraki - bugun).days
