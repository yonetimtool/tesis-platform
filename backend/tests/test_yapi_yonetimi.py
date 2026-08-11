"""(P154 / Asama 5) KULLANICI VE YAPI YONETIMI.

Olculen alti sey:
  1. BASLANGIC KATI: bodrum/zemin gercek kat numarasi olarak yazilir,
  2. TOPLU NITELIK: secili dairelere tek istekte uygulanir,
  3. SIRALAMA tek istekte (yarim uygulanmis duzen olmaz),
  4. KAT SILME kaza korumali,
  5. BLOK TOPLU SILME satir satir raporlar — sessizce atlamaz,
  6. KULLANICI SILME ayni yetki kapisindan gecer, kendini silemez.
"""
from __future__ import annotations

import uuid

import pytest


def _giris(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def yon(client, world):
    return _giris(client, world["slug_a"], world["yonetici_a"])


def _blok():
    return f"B{uuid.uuid4().hex[:3].upper()}"


# ======================= 1) BASLANGIC KATI ================================= #

def test_BODRUM_ve_ZEMIN_gercek_kat_numarasi(client, yon):
    """Eskiden katlar HER ZAMAN 1'den basliyordu; bodrumlu bir binada kat
    numaralari bir kaydirmayla yaziliyordu — veri binanin kendisini
    anlatmiyordu."""
    blok = _blok()
    r = client.post("/units/bulk", headers=yon, json={
        "blok": blok, "kat_sayisi": 4, "kat_basi_daire": 1,
        "baslangic_no": 1, "baslangic_kat": -2,
    })
    assert r.status_code == 201, r.text

    liste = client.get(
        f"/units?limit=200&blok={blok}", headers=yon
    ).json()["items"]
    assert sorted(u["kat"] for u in liste) == [-2, -1, 0, 1]


def test_BASLANGIC_KATI_verilmezse_ESKI_DAVRANIS_surer(client, yon):
    """Varsayilan 1 — DEGISMEDI.

    Brief "baslangic kati SECILEBILSIN" diyor, "varsayilan degissin"
    demiyor. 0 yapmak, alani hic gondermeyen her cagirani (mobil toplu
    olusturma dahil) sessizce etkilerdi. Ilk denememde 0 yaptim ve
    `test_units_bulk` kaymayi yakaladi.
    """
    blok = _blok()
    client.post("/units/bulk", headers=yon, json={
        "blok": blok, "kat_sayisi": 2, "kat_basi_daire": 1, "baslangic_no": 1,
    })
    liste = client.get(f"/units?limit=200&blok={blok}", headers=yon).json()["items"]
    assert sorted(u["kat"] for u in liste) == [1, 2]


# ======================== 2) TOPLU NITELIK ================================= #

def test_TOPLU_nitelik_secilenlere_uygulanir(client, yon):
    blok = _blok()
    client.post("/units/bulk", headers=yon, json={
        "blok": blok, "kat_sayisi": 1, "kat_basi_daire": 3, "baslangic_no": 1})
    liste = client.get(f"/units?limit=200&blok={blok}", headers=yon).json()["items"]
    secili = [u["id"] for u in liste[:2]]

    r = client.patch("/units/toplu", headers=yon,
                     json={"unit_ids": secili, "aktif": False})
    assert r.status_code == 200, r.text
    assert r.json()["etkilenen"] == 2

    sonra = client.get(f"/units?limit=200&blok={blok}", headers=yon).json()["items"]
    pasif = {u["id"] for u in sonra if not u["aktif"]}
    assert pasif == set(secili), "toplu islem yanlis daireleri etkiledi"


def test_TOPLU_alan_verilmezse_422(client, yon):
    """Bos bir PATCH, kullaniciya "yaptim" deyip hicbir sey yapmamak
    olurdu."""
    blok = _blok()
    client.post("/units/bulk", headers=yon, json={
        "blok": blok, "kat_sayisi": 1, "kat_basi_daire": 1, "baslangic_no": 1})
    u = client.get(f"/units?limit=5&blok={blok}", headers=yon).json()["items"][0]
    r = client.patch("/units/toplu", headers=yon, json={"unit_ids": [u["id"]]})
    assert r.status_code == 422, r.text


def test_BASKA_TESISIN_dairesi_ATLANIR(client, world, yon):
    """RLS baska tenant'in satirini zaten gostermez; kimlik SESSIZCE
    dusmez, `atlanan` icinde raporlanir."""
    b = _giris(client, world["slug_b"], world["yonetici_b"])
    blok_b = _blok()
    client.post("/units/bulk", headers=b, json={
        "blok": blok_b, "kat_sayisi": 1, "kat_basi_daire": 1, "baslangic_no": 1})
    yabanci = client.get(
        f"/units?limit=5&blok={blok_b}", headers=b
    ).json()["items"][0]["id"]

    r = client.patch("/units/toplu", headers=yon,
                     json={"unit_ids": [yabanci], "aktif": False})
    assert r.status_code == 200, r.text
    assert r.json()["etkilenen"] == 0
    assert yabanci in r.json()["atlanan"]


# ========================== 3) SIRALAMA ==================================== #

def test_SIRALAMA_tek_istekte_uygulanir(client, yon):
    """Her daire icin ayri PATCH, yirmi dairelik bir katta yirmi istek ve
    ARADA KESILME riski demekti."""
    blok = _blok()
    client.post("/units/bulk", headers=yon, json={
        "blok": blok, "kat_sayisi": 1, "kat_basi_daire": 3, "baslangic_no": 1})
    liste = client.get(f"/units?limit=200&blok={blok}", headers=yon).json()["items"]

    ters = [
        {"id": u["id"], "kat": 5, "sira": len(liste) - i}
        for i, u in enumerate(liste)
    ]
    r = client.patch("/units/siralama", headers=yon, json={"satirlar": ters})
    assert r.status_code == 200, r.text

    sonra = {
        u["id"]: (u["kat"], u["sira"])
        for u in client.get(f"/units?limit=200&blok={blok}", headers=yon).json()["items"]
    }
    for satir in ters:
        assert sonra[satir["id"]] == (satir["kat"], satir["sira"])


# ========================== 4) KAT SILME =================================== #

def test_KAT_SILME_kaza_korumali(client, yon):
    blok = _blok()
    client.post("/units/bulk", headers=yon, json={
        "blok": blok, "kat_sayisi": 2, "kat_basi_daire": 2,
        "baslangic_no": 1, "baslangic_kat": 1})

    # ONAYSIZ: 409 ve HICBIR SEY silinmez.
    r = client.post("/units/kat-sil", headers=yon, json={"blok": blok, "kat": 1})
    assert r.status_code == 409, r.text
    assert len(client.get(
        f"/units?limit=200&blok={blok}", headers=yon).json()["items"]) == 4

    r = client.post("/units/kat-sil", headers=yon,
                    json={"blok": blok, "kat": 1, "cascade": True})
    assert r.status_code == 200, r.text
    assert r.json()["silinen"] == 2

    kalan = client.get(f"/units?limit=200&blok={blok}", headers=yon).json()["items"]
    assert {u["kat"] for u in kalan} == {2}


def test_OLMAYAN_kat_404(client, yon):
    r = client.post("/units/kat-sil", headers=yon,
                    json={"blok": _blok(), "kat": 9, "cascade": True})
    assert r.status_code == 404, r.text


# ===================== 5) BLOK TOPLU SILME ================================= #

def test_BLOK_TOPLU_SILME_satir_satir_raporlar(client, yon):
    """Sessizce atlamak, kullanicinin sildigini sanmasi demekti. Dolu blok
    otekilerin silinmesini de ENGELLEMEZ: on blogun ikisi doluysa
    kullaniciyi listeyi elle ayiklamaya zorlardi."""
    bos = client.post("/blocks", headers=yon, json={"ad": _blok()}).json()
    dolu_ad = _blok()
    dolu = client.post("/blocks", headers=yon, json={"ad": dolu_ad}).json()
    client.post("/units/bulk", headers=yon, json={
        "blok": dolu_ad, "kat_sayisi": 1, "kat_basi_daire": 1, "baslangic_no": 1})

    r = client.post("/blocks/toplu-sil", headers=yon,
                    json={"ids": [bos["id"], dolu["id"]]})
    assert r.status_code == 200, r.text
    assert r.json()["silinen"] == 1
    sebepler = {a["sebep"] for a in r.json()["atlanan"]}
    assert sebepler == {"daire_var"}

    # cascade ile dolu blok da gider.
    r = client.post("/blocks/toplu-sil", headers=yon,
                    json={"ids": [dolu["id"]], "cascade": True})
    assert r.json()["silinen"] == 1


# ======================= 6) KULLANICI SILME ================================ #

def test_KULLANICI_SILINIR(client, yon):
    yeni = client.post("/users", headers=yon, json={
        "ad": "Silinecek Kisi", "role": "security",
        "telefon": f"+9053{uuid.uuid4().int % 10**8:08d}",
    })
    assert yeni.status_code == 201, yeni.text
    uid = yeni.json()["id"]

    assert client.delete(f"/users/{uid}", headers=yon).status_code == 204
    kalan = client.get("/users?limit=200", headers=yon).json()["items"]
    assert uid not in [u["id"] for u in kalan]


def test_KENDI_hesabini_SILEMEZ(client, world, yon):
    """Oturumu acik kisinin kendi kaydini silmesi tesisi yoneticisiz
    birakabilir ve geri alinamaz."""
    ben = client.get("/me", headers=yon).json()
    r = client.delete(f"/users/{ben['id']}", headers=yon)
    assert r.status_code == 409, r.text


def test_YONETICI_ADMINI_silemez(client, world, yon, owner_conn):
    """Ayni yetki kapisindan gecer: yonetici kendi kumesi disindaki bir
    kaydi silemez."""
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT u.id FROM app_user u JOIN tenant t ON t.id = u.tenant_id "
            "WHERE t.slug = %s AND u.role = 'admin' LIMIT 1",
            (world["slug_a"],),
        )
        satir = cur.fetchone()
    if satir is None:
        pytest.skip("bu tesiste admin yok")
    assert client.delete(f"/users/{satir[0]}", headers=yon).status_code == 403


