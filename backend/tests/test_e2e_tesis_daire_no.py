"""(E2E 2026-09 / TESIS-16 + ANA-4 + TESIS-18) Tekil daire no bicimi ve
sakin eklemede olmayan daire.

OLCULEN:
  * `POST /units {"no":"11","blok":"A"}` -> "11" (toplu "A-11" uretir),
  * `{"no":"B-12","blok":"A"}` -> 201 (B-12 A bloguna yazildi),
  * B blokta "1" -> "Daire no bu tesiste zaten kayitli" (neden belirsiz),
  * `POST /residents {"unit_no":"Z-99"}` (blok yok) -> BLOKSUZ daire acildi.
"""
from __future__ import annotations

import uuid


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _blok(client, h) -> str:
    ad = "E" + uuid.uuid4().hex[:5].upper()
    r = client.post("/blocks", headers=h, json={"ad": ad})
    assert r.status_code in (200, 201), r.text
    return ad


def test_rakam_no_blok_onekiyle_yazilir(client, world):
    h = _h(client, world["slug_a"], world["admin_a"])
    blok = _blok(client, h)
    r = client.post("/units", headers=h, json={"no": "11", "blok": blok})
    assert r.status_code == 201, r.text
    assert r.json()["no"] == f"{blok}-11"


def test_ayni_rakam_farkli_blokta_cakismaz(client, world):
    """ANA-4: B blokta "1" artik A blogundaki "1" ile cakismaz."""
    h = _h(client, world["slug_a"], world["admin_a"])
    a, b = _blok(client, h), _blok(client, h)
    ra = client.post("/units", headers=h, json={"no": "1", "blok": a})
    rb = client.post("/units", headers=h, json={"no": "1", "blok": b})
    assert ra.status_code == 201 and rb.status_code == 201, (ra.text, rb.text)
    assert {ra.json()["no"], rb.json()["no"]} == {f"{a}-1", f"{b}-1"}


def test_cakisma_metni_numarayi_ve_blok_onekini_soyler(client, world):
    h = _h(client, world["slug_a"], world["admin_a"])
    blok = _blok(client, h)
    assert client.post("/units", headers=h, json={"no": "5", "blok": blok}).status_code == 201
    r = client.post("/units", headers=h, json={"no": "5", "blok": blok})
    assert r.status_code == 409
    mesaj = r.json()["error"]["message"]
    assert f"{blok}-5" in mesaj and "önek" in mesaj


def test_baska_blok_onekli_no_reddedilir(client, world):
    h = _h(client, world["slug_a"], world["admin_a"])
    a, b = _blok(client, h), _blok(client, h)
    r = client.post("/units", headers=h, json={"no": f"{b}-12", "blok": a})
    assert r.status_code == 422, r.text
    assert b in r.json()["error"]["message"]


def test_serbest_onek_blok_iddiasi_tasimaz(client, world):
    """"DV-1" gibi numaralar kayitli bir blok adi degilse aynen kalir."""
    h = _h(client, world["slug_a"], world["admin_a"])
    blok = _blok(client, h)
    no = f"Q{uuid.uuid4().hex[:4].upper()}-7"
    r = client.post("/units", headers=h, json={"no": no, "blok": blok})
    assert r.status_code == 201, r.text
    assert r.json()["no"] == no


def test_patch_no_ayni_kural(client, world):
    h = _h(client, world["slug_a"], world["admin_a"])
    a, b = _blok(client, h), _blok(client, h)
    u = client.post("/units", headers=h, json={"no": "3", "blok": a}).json()
    r = client.patch(f"/units/{u['id']}", headers=h, json={"no": "4"})
    assert r.status_code == 200 and r.json()["no"] == f"{a}-4", r.text
    r = client.patch(f"/units/{u['id']}", headers=h, json={"no": f"{b}-4"})
    assert r.status_code == 422, r.text


def _tel():
    return f"+9053{uuid.uuid4().int % 10**8:08d}"


def test_sakin_eklemede_olmayan_bloksuz_daire_422(client, world, owner_conn):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    no = f"Z-{uuid.uuid4().hex[:5]}"
    r = client.post("/residents", headers=h, json={
        "telefon": _tel(), "unit_no": no,
        "email": f"z{uuid.uuid4().hex[:8]}@ornek.com"})
    assert r.status_code == 422, r.text
    assert no in r.json()["error"]["message"]
    # Hayalet daire YARATILMADI.
    say = owner_conn.execute(
        "SELECT count(*) FROM unit WHERE tenant_id=%s AND no=%s", (world["a"], no)
    ).fetchone()[0]
    assert say == 0


def test_sakin_eklemede_blok_verilirse_kanonik_daire_acilir(client, world):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    ah = _h(client, world["slug_a"], world["admin_a"])
    blok = _blok(client, ah)
    r = client.post("/residents", headers=h, json={
        "telefon": _tel(), "unit_no": "8", "blok": blok,
        "email": f"k{uuid.uuid4().hex[:8]}@ornek.com"})
    assert r.status_code == 201, r.text
    assert r.json()["unit_no"] == f"{blok}-8"
