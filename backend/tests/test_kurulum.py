"""(P154 / Asama 7.3) KURULUM SIHIRBAZI.

Olculen dort sey:
  1. TAMAMLANMA SAYILIR, SAKLANMAZ — veri gidince adim geri acilir,
  2. ATLAMA saklanir ve GERI ALINABILIR,
  3. Ilerleme atlanani da sayar (yoksa gosterge kalici bir sitem olur),
  4. Kurulum YONETIM isidir — denetci ve saha giremez.
"""
from __future__ import annotations

import uuid


def _giris(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _durum(client, basliklar):
    r = client.get("/kurulum", headers=basliklar)
    assert r.status_code == 200, r.text
    return {a["kod"]: a for a in r.json()["adimlar"]}, r.json()


# ============ 1) TAMAMLANMA VERIDEN SAYILIR — bayrak YOK ================== #

def test_ADIM_verisi_SILININCE_geri_acilir(client, world, owner_conn):
    """Bayrak tutulsaydi, yonetici tek blogunu silince adim "tamam"
    demeye devam ederdi."""
    yon = _giris(client, world["slug_a"], world["yonetici_a"])
    isaret = f"K{uuid.uuid4().hex[:8]}"

    with owner_conn.cursor() as cur:
        cur.execute("SELECT id FROM tenant WHERE slug = %s", (world["slug_a"],))
        tid = cur.fetchone()[0]
        cur.execute("DELETE FROM building_block WHERE tenant_id = %s", (tid,))
    adimlar, _ = _durum(client, yon)
    assert adimlar["blok"]["tamam"] is False, "veri yokken adim tamam gorunuyor"

    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO building_block (tenant_id, ad) VALUES (%s,%s)", (tid, isaret)
        )
    adimlar, _ = _durum(client, yon)
    assert adimlar["blok"]["tamam"] is True
    assert adimlar["blok"]["sayi"] == 1

    with owner_conn.cursor() as cur:
        cur.execute("DELETE FROM building_block WHERE tenant_id = %s", (tid,))
    adimlar, _ = _durum(client, yon)
    assert adimlar["blok"]["tamam"] is False, "veri silindi ama adim tamam kaldi"


def test_SEKIZ_adim_ve_kodlari_SABIT(client, world):
    """Kod kumesi istemcinin etiket sozlugunun anahtaridir; sessizce
    degisirse sihirbaz cevrilmemis satir cizer."""
    yon = _giris(client, world["slug_a"], world["yonetici_a"])
    _, govde = _durum(client, yon)
    assert govde["toplam"] == 8
    assert [a["kod"] for a in govde["adimlar"]] == [
        "blok", "daire", "daire_tipi", "sakin",
        "personel", "gorev_alani", "nfc_noktasi", "aidat",
    ]


# ==================== 2) ATLAMA saklanir ve GERI ALINIR ==================== #

def test_ATLAMA_saklanir_ve_GERI_ALINIR(client, world):
    yon = _giris(client, world["slug_a"], world["yonetici_a"])

    r = client.patch("/kurulum", headers=yon, json={"kod": "nfc_noktasi", "atla": True})
    assert r.status_code == 200, r.text
    adimlar = {a["kod"]: a for a in r.json()["adimlar"]}
    assert adimlar["nfc_noktasi"]["atlandi"] is True

    # AYRI BIR ISTEKTE de duruyor mu (gercekten saklandi mi).
    adimlar, _ = _durum(client, yon)
    assert adimlar["nfc_noktasi"]["atlandi"] is True

    # TEK YONLU DEGIL: sonradan NFC kuran tesis adimi geri getirebilmeli.
    r = client.patch("/kurulum", headers=yon, json={"kod": "nfc_noktasi", "atla": False})
    assert r.status_code == 200, r.text
    adimlar, _ = _durum(client, yon)
    assert adimlar["nfc_noktasi"]["atlandi"] is False


def test_ATLAMA_TESISE_ait_kullaniciya_DEGIL(client, world):
    """Bir tesiste iki yonetici olabilir (Asama 1); biri "NFC yok"
    dediyse oteki de bunu gormeli. Tarayici depolamasi yanlis yer
    olurdu."""
    a = _giris(client, world["slug_a"], world["yonetici_a"])
    client.patch("/kurulum", headers=a, json={"kod": "personel", "atla": True})

    admin = _giris(client, world["slug_a"], world["admin_a"])
    adimlar, _ = _durum(client, admin)
    assert adimlar["personel"]["atlandi"] is True, "atlama kullaniciya baglanmis"


def test_BILINMEYEN_adim_422(client, world):
    yon = _giris(client, world["slug_a"], world["yonetici_a"])
    r = client.patch("/kurulum", headers=yon, json={"kod": "boyle-adim-yok"})
    assert r.status_code == 422, r.text


def test_BASKA_TESISIN_atlamasi_GORUNMEZ(client, world):
    a = _giris(client, world["slug_a"], world["yonetici_a"])
    client.patch("/kurulum", headers=a, json={"kod": "gorev_alani", "atla": True})
    b = _giris(client, world["slug_b"], world["yonetici_b"])
    adimlar, _ = _durum(client, b)
    assert adimlar["gorev_alani"]["atlandi"] is False


# ======================= 3) ILERLEME atlanani SAYAR ======================== #

def test_ATLANAN_adim_ILERLEMEYE_sayilir(client, world, owner_conn):
    """Saymasaydik, bilincli atlayan bir tesis %100'e ASLA ulasamaz ve
    gosterge kalici bir sitem hâline gelirdi."""
    yon = _giris(client, world["slug_a"], world["yonetici_a"])
    with owner_conn.cursor() as cur:
        cur.execute("SELECT id FROM tenant WHERE slug = %s", (world["slug_a"],))
        tid = cur.fetchone()[0]
        cur.execute("DELETE FROM checkpoint WHERE tenant_id = %s", (tid,))
    client.patch("/kurulum", headers=yon, json={"kod": "nfc_noktasi", "atla": False})

    _, once = _durum(client, yon)
    client.patch("/kurulum", headers=yon, json={"kod": "nfc_noktasi", "atla": True})
    _, sonra = _durum(client, yon)
    assert sonra["gecilen"] == once["gecilen"] + 1


# =========================== 4) KURULUM YONETIM ISI ======================== #

def test_DENETCI_ve_SAHA_giremez(client, world):
    """Denetci SALT-OKUR bir roldur ve kurulum onun isi degildir."""
    for anahtar in ("denetci_a", "guard_a", "resident_a"):
        cred = world.get(anahtar)
        if cred is None:
            continue
        h = _giris(client, world["slug_a"], cred)
        assert client.get("/kurulum", headers=h).status_code == 403, anahtar
        assert client.patch(
            "/kurulum", headers=h, json={"kod": "blok", "atla": True}
        ).status_code == 403, anahtar


def test_OTURUMSUZ_erisilemez(client):
    assert client.get("/kurulum").status_code == 401
