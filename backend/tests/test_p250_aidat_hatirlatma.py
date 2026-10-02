"""(P250 §7) OTOMATIK AIDAT HATIRLATMA E-POSTASI.

Olculen:
  * duz ayar ("X gun sonra, Y kez, Z gunde bir") -> kademeler,
  * e-posta YALNIZ borcluya ve KIM ODER kuralina gore (P218),
  * sablon: tutar, donem, odeme kodu, IBAN, nazik dil,
  * bildirim tercihi (e-postayi kapatan kisiye gitmez),
  * gecmis (yonetici paneli) teslim durumuyla.
"""
from __future__ import annotations

import uuid
from datetime import date, timedelta

import pytest

from .conftest import rastgele_iban


def _h(client, slug, cred):
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
    return _h(client, world["slug_a"], world["admin_a"])


@pytest.fixture
async def db_session(world):
    """Tenant-bagli async oturum (test_p192_otomasyon ile ayni gerekce)."""
    from sqlalchemy import text as _text
    from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
    from sqlalchemy.pool import NullPool

    from app.config import settings

    engine = create_async_engine(settings.database_url, poolclass=NullPool)
    async with engine.connect() as baglanti:
        await baglanti.execute(
            _text("SELECT set_config('app.current_tenant_id', :t, false)"),
            {"t": str(world["a"])},
        )
        await baglanti.commit()
        oturum = AsyncSession(bind=baglanti, expire_on_commit=False)
        try:
            yield oturum
        finally:
            await oturum.close()
    await engine.dispose()


def _sakin(client, adm, unit_id, rol_tipi, oturuyor, ad):
    eposta = f"p250a-{_sfx()}@ornek.com"
    r = client.post("/users", headers=adm, json={
        "ad": ad, "soyad": "test", "email": eposta, "role": "resident",
    })
    assert r.status_code == 201, r.text
    uid = r.json()["id"]
    r = client.post(f"/units/{unit_id}/residents", headers=adm, json={
        "user_id": uid, "rol_tipi": rol_tipi, "oturuyor": oturuyor,
    })
    assert r.status_code in (200, 201), r.text
    return uid


def test_duz_ayar_kademelere_cevrilir(client, adm):
    r = client.patch("/hatirlatma-ayari", headers=adm, json={
        "ilk_gun": 5, "tekrar_sayisi": 3, "aralik_gun": 7, "eposta": True,
    })
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["kademeler"] == [5, 12, 19]
    assert (d["ilk_gun"], d["tekrar_sayisi"], d["aralik_gun"]) == (5, 3, 7)
    assert d["eposta"] is True
    # Eksik uclu ve iki kaynak birden -> 422.
    assert client.patch("/hatirlatma-ayari", headers=adm,
                        json={"ilk_gun": 5}).status_code == 422
    assert client.patch("/hatirlatma-ayari", headers=adm, json={
        "ilk_gun": 5, "tekrar_sayisi": 2, "aralik_gun": 7, "kademeler": [1],
    }).status_code == 422


async def test_eposta_KIM_ODER_kuralina_gore_ve_sablon(client, adm, world, db_session, owner_conn):
    from app import otomasyon

    iban = rastgele_iban()
    client.post("/kasalar", headers=adm, json={
        "kod": f"0H{_sfx()}", "ad": "Banka", "banka_mi": True, "iban": iban,
        "banka_adi": "Ornek Bank",
    })
    daire = client.post("/units", headers=adm, json={"no": f"AH-{_sfx()}", "blok": "A"}).json()
    malik = _sakin(client, adm, daire["id"], "malik", False, "malik kisi")
    kiraci = _sakin(client, adm, daire["id"], "kiraci", True, "kiraci kisi")

    vade = date.today() - timedelta(days=3)
    # Tanimsiz (kuralsiz) daire borcu -> OTURAN ONCELIKLI -> kiraci.
    r = client.post("/dues/assessments", headers=adm, json={
        "unit_id": daire["id"], "donem": "2034-01", "tutar_kurus": 123450,
        "son_odeme_tarihi": vade.isoformat()})
    assert r.status_code in (200, 201), r.text

    client.patch("/hatirlatma-ayari", headers=adm, json={
        "aktif": True, "vade_oncesi_gun": 0, "kademeler": [3], "eposta": True})
    sonuc = await otomasyon.borc_hatirlatmalari(db_session, world["a"], date.today())
    await db_session.commit()
    assert sonuc["durum"] == "gonderildi", sonuc

    eposta = {
        r[0]: r[1:] for r in owner_conn.execute(
            "SELECT user_id::text, govde, govde_html, durum FROM mesaj_gonderim "
            "WHERE tur='aidat_hatirlatma' AND user_id IN (%s,%s)", (malik, kiraci),
        ).fetchall()
    }
    assert set(eposta) == {kiraci}, eposta  # malike GITMEDI
    govde, html, durum = eposta[kiraci]
    assert durum == "kuyrukta"
    for parca in ("1.234,50", "2034-01", iban, "Ödemenizi yaptıysanız"):
        assert parca in govde, parca
        assert parca in html, parca
    kod = owner_conn.execute(
        "SELECT odeme_kodu FROM app_user WHERE id=%s", (kiraci,)).fetchone()[0]
    assert kod and kod in govde
    # Push/uygulama ici bildirim de yalniz kiraciya.
    alicilar = {
        r[0] for r in owner_conn.execute(
            "SELECT user_id::text FROM notification WHERE tip='aidat_hatirlatma' "
            "AND user_id IN (%s,%s)", (malik, kiraci)).fetchall()
    }
    assert alicilar == {kiraci}

    # Yonetici paneli: e-posta gecmisi teslim durumuyla.
    g = client.get("/finans/hatirlatma-epostalari", headers=adm).json()
    satir = next(i for i in g["items"] if i["user_id"] == kiraci)
    assert satir["durum"] == "kuyrukta"


