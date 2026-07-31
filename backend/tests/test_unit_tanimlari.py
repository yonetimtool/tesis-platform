"""Bagimsiz Bolum TIPLERI + GRUPLARI (P26).

Kilitlenen kararlar:
  * tip ve grup AYRI kavramlardir (tip = buyukluk + varsayilan aidat,
    grup = ne oldugu),
  * tip adi SERBEST metindir (sabit enum yok),
  * varsayilan aidat NULL "tanimsiz"dir, 0 DEGIL (0 = muaf daire),
  * tanim silinince DAIRE SILINMEZ, yalniz siniflandirmasi bosalir,
  * baska tenant'in tanimina baglanilamaz,
  * toplu olusturmada siniflandirma PARTININ TAMAMINA uygulanir.
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


@pytest.fixture
def yon(client, world):
    return _headers(client, world["slug_a"], world["yonetici_a"])


def _tip(client, h, ad=None, **over):
    # `ad or ...` DEGIL: bos metin de gecerli bir SINAMA girdisidir ve `or`
    # onu sessizce rastgele bir adla degistirirdi (ilk surumun kusuru).
    govde = {"ad": f"T-{uuid.uuid4().hex[:6]}" if ad is None else ad}
    govde.update(over)
    return client.post("/unit-tipleri", headers=h, json=govde)


def _grup(client, h, ad=None, **over):
    govde = {"ad": f"G-{uuid.uuid4().hex[:6]}" if ad is None else ad}
    govde.update(over)
    return client.post("/unit-gruplari", headers=h, json=govde)


def _daire(client, h, blok="A", **over):
    govde = {"no": f"{blok}-{uuid.uuid4().hex[:6]}", "blok": blok}
    govde.update(over)
    return client.post("/units", headers=h, json=govde)


# ------------------------------- CRUD --------------------------------------- #
def test_tip_adi_SERBEST_METIN(client, yon):
    """Sabit bir enum "1+1,5" ya da "stüdyo" diyen siteyi disarida birakirdi."""
    for ad in ["1+0", "2+1", "dubleks", "1+1,5", "Stüdyo", "Çatı Katı Dükkan"]:
        r = _tip(client, yon, f"{ad}-{uuid.uuid4().hex[:4]}")
        assert r.status_code == 201, (ad, r.text)


def test_tip_ve_grup_AYRI_kavramlar(client, yon):
    """Ayni ad iki listede de kullanilabilir — cakismazlar."""
    ad = f"Villa-{uuid.uuid4().hex[:6]}"
    assert _tip(client, yon, ad).status_code == 201
    assert _grup(client, yon, ad).status_code == 201


def test_ayni_ad_AYNI_listede_cakisir_409(client, yon):
    ad = f"Tekrar-{uuid.uuid4().hex[:6]}"
    assert _tip(client, yon, ad).status_code == 201
    assert _tip(client, yon, ad).status_code == 409


def test_varsayilan_aidat_NULL_ile_SIFIR_ayri(client, yon):
    """0 gecerli bir tutardir (muaf daire); NULL "tanimsiz"dir. Ikisini
    karistirmak P28'de sessiz sifir aidat uretirdi."""
    tanimsiz = _tip(client, yon).json()
    assert tanimsiz["varsayilan_aidat_kurus"] is None

    muaf = _tip(client, yon, varsayilan_aidat_kurus=0).json()
    assert muaf["varsayilan_aidat_kurus"] == 0

    # Tutar SONRADAN girilebilir (yaygin akis: once tip, sonra tutar).
    r = client.patch(f"/unit-tipleri/{tanimsiz['id']}", headers=yon,
                     json={"varsayilan_aidat_kurus": 125000})
    assert r.status_code == 200 and r.json()["varsayilan_aidat_kurus"] == 125000
    # ...ve acikca null gonderilerek KALDIRILABILIR.
    r2 = client.patch(f"/unit-tipleri/{tanimsiz['id']}", headers=yon,
                      json={"varsayilan_aidat_kurus": None})
    assert r2.status_code == 200 and r2.json()["varsayilan_aidat_kurus"] is None


def test_negatif_aidat_RET(client, yon):
    assert _tip(client, yon, varsayilan_aidat_kurus=-1).status_code == 422


def test_bos_ad_RET(client, yon):
    assert _tip(client, yon, ad="").status_code == 422
    assert _grup(client, yon, ad="   ").status_code in (409, 422)


# --------------------------- daireye baglama -------------------------------- #
def test_daireye_tip_ve_grup_baglanir_ADLARIYLA_doner(client, yon):
    tip = _tip(client, yon, f"3+1-{uuid.uuid4().hex[:4]}").json()
    grup = _grup(client, yon, f"Daire-{uuid.uuid4().hex[:4]}").json()
    r = _daire(client, yon, unit_tip_id=tip["id"], unit_grup_id=grup["id"])
    assert r.status_code == 201, r.text
    govde = r.json()
    # AD da doner: istemci ayri istek yapmadan listeyi cizebilsin.
    assert govde["unit_tip_ad"] == tip["ad"]
    assert govde["unit_grup_ad"] == grup["ad"]

    # Listede de adlar dolu (N+1 yok ama sonuc ayni olmali).
    liste = client.get("/units", headers=yon,
                       params={"unit_tip_id": tip["id"]}).json()["items"]
    assert [u["id"] for u in liste] == [govde["id"]]
    assert liste[0]["unit_tip_ad"] == tip["ad"]


