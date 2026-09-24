"""(E2E 2026-09 / TESIS-09) Turkce harf katlamali arama.

OLCULEN: `/units/ara?q=İkinci` -> [] (Python `"İ".lower()` = "i̇");
`/residents?q=kiraci` -> "Can Kiracı" bulunmuyordu (`ilike` ı/i katlamaz).
"""
from __future__ import annotations

import uuid

import pytest

from app.tr_arama import tr_kalip, tr_katla


def _giris(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_tr_katla_saf():
    assert tr_katla("İKİNCİ") == "ikinci"
    assert tr_katla("Kiracı") == "kiraci"
    assert tr_katla("ŞAHİN Öztürk Çağ Ünlü") == "sahin ozturk cag unlu"
    # Birlesik nokta (U+0307) URETILMEMELI.
    assert "̇" not in tr_katla("İ")
    # LIKE jokerleri kacislanir.
    assert tr_kalip("a%b") == "%a\\%b%"


@pytest.fixture
def turkce_sakin(client, world, owner_conn):
    ek = uuid.uuid4().hex[:6]
    no = f"A-T{ek}"
    ad = f"Burak İkinci Kiracı {ek}"
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO unit (tenant_id, no, blok) VALUES (%s,%s,'A') RETURNING id",
            (world["a"], no),
        )
        unit_id = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, email, password_hash, role) "
            "VALUES (%s,%s,%s,'x','resident'::user_role) RETURNING id",
            (world["a"], ad, f"tr-{ek}@ornek.com"),
        )
        uid = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO unit_resident (tenant_id, unit_id, user_id) VALUES (%s,%s,%s)",
            (world["a"], unit_id, uid),
        )
    return {"no": no, "ad": ad, "user_id": str(uid), "ek": ek}


@pytest.mark.parametrize("q", ["İkinci", "İKİNCİ", "ikinci", "IKINCI"])
def test_units_ara_turkce_buyuk_I_ile_bulur(client, world, turkce_sakin, q):
    h = _giris(client, world["slug_a"], world["guard_a"])
    r = client.get("/units/ara", headers=h, params={"q": f"{q} Kiraci {turkce_sakin['ek']}"})
    assert r.status_code == 200, r.text
    assert any(d["no"] == turkce_sakin["no"] for d in r.json()), (q, r.json())


@pytest.mark.parametrize("q", ["kiraci", "KIRACI", "Kiracı", "KİRACI"])
def test_residents_q_turkce_katlama(client, world, turkce_sakin, q):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    r = client.get("/residents", headers=h, params={"q": f"{q} {turkce_sakin['ek']}"})
    assert r.status_code == 200, r.text
    ids = {i["user_id"] for i in r.json()["items"]}
    assert turkce_sakin["user_id"] in ids, (q, r.json())
