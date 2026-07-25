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


# --------------------------------------------------------------------------- #
# Yeni tablolar (G1/G2): vehicle_pass + violation da RLS altinda mi?
# Tablo eklenip _enable_rls listesine yazilmayi UNUTMAK sessiz bir cross-tenant
# sizintisidir; bu test onu yakalar.
# --------------------------------------------------------------------------- #
import uuid as _uuid  # noqa: E402

import pytest  # noqa: E402


@pytest.fixture
def two_tenants_ops(owner_conn):
    """2 tenant + birer guvenlik kullanicisi + birer vehicle_pass/violation."""
    a, b = _uuid.uuid4(), _uuid.uuid4()
    with owner_conn.cursor() as cur:
        for tid, ad in ((a, "OPS-A"), (b, "OPS-B")):
            cur.execute(
                "INSERT INTO tenant (id, ad, slug) VALUES (%s,%s,%s)",
                (tid, ad, f"ops-{tid.hex[:8]}"),
            )
            cur.execute(
                "INSERT INTO app_user (tenant_id, ad, email, role) "
                "VALUES (%s,%s,%s,'security'::user_role) RETURNING id",
                (tid, f"{ad} Guard", f"g-{tid.hex[:8]}@ops.test"),
            )
            uid = cur.fetchone()[0]
            cur.execute(
                "INSERT INTO vehicle_pass (tenant_id, plaka, kaydeden_user_id) "
                "VALUES (%s,%s,%s)",
                (tid, f"{ad.replace('-', '')}{tid.hex[:4].upper()}", uid),
            )
            cur.execute(
                "INSERT INTO violation (tenant_id, baslik, olusturan_user_id) "
                "VALUES (%s,%s,%s)",
                (tid, f"{ad} ihlali", uid),
            )
    yield a, b
    with owner_conn.cursor() as cur:
        cur.execute("DELETE FROM tenant WHERE id IN (%s,%s)", (a, b))


@pytest.mark.parametrize("tablo", ["vehicle_pass", "violation"])
def test_yeni_tablolar_tenant_izole(app_conn, two_tenants_ops, tablo):
    a, b = two_tenants_ops

    _set_tenant(app_conn, a)
    rows = app_conn.execute(f"SELECT tenant_id FROM {tablo}").fetchall()
    assert len(rows) == 1 and rows[0][0] == a

    app_conn.rollback()  # local degiskeni sifirla

    _set_tenant(app_conn, b)
    rows = app_conn.execute(f"SELECT tenant_id FROM {tablo}").fetchall()
    assert len(rows) == 1 and rows[0][0] == b


@pytest.mark.parametrize("tablo", ["vehicle_pass", "violation"])
def test_yeni_tablolar_baglamsiz_bos(app_conn, two_tenants_ops, tablo):
    # app.current_tenant_id set edilmedi => guvenli varsayilan: 0 satir.
    assert app_conn.execute(f"SELECT tenant_id FROM {tablo}").fetchall() == []
