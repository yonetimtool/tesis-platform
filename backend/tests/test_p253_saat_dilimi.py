"""(P253 §E) "SIMDI CALISTIR" VE TESISIN GUNU.

Uygulama saati UTC. Istanbul gece 00:00–03:00 arasinda UTC hala dunku
tarihtir: ayin 1'i gecesi elle tetiklenen maas otomasyonu ONCEKI AYI
gorurdu. Istek yolundaki her "bugun" `app.tesis_saati` uzerinden gelir.

Saat canli sunucuda dondurulamaz (testler canli API'ye gider); bu yuzden:
  * saf kural (`yerel_bugun`) ay sinirinda olculur,
  * ayni gun maas kurali ay sinirindaki gunle calistirilir,
  * kaynak taramasi istek yolunda UTC-bugun kullanimini YASAKLAR.
"""
from __future__ import annotations

import pathlib
import re
from datetime import date, datetime, timezone

from app import maas
from app.tesis_saati import VARSAYILAN_SAAT_DILIMI, yerel_bugun

KOK = pathlib.Path(__file__).resolve().parent.parent / "app"


def test_AY_SINIRI_gecesi_tesisin_gunu_YENI_AY():
    # 31 Ekim 22:30 UTC = 1 Kasim 01:30 Istanbul.
    an = datetime(2026, 10, 31, 22, 30, tzinfo=timezone.utc)
    assert an.date() == date(2026, 10, 31), "UTC hala Ekim"
    assert yerel_bugun("Europe/Istanbul", an) == date(2026, 11, 1)
    # Ayni an, maas kurali: odeme gunu 1 -> KASIM donemi yazilir.
    assert maas.donem(yerel_bugun("Europe/Istanbul", an)) == "2026-11"
    assert maas.odeme_tarihi("2026-11", 1) == date(2026, 11, 1)


def test_YIL_SINIRI_ve_GECERSIZ_saat_dilimi():
    an = datetime(2026, 12, 31, 21, 5, tzinfo=timezone.utc)
    assert yerel_bugun("Europe/Istanbul", an) == date(2027, 1, 1)
    # Gecersiz dize finans islemini dusurmez: varsayilan bolge.
    assert yerel_bugun("Mars/Olympus", an) == yerel_bugun(VARSAYILAN_SAAT_DILIMI, an)
    # Saat dilimsiz an UTC sayilir.
    assert yerel_bugun("Europe/Istanbul", datetime(2026, 10, 31, 22, 30)) == date(2026, 11, 1)


#: Bilincli istisnalar — her biri GEREKCELI. Ikisi de "ileri tarih"
#: dogrulamasidir ve UTC'ye BIR GUN PAY tanir: tesis gunu ile en fazla
#: bir gun farkli olabilir, pay bunu zaten karsilar.
ISTISNALAR = {
    ("routers/finans.py", "ILERI_TARIH_TOLERANS_GUN"):
        "tahsilat tarihinin ileri olup olmadigi; gun payli UTC karsilastirmasi",
    ("routers/patrol_plans.py", "dt.timedelta(days=1)"):
        "ek tarihin gecmis olup olmadigi; bir gun payli (yorumunda yazili)",
}
UTC_BUGUN = re.compile(r"date\.today\(\)|now\((?:dt\.)?timezone\.utc\)\.date\(\)|utcnow\(\)\.date\(\)")


def test_ISTEK_YOLUNDA_UTC_BUGUN_YOK():
    """routers + otomasyon/maas/defter/gecikme: UTC 'bugun' yasak (yorumlar haric)."""
    dosyalar = sorted((KOK / "routers").glob("*.py")) + [
        KOK / "otomasyon.py", KOK / "maas.py", KOK / "defter.py", KOK / "gecikme.py",
    ]
    ihlal = []
    for f in dosyalar:
        satirlar = f.read_text(encoding="utf-8").splitlines()
        for i, satir in enumerate(satirlar):
            kod = satir.split("#", 1)[0]
            if not UTC_BUGUN.search(kod) or "`" in kod:
                continue
            goreli = f.relative_to(KOK).as_posix()
            pencere = "\n".join(satirlar[i:i + 3])
            if any(d == goreli and anahtar in pencere for d, anahtar in ISTISNALAR):
                continue
            ihlal.append(f"{goreli}:{i + 1}: {satir.strip()}")
    assert not ihlal, (
        "Istek yolunda UTC 'bugun' — tesisin gunu icin `tesis_saati.tesis_bugun(db)` "
        "kullanin:\n  " + "\n  ".join(ihlal)
    )
