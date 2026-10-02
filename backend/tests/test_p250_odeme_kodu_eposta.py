"""(P250 §2) ODEME KODLARI: liste sirasi, e-posta (tek/toplu), sablon, teslim durumu.

Gercek akis canli API'de surulur. Tasiyici: `konsol_eposta` (tesise calisan
bir e-posta saglayicisi verir; gonderim "gonderildi" olur). Toplu gonderim
kuyruga yazilir; kuyruk burada beat'i beklemeden AYNI kodla islenir
(`mesaj_kuyruk.kuyrugu_isle`).
"""
from __future__ import annotations

import uuid

from .conftest import rastgele_iban


def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _sakin(client, h, ad="ali", soyad="veli") -> tuple[str, str]:
    eposta = f"p250k-{uuid.uuid4().hex[:10]}@ornek.com"
    r = client.post("/residents", headers=h, json={
        "ad": ad, "soyad": soyad, "email": eposta, "blok": "A",
        "unit_no": f"K{uuid.uuid4().hex[:5]}",
        "telefon": f"+9053{uuid.uuid4().int % 100000000:08d}",
    })
    assert r.status_code == 201, r.text
    return r.json()["user_id"], eposta


def _iban(client, h) -> str:
    iban = rastgele_iban()
    r = client.post("/kasalar", headers=h, json={
        "kod": f"0P{uuid.uuid4().hex[:5]}", "ad": "Ana Banka", "banka_mi": True,
        "iban": iban, "banka_adi": "Ornek Bank",
    })
    assert r.status_code == 201, r.text
    return iban


def _liste(client, h):
    r = client.post("/users/odeme-kodlari", headers=h)
    assert r.status_code == 200, r.text
    return r.json()["items"]


def _kuyrugu_isle(tenant_id):
    """Beat'in yaptigini simdi yap (ayni kod yolu)."""
    from sqlalchemy import text

    from app.db import SessionLocal
    from app.mesaj_kuyruk import kuyrugu_isle
    from app.tasks import _async_calistir

    async def _calis():
        async with SessionLocal() as db:
            await db.execute(
                text("SELECT set_config('app.current_tenant_id', :t, true)"),
                {"t": str(tenant_id)},
            )
            n = await kuyrugu_isle(db)
            await db.commit()
            return n

    return _async_calistir(_calis)


def test_yeni_eklenen_EN_USTTE(client, world):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    uid, _ = _sakin(client, h)
    items = _liste(client, h)
    assert items[0]["user_id"] == uid, items[:2]
    assert items[0]["ad"] == "Ali VELİ"
    assert items[0]["eposta_durumu"] is None


def test_tek_kisi_HEMEN_gider_sablon_ve_durum(client, world, konsol_eposta, owner_conn):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    iban = _iban(client, h)
    uid, eposta = _sakin(client, h, "ışıl", "öztürk")
    r = client.post("/users/odeme-kodlari/eposta", headers=h, json={"user_ids": [uid]})
    assert r.status_code == 200, r.text
    assert r.json() == {"gonderilen": 1, "kuyruga_alinan": 0, "atlananlar": []}

    satir = next(i for i in _liste(client, h) if i["user_id"] == uid)
    assert satir["eposta_durumu"] == "gonderildi", satir
    kod = satir["odeme_kodu"]

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT hedef, konu, govde, govde_html, tur, durum FROM mesaj_gonderim "
            "WHERE user_id=%s AND tur='odeme_kodu'",
            (uid,),
        )
        hedef, konu, govde, html, tur, durum = cur.fetchone()
    assert hedef == eposta and tur == "odeme_kodu" and durum == "gonderildi"
    # Sablon icerigi: ad, daire, kod, IBAN, havale aciklamasi, logo.
    for parca in ("Işıl ÖZTÜRK", kod, iban, "Açıklama alanına"):
        assert parca in govde, parca
        assert parca in html, parca
    assert "yonetio-marka-acik.png" in html
    assert "Ödeme kodunuz" in html
    assert konu.endswith("ödeme kodunuz")


