"""Tahsilat, kasa ve finansal hareketler (P29).

Kilitlenen kararlar:
  * BAKIYE SAKLANMAZ, DEFTERDEN TURETILIR (kabul olcutu: bakiye = hareket
    toplami),
  * tutar HER ZAMAN POZITIF, isaret `yon`da,
  * virman IKI SATIR, iade TERS YONLU YENI kayit (orijinal silinmez),
  * banka eslestirme ONERIDIR; belirsizlikte ONERI URETMEZ,
  * icra dosyasi borcu KOPYALAMAZ, anlik okur.
"""
from __future__ import annotations

import uuid

import pytest



def _p197_mail() -> str:
    """(P197) Kullanici/sakin olusturmada e-posta ZORUNLU oldu.

    `app_user.email` NOT NULL (goc 0089): davet, dogrulama kodu ve parola
    sifirlama YALNIZ e-postadan gidiyor, yani e-postasiz acilan hesap
    sahiplenilemez. Test govdelerine BENZERSIZ adres verilir —
    `uq_app_user_tenant_email` ayni tesiste tekrari reddeder.
    """
    return f"p197-{uuid.uuid4().hex[:12]}@ornek.com"

def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _sfx() -> str:
    return uuid.uuid4().hex[:6]


@pytest.fixture
def adm(client, world):
    return _headers(client, world["slug_a"], world["admin_a"])


@pytest.fixture
def kasa(client, adm):
    r = client.post("/kasalar", headers=adm, json={
        "kod": f"K{_sfx()}", "ad": "Test Kasa", "acilis_bakiye_kurus": 100000})
    assert r.status_code == 201, r.text
    return r.json()


def _bakiye(client, adm, kasa_id):
    liste = client.get("/finans/kasa-bakiyeleri", headers=adm).json()["items"]
    return next(k for k in liste if k["kasa_id"] == kasa_id)


# ============================== BAKIYE ====================================== #
def test_bakiye_ACILIS_artı_HAREKET_toplami(client, adm, kasa):
    """KABUL OLCUTU: kasa bakiye ≡ hareket toplami. Bakiye SAKLANMAZ."""
    assert _bakiye(client, adm, kasa["id"])["bakiye_kurus"] == 100000

    client.post("/finans/tahsilat", headers=adm, json={
        "kasa_id": kasa["id"], "tutar_kurus": 50000})
    client.post("/finans/hareketler", headers=adm, json={"satirlar": [
        {"tip": "gider", "tutar_kurus": 20000, "kasa_id": kasa["id"]}]})

    b = _bakiye(client, adm, kasa["id"])
    assert b["bakiye_kurus"] == 100000 + 50000 - 20000
    assert b["hareket_kurus"] == 30000
    assert b["acilis_bakiye_kurus"] == 100000


def test_GIDER_kasadan_CIKAR_GELIR_GIRER(client, adm, kasa):
    """Yon istemciden ALINMAZ: "giris yonlu gider" imkansiz bir satir olurdu."""
    client.post("/finans/hareketler", headers=adm, json={"satirlar": [
        {"tip": "gelir", "tutar_kurus": 7000, "kasa_id": kasa["id"]},
        {"tip": "gider", "tutar_kurus": 3000, "kasa_id": kasa["id"]},
    ]})
    liste = client.get("/finans/hareketler", headers=adm,
                       params={"kasa_id": kasa["id"], "limit": 200}).json()["items"]
    yonler = {h["tip"]: h["yon"] for h in liste}
    assert yonler["gelir"] == "giris" and yonler["gider"] == "cikis"
    assert all(h["tutar_kurus"] > 0 for h in liste), "tutar HER ZAMAN pozitif"


def test_OLMAYAN_kasa_422(client, adm):
    r = client.post("/finans/tahsilat", headers=adm, json={
        "kasa_id": str(uuid.uuid4()), "tutar_kurus": 1000})
    assert r.status_code == 422


