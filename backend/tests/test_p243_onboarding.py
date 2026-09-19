"""(P243 §6) ONBOARDING — asgari kurulum, engeller, ilk giris turu.

===========================================================================
ONCE OLCUM
===========================================================================
Sihirbaz 19 adimdi ve 7'si "zorunlu" isaretliydi — aralarinda KASA,
GELIR-GIDER TANIMI ve AIDAT da vardi. Yani yeni bir yonetici DUYURU
YAPABILMEK icin once muhasebe kurmak zorundaymis gibi gorunuyordu.
"""
from __future__ import annotations


def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


# ======================== §6a ASGARI CALISIR KURULUM ====================== #
def test_ASGARI_IKI_ADIM(client, world):
    """Blok + daire. Bu ikisiyle duyuru, kamera, gorev CALISIR."""
    from app.routers.kurulum import ASGARI_KODLAR

    assert ASGARI_KODLAR == {"blok", "daire"}


def test_CALISIR_OLCUTU_ASGARIYE_BAGLI(client, world, owner_conn):
    admin = _h(client, world["slug_a"], world["admin_a"])
    d = client.get("/kurulum", headers=admin).json()
    # Yeni tesiste blok/daire YOK -> calismiyor.
    assert d["calisir"] is False
    assert set(d["asgari_eksikler"]) == {"blok", "daire"}

    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO building_block (tenant_id, ad) VALUES (%s, 'A')",
            (world["a"],),
        )
        cur.execute(
            "INSERT INTO unit (tenant_id, no, blok) VALUES (%s, 'A-1', 'A')",
            (world["a"],),
        )
    d = client.get("/kurulum", headers=admin).json()
    # MUHASEBE KURULMADAN CALISIR: eski olcut yedi adimin hepsiydi ve
    # yeni yoneticiye "duyuru yapmak icin once kasa ac" diyordu.
    assert d["calisir"] is True, d["asgari_eksikler"]
    assert d["asgari_eksikler"] == []
    # AMA EKSIKLER KAYBOLMADI — yalnizca sunumu degisti.
    assert "aidat" in d["eksik_zorunlular"]


# ====================== §6b SONRAYA BIRAKILANLAR ========================== #
def test_ADIM_BASINA_ASGARI_BAYRAGI(client, world):
    """Istemci "once sunlar" / "sonra sunlari da" ayrimini ADIM UZERINDEN
    kurar; `asgari_eksikler` yalniz EKSIK olanlari sayar ve tamamlanmis
    bir asgari adimi gruplayamaz."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    adimlar = {a["kod"]: a for a in client.get("/kurulum", headers=admin).json()["adimlar"]}
    assert adimlar["blok"]["asgari"] is True
    assert adimlar["daire"]["asgari"] is True
    # ZORUNLU ama ASGARI DEGIL: aradaki fark tam da bu turun konusu.
    assert adimlar["aidat"]["zorunlu"] is True
    assert adimlar["aidat"]["asgari"] is False


def test_ATLAMA_ASGARIYI_KAPATMAZ(client, world):
    """Blok adimini atlamak tesisi CALISIR yapmaz: atlama gostergeyi
    rahatlatir, gercegi degistirmez (P193 §2 karari asgariye de gecer)."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    r = client.patch("/kurulum", headers=admin, json={"kod": "blok"})
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["calisir"] is False
    assert "blok" in d["asgari_eksikler"]


# =========================== §6d ILK GIRIS TURU =========================== #
def test_TUR_BIR_KEZ_ve_KULLANICI_BASINA(client, world):
    admin = _h(client, world["slug_a"], world["admin_a"])
    yonetici = _h(client, world["slug_a"], world["yonetici_a"])

    assert client.get("/me", headers=admin).json()["tur_goruldu_at"] is None
    r = client.post("/me/tur-goruldu", headers=admin)
    assert r.status_code == 200
    ilk = r.json()["tur_goruldu_at"]
    assert ilk is not None

    # IDEMPOTENT: "atla" ile "sonuna kadar izle" ayni sonucu yazar ve
    # ikinci cagri DAMGAYI DEGISTIRMEZ.
    r2 = client.post("/me/tur-goruldu", headers=admin)
    assert r2.json()["tur_goruldu_at"] == ilk

    # KULLANICI BASINA: ayni tesisin ikinci yoneticisi turu HENUZ
    # gormedi — tesis basina tutulsaydi ona hic gosterilmezdi.
    assert client.get("/me", headers=yonetici).json()["tur_goruldu_at"] is None


def test_TUR_OTURUMLAR_ARASI_KALIR(client, world):
    """`localStorage` olsaydi ofiste atlayan yonetici evde yeniden
    gorurdu."""
    admin = _h(client, world["slug_a"], world["admin_a"])
    client.post("/me/tur-goruldu", headers=admin)
    yeni_oturum = _h(client, world["slug_a"], world["admin_a"])
    assert client.get("/me", headers=yeni_oturum).json()["tur_goruldu_at"]


def test_HER_ROL_KENDI_TURUNU_ISARETLER(client, world):
    for rol in ("guard_a", "resident_a", "gorevli_a"):
        h = _h(client, world["slug_a"], world[rol])
        assert client.post("/me/tur-goruldu", headers=h).status_code == 200
