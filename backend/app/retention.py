"""KVKK saklama & imha motoru (WP2) — gecelik retention/imha.

Sync psycopg (scheduler/service.py deseni). Tenant enumerasyonu OWNER ile (RLS
bootstrap); tenant-kapsamli DELETE/ANONYMIZE app_rw + set_config('app.current_
tenant_id') ile (RLS izolasyonu). audit_log purge + sistem `erasure_run` kaydi
OWNER ile yazilir (append-only: app_rw audit satirini SILEMEZ; ayrica tenant-siz
sistem kaydi RLS'i bypass gerektirir).

Idempotent + partili (batch): esik gecen satirlar tekrar calistiginda zaten
gitmis olur. Foto (kargo) once MinIO'dan silinir, sonra DB satiri — depo/DB
tutarli kalir (MinIO erisilemezse o tenant'in kargo satirlari BU GECE silinmez).

meta/erasure_run: YALNIZ SAYILAR — kisisel veri yok.
"""
from __future__ import annotations

import json

import psycopg

from . import storage
from .config import settings


def _list_tenant_ids(owner_dsn: str) -> list[str]:
    """Tum tenant id'leri — OWNER ile (RLS bootstrap, salt-okuma)."""
    with psycopg.connect(owner_dsn, autocommit=True, connect_timeout=10) as conn:
        return [str(r[0]) for r in conn.execute("SELECT id FROM tenant").fetchall()]


def run_retention() -> dict:
    """Tum tenant'larda saklama sinirini gecen kisisel veriyi siler/anonimlestirir.
    Sonuc: sinif basina islenen satir sayilari (denetime yazilir)."""
    owner_dsn = settings.owner_dsn
    app_dsn = settings.app_dsn
    m = settings  # kisayol

    totals = {
        "visitors": 0,
        "kargo": 0,
        "kargo_photos": 0,
        "reservations": 0,
        "tickets_anonymized": 0,
        "audit_purged": 0,
    }

    tenant_ids = _list_tenant_ids(owner_dsn)

    # 1) Tenant-kapsamli veri (app_rw + RLS).
    with psycopg.connect(app_dsn, connect_timeout=10) as conn:
        for tid in tenant_ids:
            with conn.transaction():
                conn.execute(
                    "SELECT set_config('app.current_tenant_id', %s, true)", (tid,)
                )

                # Ziyaretci LOG'u (24 ay) — foto yok, dogrudan sil.
                totals["visitors"] += conn.execute(
                    "DELETE FROM visitor "
                    "WHERE created_at < now() - make_interval(months => %s)",
                    (m.retention_visitors_months,),
                ).rowcount

                # Kargo (24 ay): once foto anahtarlarini MinIO'dan sil, sonra satir.
                keys = [
                    row[0]
                    for row in conn.execute(
                        "SELECT foto_key FROM kargo "
                        "WHERE foto_key IS NOT NULL "
                        "AND created_at < now() - make_interval(months => %s)",
                        (m.retention_kargo_months,),
                    ).fetchall()
                ]
                photos_ok = True
                if keys:
                    try:
                        totals["kargo_photos"] += storage.delete_objects(keys)
                    except Exception:
                        # MinIO erisilemedi -> satirlari BU GECE silme (sonraki gece
                        # tekrar denenir; foto asla DB'siz ortada kalmaz).
                        photos_ok = False
                if photos_ok:
                    totals["kargo"] += conn.execute(
                        "DELETE FROM kargo "
                        "WHERE created_at < now() - make_interval(months => %s)",
                        (m.retention_kargo_months,),
                    ).rowcount

                # Rezervasyon (gecmis 24 ay) — tamamlanmis/iptal fark etmez, gecmis.
                totals["reservations"] += conn.execute(
                    "DELETE FROM rezervasyon "
                    "WHERE tarih < (current_date - make_interval(months => %s))",
                    (m.retention_reservations_months,),
                ).rowcount

                # Talep/sikayet (cozuldu/reddedildi, 36 ay) -> ANONIMLESTIR (satir
                # is-emri/defter butunlugu icin kalir; serbest metin arsivlenir).
                totals["tickets_anonymized"] += conn.execute(
                    "UPDATE complaint "
                    "SET baslik = '(arşivlendi)', mesaj = '(arşivlendi)', "
                    "    updated_at = now() "
                    "WHERE durum IN ('cozuldu', 'reddedildi') "
                    "AND updated_at < now() - make_interval(months => %s) "
                    "AND mesaj <> '(arşivlendi)'",
                    (m.retention_tickets_months,),
                ).rowcount

    # 2) audit_log purge (24 ay) + sistem erasure_run kaydi — OWNER ile.
    #    (app_rw audit_log'da DELETE yapamaz; tenant-siz kayit RLS bypass ister.)
    with psycopg.connect(owner_dsn, autocommit=True, connect_timeout=10) as conn:
        totals["audit_purged"] = conn.execute(
            "DELETE FROM audit_log WHERE ts < now() - make_interval(months => %s)",
            (m.retention_audit_months,),
        ).rowcount
        conn.execute(
            "INSERT INTO audit_log "
            "(tenant_id, actor_user_id, actor_rol, action, resource_type, meta) "
            "VALUES (NULL, NULL, 'system', 'erasure_run', 'retention', %s::jsonb)",
            (json.dumps(totals),),
        )

    return totals