# ============================== VIRMAN ====================================== #
def test_virman_IKI_SATIR_ve_TOPLAM_DEGISMEZ(client, adm):
    a = client.post("/kasalar", headers=adm, json={
        "kod": f"A{_sfx()}", "ad": "A", "acilis_bakiye_kurus": 100000}).json()
    b = client.post("/kasalar", headers=adm, json={
        "kod": f"B{_sfx()}", "ad": "B", "acilis_bakiye_kurus": 0}).json()
    once = client.get("/finans/kasa-bakiyeleri", headers=adm).json()["genel_toplam_kurus"]

    r = client.post("/finans/virman", headers=adm, json={
        "kaynak_kasa_id": a["id"], "hedef_kasa_id": b["id"], "tutar_kurus": 40000})
    assert r.status_code == 201, r.text
    assert r.json()["meta"]["total"] == 2
    yonler = sorted(h["yon"] for h in r.json()["items"])
    assert yonler == ["cikis", "giris"]
    # IKI SATIR AYNI GRUBA bagli.
    gruplar = {h["virman_grup_id"] for h in r.json()["items"]}
    assert len(gruplar) == 1 and None not in gruplar

    assert _bakiye(client, adm, a["id"])["bakiye_kurus"] == 60000
    assert _bakiye(client, adm, b["id"])["bakiye_kurus"] == 40000
    # GENEL TOPLAM degismez — para site icinde yer degistirdi.
    sonra = client.get("/finans/kasa-bakiyeleri", headers=adm).json()["genel_toplam_kurus"]
    assert sonra == once


def test_virman_AYNI_KASAYA_reddedilir(client, adm, kasa):
    r = client.post("/finans/virman", headers=adm, json={
        "kaynak_kasa_id": kasa["id"], "hedef_kasa_id": kasa["id"],
        "tutar_kurus": 1000})
    assert r.status_code == 422


# =============================== IADE ======================================= #
def test_iade_TERS_YONLU_YENI_kayit_orijinal_DURUR(client, adm, kasa):
    """Defter APPEND-ONLY okunur: silinen bir tahsilat gecmis raporlari
    geriye donuk degistirirdi."""
    t = client.post("/finans/tahsilat", headers=adm, json={
        "kasa_id": kasa["id"], "tutar_kurus": 30000}).json()
    r = client.post("/finans/iade", headers=adm, json={"hareket_id": t["id"]})
    assert r.status_code == 201, r.text
    assert r.json()["yon"] == "cikis" and r.json()["tutar_kurus"] == 30000
    assert r.json()["iade_edilen_id"] == t["id"]

    # Orijinal DURUYOR.
    liste = client.get("/finans/hareketler", headers=adm,
                       params={"kasa_id": kasa["id"], "limit": 200}).json()["items"]
    assert t["id"] in [h["id"] for h in liste]
    assert _bakiye(client, adm, kasa["id"])["bakiye_kurus"] == 100000


def test_iade_KISMI_serbest_TOPLAM_asamaz(client, adm, kasa):
    t = client.post("/finans/tahsilat", headers=adm, json={
        "kasa_id": kasa["id"], "tutar_kurus": 10000}).json()
    assert client.post("/finans/iade", headers=adm, json={
        "hareket_id": t["id"], "tutar_kurus": 4000}).status_code == 201
    assert client.post("/finans/iade", headers=adm, json={
        "hareket_id": t["id"], "tutar_kurus": 6000}).status_code == 201
    # Toplam 10.000'e ulasti; bir kurus daha iade EDILEMEZ.
    r = client.post("/finans/iade", headers=adm, json={
        "hareket_id": t["id"], "tutar_kurus": 1})
    assert r.status_code == 422


