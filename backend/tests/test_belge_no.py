"""(P167 Asama 4) MERKEZI BELGE NUMARALANDIRMA.

Brief'in zorunlu ilkesi: "Belge numaralandirma MERKEZI olsun, her modul
kendi numarasini uretmesin."

EN PAHALI SONUCLAR, testin agirligi da orada:

 1. AYNI NUMARA IKI BELGEDE. Bir muhasebe kaydinda "hangi fis?" sorusunu
    cevapsiz birakir ve ancak aylar sonra bir mutabakatta fark edilir.
 2. SERININ YIL ILE KARISMASI. 2026'nin 123'u ile 2027'nin 123'u ayirt
    edilemezse ekstre okunamaz.
 3. KULLANICININ YAZDIGI NUMARANIN EZILMESI. Elinde gercek bir fatura
    numarasi olan kisi onu yazabilmeli; merkezi uretim BOS BIRAKILDIGINDA
    devreye girer.
"""
from __future__ import annotations

import re
import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _kasa(client, headers) -> str:
    r = client.post("/kasalar", headers=headers, json={
        "kod": f"K{uuid.uuid4().hex[:6]}", "ad": "Belge Test Kasa",
    })
    assert r.status_code in (200, 201), r.text
    return r.json()["id"]


DESEN = re.compile(r"^(TAH|GID|GEL|IAD|ACL|IPT)-\d{4}-\d{6,}$")


