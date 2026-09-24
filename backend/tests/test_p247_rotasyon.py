"""(P247 §1) VARDIYA ROTASYONU — DONGU KALIPLARI.

Kabul: (a) 2 gece-2 gunduz-2 tatil, (b) iki hafta gece 12/36 + iki hafta
gunduz 12/36, (c) ayni dongu uc kisiye 2'ser gun kaydirilarak — nobet
kesintisiz. Izin/elle degisiklik donguyu KAYDIRMAZ, uretilen satirlar
TASLAK, parti ile geri alinir, beat kayan ufku doldurur ama filigranin
gerisine donmez.

Canli sunucuya karsi kosar (P-kurali: monkeypatch yok); beat isi ayni
veritabaninda app_rw + tenant baglaminda DOGRUDAN cagrilir.
"""
from __future__ import annotations

import asyncio
import datetime as dt
import uuid

import pytest

DILIM = [
    {"ad": "Gündüz", "baslangic": "08:00", "bitis": "20:00"},
    {"ad": "Gece", "baslangic": "20:00", "bitis": "08:00"},
]
DONGU_A = [[1], [1], [0], [0], [], []]
DONGU_B = [[1], []] * 7 + [[0], []] * 7


def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _pazartesi(hafta: int = 1) -> dt.date:
    b = dt.date.today()
    return b - dt.timedelta(days=b.weekday()) + dt.timedelta(weeks=hafta)


@pytest.fixture
def yon(client, world):
    return _h(client, world["slug_a"], world["yonetici_a"])


@pytest.fixture
def ekip(client, world, owner_conn, yon):
    """Uc guvenlik gorevlisi: fixture'daki + iki yeni (sirali)."""
    from .conftest import _hash

    with owner_conn.cursor() as cur:
        for i, ad in enumerate(("Guard B2", "Guard C3")):
            cur.execute(
                "INSERT INTO app_user (tenant_id, ad, email, telefon, password_hash,"
                " password_set, role) VALUES (%s,%s,%s,%s,%s,true,'security'::user_role)",
                (world["a"], ad, f"p247-{i}-{uuid.uuid4().hex[:6]}@example.com",
                 world["bos_telefonlar"][i], _hash("x-parola-1")),
            )
    items = client.get("/users", headers=yon, params={"limit": 200}).json()["items"]
    sirali = {u["ad"]: u["id"] for u in items if u["role"] == "security"}
    return [sirali["Guard A"], sirali["Guard B2"], sirali["Guard C3"]]


def _kalip(client, yon, adimlar, ad=None):
    r = client.post("/vardiya-plani/kaliplar", headers=yon, json={
        "ad": ad or f"D{uuid.uuid4().hex[:6]}", "dilimler": DILIM, "adimlar": adimlar,
    })
    assert r.status_code == 201, r.text
    return r.json()["id"]


def _dongu(client, yon, kalip_id, kisiler, bas, **kw):
    return client.post("/vardiya-plani/dongu-uygula", headers=yon, json={
        "kalip_id": kalip_id, "kisiler": kisiler, "baslangic": str(bas), **kw,
    })


def _satirlar(owner_conn, tid, uid=None):
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT tarih, baslangic_saat, durum, id, yayinlandi_at, dongu_atama_id "
            "FROM vardiya_plani WHERE tenant_id=%s"
            + (" AND user_id=%s" if uid else "")
            + " ORDER BY tarih, baslangic_saat",
            (tid, uid) if uid else (tid,),
        )
        return cur.fetchall()


def _beat(tid, bugun):
    """Beat isini tek bir taze motorla kos (paylasilan motor baska dongude
    acilmis olabilir — test_mesaj_kuyrugu `_taze_oturum` notu)."""
    from sqlalchemy import text
    from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

    from app.config import settings
    from app.routers.vardiya_plani import dongu_ufkunu_doldur

    async def _k():
        motor = create_async_engine(settings.database_url, poolclass=None)
        try:
            async with async_sessionmaker(motor, expire_on_commit=False)() as s:
                await s.execute(
                    text("SELECT set_config('app.current_tenant_id', :t, true)"),
                    {"t": str(tid)},
                )
                o = await dongu_ufkunu_doldur(s, tid, bugun)
                await s.commit()
                return o
        finally:
            await motor.dispose()

    return asyncio.run(_k())


