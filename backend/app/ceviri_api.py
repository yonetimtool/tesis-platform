"""Ceviri — ISTEK yolu yardimcilari (async SQLAlchemy, RLS altinda).

Istek yolu ceviri YAPMAZ (ag cagrisi istegi yavaslatmaz/dusuremez): yalnizca
  * yazmada: hedef diller icin `bekliyor` satirlarini ACAR ve isi kuyruklar,
  * okumada: istenen dilin cevirisini (tek sorguda, toplu) getirir.

Satirlar icerik ile AYNI transaction'da acilir: boylece kayit basarili olur
olmaz okuma yolu `durum='bekliyor'` gorur (kuyruk/worker calismasa bile
istemci "çeviri hazırlanıyor" diyebilir).
"""
from __future__ import annotations

import json
import uuid
from collections.abc import Mapping, Sequence

from sqlalchemy import bindparam, text
from sqlalchemy.ext.asyncio import AsyncSession

from . import ceviri
from .ceviri_service import enqueue_ceviri


async def ceviri_isaretle_ve_kuyrukla(
    db: AsyncSession,
    *,
    tip_ad: str,
    entity_id: uuid.UUID,
    tenant_id: uuid.UUID,
    orijinal: Mapping[str, str],
    kaynak_dil: str = ceviri.VARSAYILAN_DIL,
) -> None:
    """Hedef diller icin `bekliyor` satirlarini acar; isi kuyruga verir.

    ELLE DUZELTME KURALI tek SQL ifadesinde: `DO UPDATE ... WHERE NOT
    (elle_duzeltildi AND kaynak_hash = EXCLUDED.kaynak_hash)`. Yani elle
    duzeltilmis bir ceviri, kaynak METIN degismediyse (yalniz foto/tarih/sira
    duzenlenmisse) OLDUGU GIBI kalir; kaynak degistiyse `bekliyor`a duser ve
    yeniden cevrilir.

    Kuyruklama BASARISIZ olsa bile istisna YUKSELMEZ (bkz. enqueue_ceviri).
    """
    t = ceviri.tip(tip_ad)
    h = ceviri.kaynak_hash(orijinal)
    hedefler = ceviri.hedef_diller(kaynak_dil)
    if not hedefler:
        return

    sql = text(
        f"""
        INSERT INTO {t.ceviri_tablo}
            (tenant_id, {t.fk_kolon}, dil, alanlar, durum, cevirildi_mi,
             elle_duzeltildi, kaynak_hash, hata_mesaji)
        VALUES (:tenant_id, :entity_id, :dil, CAST(:alanlar AS jsonb),
                CAST('bekliyor' AS ceviri_durum), true, false, :kaynak_hash, NULL)
        ON CONFLICT (tenant_id, {t.fk_kolon}, dil) DO UPDATE
           SET alanlar = CAST('{{}}' AS jsonb),
               durum = CAST('bekliyor' AS ceviri_durum),
               cevirildi_mi = true,
               elle_duzeltildi = false,
               kaynak_hash = EXCLUDED.kaynak_hash,
               hata_mesaji = NULL,
               updated_at = now()
         WHERE NOT ({t.ceviri_tablo}.elle_duzeltildi
                    AND {t.ceviri_tablo}.kaynak_hash = EXCLUDED.kaynak_hash);
        """
    )
    await db.execute(
        sql,
        [
            {
                "tenant_id": tenant_id,
                "entity_id": entity_id,
                "dil": dil,
                "alanlar": json.dumps({}),
                "kaynak_hash": h,
            }
            for dil in hedefler
        ],
    )
    enqueue_ceviri(tip_ad, entity_id, tenant_id)


