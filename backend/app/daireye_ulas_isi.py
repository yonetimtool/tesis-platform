"""(P249 §3) DAIREYE ULASMA BEAT ISLERI — onay suresi ve sesli mesaj imhasi.

* ONAY SURESI (dakikada bir): `bekliyor` durumundaki ziyaretci onay
  talebinin suresi dolduysa `cevap_yok` yapilir ve kaydi acan guvenlige
  "cevap yok" bildirimi gider. Kosullu UPDATE: sakin ayni anda yanit
  verirse ikisinden biri kazanir, cift bildirim olmaz.
* SESLI MESAJ IMHASI (gecede bir): `SES_SAKLAMA_GUN`den eski mesajlarin
  DOSYASI silinir, satir "silindi" isaretlenir (KVKK: amac kapidaki anlik
  durumu iletmekti; sonrasinda saklamanin gerekcesi yok).

Yalniz ISI OLAN tesisler taranir (sahip baglantisiyla tek sorgu).
"""
from __future__ import annotations

import logging

import psycopg

from .config import settings

logger = logging.getLogger(__name__)


def onay_suresi_dolanlar() -> dict:
    from psycopg.types.json import Jsonb

    from .push_metinleri import push_govdesi
    from .scheduler.notify import dispatch_external

    ozet = {"cevap_yok": 0}
    with psycopg.connect(settings.owner_dsn, autocommit=True, connect_timeout=10) as conn:
        tesisler = [
            r[0]
            for r in conn.execute(
                "SELECT DISTINCT tenant_id FROM visitor "
                "WHERE onay_durum = 'bekliyor' AND onay_son_at <= now()"
            ).fetchall()
        ]
    if not tesisler:
        return ozet
    with psycopg.connect(settings.app_dsn, connect_timeout=10) as conn:
        for tid in tesisler:
            try:
                with conn.transaction():
                    conn.execute(
                        "SELECT set_config('app.current_tenant_id', %s, true)", (str(tid),)
                    )
                    satirlar = conn.execute(
                        "UPDATE visitor v SET onay_durum = 'cevap_yok' "
                        "FROM unit u WHERE u.id = v.unit_id AND v.tenant_id = %s "
                        "AND v.onay_durum = 'bekliyor' AND v.onay_son_at <= now() "
                        "RETURNING v.id, v.kaydeden_user_id, v.ziyaretci_ad, u.no",
                        (tid,),
                    ).fetchall()
                    for vid, kaydeden, ad, no in satirlar:
                        veri = {"ad": ad, "daire": no}
                        conn.execute(
                            "INSERT INTO notification (tenant_id, user_id, tip, mesaj, "
                            "mesaj_kimlik, mesaj_veri) VALUES (%s, %s, "
                            "'ziyaretci_onay_yaniti', %s, 'ziyaretci_onay_cevap_yok', %s)",
                            (tid, kaydeden,
                             push_govdesi("ziyaretci_onay_cevap_yok", "tr", veri),
                             Jsonb(veri)),
                        )
                        dispatch_external(
                            "ziyaretci_onay_cevap_yok",
                            tenant_id=tid,
                            target_user_ids=[kaydeden],
                            params=veri,
                            data={"tip": "ziyaretci_onay_yaniti", "visitor_id": str(vid)},
                        )
                        ozet["cevap_yok"] += 1
            except Exception:
                logger.exception("[ziyaretci-onay] sure isleme hatasi (tesis=%s)", tid)
    return ozet


def sesli_mesaj_imhasi(gun: int | None = None) -> dict:
    from .routers.daireye_ulas import SES_SAKLAMA_GUN
    from .storage import delete_objects

    gun = SES_SAKLAMA_GUN if gun is None else gun
    ozet = {"silinen": 0}
    with psycopg.connect(settings.owner_dsn, autocommit=True, connect_timeout=10) as conn:
        satirlar = conn.execute(
            "SELECT id, depo_anahtari FROM daire_sesli_mesaj "
            "WHERE silindi_at IS NULL AND created_at < now() - make_interval(days => %s)",
            (gun,),
        ).fetchall()
        # Silme istemci tarafinda basarisiz olmus dosyalar da (anahtari
        # duran ama "silindi" isaretli) burada tekrar denenir.
        yetim = conn.execute(
            "SELECT id, depo_anahtari FROM daire_sesli_mesaj "
            "WHERE silindi_at IS NOT NULL AND depo_anahtari IS NOT NULL"
        ).fetchall()
        hepsi = satirlar + yetim
        anahtarlar = [k for _, k in hepsi if k]
        if anahtarlar:
            try:
                delete_objects(anahtarlar)
            except Exception:
                logger.exception("[sesli-mesaj] depodan silinemedi; yarin tekrar")
                return ozet
        if hepsi:
            conn.execute(
                "UPDATE daire_sesli_mesaj SET depo_anahtari = NULL, "
                "silindi_at = COALESCE(silindi_at, now()) WHERE id = ANY(%s)",
                ([i for i, _ in hepsi],),
            )
        ozet["silinen"] = len(satirlar)
    return ozet
