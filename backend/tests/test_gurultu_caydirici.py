"""Gurultu caydirici (P37) — esik -> eylem -> sifirlama."""
from __future__ import annotations

import json
import uuid
from datetime import datetime, timedelta, timezone

import pytest

from app.gurultu import (
    MAX_DENEME,
    VARSAYILAN_UYARI,
    esik_asildi,
    govde_uret,
    imza_dogrula,
    imzala,
    uyari_metni,
    yeniden_deneme_gecikmesi,
    yeniden_denenmeli,
)

UTC = timezone.utc


# ============================== SAF CEKIRDEK ================================ #
def test_esik_SINIRI_DAHILDIR():
    """`>` olsaydi esik ayari kullaniciya soyledigi sayidan BIR FAZLASINDA
    calisirdi."""
    assert esik_asildi(4, 5) is False
    assert esik_asildi(5, 5) is True
    assert esik_asildi(6, 5) is True
    # 0/negatif esik = KAPALI (kaza sonucu her sikayette anons yapilmasin).
    assert esik_asildi(99, 0) is False


def test_metin_BOS_ISE_de_varsayilana_duser():
    """Iceriksiz bir anons kullanicinin niyeti olamaz."""
    assert uyari_metni(None) == VARSAYILAN_UYARI
    assert uyari_metni("   ") == VARSAYILAN_UYARI
    assert uyari_metni("Kendi metnimiz") == "Kendi metnimiz"


def test_govde_DETERMINISTIK():
    """Alici govdeyi yeniden serilestirip AYNI imzayi uretebilmeli."""
    z = datetime(2026, 7, 31, 12, 0, tzinfo=UTC)
    a = govde_uret(daire_no="A-1", metin="m", zaman=z)
    b = govde_uret(daire_no="A-1", metin="m", zaman=z)
    assert a == b
    veri = json.loads(a)
    assert veri["daire"] == "A-1" and veri["tip"] == "gurultu_uyarisi"
    # Anahtarlar SIRALI (imza bayt-bayt hesaplanir).
    assert list(veri.keys()) == sorted(veri.keys())


def test_imza_ZAMAN_DAMGASINI_kapsar():
    """Yalniz govdeyi imzalamak, ele gecirilmis bir istegin SONSUZA DEK
    yeniden oynatilabilmesi demekti."""
    govde = b'{"a":1}'
    i1 = imzala("gizli", govde, 1000)
    i2 = imzala("gizli", govde, 2000)
    assert i1 != i2
    assert imza_dogrula("gizli", govde, 1000, i1)
    # Baska damga ile ayni imza GECERSIZ (replay kapali).
    assert not imza_dogrula("gizli", govde, 2000, i1)
    # Baska sir ile gecersiz.
    assert not imza_dogrula("baska", govde, 1000, i1)


def test_geri_cekilme_KATLANIR():
    assert yeniden_deneme_gecikmesi(0) == timedelta(minutes=1)
    assert yeniden_deneme_gecikmesi(1) == timedelta(minutes=5)
    assert yeniden_deneme_gecikmesi(2) == timedelta(minutes=25)


def test_yeniden_deneme_penceresi():
    t0 = datetime(2026, 7, 31, 12, 0, tzinfo=UTC)
    # Hic denenmemis kayit HEMEN denenir.
    assert yeniden_denenmeli(deneme=0, son_deneme_at=None, simdi=t0)
    # 1. denemeden sonra 5 dk beklenir.
    assert not yeniden_denenmeli(
        deneme=1, son_deneme_at=t0, simdi=t0 + timedelta(minutes=4))
    assert yeniden_denenmeli(
        deneme=1, son_deneme_at=t0, simdi=t0 + timedelta(minutes=5))
    # Denemeler tukendiyse DURUR (yanlis yapilandirilmis uca sonsuz istek yok).
    assert not yeniden_denenmeli(
        deneme=MAX_DENEME, son_deneme_at=t0, simdi=t0 + timedelta(days=1))


# ============================== UCTAN UCA =================================== #
def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def d(client, world, owner_conn):
    """Yonetici + sakin + sakinin blogunda bir hedef daire."""
    yonetici = _h(client, world["slug_a"], world["yonetici_a"])
    sakin_h = _h(client, world["slug_a"], world["resident_a"])
    sakin_id = client.get("/me", headers=sakin_h).json()["id"]

    blok = f"G{uuid.uuid4().hex[:3].upper()}"
    kendi = client.post("/units", headers=yonetici,
                        json={"no": f"{blok}-1", "blok": blok}).json()
    hedef = client.post("/units", headers=yonetici,
                        json={"no": f"{blok}-2", "blok": blok}).json()
    # Sakini KENDI dairesine bagla (own-block kurali).
    owner_conn.execute(
        "INSERT INTO unit_resident (tenant_id, unit_id, user_id, rol_tipi, "
        "baslangic) VALUES (%s,%s,%s,'malik', now())",
        (world["a"], kendi["id"], sakin_id))
    from types import SimpleNamespace
    return SimpleNamespace(
        yonetici=yonetici, sakin=sakin_h, hedef=hedef, blok=blok,
        conn=owner_conn, tenant=world["a"], slug=world["slug_a"],
        world=world, client=client)


