"""AKIS SAYFALAMASI — ESIT ZAMANLI olaylarda satir kaybi var mi? (tur 77)

Tur 77'de `GET /activity`in siralama+LIMIT'i her `UNION ALL` DALINA itildi
(onceden yalniz dis sorguda oldugu icin Postgres 13 kaynagin TAMAMINI
materyalize ediyordu: olcum veritabaninda tek istek 350 BIN satir okuyordu).

Itmenin DOGRULUK argumani sudur: `(zaman, id) DESC` siralamasinda global ilk
N satirin her biri, KENDI dalinin ayni siralamadaki ilk N'i icinde olmak
zorundadir. Bu argumanin KIRILDIGI tek yer ESIT `zaman` degerleridir — orada
sira tamamen `id` tie-break'ine kalir ve dal ile dis sorgu AYNI anahtari
kullanmazsa satir kaybolur ya da tekrarlanir.

Bu dosya tam olarak o durumu kurar: IKI AYRI KAYNAKTA (devriye okutma +
bildirim) AYNI mikrosaniyeye dusen olaylar yaratir ve imlecle sayfa sayfa
gezip her olayin TAM BIR KEZ gorundugunu dogrular.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

import pytest

#: Kaynak basina esit zamanli olay sayisi. Dal basina LIMIT (SAYFA+1) ile
#: karsilastirildiginda COK BUYUK olmali. Ilk halinde ADET=5 idi ve dedektor
#: KOR cikti: dal 5 esitten keyfi 3'unu dondurse bile tesadufen dogru sirayla
#: cakisiyordu (tur 77 dedektor sinamasi). 40'a cikarilinca dal-ici keyfi secim
#: neredeyse kesin YANLIS siralama uretir ve testler kirmiziya doner.
ADET = 40
SAYFA = 2


@pytest.fixture
def esit_zamanli(owner_conn, world):
    """Iki kaynakta AYNI zaman damgasina sahip olaylar."""
    tid = world["a"]
    zaman = datetime.now(timezone.utc) - timedelta(minutes=3)
    beklenen: set[str] = set()
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO checkpoint (tenant_id, ad, nfc_tag_uid) "
            "VALUES (%s,%s,%s) RETURNING id",
            (tid, "CP-esit", f"TAG-{uuid.uuid4().hex[:10]}"),
        )
        cp = cur.fetchone()[0]
        cur.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND role='security'::user_role "
            "LIMIT 1",
            (tid,),
        )
        guard = cur.fetchone()[0]
        for i in range(ADET):
            cur.execute(
                "INSERT INTO scan_event (tenant_id, guard_id, checkpoint_id, "
                "nfc_tag_uid, okutma_zamani, idempotency_key) "
                "VALUES (%s,%s,%s,%s,%s,%s) RETURNING id",
                (tid, guard, cp, "TAGX", zaman, f"esit-{uuid.uuid4().hex}"),
            )
            beklenen.add(f"devriye_okutma:{cur.fetchone()[0]}")
            cur.execute(
                "INSERT INTO notification (tenant_id, tip, mesaj, created_at) "
                "VALUES (%s,'kacirilan_tur'::notification_tip,%s,%s) RETURNING id",
                (tid, f"esit {i}", zaman),
            )
            beklenen.add(f"alarm:{cur.fetchone()[0]}")
    return beklenen


def _giris(client, world):
    r = client.post(
        "/auth/login",
        json={
            "tenant_slug": world["slug_a"],
            "email": world["admin_a"]["email"],
            "password": world["admin_a"]["password"],
        },
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_esit_zamanli_olaylar_sayfalamada_kaybolmuyor(client, world, esit_zamanli):
    basliklar = _giris(client, world)
    gorulen: list[str] = []
    cursor = None
    # Guvenlik siniri: ADET*2 olay + world'un diger kayitlari; 40 sayfa fazlasiyla
    # yeter. Sinirsiz dongu, imlec ilerlemezse testi ASKIDA BIRAKIRDI.
    for _ in range(40):
        yol = f"/activity?limit={SAYFA}" + (f"&cursor={cursor}" if cursor else "")
        r = client.get(yol, headers=basliklar)
        assert r.status_code == 200, r.text
        govde = r.json()
        gorulen.extend(x["id"] for x in govde["items"])
        cursor = govde["meta"].get("next_cursor")
        if not cursor:
            break
        if esit_zamanli <= set(gorulen):
            break

    eksik = esit_zamanli - set(gorulen)
    assert not eksik, (
        f"{len(eksik)} esit zamanli olay sayfalamada KAYBOLDU: {sorted(eksik)[:5]}"
    )
    tekrar = [x for x in set(gorulen) if gorulen.count(x) > 1]
    assert not tekrar, f"sayfalamada TEKRARLANAN olay: {tekrar[:5]}"


def test_sayfalama_siralamasi_azalan(client, world, esit_zamanli):
    """Sayfalar arasi siralama monoton azalan olmali (zaman, id)."""
    basliklar = _giris(client, world)
    anahtarlar: list[tuple[str, str]] = []
    cursor = None
    for _ in range(20):
        yol = f"/activity?limit={SAYFA}" + (f"&cursor={cursor}" if cursor else "")
        govde = client.get(yol, headers=basliklar).json()
        anahtarlar.extend((x["zaman"], x["id"]) for x in govde["items"])
        cursor = govde["meta"].get("next_cursor")
        if not cursor:
            break
    assert anahtarlar == sorted(anahtarlar, reverse=True), (
        "akis (zaman, id) azalan sirada DEGIL — imlec/dal siralamasi tutarsiz"
    )
