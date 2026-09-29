"""(P249 §2) TATBIKAT — gercek yolun provasi, karistirilamaz, raporlanir.

Olculen: tatbikat GERCEK yayin yolundan gider (alici satirlari, bildirim,
push), her yerde "TATBIKAT" yazar, yanlis alarm sayacina girmez, gercek
toplu alarm aktif tatbikati durdurur, blok kapsami yalniz o bloktaki
sakinlere gider, rapor ve PDF uretilir.
"""
from __future__ import annotations

import datetime as dt
import uuid

import pytest


def _h(client, slug, cred, dil=None):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    h = {"Authorization": f"Bearer {r.json()['access_token']}"}
    if dil:
        h["Accept-Language"] = dil
    return h


def _uid(client, h):
    return client.get("/me", headers=h).json()["id"]


@pytest.fixture
def ortam(client, world):
    return {
        "admin": _h(client, world["slug_a"], world["admin_a"]),
        "sakin": _h(client, world["slug_a"], world["resident_a"]),
        "guard": _h(client, world["slug_a"], world["guard_a"]),
    }


@pytest.fixture
def temiz(client, ortam):
    """Aktif tatbikat kalmasin: ayni anda yalniz BIR tatbikat aktif olur."""
    def _bitir():
        for t in client.get("/tatbikat", headers=ortam["admin"]).json():
            if t["durum"] == "aktif":
                client.post(f"/tatbikat/{t['id']}/bitir", headers=ortam["admin"])
            elif t["durum"] == "planli":
                client.post(f"/tatbikat/{t['id']}/iptal", headers=ortam["admin"])
    _bitir()
    yield
    _bitir()


def test_HEMEN_BASLAYAN_TATBIKAT_GERCEK_YOLDAN_GIDER(client, ortam, temiz):
    r = client.post("/tatbikat", headers=ortam["admin"],
                    json={"kategori": "deprem", "kapsam": "site"})
    assert r.status_code == 201, r.text
    t = r.json()
    assert t["durum"] == "aktif" and t["alarm_id"]
    # SAKIN alarmi TAM EKRAN kaynagindan gorur — gercekle AYNI yol.
    aktif = client.get("/panik/aktif", headers=ortam["sakin"]).json()
    a = next(x for x in aktif if x["id"] == t["alarm_id"])
    assert a["tatbikat"] is True
    assert a["baslik"].startswith("TATBİKAT"), a["baslik"]
    assert a["toplu"] is True and a["talimat"]
    # Bildirim metni de "tatbikat" der.
    b = client.get("/notifications", headers=ortam["sakin"], params={"limit": 20}).json()
    assert any(
        x["tip"] == "panik_alarm" and "tatbikat" in (x["mesaj"] or "").lower()
        for x in b["items"]
    )


def test_TATBIKAT_HER_DILDE_BELIRGIN(client, ortam, temiz):
    t = client.post("/tatbikat", headers=ortam["admin"],
                    json={"kategori": "yangin", "kapsam": "site"}).json()
    for dil, isaret in (("en", "DRILL"), ("de", "ÜBUNG"), ("ru", "УЧЕНИЯ")):
        h = {**ortam["sakin"], "Accept-Language": dil}
        a = client.get(f"/panik/{t['alarm_id']}", headers=h).json()
        assert a["baslik"].startswith(isaret), (dil, a["baslik"])


def test_GUVENDEYIM_ve_RAPOR(client, ortam, temiz):
    t = client.post("/tatbikat", headers=ortam["admin"],
                    json={"kategori": "tahliye", "kapsam": "site"}).json()
    r = client.post(f"/panik/{t['alarm_id']}/guvendeyim", headers=ortam["sakin"])
    assert r.status_code == 200, r.text
    client.post(f"/tatbikat/{t['id']}/bitir", headers=ortam["admin"])
    rap = client.get(f"/tatbikat/{t['id']}", headers=ortam["admin"]).json()
    assert rap["tatbikat"]["durum"] == "bitti"
    assert rap["durum"]["guvende"] >= 1
    assert rap["durum"]["alici"] >= rap["durum"]["guvende"]
    # Bitince tam ekran kalkar.
    aktif = client.get("/panik/aktif", headers=ortam["guard"]).json()
    assert all(x["id"] != t["alarm_id"] for x in aktif)
    # PDF uretilir.
    pdf = client.get(f"/tatbikat/{t['id']}/rapor.pdf", headers=ortam["admin"])
    assert pdf.status_code == 200
    assert pdf.headers["content-type"].startswith("application/pdf")
    assert pdf.content[:4] == b"%PDF"


def test_YANLIS_ALARM_SAYACINA_GIRMEZ(client, ortam, temiz, owner_conn):
    t = client.post("/tatbikat", headers=ortam["admin"],
                    json={"kategori": "gaz", "kapsam": "site"}).json()
    with owner_conn.cursor() as cur:
        cur.execute("SELECT durum, tatbikat_id FROM panik_alarm WHERE id=%s",
                    (t["alarm_id"],))
        durum, tid = cur.fetchone()
    assert str(tid) == t["id"]
    # Sayac sorgusu tatbikati DISLAR (kaynakta olculur: sayim ifadesi).
    import inspect

    from app.routers import panik as P

    kaynak = inspect.getsource(P._govde)
    assert "tatbikat_id.is_(None)" in kaynak