def _sikayet(d, kategori="gurultu"):
    """Haftalik spam limiti KISI BAZLIDIR — her sikayet icin YENI sakin.

    Sakin owner baglantisiyla acilir: `/users` sakin ROLU acamaz (yetki
    yukseltme korumasi) ve `/residents` akisi burada olculen sey degil.
    """
    from app.security import hash_password

    tel = f"+9054{uuid.uuid4().int % 10**8:08d}"
    uid = uuid.uuid4()
    d.conn.execute(
        "INSERT INTO app_user (id, tenant_id, ad, email, telefon, "
        "password_hash, password_set, role) "
        "VALUES (%s,%s,%s,%s,%s,%s,true,'resident'::user_role)",
        (uid, d.tenant, "Sikayetci", f"s-{uid.hex[:8]}@x.com", tel,
         hash_password("Parola123!")))
    # Ayni bloga bagla (own-block).
    kendi = d.client.post("/units", headers=d.yonetici, json={
        "no": f"{d.blok}-{uuid.uuid4().hex[:4]}", "blok": d.blok}).json()
    d.conn.execute(
        "INSERT INTO unit_resident (tenant_id, unit_id, user_id, rol_tipi, "
        "baslangic) VALUES (%s,%s,%s,'malik', now())",
        (d.tenant, kendi["id"], uid))
    r = d.client.post("/auth/login-phone", json={
        "phone": tel, "password": "Parola123!"})
    assert r.status_code == 200, r.text
    basliklar = {"Authorization": f"Bearer {r.json()['access_token']}"}
    return d.client.post("/unit-complaints", headers=basliklar, json={
        "target_unit_id": d.hedef["id"], "kategori": kategori})


def _uyarilar(d):
    return d.client.get("/unit-uyarilari", headers=d.yonetici,
                        params={"unit_id": d.hedef["id"]}).json()["items"]


def test_DORT_tetiklemez_BES_tetikler_ve_SIFIRLAR(d):
    """Sinir davranisi olcumun kalbi: 4'te hicbir sey olmamali."""
    for _ in range(4):
        assert _sikayet(d).status_code == 201
    assert _uyarilar(d) == [], "4 sikayette uyari OLMAMALI"
    # Renk skalasi hala dolu (ACIK sayisi 4).
    yog = d.client.get("/unit-complaints/density", headers=d.yonetici).json()
    satir = next(x for x in yog["items"]
                 if x["target_unit_id"] == d.hedef["id"])
    assert satir["acik_sayisi"] == 4
    assert satir["renk"] == "kirmizi", "3-4 = kirmizi (P24 skalasi)"

    assert _sikayet(d).status_code == 201
    uyari = _uyarilar(d)
    assert len(uyari) == 1, "5. sikayette uyari verilmeli"
    assert uyari[0]["esik"] == 5 and uyari[0]["sayac"] == 5
    assert uyari[0]["metin"] == VARSAYILAN_UYARI

    # SIFIRLAMA: kayitlar DURUR, sayac sifirlanir (renk yesile doner).
    yog2 = d.client.get("/unit-complaints/density", headers=d.yonetici).json()
    satir2 = next(
        (x for x in yog2["items"] if x["target_unit_id"] == d.hedef["id"]),
        None)
    # Sayac sifirlandi: ya satir hic donmez ya da 0/yesil.
    assert satir2 is None or (
        satir2["acik_sayisi"] == 0 and satir2["renk"] == "yesil")
    kalan = d.conn.execute(
        "SELECT count(*) FROM unit_complaint WHERE target_unit_id = %s",
        (d.hedef["id"],)).fetchone()[0]
    assert kalan == 5, "kayitlar SILINMEZ, gecmiste durur"


def test_YALNIZ_GURULTU_kategorisi_sayilir(d):
    """Kapi onune ayakkabi birakan daireye 'gurultu uyarisi' anonsu yapmak
    caydiriciyi anlamsiz kilardi."""
    for _ in range(5):
        assert _sikayet(d, kategori="kapi_onu_ayakkabi").status_code == 201
    assert _uyarilar(d) == []


def test_ENTEGRASYON_YOKKEN_manuel_mod(d):
    """Manuel mod bir HATA DURUMU DEGIL, birinci sinif mod: cogu sitede
    entegrasyon hic olmayacak."""
    for _ in range(5):
        _sikayet(d)
    u = _uyarilar(d)[0]
    assert u["kanal"] == "manuel"
    assert u["durum"] == "manuel_bekliyor"
    assert u["deneme"] == 0


