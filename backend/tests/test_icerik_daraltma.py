"""ICERIK DARALTMA KAPSAMI (P42) — ayni uc, role gore FARKLI GOVDE.

NEDEN BU OLCUM: `test_yetki_kapsam.py` kilidi ERISILEBILIRLIGI olcer
(401/403/digeri) ve P41'in `/yetki-matrisi` ucu da ayni katmandadir. Ikisi
de "IZIN" dedigi yerde govdenin ROLE GORE DARALDIGINI GORMEZ. Envanterin
acik maddesi tam olarak buydu: "aynı uç, farklı gövde — kilit bunu
görmüyor" (OLCULMEYEN-DURUMLAR-5, madde 4).

Bu dosya o katmani olcer: bir uc bes role de aciksa, GERCEKTEN her role
ayni veriyi mi veriyor? Daraltma VARSA calisiyor mu, YOKSA sizinti var mi?

OLCUMUN SINIRI (durustce): burada TEK TEK secilmis uclar var. Kapsam
otomatik degil cunku "hangi uc icerigi daraltmali" sorusunun makinece
turetilebilir bir yaniti yok — bu bir URUN kararidir. Bu yuzden dosya bir
ENVANTERDIR ve yeni bir daraltma eklendiginde buraya da satir eklenmelidir.
"""
from __future__ import annotations

import uuid

import pytest


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def rol(client, world):
    return {
        "admin": _h(client, world["slug_a"], world["admin_a"]),
        "yonetici": _h(client, world["slug_a"], world["yonetici_a"]),
        "security": _h(client, world["slug_a"], world["guard_a"]),
        "tesis_gorevlisi": _h(client, world["slug_a"], world["gorevli_a"]),
        "resident": _h(client, world["slug_a"], world["resident_a"]),
        "guvenlik_amiri": _h(client, world["slug_a"], world["amir_a"]),
    }


# ===================== 1. FINANSAL OZET: tahsilat blogu ===================== #
def test_financial_summary_TAHSILAT_yalniz_yonetime(client, rol):
    """Uc BES ROLE DE ACIK (seffaflik: agregat ozet) ama `tahsilat` blogu
    YALNIZ yonetime gider. Kilit bu ucu "IZIN IZIN IZIN IZIN IZIN" diye
    gosterir ve bu farki HIC gormez."""
    yonetim = client.get("/reports/financial-summary", headers=rol["admin"])
    assert yonetim.status_code == 200, yonetim.text
    assert yonetim.json().get("tahsilat") is not None

    for kim in ("security", "tesis_gorevlisi", "resident"):
        r = client.get("/reports/financial-summary", headers=rol[kim])
        assert r.status_code == 200, (kim, r.text)
        # SIZINTI OLCUMU: alan ya hic yok ya da null olmali.
        assert r.json().get("tahsilat") is None, kim


# ============================ 2. AKTIVITE AKISI ============================= #
def test_activity_ROL_KAYNAKLARI_uctan_daraltilir(client, rol):
    """`/activity` her role AYNI ucu acar ama KAYNAK KUMESI farklidir:
    security FINANS gormez, tesis_gorevlisi ziyaretci/kargo gormez."""
    tipler = {}
    for kim in ("admin", "yonetici", "security", "tesis_gorevlisi", "resident"):
        r = client.get("/activity", headers=rol[kim], params={"limit": 100})
        assert r.status_code == 200, (kim, r.text)
        tipler[kim] = {x["tur"] for x in r.json()["items"]}

    # Admin kumesi diger tum rollerin USTKUMESI olmali: bir rol adminde
    # olmayan bir tur goruyorsa, o tur admin'e kapali demektir ve bu
    # yetkilendirme hatasidir.
    for kim, kume in tipler.items():
        if kim == "admin":
            continue
        assert kume <= tipler["admin"], (kim, kume - tipler["admin"])


def test_activity_HER_IZINLI_ROLUN_kaynak_kumesi_TANIMLI():
    """SESSIZ 500 TUZAGI: `/activity` kaynak kumesini `_ROL_KAYNAKLARI[
    user.role]` ile secer. Uce yeni bir rol EKLENIP bu sozluge satir
    EKLENMEZSE, o rol icin uc KeyError ile 500 doner — ve hicbir mevcut
    olcum bunu yakalamaz (yetki kilidi 500'u "IZIN" sayar).
    """
    from app.deps import require_role  # noqa: F401  (kapali kutu degil)
    from app.routers import activity as akis

    izinli = getattr(akis._READER, "izinli_roller", None)
    assert izinli is not None, "P41 ozniteligi kayboldu"
    eksik = sorted(izinli - set(akis._ROL_KAYNAKLARI))
    assert not eksik, f"_ROL_KAYNAKLARI'nda tanimsiz rol(ler): {eksik}"


