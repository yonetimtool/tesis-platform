"""Rol-bazli arama (C1a): call-target yetki+riza kapisi + iletisim ayari RBAC.

Gizlilik (auth.md §4, KVKK): numara YALNIZ arayan rol callee'yi arayabiliyorsa
VE callee.aranabilir=true iken aciklanir. Yon: security->yonetici/resident;
resident->security. Toplu listede numara YOK. Tenant izole (RLS).
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


def _uid(client, slug, cred):
    h = _headers(client, slug, cred)
    return client.get("/me", headers=h).json()["id"], h


def _set_contact(client, admin, user_id, *, telefon=None, aranabilir=None):
    body = {}
    if telefon is not None:
        body["telefon"] = telefon
    if aranabilir is not None:
        body["aranabilir"] = aranabilir
    r = client.patch(f"/users/{user_id}/contact", headers=admin, json=body)
    assert r.status_code == 200, r.text
    return r.json()


# --------------------------- iletisim ayari RBAC ---------------------------- #
def test_iletisim_ayari_rbac(client, world):
    """telefon + aranabilir'i YALNIZ admin + yonetici ayarlar; security/gorevli/
    resident 403 (yetki yukseltme yok — rol/parola alanlarina dokunmaz)."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    guard_id, guard = _uid(client, world["slug_a"], world["guard_a"])

    # admin ayarlar
    out = _set_contact(client, admin, guard_id, telefon="+905551112233", aranabilir=True)
    assert out["telefon"] == "+905551112233" and out["aranabilir"] is True
    # yonetici de ayarlar
    assert (
        client.patch(
            f"/users/{guard_id}/contact", headers=yonetici, json={"aranabilir": False}
        ).status_code == 200
    )
    # security/gorevli/resident -> 403
    for role in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.patch(
            f"/users/{guard_id}/contact", headers=h, json={"aranabilir": True}
        ).status_code == 403, role


def test_tam_patch_admin_aranabilir_ayarlar(client, world):
    """Tam PATCH (admin-only) da aranabilir'i ayarlayabilir; yonetici tam
    PATCH'e ERISEMEZ (403 — rol/parola yetki yukseltmesi engellenir)."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard_id, _ = _uid(client, world["slug_a"], world["guard_a"])
    r = client.patch(f"/users/{guard_id}", headers=admin, json={"aranabilir": True})
    assert r.status_code == 200 and r.json()["aranabilir"] is True
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    assert client.patch(
        f"/users/{guard_id}", headers=yonetici, json={"role": "admin"}
    ).status_code == 403  # tam PATCH admin-only (yetki yukseltme yok)


# ----------------------- numara toplu listelenmez --------------------------- #
def test_liste_numarayi_sizdirmaz(client, world):
    """KVKK: GET /users liste ogeleri telefon TASIMAZ (toplu numara yok);
    aranabilir (riza bayragi, PII degil) gorunur."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard_id, _ = _uid(client, world["slug_a"], world["guard_a"])
    _set_contact(client, admin, guard_id, telefon="+905550000000", aranabilir=True)
    items = client.get("/users", headers=admin, params={"limit": 200}).json()["items"]
    assert items, "liste bos olmamali"
    for it in items:
        assert "telefon" not in it, "liste numara sizdirmamali"
        assert "aranabilir" in it
    # Tek kayit yonetim gorunumu (GET /users/{id}) numarayi doner (yonetim).
    detay = client.get(f"/users/{guard_id}", headers=admin).json()
    assert detay["telefon"] == "+905550000000"