def test_IADE_iade_edilemez(client, adm, kasa):
    t = client.post("/finans/tahsilat", headers=adm, json={
        "kasa_id": kasa["id"], "tutar_kurus": 5000}).json()
    i = client.post("/finans/iade", headers=adm, json={"hareket_id": t["id"]}).json()
    r = client.post("/finans/iade", headers=adm, json={"hareket_id": i["id"]})
    assert r.status_code == 422


# ============================ ACILIS + TOPLU ================================ #
def test_acilis_fisi_bakiyeye_girer(client, adm, kasa):
    client.post("/finans/acilis", headers=adm, json={
        "kasa_id": kasa["id"], "yon": "giris", "tutar_kurus": 25000})
    assert _bakiye(client, adm, kasa["id"])["bakiye_kurus"] == 125000


def test_toplu_tahsilat_HEPSI_ya_da_HICBIRI(client, adm, kasa):
    r = client.post("/finans/tahsilat/toplu", headers=adm, json={
        "kasa_id": kasa["id"],
        "satirlar": [{"tutar_kurus": 1000}, {"tutar_kurus": 2000},
                     {"tutar_kurus": 3000}],
    })
    assert r.status_code == 201 and r.json()["meta"]["total"] == 3
    assert _bakiye(client, adm, kasa["id"])["bakiye_kurus"] == 106000


# ========================== BANKA ESLESTIRME ================================ #
def test_banka_eslestirme_ONERI_uretir_belirsizde_URETMEZ(client, adm, world):
    """Yanlis eslesen bir satir, BASKASININ borcunu kapatip gercek borclunun
    borcunu ACIK birakirdi — belirsizlikte oneri uretilmez."""
    # Iki sakin + esit borc: tutar ayni olunca ONERI BELIRSIZ olmali.
    tanim = client.post("/gelir-gider-tanimlari", headers=adm, json={
        "ad": f"Aidat-{_sfx()}", "tip": "gider"}).json()
    kisiler = []
    for ad in ("Ahmet Şahin", "Mehmet Yılmaz"):
        u = client.post("/units", headers=adm,
                        json={"no": f"F-{_sfx()}", "blok": "A"}).json()
        r = client.post("/residents", headers=adm, json={
            "ad": ad, "unit_no": u["no"],
            "telefon": f"+9054{uuid.uuid4().int % 10**8:08d}",
            "rol_tipi": "malik", "email": _p197_mail()})
        assert r.status_code in (200, 201), r.text
        kisiler.append(r.json())
        client.post("/dues/assessments", headers=adm, json={
            "donem": f"2029-{len(kisiler):02d}", "unit_id": u["id"],
            "tutar_kurus": 123456, "gelir_gider_tanim_id": tanim["id"]})

    sonuc = client.post("/finans/banka-eslestir", headers=adm, json={"satirlar": [
        # (1) AD + TUTAR tam -> yuksek guven
        {"satir_no": 1, "aciklama": "AHMET SAHIN AIDAT ODEMESI",
         "tutar_kurus": 123456},
        # (2) yalnizca TUTAR -> iki kisi de esler -> BELIRSIZ
        {"satir_no": 2, "aciklama": "HAVALE", "tutar_kurus": 123456},
        # (3) hicbir sey tutmuyor
        {"satir_no": 3, "aciklama": "KIRA GELIRI", "tutar_kurus": 999999},
    ]}).json()["oneriler"]
    esle = {o["satir_no"]: o for o in sonuc}
    assert esle[1]["user_id"] == kisiler[0]["user_id"], esle[1]
    assert esle[1]["guven"] >= 90
    assert esle[2]["user_id"] is None and esle[2]["neden"] == "belirsiz"
    assert esle[3]["user_id"] is None


