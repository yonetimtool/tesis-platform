"""(P192 §4) FINANS OTOMASYONU — kabul olcutleri 9 ve 10.

   9. Aylik tahakkuk otomatik calisiyor, IDEMPOTENT, onizleme bildirimi
      gidiyor.
  10. Borc hatirlatmalari otomatik gidiyor, ODEYENE GITMIYOR.

Olculen kusur (`docs/finans-analiz.md`): `beat_schedule`da aidat gorevi
YOKTU; yonetici her ay elle calistiriyordu ve unutursa o ay borc
olusmuyordu. Borc hatirlatmasi hic yoktu.

GOREVIN KENDISI (Celery) DEGIL, IS FONKSIYONLARI olculur: `otomasyon.py`
tek tenant icin calisir ve tarihi disaridan alir — boylece "ayin 5'i
geldi" senaryosu saati beklemeden surulebilir.
"""
from __future__ import annotations

import uuid
from datetime import date, timedelta

import pytest


def _headers(client, slug, cred):
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
    return _headers(client, world["slug_a"], world["admin_a"])


@pytest.fixture
async def db_session(world):
    """Otomasyon fonksiyonlarini SURMEK icin tenant-bagli async oturum.

    KENDI MOTORU + `NullPool`: paylasilan `app.db.engine` havuzdaki
    baglantilari bir onceki testin event loop'una baglar ve tam suitede
    "attached to a different loop" hatasi verir (P187'de olculdu). Havuzsuz
    motor her testte taze baglanti acar ve testin sonunda kapanir.

    OTURUM TEK BAGLANTIYA BAGLANIR: `set_config(..., false)` oturum
    duzeyindedir ve havuzdan HER SEFERINDE yeni baglanti alan bir
    yapilandirmada COMMIT sonrasi kaybolur ("unrecognized configuration
    parameter" — olculdu). Baglantiyi disaridan tutmak, RLS baglamini
    testin tamami boyunca ayakta tutar.
    """
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


def _daire(client, adm, **kw):
    govde = {"no": f"OT-{_sfx()}", "blok": "A"}
    govde.update(kw)
    return client.post("/units", headers=adm, json=govde).json()


# ============================ PLAN CRUD ==================================== #
def test_plan_olustur_ve_listele(client, adm, tanim):
    r = client.post("/aidat-planlari", headers=adm, json={
        "ad": f"Plan-{_sfx()}", "gelir_gider_tanim_id": tanim["id"],
        "tutar_kurus": 50000, "tahakkuk_gunu": 5, "vade_gun": 10})
    assert r.status_code == 201, r.text
    plan = r.json()
    assert plan["son_donem"] is None  # henuz hic islenmedi
    liste = client.get("/aidat-planlari", headers=adm).json()["items"]
    assert any(p["id"] == plan["id"] for p in liste)


def test_plan_dagitimla_tutarsiz_govde_reddedilir(client, adm, tanim):
    """`arsa_payi` dagitimi TOPLAM ister; ikisini de bos birakan bir plan
    her ay sessizce hicbir sey yazmazdi."""
    r = client.post("/aidat-planlari", headers=adm, json={
        "ad": f"Plan-{_sfx()}", "gelir_gider_tanim_id": tanim["id"],
        "dagitim": "arsa_payi"})
    assert r.status_code == 422


def test_plan_sakine_kapali(client, world, tanim):
    res = _headers(client, world["slug_a"], world["resident_a"])
    assert client.get("/aidat-planlari", headers=res).status_code == 403
    assert client.post("/aidat-planlari", headers=res, json={
        "ad": "x", "gelir_gider_tanim_id": tanim["id"],
        "tutar_kurus": 1}).status_code == 403