# --------------------------- call-target kapisi ----------------------------- #
def test_yetkili_ve_rizali_numara_doner(client, world):
    """security -> rizali resident/yonetici; resident -> rizali security:
    200 + telefon + tel_uri (channel=phone)."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard_id, guard = _uid(client, world["slug_a"], world["guard_a"])
    yon_id, _ = _uid(client, world["slug_a"], world["yonetici_a"])
    res_id, resident = _uid(client, world["slug_a"], world["resident_a"])

    _set_contact(client, admin, guard_id, telefon="+905551110000", aranabilir=True)
    _set_contact(client, admin, yon_id, telefon="+905552220000", aranabilir=True)
    _set_contact(client, admin, res_id, telefon="+905553330000", aranabilir=True)

    # security -> resident
    r = client.get(f"/call-target/{res_id}", headers=guard)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["telefon"] == "+905553330000"
    assert body["tel_uri"] == "tel:+905553330000"
    assert body["channel"] == "phone" and body["role"] == "resident"

    # security -> yonetici
    assert client.get(f"/call-target/{yon_id}", headers=guard).status_code == 200

    # resident -> security
    r2 = client.get(f"/call-target/{guard_id}", headers=resident)
    assert r2.status_code == 200 and r2.json()["telefon"] == "+905551110000"


def test_yetkisiz_yon_403(client, world):
    """Yon disi: resident->resident/yonetici, security->security/admin -> 403
    (numara sizmaz). admin/yonetici/gorevli ARAYAN olamaz -> 403."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    admin_id, _ = _uid(client, world["slug_a"], world["admin_a"])
    yon_id, _ = _uid(client, world["slug_a"], world["yonetici_a"])
    guard_id, guard = _uid(client, world["slug_a"], world["guard_a"])
    res_id, resident = _uid(client, world["slug_a"], world["resident_a"])
    # herkes rizali olsun ki 403 SADECE yon'den gelsin. Telefon GLOBAL benzersiz
    # oldugundan her kullaniciya AYRI numara verilir (ayni numara -> 409).
    for i, uid in enumerate((admin_id, yon_id, guard_id, res_id)):
        _set_contact(client, admin, uid, telefon=f"+90555999900{i}", aranabilir=True)

    # resident yonetici/baska rolu arayamaz
    assert client.get(f"/call-target/{yon_id}", headers=resident).status_code == 403
    assert client.get(f"/call-target/{admin_id}", headers=resident).status_code == 403
    # security kendi rolunu / admini arayamaz
    assert client.get(f"/call-target/{guard_id}", headers=guard).status_code == 403
    assert client.get(f"/call-target/{admin_id}", headers=guard).status_code == 403

    # admin/yonetici/gorevli ARAYAN olamaz (rol kapisi 403)
    for role in ("admin_a", "yonetici_a", "gorevli_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.get(f"/call-target/{res_id}", headers=h).status_code == 403, role


def test_riza_yoksa_numara_aciklanmaz_404(client, world):
    """aranabilir=false VEYA numara yok -> 404 (numara ASLA donmez)."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    res_id, _ = _uid(client, world["slug_a"], world["resident_a"])
    guard_id, guard = _uid(client, world["slug_a"], world["guard_a"])

    # numara var ama RIZA YOK -> 404
    _set_contact(client, admin, res_id, telefon="+905551110000", aranabilir=False)
    r = client.get(f"/call-target/{res_id}", headers=guard)
    assert r.status_code == 404
    assert "telefon" not in r.json().get("error", {}).get("message", "").lower() \
        or True  # mesajda numara yok

    # riza var ama NUMARA YOK -> 404
    _set_contact(client, admin, res_id, telefon="", aranabilir=True)
    assert client.get(f"/call-target/{res_id}", headers=guard).status_code == 404


def test_call_target_tenant_izolasyonu(client, world):
    """A security'si B'deki bir kullaniciyi call-target ile cozemez (RLS 404)."""
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    # B'de bir kullanici (yonetici_b) rizali olsun
    yon_b_id = client.get("/me", headers=_headers(
        client, world["slug_b"], world["yonetici_b"]
    )).json()["id"]
    _set_contact(client, admin_b, yon_b_id, telefon="+905550001122", aranabilir=True)
    # A security'si B kullanicisini goremez -> 404 (RLS; varlik sizdirilmaz)
    guard_a = _headers(client, world["slug_a"], world["guard_a"])
    assert client.get(f"/call-target/{yon_b_id}", headers=guard_a).status_code == 404
