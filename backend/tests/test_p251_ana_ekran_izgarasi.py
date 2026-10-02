"""(P251 §11) MOBIL ANA EKRAN IZGARASI — hesapta, sirali, ayri anahtar.

Olculen:
  * secim SIRASIYLA kaydedilir ve yinelenen ad tek karo olur,
  * `secili: null` varsayilana doner,
  * web yerlesim kaydi (`PUT /me/pano-tercihi`) mobil izgarayi SILMEZ,
  * mobil izgara yazimi web duzenini ve Hizli Islemler secimini SILMEZ,
  * gecersiz ad / 8'den fazla karo 422,
  * kayit KISIYE ozel (baska kullanici kendi bos kaydini gorur).
"""
from __future__ import annotations

UC = "/me/ana-ekran-izgarasi"


def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_sirali_kayit_ve_varsayilana_donus(client, world):
    y = _h(client, world["slug_a"], world["yonetici_a"])
    r = client.put(UC, headers=y, json={"secili": ["otopark", "announcements", "otopark", "tasks"]})
    assert r.status_code == 200, r.text
    assert r.json()["secili"] == ["otopark", "announcements", "tasks"]
    assert client.get(UC, headers=y).json()["secili"] == ["otopark", "announcements", "tasks"]

    # Surukle-birak: ayni kume, yeni sira.
    r = client.put(UC, headers=y, json={"secili": ["tasks", "otopark", "announcements"]})
    assert client.get(UC, headers=y).json()["secili"] == ["tasks", "otopark", "announcements"]

    r = client.put(UC, headers=y, json={"secili": None})
    assert r.status_code == 200 and r.json()["secili"] is None
    assert client.get(UC, headers=y).json()["secili"] is None


def test_web_ve_mobil_kayitlari_birbirini_ezmez(client, world):
    y = _h(client, world["slug_a"], world["yonetici_a"])
    client.put("/me/hizli-islemler", headers=y, json={"secili": ["talep", "aidat"]})
    client.put(UC, headers=y, json={"secili": ["complaints", "otopark"]})

    # Web Ozet duzeni kaydedilir (mobil anahtari TASIMAZ).
    r = client.put("/me/pano-tercihi", headers=y, json={"bolumler": []})
    assert r.status_code == 200, r.text
    assert r.json()["ana_ekran_izgarasi"] == ["complaints", "otopark"]
    assert client.get(UC, headers=y).json()["secili"] == ["complaints", "otopark"]

    # Mobil izgara yazilir: web duzeni ve Hizli Islemler yerinde kalir.
    client.put(UC, headers=y, json={"secili": ["otopark"]})
    pano = client.get("/me/pano-tercihi", headers=y).json()
    assert pano["bolumler"] == []
    assert pano["hizli_islemler"] == ["talep", "aidat"]

    client.put(UC, headers=y, json={"secili": None})
    client.put("/me/hizli-islemler", headers=y, json={"secili": None})
    client.put("/me/pano-tercihi", headers=y, json={})


def test_gecersiz_govde_422(client, world):
    y = _h(client, world["slug_a"], world["yonetici_a"])
    for govde in (
        {"secili": ["<script>"]},
        {"secili": ["a b"]},
        {"secili": [""]},
        {"secili": ["kart:"]},
        {"secili": ["baska:x"]},
        {"secili": [f"k{i}" for i in range(9)]},
    ):
        assert client.put(UC, headers=y, json=govde).status_code == 422, govde


def test_kayit_kisiye_ozel(client, world):
    y = _h(client, world["slug_a"], world["yonetici_a"])
    s = _h(client, world["slug_a"], world["resident_a"])
    client.put(UC, headers=s, json={"secili": None})
    client.put(UC, headers=y, json={"secili": ["otopark"]})
    assert client.get(UC, headers=s).json()["secili"] is None
    # Sakin de kendi izgarasini kaydedebilir (tum roller).
    # Menusuz varsayilan kart `kart:` onekiyle saklanir.
    r = client.put(UC, headers=s, json={"secili": ["kart:sikayetlerim", "aidatim"]})
    assert r.status_code == 200 and r.json()["secili"] == ["kart:sikayetlerim", "aidatim"]
    client.put(UC, headers=s, json={"secili": None})
    client.put(UC, headers=y, json={"secili": None})
