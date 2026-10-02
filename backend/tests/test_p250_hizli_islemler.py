"""(P250 §6) HIZLI ISLEMLER — role gore secenek, hesapta secim, varsayilana don.

Secim `pano_tercihi.hizli_islemler`te (P182 altyapisi). Olculen:
  * secenekler ROLE gore (yetkisiz islem listede YOK, yazilamaz),
  * secim sirali kaydedilir ve web/mobil AYNI uctan okur,
  * yerlesim kaydi (`PUT /me/pano-tercihi`) secimi SILMEZ,
  * varsayilana don.
"""
from __future__ import annotations

from app.hizli_islem import KATALOG, VARSAYILAN


def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _sifirla(client, h):
    client.put("/me/hizli-islemler", headers=h, json={"secili": None})


def test_varsayilan_ve_secenekler_role_gore(client, world):
    yon = _h(client, world["slug_a"], world["yonetici_a"])
    _sifirla(client, yon)
    d = client.get("/me/hizli-islemler", headers=yon).json()
    assert d["secili"] == list(VARSAYILAN) and d["ozel"] is False
    assert d["secenekler"] == list(KATALOG)  # yonetici hepsini gorur

    gv = _h(client, world["slug_a"], world["guard_a"])
    g = client.get("/me/hizli-islemler", headers=gv).json()
    assert g["secenekler"] == ["ziyaretci"]
    # Varsayilandaki islemler guvenlige YETKISIZ -> dusurulur.
    assert g["secili"] == []

    dn = _h(client, world["slug_a"], world["denetci_a"])
    assert client.get("/me/hizli-islemler", headers=dn).json()["secenekler"] == ["rapor"]


def test_secim_sirali_kaydedilir_ve_varsayilana_doner(client, world):
    yon = _h(client, world["slug_a"], world["yonetici_a"])
    r = client.put("/me/hizli-islemler", headers=yon,
                   json={"secili": ["kurulum", "borclular", "kurulum", "talep"]})
    assert r.status_code == 200, r.text
    assert r.json()["secili"] == ["kurulum", "borclular", "talep"]
    assert r.json()["ozel"] is True
    assert client.get("/me/hizli-islemler", headers=yon).json()["secili"] == [
        "kurulum", "borclular", "talep",
    ]
    r = client.put("/me/hizli-islemler", headers=yon, json={"secili": None})
    assert r.json()["secili"] == list(VARSAYILAN) and r.json()["ozel"] is False


def test_yetkisiz_islem_YAZILAMAZ(client, world):
    gv = _h(client, world["slug_a"], world["guard_a"])
    r = client.put("/me/hizli-islemler", headers=gv, json={"secili": ["borclular"]})
    assert r.status_code == 422, r.text
    r = client.put("/me/hizli-islemler", headers=gv, json={"secili": ["boyle_yok"]})
    assert r.status_code == 422, r.text


def test_yerlesim_kaydi_secimi_SILMEZ(client, world):
    yon = _h(client, world["slug_a"], world["yonetici_a"])
    client.put("/me/hizli-islemler", headers=yon, json={"secili": ["gider", "anket"]})
    # Web'in yerlesim kaydi hizli_islemler TASIMAZ.
    r = client.put("/me/pano-tercihi", headers=yon, json={
        "widgetlar": [{"rota": "/dues"}], "bolumler": [{"id": "kpi"}],
    })
    assert r.status_code == 200, r.text
    assert client.get("/me/hizli-islemler", headers=yon).json()["secili"] == ["gider", "anket"]
    _sifirla(client, yon)


def test_ustsinir_8(client, world):
    yon = _h(client, world["slug_a"], world["yonetici_a"])
    r = client.put("/me/hizli-islemler", headers=yon, json={"secili": list(KATALOG)[:9]})
    assert r.status_code == 422, r.text
