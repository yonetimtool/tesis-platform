"""(P250 §9) OTOMASYON KURALLARI — onizleme ve son calisma.

Olculen:
  * plan onizlemesi KAYDETMEDEN "N daireye X TL" der, elle toplu
    borclandirma onizlemesiyle AYNI sayiyi verir, HICBIR SEY yazmaz,
  * hatirlatma onizlemesi gonderimin ta kendisiyle ayni kisi sayisini
    verir (ayni hedef hesabi),
  * her kuralin (plan, duzenli gider, hatirlatma) son calismasi ve
    sonucu kural basina doner,
  * sakin bu uclara giremez.
"""
from __future__ import annotations

import uuid
from datetime import date, timedelta

import pytest


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


@pytest.fixture
def tanim(client, adm):
    r = client.post("/gelir-gider-tanimlari", headers=adm, json={
        "ad": f"Aidat-{_sfx()}", "tip": "gider"})
    assert r.status_code == 201, r.text
    return r.json()


def test_plan_onizleme_yazmadan_toplu_onizlemeyle_ayni(client, adm, tanim, owner_conn, world):
    client.post("/units", headers=adm, json={"no": f"KO-{_sfx()}", "blok": "A"})
    once = owner_conn.execute(
        "SELECT count(*) FROM dues_assessment WHERE tenant_id=%s", (world["a"],)
    ).fetchone()[0]
    plan_sayisi = owner_conn.execute(
        "SELECT count(*) FROM aidat_plani WHERE tenant_id=%s", (world["a"],)
    ).fetchone()[0]

    r = client.post("/aidat-planlari/onizleme", headers=adm, json={
        "ad": "Aylik aidat", "gelir_gider_tanim_id": tanim["id"],
        "tutar_kurus": 120000, "tahakkuk_gunu": 1, "vade_gun": 10})
    assert r.status_code == 200, r.text
    o = r.json()
    assert o["adet"] >= 1
    assert o["toplam_kurus"] == o["adet"] * 120000
    assert o["donem"] == date.today().strftime("%Y-%m")
    # Gun 1 her zaman gecmistir/bugundur: ilk calisma BUGUN (bu gece).
    assert o["ilk_tarih"] == date.today().isoformat()

    # Elle toplu borclandirma onizlemesiyle AYNI cekirdek, AYNI sayi.
    elle = client.post("/borclandirma/toplu/onizleme", headers=adm, json={
        "donem": o["donem"], "gelir_gider_tanim_id": tanim["id"],
        "tutar_kurus": 120000, "suzgec": {}}).json()
    assert elle["islenecek"] == o["adet"]

    # HICBIR SEY YAZILMADI: ne borc ne plan.
    assert owner_conn.execute(
        "SELECT count(*) FROM dues_assessment WHERE tenant_id=%s", (world["a"],)
    ).fetchone()[0] == once
    assert owner_conn.execute(
        "SELECT count(*) FROM aidat_plani WHERE tenant_id=%s", (world["a"],)
    ).fetchone()[0] == plan_sayisi

    # Gelecek gun: ilk calisma o gun.
    if date.today().day < 28:
        r = client.post("/aidat-planlari/onizleme", headers=adm, json={
            "ad": "x", "gelir_gider_tanim_id": tanim["id"],
            "tutar_kurus": 100, "tahakkuk_gunu": 28})
        assert r.json()["ilk_tarih"] == date.today().replace(day=28).isoformat()


def test_plan_onizleme_gelir_kalemi_ve_sakin_red(client, adm, world):
    gelir = client.post("/gelir-gider-tanimlari", headers=adm, json={
        "ad": f"Gelir-{_sfx()}", "tip": "gelir"}).json()
    r = client.post("/aidat-planlari/onizleme", headers=adm, json={
        "ad": "x", "gelir_gider_tanim_id": gelir["id"], "tutar_kurus": 100})
    assert r.status_code == 422
    sakin = _h(client, world["slug_a"], world["resident_a"])
    assert client.post("/aidat-planlari/onizleme", headers=sakin, json={
        "ad": "x", "gelir_gider_tanim_id": gelir["id"], "tutar_kurus": 100,
    }).status_code == 403
    assert client.get("/hatirlatma-ayari/onizleme", headers=sakin).status_code == 403
    assert client.get("/otomasyon/son-calismalar", headers=sakin).status_code == 403


