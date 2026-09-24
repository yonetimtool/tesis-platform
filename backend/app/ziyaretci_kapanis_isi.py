"""(P247 §3) ZIYARETCI OTOMATIK KAPANISI — beat isi (saatte bir).

===========================================================================
OLCULEN KUSUR
===========================================================================
Ziyaretci kaydi `cikis_zamani IS NULL` oldugu surece "iceride" sayilir.
Cikisi damgalayacak TEK kisi kapidaki guvenlik; mobilde dugmesi yoktu
(P247 §3'te eklendi) ve dugme olsa bile unutulan cikislar olur. Unutulan
her kayit guvenlik ana ekranindaki "N iceride" sayacini SONSUZA dek
sisiriyordu — sayac bir sure sonra hicbir sey anlatmaz hale gelir.

===========================================================================
KURAL: 24 SAAT, "CIKIS KAYDEDILMEDI"
===========================================================================
* ESIK 24 SAAT (`ziyaretci_otomatik_kapanis_saat`), gun sonu DEGIL: gece
  kalan misafir (akraba, bakici) mesru bir durumdur; gece yarisi kapanisi
  onu "cikti" gosterirdi. 24 saat, ayni ziyaretin gece yarisini gecmesine
  izin verir ama bir gunden eski kaydi temizler.
* KAPANIS YALAN SOYLEMEZ: `cikis_zamani` kapanis ani ile doldurulur (kayit
  artik iceride sayilmaz) ama `cikis_otomatik = true` "cikisi kimse
  gormedi" der. Ekranlar "Cikis kaydedilmedi" yazar; etkinlik akisi bu
  kaydi "ziyaretci cikti" olarak gostermez.
* BILDIRIM YOK: bu bir temizlik isidir; sakine "ziyaretciniz cikti"
  demek (gercekte bilmedigimiz bir seyi) soylemek olurdu.
* IDEMPOTENT: yalniz `cikis_zamani IS NULL` satirlar guncellenir; guvenlik
  ayni anda cikis damgalarsa kosullu UPDATE birini kazandirir.

SAATTE BIR: esik saat cozunurluklu; daha sik kosmak yeni bilgi uretmez,
gunde bir ise kaydi 48 saate kadar acik birakirdi.
"""
from __future__ import annotations

import logging

import psycopg

from .config import settings

logger = logging.getLogger(__name__)


def tum_tenantlar_icin(
    *,
    owner_dsn: str | None = None,
    app_dsn: str | None = None,
    esik_saat: int | None = None,
    tenant_ids: list | None = None,
) -> dict:
    """Donus: {"taranan_tesis": n, "kapatilan": k}."""
    owner_dsn = owner_dsn or settings.owner_dsn
    app_dsn = app_dsn or settings.app_dsn
    saat = settings.ziyaretci_otomatik_kapanis_saat if esik_saat is None else esik_saat
    ozet = {"taranan_tesis": 0, "kapatilan": 0}

    if tenant_ids is not None:
        # Test/elle kosum: yalniz verilen tesisler (canli sunucudaki diger
        # tesislerin kayitlarina dokunmadan olcmek icin).
        tenantlar = list(tenant_ids)
    else:
        with psycopg.connect(owner_dsn, autocommit=True, connect_timeout=10) as conn:
            tenantlar = [r[0] for r in conn.execute("SELECT id FROM tenant").fetchall()]

    # RLS altinda (app rolu) tesis tesis: bir tesisin hatasi digerlerini
    # durdurmaz (bakim hatirlatma deseni).
    with psycopg.connect(app_dsn, connect_timeout=10) as conn:
        for tenant_id in tenantlar:
            ozet["taranan_tesis"] += 1
            try:
                with conn.transaction():
                    conn.execute(
                        "SELECT set_config('app.current_tenant_id', %s, true)",
                        (str(tenant_id),),
                    )
                    cur = conn.execute(
                        "UPDATE visitor SET cikis_zamani = now(), cikis_otomatik = true "
                        "WHERE tenant_id = %s AND cikis_zamani IS NULL "
                        "AND created_at < now() - make_interval(hours => %s)",
                        (tenant_id, saat),
                    )
                    ozet["kapatilan"] += cur.rowcount or 0
            except Exception:  # pragma: no cover - tesis basina yalitim
                logger.exception("ziyaretci otomatik kapanis basarisiz: %s", tenant_id)
    if ozet["kapatilan"]:
        logger.info("ZIYARETCI_OTOMATIK_KAPANIS: %s", ozet)
    return ozet