# =============================== 3. KAMERALAR =============================== #
def test_cameras_SAKIN_gizli_kamerayi_gormez(client, rol, world):
    """Uc bes role de acik; ama `sakin_gorebilir=false` kamerayi YALNIZ
    yonetim+guvenlik gorur. Erisim ayni, ICERIK farkli."""
    gizli = client.post("/cameras", headers=rol["admin"], json={
        "ad": f"Gizli {uuid.uuid4().hex[:5]}",
        "stream_url": "https://example.com/x.m3u8",
        "tur": "hls", "sakin_gorebilir": False})
    assert gizli.status_code == 201, gizli.text
    kid = gizli.json()["id"]

    tam = client.get("/cameras", headers=rol["admin"]).json()
    assert kid in [c["id"] for c in tam["items"]]

    for kim in ("resident", "tesis_gorevlisi"):
        r = client.get("/cameras", headers=rol[kim])
        assert r.status_code == 200, kim
        assert kid not in [c["id"] for c in r.json()["items"]], kim


# ========================= 4. TALEPLER (kendi kapsami) ====================== #
def test_complaints_ACAN_ROLLER_yalniz_kendini_gorur(client, rol, world):
    """Uc BES ROLE de acik ama acan roller YALNIZ kendi actiklarini gorur."""
    benim = client.post("/complaints", headers=rol["resident"], json={
        "baslik": f"Sakin talebi {uuid.uuid4().hex[:5]}", "mesaj": "metin"})
    assert benim.status_code == 201, benim.text
    bid = benim.json()["id"]

    baskasi = client.post("/complaints", headers=rol["security"], json={
        "baslik": f"Guvenlik talebi {uuid.uuid4().hex[:5]}", "mesaj": "metin"})
    assert baskasi.status_code == 201
    gid = baskasi.json()["id"]

    # Yonetim IKISINI de gorur.
    yonetim = [x["id"] for x in
               client.get("/complaints", headers=rol["yonetici"],
                          params={"limit": 200}).json()["items"]]
    assert bid in yonetim and gid in yonetim

    # Sakin YALNIZ kendisininkini; baskasinin kaydi 404 (varligi da
    # sizdirilmaz — 403 "boyle bir kayit var" demek olurdu).
    sakin = [x["id"] for x in
             client.get("/complaints", headers=rol["resident"],
                        params={"limit": 200}).json()["items"]]
    assert bid in sakin and gid not in sakin
    assert client.get(f"/complaints/{gid}", headers=rol["resident"]).status_code == 404


# ===================== 5. ANKET: sonuc gorunurlugu (P38) ==================== #
def test_anket_SONUC_yalniz_yonetime_ACIKKEN(client, rol):
    """Ayni uc, ayni anket: yonetim sayilari GORUR, sakin GORMEZ."""
    a = client.post("/anketler", headers=rol["yonetici"], json={
        "baslik": f"Daraltma {uuid.uuid4().hex[:5]}",
        "secenekler": [{"metin": "A"}, {"metin": "B"}]})
    assert a.status_code == 201, a.text
    aid = a.json()["id"]

    def _bul(h):
        liste = client.get("/anketler", headers=h, params={"limit": 200}).json()
        return next(x for x in liste["items"] if x["id"] == aid)

    assert _bul(rol["yonetici"])["toplam_oy"] is not None
    for kim in ("resident", "security", "tesis_gorevlisi", "guvenlik_amiri"):
        kayit = _bul(rol[kim])
        assert kayit["toplam_oy"] is None, kim
        assert all(s["oy"] is None for s in kayit["secenekler"]), kim


# ================= 6. SIKAYET YOGUNLUGU: sayi + renk (P24) ================== #
def test_unit_complaint_haritasi_SAYI_VE_RENK_yalniz_yonetimde(client, rol):
    """Bina haritasi TUM rollere acik (yapi herkese) ama SAYIM ve RENK
    yalniz yonetime doner — saha rolleri yalniz yapiyi gorur."""
    yonetim = client.get("/unit-complaints/building-map",
                         headers=rol["yonetici"])
    assert yonetim.status_code == 200, yonetim.text

    saha = client.get("/unit-complaints/building-map", headers=rol["security"])
    assert saha.status_code == 200, saha.text

    def _daireler(govde):
        d = list(govde.get("unplaced", []))
        for b in govde.get("bloklar", []):
            for k in b.get("katlar", []):
                d.extend(k.get("units", []))
        return d

    saha_daireler = _daireler(saha.json())
    # Saha rolunde sayim/renk YOK: dolu gelseydi komsu davranisi hakkinda
    # veri sizardi (P24/KVKK).
    for u in saha_daireler:
        assert u.get("complaint_count") is None, u
        assert u.get("renk") is None, u
