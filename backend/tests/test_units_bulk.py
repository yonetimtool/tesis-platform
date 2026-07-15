"""Toplu daire olusturma (Parca B) — POST /units/bulk.

Yonetici/admin bir blok icin kat_sayisi × kat_basi_daire adet daireyi
baslangic_no'dan ARDISIK (kat kat) uretir. Zaten var olan no'lar atlanir.
Tek tek create/patch/delete DEGISMEDI (ayni router).
"""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _bulk(client, h, **body):
    return client.post("/units/bulk", headers=h, json=body)


def test_bulk_temel_numaralandirma_ve_katlar(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    blok = f"B{uuid.uuid4().hex[:3].upper()}"
    r = _bulk(client, yon, blok=blok, kat_sayisi=3, kat_basi_daire=2, baslangic_no=101)
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["bitis_no"] == 106  # 101 + 6 - 1
    assert body["atlanan"] == []
    olus = body["olusturulan"]
    assert len(olus) == 6
    # no + kat + sira dogru (kat kat, ardisik)
    by_no = {u["no"]: u for u in olus}
    assert set(by_no) == {f"{blok}-{n}" for n in range(101, 107)}
    assert by_no[f"{blok}-101"]["kat"] == 1 and by_no[f"{blok}-101"]["sira"] == 1
    assert by_no[f"{blok}-102"]["kat"] == 1 and by_no[f"{blok}-102"]["sira"] == 2
    assert by_no[f"{blok}-103"]["kat"] == 2 and by_no[f"{blok}-103"]["sira"] == 1
    assert by_no[f"{blok}-106"]["kat"] == 3 and by_no[f"{blok}-106"]["sira"] == 2
    # gercekten kaydedildiler (blok filtresiyle liste)
    listed = client.get("/units", headers=yon, params={"blok": blok, "limit": 200})
    assert listed.status_code == 200, listed.text
    all_nos = {u["no"] for u in listed.json()["items"]}
    assert {f"{blok}-101", f"{blok}-106"} <= all_nos


def test_bulk_var_olanlari_atlar(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    blok = f"C{uuid.uuid4().hex[:3].upper()}"
    # once tek daire olustur (A-201 cakisacak)
    pre = client.post(
        "/units", headers=admin, json={"no": f"{blok}-201", "blok": blok, "kat": 1, "sira": 1}
    )
    assert pre.status_code == 201, pre.text
    # toplu: 201..204 -> 201 atlanir, 202-204 olusur
    r = _bulk(client, admin, blok=blok, kat_sayisi=2, kat_basi_daire=2, baslangic_no=201)
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["atlanan"] == [f"{blok}-201"]
    assert {u["no"] for u in body["olusturulan"]} == {
        f"{blok}-202", f"{blok}-203", f"{blok}-204"
    }


def test_bulk_bloksuz_duz_numara(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    base = 900000 + int(uuid.uuid4().int % 1000)  # cakismasin diye yuksek/rasgele
    r = _bulk(client, yon, kat_sayisi=1, kat_basi_daire=3, baslangic_no=base)
    assert r.status_code == 201, r.text
    nos = {u["no"] for u in r.json()["olusturulan"]}
    assert nos == {str(base), str(base + 1), str(base + 2)}  # blok yok -> duz no
    assert all(u["blok"] is None for u in r.json()["olusturulan"])


def test_bulk_ust_sinir_422(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    # 501 daire > 500 -> 422
    r = _bulk(client, yon, blok="Z", kat_sayisi=501, kat_basi_daire=1, baslangic_no=1)
    assert r.status_code == 422, r.text


def test_bulk_rbac_yalniz_yonetim(client, world):
    for role in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        r = _bulk(client, h, blok="X", kat_sayisi=1, kat_basi_daire=1, baslangic_no=1)
        assert r.status_code == 403, (role, r.status_code)