def test_ayni_kisiye_kisa_surede_TEKRAR_GITMEZ(client, world, konsol_eposta):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    _iban(client, h)
    uid, _ = _sakin(client, h)
    assert client.post("/users/odeme-kodlari/eposta", headers=h,
                       json={"user_ids": [uid]}).json()["gonderilen"] == 1
    r = client.post("/users/odeme-kodlari/eposta", headers=h, json={"user_ids": [uid]})
    assert r.status_code == 200, r.text
    assert r.json()["gonderilen"] == 0
    assert r.json()["atlananlar"] == [{"user_id": uid, "sebep": "yakin_zamanda"}]


def test_TOPLU_kuyruga_yazilir_sonra_gider(client, world, konsol_eposta, owner_conn):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    _iban(client, h)
    a, _ = _sakin(client, h)
    b, _ = _sakin(client, h)
    r = client.post("/users/odeme-kodlari/eposta", headers=h, json={"user_ids": [a, b]})
    assert r.status_code == 200, r.text
    assert r.json()["kuyruga_alinan"] == 2 and r.json()["gonderilen"] == 0
    durumlar = {i["user_id"]: i["eposta_durumu"] for i in _liste(client, h)}
    # Beat bu arada islemis olabilir; ikisinden biri olmali.
    assert durumlar[a] in ("kuyrukta", "gonderildi")
    _kuyrugu_isle(world["a"])
    durumlar = {i["user_id"]: i["eposta_durumu"] for i in _liste(client, h)}
    assert durumlar[a] == "gonderildi" and durumlar[b] == "gonderildi", durumlar
    # Yeniden denemede de HTML gider (kuyruk satirinda saklandi).
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM mesaj_gonderim WHERE user_id IN (%s,%s) "
            "AND tur='odeme_kodu' AND govde_html IS NOT NULL",
            (a, b),
        )
        assert cur.fetchone()[0] == 2


def test_GERI_DONDU_listede_gorunur(client, world, konsol_eposta, owner_conn):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    _iban(client, h)
    uid, _ = _sakin(client, h)
    client.post("/users/odeme-kodlari/eposta", headers=h, json={"user_ids": [uid]})
    # P234 webhook'unun bounce'ta yazdigi deger.
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE mesaj_gonderim SET durum='basarisiz', hata='bounce' "
            "WHERE user_id=%s AND tur='odeme_kodu'",
            (uid,),
        )
    satir = next(i for i in _liste(client, h) if i["user_id"] == uid)
    assert satir["eposta_durumu"] == "geri_dondu"
    # Geri donen gonderim tekrar korumasina TAKILMAZ (adres duzeltilip
    # yeniden gonderilebilmeli).
    r = client.post("/users/odeme-kodlari/eposta", headers=h, json={"user_ids": [uid]})
    assert r.json()["gonderilen"] == 1, r.text


def test_eposta_kapali_kisi_ATLANIR(client, world, konsol_eposta, owner_conn):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    _iban(client, h)
    uid, _ = _sakin(client, h)
    with owner_conn.cursor() as cur:
        cur.execute("UPDATE app_user SET bildirim_eposta=false WHERE id=%s", (uid,))
    satir = next(i for i in _liste(client, h) if i["user_id"] == uid)
    assert satir["eposta_engeli"] == "eposta_kapali"
    r = client.post("/users/odeme-kodlari/eposta", headers=h, json={"user_ids": [uid]})
    assert r.json()["atlananlar"] == [{"user_id": uid, "sebep": "eposta_kapali"}]


def test_IBAN_YOKSA_422(client, world):
    h = _h(client, world["slug_b"], world["yonetici_b"])
    r = client.post("/users/odeme-kodlari/eposta", headers=h,
                    json={"user_ids": [str(uuid.uuid4())]})
    assert r.status_code == 422, r.text
    assert "IBAN" in r.json()["error"]["message"]


def test_sakin_ve_guvenlik_GONDEREMEZ(client, world):
    for cred in ("resident_a", "guard_a"):
        h = _h(client, world["slug_a"], world[cred])
        r = client.post("/users/odeme-kodlari/eposta", headers=h,
                        json={"user_ids": [str(uuid.uuid4())]})
        assert r.status_code == 403, (cred, r.text)
