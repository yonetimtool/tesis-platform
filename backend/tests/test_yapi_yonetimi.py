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
        "email": f"sil-{uuid.uuid4().hex[:8]}@acme.com",
        "telefon": f"+9053{uuid.uuid4().int % 10**8:08d}",
    })
    assert yeni.status_code == 201, yeni.text
    uid = yeni.json()["id"]

    # (P189) Akilli silme: gecmisi YOK -> sert silme (deleted=true), 200 doner.
    r = client.delete(f"/users/{uid}", headers=yon)
    assert r.status_code == 200, r.text
    assert r.json()["deleted"] is True
    kalan = client.get("/users?limit=200", headers=yon).json()["items"]
    assert uid not in [u["id"] for u in kalan]


def test_KULLANICI_baglantili_silme_500_VERMEZ(client, yon):
    """(P189) Daire baglantisi/gecmisi olan kullanicida eski HAM `db.delete`
    IntegrityError firlatiyordu; akilli silme 200 doner (sert ya da anonim —
    hangisi olursa olsun 405/500 DEGIL)."""
    created = client.post("/residents", headers=yon, json={
        "telefon": f"+9053{uuid.uuid4().int % 10**8:08d}",
        "unit_no": f"SIL-{uuid.uuid4().hex[:4]}",
        "email": f"sil2-{uuid.uuid4().hex[:8]}@acme.com",
    }).json()
    uid = created["user_id"]
    r = client.delete(f"/users/{uid}", headers=yon)
    assert r.status_code == 200, r.text
    assert isinstance(r.json()["deleted"], bool)


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
        "email": f"sakin-{uuid.uuid4().hex[:8]}@acme.com",
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
    """Kilitli kural 4 — ROL BASINA (goc 0049; karar rapor §4.51).

    Rolsuz iki atama: ikincisi 409. NULL da BIR DEGERDIR.
    """
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


# ============ (P154 / goc 0049) DAIREDE HER ROLDEN TEK AKTIF HESAP ========== #
#
# Kuralin HARFI (rol'e bakmadan tek sakin) olculdu ve tam takimda 1 kirik +
# 104 hata verdi; kirilan test `test_hedefleme_KIRACI_VAR_YOK_IKISI_BIRDEN`
# idi. `borclandirma.hedef_sec`in `kiraci_oncelikli` kurali bir dairede
# malik VE kiraci bulunabilmesi uzerine kurulu. Kerem A secenegini
# onayladi: her ROLDEN en fazla bir aktif hesap.


def test_MALIK_ve_KIRACI_AYNI_DAIREDE_yasal(client, yon):
    """Bu, kuralin KORUDUGU sey — engelledigi degil.

    `hedef_sec`in `kiraci_oncelikli` kurali ("kiraci varsa ona, yoksa
    malike") tam olarak bu durumu cozmek icin var; engellenseydi o kural
    olu koda donerdi.
    """
    u = _daire(client, yon)
    m, k = _sakin(client, yon, "Malik"), _sakin(client, yon, "Kiraci")

    assert client.post(f"/units/{u['id']}/residents", headers=yon,
                       json={"user_id": m, "rol_tipi": "malik"}).status_code == 201
    r = client.post(f"/units/{u['id']}/residents", headers=yon,
                    json={"user_id": k, "rol_tipi": "kiraci"})
    assert r.status_code == 201, r.text


def test_AYNI_ROLDEN_IKINCI_hesap_409(client, yon):
    u = _daire(client, yon)
    a, b = _sakin(client, yon, "Malik A"), _sakin(client, yon, "Malik B")

    assert client.post(f"/units/{u['id']}/residents", headers=yon,
                       json={"user_id": a, "rol_tipi": "malik"}).status_code == 201
    r = client.post(f"/units/{u['id']}/residents", headers=yon,
                    json={"user_id": b, "rol_tipi": "malik"})
    assert r.status_code == 409, r.text


def test_KISIT_VERITABANINDA_var_ve_ROL_BASINA(owner_conn):
    """Indeks `(unit_id, rol_tipi)` ve KISMI.

    KISMI olmasi SART: kosulsuz benzersizlik, bir daireye GECMISTE
    baglanmis herkesi sonsuza dek engellerdi.

    ESKI INDEKS DE DURUYOR: `(unit_id, user_id)` AYNI KISININ iki kez
    baglanmasini engelliyor ve yeni indeks bunu KAPSAMIYOR (ayni kisi
    malik + kiraci olarak catismadan gecerdi).
    """
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT indexname, indexdef FROM pg_indexes "
            "WHERE tablename = 'unit_resident' AND indexname LIKE 'uq_%'"
        )
        idx = dict(cur.fetchall())

    yeni = idx.get("uq_unitresident_daire_rol")
    assert yeni is not None, "goc 0049'un indeksi YOK"
    assert "UNIQUE" in yeni and "rol_tipi" in yeni
    assert "bitis IS NULL" in yeni, "kismi degil — daire el degistiremezdi"

    eski = idx.get("uq_unitresident_aktif")
    assert eski is not None, (
        "eski indeks dusurulmus — ayni kisi malik+kiraci olarak iki kez "
        "baglanabilir hâle gelir (ve seed'in ON CONFLICT'i kirilir)"
    )


