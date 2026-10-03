"""(P253 §B) Toplu mesaj: gonderim ONCESI ozet + dogru sonuc sayaclari.

Olculen:
  * `/mesajlar/alicilar` HICBIR SEY gondermez ve gonderimle AYNI sayiyi
    verir (onay ekranindaki "N kisiye gidecek" gercek olmali);
  * kanal yapilandirilmamissa (dev) mesaj GITMEZ ve sayac "gonderildi"
    DEMEZ — eskiden `yapilandirilmadi` sonucu gonderildi sayiliyordu;
  * yalniz yonetim.
"""
from __future__ import annotations

import uuid


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _sablon(client, h, kanal="eposta"):
    r = client.post("/mesaj-sablonlari", headers=h, json={
        "kanal": kanal, "ad": f"P253-{uuid.uuid4().hex[:6]}", "konu": "Duyuru",
        "govde": "Sayın {adi_soyadi}", "amac": "operasyonel"})
    assert r.status_code == 201, r.text
    return r.json()["id"]


def test_OZET_gondermez_ve_GONDERIMLE_AYNI_sayi(client, world, owner_conn):
    y = _h(client, world["slug_a"], world["yonetici_a"])
    sid = _sablon(client, y)
    kisiler = [u["id"] for u in client.get("/users", headers=y, params={"limit": 5}).json()["items"]]
    govde = {"sablon_id": sid, "user_ids": kisiler}
    with owner_conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM mesaj_gonderim WHERE sablon_id=%s", (sid,))
        assert cur.fetchone()[0] == 0
    o = client.post("/mesajlar/alicilar", headers=y, json=govde)
    assert o.status_code == 200, o.text
    o = o.json()
    assert o["toplam"] == len(kisiler) and o["kanal"] == "eposta"
    assert o["gonderilecek"] + o["riza_yok"] + o["adres_yok"] == o["toplam"]
    with owner_conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM mesaj_gonderim WHERE sablon_id=%s", (sid,))
        assert cur.fetchone()[0] == 0, "ozet ucu GONDERDI"
    g = client.post("/mesajlar/gonder", headers=y, json=govde).json()
    assert g["gonderildi"] + g["kuyrukta"] + g["gonderilemedi"] == o["gonderilecek"]
    assert g["adres_yok"] == o["adres_yok"] and g["riza_yok"] == o["riza_yok"]
    if not o["kanal_hazir"]:
        # KANAL YOK: hicbir sey GITMEDI ve sayac bunu soyluyor.
        assert g["gonderildi"] == 0 and g["gonderilemedi"] == o["gonderilecek"]


def test_OZET_yalniz_YONETIM(client, world):
    y = _h(client, world["slug_a"], world["yonetici_a"])
    sid = _sablon(client, y)
    for rol in ("guard_a", "amir_a", "resident_a"):
        h = _h(client, world["slug_a"], world[rol])
        assert client.post("/mesajlar/alicilar", headers=h,
                           json={"sablon_id": sid}).status_code == 403, rol