# ==================== OLCUT 9: OTOMATIK TAHAKKUK =========================== #
async def test_otomatik_tahakkuk_ve_idempotency(client, adm, world, tanim, db_session):
    from app import otomasyon

    daire = _daire(client, adm)
    plan = client.post("/aidat-planlari", headers=adm, json={
        "ad": f"Plan-{_sfx()}", "gelir_gider_tanim_id": tanim["id"],
        "suzgec": None, "tutar_kurus": 40000,
        "tahakkuk_gunu": 5, "vade_gun": 10, "onizleme_gun": 0,
    }).json()

    bugun = date(2033, 6, 5)
    ilk = await otomasyon.aidat_planlari_isle(db_session, world["a"], bugun)
    await db_session.commit()
    assert ilk["tahakkuk"] >= 1

    bakiye = client.get(f"/units/{daire['id']}/dues", headers=adm).json()
    assert bakiye["bakiye_kurus"] == 40000
    assert bakiye["assessments"][0]["donem"] == "2033-06"
    assert bakiye["assessments"][0]["son_odeme_tarihi"] == "2033-06-15"

    # IDEMPOTENT: gorev gunde on kez kossa da ikinci kez tahakkuk ETMEZ.
    ikinci = await otomasyon.aidat_planlari_isle(db_session, world["a"], bugun)
    await db_session.commit()
    assert ikinci["tahakkuk"] == 0
    assert client.get(
        f"/units/{daire['id']}/dues", headers=adm
    ).json()["bakiye_kurus"] == 40000

    # DAMGA gorunur: plan hangi donemi isledigini soyler.
    guncel = next(
        p for p in client.get("/aidat-planlari", headers=adm).json()["items"]
        if p["id"] == plan["id"]
    )
    assert guncel["son_donem"] == "2033-06"

    # ...ve otomasyon GUNLUGUNE yazildi.
    gunluk = client.get(
        "/otomasyon-gunlugu", headers=adm, params={"tur": "aidat_tahakkuk"}
    ).json()["items"]
    assert any(g["donem"] == "2033-06" and g["adet"] >= 1 for g in gunluk)


async def test_tahakkuk_gunu_gelmeden_yazmaz(client, adm, world, tanim, db_session):
    from app import otomasyon

    daire = _daire(client, adm)
    client.post("/aidat-planlari", headers=adm, json={
        "ad": f"Plan-{_sfx()}", "gelir_gider_tanim_id": tanim["id"],
        "tutar_kurus": 30000, "tahakkuk_gunu": 20, "onizleme_gun": 0})

    await otomasyon.aidat_planlari_isle(db_session, world["a"], date(2033, 7, 3))
    await db_session.commit()
    assert client.get(
        f"/units/{daire['id']}/dues", headers=adm
    ).json()["bakiye_kurus"] == 0


async def test_erteleme_o_ayi_atlar_plani_kapatmaz(
    client, adm, world, tanim, db_session
):
    from app import otomasyon

    daire = _daire(client, adm)
    plan = client.post("/aidat-planlari", headers=adm, json={
        "ad": f"Plan-{_sfx()}", "gelir_gider_tanim_id": tanim["id"],
        "tutar_kurus": 25000, "tahakkuk_gunu": 3, "onizleme_gun": 0}).json()

    r = client.post(f"/aidat-planlari/{plan['id']}/ertele", headers=adm,
                    json={"donem": "2033-08"})
    assert r.status_code == 200, r.text

    await otomasyon.aidat_planlari_isle(db_session, world["a"], date(2033, 8, 3))
    await db_session.commit()
    assert client.get(
        f"/units/{daire['id']}/dues", headers=adm
    ).json()["bakiye_kurus"] == 0

    # ERTELEME PLANI KAPATMAZ: gelecek ay yine calisir.
    await otomasyon.aidat_planlari_isle(db_session, world["a"], date(2033, 9, 3))
    await db_session.commit()
    assert client.get(
        f"/units/{daire['id']}/dues", headers=adm
    ).json()["bakiye_kurus"] == 25000


async def test_onizleme_bildirimi_tahakkuktan_once(
    client, adm, world, tanim, db_session, owner_conn
):
    """"3 gun sonra 26 daireye toplam X TL tahakkuk edilecek"."""
    from app import otomasyon

    _daire(client, adm)
    client.post("/aidat-planlari", headers=adm, json={
        "ad": f"Plan-{_sfx()}", "gelir_gider_tanim_id": tanim["id"],
        "tutar_kurus": 10000, "tahakkuk_gunu": 10, "onizleme_gun": 3})

    once = owner_conn.execute(
        "SELECT count(*) FROM notification WHERE tenant_id=%s AND tip='aidat_onizleme'",
        (str(world["a"]),),
    ).fetchone()[0]

    await otomasyon.aidat_planlari_isle(db_session, world["a"], date(2033, 10, 7))
    await db_session.commit()

    sonra = owner_conn.execute(
        "SELECT count(*) FROM notification WHERE tenant_id=%s AND tip='aidat_onizleme'",
        (str(world["a"]),),
    ).fetchone()[0]
    assert sonra > once