# ============================ ICRA DOSYASI ================================== #
def test_icra_dosyasi_borcu_KOPYALAMAZ_anlik_okur(client, adm):
    tanim = client.post("/gelir-gider-tanimlari", headers=adm, json={
        "ad": f"T-{_sfx()}", "tip": "gider"}).json()
    u = client.post("/units", headers=adm,
                    json={"no": f"I-{_sfx()}", "blok": "A"}).json()
    kisi = client.post("/residents", headers=adm, json={
        "ad": "Borclu Kisi", "unit_no": u["no"],
        "telefon": f"+9054{uuid.uuid4().int % 10**8:08d}", "rol_tipi": "malik", "email": _p197_mail()}).json()
    client.post("/dues/assessments", headers=adm, json={
        "donem": "2029-11", "unit_id": u["id"], "tutar_kurus": 50000,
        "gelir_gider_tanim_id": tanim["id"]})

    d = client.post("/finans/icra-dosyalari", headers=adm, json={
        "dosya_no": f"2029/{_sfx()}", "user_id": kisi["user_id"],
        "avukat": "Av. Test"})
    assert d.status_code == 201, d.text
    assert d.json()["acik_borc_kurus"] == 50000
    assert d.json()["user_ad"] == "Borclu Kisi"

    # Tahsilat yapilinca dosyaya DOKUNULMADAN borc duser.
    kasa = client.post("/kasalar", headers=adm, json={
        "kod": f"IC{_sfx()}", "ad": "K"}).json()
    client.post("/finans/tahsilat", headers=adm, json={
        "kasa_id": kasa["id"], "user_id": kisi["user_id"], "tutar_kurus": 20000})
    liste = client.get("/finans/icra-dosyalari", headers=adm,
                       params={"user_id": kisi["user_id"]}).json()["items"]
    assert liste[0]["acik_borc_kurus"] == 30000


def test_icra_dosya_no_TEK(client, adm, world):
    kisi_id = client.get("/users", headers=adm,
                         params={"limit": 5}).json()["items"][0]["id"]
    no = f"2029/{_sfx()}"
    assert client.post("/finans/icra-dosyalari", headers=adm, json={
        "dosya_no": no, "user_id": kisi_id}).status_code == 201
    assert client.post("/finans/icra-dosyalari", headers=adm, json={
        "dosya_no": no, "user_id": kisi_id}).status_code == 409


def test_icra_durum_guncellenir(client, adm):
    kisi_id = client.get("/users", headers=adm,
                         params={"limit": 5}).json()["items"][0]["id"]
    d = client.post("/finans/icra-dosyalari", headers=adm, json={
        "dosya_no": f"2029/{_sfx()}", "user_id": kisi_id}).json()
    # (P168 §2) Durum sozlugu degisti (goc 0062): brief'in bes degeri.
    r = client.patch(f"/finans/icra-dosyalari/{d['id']}", headers=adm,
                     json={"durum": "mahkemede"})
    assert r.status_code == 200 and r.json()["durum"] == "mahkemede"


# ================================ OZET ====================================== #
def test_ozet_DEFTERDEN_okunur(client, adm, kasa):
    once = client.get("/finans/ozet", headers=adm).json()
    client.post("/finans/tahsilat", headers=adm, json={
        "kasa_id": kasa["id"], "tutar_kurus": 15000})
    sonra = client.get("/finans/ozet", headers=adm).json()
    assert sonra["tahsil_edilen_ay_kurus"] == once["tahsil_edilen_ay_kurus"] + 15000
    assert sonra["kasa_toplam_kurus"] == once["kasa_toplam_kurus"] + 15000


# ================================ RBAC ====================================== #
def test_rbac(client, world):
    # (P206 §1) YONETICI ARTIK YAZAR. Eski beklenti (`False`) bir
    # KUSURU kilitliyordu: yonetici kendi tesisinin tahsilatini
    # giremiyordu — parayi kapida alan kisi o. Gerekce
    # `docs/P206-kararlar.md` K1.1; kapsam kilidi
    # `test_p206_yonetici_finans.py`.
    for rol, yazabilir, okuyabilir in [
        ("admin_a", True, True), ("yonetici_a", True, True),
        ("guard_a", False, False), ("resident_a", False, False),
    ]:
        h = _headers(client, world["slug_a"], world[rol])
        okuma = client.get("/finans/kasa-bakiyeleri", headers=h)
        assert (okuma.status_code == 200) is okuyabilir, (rol, okuma.status_code)
        yazma = client.post("/finans/tahsilat", headers=h, json={
            "kasa_id": str(uuid.uuid4()), "tutar_kurus": 100})
        assert (yazma.status_code != 403) is yazabilir, (rol, yazma.status_code)


