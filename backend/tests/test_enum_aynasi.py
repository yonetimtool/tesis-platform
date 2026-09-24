"""(E2E 2026-09) MODEL ENUM'LARI = VERITABANI ENUM'LARI (birebir).

OLCULEN KUSUR: `notification_tip` DB enum'unda `vardiya_hatirlatma` ve
`vardiya_baslamadi` vardi, `models.NOTIFICATION_TIP`te YOKTU. Beat bu
tipleri ham SQL ile yaziyor (yazma basarili), ORM okumasi ise
`LookupError` ile patliyordu: ilk vardiya hatirlatmasindan sonra yonetim
ve guvenlik icin `GET /notifications` 500.

Dosyanin kendi kurali "gocun birebir aynasi olmak" — bu test o kurali
makineye devreder: bir goc enum'a deger ekleyip modeli unutursa burada
duser, uretimde degil.
"""
from __future__ import annotations

from sqlalchemy.dialects.postgresql import ENUM

from app import models


def _model_enumlari() -> dict[str, tuple[str, ...]]:
    bulunan: dict[str, tuple[str, ...]] = {}
    for deger in vars(models).values():
        if isinstance(deger, ENUM) and deger.name:
            bulunan[deger.name] = tuple(deger.enums)
    return bulunan


def test_MODEL_ENUMLARI_DB_ILE_AYNI(owner_conn):
    eksik: list[str] = []
    fazla: list[str] = []
    with owner_conn.cursor() as cur:
        for ad, degerler in _model_enumlari().items():
            cur.execute(
                "SELECT e.enumlabel FROM pg_enum e JOIN pg_type t "
                "ON t.oid = e.enumtypid WHERE t.typname = %s",
                (ad,),
            )
            db = {r[0] for r in cur.fetchall()}
            if not db:
                continue  # tip bu semada yok (baska sema / henuz gocsuz)
            for d in db - set(degerler):
                eksik.append(f"{ad}.{d}")
            for d in set(degerler) - db:
                fazla.append(f"{ad}.{d}")
    assert not eksik, f"DB'de olup MODELDE olmayan enum degerleri: {sorted(eksik)}"
    assert not fazla, f"MODELDE olup DB'de olmayan enum degerleri: {sorted(fazla)}"
