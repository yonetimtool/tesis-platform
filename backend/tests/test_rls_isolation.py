"""RLS tenant izolasyon testi (KABUL KRITERI).

Senaryo (/contracts/db/README.md ile uyumlu):
  a) owner ile 2 tenant + checkpoint'lar olusturulur (fixture: two_tenants).
  b) app_rw + app.current_tenant_id = A  -> SADECE A'nin satirlari gorunur.
  c) app_rw + app.current_tenant_id = B  -> SADECE B'nin satirlari gorunur.
  d) app_rw + app.current_tenant_id SET DEGIL -> hicbir satir gorunmez.
"""
from __future__ import annotations


def _set_tenant(conn, tenant_id) -> None:
    # set_config(..., is_local=true) == SET LOCAL; transaction kapsaminda gecerli.
    conn.execute(
        "SELECT set_config('app.current_tenant_id', %s, true)", (str(tenant_id),)
    )


def _visible_checkpoints(conn):
    return conn.execute("SELECT tenant_id FROM checkpoint").fetchall()


def test_app_rw_sees_only_tenant_a(app_conn, two_tenants):
    tenant_a, _ = two_tenants
    _set_tenant(app_conn, tenant_a)

    rows = _visible_checkpoints(app_conn)
    assert len(rows) == 2
    assert all(r[0] == tenant_a for r in rows)


def test_app_rw_sees_only_tenant_b(app_conn, two_tenants):
    _, tenant_b = two_tenants
    _set_tenant(app_conn, tenant_b)

    rows = _visible_checkpoints(app_conn)
    assert len(rows) == 3
    assert all(r[0] == tenant_b for r in rows)


def test_app_rw_no_cross_tenant_leak(app_conn, two_tenants):
    tenant_a, tenant_b = two_tenants

    _set_tenant(app_conn, tenant_a)
    a_rows = _visible_checkpoints(app_conn)
    assert all(r[0] != tenant_b for r in a_rows)  # B'nin satirlari A'ya sizmaz

    app_conn.rollback()  # local degiskeni sifirla

    _set_tenant(app_conn, tenant_b)
    b_rows = _visible_checkpoints(app_conn)
    assert all(r[0] != tenant_a for r in b_rows)


def test_app_rw_no_tenant_context_no_rows(app_conn, two_tenants):
    # app.current_tenant_id hic set edilmedi => guvenli varsayilan: 0 satir.
    rows = _visible_checkpoints(app_conn)
    assert rows == []