async def test_hatirlatma_onizleme_gonderimle_ayni(client, adm, world, db_session, owner_conn):
    from app import otomasyon

    daire = client.post("/units", headers=adm, json={"no": f"KH-{_sfx()}", "blok": "A"}).json()
    r = client.post("/users", headers=adm, json={
        "ad": "onizleme", "soyad": "kisi", "email": f"p250k-{_sfx()}@ornek.com",
        "role": "resident"})
    uid = r.json()["id"]
    client.post(f"/units/{daire['id']}/residents", headers=adm, json={
        "user_id": uid, "rol_tipi": "kiraci", "oturuyor": True})
    client.post("/dues/assessments", headers=adm, json={
        "unit_id": daire["id"], "donem": "2035-01", "tutar_kurus": 7700,
        "son_odeme_tarihi": (date.today() - timedelta(days=4)).isoformat()})
    # KAPALIYKEN de hesaplanir: acmadan once ne olacagi gorulmeli.
    client.patch("/hatirlatma-ayari", headers=adm, json={
        "aktif": False, "vade_oncesi_gun": 0, "kademeler": [4], "eposta": False})
    o = client.get("/hatirlatma-ayari/onizleme", headers=adm)
    assert o.status_code == 200, o.text
    onizleme = o.json()
    assert onizleme["adet"] >= 1
    assert onizleme["toplam_kurus"] >= 7700

    client.patch("/hatirlatma-ayari", headers=adm, json={"aktif": True})
    owner_conn.execute(
        "UPDATE hatirlatma_ayari SET son_calisma=NULL WHERE tenant_id=%s", (world["a"],))
    sonuc = await otomasyon.borc_hatirlatmalari(db_session, world["a"], date.today())
    await db_session.commit()
    # ONIZLEME = GERCEK: ayni hedef hesabi.
    assert sonuc["gonderilen"] == onizleme["adet"]

    son = {i["kural"]: i for i in client.get(
        "/otomasyon/son-calismalar", headers=adm).json()["items"]}
    assert son["borc_hatirlatma"]["adet"] == onizleme["adet"]


async def test_son_calisma_kural_basina(client, adm, world, tanim, db_session):
    from app import otomasyon

    client.post("/units", headers=adm, json={"no": f"KS-{_sfx()}", "blok": "A"})
    plan = client.post("/aidat-planlari", headers=adm, json={
        "ad": f"Plan-{_sfx()}", "gelir_gider_tanim_id": tanim["id"],
        "tutar_kurus": 3300, "tahakkuk_gunu": 2, "vade_gun": 5, "onizleme_gun": 0,
    }).json()
    kasa = client.post("/kasalar", headers=adm, json={
        "kod": f"KS{_sfx()}", "ad": "Kasa", "acilis_bakiye_kurus": 0}).json()
    gider = client.post("/duzenli-giderler", headers=adm, json={
        "ad": f"Temizlik-{_sfx()}", "tutar_kurus": 90000, "periyot": "aylik",
        "sonraki_tarih": "2036-03-02", "kasa_id": kasa["id"]}).json()

    await otomasyon.aidat_planlari_isle(db_session, world["a"], date(2036, 3, 2))
    await otomasyon.duzenli_giderleri_isle(db_session, world["a"], date(2036, 3, 2))
    await db_session.commit()

    son = {i["kural"]: i for i in client.get(
        "/otomasyon/son-calismalar", headers=adm).json()["items"]}
    assert son[plan["id"]]["tur"] == "aidat_tahakkuk"
    assert son[plan["id"]]["adet"] >= 1
    assert son[plan["id"]]["tutar_kurus"] == son[plan["id"]]["adet"] * 3300
    assert son[gider["id"]]["tur"] == "duzenli_gider"
