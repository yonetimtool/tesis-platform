"""(P211 §3) TAHSILAT 500'LERI — GECERSIZ GIRDI ARTIK ANLASILIR 422.

=========================================================================
OLCULEN KUSUR
=========================================================================
`POST /dues/payments` iki ayri girdide 500 donuyordu; ikisi de is kurali
degil, DOGRULAMA BOSLUGUYDU ve hata surucude patliyordu:

  1. `tutar_kurus` int64'u asinca -> asyncpg `DataError: value out of
     int64 range`. (Kullanicinin tutar alanina fazladan hane yazmasi.)
  2. `odeme_zamani` yili belge serisi araliginin disinda kalinca ->
     `CheckViolationError: ck_belge_sayaci_yil` (goc 0058). (Tarih
     alanina 9999 yazmak, ya da yil hanesini kaydirmak.)

Ayrica iki mesaj YANLIS SEYI anlatiyordu:

  3. Var olmayan `kasa_id` -> FK ihlali "iliskili kayit nedeniyle islem
     yapilamiyor" (409) diye donuyordu.
  4. Ayni makbuz numarasi ikinci kez -> `uq_hareket_belge_no` ihlali
     "Ayni Idempotency-Key farkli govde ile gonderildi" diye donuyordu;
     kullanici anahtarini degistirse bile ayni cevabi alirdi.

Bu dosya dordunu de kilitler. Testler CANLI sunucuya gider (bu paketin
kurali): govde gercekten uca gonderilir, yanit kodu VE mesaji olculur.
"""
import uuid

from tests.test_dues import _headers, _new_unit

KURUS_UST_SINIR = 10**15


def _gonder(client, hdr, govde):
    return client.post(
        "/dues/payments",
        headers={**hdr, "Idempotency-Key": uuid.uuid4().hex},
        json=govde,
    )


def _taban(unit_id):
    return {"unit_id": unit_id, "tutar_kurus": 1000, "yontem": "elden"}


def test_tutar_int64_asamaz_422(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    u = _new_unit(client, admin)
    r = _gonder(client, admin, {**_taban(u["id"]), "tutar_kurus": 10**19})
    # 500 DEGIL: sinir semada, veritabanina hic inmiyor.
    assert r.status_code == 422, r.text
    assert r.json()["error"]["code"] == "validation_error"


def test_tutar_ust_sinir_KABUL_edilir(client, world):
    # Iki yon sart: yalniz reddi olcseydik, sinir 1'e cekilse de test gecerdi.
    admin = _headers(client, world["slug_a"], world["admin_a"])
    u = _new_unit(client, admin)
    r = _gonder(client, admin, {**_taban(u["id"]), "tutar_kurus": KURUS_UST_SINIR})
    assert r.status_code == 201, r.text
    r2 = _gonder(client, admin, {**_taban(u["id"]), "tutar_kurus": KURUS_UST_SINIR + 1})
    assert r2.status_code == 422, r2.text


def test_belge_yili_araligi_disi_422(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    u = _new_unit(client, admin)
    for zaman, yil in (("9999-12-31T23:59:59Z", "9999"), ("1899-01-01T00:00:00Z", "1899")):
        r = _gonder(client, admin, {**_taban(u["id"]), "odeme_zamani": zaman})
        assert r.status_code == 422, r.text
        # Mesaj SORUNU ANLATIR: hangi yil, hangi aralik.
        assert yil in r.json()["error"]["message"]


def test_gecerli_gecmis_tarih_KABUL_edilir(client, world):
    # Aralik daralmasin: 2019 tarihli bir makbuz girilebilmeli.
    admin = _headers(client, world["slug_a"], world["admin_a"])
    u = _new_unit(client, admin)
    r = _gonder(client, admin, {**_taban(u["id"]), "odeme_zamani": "2019-01-05T10:00:00Z"})
    assert r.status_code == 201, r.text


def test_olmayan_kasa_422_ve_KASAYI_soyler(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    u = _new_unit(client, admin)
    r = _gonder(client, admin, {**_taban(u["id"]), "kasa_id": str(uuid.uuid4())})
    assert r.status_code == 422, r.text
    assert r.json()["error"]["code"] == "invalid_reference"
    assert "Kasa" in r.json()["error"]["message"]


def test_ayni_makbuz_no_BELGE_hatasi_doner(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    u = _new_unit(client, admin)
    no = f"MKB-{uuid.uuid4().hex[:8]}"
    ilk = _gonder(client, admin, {**_taban(u["id"]), "makbuz_no": no})
    assert ilk.status_code == 201, ilk.text
    # ANAHTAR FARKLI: sorun idempotency degil, belge numarasi.
    ikinci = _gonder(client, admin, {**_taban(u["id"]), "makbuz_no": no})
    assert ikinci.status_code == 409, ikinci.text
    mesaj = ikinci.json()["error"]["message"]
    assert no in mesaj
    assert "Idempotency" not in mesaj


def test_idempotency_celiskisi_HALA_kendi_mesajini_verir(client, world):
    # Gerileme kapisi: belge dali eklenirken idempotency dali kaybolmamali.
    admin = _headers(client, world["slug_a"], world["admin_a"])
    u = _new_unit(client, admin)
    anahtar = uuid.uuid4().hex
    hdr = {**admin, "Idempotency-Key": anahtar}
    assert client.post("/dues/payments", headers=hdr, json=_taban(u["id"])).status_code == 201
    ikinci = client.post(
        "/dues/payments", headers=hdr, json={**_taban(u["id"]), "tutar_kurus": 2000}
    )
    assert ikinci.status_code == 409, ikinci.text
    assert "Idempotency" in ikinci.json()["error"]["message"]
