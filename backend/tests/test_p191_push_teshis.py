"""(P191 §2) PUSH ZINCIRININ TESHISI + eksik olan iki bildirim.

===========================================================================
BU DOSYA NEYI KANITLIYOR
===========================================================================
Kullanici Play'den guncel surumu kurdu, bir GOREV olusturdu, hicbir
bildirim gelmedi. Iz surulunce iki ayri sey cikti:

  1. GOREV ATAMA yolunda push cagrisi HIC YOKTU (`dispatch_external`
     kullanan 12 yolun arasinda `tasks.py` yoktu). Ayni bosluk AIDAT
     borclandirmasinda da vardi.
  2. Zincirin nerede koptugunu gosteren HICBIR YUZEY yoktu: saglayici
     noop mu, cihaz kayitli mi, tercih kapali mi, FCM ne dedi.

Olculen: (1) icin gercek uctan gorev/borc yaratilir ve `push_gonderim`
satiri ARANIR; (2) icin `/push/teshis` ve `/push/test` uclari.
"""
from __future__ import annotations

import uuid

import pytest


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _teshis(client, headers, **q):
    r = client.get("/push/teshis", headers=headers, params=q)
    assert r.status_code == 200, r.text
    return r.json()


# =========================== A. TESHIS UCU ================================== #
def test_teshis_zincirin_ALTI_HALKASINI_tek_yanitta_verir(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    d = _teshis(client, admin)
    # (f) saglayici + yapilandirma, (b) cihaz sayilari, (e) tercih,
    # (d) son 24 saatin sonuc dagilimi.
    for alan in (
        "saglayici",
        "yapilandirildi",
        "cihaz_aktif",
        "cihaz_kullanici",
        "bildirim_kapali",
        "ozet_24s",
        "denemeler",
    ):
        assert alan in d, f"{alan} eksik: {d}"
    # Dev/test sunucusu noop kosar — teshis bunu ACIKCA soylemeli, cunku
    # "noop" bildirim gelmemesinin EN SIK nedeni ve bir hata gibi gorunmez.
    assert d["saglayici"] in ("noop", "fcm")


def test_teshis_cihaz_kaydini_GORUR(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    onceki = _teshis(client, admin)["cihaz_aktif"]
    tok = f"P191-{uuid.uuid4().hex[:10]}"
    assert client.post(
        "/devices", headers=guard, json={"fcm_token": tok, "platform": "android"}
    ).status_code == 201
    assert _teshis(client, admin)["cihaz_aktif"] == onceki + 1


def test_teshis_YALNIZ_YONETIME_acik(client, world):
    sakin = _headers(client, world["slug_a"], world["resident_a"])
    assert client.get("/push/teshis", headers=sakin).status_code == 403
    assert client.post("/push/test", headers=sakin).status_code == 403


def test_teshis_KIMLIKSIZ_401(client):
    assert client.get("/push/teshis").status_code == 401


def test_TAM_JETON_hicbir_yanitta_DONMEZ(client, world):
    """Teshis bir sizinti yuzeyi olmamali: token yalniz SON 6 karakter."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    tok = f"P191GIZLI-{uuid.uuid4().hex}"
    assert client.post(
        "/devices", headers=admin, json={"fcm_token": tok, "platform": "android"}
    ).status_code == 201
    r = client.post("/push/test", headers=admin)
    assert r.status_code == 200, r.text
    d = _teshis(client, admin, limit=50)
    assert tok not in r.text
    for satir in d["denemeler"]:
        assert satir["token_son6"] is None or len(satir["token_son6"]) <= 6
    assert tok not in str(d)


# =========================== B. TEST GONDERIMI ============================== #
def test_test_gonderimi_CIHAZ_YOKKEN_hedef_yok_der(client, world):
    """Cihazi olmayan yonetici "hedef_yok" gorur — sessiz basari DEGIL.

    Bu ayrim teshisin kalbi: "push tetiklendi ama cihaz yok" ile "push hic
    tetiklenmedi" TAMAMEN farkli iki arizadir.
    """
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/push/test", headers=yonetici)
    assert r.status_code == 200, r.text
    d = r.json()
    if d["cihaz"] == 0:
        assert d["durum"] == "hedef_yok"
        # Deneme PANELDE gorunur olmali.
        son = _teshis(client, yonetici)["denemeler"]
        assert any(s["kimlik"] == "test" for s in son)


def test_test_gonderimi_CIHAZ_VARKEN_satir_yazar(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    tok = f"P191T-{uuid.uuid4().hex[:10]}"
    assert client.post(
        "/devices", headers=admin, json={"fcm_token": tok, "platform": "ios"}
    ).status_code == 201
    r = client.post("/push/test", headers=admin)
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["cihaz"] >= 1
    # Sunucu noop kosuyorsa durum 'noop' olur — ve bu DOGRU cevaptir:
    # "gonderdim" demek yanlis bir guven verirdi.
    assert d["durum"] in ("noop", "gonderildi", "basarisiz", "yapilandirilmadi")
    satirlar = _teshis(client, admin)["denemeler"]
    assert any(
        s["kimlik"] == "test" and s["token_son6"] == tok[-6:] for s in satirlar
    ), satirlar[:3]


# ===================== C. EKSIK OLAN IKI BILDIRIM =========================== #
def test_GOREV_ATAMASI_bildirim_uretir(client, world):
    """Kok kusur: gorev olusturuluyordu, atanan kisiye HICBIR SEY gitmiyordu."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    # Gorevlinin kimligi world'de yok; listeden cozulur (uc zaten admin'e acik).
    liste = client.get("/users", headers=admin, params={"limit": 200})
    assert liste.status_code == 200, liste.text
    hedef = next(
        (
            u
            for u in liste.json()["items"]
            if (u.get("email") or "").lower() == world["gorevli_a"]["email"].lower()
        ),
        None,
    )
    if hedef is None:
        pytest.skip("gorevli kullanicisi listede bulunamadi")
    gorevli_id = hedef["id"]
    r = client.post(
        "/tasks",
        headers=admin,
        json={
            "ad": f"P191 gorev {uuid.uuid4().hex[:6]}",
            "atanan_user_id": str(gorevli_id),
        },
    )
    assert r.status_code == 201, r.text
    satirlar = _teshis(client, admin, limit=100)["denemeler"]
    assert any(s["kimlik"] == "gorev_atandi" for s in satirlar), satirlar[:5]


def test_ATANMAMIS_gorev_bildirim_URETMEZ(client, world):
    """Havuz gorevi: kime gonderilecegi belli degil -> deneme de yok."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    once = [
        s for s in _teshis(client, admin, limit=200)["denemeler"]
        if s["kimlik"] == "gorev_atandi"
    ]
    r = client.post(
        "/tasks", headers=admin, json={"ad": f"P191 havuz {uuid.uuid4().hex[:6]}"}
    )
    assert r.status_code == 201, r.text
    sonra = [
        s for s in _teshis(client, admin, limit=200)["denemeler"]
        if s["kimlik"] == "gorev_atandi"
    ]
    assert len(sonra) == len(once)


def test_AIDAT_BORCU_sakine_bildirim_uretir(client, world):
    """Ikinci bosluk: borclandirma yapiliyor, sakinin telefonuna hicbir sey
    dusmuyordu. Aidat kullanicinin PARASIYLA ilgili tek olaydir."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])
    resident_id = client.get("/me", headers=resident).json()["id"]
    # Sakinin bir CIHAZI olsun ki deneme satiri "kime" bilgisini tasisin;
    # cihazsizken satir yine yazilir ama `hedef_yok` olur (bu da bir sonuctur).
    assert client.post(
        "/devices",
        headers=resident,
        json={"fcm_token": f"P191A-{uuid.uuid4().hex[:10]}", "platform": "android"},
    ).status_code == 201

    u = client.post(
        "/units", headers=admin, json={"no": f"P191-{uuid.uuid4().hex[:6]}", "blok": "A"}
    )
    assert u.status_code == 201, u.text
    unit = u.json()
    assert client.post(
        f"/units/{unit['id']}/residents",
        headers=admin,
        json={"user_id": resident_id, "rol_tipi": "malik"},
    ).status_code == 201

    r = client.post(
        "/dues/assessments",
        headers=admin,
        json={"unit_id": unit["id"], "donem": "2031-04", "tutar_kurus": 123400},
    )
    assert r.status_code == 201, r.text
    satirlar = _teshis(client, admin, limit=100)["denemeler"]
    aidat = [s for s in satirlar if s["kimlik"] == "aidat_borc"]
    assert aidat, satirlar[:5]
    # Bildirim SAKINE gider, borcu YAZAN yoneticiye degil.
    assert any(s["user_id"] == resident_id for s in aidat), aidat[:3]


def test_HEDEFSIZ_daire_borcu_bildirim_URETMEZ(client, world):
    """Daireye bagli sakin yoksa gonderilecek kisi de yoktur — sessiz kayip
    degil: borc kaydi yazildi ve daire ekraninda gorunuyor."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    once = len([
        s for s in _teshis(client, admin, limit=200)["denemeler"]
        if s["kimlik"] == "aidat_borc"
    ])
    u = client.post(
        "/units", headers=admin, json={"no": f"P191B-{uuid.uuid4().hex[:6]}", "blok": "A"}
    ).json()
    r = client.post(
        "/dues/assessments",
        headers=admin,
        json={"unit_id": u["id"], "donem": "2031-05", "tutar_kurus": 5000},
    )
    assert r.status_code == 201, r.text
    sonra = len([
        s for s in _teshis(client, admin, limit=200)["denemeler"]
        if s["kimlik"] == "aidat_borc"
    ])
    assert sonra == once