async def test_MALIK_kurali_ve_eposta_tercihi(client, adm, world, db_session, owner_conn):
    from app import otomasyon

    tanim = client.post("/gelir-gider-tanimlari", headers=adm, json={
        "ad": f"Onarim-{_sfx()}", "tip": "gider", "hedef_kurali": "malik"}).json()
    daire = client.post("/units", headers=adm, json={"no": f"AM-{_sfx()}", "blok": "A"}).json()
    malik = _sakin(client, adm, daire["id"], "malik", False, "malik iki")
    kiraci = _sakin(client, adm, daire["id"], "kiraci", True, "kiraci iki")
    owner_conn.execute("UPDATE app_user SET bildirim_eposta=false WHERE id=%s", (malik,))

    vade = date.today() - timedelta(days=3)
    owner_conn.execute(
        "INSERT INTO dues_assessment (tenant_id, unit_id, donem, tutar_kurus, "
        "son_odeme_tarihi, gelir_gider_tanim_id) VALUES (%s,%s,'2034-02',5000,%s,%s)",
        (world["a"], daire["id"], vade, tanim["id"]),
    )
    client.patch("/hatirlatma-ayari", headers=adm, json={
        "aktif": True, "vade_oncesi_gun": 0, "kademeler": [3], "eposta": True})
    await otomasyon.borc_hatirlatmalari(db_session, world["a"], date.today())
    await db_session.commit()

    bildirim = {
        r[0] for r in owner_conn.execute(
            "SELECT user_id::text FROM notification WHERE tip='aidat_hatirlatma' "
            "AND user_id IN (%s,%s)", (malik, kiraci)).fetchall()
    }
    assert bildirim == {malik}  # malik kurali
    # Malik e-postayi KAPATTI: bildirim gider, e-posta GITMEZ.
    assert owner_conn.execute(
        "SELECT count(*) FROM mesaj_gonderim WHERE tur='aidat_hatirlatma' AND user_id=%s",
        (malik,)).fetchone()[0] == 0


async def test_eposta_kapaliyken_yalniz_bildirim(client, adm, world, db_session, owner_conn):
    from app import otomasyon

    daire = client.post("/units", headers=adm, json={"no": f"AK-{_sfx()}", "blok": "A"}).json()
    kiraci = _sakin(client, adm, daire["id"], "kiraci", True, "kiraci uc")
    vade = date.today() - timedelta(days=3)
    client.post("/dues/assessments", headers=adm, json={
        "unit_id": daire["id"], "donem": "2034-03", "tutar_kurus": 1000,
        "son_odeme_tarihi": vade.isoformat()})
    client.patch("/hatirlatma-ayari", headers=adm, json={
        "aktif": True, "vade_oncesi_gun": 0, "kademeler": [3], "eposta": False})
    await otomasyon.borc_hatirlatmalari(db_session, world["a"], date.today())
    await db_session.commit()
    assert owner_conn.execute(
        "SELECT count(*) FROM mesaj_gonderim WHERE tur='aidat_hatirlatma' AND user_id=%s",
        (kiraci,)).fetchone()[0] == 0
    assert owner_conn.execute(
        "SELECT count(*) FROM notification WHERE tip='aidat_hatirlatma' AND user_id=%s",
        (kiraci,)).fetchone()[0] == 1
