"""(P167 Asama 3) "Kayitsiz blok" kusuru — daire var, blogun kaydi YOK.

===========================================================================
NE OLCULUYOR
===========================================================================
Bildirilen kusur: web'den toplu olusturulan daireler editorde "kayitsiz
(yalnizca dairede)" ibaresiyle geliyor, DUZENLENEMIYOR ve SILINEMIYOR.
Mobilden ayni islem duzgun calisiyor.

Kok neden istemcide DEGILDI: iki istemci ayni ucu ayni govdeyle cagiriyor.
Fark ONCESINDE — mobil diyalogu bir blogun ICINDEN aciyor (blok kaydi
zaten var), web ise blok adini serbest metin yazdirip dogrudan
`/units/bulk`a gonderiyordu.

Bu yuzden test ISTEMCIYI degil UCU olcuyor: "kaydi olmayan bir blok adiyla
daire olusturulursa blogun kaydi da acilir mi?" Web'i mobile benzeten bir
test, ayni delige dusecek OTEKI yollari (ice aktarim, dogrudan API)
gormezdi.

EN PAHALI SONUC SESSIZLIK: istek 201 doner, daireler gorunur, her sey
"calisiyor" gibidir. Kusur ancak editor acilip blok kutucugunda Duzenle
dugmesi aranana kadar fark edilmez.
"""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _blok_adlari(client, headers) -> set[str]:
    r = client.get("/blocks", headers=headers)
    assert r.status_code == 200, r.text
    return {b["ad"] for b in r.json()["items"]}


def test_TOPLU_olusturma_kaydi_olmayan_blogu_ACAR(client, world):
    """Asil kusur. Blok kaydi ONCEDEN YOK; toplu olusturma onu acmali."""
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    etiket = f"Z{uuid.uuid4().hex[:4].upper()}"
    assert etiket not in _blok_adlari(client, y)

    r = client.post("/units/bulk", headers=y, json={
        "blok": etiket, "kat_sayisi": 2, "kat_basi_daire": 2, "baslangic_no": 1,
    })
    assert r.status_code == 201, r.text
    assert len(r.json()["olusturulan"]) == 4

    # BLOGUN KAYDI ACILDI — editor artik Duzenle/Sil cizebilir.
    assert etiket in _blok_adlari(client, y)


def test_TEKIL_olusturma_da_blogu_ACAR(client, world):
    # Ayni delik tekil `POST /units`te de vardi; kural UCTA oldugu icin
    # ikisi de kapandi.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    etiket = f"T{uuid.uuid4().hex[:4].upper()}"
    r = client.post("/units", headers=y, json={
        "no": f"{etiket}-1", "blok": etiket, "kat": 1,
    })
    assert r.status_code == 201, r.text
    assert etiket in _blok_adlari(client, y)


def test_ACILAN_BLOK_YONETILEBILIR(client, world):
    """Kusurun ASIL bedeli: kayit yoksa blok duzenlenemez/silinemez.

    Editor `block.id` olmadan dugme cizemiyordu; testin olctugu sey de
    tam olarak o kimligin ISE YARADIGI.
    """
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    etiket = f"Y{uuid.uuid4().hex[:4].upper()}"
    client.post("/units/bulk", headers=y, json={
        "blok": etiket, "kat_sayisi": 1, "kat_basi_daire": 1, "baslangic_no": 1,
    })
    blok = next(b for b in client.get("/blocks", headers=y).json()["items"]
                if b["ad"] == etiket)

    # DUZENLENEBILIR (gercek rename: daireler de tasinir — P162 kurali).
    yeni = f"{etiket}X"
    r = client.patch(f"/blocks/{blok['id']}", headers=y, json={"ad": yeni})
    assert r.status_code == 200, r.text
    assert yeni in _blok_adlari(client, y)

    # SILINEBILIR (daireleriyle birlikte).
    r = client.delete(f"/blocks/{blok['id']}?cascade=true", headers=y)
    assert r.status_code == 204, r.text
    assert yeni not in _blok_adlari(client, y)


def test_MEVCUT_BLOK_ikinci_kez_ACILMAZ(client, world):
    # Uc idempotent olmali: ayni bloga ikinci parti eklemek yeni bir blok
    # kaydi (ya da 409) uretmemeli.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    etiket = f"M{uuid.uuid4().hex[:4].upper()}"
    for baslangic in (1, 100):
        r = client.post("/units/bulk", headers=y, json={
            "blok": etiket, "kat_sayisi": 1, "kat_basi_daire": 1,
            "baslangic_no": baslangic,
        })
        assert r.status_code == 201, r.text
    adlar = [b["ad"] for b in client.get("/blocks", headers=y).json()["items"]]
    assert adlar.count(etiket) == 1


def test_ACILAN_BLOK_DIGER_TESISTE_GORUNMEZ(client, world):
    # Otomatik acilan kaydin `tenant_id`si TOKEN'dan geliyor; bir yetki
    # genisletmesinde en pahali sessiz hata kapsamin da genislemesidir.
    a = _headers(client, world["slug_a"], world["yonetici_a"])
    b = _headers(client, world["slug_b"], world["yonetici_b"])
    etiket = f"K{uuid.uuid4().hex[:4].upper()}"
    client.post("/units/bulk", headers=a, json={
        "blok": etiket, "kat_sayisi": 1, "kat_basi_daire": 1, "baslangic_no": 1,
    })
    assert etiket in _blok_adlari(client, a)
    assert etiket not in _blok_adlari(client, b)


def test_ONARIM_GOCU_UYGULANDI_kayitsiz_blok_KALMADI(client, world, owner_conn):
    """(Goc 0057) Gecmiste olusmus kayitsiz bloklar onarildi mi?

    Goc, `unit.blok`ta gecip `building_block`ta karsiligi olmayan her
    (tenant, etiket) cifti icin satir ekliyordu. Bu test onun SONUCUNU
    olcuyor: veritabaninda oyle bir cift KALMAMALI.

    OLCUM TUM TENANT'LAR UZERINDE (owner baglantisi, RLS bypass): goc bir
    veri onarimidir ve tek bir tesisi degil tabloyu duzeltir.
    """
    with owner_conn.cursor() as cur:
        cur.execute(
            """
            SELECT u.tenant_id, btrim(u.blok)
              FROM unit u
             WHERE u.blok IS NOT NULL
               AND btrim(u.blok) <> ''
               AND NOT EXISTS (
                     SELECT 1 FROM building_block b
                      WHERE b.tenant_id = u.tenant_id
                        AND b.ad = btrim(u.blok)
                   )
             LIMIT 5
            """
        )
        kalan = cur.fetchall()
    assert kalan == [], f"onarilmamis kayitsiz blok: {kalan}"
