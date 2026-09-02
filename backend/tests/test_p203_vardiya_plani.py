"""(P203 §4) VARDIYA PLANLAMA — uc davranisi.

===========================================================================
ONCE OLCUM: MEVCUT MODEL PLANLAMA YAPAMIYORDU
===========================================================================
`shift_assignment` TARIH TASIMIYOR — soyledigi tek sey "Ali gece
vardiyasindadir". Haftalik plan, gun ici degisiklik ve cakisma kontrolu
ucu de tarih ister. Goc 0093 `vardiya_plani` tablosunu ekledi;
`shift_assignment` VARSAYILAN KADRO olarak KALDI.
"""
from __future__ import annotations

import datetime as dt
import uuid

import pytest


def _giris(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def duzen(client, world, owner_conn):
    """Iki vardiya sablonu + iki personel; testler arasi TEMIZ."""
    with owner_conn.cursor() as cur:
        cur.execute("DELETE FROM vardiya_plani WHERE tenant_id=%s", (world["a"],))
        cur.execute("DELETE FROM shift_assignment WHERE tenant_id=%s", (world["a"],))
        cur.execute("DELETE FROM shift WHERE tenant_id=%s AND ad LIKE 'P203%%'",
                    (world["a"],))
        cur.execute(
            "INSERT INTO shift (tenant_id, ad, baslangic_saat, bitis_saat) "
            "VALUES (%s,'P203 Gunduz','08:00','16:00') RETURNING id", (world["a"],))
        gunduz = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO shift (tenant_id, ad, baslangic_saat, bitis_saat) "
            "VALUES (%s,'P203 Gece','20:00','08:00') RETURNING id", (world["a"],))
        gece = cur.fetchone()[0]
        cur.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND role='security' LIMIT 1",
            (world["a"],))
        kisi = cur.fetchone()[0]
        cur.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND role='tesis_gorevlisi' "
            "LIMIT 1", (world["a"],))
        kisi2 = cur.fetchone()[0]
    yield {"gunduz": str(gunduz), "gece": str(gece),
           "kisi": str(kisi), "kisi2": str(kisi2)}
    with owner_conn.cursor() as cur:
        cur.execute("DELETE FROM vardiya_plani WHERE tenant_id=%s", (world["a"],))
        cur.execute("DELETE FROM shift_assignment WHERE tenant_id=%s", (world["a"],))
        cur.execute("DELETE FROM shift WHERE tenant_id=%s AND ad LIKE 'P203%%'",
                    (world["a"],))


BUGUN = dt.date(2026, 9, 2)   # carsamba — hafta ici


def _ata(client, h, duzen, shift, tarih=BUGUN, kisi=None, **kw):
    return client.post("/vardiya-plani", headers=h, json={
        "shift_id": duzen[shift], "tarih": tarih.isoformat(),
        "user_id": kisi or duzen["kisi"], **kw})


def _hafta(client, h, gun=7, baslangic=BUGUN):
    r = client.get("/vardiya-plani", headers=h,
                   params={"baslangic": baslangic.isoformat(), "gun": gun})
    assert r.status_code == 200, r.text
    return r.json()


# ======================= 4.1 HAFTALIK GORUNUM ============================= #

def test_HAFTA_gun_x_vardiya_izgarasi(client, world, duzen):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    d = _hafta(client, h)
    assert len(d["gunler"]) == 7
    adlar = {s["shift_ad"] for s in d["gunler"][0]["slotlar"]}
    assert {"P203 Gunduz", "P203 Gece"} <= adlar