# ============================== SAF HESAP ================================= #
def test_ADIM_TAKVIMDEN_ve_BOSLUK_HESABI():
    from app.vardiya import dongu_adimi, kapsama_bosluklari

    ref = dt.date(2026, 3, 2)
    assert dongu_adimi(ref, ref, 6) == 0
    assert dongu_adimi(ref + dt.timedelta(days=7), ref, 6) == 1
    # Referanstan ONCE: kaydirilmis uye dongunun SONUNDAN gelir.
    assert dongu_adimi(ref - dt.timedelta(days=2), ref, 6) == 4
    g = dt.date(2026, 3, 3)
    gece_dun = (dt.datetime(2026, 3, 2, 20), dt.datetime(2026, 3, 3, 8))
    gunduz = (dt.datetime(2026, 3, 3, 8), dt.datetime(2026, 3, 3, 20))
    assert kapsama_bosluklari(g, [gece_dun, gunduz]) == [
        (dt.datetime(2026, 3, 3, 20), dt.datetime(2026, 3, 4, 0))
    ]
    assert kapsama_bosluklari(g, []) == [
        (dt.datetime(2026, 3, 3, 0), dt.datetime(2026, 3, 4, 0))
    ]


# ============================== TANIM ===================================== #
def test_DONGU_KALIBI_kaydedilir_ve_dogrulanir(client, yon):
    a = _kalip(client, yon, DONGU_A)
    b = _kalip(client, yon, DONGU_B)
    items = client.get("/vardiya-plani/kaliplar", headers=yon).json()["items"]
    by = {k["id"]: k for k in items}
    assert by[a]["adimlar"] == DONGU_A
    assert len(by[b]["adimlar"]) == 28
    for bozuk in ([[2]], [[]] * 3, [[0, 0]]):
        r = client.post("/vardiya-plani/kaliplar", headers=yon, json={
            "ad": f"X{uuid.uuid4().hex[:5]}", "dilimler": DILIM, "adimlar": bozuk})
        assert r.status_code == 422, (bozuk, r.text)
    # Klasik kalip bozulmadi: adimlar NULL.
    r = client.post("/vardiya-plani/kaliplar", headers=yon, json={
        "ad": f"K{uuid.uuid4().hex[:5]}", "dilimler": DILIM})
    assert r.status_code == 201 and r.json()["adimlar"] is None


# ============================ (c) EKIP ==================================== #
def test_EKIP_KAYDIRMA_nobet_KESINTISIZ_ve_onizleme_YAZMAZ(
    client, world, yon, ekip, owner_conn
):
    kalip = _kalip(client, yon, DONGU_A)
    bas = _pazartesi()
    r = _dongu(client, yon, kalip, ekip, bas, kaydirma=2, kuru=True)
    assert r.status_code == 200, r.text
    j = r.json()
    assert j["uygulandi"] is False
    assert list(j["ofsetler"].values()) == [0, 2, 4]
    assert _satirlar(owner_conn, world["a"]) == [], "onizleme YAZMAMALI"
    bos = [k for k in j["kapsama"] if k["bos_dakika"]]
    # Ilk gunun 00-08'i ONCEKI geceden gelir ve o gece kimse planli degil —
    # gercek bir bosluk; sonrasi kesintisiz.
    assert [(k["tarih"], k["bosluklar"]) for k in bos] == [
        (str(bas), [{"baslangic": "00:00:00", "bitis": "08:00:00"}])
    ]
    ilk = {(s["tarih"], s["user_id"]): s["dilim"] for s in j["satirlar"]
           if s["tarih"] == str(bas)}
    assert ilk == {(str(bas), ekip[0]): "Gece", (str(bas), ekip[2]): "Gündüz"}


def test_IKI_KISIDE_BOSLUK_BELIRGIN(client, yon, ekip):
    kalip = _kalip(client, yon, DONGU_A)
    j = _dongu(client, yon, kalip, ekip[:2], _pazartesi(), kaydirma=2, kuru=True).json()
    bos = [k for k in j["kapsama"] if k["bos_dakika"]]
    assert len(bos) > len(j["kapsama"]) // 3
    assert all(k["bosluklar"] for k in bos)


