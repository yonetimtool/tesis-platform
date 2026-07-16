"""SOS/acil-durum ozelligi TAMAMEN kaldirildi — hicbir rol icin yok.

Bu dosya bir REGRESYON KAPISIDIR: ozellik geri sizarsa kirilir.
"""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={
            "tenant_slug": slug,
            "email": cred["email"],
            "password": cred["password"],
        },
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_emergency_uclari_404(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])

    assert client.post("/emergency", json={}, headers=admin).status_code == 404
    assert client.get("/emergency", headers=admin).status_code == 404
    assert (
        client.patch(
            f"/emergency/{uuid.uuid4()}", json={"durum": "cozuldu"}, headers=admin
        ).status_code
        == 404
    )


def test_tenant_settings_acil_durum_telefon_tasimaz(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.get("/tenant/settings", headers=admin)
    assert r.status_code == 200, r.text
    assert "acil_durum_telefon" not in r.json()


def test_acil_durum_telefon_patch_edilemez(client, world):
    """Kolon yok; sema de kabul etmemeli (bilinmeyen alan sessizce yutulur ->
    en azindan 200 donse bile kolon yazilmaz). Sema reddediyorsa 422."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.patch(
        "/tenant/settings", json={"acil_durum_telefon": "+902120000000"}, headers=admin
    )
    # Pydantic bilinmeyen alani yoksayar -> "en az bir alan" kurali patlar (422).
    assert r.status_code == 422, r.text
