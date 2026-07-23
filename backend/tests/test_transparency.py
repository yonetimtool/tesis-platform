"""Seffaflik Panosu — anonim aylik ozet + yayin kontrolu + RBAC/izolasyon.

ANONIMLIK: yanit JSON'unda sakin ADI / daire ETIKETI / bireysel tutar ASLA yok
(seed'den gelen degerlerle dogrulanir). Testler canli sunucuya (httpx) vurur.
"""
from __future__ import annotations

import uuid

import pytest

AY = "2026-03"  # saat-bagimsiz sabit ay (flake yok)


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _uid(owner_conn, tid, role):
    return owner_conn.execute(
        "SELECT id FROM app_user WHERE tenant_id=%s AND role=%s LIMIT 1", (str(tid), role)
    ).fetchone()[0]


def _seed_month(owner_conn, tid, creator_id, ay=AY):
    """AY icin: gider 2000TL + gelir 3000TL + 1 daire tahakkuk 750 tam odenmis,
    1 daire tahakkuk 750 ODENMEMIS (geciken=1). Daire no'lari test icin doner."""
    kg = owner_conn.execute(
        "INSERT INTO budget_category (tenant_id, ad, tip) VALUES (%s,%s,'gider') RETURNING id",
        (str(tid), f"Elektrik-{uuid.uuid4().hex[:4]}"),
    ).fetchone()[0]
    owner_conn.execute(
        "INSERT INTO budget_entry (tenant_id, kategori_id, tip, tutar_kurus, tarih, created_by) "
        "VALUES (%s,%s,'gider',200000,%s,%s)",
        (str(tid), kg, f"{ay}-15", str(creator_id)),
    )
    kgel = owner_conn.execute(
        "INSERT INTO budget_category (tenant_id, ad, tip) VALUES (%s,%s,'gelir') RETURNING id",
        (str(tid), f"Aidat-{uuid.uuid4().hex[:4]}"),
    ).fetchone()[0]
    owner_conn.execute(
        "INSERT INTO budget_entry (tenant_id, kategori_id, tip, tutar_kurus, tarih, created_by) "
        "VALUES (%s,%s,'gelir',300000,%s,%s)",
        (str(tid), kgel, f"{ay}-16", str(creator_id)),
    )
    # iki daire
    u_paid = owner_conn.execute(
        "INSERT INTO unit (tenant_id, no, blok) VALUES (%s,%s,'A') RETURNING no, id",
        (str(tid), f"SF-P{uuid.uuid4().hex[:4]}"),
    ).fetchone()
    u_owe = owner_conn.execute(
        "INSERT INTO unit (tenant_id, no, blok) VALUES (%s,%s,'A') RETURNING no, id",
        (str(tid), f"SF-O{uuid.uuid4().hex[:4]}"),
    ).fetchone()
    for _, uid in (u_paid, u_owe):
        owner_conn.execute(
            "INSERT INTO dues_assessment (tenant_id, unit_id, donem, tutar_kurus) "
            "VALUES (%s,%s,%s,75000)",
            (str(tid), str(uid), ay),
        )
    # yalniz u_paid tam oder
    owner_conn.execute(
        "INSERT INTO dues_payment (tenant_id, unit_id, tutar_kurus, donem, yontem, durum, "
        "kaydeden_user_id, idempotency_key) "
        "VALUES (%s,%s,75000,%s,'elden'::dues_yontem,'basarili'::dues_durum,%s,%s)",
        (str(tid), str(u_paid[1]), ay, str(creator_id), uuid.uuid4().hex),
    )
    return u_paid[0], u_owe[0]  # no'lar


def _publish(client, yon_h, ay=AY, yayin=True):
    r = client.put(f"/transparency/{ay}/publish", headers=yon_h, json={"yayin": yayin})
    assert r.status_code == 200, r.text
    return r.json()


# ------------------------- yayin kapisi + hesaplama ------------------------- #
def test_resident_yayinlanmis_gorur_yayinlanmamis_404(world, client, owner_conn):
    tid = world["a"]
    yon_id = _uid(owner_conn, tid, "yonetici")
    _seed_month(owner_conn, tid, yon_id)
    res = _headers(client, world["slug_a"], world["resident_a"])
    yon = _headers(client, world["slug_a"], world["yonetici_a"])

    # yayinlanmadan sakin goremez (404); yonetim ONIZLEME gorur.
    assert client.get(f"/transparency/{AY}", headers=res).status_code == 404
    prev = client.get(f"/transparency/{AY}", headers=yon)
    assert prev.status_code == 200 and prev.json()["yayinlandi"] is False

    _publish(client, yon)  # yayinla

    r = client.get(f"/transparency/{AY}", headers=res)
    assert r.status_code == 200
    b = r.json()
    assert b["yayinlandi"] is True
    assert b["toplam_gelir_kurus"] == 300000
    assert b["toplam_gider_kurus"] == 200000
    assert b["net_kurus"] == 100000
    # aidat: 2 daire, 1 tam odeyen -> daire orani %50, geciken 1
    assert b["aidat"]["toplam_daire"] == 2
    assert b["aidat"]["odeyen_daire"] == 1
    assert b["aidat"]["daire_orani_yuzde"] == 50
    assert b["aidat"]["geciken_daire_sayisi"] == 1
    # tutar-bazli: tahakkuk 1500, tahsilat 750 -> %50
    assert b["aidat"]["tahakkuk_kurus"] == 150000
    assert b["aidat"]["tahsilat_kurus"] == 75000
    assert b["aidat"]["tutar_orani_yuzde"] == 50
    # gider dagilimi: Elektrik 2000 (%100 gider)
    assert any(k["toplam_kurus"] == 200000 for k in b["gider_dagilimi"])