def test_tenant_izolasyonu(client, world):
    a = _headers(client, world["slug_a"], world["admin_a"])
    b = _headers(client, world["slug_b"], world["admin_b"])
    kasa = client.post("/kasalar", headers=a, json={
        "kod": f"IZ{_sfx()}", "ad": "A Kasa"}).json()
    client.post("/finans/tahsilat", headers=a, json={
        "kasa_id": kasa["id"], "tutar_kurus": 9999})
    b_kasalar = client.get("/finans/kasa-bakiyeleri", headers=b).json()["items"]
    assert kasa["id"] not in [k["kasa_id"] for k in b_kasalar]
    # B, A'nin kasasina hareket YAZAMAZ.
    r = client.post("/finans/tahsilat", headers=b, json={
        "kasa_id": kasa["id"], "tutar_kurus": 100})
    assert r.status_code == 422


# ======================= IDEMPOTENCY / CIFT KAYIT (P64) ===================== #
#
# OLCULEN RISK: panelin dugmesi ucus sirasinda kilitli oldugu icin HIZLI
# CIFT TIKLAMA zaten korunuyordu; korunmayan sey ZAMAN ASIMI SONRASI
# TEKRARDI. Asagidaki testler "tekrar" davranisini defterin KENDISINDEN
# (kasa bakiyesi) dogruluyor: yalniz yanit govdesine bakmak, ikinci bir
# satirin sessizce yazildigini KACIRABILIRDI.


def _idem() -> dict:
    return {"Idempotency-Key": f"vezne-{uuid.uuid4()}"}


def test_tekrar_AYNI_anahtarla_IKINCI_kayit_ACILMAZ(client, adm, kasa):
    """Ayni anahtarla ikinci istek: 200 + AYNI kayit; bakiye DEGISMEZ."""
    basta = _bakiye(client, adm, kasa["id"])["bakiye_kurus"]
    h = _idem()
    govde = {"kasa_id": kasa["id"], "tutar_kurus": 50000}

    ilk = client.post("/finans/tahsilat", headers={**adm, **h}, json=govde)
    assert ilk.status_code == 201, ilk.text
    ikinci = client.post("/finans/tahsilat", headers={**adm, **h}, json=govde)
    assert ikinci.status_code == 200, ikinci.text
    assert ikinci.json()["id"] == ilk.json()["id"]

    # DEFTERIN KENDISI: bakiye TEK tahsilat kadar artmis olmali.
    assert _bakiye(client, adm, kasa["id"])["bakiye_kurus"] == basta + 50000


def test_tekrar_ANAHTARSIZ_istek_ESKI_davranisi_surdurur(client, adm, kasa):
    """Baslik ZORUNLU DEGIL: gonderilmeyince iki ayri kayit olusur.

    Zorunlu kilmak, calisan prod'da baslik gondermeyen her istemciyi
    ANINDA kirardi; bu test o geriye uyumu kilitler.
    """
    basta = _bakiye(client, adm, kasa["id"])["bakiye_kurus"]
    govde = {"kasa_id": kasa["id"], "tutar_kurus": 1500}
    a = client.post("/finans/tahsilat", headers=adm, json=govde)
    b = client.post("/finans/tahsilat", headers=adm, json=govde)
    assert a.status_code == 201 and b.status_code == 201
    assert a.json()["id"] != b.json()["id"]
    assert _bakiye(client, adm, kasa["id"])["bakiye_kurus"] == basta + 3000