def test_SAKIN_kullanici_SILEMEZ(client, world):
    sakin = _giris(client, world["slug_a"], world["resident_a"])
    ben = client.get("/me", headers=sakin).json()
    assert client.delete(f"/users/{ben['id']}", headers=sakin).status_code == 403


# ============ 7) DAIRE BASINA TEK HESAP (kilitli kural) ==================== #

def _sakin(client, yon, ad="Yeni Sakin"):
    r = client.post("/users", headers=yon, json={
        "ad": ad, "role": "resident",
        "telefon": f"+9053{uuid.uuid4().int % 10**8:08d}",
    })
    assert r.status_code == 201, r.text
    return r.json()["id"]


def _daire(client, yon):
    blok = _blok()
    client.post("/units/bulk", headers=yon, json={
        "blok": blok, "kat_sayisi": 1, "kat_basi_daire": 1, "baslangic_no": 1})
    return client.get(f"/units?limit=5&blok={blok}", headers=yon).json()["items"][0]


def test_DAIRE_BASINA_TEK_HESAP(client, yon):
    """Brief'in KILITLI KURALI. Ikinci atama 409 doner."""
    u = _daire(client, yon)
    a, b = _sakin(client, yon, "Sakin A"), _sakin(client, yon, "Sakin B")

    assert client.post(f"/units/{u['id']}/residents", headers=yon,
                       json={"user_id": a}).status_code == 201
    r = client.post(f"/units/{u['id']}/residents", headers=yon, json={"user_id": b})
    assert r.status_code == 409, r.text


