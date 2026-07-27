"""Ceviri isi — WORKER tarafi (sync psycopg, scheduler ile ayni desen).

RLS: is her zaman app_rw + `SET LOCAL app.current_tenant_id` altinda yapilir
(owner baglantisi KULLANILMAZ) — bir tenant'in icerigi digerine sizamaz.

BASARISIZLIK ILKESI (non-negotiable): ceviri icerik kaydini ASLA dusurmez.
  * Saglayici cokerse/yavassa: ilgili diller `durum='hata'` olur, ORIJINAL
    metin servis edilmeye devam eder.
  * Kuyruk (Redis) erisilemezse: [enqueue_ceviri] sessizce loglar, istek 201
    doner (satirlar `bekliyor` kalir; sonraki duzenlemede yeniden kuyruklanir).

Ag cagrilari TRANSACTION DISINDA yapilir: 7 dillik ceviri saniyeler surebilir,
bu sure boyunca DB kilidi/transaction acik tutulmaz.
"""
from __future__ import annotations

import json
import logging
import uuid
from collections.abc import Mapping

import psycopg

from . import ceviri
from .celery_app import celery_app
from .config import settings
from .translate import TranslationError, TranslationProvider, get_translation_provider

logger = logging.getLogger("ceviri")

# hata_mesaji kolonuna yazilan azami uzunluk (saglayici mesaji kisaltilir).
_MAX_HATA = 400

#: Kuyruk task adi — `app.tasks` ile paylasilir (string ile gevsek baglanti).
TASK_ADI = "ceviri.translate_entity"


def enqueue_ceviri(
    tip_ad: str, entity_id: uuid.UUID, tenant_id: uuid.UUID
) -> bool:
    """Ceviri isini kuyruga at — ASLA yukselmez (icerik kaydi kutsaldir).

    COMMIT YARISI: bu fonksiyon istek yolundan, istegin transaction'i HENUZ
    COMMIT EDILMEDEN cagrilir. Worker milisaniyeler icinde kosarsa icerigi
    goremez ve is "icerik yok" ile biter — ceviri HIC uretilmezdi (gozlemlendi:
    worker loglarinda `not: icerik yok`). Bu yuzden is KUCUK BIR GECIKME ile
    kuyruklanir; ayrica task icerigi bulamazsa sinirli sayida yeniden dener
    (app/tasks.py). Iki onlem birlikte: commit yavas olsa da ceviri kaybolmaz.

    Donus: kuyruga verildi mi (test/gozlem icin). False = broker erisilemedi;
    icerik kaydi yine de basarilidir.
    """
    try:
        celery_app.send_task(
            TASK_ADI,
            kwargs={
                "tip_ad": tip_ad,
                "entity_id": str(entity_id),
                "tenant_id": str(tenant_id),
            },
            countdown=settings.translate_enqueue_delay_seconds,
        )
        return True
    except Exception:  # broker kapali/erisilemez — icerik kaydi ETKILENMEZ
        logger.exception(
            "ceviri kuyruga verilemedi (icerik kaydi etkilenmedi): %s/%s",
            tip_ad,
            entity_id,
        )
        return False


def _kaynak_oku(
    conn: psycopg.Connection, t: ceviri.CevrilebilirTip, entity_id: uuid.UUID
) -> tuple[dict[str, str], str] | None:
    """Kaynak satirin cevrilecek alanlari + kaynak dili (yoksa None)."""
    kolonlar = ", ".join(t.alanlar)
    satir = conn.execute(
        f"SELECT {kolonlar}, kaynak_dil FROM {t.kaynak_tablo} WHERE id = %s",
        (entity_id,),
    ).fetchone()
    if satir is None:
        return None
    alanlar = {ad: (satir[i] or "") for i, ad in enumerate(t.alanlar)}
    return alanlar, satir[len(t.alanlar)]


def _ceviriler_oku(
    conn: psycopg.Connection, t: ceviri.CevrilebilirTip, entity_id: uuid.UUID
) -> dict[str, ceviri.CeviriSatiri]:
    satirlar = conn.execute(
        f"SELECT dil, alanlar, durum::text, cevirildi_mi, elle_duzeltildi, "
        f"kaynak_hash FROM {t.ceviri_tablo} WHERE {t.fk_kolon} = %s",
        (entity_id,),
    ).fetchall()
    return {
        r[0]: ceviri.CeviriSatiri(
            dil=r[0],
            alanlar=r[1] or {},
            durum=r[2],
            cevirildi_mi=r[3],
            elle_duzeltildi=r[4],
            kaynak_hash=r[5],
        )
        for r in satirlar
    }


def _yaz(
    conn: psycopg.Connection,
    t: ceviri.CevrilebilirTip,
    entity_id: uuid.UUID,
    tenant_id: uuid.UUID,
    dil: str,
    *,
    alanlar: Mapping[str, str],
    durum: str,
    kaynak_hash_: str,
    hata_mesaji: str | None,
) -> None:
    """Tek dilin cevirisini UPSERT et.

    ELLE DUZELTME KORUMASI burada da tekrarlanir (WHERE NOT ...): worker ile
    istek yolu yaris ederse (duzenleme sirasinda eski is bitmek uzereyse) elle
    duzeltilmis ve kaynagi ayni olan satirin uzerine YAZILMAZ.
    """
    kisa_hata = hata_mesaji[:_MAX_HATA] if hata_mesaji else None
    conn.execute(
        f"""
        INSERT INTO {t.ceviri_tablo}
            (tenant_id, {t.fk_kolon}, dil, alanlar, durum, cevirildi_mi,
             elle_duzeltildi, kaynak_hash, hata_mesaji)
        VALUES (%s, %s, %s, %s::jsonb, %s::ceviri_durum, true, false, %s, %s)
        ON CONFLICT (tenant_id, {t.fk_kolon}, dil) DO UPDATE
           SET alanlar = EXCLUDED.alanlar,
               durum = EXCLUDED.durum,
               cevirildi_mi = true,
               elle_duzeltildi = false,
               kaynak_hash = EXCLUDED.kaynak_hash,
               hata_mesaji = EXCLUDED.hata_mesaji,
               updated_at = now()
         WHERE NOT ({t.ceviri_tablo}.elle_duzeltildi
                    AND {t.ceviri_tablo}.kaynak_hash = EXCLUDED.kaynak_hash);
        """,
        (
            tenant_id,
            entity_id,
            dil,
            json.dumps(dict(alanlar), ensure_ascii=False),
            durum,
            kaynak_hash_,
            kisa_hata,
        ),
    )


