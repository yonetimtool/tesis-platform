"""(P249 §3) GUVENLIKTEN DAIREYE ULASMA — onay talebi, sesli mesaj, telefon.

Saha sorunu: ev sahibi evde degil, biri "beni bekliyor" diyor, guvenlik
dogrulayamiyor. Olculen:
  (a) onay talebi dairenin TUM aktif sakinlerine gider, ilk yanit gecerli,
      yanit guvenlige doner, sure dolunca "cevap yok",
  (b) sesli mesaj yalniz o dairenin sakinine ulasir, dinlenince isaretlenir,
      silinince erisilemez, 7 gun sonra imha edilir,
  (e) telefon YALNIZ sakin izin verdiyse, TEK kisi icin ve DENETIM
      kaydiyla acilir; ozet uc numara DONDURMEZ.
"""
from __future__ import annotations

import uuid

import pytest


def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _uid(client, h):
    return client.get("/me", headers=h).json()["id"]


@pytest.fixture
def daire(client, world):
    """Sakin A bir daireye bagli (world'un sakini daireye bagli degil)."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    sakin = _h(client, world["slug_a"], world["resident_a"])
    guard = _h(client, world["slug_a"], world["guard_a"])
    blok = f"UL{uuid.uuid4().hex[:4].upper()}"
    client.post("/blocks", headers=admin, json={"ad": blok})
    r = client.post("/units", headers=admin, json={"no": f"{blok}-1", "blok": blok})
    assert r.status_code == 201, r.text
    unit_id = r.json()["id"]
    sakin_id = _uid(client, sakin)
    r = client.post(f"/units/{unit_id}/residents", headers=admin,
                    json={"user_id": sakin_id, "rol_tipi": "malik", "oturuyor": True})
    assert r.status_code in (200, 201), r.text
    yield {"admin": admin, "sakin": sakin, "guard": guard, "unit_id": unit_id,
           "sakin_id": sakin_id, "no": f"{blok}-1"}
    client.patch("/me/bildirim-tercihleri", headers=sakin, json={"yonetim_arayabilir": False})
    client.delete(f"/units/{unit_id}/residents/{sakin_id}", headers=admin)


# ============================ (a) ONAY TALEBI ============================== #
def _onay_iste(client, d):
    r = client.post("/visitors", headers=d["guard"], json={
        "unit_id": d["unit_id"], "ziyaretci_ad": "Kurye Ali",
        "target_resident_user_id": d["sakin_id"], "onay_iste": True})
    assert r.status_code == 201, r.text
    return r.json()


def test_ONAY_TALEBI_SAKINE_GIDER_ONAY_GUVENLIGE_DONER(client, daire):
    v = _onay_iste(client, daire)
    assert v["onay_durum"] == "bekliyor" and v["onay_son_at"]
    b = client.get("/notifications", headers=daire["sakin"], params={"limit": 20}).json()
    assert any(x["tip"] == "ziyaretci_onay_istegi" for x in b["items"])

    r = client.post(f"/visitors/{v['id']}/onay", headers=daire["sakin"], json={"karar": "onayla"})
    assert r.status_code == 200, r.text
    assert r.json()["onay_durum"] == "onaylandi"
    g = client.get(f"/visitors/{v['id']}", headers=daire["guard"]).json()
    assert g["onay_durum"] == "onaylandi" and g["onay_yanitlayan_ad"]
    b = client.get("/notifications", headers=daire["guard"], params={"limit": 20}).json()
    assert any(x["tip"] == "ziyaretci_onay_yaniti" for x in b["items"])
    # ILK YANIT GECERLI: ikinci yanit 409.
    r = client.post(f"/visitors/{v['id']}/onay", headers=daire["sakin"], json={"karar": "reddet"})
    assert r.status_code == 409


def test_ONAY_BASKA_DAIRENIN_SAKINI_YANITLAYAMAZ(client, world, daire):
    v = _onay_iste(client, daire)
    baska = _h(client, world["slug_b"], world["resident_b"]) if "resident_b" in world else None
    if baska is not None:
        r = client.post(f"/visitors/{v['id']}/onay", headers=baska, json={"karar": "onayla"})
        assert r.status_code == 404
    # Guvenlik "sakin gibi" yanit veremez.
    r = client.post(f"/visitors/{v['id']}/onay", headers=daire["guard"], json={"karar": "onayla"})
    assert r.status_code == 403


def test_SURE_DOLUNCA_CEVAP_YOK_ve_GUVENLIGE_BILDIRIM(client, daire, owner_conn):
    from app.daireye_ulas_isi import onay_suresi_dolanlar

    v = _onay_iste(client, daire)
    with owner_conn.cursor() as cur:
        cur.execute("UPDATE visitor SET onay_son_at = now() - interval '1 minute' WHERE id=%s",
                    (v["id"],))
    onay_suresi_dolanlar()
    g = client.get(f"/visitors/{v['id']}", headers=daire["guard"]).json()
    assert g["onay_durum"] == "cevap_yok"
    b = client.get("/notifications", headers=daire["guard"], params={"limit": 20}).json()
    assert any(x["tip"] == "ziyaretci_onay_yaniti"
               and "yanıt vermedi" in (x["mesaj"] or "") for x in b["items"])


def test_ONAY_ISTENMEMIS_KAYIT_ESKI_LOG_DAVRANISI(client, daire):
    r = client.post("/visitors", headers=daire["guard"], json={
        "unit_id": daire["unit_id"], "ziyaretci_ad": "Misafir",
        "target_resident_user_id": daire["sakin_id"]})
    assert r.status_code == 201
    assert r.json()["onay_durum"] is None


# ============================ (b) SESLI MESAJ ============================== #
def _ses_gonder(client, d):
    y = client.post(f"/units/{d['unit_id']}/sesli-mesaj/yukleme", headers=d["guard"],
                    json={"icerik_turu": "audio/mp4", "boyut": 20000})
    assert y.status_code == 200, y.text
    anahtar = y.json()["anahtar"]
    # GERCEK YUKLEME: sunucu dosyanin depoda oldugunu dogruluyor.
    import httpx

    put = httpx.put(y.json()["url"], content=b"\x00" * 20000,
                    headers={"Content-Type": "audio/mp4"}, timeout=10)
    assert put.status_code == 200, put.text
    r = client.post(f"/units/{d['unit_id']}/sesli-mesaj", headers=d["guard"],
                    json={"anahtar": anahtar, "sure_ms": 4200, "boyut": 20000,
                          "icerik_turu": "audio/mp4"})
    assert r.status_code == 201, r.text
    return r.json()


def test_SESLI_MESAJ_SAKINE_ULASIR_DINLENINCE_ISARETLENIR(client, daire):
    m = _ses_gonder(client, daire)
    b = client.get("/notifications", headers=daire["sakin"], params={"limit": 20}).json()
    assert any(x["tip"] == "sesli_mesaj" for x in b["items"])
    liste = client.get("/sesli-mesaj", headers=daire["sakin"]).json()
    assert any(x["id"] == m["id"] for x in liste)
    d = client.get(f"/sesli-mesaj/{m['id']}/dinle", headers=daire["sakin"])
    assert d.status_code == 200 and d.json()["url"].startswith("http")
    # GONDEREN dinlendigini gorur.
    g = client.get("/sesli-mesaj", headers=daire["guard"]).json()
    assert next(x for x in g if x["id"] == m["id"])["dinlendi_at"]


def test_SESLI_MESAJ_BASKASI_DINLEYEMEZ_SILINCE_ERISILEMEZ(client, world, daire):
    m = _ses_gonder(client, daire)
    admin = daire["admin"]
    # Yonetim (gonderen degil, sakin degil) DINLEYEMEZ — ses kisisel veri.
    assert client.get(f"/sesli-mesaj/{m['id']}/dinle", headers=admin).status_code == 404
    assert client.delete(f"/sesli-mesaj/{m['id']}", headers=daire["sakin"]).status_code == 204
    assert client.get(f"/sesli-mesaj/{m['id']}/dinle", headers=daire["sakin"]).status_code == 404


def test_SESLI_MESAJ_BASKA_DAIRENIN_ANAHTARI_BAGLANAMAZ(client, daire):
    r = client.post(f"/units/{daire['unit_id']}/sesli-mesaj", headers=daire["guard"],
                    json={"anahtar": "baska/sesli-mesaj/x/y.m4a", "sure_ms": 1000,
                          "boyut": 1000, "icerik_turu": "audio/mp4"})
    assert r.status_code == 422
    r = client.post(f"/units/{daire['unit_id']}/sesli-mesaj/yukleme", headers=daire["guard"],
                    json={"icerik_turu": "video/mp4", "boyut": 1000})
    assert r.status_code == 422
    # YUKLENMEMIS dosya baglanamaz (sunucu depoda arar).
    y0 = client.post(f"/units/{daire['unit_id']}/sesli-mesaj/yukleme", headers=daire["guard"],
                     json={"icerik_turu": "audio/mp4", "boyut": 1000}).json()
    r = client.post(f"/units/{daire['unit_id']}/sesli-mesaj", headers=daire["guard"],
                    json={"anahtar": y0["anahtar"], "sure_ms": 1000, "boyut": 1000,
                          "icerik_turu": "audio/mp4"})
    assert r.status_code == 422
    # 60 sn'yi asan mesaj reddedilir.
    y = client.post(f"/units/{daire['unit_id']}/sesli-mesaj/yukleme", headers=daire["guard"],
                    json={"icerik_turu": "audio/mp4", "boyut": 1000}).json()
    r = client.post(f"/units/{daire['unit_id']}/sesli-mesaj", headers=daire["guard"],
                    json={"anahtar": y["anahtar"], "sure_ms": 61000, "boyut": 1000,
                          "icerik_turu": "audio/mp4"})
    assert r.status_code == 422


def test_SESLI_MESAJ_7_GUN_SONRA_IMHA(client, daire, owner_conn):
    from app.daireye_ulas_isi import sesli_mesaj_imhasi

    m = _ses_gonder(client, daire)
    with owner_conn.cursor() as cur:
        cur.execute("UPDATE daire_sesli_mesaj SET created_at = now() - interval '8 days' "
                    "WHERE id=%s", (m["id"],))
    sesli_mesaj_imhasi()
    with owner_conn.cursor() as cur:
        cur.execute("SELECT depo_anahtari, silindi_at FROM daire_sesli_mesaj WHERE id=%s",
                    (m["id"],))
        anahtar, silindi = cur.fetchone()
    assert anahtar is None and silindi is not None


def test_SAKIN_SESLI_MESAJ_GONDEREMEZ(client, daire):
    r = client.post(f"/units/{daire['unit_id']}/sesli-mesaj/yukleme", headers=daire["sakin"],
                    json={"icerik_turu": "audio/mp4", "boyut": 1000})
    assert r.status_code == 403


# =========================== (e) TELEFON YEDEGI ============================ #
def test_TELEFON_YALNIZ_IZINLE_TEK_KISI_DENETIMLI(client, daire, owner_conn):
    with owner_conn.cursor() as cur:
        cur.execute("UPDATE app_user SET telefon='+905551234567' WHERE id=%s",
                    (daire["sakin_id"],))
    # Ozet uc NUMARA DONDURMEZ.
    oz = client.get(f"/units/{daire['unit_id']}/ulas", headers=daire["guard"])
    assert oz.status_code == 200, oz.text
    assert "5551234567" not in oz.text
    s = next(x for x in oz.json()["sakinler"] if x["user_id"] == daire["sakin_id"])
    assert s["telefonla_aranabilir"] is False
    # Izin YOKKEN numara acilmaz.
    r = client.post(f"/units/{daire['unit_id']}/ulas/telefon", headers=daire["guard"],
                    json={"user_id": daire["sakin_id"]})
    assert r.status_code == 403 and "5551234567" not in r.text
    # Sakin izin verir.
    r = client.patch("/me/bildirim-tercihleri", headers=daire["sakin"],
                     json={"yonetim_arayabilir": True})
    assert r.status_code == 200 and r.json()["yonetim_arayabilir"] is True
    oz = client.get(f"/units/{daire['unit_id']}/ulas", headers=daire["guard"]).json()
    assert next(x for x in oz["sakinler"] if x["user_id"] == daire["sakin_id"])[
        "telefonla_aranabilir"] is True
    r = client.post(f"/units/{daire['unit_id']}/ulas/telefon", headers=daire["guard"],
                    json={"user_id": daire["sakin_id"]})
    assert r.status_code == 200 and r.json()["telefon"] == "+905551234567"
    with owner_conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM audit_log WHERE action='daire_telefon_goster' "
                    "AND resource_id=%s", (daire["unit_id"],))
        assert cur.fetchone()[0] >= 1, "her numara acilisi DENETIM kaydina gecmeli"


def test_SAKIN_ULAS_UCUNU_KULLANAMAZ(client, daire):
    assert client.get(f"/units/{daire['unit_id']}/ulas", headers=daire["sakin"]).status_code == 403
