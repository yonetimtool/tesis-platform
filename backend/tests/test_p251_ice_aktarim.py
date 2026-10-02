"""(P251 §6) ICE AKTARIM — satir numarasi, Turkce rol yazimi, ad/soyad.

Olculen:
  * hata satirindaki numara istemcinin gonderdigi (ekranda gorunen,
    1'den baslayan) numaranin AYNISI,
  * rol sutunu Turkce yazimlari tanir ("Kiracı", "KİRACI", "Malik oturan"),
    taninmayan deger sessizce duzeltilmez (satir hatasi),
  * ad/soyad Turkce buyuk/kucuk kuralina uyar (P250 §1).
"""
from __future__ import annotations

import uuid


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _aktar(client, h, satirlar, dogrula=True):
    r = client.post("/ice-aktarim/kisi", headers=h, json={
        "satirlar": satirlar, "yalniz_dogrula": dogrula, "dosya_adi": None})
    assert r.status_code == 201, r.text
    return r.json()


def _daire(owner_conn, world):
    no = f"P{uuid.uuid4().hex[:4]}"
    owner_conn.execute(
        "INSERT INTO unit (id, tenant_id, no, blok) VALUES (gen_random_uuid(), %s, %s, 'A')",
        (world["a"], no))
    return no


def _satir(no, **d):
    d.setdefault("soyad", "Test")
    d.setdefault("eposta", f"p251-{uuid.uuid4().hex[:8]}@ornek.com")
    return {"satir_no": no, "degerler": d}


def test_satir_no_ekrandakiyle_ayni_ve_turkce_rol(client, world, owner_conn):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    d = [_daire(owner_conn, world) for _ in range(4)]
    r = _aktar(client, h, [
        _satir(1, ad="Ali", daire_no=d[0], rol_tipi="Kiracı"),
        _satir(2, ad="Veli", daire_no=d[1], rol_tipi="KİRACI"),
        _satir(3, ad="Ayşe", daire_no=d[2], rol_tipi="Malik oturan"),
        _satir(4, ad="Can", daire_no=d[3], rol_tipi="komşu"),
    ])
    assert r["hatali"] == 1, r["hatalar"]
    h4 = r["hatalar"][0]
    assert h4["satir_no"] == 4 and h4["alan"] == "rol_tipi"


def test_ad_soyad_turkce_bicim(client, world, owner_conn):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    eposta = f"p251-{uuid.uuid4().hex[:8]}@ornek.com"
    r = _aktar(client, h, [_satir(1, ad="ışıl", soyad="ilhan", eposta=eposta)], dogrula=False)
    assert r["olusan"] == 1, r
    ad, soyad = owner_conn.execute(
        "SELECT ad, soyad FROM app_user WHERE email=%s", (eposta,)).fetchone()
    assert soyad == "İLHAN"
    assert ad == "Işıl İLHAN"