def test_UYGULA_TASLAK_PARTI_ve_ATAMA(client, world, yon, ekip, owner_conn):
    kalip = _kalip(client, yon, DONGU_A)
    bas = _pazartesi()
    r = _dongu(client, yon, kalip, ekip, bas, kaydirma=2)
    j = r.json()
    assert r.status_code == 200 and j["uygulandi"] and j["parti_id"], r.text
    # KAYAN UFUK: bugun + 62 gun.
    assert dt.date.fromisoformat(j["bitis"]) == max(dt.date.today(), bas) + dt.timedelta(days=61)
    satir = _satirlar(owner_conn, world["a"])
    assert len(satir) == j["eklenen"] > 0
    assert all(s[4] is None for s in satir), "uretilen satir TASLAK olmali"
    assert all(s[5] is not None for s in satir)
    liste = client.get("/vardiya-plani/dongu-atamalari", headers=yon).json()
    assert liste["ufuk_gun"] == 62
    assert sorted(a["user_id"] for a in liste["items"]) == sorted(ekip)
    assert {a["durum"] for a in liste["items"]} == {"aktif"}
    # Ayni kisiye ikinci etkin dongu YOK.
    r = _dongu(client, yon, kalip, [ekip[0]], bas, kuru=True)
    assert r.status_code == 409, r.text
    # Etkin dongudeki kalip silinemez; kalip-uygula'dan da uygulanamaz.
    assert client.delete(f"/vardiya-plani/kaliplar/{kalip}", headers=yon).status_code == 409
    r = client.post("/vardiya-plani/kalip-uygula", headers=yon, json={
        "kalip_id": kalip, "gunler": [str(bas)], "atamalar": {"0": [ekip[0]]},
        "kuru": True})
    assert r.status_code == 422, r.text


# ======================= IZIN — DONGU KAYMAZ ============================== #
def test_IZIN_DONGUYU_KAYDIRMAZ(client, world, yon, ekip, owner_conn):
    kalip = _kalip(client, yon, DONGU_A)
    bas = _pazartesi()
    izin = bas + dt.timedelta(days=6)  # ekip[0]: adim 0 = Gece
    r = client.post("/vardiya-izin", headers=yon, json={
        "user_id": ekip[0], "tur": "yillik", "baslangic": str(izin), "bitis": str(izin)})
    assert r.status_code in (200, 201), r.text
    j = _dongu(client, yon, kalip, ekip, bas, kaydirma=2).json()
    assert j["izinli"] == 1 and j["cakisan"] == 0
    assert any(s["durum"] == "izinli" and s["tarih"] == str(izin) for s in j["satirlar"])
    s = {(t, b.strftime("%H:%M")): d for t, b, d, *_ in _satirlar(owner_conn, world["a"], ekip[0])}
    assert (izin, "20:00") not in s, "izinli gune vardiya URETILMEZ"
    # SAYAC ILERLEDI: ertesi gun adim 1 (Gece), ondan sonra adim 2 (Gunduz).
    assert s[(izin + dt.timedelta(days=1), "20:00")] == "planli"
    assert s[(izin + dt.timedelta(days=2), "08:00")] == "planli"
    atama = next(a for a in client.get("/vardiya-plani/dongu-atamalari", headers=yon)
                 .json()["items"] if a["user_id"] == ekip[0])
    assert atama["atlanan"] == [{"tarih": str(izin), "dilim": "Gece", "sebep": "izinli"}]


def test_SONRADAN_IZIN_satiri_iptal_eder_BEAT_geri_getirmez(
    client, world, yon, ekip, owner_conn
):
    kalip = _kalip(client, yon, DONGU_A)
    bas = _pazartesi()
    _dongu(client, yon, kalip, ekip, bas, kaydirma=2)
    izin = bas + dt.timedelta(days=6)
    client.post("/vardiya-izin", headers=yon, json={
        "user_id": ekip[0], "tur": "yillik", "baslangic": str(izin), "bitis": str(izin)})
    _beat(world["a"], dt.date.today() + dt.timedelta(days=3))
    s = [(t, d) for t, b, d, *_ in _satirlar(owner_conn, world["a"], ekip[0]) if t == izin]
    assert s == [(izin, "iptal")]


# ==================== ELLE DEGISIKLIK — EZILMEZ ============================ #
def test_ELLE_DEGISIKLIK_yalniz_o_gun_ve_BEAT_ezmez(
    client, world, yon, ekip, owner_conn
):
    kalip = _kalip(client, yon, DONGU_A)
    _dongu(client, yon, kalip, ekip, _pazartesi(), kaydirma=2)
    hedef = _satirlar(owner_conn, world["a"], ekip[1])[2]  # 08:00 gunduz
    assert hedef[1].strftime("%H:%M") == "08:00"
    r = client.patch(f"/vardiya-plani/{hedef[3]}", headers=yon,
                     json={"baslangic_saat": "09:00"})
    assert r.status_code == 200, r.text
    r = client.patch(f"/vardiya-plani/{hedef[3]}", headers=yon,
                     json={"not_metni": "x", "kapsam": "seri"})
    assert r.status_code == 422 and r.json()["error"]["message"].startswith("Döngüden")
    once = _satirlar(owner_conn, world["a"], ekip[1])
    assert sum(1 for t, b, *_ in once if b.strftime("%H:%M") == "09:00") == 1
    _beat(world["a"], dt.date.today() + dt.timedelta(days=4))
    sonra = _satirlar(owner_conn, world["a"], ekip[1])
    gun = [x for x in sonra if x[0] == hedef[0] and x[2] == "planli"]
    assert len(gun) == 1 and gun[0][1].strftime("%H:%M") == "09:00"


