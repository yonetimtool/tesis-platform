"""(P251 §5b) Rezervasyon alanina istege bagli gorsel.

Olculen: presign anahtariyla olusturulan alan listede `foto_url` doner;
baska tesisin anahtari 422; PATCH null gorseli kaldirir; gorselsiz alan
eskisi gibi calisir. Sakin listede gorseli gorur.
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


def _anahtar(client, h):
    r = client.post("/uploads/presign", headers=h,
                    json={"content_type": "image/png", "dosya_adi": "havuz.png"})
    assert r.status_code == 200, r.text
    return r.json()["foto_key"]


def test_alan_gorseli_olustur_listele_kaldir(client, world):
    y = _h(client, world["slug_a"], world["yonetici_a"])
    sakin = _h(client, world["slug_a"], world["resident_a"])
    key = _anahtar(client, y)
    ad = f"Havuz {uuid.uuid4().hex[:6]}"
    r = client.post("/common-areas", headers=y, json={"ad": ad, "foto_key": key})
    assert r.status_code == 201, r.text
    alan = r.json()
    assert alan["foto_key"] == key
    assert alan["foto_url"] and key.split("/")[-1] in alan["foto_url"]

    gorunen = next(a for a in client.get("/common-areas", headers=sakin,
                                         params={"limit": 200}).json()["items"]
                   if a["id"] == alan["id"])
    assert gorunen["foto_url"]

    r = client.patch(f"/common-areas/{alan['id']}", headers=y, json={"foto_key": None})
    assert r.status_code == 200, r.text
    assert r.json()["foto_key"] is None and r.json()["foto_url"] is None


def test_alan_gorseli_baska_tesisin_anahtari_422(client, world):
    y = _h(client, world["slug_a"], world["yonetici_a"])
    yabanci = f"{uuid.uuid4()}/tasks/x.png"
    r = client.post("/common-areas", headers=y,
                    json={"ad": f"Teras {uuid.uuid4().hex[:6]}", "foto_key": yabanci})
    assert r.status_code == 422, r.text
    alan = client.post("/common-areas", headers=y,
                       json={"ad": f"Salon {uuid.uuid4().hex[:6]}"}).json()
    assert alan["foto_url"] is None
    assert client.patch(f"/common-areas/{alan['id']}", headers=y,
                        json={"foto_key": yabanci}).status_code == 422
