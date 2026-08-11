"""(P154 / Asama 10) TERS KAYIT + DEFTERDE SILME KILIDI.

Olculen dort sey:
  1. Defter satiri SILINEMEZ — veritabani duzeyinde (uygulama degil),
  2. Iptal TERS KAYIT yazar; orijinal DURUR ve bakiye sifirlanir,
  3. Iki kez iptal edilemez; iptalin iptali edilemez,
  4. Ice aktarim geri almasi defter satirini SILMEZ, TERSINE CEVIRIR
     (Asama 8 ile Asama 10 arasindaki cakismanin cozumu).
"""
from __future__ import annotations

import uuid

import pytest


def _giris(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def adm(client, world):
    return _giris(client, world["slug_a"], world["admin_a"])


def _kasa(client, adm):
    r = client.post("/kasalar", headers=adm, json={
        "kod": f"K{uuid.uuid4().hex[:5]}", "ad": "Test Kasa"})
    assert r.status_code == 201, r.text
    return r.json()["id"]


def _gelir(client, adm, kasa_id, tutar=50_000):
    r = client.post("/finans/hareketler", headers=adm, json={"satirlar": [
        {"tip": "gelir", "tutar_kurus": tutar, "kasa_id": kasa_id}
    ]})
    assert r.status_code == 201, r.text
    return r.json()["items"][0]


# ================== 1) DEFTER SATIRI SILINEMEZ (VERITABANI) ================ #

def test_app_rw_DELETE_yetkisi_YOK(owner_conn):
    """Uygulama katmaninda "silmiyoruz" demek yetmez: bugun hicbir uc
    silmiyor, yarin biri yazarsa kimse fark etmez. Yetkiyi geri almak
    kurali KANITLANABILIR kilar (`audit_log` ile ayni yol)."""
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT has_table_privilege('app_rw','finansal_hareket','DELETE')"
        )
        assert cur.fetchone()[0] is False, "defter satiri silinebiliyor"


def test_audit_log_kilidi_de_DURUYOR(owner_conn):
    """Olcum bosa dusmesin: yeni revoke eskisini bozmamis olmali."""
    with owner_conn.cursor() as cur:
        cur.execute("SELECT has_table_privilege('app_rw','audit_log','DELETE')")
        assert cur.fetchone()[0] is False


# ===================== 2) IPTAL TERS KAYIT YAZAR =========================== #

def test_IPTAL_orijinali_BIRAKIR_ve_bakiyeyi_sifirlar(client, adm, owner_conn):
    kasa_id = _kasa(client, adm)
    h = _gelir(client, adm, kasa_id)

    r = client.post(f"/finans/hareketler/{h['id']}/iptal", headers=adm,
                    json={"aciklama": "yanlis girildi"})
    assert r.status_code == 201, r.text
    iptal = r.json()
    assert iptal["tip"] == "iptal"
    assert iptal["yon"] == "cikis", "ters yon yazilmamis"
    assert iptal["tutar_kurus"] == h["tutar_kurus"]

    # ORIJINAL DURUYOR: defter append-only okunur.
    with owner_conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM finansal_hareket WHERE id = %s", (h["id"],))
        assert cur.fetchone()[0] == 1, "orijinal kayit silinmis"
        cur.execute(
            "SELECT ters_kayit_id FROM finansal_hareket WHERE id = %s", (iptal["id"],)
        )
        assert str(cur.fetchone()[0]) == h["id"], "iptal, iptal ettigini gostermiyor"

    # BAKIYE: giris + cikis = 0.
    bak = client.get("/finans/kasa-bakiyeleri", headers=adm).json()
    satir = next(k for k in bak["items"] if k["kasa_id"] == kasa_id)
    assert satir["bakiye_kurus"] == 0


def test_IPTAL_IADEDEN_AYRI_tiptir(client, adm):
    """Ikisini ayni tiple yazmak, "bu ay ne kadar iade verdik" sorusunu
    yanlis yanitlardi."""
    kasa_id = _kasa(client, adm)
    h = _gelir(client, adm, kasa_id)
    iptal = client.post(
        f"/finans/hareketler/{h['id']}/iptal", headers=adm, json={}
    ).json()
    assert iptal["tip"] == "iptal" and iptal["tip"] != "iade"


# ======================== 3) IKINCI IPTAL YOK ============================== #

def test_IKI_KEZ_iptal_edilemez(client, adm):
    """Iki ters kayit, orijinali geri getirmis gibi gorunen bir bakiye
    uretirdi."""
    kasa_id = _kasa(client, adm)
    h = _gelir(client, adm, kasa_id)
    assert client.post(
        f"/finans/hareketler/{h['id']}/iptal", headers=adm, json={}
    ).status_code == 201
    assert client.post(
        f"/finans/hareketler/{h['id']}/iptal", headers=adm, json={}
    ).status_code == 409


def test_IPTALIN_IPTALI_edilemez(client, adm):
    kasa_id = _kasa(client, adm)
    h = _gelir(client, adm, kasa_id)
    iptal = client.post(
        f"/finans/hareketler/{h['id']}/iptal", headers=adm, json={}
    ).json()
    assert client.post(
        f"/finans/hareketler/{iptal['id']}/iptal", headers=adm, json={}
    ).status_code == 422


def test_YALNIZ_ADMIN_iptal_edebilir(client, world, adm):
    kasa_id = _kasa(client, adm)
    h = _gelir(client, adm, kasa_id)
    yon = _giris(client, world["slug_a"], world["yonetici_a"])
    assert client.post(
        f"/finans/hareketler/{h['id']}/iptal", headers=yon, json={}
    ).status_code == 403


# ============ 4) ASAMA 8 CAKISMASI: geri alma TERSINE CEVIRIR ============== #

def test_ICE_AKTARIM_geri_almasi_defteri_SILMEZ(client, adm, world, owner_conn):
    """Asama 8'in geri almasi `acilis_bakiye` satirlarini SILIYORDU;
    goc 0047 DELETE'i kapatinca bu yol kirilirdi. Cozum kilidi
    gevsetmek DEGIL, ters kayit yazmak."""
    daire = f"TK-{uuid.uuid4().hex[:6]}"
    client.post("/ice-aktarim/daire", headers=adm, json={
        "satirlar": [{"satir_no": 1, "degerler": {"blok": "TK", "daire_no": daire}}]})

    sonuc = client.post("/ice-aktarim/acilis_bakiye", headers=adm, json={
        "satirlar": [{"satir_no": 1,
                      "degerler": {"daire_no": daire, "tutar": "100,00"}}]})
    assert sonuc.status_code == 201, sonuc.text
    aktarim_id = sonuc.json()["aktarim_id"]
    assert sonuc.json()["olusan"] == 1

    r = client.post(f"/ice-aktarim/{aktarim_id}/geri-al", headers=adm)
    assert r.status_code == 200, r.text

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT h.tip, h.yon, h.tutar_kurus, h.ters_kayit_id "
            "FROM finansal_hareket h JOIN unit u ON u.id = h.unit_id "
            "WHERE u.no = %s ORDER BY h.created_at",
            (daire,),
        )
        satirlar = cur.fetchall()

    # ORIJINAL + IPTAL: iki satir. Silme OLMADI.
    assert len(satirlar) == 2, f"beklenen 2 satir, gelen {len(satirlar)}"
    assert satirlar[0][0] == "acilis" and satirlar[1][0] == "iptal"
    assert satirlar[0][1] != satirlar[1][1], "ters yon yazilmamis"
    assert satirlar[1][3] is not None, "iptal neyi iptal ettigini gostermiyor"