def test_tekrar_AYNI_anahtar_FARKLI_tutar_409(client, adm, kasa):
    """Ayni kimlikle baska bir para hareketi ISTEMCI KUSURUDUR.

    Sessizce eski kaydi dondurmek, kullaniciya "kaydedildi" deyip PARAYI
    KAYDETMEMEK olurdu.
    """
    h = _idem()
    ilk = client.post("/finans/tahsilat", headers={**adm, **h},
                      json={"kasa_id": kasa["id"], "tutar_kurus": 7000})
    assert ilk.status_code == 201, ilk.text
    catisma = client.post("/finans/tahsilat", headers={**adm, **h},
                          json={"kasa_id": kasa["id"], "tutar_kurus": 9999})
    assert catisma.status_code == 409, catisma.text


def test_tekrar_ACIKLAMA_farki_AYNI_islem_sayilir(client, adm, kasa):
    """Serbest metin imzada YOK: kullanici tekrar denerken aciklamayi
    duzeltmis olabilir; para hareketi ayniysa bu AYNI islemdir."""
    basta = _bakiye(client, adm, kasa["id"])["bakiye_kurus"]
    h = _idem()
    a = client.post("/finans/tahsilat", headers={**adm, **h},
                    json={"kasa_id": kasa["id"], "tutar_kurus": 2500,
                          "aciklama": "elden"})
    b = client.post("/finans/tahsilat", headers={**adm, **h},
                    json={"kasa_id": kasa["id"], "tutar_kurus": 2500,
                          "aciklama": "elden tahsilat"})
    assert a.status_code == 201 and b.status_code == 200
    assert _bakiye(client, adm, kasa["id"])["bakiye_kurus"] == basta + 2500


def test_tekrar_COK_SATIRLI_islem_TUM_satirlari_dondurur(client, adm, kasa):
    """VIRMAN IKI SATIRDIR: kimlik satirlarin yalnizca birine yazilsaydi,
    tekrar gelen istek islemin OTEKI satirini bulamazdi (eksik yanit)."""
    r = client.post("/kasalar", headers=adm, json={
        "kod": f"K{_sfx()}", "ad": "Hedef Kasa", "acilis_bakiye_kurus": 0})
    hedef = r.json()
    h = _idem()
    govde = {"kaynak_kasa_id": kasa["id"], "hedef_kasa_id": hedef["id"],
             "tutar_kurus": 12000}

    ilk = client.post("/finans/virman", headers={**adm, **h}, json=govde)
    assert ilk.status_code == 201, ilk.text
    assert len(ilk.json()["items"]) == 2

    ikinci = client.post("/finans/virman", headers={**adm, **h}, json=govde)
    assert ikinci.status_code == 200, ikinci.text
    assert len(ikinci.json()["items"]) == 2
    assert (sorted(k["id"] for k in ikinci.json()["items"])
            == sorted(k["id"] for k in ilk.json()["items"]))
    # Hedef kasa YALNIZ BIR KEZ artmis olmali.
    assert _bakiye(client, adm, hedef["id"])["bakiye_kurus"] == 12000


def test_tekrar_VEZNE_hareket_ucunda_da_gecerli(client, adm, kasa):
    """Panelin gercekten kullandigi uc `POST /finans/hareketler`tir."""
    basta = _bakiye(client, adm, kasa["id"])["bakiye_kurus"]
    h = _idem()
    govde = {"satirlar": [
        {"tip": "gider", "tutar_kurus": 4000, "kasa_id": kasa["id"]}]}
    a = client.post("/finans/hareketler", headers={**adm, **h}, json=govde)
    b = client.post("/finans/hareketler", headers={**adm, **h}, json=govde)
    assert a.status_code == 201, a.text
    assert b.status_code == 200, b.text
    assert _bakiye(client, adm, kasa["id"])["bakiye_kurus"] == basta - 4000