# ================= OLCUT 10: OTOMATIK BORC HATIRLATMA ====================== #
async def test_hatirlatma_odeyene_GITMEZ(
    client, adm, world, db_session, owner_conn
):
    """ODEYENE HATIRLATMA GITMEZ. Aday kumesi tahakkuk listesi DEGIL,
    "kalan > 0" olan borclardir."""
    from app import otomasyon

    resident = _headers(client, world["slug_a"], world["resident_a"])
    resident_id = client.get("/me", headers=resident).json()["id"]
    odeyen = _daire(client, adm)
    borclu = _daire(client, adm)
    for d in (odeyen, borclu):
        client.post(f"/units/{d['id']}/residents", headers=adm,
                    json={"user_id": resident_id, "rol_tipi": "malik"})

    vade = date.today() - timedelta(days=3)
    t_odeyen = client.post("/dues/assessments", headers=adm, json={
        "unit_id": odeyen["id"], "donem": "2033-11", "tutar_kurus": 10000,
        "son_odeme_tarihi": vade.isoformat()}).json()["created"][0]
    client.post("/dues/assessments", headers=adm, json={
        "unit_id": borclu["id"], "donem": "2033-11", "tutar_kurus": 20000,
        "son_odeme_tarihi": vade.isoformat()})

    kasa = client.post("/kasalar", headers=adm, json={
        "kod": f"HT{_sfx()}", "ad": "Kasa"}).json()
    client.post("/finans/tahsilat", headers=adm, json={
        "kasa_id": kasa["id"], "tutar_kurus": 10000,
        "unit_id": odeyen["id"], "assessment_id": t_odeyen["id"]})

    r = client.patch("/hatirlatma-ayari", headers=adm, json={
        "aktif": True, "vade_oncesi_gun": 0, "kademeler": [3]})
    assert r.status_code == 200, r.text

    sonuc = await otomasyon.borc_hatirlatmalari(db_session, world["a"], date.today())
    await db_session.commit()
    assert sonuc["durum"] == "gonderildi"

    # Bildirim satiri YAZILDI ve tutar YALNIZ acik borcu iceriyor.
    satir = owner_conn.execute(
        "SELECT mesaj_veri FROM notification WHERE tenant_id=%s AND tip='aidat_hatirlatma' "
        "AND user_id=%s ORDER BY created_at DESC LIMIT 1",
        (str(world["a"]), resident_id),
    ).fetchone()
    assert satir is not None
    assert "200" in satir[0]["tutar"], satir[0]


async def test_hatirlatma_gunde_bir_kez(client, adm, world, db_session):
    from app import otomasyon

    client.patch("/hatirlatma-ayari", headers=adm, json={"aktif": True})
    ilk = await otomasyon.borc_hatirlatmalari(db_session, world["a"], date.today())
    await db_session.commit()
    ikinci = await otomasyon.borc_hatirlatmalari(db_session, world["a"], date.today())
    await db_session.commit()
    assert ilk["durum"] != "bugun_calisti"
    assert ikinci["durum"] == "bugun_calisti"


async def test_hatirlatma_kapaliyken_hicbir_sey_gitmez(client, adm, world, db_session):
    from app import otomasyon

    client.patch("/hatirlatma-ayari", headers=adm, json={"aktif": False})
    sonuc = await otomasyon.borc_hatirlatmalari(db_session, world["a"], date.today())
    assert sonuc == {"gonderilen": 0, "durum": "kapali"}