def test_KISIT_UCU_ATLAYAN_yazmayi_da_durdurur(client, yon, owner_conn):
    """Indeksin ASIL isi: uc katmanini HIC gormeyen bir yazma yolu.

    Fixture baglantisi AUTOCOMMIT oldugu icin basarisiz INSERT
    baglantiyi bozmaz; SAVEPOINT'e gerek yok (denendi: "SAVEPOINT can
    only be used in transaction blocks").
    """
    import psycopg

    u = _daire(client, yon)
    a, b = _sakin(client, yon, "SQL A"), _sakin(client, yon, "SQL B")
    assert client.post(f"/units/{u['id']}/residents", headers=yon,
                       json={"user_id": a, "rol_tipi": "malik"}).status_code == 201

    with owner_conn.cursor() as cur:
        cur.execute("SELECT tenant_id FROM unit WHERE id = %s", (u["id"],))
        tenant_id = cur.fetchone()[0]
        try:
            cur.execute(
                "INSERT INTO unit_resident (tenant_id, unit_id, user_id, rol_tipi) "
                "VALUES (%s, %s, %s, 'malik')",
                (tenant_id, u["id"], b),
            )
        except psycopg.errors.UniqueViolation:
            pass
        else:
            raise AssertionError("ikinci malik YAZILDI — kisit yok")


def test_ROLSUZ_BOSLUGU_UYGULAMA_kapatir(client, yon, owner_conn):
    """PostgreSQL benzersiz indekste NULL'lari CATISTIRMAZ.

    Yani rolsuz ikinci sakin VERITABANINDAN gecer; kontrol uygulama
    katmanindadir ve bu bilincli bir sinirdir (goc 0049 basligi: boslugu
    veritabaninda kapatmanin iki yolu da elendi — `COALESCE` IMMUTABLE
    degil, ayri kismi indeks 37 testi kirdi).

    Test IKISINI DE olcer: uc reddeder, dogrudan SQL gecer.
    """
    u = _daire(client, yon)
    a, b = _sakin(client, yon, "Rolsuz A"), _sakin(client, yon, "Rolsuz B")
    assert client.post(f"/units/{u['id']}/residents", headers=yon,
                       json={"user_id": a}).status_code == 201

    # UC: reddeder.
    assert client.post(f"/units/{u['id']}/residents", headers=yon,
                       json={"user_id": b}).status_code == 409

    # DOGRUDAN SQL: gecer — belgelenen sinir.
    with owner_conn.cursor() as cur:
        cur.execute("SELECT tenant_id FROM unit WHERE id = %s", (u["id"],))
        tenant_id = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO unit_resident (tenant_id, unit_id, user_id) "
            "VALUES (%s, %s, %s) RETURNING id",
            (tenant_id, u["id"], b),
        )
        assert cur.fetchone() is not None, (
            "rolsuz ikinci satir veritabanindan GECMELIYDI — gecmiyorsa "
            "indeks degismis ve 37 ziyaretci testi kirilmis olmali"
        )


def test_KAPATILAN_bag_AYNI_ROLE_yer_acar(client, yon, owner_conn):
    """`bitis` yazilmis bag kisiti ISGAL ETMEZ.

    Kapatma = SILME DEGIL: eski satir tarihcede kalir, hesap ve erisim
    dokunulmaz (kilitli kural 1) — ama rol yeniden atanabilir.
    """
    u = _daire(client, yon)
    a, b = _sakin(client, yon, "Cikan Malik"), _sakin(client, yon, "Giren Malik")
    client.post(f"/units/{u['id']}/residents", headers=yon,
                json={"user_id": a, "rol_tipi": "malik"})
    assert client.delete(
        f"/units/{u['id']}/residents/{a}", headers=yon
    ).status_code == 204

    r = client.post(f"/units/{u['id']}/residents", headers=yon,
                    json={"user_id": b, "rol_tipi": "malik"})
    assert r.status_code == 201, r.text

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM unit_resident WHERE unit_id = %s", (u["id"],)
        )
        assert cur.fetchone()[0] == 2, "eski satir silinmis — tarihce kaybi"


def test_EXCELDE_FARKLI_ROL_IKI_SATIR_IKISI_de_gecer(client, yon):
    """Ayni daireye malik + kiraci satiri: IKISI de yazilir.

    Ayni rolden iki satirda ilki kazaniyordu
    (`test_EXCELDE_AYNI_DAIREYE_IKI_SATIR_ILKI_KAZANIR`); ayrim ROLDE.
    """
    u = _daire(client, yon)
    t1, t2 = (f"+9053{uuid.uuid4().int % 10**8:08d}" for _ in range(2))

    r = client.post("/ice-aktarim/kisi", headers=yon, json={"satirlar": [
        {"satir_no": 1, "degerler": {"ad": "Malik", "telefon": t1,
                                     "daire_no": u["no"], "rol_tipi": "malik"}},
        {"satir_no": 2, "degerler": {"ad": "Kiraci", "telefon": t2,
                                     "daire_no": u["no"], "rol_tipi": "kiraci"}},
    ]})
    assert r.status_code == 201, r.text
    assert r.json()["olusan"] == 2, r.json()
    assert r.json()["hatali"] == 0