def test_DAIRE_EL_DEGISTIREBILIR(client, yon):
    """"Aktif" olculur, "hic" degil: gecmis sakinler sayilsaydi bir daire
    EL DEGISTIREMEZDI — kiraci cikip yenisi girdiginde daire sonsuza dek
    dolu gorunurdu."""
    u = _daire(client, yon)
    a, b = _sakin(client, yon, "Eski"), _sakin(client, yon, "Yeni")

    client.post(f"/units/{u['id']}/residents", headers=yon, json={"user_id": a})
    assert client.delete(
        f"/units/{u['id']}/residents/{a}", headers=yon
    ).status_code == 204
    r = client.post(f"/units/{u['id']}/residents", headers=yon, json={"user_id": b})
    assert r.status_code == 201, r.text


def test_EXCELDE_AYNI_DAIREYE_IKI_SATIR_ILKI_KAZANIR(client, yon):
    """Uzerine yazmak, ilk satiri kullaniciya hic soylemeden atmak
    olurdu; ikisini de baglamak kurali cignerdi."""
    u = _daire(client, yon)
    t1, t2 = (f"+9053{uuid.uuid4().int % 10**8:08d}" for _ in range(2))

    r = client.post("/ice-aktarim/kisi", headers=yon, json={"satirlar": [
        {"satir_no": 1, "degerler": {"ad": "Birinci", "telefon": t1,
                                     "daire_no": u["no"]}},
        {"satir_no": 2, "degerler": {"ad": "Ikinci", "telefon": t2,
                                     "daire_no": u["no"]}},
    ]})
    assert r.status_code == 201, r.text
    sonuc = r.json()
    assert sonuc["olusan"] == 1, "iki satir da yazildi — kural cignendi"
    assert sonuc["hatali"] == 1
    assert sonuc["hatalar"][0]["satir_no"] == 2, "ILK satir kazanmali"