def test_BOS_VARDIYA_acikca_isaretli(client, world, duzen):
    """Istegin acik sarti: "bos kalan vardiyalar BELIRGIN olsun".
    Bayrak `kisiler`den turetilebilir ama yine de doner — istemci
    "uzunluk 0" kontrolunu her cizim yerinde tekrarlasaydi birinde
    unuturdu."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    d = _hafta(client, h, gun=1)
    assert all(s["bos"] for s in d["gunler"][0]["slotlar"])

    _ata(client, h, duzen, "gunduz")
    d = _hafta(client, h, gun=1)
    gunduz = next(s for s in d["gunler"][0]["slotlar"] if s["shift_ad"] == "P203 Gunduz")
    gece = next(s for s in d["gunler"][0]["slotlar"] if s["shift_ad"] == "P203 Gece")
    assert gunduz["bos"] is False and len(gunduz["kisiler"]) == 1
    assert gece["bos"] is True


def test_GUN_TIPI_sablonu_YALNIZ_UYGUN_GUNDE_cizilir(client, world, duzen, owner_conn):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO shift (tenant_id, ad, baslangic_saat, bitis_saat, gun_tipi) "
            "VALUES (%s,'P203 Haftasonu','10:00','18:00','hafta_sonu'::gun_tipi)",
            (world["a"],))
    d = _hafta(client, h)
    carsamba = d["gunler"][0]          # 2026-09-02 carsamba
    cumartesi = d["gunler"][3]         # 2026-09-05 cumartesi
    assert not any(s["shift_ad"] == "P203 Haftasonu" for s in carsamba["slotlar"])
    assert any(s["shift_ad"] == "P203 Haftasonu" for s in cumartesi["slotlar"])


# ========================= 4.3 ATAMA + CAKISMA ============================ #

def test_ATAMA_ve_GUN_ICI_CIKARMA(client, world, duzen):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    r = _ata(client, h, duzen, "gunduz")
    assert r.status_code == 201, r.text
    plan_id = r.json()["id"]

    r = client.delete(f"/vardiya-plani/{plan_id}", headers=h,
                      params={"not_metni": "hastalik"})
    assert r.status_code == 200, r.text
    # SILMEZ, IPTAL ISARETLER: denetim izi "neyin degistigini" gostermeli.
    assert r.json()["durum"] == "iptal"
    d = _hafta(client, h, gun=1)
    gunduz = next(s for s in d["gunler"][0]["slotlar"] if s["shift_ad"] == "P203 Gunduz")
    assert gunduz["bos"] is True


def test_CIKARILAN_KISI_GERI_KONABILIR(client, world, duzen):
    """Iptal edilmis satir YENIDEN CANLANIR; yeni satir acmak ayni
    ucusu icin iki kayit birakir ve denetim izini okunmaz yapardi."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    plan_id = _ata(client, h, duzen, "gunduz").json()["id"]
    client.delete(f"/vardiya-plani/{plan_id}", headers=h)
    r = _ata(client, h, duzen, "gunduz")
    assert r.status_code == 201, r.text
    assert r.json()["id"] == plan_id, "ayni satir canlanmali"


def test_AYNI_ATAMA_IKINCI_KEZ_anlasilir_hata(client, world, duzen):
    """ILK YAZIMDA burada "bu kisi ayni saatte baska bir vardiyada"
    diyordu — cakisma denetimi KENDI satiriyla cakisiyor saniyordu.
    Akis calistirilinca goruldu."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    _ata(client, h, duzen, "gunduz")
    r = _ata(client, h, duzen, "gunduz")
    assert r.status_code == 422, r.text
    assert "zaten" in r.json()["error"]["message"].lower()


def test_CAKISMA_KESIN_REDDEDILIR(client, world, duzen, owner_conn):
    """Ayni kisi ayni anda iki yerde OLAMAZ — tercih degil, fiziksel
    imkansizlik. Uyari verip gecmek plani YALAN yapardi."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO shift (tenant_id, ad, baslangic_saat, bitis_saat) "
            "VALUES (%s,'P203 Ogle','12:00','20:00') RETURNING id", (world["a"],))
        ogle = str(cur.fetchone()[0])
    _ata(client, h, duzen, "gunduz")              # 08-16
    r = client.post("/vardiya-plani", headers=h, json={
        "shift_id": ogle, "tarih": BUGUN.isoformat(), "user_id": duzen["kisi"]})
    assert r.status_code == 422, r.text
    assert "aynı saatte" in r.json()["error"]["message"]


