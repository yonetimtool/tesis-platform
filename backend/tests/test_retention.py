"""KVKK saklama & imha motoru (WP2) — retention task + sakin anonimlestirme.

Zaman "dondurma": satirlar owner_conn ile GERI TARIHLI (esik otesi) ve GUNCEL
olarak eklenir; run_retention() gercek now() - make_interval ile calisir, boylece
YALNIZ esigi gecenler islenir. run_retention app.retention'dan dogrudan cagrilir
(pytest api container'inda kosar; OWNER_DSN/APP_DSN env'de).
"""
from __future__ import annotations

import uuid

import pytest

from app.retention import run_retention


def _uid(owner_conn, tid, role):
    return owner_conn.execute(
        "SELECT id FROM app_user WHERE tenant_id=%s AND role=%s LIMIT 1", (str(tid), role)
    ).fetchone()[0]


def _exists(owner_conn, table, row_id):
    return owner_conn.execute(
        f"SELECT count(*) FROM {table} WHERE id=%s", (str(row_id),)
    ).fetchone()[0]


def test_retention_siler_ve_anonimlestirir_esik_hassas(world, owner_conn):
    tid = world["a"]
    admin_id = _uid(owner_conn, tid, "admin")
    resident_id = _uid(owner_conn, tid, "resident")

    unit_id = owner_conn.execute(
        "INSERT INTO unit (tenant_id, no, blok) VALUES (%s, %s, 'A') RETURNING id",
        (str(tid), f"RT-{uuid.uuid4().hex[:5]}"),
    ).fetchone()[0]

    old_visitor = uuid.uuid4()
    new_visitor = uuid.uuid4()
    for vid, age in ((old_visitor, "30 months"), (new_visitor, "1 month")):
        owner_conn.execute(
            "INSERT INTO visitor (id, tenant_id, unit_id, ziyaretci_ad, "
            "kaydeden_user_id, target_resident_user_id, created_at) "
            f"VALUES (%s, %s, %s, 'Ziyaretci', %s, %s, now() - interval '{age}')",
            (str(vid), str(tid), str(unit_id), str(admin_id), str(resident_id)),
        )

    # Cozulmus talep (36 ay otesi) -> anonimlestirilecek; guncel cozulmus KALIR.
    old_complaint = uuid.uuid4()
    new_complaint = uuid.uuid4()
    for cid, age in ((old_complaint, "40 months"), (new_complaint, "1 month")):
        owner_conn.execute(
            "INSERT INTO complaint (id, tenant_id, acan_user_id, baslik, mesaj, durum, "
            "created_at, updated_at) "
            f"VALUES (%s, %s, %s, 'Gizli Baslik', 'Gizli mesaj icerigi', 'cozuldu', "
            f"now() - interval '{age}', now() - interval '{age}')",
            (str(cid), str(tid), str(resident_id)),
        )

    # Eski denetim satiri (24 ay otesi) -> purge; guncel KALIR.
    old_audit = uuid.uuid4()
    owner_conn.execute(
        "INSERT INTO audit_log (id, tenant_id, action, ts) "
        "VALUES (%s, %s, 'login_ok', now() - interval '30 months')",
        (str(old_audit), str(tid)),
    )

    result = run_retention()

    # Ziyaretci: eski gitti, yeni kaldi (esik hassasiyeti).
    assert _exists(owner_conn, "visitor", old_visitor) == 0
    assert _exists(owner_conn, "visitor", new_visitor) == 1

    # Talep: eski anonimlestirildi (satir KALIR), yeni dokunulmadi.
    old_row = owner_conn.execute(
        "SELECT baslik, mesaj FROM complaint WHERE id=%s", (str(old_complaint),)
    ).fetchone()
    assert old_row == ("(arşivlendi)", "(arşivlendi)")
    new_row = owner_conn.execute(
        "SELECT baslik, mesaj FROM complaint WHERE id=%s", (str(new_complaint),)
    ).fetchone()
    assert new_row == ("Gizli Baslik", "Gizli mesaj icerigi")

    # Denetim: eski purge edildi + erasure_run sistem kaydi yazildi.
    assert _exists(owner_conn, "audit_log", old_audit) == 0
    er = owner_conn.execute(
        "SELECT count(*) FROM audit_log WHERE action='erasure_run' "
        "AND actor_rol='system' AND tenant_id IS NULL"
    ).fetchone()[0]
    assert er >= 1
    assert result["visitors"] >= 1 and result["tickets_anonymized"] >= 1


def test_resident_erasure_anonimlestirir_defteri_korur(world, client, owner_conn):
    """KVKK silme: ledger referansi olan sakin ANONIMLESTIRILIR (silinmez);
    kimlik alanlari temizlenir, finansal/ticket satiri KALIR, audit yazilir."""
    tid = world["a"]
    resident_id = _uid(owner_conn, tid, "resident")

    # Ledger referansi yarat: sakin bir talep acmis (acan_user_id RESTRICT) ->
    # hard-delete bloklanir, anonimlestirme yoluna dusulur.
    complaint_id = uuid.uuid4()
    owner_conn.execute(
        "INSERT INTO complaint (id, tenant_id, acan_user_id, baslik, mesaj, durum) "
        "VALUES (%s, %s, %s, 'Arizali asansor', 'Detay', 'acik')",
        (str(complaint_id), str(tid), str(resident_id)),
    )

    admin = {
        "Authorization": "Bearer "
        + client.post(
            "/auth/login",
            json={"tenant_slug": world["slug_a"], "email": world["admin_a"]["email"],
                  "password": world["admin_a"]["password"]},
        ).json()["access_token"]
    }
    r = client.delete(f"/residents/{resident_id}", headers=admin)
    assert r.status_code == 200, r.text
    assert r.json()["deleted"] is False  # ledger var -> anonimlestirildi

    ad, email, telefon, aktif, pset = owner_conn.execute(
        "SELECT ad, email, telefon, is_active, password_set FROM app_user WHERE id=%s",
        (str(resident_id),),
    ).fetchone()
    assert ad == "Silinmiş Kullanıcı"
    assert email is None and telefon is None
    assert aktif is False and pset is False

    # Ledger/ticket KORUNDU (yazar anonim kullaniciya isaret eder).
    assert _exists(owner_conn, "complaint", complaint_id) == 1

    # Denetim: resident_erasure yazildi.
    assert owner_conn.execute(
        "SELECT count(*) FROM audit_log WHERE tenant_id=%s AND action='resident_erasure' "
        "AND resource_id=%s",
        (str(tid), str(resident_id)),
    ).fetchone()[0] == 1