# ======================== 4.5 DUZENLI GIDERLER ============================= #
async def test_duzenli_gider_onay_bekleyen_yazar_ve_ilerler(
    client, adm, world, db_session
):
    """Otomatik "odendi" yazmak, sistemin kimseye sormadan kasadan para
    cikarmasi olurdu — varsayilan ONAY BEKLEYEN."""
    from app import otomasyon

    kasa = client.post("/kasalar", headers=adm, json={
        "kod": f"DG{_sfx()}", "ad": "Gider Kasa",
        "acilis_bakiye_kurus": 1000000}).json()
    gider = client.post("/duzenli-giderler", headers=adm, json={
        "ad": f"Kapici-{_sfx()}", "tutar_kurus": 150000, "periyot": "aylik",
        "sonraki_tarih": "2034-01-05", "kasa_id": kasa["id"]}).json()

    sonuc = await otomasyon.duzenli_giderleri_isle(
        db_session, world["a"], date(2034, 1, 6))
    await db_session.commit()
    assert sonuc["yazilan"] == 1

    # BAKIYE DEGISMEDI (onay bekliyor), bekleyen cikista GORUNUYOR.
    satir = next(
        k for k in client.get("/finans/kasa-bakiyeleri", headers=adm).json()["items"]
        if k["kasa_id"] == kasa["id"]
    )
    assert satir["bakiye_kurus"] == 1000000
    assert satir["bekleyen_cikis_kurus"] == 150000

    # Tarih BIR PERIYOT ilerledi -> tekrar kosum ikinci kez yazmaz.
    guncel = next(
        g for g in client.get("/duzenli-giderler", headers=adm).json()["items"]
        if g["id"] == gider["id"]
    )
    assert guncel["sonraki_tarih"] == "2034-02-05"
    tekrar = await otomasyon.duzenli_giderleri_isle(
        db_session, world["a"], date(2034, 1, 6))
    assert tekrar["yazilan"] == 0


def test_ay_ekle_ay_sonunu_asmaz():
    """31 Ocak + 1 ay = 28/29 Subat. `timedelta(days=30)` her tekrarda
    tarihi kaydirir ve bir yil sonra gider "ayin 20'si" olmaktan cikardi."""
    from app.otomasyon import ay_ekle

    assert ay_ekle(date(2034, 1, 31), 1) == date(2034, 2, 28)
    assert ay_ekle(date(2032, 1, 31), 1) == date(2032, 2, 29)  # artik yil
    assert ay_ekle(date(2034, 11, 20), 3) == date(2035, 2, 20)


# =========================== 4.6 AYLIK OZET ================================ #
async def test_aylik_ozet_ayda_bir_gonderilir(client, adm, world, db_session):
    from app import otomasyon

    ilk = await otomasyon.aylik_ozet(db_session, world["a"], date(2035, 3, 1))
    await db_session.commit()
    assert ilk["donem"] == "2035-02"
    ikinci = await otomasyon.aylik_ozet(db_session, world["a"], date(2035, 3, 4))
    assert ikinci["durum"] == "zaten"

    gunluk = client.get(
        "/otomasyon-gunlugu", headers=adm, params={"tur": "aylik_ozet"}
    ).json()["items"]
    assert any(g["donem"] == "2035-02" for g in gunluk)


# ================= 4.3 BANKADAN CIKAN PARA = GIDER ========================= #
def test_banka_cikisi_onay_bekleyen_gider_yazar(client, adm, owner_conn, world):
    """Onceden `cikis` yonlu satirlar sonsuza kadar "manuel_inceleme"de
    bekliyordu: motor yalniz BORC kapatmayi biliyor. Karsiliginin defterde
    olmamasi, banka bakiyesi ile kasa bakiyesinin ayrismasi demekti.

    OTOMATIK "ODENDI" YAZILMAZ: banka masrafi yoneticinin onayina duser."""
    hesap = client.post("/kasalar", headers=adm, json={
        "kod": f"BC{_sfx()}", "ad": "Banka", "banka_mi": True,
        "iban": f"TR{uuid.uuid4().int % 10**24:024d}"}).json()
    etiket = _sfx()
    r = client.post("/banka/ice-aktar", headers=adm, json={
        "kaynak": "ekstre", "kasa_id": hesap["id"],
        "satirlar": [{"tarih": date.today().isoformat(), "tutar": 2500,
                      "yon": "cikis", "aciklama": f"BANKA MASRAFI {etiket}"}]})
    assert r.status_code == 201, r.text
    assert client.post("/banka/eslestir", headers=adm).status_code == 200

    satir = next(
        k for k in client.get("/finans/kasa-bakiyeleri", headers=adm).json()["items"]
        if k["kasa_id"] == hesap["id"]
    )
    # ONAY BEKLIYOR: bakiyeyi DUSURMEZ, bekleyen cikista GORUNUR.
    assert satir["bakiye_kurus"] == 0
    assert satir["bekleyen_cikis_kurus"] == 2500

    durum = owner_conn.execute(
        "SELECT durum FROM finansal_hareket WHERE tenant_id=%s "
        "AND aciklama LIKE %s", (str(world["a"]), f"%{etiket}%"),
    ).fetchone()
    assert durum[0] == "onay_bekliyor"


