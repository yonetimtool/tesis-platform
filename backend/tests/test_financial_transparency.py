"""Wave 2B — sakin finansal seffafligi + ozet raporlar (KABUL KRITERI).

Kurallar:
  * SAKIN + SAHA: butce OZETINI okur (agregat; toplam gelir/gider/kasa +
    kategori kirilimi) — defter SATIRLARINI goremez, butceyi YONETEMEZ.
  * SAKIN kendi dairesinin aidat detayini /me/dues'tan okur; /units/{id}/dues
    (yonetim raporu) sakine KAPALIDIR — baska unit_id vererek asilamaz.
  * GET /reports/financial-summary: yonetim TAM icerik (tahsilat orani,
    geciken daire), sakin/saha yalniz agregat (tahsilat=null).
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


def _mk_unit(client, admin, no=None):
    r = client.post("/units", headers=admin, json={"no": no or f"T-{uuid.uuid4().hex[:6]}", "blok": "A"})
    assert r.status_code == 201, r.text
    return r.json()


def _mk_category(client, yon, tip, ad=None):
    r = client.post(
        "/budget/categories",
        headers=yon,
        json={"ad": ad or f"Kat-{uuid.uuid4().hex[:6]}", "tip": tip},
    )
    assert r.status_code == 201, r.text
    return r.json()


def _mk_entry(client, yon, kategori_id, tutar, tarih):
    r = client.post(
        "/budget/entries",
        headers=yon,
        json={"kategori_id": kategori_id, "tutar_kurus": tutar, "tarih": tarih},
    )
    assert r.status_code == 201, r.text
    return r.json()


# ------------------- butce ozeti: seffaflik okumasi ------------------------- #
def test_sakin_ve_saha_butce_ozetini_okur(client, world):
    """GET /budget/summary artik TUM rollere acik (Wave 2B seffaflik) —
    yalniz agregat icerir, satir/kisi verisi yoktur."""
    for role in ("resident_a", "guard_a", "gorevli_a", "yonetici_a", "admin_a"):
        h = _headers(client, world["slug_a"], world[role])
        r = client.get("/budget/summary", headers=h)
        assert r.status_code == 200, f"{role}: {r.status_code}"
        body = r.json()
        assert set(body) >= {
            "toplam_gelir_kurus", "toplam_gider_kurus", "bakiye_kurus", "kategoriler",
        }
        # agregat disinda alan sizmadigini dogrula (satir/kisi verisi yok)
        for k in body["kategoriler"]:
            assert set(k) == {"kategori_id", "ad", "tip", "toplam_kurus"}


def test_sakin_defteri_goremez_ve_yonetemez(client, world):
    """Sakin (ve saha) icin defter DETAYI + butce YONETIMI kapali kalir."""
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    cat = _mk_category(client, yon, "gider")

    for role in ("resident_a", "guard_a", "gorevli_a"):
        h = _headers(client, world["slug_a"], world[role])
        # defter satirlari: 403
        assert client.get("/budget/entries", headers=h).status_code == 403, role
        # kategori listesi/yonetimi: 403
        assert client.get("/budget/categories", headers=h).status_code == 403, role
        assert (
            client.post(
                "/budget/categories", headers=h, json={"ad": "X", "tip": "gider"}
            ).status_code
            == 403
        ), role
        assert (
            client.post(
                "/budget/entries",
                headers=h,
                json={"kategori_id": cat["id"], "tutar_kurus": 100, "tarih": "2026-07-01"},
            ).status_code
            == 403
        ), role
        assert (
            client.patch(
                f"/budget/categories/{cat['id']}", headers=h, json={"aktif": False}
            ).status_code
            == 403
        ), role


# ------------------------ sakin kendi aidat detayi -------------------------- #
def test_sakin_yalniz_kendi_dairesinin_aidatini_gorur(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])
    resident_id = client.get("/me", headers=resident).json()["id"]

    kendi = _mk_unit(client, admin)
    baskasi = _mk_unit(client, admin)
    assert (
        client.post(
            f"/units/{kendi['id']}/residents",
            headers=admin,
            json={"user_id": resident_id, "rol_tipi": "malik"},
        ).status_code
        == 201
    )
    # her iki daireye tahakkuk
    for u, kurus in ((kendi, 50000), (baskasi, 70000)):
        assert (
            client.post(
                "/dues/assessments",
                headers=admin,
                json={"unit_id": u["id"], "donem": "2024-03", "tutar_kurus": kurus},
            ).status_code
            == 201
        )

    # /me/dues: YALNIZ kendi dairesi doner (baskasininki yok)
    items = client.get("/me/dues", headers=resident).json()["items"]
    unit_ids = {it["unit_id"] for it in items}
    assert kendi["id"] in unit_ids
    assert baskasi["id"] not in unit_ids
    mine = next(it for it in items if it["unit_id"] == kendi["id"])
    # detay tam: tahakkuk - odenen = bakiye, gecmis listeleri mevcut
    assert mine["toplam_tahakkuk_kurus"] - mine["toplam_odenen_kurus"] == mine["bakiye_kurus"]
    assert "assessments" in mine and "payments" in mine

    # /units/{id}/dues yonetim raporudur: sakin KENDI dairesi icin bile 403
    # (unit_id degistirerek baskasininkine ulasma yolu yoktur).
    assert client.get(f"/units/{kendi['id']}/dues", headers=resident).status_code == 403
    assert client.get(f"/units/{baskasi['id']}/dues", headers=resident).status_code == 403


# ------------------- GET /reports/financial-summary ------------------------- #
def test_financial_summary_matematik_ve_rol_icerigi(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])

    donem = "2024-05"
    # dues: 2 daire, 1000 TL tahakkuk, 600 TL tahsilat -> %60, 1 geciken daire
    u1 = _mk_unit(client, admin)
    u2 = _mk_unit(client, admin)
    for u, kurus in ((u1, 60000), (u2, 40000)):
        assert (
            client.post(
                "/dues/assessments",
                headers=admin,
                json={"unit_id": u["id"], "donem": donem, "tutar_kurus": kurus},
            ).status_code
            == 201
        )
    r = client.post(
        "/dues/payments",
        headers={**admin, "Idempotency-Key": uuid.uuid4().hex},
        json={"unit_id": u1["id"], "tutar_kurus": 60000, "yontem": "elden", "donem": donem},
    )
    assert r.status_code == 201, r.text

    # butce: ayni donem tarihli manuel kayitlar (en yuksek giderler icin 2 kategori)
    buyuk = _mk_category(client, yon, "gider", ad=f"Buyuk-{uuid.uuid4().hex[:4]}")
    kucuk = _mk_category(client, yon, "gider", ad=f"Kucuk-{uuid.uuid4().hex[:4]}")
    gelir = _mk_category(client, yon, "gelir")
    _mk_entry(client, yon, buyuk["id"], 90000, f"{donem}-10")
    _mk_entry(client, yon, kucuk["id"], 10000, f"{donem}-12")
    _mk_entry(client, yon, gelir["id"], 30000, f"{donem}-15")

    # ---- YONETICI: tam icerik ----
    s = client.get(
        "/reports/financial-summary", headers=yon, params={"donem": donem}
    ).json()
    assert s["donem"] == donem
    assert s["toplam_gelir_kurus"] == 30000
    assert s["toplam_gider_kurus"] == 100000
    assert s["bakiye_kurus"] == -70000  # negatif kasa
    # en yuksek giderler: buyukten kucuge
    giderler = s["en_yuksek_giderler"]
    assert giderler[0]["ad"] == buyuk["ad"] and giderler[0]["toplam_kurus"] == 90000
    assert giderler[1]["ad"] == kucuk["ad"] and giderler[1]["toplam_kurus"] == 10000
    # tahsilat blogu (yonetim-only)
    t = s["tahsilat"]
    assert t["tahakkuk_kurus"] == 100000
    assert t["tahsilat_kurus"] == 60000
    assert t["tahsilat_orani_yuzde"] == 60
    assert t["geciken_daire_sayisi"] == 1

    # ---- SAKIN: yalniz agregat; tahsilat blogu YOK (null) ----
    sr = client.get(
        "/reports/financial-summary", headers=resident, params={"donem": donem}
    )
    assert sr.status_code == 200
    sbody = sr.json()
    assert sbody["toplam_gider_kurus"] == 100000
    assert sbody["bakiye_kurus"] == -70000
    assert sbody["tahsilat"] is None  # yonetim-disi rollerde doldurulmaz
    assert sbody["en_yuksek_giderler"][0]["toplam_kurus"] == 90000

    # saha da agregat okur
    guard = _headers(client, world["slug_a"], world["guard_a"])
    gr = client.get("/reports/financial-summary", headers=guard, params={"donem": donem})
    assert gr.status_code == 200 and gr.json()["tahsilat"] is None


def test_financial_summary_tenant_izolasyonu(client, world):
    """B tenant'inin yoneticisi A'nin rakamlarini goremez (RLS)."""
    yon_b = _headers(client, world["slug_b"], world["yonetici_b"])
    s = client.get(
        "/reports/financial-summary", headers=yon_b, params={"donem": "2024-05"}
    ).json()
    assert s["toplam_gelir_kurus"] == 0
    assert s["toplam_gider_kurus"] == 0
    assert s["tahsilat"]["tahakkuk_kurus"] == 0


def test_financial_summary_donemsiz_tum_zamanlar(client, world):
    """Parametresiz cagri tum zamanlarin ozetidir (telefondan hizli bakis)."""
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.get("/reports/financial-summary", headers=yon)
    assert r.status_code == 200
    body = r.json()
    assert body["donem"] is None
    assert isinstance(body["toplam_gelir_kurus"], int)
    assert isinstance(body["tahsilat"]["tahakkuk_kurus"], int)
