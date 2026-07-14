"""Rezervasyon zamanlama kurallari — SAF (DB'siz), birim-test edilebilir.

Slot baslangici `tarih + baslangic` tenant'in yerel saatinde (tenant.timezone,
varsayilan 'Europe/Istanbul') yorumlanir; sunucunun UTC "simdi"sine cevrilip
karsilastirilir. Iki esik de bu slot-baslangic anina gore olculur:

  (a) 24 SAAT PENCERESI: slot baslangicina 24 saatten AZ kaldiginda rezerve
      edilebilir. 24 saatten erken (delta >= 24s) => 'cok_erken'. Baslangici
      GECMIS slot (delta <= 0) => 'gecti'.
  (b) GUNDE BIR: sakin, slotu ayni takvim gunune (rezerve edilen slotun gunu)
      denk gelen en fazla BIR aktif rezervasyon tutabilir; ikincisi => 'gunluk'.
  (c) SON DAKIKA ISTISNASI: slot hala BOS ve baslangicina 10 dakikadan AZ
      kaldiysa gunluk kota dolsa bile rezerve edilebilir (bos slot bosa gitmesin).
      Yalniz (b)'yi gecersiz kilar; (a)'nin ust siniri zaten saglanmistir.

Cakisma (dolu) her seyin onunde: dolu slot asla rezerve edilemez.
"""
from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

# Rezervasyon slot baslangicina EN COK bu kadar kala acilir (24 saat penceresi).
MIN_WINDOW = timedelta(hours=24)
# Son dakika istisnasi: bu kadardan az kala bos slot kotayi baypas eder.
LAST_MINUTE = timedelta(minutes=10)


def now_utc() -> datetime:
    """Sunucu "simdi"si (aware UTC). Testler bu fonksiyonu monkeypatch'ler."""
    return datetime.now(timezone.utc)


def slot_start_utc(tzname: str, tarih: date, baslangic: time) -> datetime:
    """`tarih + baslangic`i tenant-yerel saat kabul edip UTC'ye cevirir
    (DST-guvenli: zoneinfo ile olusturulup .astimezone(UTC))."""
    local = datetime(
        tarih.year, tarih.month, tarih.day,
        baslangic.hour, baslangic.minute, baslangic.second,
        tzinfo=ZoneInfo(tzname),
    )
    return local.astimezone(timezone.utc)


def booking_reason(
    tzname: str,
    tarih: date,
    baslangic: time,
    *,
    dolu: bool,
    kota_dolu: bool,
    now: datetime | None = None,
) -> str | None:
    """Bir slotun rezerve EDILEMEME sebebi — None ise rezerve edilebilir.

    Sebep kodlari (oncelik sirasi): 'dolu' -> 'gecti' -> 'cok_erken' -> 'gunluk'.
    """
    if dolu:
        return "dolu"
    delta = slot_start_utc(tzname, tarih, baslangic) - (now or now_utc())
    if delta <= timedelta(0):
        return "gecti"
    if delta >= MIN_WINDOW:
        return "cok_erken"
    # Son dakika istisnasi: <10 dk kala bos slot kotayi baypas eder.
    son_dakika = delta < LAST_MINUTE
    if kota_dolu and not son_dakika:
        return "gunluk"
    return None
