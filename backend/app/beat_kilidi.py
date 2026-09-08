"""BEAT AYRISMA TESPITI — zamanlayicinin ESKI IMAJLA kosmasini gorunur kilar.

===========================================================================
UC KEZ AYNI KUSUR
===========================================================================
Ucunde de ayni sey oldu:

  P187  vardiya ozeti      -> gorev yazildi, api+worker yenilendi,
  P192  finans otomasyonu     beat ATLANDI, hicbir hata gorunmedi,
  F8b   reklam bakimi         gorev prod'da HIC KOSMADI.

Sebep yapisal: `beat`in zamanlamasi `celery_app.conf.beat_schedule`dan
gelir ve o dosya IMAJA GOMULUDUR. Imaj eskiyse beat ESKI zamanlamayi
yukler — ve bunun YANLIS oldugunu bilmesinin hicbir yolu yoktur.
"Calisiyor" gorunur: sureç ayakta, log akiyor, gorev yok.

===========================================================================
NEDEN "BEAT KENDI TANIMIYLA KARSILASTIRSIN" TEK BASINA CALISMAZ
===========================================================================
Ilk akla gelen cozum "beat, `beat_schedule`ini `celery_app.py`deki
tanimla karsilastirsin" idi. CALISMAZ: beat'in yukledigi zamanlama ZATEN
o dosyadan geliyor ve ikisi AYNI IMAJIN icinde. Bir seyi kendisiyle
karsilastirmak her zaman gecer — ve eski imajda da gecerdi.

Karsilastirma ancak IMAJIN DISINDAN gelen bir seyle anlamli olur.

===========================================================================
COZUM: `contracts/` CANLI MOUNT'TUR
===========================================================================
Bu depoda zaten bir ayrim var ve uc kez ise yaradi: `backend/` imaja
GOMULU, `contracts/` ise CANLI MOUNT (goc dosyalari, `openapi.yaml`).
Yani `contracts/` her zaman DEPODAKI halidir; imaj eski olsa bile.

`contracts/beat-gorevleri.txt` bu yuzden orada duruyor. Beat acilista
kendi zamanlamasini o dosyayla karsilastirir:

  * ESLESIYORSA  -> imaj guncel, INFO satiri.
  * ESLESMIYORSA -> IMAJ ESKI (ya da manifest guncellenmemis) -> ERROR.

Ayni mantik `migrate` servisinde de var: goc dosyalari mount'tan
okunur, kod imajdan gelir; ayrisma orada da yakalanir.

===========================================================================
BEAT DURDURULMAZ — VE BU BILINCLI
===========================================================================
Ayrisma halinde surec KAPATILMIYOR. Sebep P124'te yazili olanla ayni:
eski zamanlama ile kosan bir beat, gorevlerin BIR KISMINI yine de
calistirir. Kapatmak, teshis edilebilir bir bozuklugu ERISILEMEZ bir
bosluga cevirirdi (hicbir gorev kosmaz). Ayrisma ANLATILIR, karar
operatorundur.

===========================================================================
DURUM REDIS'E DE YAZILIR — CUNKU BEAT'IN HTTP'SI YOK
===========================================================================
`docker compose logs beat | grep` ise yarar ama BAKAN biri gerekir. Uc
olayin ucunde de kimse bakmadi.

Beat, durumunu Redis'e yaziyor; `GET /health` onu okuyup raporluyor.
Boylece dagitim sonrasi dogrulama TEK SATIR oluyor ve `api` uzerinden
sorulabiliyor — beat'e girmeye gerek yok.

TTL VAR (25 saat): beat olurse kayit ESKIR ve `/health` "bayat" der.
Kalici bir kayit, olmus bir beat'i "saglikli" gosterirdi.
"""
from __future__ import annotations

import hashlib
import json
import logging
import os
from pathlib import Path

logger = logging.getLogger(__name__)

#: Manifest — `contracts/` CANLI MOUNT oldugu icin imajdan bagimsiz.
SOZLESME_YOLU = Path(os.getenv("BEAT_SOZLESME_YOLU", "/contracts/beat-gorevleri.txt"))

#: Redis anahtari ve omru. 25 saat: gecelik gorevlerden uzun, iki gunden
#: kisa — olmus bir beat en gec ertesi gun "bayat" gorunur.
REDIS_ANAHTARI = "beat:durum"
REDIS_OMRU_SN = 25 * 3600


def zamanlama_satirlari(beat_schedule: dict) -> list[str]:
    """Zamanlamayi KARSILASTIRILABILIR satirlara cevirir.

    Doner: `"<kayit adi>\\t<task adi>\\t<schedule>"` satirlari, SIRALI.

    NEDEN SIRALI VE METIN: sozluk sirasi Python surumune/ekleme sirasina
    gore degisebilir; siralanmis metin iki tarafta da AYNI uretilir.
    `schedule` degeri `crontab(...)` ya da saniye olabiliyor; `str()`
    ikisini de kararli sekilde yaziyor.
    """
    satirlar = []
    for ad, kayit in (beat_schedule or {}).items():
        satirlar.append(f"{ad}\t{kayit.get('task', '')}\t{kayit.get('schedule', '')}")
    return sorted(satirlar)


