"""(P160) UZAK OKUTMA ALARMI — okutma noktadan esikten uzakta yapildi.

Bu dosyanin en onemli testleri ALARM URETILMEYEN durumlar: bir alarm
birinin telefonunu caldirir ve haritada renk degistirmekten cok daha agir
bir iddiadir. Yanlis alarm, dogru alarmin degerini de dusurur.

URETILMEYEN UC DURUM (hepsi bilincli):
  1. konum yoksa      -> karsilastirilacak sey yok,
  2. noktanin koordinati yoksa -> "uzak" demek icin REFERANS yok,
  3. olcum belirsizse (dogruluk > esik) -> kiyas karar veremez.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

UTC = timezone.utc
ANIN = datetime(2029, 6, 1, 12, 0, tzinfo=UTC)

# Nokta konumu ve ondan ~111 m kuzeydeki bir okutma (0.001 derece enlem).
NOKTA_LAT, NOKTA_LON = 41.000000, 29.000000
UZAK_LAT = 41.001000  # ~111 m
YAKIN_LAT = 41.000090  # ~10 m


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _checkpoint(client, headers, *, konumlu=True) -> dict:
    nfc = f"NFC-{uuid.uuid4().hex[:10]}"
    govde = {"ad": f"CP-{nfc[-4:]}", "nfc_tag_uid": nfc}
    if konumlu:
        govde["gps_lat"] = NOKTA_LAT
        govde["gps_lng"] = NOKTA_LON
    r = client.post("/checkpoints", headers=headers, json=govde)
    assert r.status_code == 201, r.text
    return r.json()


def _okut(client, headers, nfc, **extra) -> dict:
    """Okutmayi GUVENLIK yapar — `_SCANNER` yoneticiyi kapsamaz."""
    govde = {"nfc_tag_uid": nfc, "okutma_zamani": ANIN.isoformat()}
    govde.update(extra)
    r = client.post(
        "/scans",
        headers={**headers, "Idempotency-Key": uuid.uuid4().hex},
        json=govde,
    )
    assert r.status_code == 201, r.text
    return r.json()


def _alarmlar(owner_conn, tenant_id) -> list[tuple]:
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT mesaj_veri, checkpoint_id FROM notification "
            "WHERE tenant_id = %s AND tip = 'uzak_okutma'",
            (tenant_id,),
        )
        return cur.fetchall()


def _esik_yaz(client, headers, deger: int) -> None:
    r = client.patch(
        "/tenant/settings", json={"okutma_mesafe_esigi_m": deger}, headers=headers
    )
    assert r.status_code == 200, r.text


# --------------------------- ALARM URETILIR -------------------------------- #
def test_esik_disinda_okutma_alarm_uretir(client, world, owner_conn):
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    g = _headers(client, world["slug_a"], world["guard_a"])
    _esik_yaz(client, h, 50)
    cp = _checkpoint(client, h)

    onceki = len(_alarmlar(owner_conn, world["a"]))
    _okut(
        client, g, cp["nfc_tag_uid"],
        gps_lat=UZAK_LAT, gps_lng=NOKTA_LON, konum_durumu="var", gps_dogruluk_m=5,
    )
    simdi = _alarmlar(owner_conn, world["a"])
    assert len(simdi) == onceki + 1, "esik disi okutma alarm uretmeliydi"

    veri = simdi[-1][0]
    # METIN KAYDA DONMEZ, KIMLIK + VERI durur (tur 16).
    assert veri["esik"] == 50
    assert veri["mesafe"] > 50, veri
    assert veri["nokta"] == cp["ad"]


def test_alarm_NOKTAYA_baglanir(client, world, owner_conn):
    """Alarm hangi noktaya ait — yonetici oraya gidebilmeli."""
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    g = _headers(client, world["slug_a"], world["guard_a"])
    _esik_yaz(client, h, 50)
    cp = _checkpoint(client, h)
    _okut(
        client, g, cp["nfc_tag_uid"],
        gps_lat=UZAK_LAT, gps_lng=NOKTA_LON, konum_durumu="var", gps_dogruluk_m=5,
    )
    satirlar = _alarmlar(owner_conn, world["a"])
    assert str(satirlar[-1][1]) == cp["id"]


def test_ESIK_AYARDAN_okunur(client, world, owner_conn):
    """Ayni okutma, GENIS esikte alarm URETMEZ — esik gercekten okunuyor."""
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    g = _headers(client, world["slug_a"], world["guard_a"])
    _esik_yaz(client, h, 500)  # ~111 m artik esik ICINDE
    cp = _checkpoint(client, h)

    onceki = len(_alarmlar(owner_conn, world["a"]))
    _okut(
        client, g, cp["nfc_tag_uid"],
        gps_lat=UZAK_LAT, gps_lng=NOKTA_LON, konum_durumu="var", gps_dogruluk_m=5,
    )
    assert len(_alarmlar(owner_conn, world["a"])) == onceki


# ------------------------- ALARM URETILMEZ --------------------------------- #
def test_esik_icinde_okutma_alarm_URETMEZ(client, world, owner_conn):
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    g = _headers(client, world["slug_a"], world["guard_a"])
    _esik_yaz(client, h, 50)
    cp = _checkpoint(client, h)

    onceki = len(_alarmlar(owner_conn, world["a"]))
    _okut(
        client, g, cp["nfc_tag_uid"],
        gps_lat=YAKIN_LAT, gps_lng=NOKTA_LON, konum_durumu="var", gps_dogruluk_m=5,
    )
    assert len(_alarmlar(owner_conn, world["a"])) == onceki


def test_KONUMSUZ_okutma_alarm_URETMEZ(client, world, owner_conn):
    """Konum yoksa karsilastirilacak bir sey de yok (P34 ayri konu)."""
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    g = _headers(client, world["slug_a"], world["guard_a"])
    _esik_yaz(client, h, 50)
    cp = _checkpoint(client, h)

    onceki = len(_alarmlar(owner_conn, world["a"]))
    _okut(client, g, cp["nfc_tag_uid"], konum_durumu="izin_yok")
    assert len(_alarmlar(owner_conn, world["a"])) == onceki


def test_NOKTA_KOORDINATSIZSA_alarm_URETMEZ(client, world, owner_conn):
    """Referans yoksa "uzak" denemez — olmayan referansa gore olcmek uydurmakti."""
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    g = _headers(client, world["slug_a"], world["guard_a"])
    _esik_yaz(client, h, 50)
    cp = _checkpoint(client, h, konumlu=False)

    onceki = len(_alarmlar(owner_conn, world["a"]))
    _okut(
        client, g, cp["nfc_tag_uid"],
        gps_lat=UZAK_LAT, gps_lng=NOKTA_LON, konum_durumu="var", gps_dogruluk_m=5,
    )
    assert len(_alarmlar(owner_conn, world["a"])) == onceki


def test_OLCUM_BELIRSIZSE_alarm_URETMEZ(client, world, owner_conn):
    """EN ONEMLI KURAL.

    ±500 m hatayla olculmus bir mesafenin 50 m esigini gecip gecmedigi
    BILINEMEZ. Alarm uretmek, olcum hatasini ihlal diye raporlamak ve
    birinin telefonunu caldirmakti.
    """
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    g = _headers(client, world["slug_a"], world["guard_a"])
    _esik_yaz(client, h, 50)
    cp = _checkpoint(client, h)

    onceki = len(_alarmlar(owner_conn, world["a"]))
    _okut(
        client, g, cp["nfc_tag_uid"],
        gps_lat=UZAK_LAT, gps_lng=NOKTA_LON, konum_durumu="var", gps_dogruluk_m=500,
    )
    assert len(_alarmlar(owner_conn, world["a"])) == onceki


# ------------------------------ tekrar ------------------------------------- #
def test_AYNI_OKUTMA_iki_alarm_uretmez(client, world, owner_conn):
    """Idempotent tekrar gonderim ikinci alarmi YAZMAZ.

    Bir okutma TEK bir olaydir; `gecikmis_okutma` tekrar eder cunku orada
    olculen SUREN bir eksikliktir.
    """
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    g = _headers(client, world["slug_a"], world["guard_a"])
    _esik_yaz(client, h, 50)
    cp = _checkpoint(client, h)

    anahtar = uuid.uuid4().hex
    govde = {
        "nfc_tag_uid": cp["nfc_tag_uid"],
        "okutma_zamani": ANIN.isoformat(),
        "gps_lat": UZAK_LAT,
        "gps_lng": NOKTA_LON,
        "konum_durumu": "var",
        "gps_dogruluk_m": 5,
    }
    onceki = len(_alarmlar(owner_conn, world["a"]))
    r1 = client.post("/scans", headers={**g, "Idempotency-Key": anahtar}, json=govde)
    assert r1.status_code == 201, r1.text
    r2 = client.post("/scans", headers={**g, "Idempotency-Key": anahtar}, json=govde)
    assert r2.status_code == 200, r2.text  # idempotent tekrar

    assert len(_alarmlar(owner_conn, world["a"])) == onceki + 1


# ---------------------------- izolasyon ------------------------------------ #
def test_alarm_TENANT_IZOLE(client, world, owner_conn):
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    g = _headers(client, world["slug_a"], world["guard_a"])
    _esik_yaz(client, h, 50)
    cp = _checkpoint(client, h)

    b_onceki = len(_alarmlar(owner_conn, world["b"]))
    _okut(
        client, g, cp["nfc_tag_uid"],
        gps_lat=UZAK_LAT, gps_lng=NOKTA_LON, konum_durumu="var", gps_dogruluk_m=5,
    )
    assert len(_alarmlar(owner_conn, world["b"])) == b_onceki, "B tesisine alarm sizdi"
