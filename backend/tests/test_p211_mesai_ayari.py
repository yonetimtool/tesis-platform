"""(P211 §5) FAZLA MESAI KATSAYISI ARTIK UCTAN DEGISTIRILEBILIYOR.

===========================================================================
OLCULEN BOSLUK
===========================================================================
P203 §5 `tenant.mesai_katsayisi` sutununu acti ve belgesine
"DEGISTIRILEBILIR" yazdi — ama hicbir uc onu YAZMIYORDU. Yani soz ancak
veritabanina elle SQL yazarak tutuluyordu; P203 testi de katsayiyi
`UPDATE tenant ...` ile degistirerek olcuyordu (bu dosyanin varlik
sebebi tam olarak o satir).

KILITLENEN KURALLAR
  1. Yonetici katsayiyi degistirebilir ve OZET yeni katsayiyi kullanir,
  2. Denetci OKUR ama YAZAMAZ (sayi dogrudan paraya cevriliyor),
  3. Sinir disi degerler 422 — "150" gibi bir yazim hatasi bir maasi
     150 katina cikarip ONAY BEKLEYEN GIDERE donusurdu,
  4. Tesis izolasyonu: bir tesisin katsayisi otekini etkilemez.
"""
from __future__ import annotations


def _giris(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _eski_haline(client, h, deger):
    client.patch("/mesai/ayar", headers=h, json={"katsayi": deger})


def test_yonetici_katsayiyi_DEGISTIRIR(client, world):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    onceki = client.get("/mesai/ayar", headers=h).json()["katsayi"]
    try:
        r = client.patch("/mesai/ayar", headers=h, json={"katsayi": 2.25})
        assert r.status_code == 200, r.text
        assert r.json()["katsayi"] == 2.25
        # OKUMA DA GORUR: yalniz yaniti olcmek, yazilmadigi hâlde
        # "yazildi" diyen bir ucu gecirebilirdi.
        assert client.get("/mesai/ayar", headers=h).json()["katsayi"] == 2.25
    finally:
        _eski_haline(client, h, onceki)


def test_OZET_yeni_katsayiyi_KULLANIR(client, world):
    # Ayarin bir sonuca donustugunu olcer: yalniz saklanmasi yetmez.
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    onceki = client.get("/mesai/ayar", headers=h).json()["katsayi"]
    try:
        client.patch("/mesai/ayar", headers=h, json={"katsayi": 2.0})
        d = client.get("/mesai/ozet", headers=h, params={"yil": 2026, "ay": 9})
        assert d.status_code == 200, d.text
        assert d.json()["katsayi"] == 2.0
    finally:
        _eski_haline(client, h, onceki)


def test_DENETCI_okur_ama_YAZAMAZ(client, world):
    h = _giris(client, world["slug_a"], world["denetci_a"])
    assert client.get("/mesai/ayar", headers=h).status_code == 200
    r = client.patch("/mesai/ayar", headers=h, json={"katsayi": 3.0})
    assert r.status_code == 403, r.text


def test_SINIR_DISI_degerler_422(client, world):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    for deger in (0, 0.5, 150, 5.01, -1):
        r = client.patch("/mesai/ayar", headers=h, json={"katsayi": deger})
        assert r.status_code == 422, f"{deger} -> {r.status_code} {r.text}"


def test_TESIS_IZOLASYONU_katsayi_sizmaz(client, world):
    a = _giris(client, world["slug_a"], world["yonetici_a"])
    b = _giris(client, world["slug_b"], world["admin_b"])
    onceki_a = client.get("/mesai/ayar", headers=a).json()["katsayi"]
    onceki_b = client.get("/mesai/ayar", headers=b).json()["katsayi"]
    try:
        client.patch("/mesai/ayar", headers=a, json={"katsayi": 3.0})
        assert client.get("/mesai/ayar", headers=b).json()["katsayi"] == onceki_b
    finally:
        _eski_haline(client, a, onceki_a)