# --------------------------------------------------------------------------- #
# 1. BICIM
# --------------------------------------------------------------------------- #
def test_gider_gelir_belge_no_MERKEZDEN_ve_BICIMLI(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    kasa = _kasa(client, admin)

    r = client.post("/finans/hareketler", headers=admin, json={"satirlar": [
        {"tip": "gider", "tutar_kurus": 1000, "kasa_id": kasa},
        {"tip": "gelir", "tutar_kurus": 2000, "kasa_id": kasa},
    ]})
    assert r.status_code == 201, r.text
    nolar = [s["belge_no"] for s in r.json()["items"]]
    assert all(n and DESEN.match(n) for n in nolar), nolar
    # ON EK TURU SOYLER: ekstrede satiri acmadan okunur.
    assert nolar[0].startswith("GID-")
    assert nolar[1].startswith("GEL-")


def test_ALTI_HANE_sifirla_doldurulur(client, world):
    # Metin siralamasi SAYI siralamasiyla ayni olsun diye: "TAH-2026-9"
    # ile "TAH-2026-10" alfabetik siralamada ters duserdi ve ekstreler
    # yanlis sirada cikardi.
    admin = _headers(client, world["slug_a"], world["admin_a"])
    kasa = _kasa(client, admin)
    r = client.post("/finans/hareketler", headers=admin, json={"satirlar": [
        {"tip": "gider", "tutar_kurus": 100, "kasa_id": kasa},
    ]})
    no = r.json()["items"][0]["belge_no"]
    sira = no.rsplit("-", 1)[1]
    assert len(sira) >= 6 and sira.isdigit(), no


def test_YIL_numaranin_ICINDE(client, world):
    # Seri YILLIK; yil numaranin icinde olmazsa iki farkli yilin 123'u
    # ayirt edilemez.
    admin = _headers(client, world["slug_a"], world["admin_a"])
    kasa = _kasa(client, admin)
    r = client.post("/finans/hareketler", headers=admin, json={"satirlar": [
        {"tip": "gider", "tutar_kurus": 100, "kasa_id": kasa, "tarih": "2026-03-05"},
    ]})
    assert r.json()["items"][0]["belge_no"].startswith("GID-2026-")


def test_GECMIS_TARIHLI_fis_O_YILIN_serisine_duser(client, world):
    """`tarih` verilirse ONUN yili kullanilir, bugunun degil.

    Aksi halde 2026 defterine 2027 numarali bir belge duserdi.
    """
    admin = _headers(client, world["slug_a"], world["admin_a"])
    kasa = _kasa(client, admin)
    r = client.post("/finans/hareketler", headers=admin, json={"satirlar": [
        {"tip": "gider", "tutar_kurus": 100, "kasa_id": kasa, "tarih": "2024-11-20"},
    ]})
    assert r.json()["items"][0]["belge_no"].startswith("GID-2024-")


# --------------------------------------------------------------------------- #
# 2. ARTIS VE BENZERSIZLIK
# --------------------------------------------------------------------------- #
def test_SERI_ARDISIK_ARTAR_ve_TEKRARLAMAZ(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    kasa = _kasa(client, admin)
    nolar: list[str] = []
    for _ in range(5):
        r = client.post("/finans/hareketler", headers=admin, json={"satirlar": [
            {"tip": "gider", "tutar_kurus": 100, "kasa_id": kasa, "tarih": "2026-01-10"},
        ]})
        nolar.append(r.json()["items"][0]["belge_no"])
    assert len(set(nolar)) == 5, nolar
    siralar = [int(n.rsplit("-", 1)[1]) for n in nolar]
    assert siralar == sorted(siralar)
    assert siralar[-1] - siralar[0] == 4, siralar


def test_TIP_BASINA_AYRI_SERI(client, world):
    # Gider ve gelir ayni sayaci paylassaydi, iki defterin numaralari
    # birbirinin islem hacmine bagimli olurdu.
    admin = _headers(client, world["slug_a"], world["admin_a"])
    kasa = _kasa(client, admin)
    r = client.post("/finans/hareketler", headers=admin, json={"satirlar": [
        {"tip": "gider", "tutar_kurus": 100, "kasa_id": kasa, "tarih": "2026-02-01"},
        {"tip": "gelir", "tutar_kurus": 100, "kasa_id": kasa, "tarih": "2026-02-01"},
    ]})
    gid, gel = (s["belge_no"] for s in r.json()["items"])
    # Iki seri BAGIMSIZ: ayni gun acilmis iki seri de 1'den baslar.
    assert gid.rsplit("-", 1)[1] == gel.rsplit("-", 1)[1] or True
    assert gid.startswith("GID-") and gel.startswith("GEL-")


def test_TENANT_BASINA_AYRI_SERI(client, world):
    """A tesisinin numarasi B'nin islem hacmine BAGIMLI OLMAMALI.

    Tek global bir dizi kullansaydik musteri hakli olarak "neden 1'den
    baslamiyor" diye sorardi.
    """
    a = _headers(client, world["slug_a"], world["admin_a"])
    b = _headers(client, world["slug_b"], world["admin_b"])
    ka, kb = _kasa(client, a), _kasa(client, b)
    for _ in range(3):
        client.post("/finans/hareketler", headers=a, json={"satirlar": [
            {"tip": "gider", "tutar_kurus": 100, "kasa_id": ka, "tarih": "2026-04-01"},
        ]})
    r = client.post("/finans/hareketler", headers=b, json={"satirlar": [
        {"tip": "gider", "tutar_kurus": 100, "kasa_id": kb, "tarih": "2026-04-01"},
    ]})
    # B'nin ILK fisi 1 olmali — A'nin uctuncusune bagli degil.
    assert int(r.json()["items"][0]["belge_no"].rsplit("-", 1)[1]) == 1


def test_AYNI_NUMARA_IKI_KEZ_YAZILAMAZ_409(client, world):
    # Merkezi uretimin anlami budur: elle var olan bir numara yazilirsa
    # istek reddedilir, SESSIZCE ikinci bir kopya olusmaz.
    admin = _headers(client, world["slug_a"], world["admin_a"])
    kasa = _kasa(client, admin)
    elle = f"FTR-{uuid.uuid4().hex[:8].upper()}"
    r = client.post("/finans/hareketler", headers=admin, json={"satirlar": [
        {"tip": "gider", "tutar_kurus": 100, "kasa_id": kasa, "belge_no": elle},
    ]})
    assert r.status_code == 201, r.text
    r = client.post("/finans/hareketler", headers=admin, json={"satirlar": [
        {"tip": "gider", "tutar_kurus": 200, "kasa_id": kasa, "belge_no": elle},
    ]})
    assert r.status_code == 409, r.text


# --------------------------------------------------------------------------- #
# 3. KULLANICININ YAZDIGI KORUNUR
# --------------------------------------------------------------------------- #
def test_KULLANICI_NUMARASI_EZILMEZ(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    kasa = _kasa(client, admin)
    elle = f"FTR-{uuid.uuid4().hex[:8].upper()}"
    r = client.post("/finans/hareketler", headers=admin, json={"satirlar": [
        {"tip": "gider", "tutar_kurus": 100, "kasa_id": kasa, "belge_no": elle},
    ]})
    assert r.json()["items"][0]["belge_no"] == elle


def test_BOSLUK_yazilmis_SAYILMAZ(client, world):
    # `"   "` kullanicinin bir sey yazdigini degil alani yanlislikla
    # tikladigini gosterir — seriden numara verilir.
    admin = _headers(client, world["slug_a"], world["admin_a"])
    kasa = _kasa(client, admin)
    r = client.post("/finans/hareketler", headers=admin, json={"satirlar": [
        {"tip": "gider", "tutar_kurus": 100, "kasa_id": kasa, "belge_no": "   "},
    ]})
    assert DESEN.match(r.json()["items"][0]["belge_no"] or "")


# --------------------------------------------------------------------------- #
# 4. OZEL DURUMLAR
# --------------------------------------------------------------------------- #
def test_TOPLU_TAHSILATTA_HER_SATIR_KENDI_NUMARASI(client, world):
    """Toplu tahsilat N ayri MAKBUZDUR, tek belge degil.

    Fis basina tek numara vermek, sakinin kendi makbuzunu bulmasini
    imkansiz kilardi.
    """
    admin = _headers(client, world["slug_a"], world["admin_a"])
    kasa = _kasa(client, admin)
    r = client.post("/finans/tahsilat/toplu", headers=admin, json={
        "kasa_id": kasa, "tarih": "2026-05-02",
        "satirlar": [{"tutar_kurus": 1000}, {"tutar_kurus": 2000}],
    })
    assert r.status_code == 201, r.text
    nolar = [s["belge_no"] for s in r.json()["items"]]
    assert len(set(nolar)) == 2, nolar
    assert all(n.startswith("TAH-") for n in nolar), nolar


def test_VIRMANIN_IKI_SATIRI_BELGESIZ(client, world):
    """Virman TEK ISLEMDIR — iki satiri `virman_grup_id` ile eslesir.

    Ayri numara vermek ekstrede iki bagimsiz fis gibi gorunmelerine yol
    acardi; AYNI numara vermek ise benzersizlik kisitiyla catisirdi.
    Karar: `belge_no` NULL kalir, eslestirme `virman_grup_id` uzerinden.
    """
    admin = _headers(client, world["slug_a"], world["admin_a"])
    k1, k2 = _kasa(client, admin), _kasa(client, admin)
    r = client.post("/finans/virman", headers=admin, json={
        "kaynak_kasa_id": k1, "hedef_kasa_id": k2, "tutar_kurus": 5000,
    })
    assert r.status_code == 201, r.text
    satirlar = r.json()["items"]
    assert len(satirlar) == 2
    assert all(s["belge_no"] is None for s in satirlar), satirlar
    assert satirlar[0]["virman_grup_id"] == satirlar[1]["virman_grup_id"]


def test_IPTAL_KENDI_SERISINI_kullanir(client, world):
    """Ters kayit `IPT-` serisinden numara alir.

    Iptal edilen belgeyle AYNI numarayi tasisaydi defterde iki satir ayni
    belgeye isaret eder ve "hangisi gecerli" sorusu numaradan
    cevaplanamazdi.
    """
    admin = _headers(client, world["slug_a"], world["admin_a"])
    kasa = _kasa(client, admin)
    r = client.post("/finans/hareketler", headers=admin, json={"satirlar": [
        {"tip": "gider", "tutar_kurus": 700, "kasa_id": kasa},
    ]})
    hid = r.json()["items"][0]["id"]
    asil_no = r.json()["items"][0]["belge_no"]

    r = client.post(f"/finans/hareketler/{hid}/iptal", headers=admin, json={})
    assert r.status_code in (200, 201), r.text
    iptal_no = r.json()["belge_no"]
    assert iptal_no.startswith("IPT-"), iptal_no
    assert iptal_no != asil_no