# ==================== 4.4 SAKININ MAKBUZ ARSIVI ============================ #
def test_makbuz_arsivi_sakine_acik_ve_kendi_makbuzlari(client, adm, world):
    """Makbuz uretiliyordu ama sakin ONA ULASAMIYORDU: uc yalniz yonetime
    acikti ve arsiv ekrani yoktu."""
    resident = _headers(client, world["slug_a"], world["resident_a"])
    r = client.get("/me/makbuzlar", headers=resident)
    assert r.status_code == 200, r.text
    govde = r.json()
    assert "items" in govde and "meta" in govde
    # Yonetici SAKIN ucunu kullanamaz (rol kapisi).
    assert client.get("/me/makbuzlar", headers=adm).status_code == 403


# =============== 4.2 YONETICININ METNI + GORUNUR IZ ======================== #
async def test_yoneticinin_METNI_kullanilir_ve_cevrilmez(
    client, adm, world, db_session, owner_conn
):
    """Yoneticinin yazdigi cumleyi makineyle degistirmek, onun
    soylemedigi bir seyi ona soyletmek olurdu — metin CEVRILMEZ."""
    from app import otomasyon

    resident = _headers(client, world["slug_a"], world["resident_a"])
    resident_id = client.get("/me", headers=resident).json()["id"]
    daire = _daire(client, adm)
    client.post(f"/units/{daire['id']}/residents", headers=adm,
                json={"user_id": resident_id, "rol_tipi": "malik"})
    vade = date.today() - timedelta(days=3)
    client.post("/dues/assessments", headers=adm, json={
        "unit_id": daire["id"], "donem": "2033-12", "tutar_kurus": 12300,
        "son_odeme_tarihi": vade.isoformat()})

    client.patch("/hatirlatma-ayari", headers=adm, json={
        "aktif": True, "vade_oncesi_gun": 0, "kademeler": [3],
        "metin": "Sayin komsumuz, {tutar} borcunuz var. Site Yonetimi"})

    sonuc = await otomasyon.borc_hatirlatmalari(db_session, world["a"], date.today())
    await db_session.commit()
    assert sonuc["durum"] == "gonderildi"

    # KALICI SATIRDA da ozel metin var — push ile in-app ayni cumleyi
    # gostermeli.
    veri = owner_conn.execute(
        "SELECT mesaj_veri FROM notification WHERE tenant_id=%s "
        "AND tip='aidat_hatirlatma' AND user_id=%s "
        "ORDER BY created_at DESC LIMIT 1",
        (str(world["a"]), resident_id),
    ).fetchone()[0]
    assert veri["metin"].startswith("Sayin komsumuz")
    assert "123" in veri["metin"]  # {tutar} dolduruldu

    # Sakin bildirim listesinde de AYNI cumleyi gorur.
    liste = client.get("/notifications", headers=resident).json()["items"]
    hedef = next(n for n in liste if n["tip"] == "aidat_hatirlatma")
    assert hedef["mesaj"].startswith("Sayin komsumuz")

    client.patch("/hatirlatma-ayari", headers=adm, json={"metin": None})


def test_hatirlatma_gecmisi_gonderilen_ve_OKUNAN_gosterir(client, adm, world):
    """Sayilar `otomasyon_gunlugu`nda da var ama orasi "gorev ne yapti"
    sorusunu yanitlar; burasi "kime ulasti"yi."""
    r = client.get("/finans/hatirlatma-gecmisi", headers=adm)
    assert r.status_code == 200, r.text
    govde = r.json()
    assert "gonderilen" in govde and "okunan" in govde
    assert govde["okunan"] <= govde["gonderilen"]
    for satir in govde["items"]:
        assert "okundu" in satir and "gonderim_zamani" in satir


