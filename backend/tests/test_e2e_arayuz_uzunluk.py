"""(E2E 2026-09, ARAYUZ-6) Serbest metin alanlarinin UST SINIRI.

Olculen: `POST /users {"ad": "a"*10000}` ve `POST /tasks {"ad": "a"*10000}`
201 donuyordu; 10.000 karakterlik kullanici adi web /tasks sayfasindaki
atanan secicisini 90.000 px'e tasirdi. Diger uclar (duyuru 200, talep 200,
personel 150) zaten sinirliydi; bu uclar geride kalmisti.

Sinir DOGRULAMADA (422) — veritabani `text` oldugu icin orada hicbir sey
durdurmuyordu. Hicbir satir YAZILMAZ: 422 govde dogrulamasinda doner.
"""
from __future__ import annotations

import uuid


def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _tel() -> str:
    return "+9055" + str(uuid.uuid4().int % 10**8).rjust(8, "0")


def test_GOREV_ADI_VE_ACIKLAMASI_SINIRLI(client, world):
    adm = _h(client, world["slug_a"], world["admin_a"])
    assert client.post("/tasks", headers=adm, json={"ad": "a" * 201}).status_code == 422
    assert (
        client.post("/tasks", headers=adm, json={"ad": "x", "aciklama": "a" * 5001}).status_code
        == 422
    )
    # SINIRDA kabul — sinir fazla dar degil.
    r = client.post("/tasks", headers=adm, json={"ad": "a" * 200, "aciklama": "b" * 5000})
    assert r.status_code == 201, r.text
    tid = r.json()["id"]
    # Guncelleme de ayni sinira tabi.
    assert (
        client.patch(f"/tasks/{tid}", headers=adm, json={"ad": "a" * 201}).status_code == 422
    )
    client.delete(f"/tasks/{tid}", headers=adm)


def test_KULLANICI_ADI_SINIRLI(client, world):
    adm = _h(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/users",
        headers=adm,
        json={
            "ad": "a" * 151,
            "email": f"uzun-{uuid.uuid4().hex[:8]}@acme.com",
            "telefon": _tel(),
            "role": "security",
        },
    )
    assert r.status_code == 422, r.text


def test_SAKIN_ADI_SINIRLI(client, world):
    adm = _h(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/residents",
        headers=adm,
        json={
            "unit_no": f"U-{uuid.uuid4().hex[:5]}",
            "ad": "a" * 151,
            "telefon": _tel(),
            "email": f"sakin-{uuid.uuid4().hex[:8]}@acme.com",
        },
    )
    assert r.status_code == 422, r.text