def test_GERCEK_TOPLU_ALARM_TATBIKATI_DURDURUR(client, ortam, temiz):
    from app.tasks import panik_yayinla

    t = client.post("/tatbikat", headers=ortam["admin"],
                    json={"kategori": "deprem", "kapsam": "site"}).json()
    r = client.post("/panik", headers=ortam["guard"],
                    json={"tip": "guvenlik", "kategori": "yangin"})
    assert r.status_code == 201, r.text
    gercek = r.json()
    tid = client.get("/me", headers=ortam["admin"]).json()["tenant_id"]
    panik_yayinla(gercek["id"], tid)
    try:
        durum = client.get(f"/tatbikat/{t['id']}", headers=ortam["admin"]).json()
        assert durum["tatbikat"]["durum"] == "bitti"
        assert durum["tatbikat"]["bitis_nedeni"] == "gercek_alarm"
        aktif = client.get("/panik/aktif", headers=ortam["sakin"]).json()
        assert aktif and aktif[0]["id"] == gercek["id"], "gercek alarm ONCE"
    finally:
        client.post(f"/panik/{gercek['id']}/kapat", headers=ortam["admin"], json={})


def test_PLANLI_TATBIKAT_DUYURU_ve_BEAT_BASLATIR(client, ortam, temiz, owner_conn):
    from app import panik_tatbikat as T

    an = (dt.datetime.now(dt.timezone.utc) + dt.timedelta(minutes=30)).isoformat()
    r = client.post("/tatbikat", headers=ortam["admin"],
                    json={"kategori": "deprem", "kapsam": "site",
                          "planlanan_at": an, "duyuru": True})
    assert r.status_code == 201, r.text
    t = r.json()
    assert t["durum"] == "planli" and t["duyuru_gonderildi_at"]
    b = client.get("/notifications", headers=ortam["sakin"], params={"limit": 20}).json()
    assert any(x["tip"] == "panik_tatbikat_duyuru" for x in b["items"])
    # Zamani gelmis gibi yap -> beat baslatir.
    with owner_conn.cursor() as cur:
        cur.execute("UPDATE panik_tatbikat SET planlanan_at = now() - interval '1 minute' "
                    "WHERE id=%s", (t["id"],))
    T.tum_tenantlar_icin()
    s = client.get(f"/tatbikat/{t['id']}", headers=ortam["admin"]).json()
    assert s["tatbikat"]["durum"] == "aktif"


def test_BLOK_KAPSAMI_YALNIZ_O_BLOKTAKI_SAKINE(client, ortam, temiz):
    admin = ortam["admin"]
    blok = f"TB{uuid.uuid4().hex[:4].upper()}"
    assert client.post("/blocks", headers=admin, json={"ad": blok}).status_code == 201
    r = client.post("/tatbikat", headers=admin,
                    json={"kategori": "yangin", "kapsam": "blok", "blok": blok})
    assert r.status_code == 201, r.text
    t = r.json()
    # world'un sakini bu blokta DEGIL -> almaz.
    aktif = client.get("/panik/aktif", headers=ortam["sakin"]).json()
    assert all(x["id"] != t["alarm_id"] for x in aktif), "blok disi sakine GITMEMELI"
    # Personel alir.
    aktif_g = client.get("/panik/aktif", headers=ortam["guard"]).json()
    assert any(x["id"] == t["alarm_id"] for x in aktif_g)


def test_YETKI_ve_DOGRULAMA(client, ortam, temiz):
    # Yalniz yonetim baslatir.
    r = client.post("/tatbikat", headers=ortam["guard"],
                    json={"kategori": "deprem", "kapsam": "site"})
    assert r.status_code == 403
    r = client.post("/tatbikat", headers=ortam["sakin"],
                    json={"kategori": "deprem", "kapsam": "site"})
    assert r.status_code == 403
    # Yardim kategorisinde tatbikat YOK.
    r = client.post("/tatbikat", headers=ortam["admin"],
                    json={"kategori": "saglik", "kapsam": "site"})
    assert r.status_code == 422
    # Olmayan blok.
    r = client.post("/tatbikat", headers=ortam["admin"],
                    json={"kategori": "deprem", "kapsam": "blok", "blok": "YOK-BLOK-XYZ"})
    assert r.status_code == 422
    # Hemen baslayanin onceden duyurusu olmaz.
    r = client.post("/tatbikat", headers=ortam["admin"],
                    json={"kategori": "deprem", "kapsam": "site", "duyuru": True})
    assert r.status_code == 422
    # Ayni anda iki aktif tatbikat yok.
    assert client.post("/tatbikat", headers=ortam["admin"],
                       json={"kategori": "deprem", "kapsam": "site"}).status_code == 201
    r = client.post("/tatbikat", headers=ortam["admin"],
                    json={"kategori": "gaz", "kapsam": "site"})
    assert r.status_code == 409
    # Guvenlik raporu OKUR.
    assert client.get("/tatbikat", headers=ortam["guard"]).status_code == 200
