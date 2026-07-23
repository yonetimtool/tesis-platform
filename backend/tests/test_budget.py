"""Butce modulu (Wave 2A) — dinamik kategoriler + gelir/gider defteri +
otomatik aidat→gelir entegrasyonu + ozet (KABUL KRITERI).

Para HER YERDE integer KURUS. RBAC: yonetim (admin+yonetici) tam yetkili;
saha/sakin erisemez (sakin okumasi Wave 2B). Kategori silme = soft-delete
(aktif=false); kayitli hareketi olan kategori korunur.
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


def _new_category(client, headers, ad=None, tip="gider"):
    r = client.post(
        "/budget/categories",
        headers=headers,
        json={"ad": ad or f"Kat-{uuid.uuid4().hex[:6]}", "tip": tip},
    )
    assert r.status_code == 201, r.text
    return r.json()


def _new_entry(client, headers, kategori_id, tutar, **over):
    body = {"kategori_id": kategori_id, "tutar_kurus": tutar, "tarih": "2026-07-05"}
    body.update(over)
    r = client.post("/budget/entries", headers=headers, json=body)
    assert r.status_code == 201, r.text
    return r.json()


def _mk_unit(client, admin):
    r = client.post("/units", headers=admin, json={"no": f"B-{uuid.uuid4().hex[:6]}", "blok": "A"})
    assert r.status_code == 201, r.text
    return r.json()


def _pay(client, admin, unit_id, tutar, key=None, donem="2026-07"):
    r = client.post(
        "/dues/payments",
        headers={**admin, "Idempotency-Key": key or uuid.uuid4().hex},
        json={"unit_id": unit_id, "tutar_kurus": tutar, "yontem": "elden", "donem": donem},
    )
    assert r.status_code in (200, 201), r.text
    return r.json()


# ----------------------------- kategoriler --------------------------------- #
def test_kategori_crud_ve_dup(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])

    cat = _new_category(client, yon, ad="Elektrik", tip="gider")
    assert cat["ad"] == "Elektrik" and cat["tip"] == "gider" and cat["aktif"] is True

    # ayni tenant + tip + ad -> 409
    dup = client.post(
        "/budget/categories", headers=yon, json={"ad": "Elektrik", "tip": "gider"}
    )
    assert dup.status_code == 409

    # ayni ad farkli tip serbest (gelir kategorisi olarak)
    gelir = client.post(
        "/budget/categories", headers=yon, json={"ad": "Elektrik", "tip": "gelir"}
    )
    assert gelir.status_code == 201

    # liste + tip filtresi
    body = client.get(
        "/budget/categories", headers=yon, params={"tip": "gider", "limit": 200}
    ).json()
    assert any(it["id"] == cat["id"] for it in body["items"])
    assert all(it["tip"] == "gider" for it in body["items"])

    # PATCH: ad + aktif (soft-delete)
    p = client.patch(
        f"/budget/categories/{cat['id']}", headers=yon, json={"ad": "Elektrik-Su", "aktif": False}
    )
    assert p.status_code == 200
    assert p.json()["ad"] == "Elektrik-Su" and p.json()["aktif"] is False

    # gecersiz tip -> 422
    assert (
        client.post(
            "/budget/categories", headers=yon, json={"ad": "X", "tip": "yatirim"}
        ).status_code
        == 422
    )


def test_kategori_rbac_ve_tenant_izolasyonu(client, world):
    yon_a = _headers(client, world["slug_a"], world["yonetici_a"])
    yon_b = _headers(client, world["slug_b"], world["yonetici_b"])
    cat = _new_category(client, yon_a, ad="Izole", tip="gider")

    # saha + sakin: yonetemez ve GOREMEZ (Wave 2B'ye kadar okuma da kapali)
    for role in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.get("/budget/categories", headers=h).status_code == 403, role
        assert (
            client.post(
                "/budget/categories", headers=h, json={"ad": "X", "tip": "gider"}
            ).status_code
            == 403
        ), role

    # tenant izolasyonu: B, A'nin kategorisini listede goremez + patch edemez
    b_items = client.get("/budget/categories", headers=yon_b, params={"limit": 200}).json()["items"]
    assert all(it["id"] != cat["id"] for it in b_items)
    assert (
        client.patch(
            f"/budget/categories/{cat['id']}", headers=yon_b, json={"aktif": False}
        ).status_code
        == 404
    )


# ------------------------------- defter ------------------------------------ #
def test_defter_kayit_ve_filtreler(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    gider = _new_category(client, yon, tip="gider")
    gelir = _new_category(client, yon, tip="gelir")

    e1 = _new_entry(client, yon, gider["id"], 120000, tarih="2026-07-01", aciklama="Elektrik faturasi")
    e2 = _new_entry(client, yon, gelir["id"], 50000, tarih="2026-07-03")
    e3 = _new_entry(client, yon, gider["id"], 30000, tarih="2026-06-15")

    # tip kategori'den turetilir (istemci tip GONDERMEZ)
    assert e1["tip"] == "gider" and e2["tip"] == "gelir"
    assert e1["kaynak"] == "manuel" and e1["ilgili_payment_id"] is None
    assert e1["kategori_ad"] == gider["ad"]
    # para integer kurus
    assert isinstance(e1["tutar_kurus"], int) and e1["tutar_kurus"] == 120000

    # tip filtresi
    ids = {
        it["id"]
        for it in client.get(
            "/budget/entries", headers=yon, params={"tip": "gider", "limit": 200}
        ).json()["items"]
    }
    assert e1["id"] in ids and e3["id"] in ids and e2["id"] not in ids

    # kategori filtresi
    ids = {
        it["id"]
        for it in client.get(
            "/budget/entries", headers=yon, params={"kategori_id": gelir["id"], "limit": 200}
        ).json()["items"]
    }
    assert ids >= {e2["id"]} and e1["id"] not in ids

    # tarih araligi + donem
    ids = {
        it["id"]
        for it in client.get(
            "/budget/entries",
            headers=yon,
            params={"baslangic": "2026-07-01", "bitis": "2026-07-31", "limit": 200},
        ).json()["items"]
    }
    assert e1["id"] in ids and e2["id"] in ids and e3["id"] not in ids
    donem_items = client.get(
        "/budget/entries", headers=yon, params={"donem": "2026-06", "limit": 200}
    ).json()["items"]
    assert {it["id"] for it in donem_items} >= {e3["id"]}
    assert all(it["tarih"].startswith("2026-06") for it in donem_items)

    # siralama: tarih DESC
    items = client.get(
        "/budget/entries", headers=yon, params={"limit": 200}
    ).json()["items"]
    tarihs = [it["tarih"] for it in items]
    assert tarihs == sorted(tarihs, reverse=True)


def test_defter_dogrulama_para_integer_kurus(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    cat = _new_category(client, yon, tip="gider")

    for bad in (0, -5, 10.5, "yuzelli"):
        r = client.post(
            "/budget/entries",
            headers=yon,
            json={"kategori_id": cat["id"], "tutar_kurus": bad, "tarih": "2026-07-01"},
        )
        assert r.status_code == 422, f"tutar={bad}: {r.status_code}"

    # olmayan kategori -> 422
    r = client.post(
        "/budget/entries",
        headers=yon,
        json={"kategori_id": str(uuid.uuid4()), "tutar_kurus": 100, "tarih": "2026-07-01"},
    )
    assert r.status_code == 422

    # pasif kategoriye YENI kayit yazilamaz
    pasif = _new_category(client, yon, tip="gider")
    client.patch(f"/budget/categories/{pasif['id']}", headers=yon, json={"aktif": False})
    r = client.post(
        "/budget/entries",
        headers=yon,
        json={"kategori_id": pasif["id"], "tutar_kurus": 100, "tarih": "2026-07-01"},
    )
    assert r.status_code == 422


def test_soft_delete_kategori_kayitlari_korur(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    cat = _new_category(client, yon, ad="Kapanacak", tip="gider")
    entry = _new_entry(client, yon, cat["id"], 7500)

    # soft-delete (aktif=false)
    assert (
        client.patch(
            f"/budget/categories/{cat['id']}", headers=yon, json={"aktif": False}
        ).status_code
        == 200
    )

    # mevcut kayit listede kategori adiyla durur
    items = client.get(
        "/budget/entries", headers=yon, params={"kategori_id": cat["id"], "limit": 200}
    ).json()["items"]
    assert [it["id"] for it in items] == [entry["id"]]
    assert items[0]["kategori_ad"] == "Kapanacak"


def test_defter_guncelle_sil_ve_rbac(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    cat = _new_category(client, yon, tip="gider")
    entry = _new_entry(client, yon, cat["id"], 10000, aciklama="ilk")

    # PATCH: tutar + aciklama
    p = client.patch(
        f"/budget/entries/{entry['id']}",
        headers=yon,
        json={"tutar_kurus": 12500, "aciklama": "duzeltildi"},
    )
    assert p.status_code == 200 and p.json()["tutar_kurus"] == 12500

    # saha/sakin: defter SATIRLARI kapali; OZET Wave 2B'de seffaflik icin
    # tum rollere acildi (bkz. test_financial_transparency).
    for role in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.get("/budget/entries", headers=h).status_code == 403, role
        assert client.get("/budget/summary", headers=h).status_code == 200, role

    # DELETE -> 204, listeden duser
    assert client.delete(f"/budget/entries/{entry['id']}", headers=yon).status_code == 204
    items = client.get(
        "/budget/entries", headers=yon, params={"kategori_id": cat["id"], "limit": 200}
    ).json()["items"]
    assert all(it["id"] != entry["id"] for it in items)


# -------------------------------- ozet -------------------------------------- #
def test_ozet_matematigi_ve_negatif_kasa(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    gelir = _new_category(client, yon, tip="gelir")
    gider = _new_category(client, yon, tip="gider")

    # Ayri bir donemde calis (diger testlerle karismasin)
    _new_entry(client, yon, gelir["id"], 100000, tarih="2025-01-10")
    _new_entry(client, yon, gider["id"], 120000, tarih="2025-01-12")
    _new_entry(client, yon, gider["id"], 30000, tarih="2025-01-20")

    s = client.get("/budget/summary", headers=yon, params={"donem": "2025-01"}).json()
    assert s["toplam_gelir_kurus"] == 100000
    assert s["toplam_gider_kurus"] == 150000
    assert s["bakiye_kurus"] == -50000  # kasa negatif olabilir
    assert isinstance(s["bakiye_kurus"], int)

    # kategori kirilimi
    kirilim = {k["kategori_id"]: k for k in s["kategoriler"]}
    assert kirilim[gelir["id"]]["toplam_kurus"] == 100000
    assert kirilim[gider["id"]]["toplam_kurus"] == 150000

    # tarih araligiyla ayni sonuc
    s2 = client.get(
        "/budget/summary",
        headers=yon,
        params={"baslangic": "2025-01-01", "bitis": "2025-01-31"},
    ).json()
    assert s2["bakiye_kurus"] == -50000


# ---------------------- OTOMATIK aidat -> gelir ----------------------------- #
def test_aidat_odemesi_tek_gelir_kaydi_uretir_idempotent(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    unit = _mk_unit(client, admin)

    key = uuid.uuid4().hex
    payment = _pay(client, admin, unit["id"], 75000, key=key)
    assert payment["durum"] == "basarili"

    def _auto_entries():
        items = client.get(
            "/budget/entries", headers=yon, params={"kaynak": "aidat_odeme", "limit": 200}
        ).json()["items"]
        return [it for it in items if it["ilgili_payment_id"] == payment["id"]]

    entries = _auto_entries()
    assert len(entries) == 1, f"beklenen 1 otomatik gelir kaydi, gelen {len(entries)}"
    e = entries[0]
    assert e["tip"] == "gelir"
    assert e["kaynak"] == "aidat_odeme"
    assert e["tutar_kurus"] == 75000  # tutar odemeyle birebir
    assert e["kategori_ad"] == "Aidat"  # varsayilan otomatik kategori

    # ayni odeme tekrar POST edilirse (ayni Idempotency-Key) -> hala TEK kayit
    again = _pay(client, admin, unit["id"], 75000, key=key)
    assert again["id"] == payment["id"]
    assert len(_auto_entries()) == 1

    # farkli odeme -> ikinci, AYRI gelir kaydi
    p2 = _pay(client, admin, unit["id"], 25000)
    items = client.get(
        "/budget/entries", headers=yon, params={"kaynak": "aidat_odeme", "limit": 200}
    ).json()["items"]
    linked = {it["ilgili_payment_id"] for it in items}
    assert {payment["id"], p2["id"]} <= linked


def test_otomatik_kayit_duzenlenemez_silinemez(client, world):
    """aidat_odeme kaynakli kayit defterden elle degistirilemez/silinemez —
    aidat mutabakati bozulmasin (odeme iptali Wave sonrasi)."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    unit = _mk_unit(client, admin)
    payment = _pay(client, admin, unit["id"], 10000)

    items = client.get(
        "/budget/entries", headers=yon, params={"kaynak": "aidat_odeme", "limit": 200}
    ).json()["items"]
    auto = next(it for it in items if it["ilgili_payment_id"] == payment["id"])

    assert (
        client.patch(
            f"/budget/entries/{auto['id']}", headers=yon, json={"tutar_kurus": 1}
        ).status_code
        == 422
    )
    assert client.delete(f"/budget/entries/{auto['id']}", headers=yon).status_code == 422


def test_aidat_gelir_kaydi_ozete_yansir_ve_dues_bozulmaz(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    unit = _mk_unit(client, admin)

    # tahakkuk + odeme (dues akisi aynen calisiyor)
    a = client.post(
        "/dues/assessments",
        headers=admin,
        json={"unit_id": unit["id"], "donem": "2026-08", "tutar_kurus": 60000},
    )
    assert a.status_code == 201
    _pay(client, admin, unit["id"], 60000, donem="2026-08")

    # dues bakiyesi dogru (60000 - 60000 = 0)
    status = client.get(f"/units/{unit['id']}/dues", headers=admin).json()
    assert status["bakiye_kurus"] == 0

    # butce ozeti (filtresiz = tum zamanlar) bu geliri gorur. Not: otomatik
    # kaydin tarihi ODEME zamanidir (nakit esasi), tahakkuk donemi degil.
    s = client.get("/budget/summary", headers=yon).json()
    assert s["toplam_gelir_kurus"] >= 60000
