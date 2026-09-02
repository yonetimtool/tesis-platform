"""(P203 §5) FAZLA MESAI HESABI.

===========================================================================
YASAL DAYANAK
===========================================================================
4857 sayili Is Kanunu:
  * md. 63 — haftalik NORMAL calisma suresi 45 saattir,
  * md. 41 — 45 saati asan calisma FAZLA CALISMADIR ve her fazla saat
    icin verilecek ucret, normal saat ucretinin YUZDE ELLI FAZLASIDIR.

Katsayi bu yuzden 1.50 dogar ama TENANT AYARINDADIR ve degistirilebilir:
toplu is sozlesmesi daha yuksek bir oran belirleyebilir ve yazilim
mesru bir sozlesmeyi imkansiz kilmamali.

===========================================================================
HAFTALIK HESAP, AYLIK DEGIL — ve nedeni
===========================================================================
Fazla calisma HAFTALIK esige gore dogar (md. 41: "haftalik kirk bes
saati asan"). Ay uzerinden hesaplamak, bir hafta 60 saat calisip
otekinde 30 saat calisan biri icin FAZLA MESAI YOK sonucunu verirdi —
oysa ilk haftada 15 saat fazla calisma DOGMUSTUR ve ikinci haftanin
azligi onu silmez.

Bu yuzden ay ozeti, ayin ICINE DUSEN HAFTALARI tek tek hesaplar.

===========================================================================
SAATLIK UCRET
===========================================================================
`saatlik_ucret_kurus` verilmisse O KULLANILIR. Bos ise aylik ucretten
turetilir: `maas_kurus / 225`.

225 = 30 gun x 7,5 saat, Turkiye'de aylik ucretten saatlik ucret
cikarmanin standart bolenidir. Ikisi de yoksa hesap YAPILMAZ ve kisi
"ucret tanimsiz" olarak isaretlenir — sifir kabul edip 0 TL mesai
yazmak, yoneticiye "mesai yok" demenin sessiz ve yanlis yoluydu.
"""
from __future__ import annotations

import datetime as dt
from dataclasses import dataclass, field

#: (4857/63) Haftalik normal calisma suresi.
HAFTALIK_NORMAL_SAAT = 45.0

#: Aylik ucretten saatlik ucrete BOLEN (30 gun x 7,5 saat).
AYLIK_SAAT_BOLENI = 225


def saatlik_ucret(
    saatlik_kurus: int | None, aylik_kurus: int | None
) -> int | None:
    """Saatlik ucret (kurus). Ikisi de yoksa `None`.

    `None` DONMEK ONEMLI: sifir kabul edip 0 TL mesai yazmak,
    yoneticiye "mesai yok" demenin sessiz ve yanlis yoluydu.
    """
    if saatlik_kurus is not None and saatlik_kurus > 0:
        return saatlik_kurus
    if aylik_kurus is not None and aylik_kurus > 0:
        # Tam sayi bolme: kurusun altinda birim yok.
        return aylik_kurus // AYLIK_SAAT_BOLENI
    return None


@dataclass
class HaftaOzeti:
    hafta_basi: dt.date
    toplam_saat: float = 0.0

    @property
    def normal_saat(self) -> float:
        return min(self.toplam_saat, HAFTALIK_NORMAL_SAAT)

    @property
    def fazla_saat(self) -> float:
        return max(0.0, self.toplam_saat - HAFTALIK_NORMAL_SAAT)


@dataclass
class KisiOzeti:
    user_id: str
    ad: str
    haftalar: dict[dt.date, HaftaOzeti] = field(default_factory=dict)
    saatlik_ucret_kurus: int | None = None

    def ekle(self, tarih: dt.date, saat: float) -> None:
        hb = tarih - dt.timedelta(days=tarih.weekday())
        self.haftalar.setdefault(hb, HaftaOzeti(hafta_basi=hb)).toplam_saat += saat

    @property
    def toplam_saat(self) -> float:
        return sum(h.toplam_saat for h in self.haftalar.values())

    @property
    def fazla_saat(self) -> float:
        """HAFTA HAFTA toplanir.

        Ay toplami uzerinden hesaplamak, bir hafta 60 otekinde 30 saat
        calisan biri icin "fazla mesai yok" sonucunu verirdi — oysa ilk
        haftada 15 saat fazla calisma DOGMUSTUR.
        """
        return sum(h.fazla_saat for h in self.haftalar.values())

    def fazla_mesai_kurus(self, katsayi: float) -> int | None:
        """Fazla mesai TUTARI. Ucret tanimsizsa `None`."""
        if self.saatlik_ucret_kurus is None:
            return None
        return round(self.fazla_saat * self.saatlik_ucret_kurus * katsayi)


def ay_araligi(yil: int, ay: int) -> tuple[dt.date, dt.date]:
    """Ayin ilk ve son gunu."""
    bas = dt.date(yil, ay, 1)
    son = dt.date(yil + (ay // 12), (ay % 12) + 1, 1) - dt.timedelta(days=1)
    return bas, son