def test_UC_UCA_VARDIYALAR_CAKISMA_SAYILMAZ(client, world, duzen):
    """Dun gece 20:00-08:00 ile bugun 08:00-16:00 ARDISIKTIR. Sinir
    anini paylasmak ayni anda iki yerde olmak DEGILDIR; `<=` kullanmak
    mesru bir devir teslimi engellerdi."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    dun = BUGUN - dt.timedelta(days=1)
    assert _ata(client, h, duzen, "gece", tarih=dun).status_code == 201
    r = _ata(client, h, duzen, "gunduz")
    assert r.status_code == 201, r.text


def test_GECEYI_ASAN_vardiya_ERTESI_SABAHLA_cakisir(client, world, duzen, owner_conn):
    """Tarihi yok saymak bunu KACIRIRDI."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO shift (tenant_id, ad, baslangic_saat, bitis_saat) "
            "VALUES (%s,'P203 Erken','06:00','14:00') RETURNING id", (world["a"],))
        erken = str(cur.fetchone()[0])
    dun = BUGUN - dt.timedelta(days=1)
    assert _ata(client, h, duzen, "gece", tarih=dun).status_code == 201
    r = client.post("/vardiya-plani", headers=h, json={
        "shift_id": erken, "tarih": BUGUN.isoformat(), "user_id": duzen["kisi"]})
    assert r.status_code == 422, r.text


# ===================== SURE SINIRLARI: UYARI, RED DEGIL =================== #

def test_ONIKI_SAATLIK_GECE_VARDIYASI_REDDEDILMEZ(client, world, duzen):
    """AKIS CALISTIRILINCA BULUNAN KUSUR.

    Ilk yazimda gunluk 11 saat KESIN REDDI vardi ve 20:00-08:00 gece
    vardiyasi (12 saat) TEK BASINA reddediliyordu — guvenlik
    sektorunun STANDART kalibi. Model ara dinlenmeyi bilmiyor;
    dogrulayamadigimiz bir seyi "kanuna aykiri" diye reddetmek mesru
    bir plani imkansiz kilardi.
    """
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    r = _ata(client, h, duzen, "gece")
    assert r.status_code == 201, r.text
    assert "gunluk_sinir_asildi" in r.json()["uyarilar"]


def test_GUNLUK_ASIM_UYARI_verir(client, world, duzen):
    """8 + 12 = 20 saat: uyarilir ama ENGELLENMEZ."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    _ata(client, h, duzen, "gunduz")
    r = _ata(client, h, duzen, "gece")
    assert r.status_code == 201, r.text
    assert "gunluk_sinir_asildi" in r.json()["uyarilar"]


def test_HAFTALIK_45_ASIMI_UYARI_verir_RED_DEGIL(client, world, duzen):
    """45 saat ustu FAZLA MESAIDIR: yasal (md. 41) ama MALIYETLI.
    Engellemek, §5'in hesaplayip gidere yazdigi mesru durumu imkansiz
    kilardi."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    hafta_bas = BUGUN - dt.timedelta(days=BUGUN.weekday())
    son = None
    for i in range(6):                       # 6 x 8 saat = 48 > 45
        son = _ata(client, h, duzen, "gunduz", tarih=hafta_bas + dt.timedelta(days=i))
        assert son.status_code == 201, son.text
    assert "haftalik_normal_asildi" in son.json()["uyarilar"]


# ===================== KADRODAN TOHUMLAMA ================================= #