def entity_cevir(
    tip_ad: str,
    entity_id: uuid.UUID | str,
    tenant_id: uuid.UUID | str,
    *,
    app_dsn: str | None = None,
    provider: TranslationProvider | None = None,
) -> dict:
    """Bir icerigin eksik/bayat cevirilerini uretir (idempotent).

    Donus ozeti: {"cevrilen": [dil...], "hata": [dil...], "korunan": n,
    "atlanan": n} — kuyruk loglarinda gorunur.
    """
    t = ceviri.tip(tip_ad)
    entity_id = uuid.UUID(str(entity_id))
    tenant_id = uuid.UUID(str(tenant_id))
    provider = provider or get_translation_provider()
    dsn = app_dsn or settings.app_dsn

    with psycopg.connect(dsn, connect_timeout=10) as conn:
        # 1) Plan (kisa transaction — ag cagrisi YOK).
        with conn.transaction():
            conn.execute(
                "SELECT set_config('app.current_tenant_id', %s, true)",
                (str(tenant_id),),
            )
            kaynak = _kaynak_oku(conn, t, entity_id)
            if kaynak is None:
                # Icerik bu arada silinmis: yapacak is yok (CASCADE cevirileri de sildi).
                return {"cevrilen": [], "hata": [], "korunan": 0, "atlanan": 0,
                        "not": "icerik yok"}
            orijinal, kaynak_dil = kaynak
            h = ceviri.kaynak_hash(orijinal)
            mevcut = _ceviriler_oku(conn, t, entity_id)
            hedefler = ceviri.hedef_diller(kaynak_dil)
            cevrilecek = ceviri.cevrilecek_diller(
                mevcut=mevcut, yeni_hash=h, hedefler=hedefler
            )
            korunan = sum(
                1 for d in hedefler if ceviri.korunur_mu(mevcut.get(d), h)
            )

        if not cevrilecek:
            return {"cevrilen": [], "hata": [], "korunan": korunan,
                    "atlanan": len(hedefler) - korunan}

        # 2) Ceviri (TRANSACTION DISI — ag).
        alan_sonuclari: dict[str, dict[str, str]] = {}
        genel_hata: str | None = None
        if not provider.hazir:
            genel_hata = "ceviri saglayicisi yapilandirilmamis"
        else:
            for alan, metin in orijinal.items():
                try:
                    alan_sonuclari[alan] = provider.translate(
                        metin, kaynak_dil, list(cevrilecek)
                    )
                except TranslationError as exc:
                    genel_hata = str(exc)
                    break
                except Exception as exc:  # saglayicidan beklenmeyen hata
                    genel_hata = f"{type(exc).__name__}: {exc}"
                    logger.exception("ceviri saglayicisi beklenmeyen hata verdi")
                    break

        # 3) Yazim (kisa transaction). Bir dil TUM alanlarda basarili degilse
        #    'hata' isaretlenir — YARIM ceviri servis edilmez.
        cevrilen: list[str] = []
        hatali: list[str] = []
        with conn.transaction():
            conn.execute(
                "SELECT set_config('app.current_tenant_id', %s, true)",
                (str(tenant_id),),
            )
            for dil in cevrilecek:
                if genel_hata is not None:
                    _yaz(conn, t, entity_id, tenant_id, dil, alanlar={},
                         durum=ceviri.DURUM_HATA, kaynak_hash_=h,
                         hata_mesaji=genel_hata)
                    hatali.append(dil)
                    continue
                cevrilmis = {
                    alan: alan_sonuclari.get(alan, {}).get(dil)
                    for alan in orijinal
                }
                eksik = [a for a, v in cevrilmis.items() if v is None]
                if eksik:
                    _yaz(conn, t, entity_id, tenant_id, dil, alanlar={},
                         durum=ceviri.DURUM_HATA, kaynak_hash_=h,
                         hata_mesaji=f"eksik alan: {','.join(eksik)}")
                    hatali.append(dil)
                else:
                    _yaz(
                        conn, t, entity_id, tenant_id, dil,
                        alanlar={a: v for a, v in cevrilmis.items() if v is not None},
                        durum=ceviri.DURUM_HAZIR, kaynak_hash_=h, hata_mesaji=None,
                    )
                    cevrilen.append(dil)

    logger.info(
        "ceviri bitti %s/%s: cevrilen=%s hata=%s korunan=%d",
        tip_ad, entity_id, cevrilen, hatali, korunan,
    )
    return {
        "cevrilen": cevrilen,
        "hata": hatali,
        "korunan": korunan,
        "atlanan": len(hedefler) - len(cevrilecek) - korunan,
    }