def test_manuel_YAPILDI_isaretlemesi(d):
    for _ in range(5):
        _sikayet(d)
    uid = _uyarilar(d)[0]["id"]
    r = d.client.post(f"/unit-uyarilari/{uid}/yapildi", headers=d.yonetici)
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "manuel_yapildi"
    # Ikinci kez isaretlemek 409 (sessizce yutmak, denetimde iki kez
    # yapilmis gibi gorunmesine yol acardi).
    assert d.client.post(f"/unit-uyarilari/{uid}/yapildi",
                         headers=d.yonetici).status_code == 409


def test_ESIK_TENANT_AYARI(d):
    r = d.client.patch("/tenant/settings", headers=d.yonetici,
                       json={"gurultu_esigi": 2, "gurultu_uyari_metni": "Özel metin"})
    assert r.status_code == 200, r.text
    try:
        _sikayet(d)
        assert _uyarilar(d) == []
        _sikayet(d)
        u = _uyarilar(d)
        assert len(u) == 1 and u[0]["esik"] == 2
        assert u[0]["metin"] == "Özel metin"
    finally:
        d.client.patch("/tenant/settings", headers=d.yonetici,
                       json={"gurultu_esigi": 5, "gurultu_uyari_metni": None})


def test_esik_SINIRLARI(d):
    assert d.client.patch("/tenant/settings", headers=d.yonetici,
                          json={"gurultu_esigi": 0}).status_code == 422
    assert d.client.patch("/tenant/settings", headers=d.yonetici,
                          json={"gurultu_esigi": 51}).status_code == 422


def test_uyari_kaydi_YALNIZ_YONETIM(d, world, client):
    for _ in range(5):
        _sikayet(d)
    for rol in ("resident_a", "guard_a", "gorevli_a"):
        h = _h(client, world["slug_a"], world[rol])
        assert client.get("/unit-uyarilari", headers=h).status_code == 403


def test_ESIK_SONRASI_yeniden_birikir(d):
    """Sifirlama sayaci sifirlar, ozelligi KAPATMAZ: daire tekrar esige
    varirsa IKINCI uyari verilir."""
    for _ in range(5):
        _sikayet(d)
    assert len(_uyarilar(d)) == 1
    for _ in range(5):
        _sikayet(d)
    assert len(_uyarilar(d)) == 2


def test_tenant_izolasyonu(d, world, client):
    for _ in range(5):
        _sikayet(d)
    b = _h(client, world["slug_b"], world["yonetici_b"])
    assert client.get("/unit-uyarilari", headers=b).json()["items"] == []


# ========================= WEBHOOK MODU + IMZA ============================== #
def test_WEBHOOK_modu_ve_SSRF_kapisi(d):
    """Entegrasyon secilince kanal `webhook` olur.

    Hedef OZEL bir adres oldugu icin SSRF kapisi REDDEDER — ve bu tam olarak
    olculmek istenen sey: caydirici, ic aga istek atmak icin kullanilamaz.
    Kayit `basarisiz` olur ve YENIDEN DENEME kuyrugunda bekler; sikayet
    kaydi bundan ETKILENMEZ.
    """
    ent = d.client.post("/integrations", headers=d.yonetici, json={
        "ad": "Anons", "channel_type": "smarthome",
        "endpoint_url": "http://192.168.1.50/announce",
        "auth_type": "api_key", "auth_secret": "sir123",
        "payload_template": "{}"})
    assert ent.status_code == 201, ent.text
    r = d.client.patch("/tenant/settings", headers=d.yonetici,
                       json={"gurultu_integration_id": ent.json()["id"]})
    assert r.status_code == 200, r.text
    try:
        for _ in range(5):
            assert _sikayet(d).status_code == 201, "caydirici ucu DUSURMEZ"
        u = _uyarilar(d)[0]
        assert u["kanal"] == "webhook"
        assert u["durum"] == "basarisiz"
        assert u["deneme"] == 1
        assert u["hata"]

        # Kuyruk: geri cekilme suresi dolmadigi icin HENUZ denenmez.
        k = d.client.post("/unit-uyarilari/kuyruk-isle",
                          headers=_h(d.client, d.slug, d.world["admin_a"]))
        assert k.status_code == 200, k.text
        assert k.json()["islenen"] == 0, "1 dk gecmeden yeniden denenmez"
    finally:
        d.client.patch("/tenant/settings", headers=d.yonetici,
                       json={"gurultu_integration_id": None})


def test_ALICI_imzayi_DOGRULAYABILIR():
    """Alici tarafinin yapmasi gerekeni gosteren uctan uca ornek: govde
    yeniden serilestirilip ayni imza uretilebilmeli."""
    z = datetime(2026, 7, 31, 21, 0, tzinfo=UTC)
    govde = govde_uret(daire_no="B-12", metin=VARSAYILAN_UYARI, zaman=z)
    damga = 1785000000
    imza = imzala("paylasilan-sir", govde, damga)

    # --- alici tarafi ---
    veri = json.loads(govde)
    yeniden = govde_uret(
        daire_no=veri["daire"], metin=veri["metin"],
        zaman=datetime.fromisoformat(veri["zaman"]))
    assert yeniden == govde
    assert imza_dogrula("paylasilan-sir", yeniden, damga, imza)