def parmak_izi(satirlar: list[str]) -> str:
    """Satirlarin kisa ozeti — loglarda ve `/health`te gosterilir."""
    ham = "\n".join(satirlar).encode()
    return hashlib.sha256(ham).hexdigest()[:12]


def sozlesme_satirlari(yol: Path | None = None) -> list[str] | None:
    """Manifest satirlari; dosya yoksa `None`.

    `None` "ayrisma yok" DEMEK DEGIL — "olculemedi" demek. Ikisini ayni
    saymak, mount'u unutulmus bir kurulumu "saglikli" gosterirdi.
    """
    p = yol or SOZLESME_YOLU
    try:
        ham = p.read_text(encoding="utf-8")
    except OSError:
        return None
    return sorted(
        s for s in (x.strip() for x in ham.splitlines())
        if s and not s.startswith("#")
    )


def karsilastir(beat_schedule: dict, yol: Path | None = None) -> dict:
    """Kod ile manifesti karsilastirir.

    Doner:
      {"uyumlu": bool|None, "kod_gorev": int, "sozlesme_gorev": int|None,
       "kod_parmak": str, "sozlesme_parmak": str|None,
       "yalniz_kodda": [...], "yalniz_sozlesmede": [...]}

    `uyumlu is None` -> OLCULEMEDI (manifest okunamadi).
    """
    kod = zamanlama_satirlari(beat_schedule)
    sz = sozlesme_satirlari(yol)
    if sz is None:
        return {"uyumlu": None, "kod_gorev": len(kod), "sozlesme_gorev": None,
                "kod_parmak": parmak_izi(kod), "sozlesme_parmak": None,
                "yalniz_kodda": [], "yalniz_sozlesmede": []}
    return {
        "uyumlu": kod == sz,
        "kod_gorev": len(kod),
        "sozlesme_gorev": len(sz),
        "kod_parmak": parmak_izi(kod),
        "sozlesme_parmak": parmak_izi(sz),
        # AYRINTI DA DONUYOR: "uyumsuz" demek operatore ne yapacagini
        # soylemez; HANGI gorevin eksik oldugunu soylemek soyler.
        "yalniz_kodda": [s.split("\t")[0] for s in kod if s not in sz],
        "yalniz_sozlesmede": [s.split("\t")[0] for s in sz if s not in kod],
    }


def durumu_gunlukle_ve_yaz(beat_schedule: dict, redis_url: str | None) -> dict:
    """Acilista cagrilir: karsilastirir, loglar, Redis'e yazar.

    HICBIR KOSULDA FIRLATMAZ: bir tespit mekanizmasi, tespit ettigi
    seyden daha buyuk bir arizaya yol acmamali. Redis erisilemezse
    yalnizca log kalir.
    """
    d = karsilastir(beat_schedule)

    if d["uyumlu"] is False:
        logger.error(
            "BEAT AYRISMASI: imajdaki zamanlama ile contracts/ "
            "manifesti UYUSMUYOR. kod=%d gorev (%s), sozlesme=%d gorev (%s). "
            "YALNIZ KODDA: %s | YALNIZ SOZLESMEDE: %s. "
            "EN SIK NEDEN: `beat` imaji yeniden KURULMADI — "
            "`docker compose build ... beat` ve `up -d --force-recreate beat`. "
            "Zamanlanmis gorevler ESKI listeye gore kosuyor.",
            d["kod_gorev"], d["kod_parmak"],
            d["sozlesme_gorev"], d["sozlesme_parmak"],
            d["yalniz_kodda"] or "-", d["yalniz_sozlesmede"] or "-",
        )
    elif d["uyumlu"] is None:
        logger.warning(
            "BEAT manifesti OKUNAMADI (%s). Ayrisma OLCULEMIYOR — "
            "`contracts/` bu servise mount edilmis mi? kod=%d gorev (%s)",
            SOZLESME_YOLU, d["kod_gorev"], d["kod_parmak"],
        )
    else:
        logger.info(
            "BEAT zamanlamasi uyumlu: %d gorev (%s)",
            d["kod_gorev"], d["kod_parmak"],
        )

    if redis_url:
        try:
            import redis as _redis

            istemci = _redis.Redis.from_url(redis_url)
            istemci.setex(REDIS_ANAHTARI, REDIS_OMRU_SN, json.dumps(d))
        except Exception as e:  # pragma: no cover - Redis yoksa
            logger.warning("BEAT durumu Redis'e yazilamadi: %s", e)
    return d