def test_anonimlik_isim_ve_daire_sizmaz(world, client, owner_conn):
    """KVKK/anonimlik: yanit JSON'u sakin ADINI veya daire NO'sunu ICERMEZ."""
    tid = world["a"]
    yon_id = _uid(owner_conn, tid, "yonetici")
    paid_no, owe_no = _seed_month(owner_conn, tid, yon_id)
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    _publish(client, yon)

    raw = client.get(f"/transparency/{AY}", headers=yon).text
    # Seed sakin adlari (conftest) + daire no'lari yanita ASLA girmez.
    assert "Resident A" not in raw and "Yonetici A" not in raw
    assert paid_no not in raw and owe_no not in raw
    # (kategori ADLARI kisisel veri degil -> dagilimda olabilir.)


def test_bos_ay_sifir_cokme_yok(world, client):
    """Verisi olmayan ay: sifirlar, crash yok. Sakin 404 (yayin yok); yonetim onizleme."""
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    res = _headers(client, world["slug_a"], world["resident_a"])
    bos = "2020-01"
    assert client.get(f"/transparency/{bos}", headers=res).status_code == 404
    r = client.get(f"/transparency/{bos}", headers=yon)
    assert r.status_code == 200
    b = r.json()
    assert b["toplam_gelir_kurus"] == 0 and b["toplam_gider_kurus"] == 0
    assert b["net_kurus"] == 0 and b["gider_dagilimi"] == []
    assert b["aidat"]["toplam_daire"] == 0 and b["aidat"]["geciken_daire_sayisi"] == 0
    assert b["aidat"]["daire_orani_yuzde"] is None  # tanimsiz -> null


# ------------------------------- RBAC + audit ------------------------------- #
def test_publish_rbac_ve_audit(world, client, owner_conn):
    tid = world["a"]
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    # Sakin + saha yayinlayamaz (403).
    for role in ("resident_a", "guard_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.put(f"/transparency/{AY}/publish", headers=h,
                          json={"yayin": True}).status_code == 403
    _publish(client, yon, yayin=True)
    # audit: transparency_publish yazildi.
    assert owner_conn.execute(
        "SELECT count(*) FROM audit_log WHERE tenant_id=%s AND action='transparency_publish' "
        "AND resource_id=%s", (str(tid), AY),
    ).fetchone()[0] == 1
    # geri al -> unpublish audit + sakin tekrar 404.
    _publish(client, yon, yayin=False)
    res = _headers(client, world["slug_a"], world["resident_a"])
    assert client.get(f"/transparency/{AY}", headers=res).status_code == 404
    assert owner_conn.execute(
        "SELECT count(*) FROM audit_log WHERE tenant_id=%s AND action='transparency_unpublish'",
        (str(tid),),
    ).fetchone()[0] == 1


def test_capraz_tenant_izolasyon(world, client, owner_conn):
    """A'da yayinlanan ay B'de gorunmez (RLS). B sakini 404; B listesinde yok."""
    yon_a = _headers(client, world["slug_a"], world["yonetici_a"])
    _publish(client, yon_a)  # A'da AY yayinlandi
    res_b = _headers(client, world["slug_b"], world["resident_b"]) if "resident_b" in world else None
    # world'de resident_b yoksa admin_b ile liste izolasyonunu dogrula.
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    lst_b = client.get("/transparency", headers=admin_b).json()["items"]
    assert all(it["ay"] != AY or it["yayinlandi"] is False for it in lst_b)


def test_liste_sakin_yalniz_yayinlanmis(world, client, owner_conn):
    tid = world["a"]
    yon_id = _uid(owner_conn, tid, "yonetici")
    _seed_month(owner_conn, tid, yon_id, ay="2026-03")
    _seed_month(owner_conn, tid, yon_id, ay="2026-04")
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    res = _headers(client, world["slug_a"], world["resident_a"])
    _publish(client, yon, ay="2026-03")  # yalniz 03 yayinlandi

    # yonetim: her iki aday ay da listede (durumlariyla).
    ymonths = {it["ay"]: it["yayinlandi"] for it in client.get("/transparency", headers=yon).json()["items"]}
    assert ymonths.get("2026-03") is True and ymonths.get("2026-04") is False
    # sakin: YALNIZ yayinlanmis (2026-03).
    rmonths = [it["ay"] for it in client.get("/transparency", headers=res).json()["items"]]
    assert "2026-03" in rmonths and "2026-04" not in rmonths


def test_ay_format_dogrulama_422(world, client):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    for bad in ("2026-13", "2026-3", "abc", "202603"):
        assert client.get(f"/transparency/{bad}", headers=yon).status_code == 422
