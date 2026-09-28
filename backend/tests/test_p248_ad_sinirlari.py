"""(P248 gozden gecirme) GERCEK ADLAR SIGMALI — blok, daire no, tanim, firma.

Kullanici: "Blok adi siniri 8 karakter — cok dar. 'Güneş Blok', 'Menekşe
Blok', 'A1 Blok Doğu' gibi gercek blok adlari sigmiyor." Olculdu: sorun
yalniz uzunluk DEGILDI — desen (`^[A-Za-z0-9]+$`) bosluk ve Turkce harfi de
reddediyordu. Toplu olusturma daire no'yu "{blok}-{n}" diye kurdugu icin
daire no deseni ve uzunlugu bloga UYMALI.
"""
from __future__ import annotations

import uuid


def _h(client, world):
    cred = world["yonetici_a"]
    r = client.post("/auth/login", json={
        "tenant_slug": world["slug_a"], "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _ek():
    return uuid.uuid4().hex[:4]


def test_GERCEK_BLOK_ADLARI_KABUL(client, world):
    h = _h(client, world)
    for ad in ("Güneş Blok", "Menekşe Blok", "A1 Blok Doğu", "C-2", "St. Paul"):
        r = client.post("/blocks", headers=h, json={"ad": f"{ad} {_ek()}"})
        assert r.status_code == 201, (ad, r.text)


def test_BLOK_50_KABUL_51_RED(client, world):
    h = _h(client, world)
    elli = ("Güneş Vadisi Evleri 3. Etap Doğu Kanadı " + _ek() * 3)[:50]
    assert len(elli) == 50
    assert client.post("/blocks", headers=h, json={"ad": elli}).status_code == 201
    r = client.post("/blocks", headers=h, json={"ad": elli + "x"})
    assert r.status_code == 422


def test_TOPLU_OLUSTURMA_GERCEK_BLOKLA_ve_DAIRELER_DUZENLENEBILIR(client, world):
    """Uretilen "{blok}-{n}" numarasi daire no desenine ve uzunluguna uymali:
    aksi hâlde toplu olusan daire bir daha DUZENLENEMEZDI."""
    h = _h(client, world)
    blok = f"Menekşe Blok Doğu {_ek()}"
    r = client.post("/units/bulk", headers=h, json={
        "blok": blok, "kat_sayisi": 1, "kat_basi_daire": 2, "baslangic_no": 1})
    assert r.status_code == 201, r.text
    daire = r.json()["olusturulan"][0]
    assert daire["no"] == f"{blok}-1"
    r = client.patch(f"/units/{daire['id']}", headers=h, json={"no": daire["no"]})
    assert r.status_code == 200, r.text
    # En uzun blok (50) + tire + cok haneli numara da sigar (DAIRE_NO 60).
    uzun = ("Uzun Blok Adı " + "x" * 50)[:50]
    r = client.post("/units/bulk", headers=h, json={
        "blok": uzun, "kat_sayisi": 1, "kat_basi_daire": 1, "baslangic_no": 123456})
    assert r.status_code == 201, r.text
    d = r.json()["olusturulan"][0]
    assert client.patch(f"/units/{d['id']}", headers=h, json={"no": d["no"]}).status_code == 200


def test_TIRELI_BLOKTA_ONEK_ILK_TIREDEN_BOLUNMEZ(client, world):
    """ "C-2" blogunun "C-2-5" dairesi "C" blogunu iddia ediyor SAYILMAZ;
    baska bir kayitli blogun oneki ise hâlâ reddedilir."""
    h = _h(client, world)
    e = _ek().upper()
    tireli, baska = f"C{e}-2", f"C{e}"
    for ad in (tireli, baska):
        assert client.post("/blocks", headers=h, json={"ad": ad}).status_code == 201
    r = client.post("/units", headers=h, json={"no": f"{tireli}-5", "blok": tireli})
    assert r.status_code == 201, r.text
    # Yalniz rakam -> kendi blogunun onekiyle kanoniklesir.
    r = client.post("/units", headers=h, json={"no": "6", "blok": tireli})
    assert r.status_code == 201 and r.json()["no"] == f"{tireli}-6"
    # Baska KAYITLI blogun oneki -> 422 (davranis korunur).
    r = client.post("/units", headers=h, json={"no": f"{tireli}-7", "blok": baska})
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "validation_error"
    assert r.json()["error"]["message"]


def test_DAIRE_NO_BOSLUK_ve_TURKCE_HARF(client, world):
    h = _h(client, world)
    blok = f"Çarşı {_ek()}"
    assert client.post("/blocks", headers=h, json={"ad": blok}).status_code == 201
    r = client.post("/units", headers=h, json={"no": f"{blok}-Dükkan 2", "blok": blok})
    assert r.status_code == 201, r.text
    assert client.post("/units", headers=h, json={"no": "A/1", "blok": blok}).status_code == 422


def test_TANIM_ve_FIRMA_ADLARI_GENISLEDI(client, world):
    h = _h(client, world)
    tanim = ("Dubleks Çatı Katı (Bahçe Katlı, Teraslı) " + _ek() * 20)[:100]
    for uc in ("/unit-gruplari", "/unit-tipleri"):
        assert client.post(uc, headers=h, json={"ad": tanim}).status_code == 201, uc
        assert client.post(uc, headers=h, json={"ad": tanim + "x"}).status_code == 422, uc
    unvan = ("Yönetio Tesis Yönetim Danışmanlık Temizlik Güvenlik Hizmetleri "
             "Sanayi ve Ticaret Anonim Şirketi " + _ek() * 40)[:200]
    assert client.post("/firmalar", headers=h, json={"ad": unvan}).status_code == 201
    assert client.post("/firmalar", headers=h, json={"ad": unvan + "x"}).status_code == 422
