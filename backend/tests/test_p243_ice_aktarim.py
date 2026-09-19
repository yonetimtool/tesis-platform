"""(P243 §3) ICE AKTARIM — UC TUR, birlesik satirlar.

ONCE OLCUM: dort tur vardi (`daire`, `kisi`, `acilis_bakiye`, `arac`).
Yonetici ayni insan icin IKI dosya hazirliyordu (kisiler + plakalar) ve
ikincisinde daireyi TEKRAR yaziyordu. Ayni sekilde daire ve sakin ayri
dosyalardaydi.
"""
from __future__ import annotations

import uuid


def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _aktar(client, h, tur: str, satirlar: list[dict], dogrula=True):
    r = client.post(
        f"/ice-aktarim/{tur}",
        headers=h,
        json={
            "satirlar": [
                {"satir_no": i + 2, "degerler": d} for i, d in enumerate(satirlar)
            ],
            "yalniz_dogrula": dogrula,
        },
    )
    assert r.status_code == 201, r.text
    return r.json()


def test_UC_TUR_VAR_arac_YOK(client, world):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    kodlar = {t["kod"] for t in client.get("/ice-aktarim/turler", headers=h).json()}
    assert kodlar == {"daire", "kisi", "acilis_bakiye"}


def test_KISI_SATIRI_ARACI_DA_YARATIR(client, world):
    """`arac` turu `kisi`ye katlandi — tek satir, tek dosya."""
    h = _h(client, world["slug_a"], world["yonetici_a"])
    ek = uuid.uuid4().hex[:6]
    plaka = f"34AB{ek[:3].upper()}"
    _aktar(client, h, "kisi", [{
        "ad": "Ali Veli", "eposta": f"ali-{ek}@ornek.com", "plaka": plaka,
        "arac_marka": "Fiat", "arac_model": "Egea",
    }], dogrula=False)
    # ARAC KAYDININ KENDI LISTE UCU YOK (ANPR tarafinda yasiyor);
    # ARAMA ucu plakayi indeksliyor ve sorguya EN YAKIN yuzey o.
    r = client.get("/arama", headers=h, params={"q": plaka})
    assert r.status_code == 200, r.text
    assert plaka in r.text, r.text[:300]


def test_PLAKA_BOS_OLABILIR_aracsiz_kisi_OLAGAN(client, world):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    ek = uuid.uuid4().hex[:6]
    sonuc = _aktar(client, h, "kisi", [
        {"ad": "Veli", "eposta": f"veli-{ek}@ornek.com"},
    ], dogrula=True)
    assert sonuc["hatali"] == 0, sonuc["hatalar"]
    assert sonuc["olusan"] == 1


def test_DAIRE_SATIRI_SAKINI_DA_YARATIR(client, world):
    """"Daireler ve sakinler" — tek dosya."""
    h = _h(client, world["slug_a"], world["yonetici_a"])
    ek = uuid.uuid4().hex[:5]
    daire = f"Z-{ek}"
    eposta = f"sakin-{ek}@ornek.com"
    sonuc = _aktar(client, h, "daire", [{
        "blok": "Z", "daire_no": daire,
        "sakin_ad": "Ayşe Yılmaz", "sakin_eposta": eposta,
        "rol_tipi": "malik",
    }], dogrula=False)
    print("SONUC:", sonuc)

    daireler = client.get("/units", headers=h, params={"limit": 200}).json()["items"]
    hedef = next((u for u in daireler if u["no"] == daire), None)
    assert hedef is not None, "daire yaratilmali"

    kisiler = client.get("/users", headers=h, params={"limit": 300}).json()["items"]
    assert any(k["email"] == eposta for k in kisiler), "sakin de yaratilmali"


def test_BOS_SAKIN_SUTUNU_HATA_DEGIL(client, world):
    """Bos daire de bir gercektir; o satir yalniz daireyi yaratir."""
    h = _h(client, world["slug_a"], world["yonetici_a"])
    ek = uuid.uuid4().hex[:5]
    sonuc = _aktar(client, h, "daire", [
        {"blok": "Y", "daire_no": f"Y-{ek}"},
    ], dogrula=True)
    assert sonuc["hatali"] == 0, sonuc["hatalar"]


def test_YARIM_SAKIN_SATIRI_SESSIZ_GECMEZ(client, world):
    """Ad var e-posta yok: sessizce yarim kisi yaratmak, sahiplenilemeyen
    bir hesap birakirdi (P193 kurali — sessiz atlama YOK)."""
    h = _h(client, world["slug_a"], world["yonetici_a"])
    ek = uuid.uuid4().hex[:5]
    sonuc = _aktar(client, h, "daire", [
        {"blok": "X", "daire_no": f"X-{ek}", "sakin_ad": "Adsiz Eposta"},
    ], dogrula=True)
    assert sonuc["hatali"] == 1, sonuc
    assert sonuc["hatalar"][0]["alan"] == "sakin_eposta"
    assert sonuc["hatalar"][0]["satir_no"] == 2


def test_ONIZLEME_HICBIR_SEY_YAZMAZ(client, world):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    ek = uuid.uuid4().hex[:5]
    daire = f"W-{ek}"
    _aktar(client, h, "daire", [{
        "blok": "W", "daire_no": daire,
        "sakin_ad": "Onizleme Kisi", "sakin_eposta": f"onz-{ek}@ornek.com",
    }], dogrula=True)
    daireler = client.get("/units", headers=h, params={"limit": 200}).json()["items"]
    assert all(u["no"] != daire for u in daireler), "onizleme YAZMAMALI"
