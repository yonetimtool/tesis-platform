"""(P240 §4) PERIYODIK ENTEGRASYON SAGLIK KONTROLU — beat isi.

Her tesisin AKTIF entegrasyonlarina TCP baglantisi dener (HTTP istegi
GONDERMEZ — bkz. `entegrasyon_saglik` modul basligi) ve durumu yazar.

===========================================================================
KOPUSTA BIR KEZ BILDIRIM
===========================================================================
`kopus_bildirildi_at` damgasi olmadan bu gorev, kopuk bir entegrasyon
icin GUNDE 96 bildirim gonderirdi (15 dakikada bir). Damga bir kopus
OLAYINI isaretler; baglanti geri gelince temizlenir ve bir sonraki kopus
yeniden bildirilir.

===========================================================================
PASIF ENTEGRASYON KONTROL EDILMEZ
===========================================================================
`aktif=false` olan bir entegrasyon bilincli olarak kapatilmistir;
"kopuk" demek, kullanicinin kendi kararini hata gibi gostermek olurdu.
"""
from __future__ import annotations

import datetime as dt
import logging
import uuid

import psycopg

from .config import settings
from .entegrasyon_saglik import baglanti_dene, simdi
from .push_metinleri import push_govdesi
from .scheduler.notify import dispatch_external

logger = logging.getLogger(__name__)

#: Bildirim alan roller — entegrasyonu yonetenler.
BILDIRIM_ROLLERI: tuple[str, ...] = ("admin", "yonetici")


def _tenantlar(owner_dsn: str) -> list[uuid.UUID]:
    with psycopg.connect(owner_dsn, autocommit=True, connect_timeout=10) as conn:
        return [r[0] for r in conn.execute("SELECT id FROM tenant").fetchall()]


def tum_tenantlar_icin(
    *, owner_dsn: str | None = None, app_dsn: str | None = None
) -> dict:
    """Donus: {"kontrol": n, "kopuk": m, "bildirim": k}."""
    owner_dsn = owner_dsn or settings.owner_dsn
    app_dsn = app_dsn or settings.app_dsn
    ozet = {"kontrol": 0, "kopuk": 0, "bildirim": 0}
    an = simdi()

    with psycopg.connect(app_dsn, connect_timeout=10) as conn:
        for tenant_id in _tenantlar(owner_dsn):
            with conn.transaction():
                conn.execute(
                    "SELECT set_config('app.current_tenant_id', %s, true)",
                    (str(tenant_id),),
                )
                satirlar = conn.execute(
                    "SELECT id, ad, endpoint_url, saglik, kopus_bildirildi_at "
                    "FROM integration WHERE aktif = true"
                ).fetchall()
                for ent_id, ad, url, onceki, bildirildi in satirlar:
                    sonuc = baglanti_dene(url)
                    ozet["kontrol"] += 1
                    if sonuc.bagli:
                        conn.execute(
                            "UPDATE integration SET saglik = 'bagli', "
                            "son_kontrol_at = %s, son_basarili_at = %s, "
                            "son_hata_kod = NULL, son_hata_ayrinti = NULL, "
                            "kopus_bildirildi_at = NULL WHERE id = %s",
                            (an, an, ent_id),
                        )
                        continue

                    ozet["kopuk"] += 1
                    conn.execute(
                        "UPDATE integration SET saglik = 'hata', "
                        "son_kontrol_at = %s, son_hata_kod = %s, "
                        "son_hata_ayrinti = %s WHERE id = %s",
                        (an, sonuc.hata_kod, sonuc.ayrinti, ent_id),
                    )
                    if bildirildi is not None:
                        continue  # bu kopus ZATEN bildirildi

                    veri = {"ad": ad or ""}
                    conn.execute(
                        "UPDATE integration SET kopus_bildirildi_at = %s "
                        "WHERE id = %s",
                        (an, ent_id),
                    )
                    # TEK SATIR, `user_id = NULL` — YONETIM ALARMI.
                    #
                    # Ilk yazimda her yoneticiye AYRI satir yazildi ve
                    # hicbiri GORUNMEDI: `routers/notifications._kapsam`
                    # yonetim rollerine YALNIZ `user_id IS NULL`
                    # satirlarini gosterir (kisiye ozel akis sakinindir).
                    # Yani kayit yaziliyordu ama kimse goremiyordu —
                    # test bunu yakaladi.
                    #
                    # Model de bunu soyluyor: entegrasyon kopmasi
                    # KISISEL bir olay degil, "kacirilan tur" gibi
                    # TESISE ait bir alarmdir.
                    conn.execute(
                        "INSERT INTO notification "
                        "(tenant_id, user_id, tip, mesaj, mesaj_kimlik, "
                        " mesaj_veri) "
                        "VALUES (%s, NULL, 'entegrasyon_koptu', %s, "
                        "        'entegrasyon_koptu', %s::jsonb)",
                        (
                            tenant_id,
                            push_govdesi("entegrasyon_koptu", "tr", veri),
                            _json(veri),
                        ),
                    )
                    # PUSH ROL UZERINDEN: kisi listesi burada cozulmez —
                    # rol degisirse liste de degismeli.
                    dispatch_external(
                        "entegrasyon_koptu",
                        tenant_id=tenant_id,
                        target_roles=list(BILDIRIM_ROLLERI),
                        params=veri,
                        data={"tip": "entegrasyon_koptu",
                              "integration_id": str(ent_id)},
                    )
                    ozet["bildirim"] += 1
    return ozet


def _json(veri: dict) -> str:
    import json

    return json.dumps(veri)


def _simdi_utc() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)