def test_ELLE_SILINEN_gun_BEAT_ile_GERI_GELMEZ(client, world, yon, ekip, owner_conn):
    """Filigranin varlik sebebi: uretici gecmise DONMEZ.

    Izinli ya da degistirilmis gun zaten baska bir kuralla korunuyor
    (izin denetimi / cakisma); elle KALDIRILAN bir gunu yalniz filigran
    korur — beat bastan uretseydi yoneticinin "o gun Ali gelmeyecek"
    karari ertesi gece sessizce geri alinirdi.
    """
    kalip = _kalip(client, yon, DONGU_A)
    bas = _pazartesi()
    _dongu(client, yon, kalip, ekip, bas, kaydirma=2)
    hedef = _satirlar(owner_conn, world["a"], ekip[0])[0]
    r = client.delete(f"/vardiya-plani/{hedef[3]}", headers=yon)
    assert r.status_code == 200, r.text
    _beat(world["a"], bas + dt.timedelta(days=3))
    gun = [d for t, b, d, *_ in _satirlar(owner_conn, world["a"], ekip[0])
           if t == hedef[0] and b == hedef[1]]
    assert gun == ["iptal"], gun


# ========================== KAYAN UFUK (BEAT) ============================= #
def test_BEAT_ufku_ilerletir_ve_IDEMPOTENT(client, world, yon, ekip, owner_conn):
    from app.celery_app import celery_app

    kalip = _kalip(client, yon, DONGU_A)
    bas = _pazartesi()
    j = _dongu(client, yon, kalip, ekip, bas, kaydirma=2).json()
    son = dt.date.fromisoformat(j["bitis"])
    # Ufuk bugune degil BASLANGICA gore: bas+61 -> beat "bas+6" gununde
    # tam 6 gun ilerler.
    o = _beat(world["a"], bas + dt.timedelta(days=6))
    assert o["atama"] == 3
    # 6 gun x 2 vardiya (her gun bir gece + bir gunduz) = 12 yeni satir.
    assert o["eklenen"] == 12, o
    assert _beat(world["a"], bas + dt.timedelta(days=6))["eklenen"] == 0
    # Yeni gunler de dogru adimda: son gun icin takvimden hesap.
    yeni_son = son + dt.timedelta(days=6)
    for i, uid in enumerate(ekip):
        adim = (yeni_son - (bas + dt.timedelta(days=2 * i))).days % 6
        satir = [b.strftime("%H:%M") for t, b, d, *_ in
                 _satirlar(owner_conn, world["a"], uid) if t == yeni_son]
        beklenen = {0: ["20:00"], 1: ["20:00"], 2: ["08:00"], 3: ["08:00"]}.get(adim, [])
        assert satir == beklenen, (i, adim, satir)
    assert any(
        g["task"] == "scheduler.vardiya_dongu_uret"
        for g in celery_app.conf.beat_schedule.values()
    )


# ============================ GERI AL ===================================== #
def test_GERI_AL_satirlari_ve_ATAMAYI_kapatir(client, world, yon, ekip, owner_conn):
    kalip = _kalip(client, yon, DONGU_A)
    j = _dongu(client, yon, kalip, ekip, _pazartesi(), kaydirma=2).json()
    r = client.post(f"/vardiya-plani/parti/{j['parti_id']}/geri-al", headers=yon)
    assert r.status_code == 200 and r.json()["iptal_edilen"] == j["eklenen"], r.text
    assert {d for _, _, d, *_ in _satirlar(owner_conn, world["a"])} == {"iptal"}
    assert client.get("/vardiya-plani/dongu-atamalari", headers=yon).json()["items"] == []
    # Beat geri alinan donguyu YENIDEN doldurmaz.
    assert _beat(world["a"], dt.date.today() + dt.timedelta(days=10))["eklenen"] == 0
    # Kalip artik silinebilir.
    assert client.delete(f"/vardiya-plani/kaliplar/{kalip}", headers=yon).status_code == 204