# ================= 4.1 ATLANMIS DONEM TELAFISI ============================= #
def test_islenecek_donem_YENI_PLAN_gecmisi_borclandirmaz():
    """Bir plan tanimlamak, gecmis aylarin aidatini bir anda yazmak
    anlamina gelmemeli."""
    from app.otomasyon import islenecek_donem

    class _Plan:
        son_donem = None
        tahakkuk_gunu = 5

    plan = _Plan()
    assert islenecek_donem(plan, date(2035, 6, 4)) is None   # gun gelmedi
    assert islenecek_donem(plan, date(2035, 6, 5)) == "2035-06"


def test_islenecek_donem_ATLANMIS_ayi_telafi_eder():
    """Gorev bir gun kosmazsa o ayin tahakkuku SESSIZCE KAYBOLURDU:
    ertesi ay `bugun.day` yeni ayin tahakkuk gununden kucuk olur ve
    gecmis ay bir daha hic bakilmaz."""
    from app.otomasyon import islenecek_donem

    class _Plan:
        son_donem = "2035-04"
        tahakkuk_gunu = 25

    plan = _Plan()
    # Mayis atlandi; Haziran'in 3'undeyiz. Once MAYIS islenir.
    assert islenecek_donem(plan, date(2035, 6, 3)) == "2035-05"
    # Mayis islendikten sonra Haziran'in gunu henuz gelmedi.
    plan.son_donem = "2035-05"
    assert islenecek_donem(plan, date(2035, 6, 3)) is None
    # Gun gelince Haziran.
    assert islenecek_donem(plan, date(2035, 6, 25)) == "2035-06"


def test_islenecek_donem_KOSUM_BASINA_BIR_DONEM():
    """Uc aylik bir kesintiden sonra butun tahakkuklari tek seferde
    yazmak, yoneticiye aciklanamayan bir borc yigini gostermek olurdu."""
    from app.otomasyon import islenecek_donem

    class _Plan:
        son_donem = "2035-01"
        tahakkuk_gunu = 1

    plan = _Plan()
    assert islenecek_donem(plan, date(2035, 5, 10)) == "2035-02"
    plan.son_donem = "2035-02"
    assert islenecek_donem(plan, date(2035, 5, 10)) == "2035-03"


def test_tahakkuk_tarihi_donemin_gununu_kullanir():
    """`date.today()` kullanmak, gecmis bir donemin tahakkukunu bugunun
    tarihiyle yazmak olurdu; "Mart tahakkuku" Haziran'da gorunurdu."""
    from app.otomasyon import tahakkuk_tarihi

    assert tahakkuk_tarihi("2035-03", 25) == date(2035, 3, 25)
    # Subat'ta olmayan gun ay sonuna cekilir (28/29).
    assert tahakkuk_tarihi("2035-02", 30) == date(2035, 2, 28)


async def test_atlanan_ay_gercekten_yazilir(client, adm, world, tanim, db_session):
    from app import otomasyon

    daire = _daire(client, adm)
    plan = client.post("/aidat-planlari", headers=adm, json={
        "ad": f"Plan-{_sfx()}", "gelir_gider_tanim_id": tanim["id"],
        "tutar_kurus": 60000, "tahakkuk_gunu": 25, "onizleme_gun": 0,
    }).json()

    # Nisan islendi, Mayis ATLANDI (gorev kosmadi), Haziran'in 3'undeyiz.
    await otomasyon.aidat_planlari_isle(db_session, world["a"], date(2035, 4, 25))
    await db_session.commit()
    await otomasyon.aidat_planlari_isle(db_session, world["a"], date(2035, 6, 3))
    await db_session.commit()

    durum = client.get(f"/units/{daire['id']}/dues", headers=adm).json()
    donemler = sorted(a["donem"] for a in durum["assessments"])
    assert donemler == ["2035-04", "2035-05"], donemler
    # TELAFI EDILEN AYIN TARIHI KENDI AYINDAN: "Mayis tahakkuku" Haziran'da
    # gorunmemeli.
    mayis = next(a for a in durum["assessments"] if a["donem"] == "2035-05")
    assert mayis["tarih"] == "2035-05-25"

    guncel = next(
        p for p in client.get("/aidat-planlari", headers=adm).json()["items"]
        if p["id"] == plan["id"]
    )
    assert guncel["son_donem"] == "2035-05"
