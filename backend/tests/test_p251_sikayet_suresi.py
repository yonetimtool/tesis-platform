"""(P251 §3) Daire sikayet listesi "suresi dolmus" isaretini tasir.

Harita penceresi (`sikayet_harita_saat`) disindaki ACIK sikayet haritada
sayilmaz; ayrinti penceresi onu ayri gosterir. Tek kaynak: ayni ayar.
"""
from __future__ import annotations

import uuid


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_suresi_doldu_isareti(client, world, owner_conn):
    y = _h(client, world["slug_a"], world["yonetici_a"])
    unit = owner_conn.execute(
        "INSERT INTO unit (id, tenant_id, no, blok) VALUES (gen_random_uuid(), %s, %s, 'A') "
        "RETURNING id::text", (world["a"], f"S{uuid.uuid4().hex[:4]}")).fetchone()[0]
    eski_saat = owner_conn.execute(
        "SELECT sikayet_harita_saat FROM tenant WHERE id=%s", (world["a"],)).fetchone()[0]
    sakin = owner_conn.execute(
        "SELECT id::text FROM app_user WHERE tenant_id=%s AND email=%s",
        (world["a"], world["resident_a"]["email"])).fetchone()[0]
    owner_conn.execute("UPDATE tenant SET sikayet_harita_saat=24 WHERE id=%s", (world["a"],))
    try:
        yeni = owner_conn.execute(
            "INSERT INTO unit_complaint (tenant_id, target_unit_id, complainant_user_id, kategori, durum) "
            "VALUES (%s, %s, %s, 'gurultu', 'acik') RETURNING id::text",
            (world["a"], unit, sakin)).fetchone()[0]
        eski = owner_conn.execute(
            "INSERT INTO unit_complaint (tenant_id, target_unit_id, complainant_user_id, kategori, durum, created_at) "
            "VALUES (%s, %s, %s, 'gurultu', 'acik', now() - interval '3 days') RETURNING id::text",
            (world["a"], unit, sakin)).fetchone()[0]
        r = client.get("/unit-complaints", headers=y,
                       params={"target_unit_id": unit, "durum": "acik"})
        assert r.status_code == 200, r.text
        isaret = {i["id"]: i["suresi_doldu"] for i in r.json()["items"]}
        assert isaret == {yeni: False, eski: True}
        # Kimlik hala donmuyor (Rev-2 gizlilik kurali korunuyor).
        assert all("complainant_ad" not in i for i in r.json()["items"])
        # Pencere 0 (suresiz) -> hicbiri dolmus degil.
        owner_conn.execute("UPDATE tenant SET sikayet_harita_saat=0 WHERE id=%s", (world["a"],))
        r = client.get("/unit-complaints", headers=y, params={"target_unit_id": unit})
        assert all(i["suresi_doldu"] is False for i in r.json()["items"])
    finally:
        owner_conn.execute("UPDATE tenant SET sikayet_harita_saat=%s WHERE id=%s",
                           (eski_saat, world["a"]))