def test_HAFTAYI_DOLDUR_varsayilan_kadrodan(client, world, duzen, owner_conn):
    """`shift_assignment` KALDI ve anlami netlesti: VARSAYILAN KADRO.
    Onsuz yonetici her hafta ekibi tek tek atamak zorunda kalirdi."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO shift_assignment (tenant_id, shift_id, user_id) "
            "VALUES (%s,%s,%s)", (world["a"], duzen["gunduz"], duzen["kisi"]))
    r = client.post("/vardiya-plani/haftayi-doldur", headers=h,
                    params={"baslangic": BUGUN.isoformat(), "gun": 3})
    assert r.status_code == 200, r.text
    for gun in r.json()["gunler"]:
        gunduz = next(s for s in gun["slotlar"] if s["shift_ad"] == "P203 Gunduz")
        assert gunduz["bos"] is False, gun["tarih"]


def test_DOLDURMA_BILINCLI_IPTALI_EZMEZ(client, world, duzen, owner_conn):
    """Yoneticinin gun ici karari sessizce geri alinmamali."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO shift_assignment (tenant_id, shift_id, user_id) "
            "VALUES (%s,%s,%s)", (world["a"], duzen["gunduz"], duzen["kisi"]))
    plan_id = _ata(client, h, duzen, "gunduz").json()["id"]
    client.delete(f"/vardiya-plani/{plan_id}", headers=h, params={"not_metni": "izin"})
    client.post("/vardiya-plani/haftayi-doldur", headers=h,
                params={"baslangic": BUGUN.isoformat(), "gun": 1})
    d = _hafta(client, h, gun=1)
    gunduz = next(s for s in d["gunler"][0]["slotlar"] if s["shift_ad"] == "P203 Gunduz")
    assert gunduz["bos"] is True, "iptal edilen atama doldurma ile GERI GELMEMELI"


# ========================== 4.2 ANLIK DURUM =============================== #

def test_SIMDI_gorevde_ve_sonraki(client, world, duzen, owner_conn):
    """Sunucu saati sabitlenemedigi icin GELECEGE bir vardiya konur ve
    "sonraki" alani olculur; "su an gorevde" alani tarihe bagli oldugu
    icin burada IDDIA EDILMEZ (bkz. ölçemediğim notu)."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    yarin = dt.date.today() + dt.timedelta(days=1)
    _ata(client, h, duzen, "gunduz", tarih=yarin)
    r = client.get("/vardiya-plani/simdi", headers=h)
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["sonraki_vardiya"] is not None
    assert d["sonraki_vardiya"]["shift_ad"] == "P203 Gunduz"
    assert [k["user_id"] for k in d["sonrakiler"]] == [duzen["kisi"]]


def test_SIMDI_SAHA_ROLLERINE_de_ACIK(client, world, duzen):
    """"Bir sonraki vardiyada kim var" tam da sahanin sorusudur."""
    h = _giris(client, world["slug_a"], world["guard_a"])
    assert client.get("/vardiya-plani/simdi", headers=h).status_code == 200


def test_SAHA_PLAN_YAZAMAZ(client, world, duzen):
    h = _giris(client, world["slug_a"], world["guard_a"])
    r = _ata(client, h, duzen, "gunduz")
    assert r.status_code == 403, r.text


def test_SAKIN_PLANI_GOREMEZ(client, world, duzen):
    h = _giris(client, world["slug_a"], world["resident_a"])
    r = client.get("/vardiya-plani", headers=h,
                   params={"baslangic": BUGUN.isoformat()})
    assert r.status_code == 403, r.text


# ============================ DENETIM ===================================== #

def test_DEGISIKLIK_DENETIME_YAZILIR(client, world, duzen, owner_conn):
    """(istek §4.3) Kimin yerine kimin konuldugu, bir olay sonrasi
    sorulacak ILK sorudur."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    plan_id = _ata(client, h, duzen, "gunduz").json()["id"]
    client.delete(f"/vardiya-plani/{plan_id}", headers=h, params={"not_metni": "grip"})
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT meta FROM audit_log WHERE tenant_id=%s "
            "AND action='vardiya_plan_update' ORDER BY ts DESC LIMIT 2",
            (world["a"],))
        kayitlar = [r[0] for r in cur.fetchall()]
    islemler = {k.get("islem") for k in kayitlar}
    assert {"ata", "cikar"} <= islemler, kayitlar
    assert any(k.get("not") == "grip" for k in kayitlar)


def test_BASKA_TESISIN_plani_GORUNMEZ(client, world, duzen, owner_conn):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO shift (tenant_id, ad, baslangic_saat, bitis_saat) "
            "VALUES (%s,'B TESIS VARDIYA','08:00','16:00')", (world["b"],))
    d = _hafta(client, h, gun=1)
    adlar = {s["shift_ad"] for s in d["gunler"][0]["slotlar"]}
    assert "B TESIS VARDIYA" not in adlar