def test_SONLANDIR_yalniz_o_kisinin_gelecegini_iptal_eder(
    client, world, yon, ekip, owner_conn
):
    kalip = _kalip(client, yon, DONGU_A)
    bas = _pazartesi()
    _dongu(client, yon, kalip, ekip, bas, kaydirma=2)
    aid = next(a["id"] for a in client.get("/vardiya-plani/dongu-atamalari", headers=yon)
               .json()["items"] if a["user_id"] == ekip[0])
    kes = bas + dt.timedelta(days=10)
    r = client.post(f"/vardiya-plani/dongu-atamalari/{aid}/sonlandir", headers=yon,
                    json={"tarih": str(kes)})
    assert r.status_code == 200 and r.json()["bitis"] == str(kes - dt.timedelta(days=1))
    ali = [t for t, b, d, *_ in _satirlar(owner_conn, world["a"], ekip[0]) if d == "planli"]
    assert ali and max(ali) < kes
    veli = [t for t, b, d, *_ in _satirlar(owner_conn, world["a"], ekip[1]) if d == "planli"]
    assert max(veli) > kes, "otekilerin dongusu surer"
    o = _beat(world["a"], dt.date.today() + dt.timedelta(days=5))
    assert o["atama"] == 2


# ======================= (b) 12/36 — GUN ASIRI ============================ #
def test_12_36_IKI_HAFTA_GECE_IKI_HAFTA_GUNDUZ(client, world, yon, ekip, owner_conn):
    kalip = _kalip(client, yon, DONGU_B)
    bas = _pazartesi()
    r = _dongu(client, yon, kalip, [ekip[0]], bas)
    assert r.status_code == 200, r.text
    satir = [(t, b.strftime("%H:%M")) for t, b, d, *_ in
             _satirlar(owner_conn, world["a"], ekip[0])
             if t < bas + dt.timedelta(days=28)]
    assert [s[1] for s in satir] == ["20:00"] * 7 + ["08:00"] * 7
    assert all((satir[i + 1][0] - satir[i][0]).days == 2 for i in range(13))
    # Gece 12/36 GECE ASAR: 20:00 -> ertesi gun 08:00.
    c = client.get("/vardiya-plani/cizelge", headers=yon,
                   params={"baslangic": str(bas), "gun": 2}).json()
    blok = next(k for k in c["personel"] if k["user_id"] == ekip[0])["bloklar"][0]
    assert blok["gece_asiyor"] is True and blok["biter"].startswith(
        str(bas + dt.timedelta(days=1)) + "T08:00")


# ====================== CAKISMA (P205 kurali korundu) ===================== #
def test_CAKISMA_sessizce_ATLANMAZ(client, world, yon, ekip, owner_conn):
    kalip = _kalip(client, yon, DONGU_A)
    bas = _pazartesi()
    r = client.post("/vardiya-plani/toplu", headers=yon, json={
        "user_id": ekip[0], "baslangic_tarih": str(bas), "bitis_tarih": str(bas),
        "baslangic_saat": "18:00", "bitis_saat": "22:00"})
    assert r.status_code == 200 and r.json()["eklenen"] == 1, r.text
    r = _dongu(client, yon, kalip, [ekip[0]], bas)
    j = r.json()
    assert j["uygulandi"] is False and j["cakisan"] == 1
    assert len(_satirlar(owner_conn, world["a"], ekip[0])) == 1, "hicbir sey yazilmamali"
    j = _dongu(client, yon, kalip, [ekip[0]], bas, cakisanlari_atla=True).json()
    assert j["uygulandi"] is True and j["cakisan"] == 1


# ========================= AMIR KAPSAMI =================================== #
def test_AMIR_yalniz_GUVENLIGE_dongu_atar(client, world, yon, ekip):
    amir = _h(client, world["slug_a"], world["amir_a"])
    kalip = _kalip(client, yon, DONGU_A)
    items = client.get("/users", headers=yon, params={"limit": 200}).json()["items"]
    gorevli = next(u["id"] for u in items if u["role"] == "tesis_gorevlisi")
    r = _dongu(client, amir, kalip, [gorevli], _pazartesi(), kuru=True)
    assert r.status_code == 403, r.text
    r = _dongu(client, amir, kalip, ekip, _pazartesi(), kaydirma=2, kuru=True)
    assert r.status_code == 200, r.text