def test_OLMAYAN_tanim_422_invalid_reference(client, yon):
    r = _daire(client, yon, unit_tip_id=str(uuid.uuid4()))
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "invalid_reference"


def test_siniflandirma_KALDIRILABILIR(client, yon):
    tip = _tip(client, yon).json()
    d = _daire(client, yon, unit_tip_id=tip["id"]).json()
    r = client.patch(f"/units/{d['id']}", headers=yon,
                     json={"unit_tip_id": None})
    assert r.status_code == 200
    assert r.json()["unit_tip_id"] is None and r.json()["unit_tip_ad"] is None


def test_gonderilmeyen_alan_DOKUNULMAZ(client, yon):
    """`exclude_unset`: "gonderilmedi" ile "null gonderildi" AYRI."""
    tip = _tip(client, yon).json()
    d = _daire(client, yon, unit_tip_id=tip["id"]).json()
    r = client.patch(f"/units/{d['id']}", headers=yon, json={"aktif": False})
    assert r.status_code == 200
    assert r.json()["unit_tip_id"] == tip["id"], "dokunulmamis alan silinmis"


def test_toplu_olusturmada_PARTININ_TAMAMINA_uygulanir(client, yon):
    tip = _tip(client, yon).json()
    grup = _grup(client, yon).json()
    blok = f"Z{uuid.uuid4().hex[:3].upper()}"
    r = client.post("/units/bulk", headers=yon, json={
        "blok": blok, "kat_sayisi": 2, "kat_basi_daire": 3,
        "baslangic_no": 1, "unit_tip_id": tip["id"], "unit_grup_id": grup["id"],
    })
    assert r.status_code == 201, r.text
    olusan = r.json()["olusturulan"]
    assert len(olusan) == 6
    assert all(u["unit_tip_id"] == tip["id"] for u in olusan)
    assert all(u["unit_grup_ad"] == grup["ad"] for u in olusan)


def test_toplu_olusturmada_OLMAYAN_tanim_422(client, yon):
    r = client.post("/units/bulk", headers=yon, json={
        "blok": f"Y{uuid.uuid4().hex[:3].upper()}", "kat_sayisi": 1,
        "kat_basi_daire": 1, "baslangic_no": 1,
        "unit_grup_id": str(uuid.uuid4()),
    })
    assert r.status_code == 422


# ------------------------------ silme --------------------------------------- #
def test_silme_DAIREYI_SILMEZ_siniflandirmayi_bosaltir(client, yon):
    """Tanim listesi temizlemek yaygin bir bakimdir; "once 400 daireyi
    degistir" demek kullaniciyi tanimi pasife alip listede birakmaya iterdi."""
    tip = _tip(client, yon).json()
    d = _daire(client, yon, unit_tip_id=tip["id"]).json()

    r = client.delete(f"/unit-tipleri/{tip['id']}", headers=yon)
    assert r.status_code == 200
    # Islem SESSIZ DEGIL: kac daireyi etkiledigi doner.
    assert r.json()["etkilenen_daire"] == 1

    kalan = client.get(f"/units/{d['id']}", headers=yon)
    assert kalan.status_code == 200, "daire silinmis!"
    assert kalan.json()["unit_tip_id"] is None


def test_daire_sayisi_listede_doner(client, yon):
    tip = _tip(client, yon).json()
    for _ in range(3):
        _daire(client, yon, unit_tip_id=tip["id"])
    liste = client.get("/unit-tipleri", headers=yon,
                       params={"limit": 200}).json()["items"]
    kayit = next(t for t in liste if t["id"] == tip["id"])
    assert kayit["daire_sayisi"] == 3


# ------------------------------- RBAC + izolasyon --------------------------- #
def test_rbac(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    tip = _tip(client, yonetici).json()
    for rol, yazabilir, okuyabilir in [
        ("admin_a", True, True),
        ("yonetici_a", True, True),
        ("guard_a", False, True),
        ("gorevli_a", False, True),
        ("resident_a", False, False),
    ]:
        h = _headers(client, world["slug_a"], world[rol])
        okuma = client.get("/unit-tipleri", headers=h)
        assert (okuma.status_code == 200) is okuyabilir, (rol, okuma.status_code)
        yazma = client.patch(f"/unit-tipleri/{tip['id']}", headers=h,
                             json={"aktif": True})
        assert (yazma.status_code == 200) is yazabilir, (rol, yazma.status_code)


def test_tenant_izolasyonu(client, world):
    a = _headers(client, world["slug_a"], world["admin_a"])
    b = _headers(client, world["slug_b"], world["admin_b"])
    tip = _tip(client, a).json()

    # B, A'nin tipini GORMEZ.
    b_liste = client.get("/unit-tipleri", headers=b,
                         params={"limit": 200}).json()["items"]
    assert tip["id"] not in [t["id"] for t in b_liste]
    # ...ve ona daire BAGLAYAMAZ (bilesik FK'dan once 422 ile durur).
    r = client.post("/units", headers=b, json={
        "no": f"B-{uuid.uuid4().hex[:6]}", "blok": "A",
        "unit_tip_id": tip["id"],
    })
    assert r.status_code == 422
