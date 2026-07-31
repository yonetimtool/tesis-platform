"""ANPR (plaka okuma) — KAYNAKTAN BAGIMSIZ cekirdek + adaptorler.

MASTER-PLAN P16. Frigate, Hikvision (ISAPI), Dahua ve elle giris AYNI ic
gövdeye (`AnprOlay`) cevrilir; uc katmani yalnizca bu gövdeyi tanir. Boylece
yeni bir marka eklemek = yeni bir ADAPTOR fonksiyonu; router, sema ve is
kurallari degismez.

Bu modul SAFTIR (DB/HTTP bilmez, testte dogrudan cagrilir):
  * kaynak yuklerinin normalize gövdeye cevrilmesi (adaptorler),
  * "bu olay ne yapmali" karari (`karar_ver`) — gecis ac / kapat / onaya
    dusur / yok say.

DB yazimi ve idempotency `routers/anpr.py` icindedir.

TASARIM NOTU — YON (P15'te olculdu): Frigate yon BILGISI URETMEZ. Yon uc
kaynaktan gelebilir: (a) olayin kendisi acikca soyluyorsa, (b) kameranin
sabit yonu (tek yonlu kapi — en yaygin saha kurulumu), (c) hicbiri yoksa
`bilinmiyor`. `bilinmiyor` GERCEK bir haldir ve sessizce "giris" sayilmaz:
plakanin ACIK gecisi varsa CIKIS, yoksa GIRIS kabul edilir (asagida
`karar_ver`). Bu, tek kameral cift yonlu gecitte dogru davranistir.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import UTC, datetime
from decimal import Decimal
from typing import Any

from .errors import APIError

#: Desteklenen kaynaklar. Yeni marka eklemek = yeni adaptor + bu kumeye ad.
KAYNAKLAR: tuple[str, ...] = ("frigate", "hikvision", "dahua", "manuel")

#: Yon degerleri (DB enum'u `anpr_yon` ile birebir).
YON_GIRIS = "giris"
YON_CIKIS = "cikis"
YON_BILINMIYOR = "bilinmiyor"

#: Olay durumlari (DB enum'u `anpr_olay_durum` ile birebir).
DURUM_ISLENDI = "islendi"
DURUM_ONAY_BEKLIYOR = "onay_bekliyor"
DURUM_YOK_SAYILDI = "yok_sayildi"
DURUM_HATA = "hata"

#: Kararlar.
EYLEM_GIRIS_AC = "giris_ac"
EYLEM_CIKIS_KAPAT = "cikis_kapat"
EYLEM_ONAYA_DUSUR = "onaya_dusur"
EYLEM_YOK_SAY = "yok_say"

_PLAKA_ATILACAK = re.compile(r"[^A-Za-z0-9]")


def norm_plaka_yumusak(plaka: str) -> str | None:
    """Plakayi kanonik forma cevir; GECERSIZSE `None` (istisna ATMAZ).

    `crud_helpers.norm_plaka` 422 atar — insan formu icin dogru. ANPR'da
    ise gecersiz okuma BEKLENEN bir durumdur (kamera cerceveyi yanlis
    kirpar, cikartma okur). Boyle bir olay isteği DUSURMEZ; olay `hata`
    durumuyla DEFTERE yazilir ki saha "kamera sacmaliyor" diyebilsin.
    """
    norm = _PLAKA_ATILACAK.sub("", plaka or "").upper()
    return norm if 2 <= len(norm) <= 20 else None


@dataclass(frozen=True)
class AnprOlay:
    """Kaynaktan bagimsiz NORMALIZE olay gövdesi."""

    kaynak: str
    kaynak_olay_id: str
    plaka: str            # NORMALIZE
    plaka_ham: str | None
    zaman: datetime       # UTC
    kamera: str | None
    yon: str
    guven: Decimal | None  # 0..1
    foto_key: str | None
    ham: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class Karar:
    """`karar_ver` ciktisi — uc katmani bunu uygular."""

    eylem: str
    durum: str
    neden: str | None = None


def _utc(deger: Any) -> datetime:
    """Kaynaklardan gelen zamani UTC `datetime`a cevir.

    Frigate UNIX float SANIYE kullanir; Hikvision/Dahua ISO8601 metin
    (Hikvision cogunlukla `+03:00` gibi bir OFSETLE gonderir).

    ONEMLI: donus HER ZAMAN UTC'ye NORMALIZE edilir. Ofseti oldugu gibi
    tasimak yanlis SONUC vermezdi (an aynidir) ama akis asagisinda karsilastirma
    ve gunluk sinirlarinda ofsetli/ofsetsiz karisimi uretirdi; fonksiyonun adi
    da bunu vaat ediyor. Naive bir zaman gelirse UTC KABUL EDILIR — sunucu ile
    kamera arasinda saat dilimi TAHMIN etmek sessiz hata uretir.
    """
    if isinstance(deger, (int, float)):
        return datetime.fromtimestamp(float(deger), tz=UTC)
    if isinstance(deger, datetime):
        d = deger if deger.tzinfo else deger.replace(tzinfo=UTC)
        return d.astimezone(UTC)
    if isinstance(deger, str) and deger:
        metin = deger.replace("Z", "+00:00")
        try:
            d = datetime.fromisoformat(metin)
        except ValueError:
            raise APIError(422, "validation_error", "anpr_zaman_bicimi")
        d = d if d.tzinfo else d.replace(tzinfo=UTC)
        return d.astimezone(UTC)
    raise APIError(422, "validation_error", "anpr_zaman_bicimi")


def _guven(deger: Any) -> Decimal | None:
    if deger is None:
        return None
    try:
        d = Decimal(str(deger))
    except Exception:
        return None
    # Kaynaklar bazen 0-100 arasi yuzde gonderir; 1'i asan degeri yuzde say.
    if d > 1:
        d = d / Decimal(100)
    if d < 0 or d > 1:
        return None
    return d.quantize(Decimal("0.001"))


# --------------------------------------------------------------------------- #
# Adaptorler — kaynak yuku -> AnprOlay
# --------------------------------------------------------------------------- #
def _standart(govde: dict[str, Any]) -> AnprOlay:
    """Bizim KENDI gövdemiz (`manuel` ve sema ile birebir gonderen kaynaklar).

    `docs/frigate-poc.md` §6'daki alan adlariyla ayni.
    """
    plaka_ham = govde.get("plaka")
    norm = norm_plaka_yumusak(plaka_ham or "")
    if norm is None:
        raise APIError(422, "validation_error", "anpr_plaka_bicimi")
    yon = govde.get("yon") or YON_BILINMIYOR
    if yon not in (YON_GIRIS, YON_CIKIS, YON_BILINMIYOR):
        raise APIError(422, "validation_error", "anpr_yon_gecersiz")
    olay_id = govde.get("kaynak_olay_id")
    if not olay_id:
        raise APIError(422, "validation_error", "anpr_olay_id_gerekli")
    return AnprOlay(
        kaynak=govde.get("kaynak") or "manuel",
        kaynak_olay_id=str(olay_id),
        plaka=norm,
        plaka_ham=plaka_ham,
        zaman=_utc(govde.get("zaman")),
        kamera=govde.get("kamera"),
        yon=yon,
        guven=_guven(govde.get("guven")),
        foto_key=govde.get("foto_key"),
        ham=govde.get("ham") or {},
    )


def _frigate(govde: dict[str, Any]) -> AnprOlay:
    """Frigate `GET /api/events` satiri (ya da `frigate/events` MQTT yuku).

    P15'te olculen gercekler:
      * plaka `sub_label` alanindadir (LPR sonucu); `label` "car"dir.
      * `id` "1785450578.367615-mhjk2h" bicimindedir ve olay YASAM BOYU
        AYNIDIR — idempotency anahtarimiz budur.
      * `start_time` UNIX float SANIYEDIR.
      * yon YOKTUR (bkz. modul notu).
    """
    olay = govde.get("after") or govde.get("event") or govde
    plaka_ham = olay.get("sub_label") or olay.get("plaka")
    norm = norm_plaka_yumusak(plaka_ham or "")
    if norm is None:
        raise APIError(422, "validation_error", "anpr_plaka_bicimi")
    olay_id = olay.get("id")
    if not olay_id:
        raise APIError(422, "validation_error", "anpr_olay_id_gerekli")
    data = olay.get("data") or {}
    return AnprOlay(
        kaynak="frigate",
        kaynak_olay_id=str(olay_id),
        plaka=norm,
        plaka_ham=plaka_ham,
        zaman=_utc(olay.get("start_time")),
        kamera=olay.get("camera"),
        # Frigate yon uretmez; kamera ayari uc katmaninda uygulanir.
        yon=govde.get("yon") or YON_BILINMIYOR,
        guven=_guven(
            olay.get("plate_score")
            or data.get("top_score")
            or olay.get("top_score")
        ),
        foto_key=govde.get("foto_key"),
        ham=govde,
    )


def _hikvision(govde: dict[str, Any]) -> AnprOlay:
    """Hikvision ISAPI olay bildirimi (`ANPR` / `AID` yuku).

    Hikvision ic ice `EventNotificationAlert.ANPR` gonderir; plaka
    `licensePlate`, zaman `dateTime` (ISO8601, saat dilimi ekli).
    """
    kok = govde.get("EventNotificationAlert") or govde
    anpr = kok.get("ANPR") or kok
    plaka_ham = anpr.get("licensePlate") or anpr.get("plateNumber")
    norm = norm_plaka_yumusak(plaka_ham or "")
    if norm is None:
        raise APIError(422, "validation_error", "anpr_plaka_bicimi")
    # Hikvision her bildirimde ayri bir kimlik vermeyebilir; yoksa
    # (plaka + zaman) ciftinden TUREVSEL bir kimlik uretilir — ayni olayin
    # tekrari yine ayni kimligi verir, idempotency korunur.
    zaman = _utc(anpr.get("dateTime") or kok.get("dateTime"))
    olay_id = (
        anpr.get("eventId")
        or kok.get("eventId")
        or f"{norm}-{int(zaman.timestamp())}"
    )
    return AnprOlay(
        kaynak="hikvision",
        kaynak_olay_id=str(olay_id),
        plaka=norm,
        plaka_ham=plaka_ham,
        zaman=zaman,
        kamera=kok.get("channelName") or kok.get("channelID"),
        yon=govde.get("yon") or YON_BILINMIYOR,
        guven=_guven(anpr.get("confidenceLevel")),
        foto_key=govde.get("foto_key"),
        ham=govde,
    )


def _dahua(govde: dict[str, Any]) -> AnprOlay:
    """Dahua HTTP push (`TrafficCar` olayi).

    Dahua `Events[].Data.PlateNumber` gonderir; zaman `UTC` (UNIX saniye)
    ya da `Time` (ISO metin) olabilir.
    """
    olaylar = govde.get("Events")
    kok = olaylar[0] if isinstance(olaylar, list) and olaylar else govde
    veri = kok.get("Data") or kok
    plaka_ham = veri.get("PlateNumber") or veri.get("plateNumber")
    norm = norm_plaka_yumusak(plaka_ham or "")
    if norm is None:
        raise APIError(422, "validation_error", "anpr_plaka_bicimi")
    zaman = _utc(veri.get("UTC") or veri.get("Time") or kok.get("Time"))
    olay_id = (
        veri.get("EventID")
        or kok.get("EventID")
        or f"{norm}-{int(zaman.timestamp())}"
    )
    return AnprOlay(
        kaynak="dahua",
        kaynak_olay_id=str(olay_id),
        plaka=norm,
        plaka_ham=plaka_ham,
        zaman=zaman,
        kamera=veri.get("ChannelName") or kok.get("Channel"),
        yon=govde.get("yon") or YON_BILINMIYOR,
        guven=_guven(veri.get("Confidence")),
        foto_key=govde.get("foto_key"),
        ham=govde,
    )


#: kaynak adi -> adaptor. Yeni marka eklemek yalnizca buraya satir ekler.
ADAPTORLER = {
    "frigate": _frigate,
    "hikvision": _hikvision,
    "dahua": _dahua,
    "manuel": _standart,
    "standart": _standart,
}


def coz(kaynak: str, govde: dict[str, Any]) -> AnprOlay:
    """Kaynak adina gore adaptoru sec ve olayi normalize et."""
    adaptor = ADAPTORLER.get(kaynak)
    if adaptor is None:
        raise APIError(422, "validation_error", "anpr_kaynak_bilinmiyor")
    return adaptor(govde)


# --------------------------------------------------------------------------- #
# Karar
# --------------------------------------------------------------------------- #
def karar_ver(
    olay: AnprOlay,
    *,
    acik_gecis_var: bool,
    esik: Decimal,
    otomatik_cikis: bool,
) -> Karar:
    """Bu olay ne yapmali?

    Kurallar (hepsi testle kilitli):

    1. GUVEN ESIGI — `guven` verilmis ve esigin ALTINDAYSA hicbir gecis
       acilmaz/kapanmaz; olay ONAY KUYRUGUNA duser. Guven HIC verilmemisse
       (kaynak bildirmiyor) olay islenir: eksik veri, kotu veri demek
       degildir ve tum kaynaklar guven uretmez.
    2. YON — acikca verilmisse ona uyulur. `bilinmiyor` ise plakanin ACIK
       gecisi varsa CIKIS, yoksa GIRIS kabul edilir (tek kameral cift yonlu
       gecidin dogru davranisi).
    3. TEKRAR — giris istenmis ama arac ZATEN iceridiyse yok sayilir (kismi
       unique indeks zaten 409 verirdi; sessiz yok saymak kamera tekrarinda
       dogru davranis). Cikis istenmis ama acik gecis YOKSA da yok sayilir.
    4. OTOMATIK CIKIS KAPALIYSA cikis olayi yok sayilir — tek yonlu kapida
       (yalniz giris kamerasi) yanlis kapatma yapilmasin.
    """
    if olay.guven is not None and olay.guven < esik:
        return Karar(EYLEM_ONAYA_DUSUR, DURUM_ONAY_BEKLIYOR, "dusuk_guven")

    yon = olay.yon
    if yon == YON_BILINMIYOR:
        yon = YON_CIKIS if acik_gecis_var else YON_GIRIS

    if yon == YON_GIRIS:
        if acik_gecis_var:
            return Karar(EYLEM_YOK_SAY, DURUM_YOK_SAYILDI, "zaten_iceride")
        return Karar(EYLEM_GIRIS_AC, DURUM_ISLENDI)

    # yon == cikis
    if not otomatik_cikis:
        return Karar(EYLEM_YOK_SAY, DURUM_YOK_SAYILDI, "otomatik_cikis_kapali")
    if not acik_gecis_var:
        return Karar(EYLEM_YOK_SAY, DURUM_YOK_SAYILDI, "acik_gecis_yok")
    return Karar(EYLEM_CIKIS_KAPAT, DURUM_ISLENDI)
