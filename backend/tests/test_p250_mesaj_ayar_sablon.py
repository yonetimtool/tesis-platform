"""(P250 §8) Teknik mesaj ayarlari PLATFORMDA, sablonlar YONETICIDE.

Olculen:
  * yonetici teknik ayarlari GOREMEZ / YAZAMAZ / TEST EDEMEZ (403),
  * yonetici yalniz "hazir mi" durumunu gorur (sir yok),
  * platform admini HERHANGI bir tesisin ayarini tesis kimligiyle yazar,
  * hazir sablon kutuphanesi: 8 sablon x 2 kanal x 7 dil, bilinmeyen
    etiket YOK, SMS surumu en fazla 2 parca, kaydedilip gonderilebilir.
"""
from __future__ import annotations

import uuid

import pytest

from app import hazir_sablonlar
from app.mesajlasma import bilinmeyen_etiketler, etiketleri_coz, sms_olc


def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_yonetici_teknik_ayarlari_goremez_ama_durumu_gorur(client, world):
    y = _h(client, world["slug_a"], world["yonetici_a"])
    assert client.get("/mesaj-ayarlari", headers=y).status_code == 403
    assert client.put("/mesaj-ayarlari", headers=y,
                      json={"gunluk_kota": 5}).status_code == 403
    assert client.post("/mesaj-ayarlari/test", headers=y, json={
        "kanal": "sms", "hedef": "05001112233"}).status_code == 403
    assert client.get(f"/tenants/{world['a']}/mesaj-ayarlari",
                      headers=y).status_code == 403

    r = client.get("/mesaj-durumu", headers=y)
    assert r.status_code == 200, r.text
    d = r.json()
    assert set(d) == {"sms_hazir", "eposta_hazir", "bugun_gonderilen", "gunluk_kota"}
    # Sir sizmaz: durum cevabinda saglayici/parola alani YOK.
    assert "smtp_parola" not in r.text and "sms_kullanici" not in r.text


def test_platform_admini_baska_tesisin_ayarini_yazar(client, world):
    adm = _h(client, world["slug_a"], world["admin_a"])
    b = world["b"]
    r = client.put(f"/tenants/{b}/mesaj-ayarlari", headers=adm,
                   json={"gunluk_kota": 321})
    assert r.status_code == 200, r.text
    assert r.json()["gunluk_kota"] == 321
    assert client.get(f"/tenants/{b}/mesaj-ayarlari",
                      headers=adm).json()["gunluk_kota"] == 321
    # A tesisinin ayari ETKILENMEDI.
    assert client.get(f"/tenants/{world['a']}/mesaj-ayarlari",
                      headers=adm).json()["gunluk_kota"] != 321
    # Olmayan tesis -> 404.
    assert client.get(f"/tenants/{uuid.uuid4()}/mesaj-ayarlari",
                      headers=adm).status_code == 404
    # Test gonderimi de tesis kimligiyle (saglayici yok -> yapilandirilmadi).
    t = client.post(f"/tenants/{b}/mesaj-ayarlari/test", headers=adm,
                    json={"kanal": "sms", "hedef": "05001112233"})
    assert t.status_code == 200, t.text
    assert t.json()["durum"] != "gonderildi"


@pytest.mark.parametrize("dil", hazir_sablonlar.DILLER)
def test_hazir_sablonlar_her_dilde_tam_ve_gecerli(dil):
    for kanal in ("eposta", "sms"):
        liste = hazir_sablonlar.listele(kanal, dil)
        assert [s["kod"] for s in liste] == list(hazir_sablonlar.KODLAR)
        for s in liste:
            metin = f"{s['konu'] or ''} {s['govde']}"
            assert s["ad"] and s["govde"]
            assert bilinmeyen_etiketler(metin) == [], (dil, kanal, s["kod"])
            if kanal == "sms":
                assert s["konu"] is None
                ornek = etiketleri_coz(s["govde"], {
                    "site_adi": "Güneş Sitesi", "adres": "A-12", "borc": "1.250,00",
                    "odeme_kodu": "AB12CD", "adi_soyadi": "Ayşe YILMAZ"})
                assert sms_olc(ornek).parca <= 2, (dil, s["kod"], ornek)
            else:
                assert s["konu"]


def test_hazir_sablon_ucu_dil_ve_kanal(client, world):
    y = _h(client, world["slug_a"], world["yonetici_a"])
    r = client.get("/mesaj-sablonlari/hazir", headers=y,
                   params={"kanal": "sms", "dil": "de"})
    assert r.status_code == 200, r.text
    items = r.json()["items"]
    assert len(items) == len(hazir_sablonlar.KODLAR)
    assert all(i["kanal"] == "sms" and i["konu"] is None for i in items)
    assert any("Hausgeld" in i["govde"] for i in items)
    # Bilinmeyen dil -> Turkce; gecersiz kanal -> 422.
    tr = client.get("/mesaj-sablonlari/hazir", headers=y, params={"dil": "xx"}).json()
    assert tr["items"][0]["ad"] == "Aidat hatırlatma"
    assert client.get("/mesaj-sablonlari/hazir", headers=y,
                      params={"kanal": "faks"}).status_code == 422


def test_hazir_sablon_kendi_sablonu_olarak_kaydedilir_ve_odeme_kodu_dolar(client, world):
    y = _h(client, world["slug_a"], world["yonetici_a"])
    hazir = next(i for i in client.get(
        "/mesaj-sablonlari/hazir", headers=y, params={"kanal": "eposta"}).json()["items"]
        if i["kod"] == "odeme_kodu")
    r = client.post("/mesaj-sablonlari", headers=y, json={
        "kanal": "eposta", "ad": f"Kod {uuid.uuid4().hex[:6]}",
        "konu": hazir["konu"], "govde": hazir["govde"]})
    assert r.status_code == 201, r.text
    assert r.json()["bilinmeyen_etiketler"] == []
    assert "odeme_kodu" in r.json()["etiketler"]
    o = client.post("/mesajlar/onizleme", headers=y, params={"kanal": "eposta"},
                    json={"govde": hazir["govde"]})
    assert o.status_code == 200, o.text
    assert "{odeme_kodu}" not in o.text