async def yerel_harita(
    db: AsyncSession,
    *,
    tip_ad: str,
    objeler: Sequence[object],
    accept_language: str | None,
    istek_dil: str | None = None,
) -> dict[uuid.UUID, ceviri.Yerel]:
    """Icerik nesneleri -> id basina yerelestirme karari.

    Istenen dil kayit BASINA hesaplanir (kaynak dil satirdan gelir), sonra ayni
    dili isteyen kayitlar TEK sorguda cekilir — liste ucunda N+1 yok. Kaynak dil
    istendiginde (en sik durum: tr istemci) hic ceviri sorgusu ACILMAZ.
    """
    t = ceviri.tip(tip_ad)
    if not objeler:
        return {}

    # 1) Kayit basina istenen dil.
    istenen: dict[uuid.UUID, str] = {}
    kaynak: dict[uuid.UUID, str] = {}
    for obj in objeler:
        kaynak_dil = getattr(obj, "kaynak_dil", None) or ceviri.VARSAYILAN_DIL
        oid = getattr(obj, "id")
        kaynak[oid] = kaynak_dil
        istenen[oid] = ceviri.dil_sec(
            accept_language=accept_language,
            kaynak_dil=kaynak_dil,
            istek_dil=istek_dil,
        )

    # 2) Kaynak dilden FARKLI dil isteyenleri dile gore grupla ve topluca cek.
    satirlar: dict[uuid.UUID, ceviri.CeviriSatiri] = {}
    dile_gore: dict[str, list[uuid.UUID]] = {}
    for oid, dil in istenen.items():
        if dil != kaynak[oid]:
            dile_gore.setdefault(dil, []).append(oid)
    for dil, idler in dile_gore.items():
        satirlar.update(
            await ceviriler_getir(db, tip_ad=tip_ad, entity_ids=idler, dil=dil)
        )

    # 3) Karar (saf).
    sonuc: dict[uuid.UUID, ceviri.Yerel] = {}
    for obj in objeler:
        oid = getattr(obj, "id")
        orijinal = {a: (getattr(obj, a, None) or "") for a in t.alanlar}
        sonuc[oid] = ceviri.yerelestir(
            orijinal=orijinal,
            satir=satirlar.get(oid),
            istenen_dil=istenen[oid],
            kaynak_dil=kaynak[oid],
        )
    return sonuc


def ceviri_uygula(
    out,
    *,
    tip_ad: str,
    yerel: ceviri.Yerel | None,
    kaynak_dil: str = ceviri.VARSAYILAN_DIL,
) -> None:
    """Yanit modelini yerelestirme kararina gore DOLDUR (yerinde degistirir).

    Metin alanlari secilen dille EZILIR; `orijinal` sozlugu yanitta HER ZAMAN
    bulunur (bkz. schemas.CevrilebilirOut). `out` cagrildiginda metin alanlari
    henuz ORIJINALDIR — `orijinal` bu yuzden ezmeden ONCE kopyalanir.
    """
    t = ceviri.tip(tip_ad)
    out.orijinal = {a: (getattr(out, a, None) or "") for a in t.alanlar}
    out.orijinal_dil = kaynak_dil
    out.gosterilen_dil = kaynak_dil
    if yerel is None:
        return
    for alan, deger in yerel.alanlar.items():
        if hasattr(out, alan):
            setattr(out, alan, deger)
    out.gosterilen_dil = yerel.dil
    out.ceviri_durumu = yerel.durum
    out.cevirildi_mi = yerel.cevirildi_mi


async def ceviriler_getir(
    db: AsyncSession,
    *,
    tip_ad: str,
    entity_ids: Sequence[uuid.UUID],
    dil: str,
) -> dict[uuid.UUID, ceviri.CeviriSatiri]:
    """Verilen icerikler icin TEK dildeki ceviri satirlari (tek sorgu).

    Liste uclarinda N+1 sorgu olmamasi icin toplu; kaynak dil istendiginde
    (ceviri gerekmez) hic sorgu ACILMAZ.
    """
    if not entity_ids:
        return {}
    t = ceviri.tip(tip_ad)
    sql = text(
        f"""
        SELECT {t.fk_kolon}, dil, alanlar, durum::text, cevirildi_mi,
               elle_duzeltildi, kaynak_hash
          FROM {t.ceviri_tablo}
         WHERE dil = :dil AND {t.fk_kolon} IN :ids
        """
    ).bindparams(bindparam("ids", expanding=True))
    satirlar = (
        await db.execute(sql, {"dil": dil, "ids": list(entity_ids)})
    ).all()
    return {
        r[0]: ceviri.CeviriSatiri(
            dil=r[1],
            alanlar=r[2] or {},
            durum=r[3],
            cevirildi_mi=r[4],
            elle_duzeltildi=r[5],
            kaynak_hash=r[6],
        )
        for r in satirlar
    }
