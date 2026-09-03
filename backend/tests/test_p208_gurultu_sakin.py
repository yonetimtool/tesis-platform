"""(P208 §1) GURULTU ESIGI ASILINCA SAKINE UYARI.

===========================================================================
OLCULEN EKSIK (P37'den beri)
===========================================================================
Esik asilinca sistem ya anons cihazina webhook atiyor ya da yoneticiye
"anonsu yapin" diyordu. DAIRENIN SAKININE HICBIR SEY GITMIYORDU — yani
uyari, uyarilmasi gereken kisiye ulasmiyordu.

Ayrica sayim PENCERESIZDI: bir yil once acilmis ve kapatilmamis bir
sikayet, dun geceki kadar agirlik tasiyordu.

===========================================================================
BU DOSYANIN EN SERT KILITLERI
===========================================================================
  1. Bildirimde SIKAYET EDENIN IZI YOK (kimlik, daire, hatta SAYI bile),
  2. PENCERE: eski sikayetler sayilmaz,
  3. SUSMA: uyarilan daire yeniden uyarilmaz,
  4. KIRACI VARSA yalniz kiraciya (oturmayan malike gitmez),
  5. SAKIN YOKSA yalniz yonetim bilgilendirilir,
  6. DENETIME yazilir.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

import pytest

from app.push_metinleri import METINLER

UTC = timezone.utc


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def d(client, world, owner_conn):
    """Hedef daire + o dairede oturan bir SAKIN."""
    from types import SimpleNamespace

    yonetici = _h(client, world["slug_a"], world["yonetici_a"])
    blok = f"P{uuid.uuid4().hex[:3].upper()}"
    hedef = client.post("/units", headers=yonetici,
                        json={"no": f"{blok}-9", "blok": blok}).json()
    yield SimpleNamespace(
        yonetici=yonetici, hedef=hedef, blok=blok, conn=owner_conn,
        tenant=world["a"], client=client, world=world)
    owner_conn.execute(
        "UPDATE tenant SET gurultu_pencere_gun=30, gurultu_susma_gun=7, "
        "gurultu_sakin_uyarisi=true WHERE id=%s", (world["a"],))
    owner_conn.commit()


def _kullanici(d) -> uuid.UUID:
    """Daireye BAGLI OLMAYAN sakin — sikayet edenler icin.

    `uq_unitresident_daire_rol` bir daireye ROL BASINA TEK bag verir
    (bir malik + bir kiraci); sikayet edenleri hedef daireye baglamak
    ikinci malikte patlardi (ilk yazimda oyleydi, test gosterdi).
    """
    from app.security import hash_password

    uid = uuid.uuid4()
    d.conn.execute(
        "INSERT INTO app_user (id, tenant_id, ad, email, telefon, "
        "password_hash, password_set, role) "
        "VALUES (%s,%s,%s,%s,%s,%s,true,'resident'::user_role)",
        (uid, d.tenant, "Sikayetci", f"p208-{uid.hex[:8]}@x.com",
         f"+9053{uuid.uuid4().int % 10**8:08d}", hash_password("Parola123!")))
    d.conn.commit()
    return uid


def _sakin_ekle(d, rol="malik", *, unit_id=None):
    """Hedef daireye AKTIF sakin bagi kurar; kullanici kimligini doner."""
    uid = _kullanici(d)
    d.conn.execute(
        "INSERT INTO unit_resident (tenant_id, unit_id, user_id, rol_tipi, "
        "baslangic) VALUES (%s,%s,%s,%s::resident_rol, now())",
        (d.tenant, unit_id or d.hedef["id"], uid, rol))
    d.conn.commit()
    return uid


def _sikayet(d, *, kategori="gurultu", gun_once=0):
    """Hedef daireye bir sikayet yazar (owner ile — akis testleri
    `test_gurultu_caydirici`de; burada olculen sey ESIK SONRASI)."""
    cid = uuid.uuid4()
    zaman = datetime.now(tz=UTC) - timedelta(days=gun_once)
    uid = _kullanici(d)
    d.conn.execute(
        "INSERT INTO unit_complaint (id, tenant_id, target_unit_id, "
        "complainant_user_id, kategori, durum, created_at) "
        "VALUES (%s,%s,%s,%s,'gurultu','acik',%s)",
        (cid, d.tenant, d.hedef["id"], uid, zaman))
    d.conn.commit()
    return cid


async def _esigi_calistir(d):
    """`esik_kontrol`u KENDI oturumunda calistirir (P187 dersi: asyncpg
    baglantilari OLUSTURULDUKLARI dongude yasar)."""
    from sqlalchemy import select

    from app.db import SessionLocal, set_tenant
    from app.gurultu_akisi import esik_kontrol
    from app.models import Unit

    async with SessionLocal() as session:
        async with session.begin():
            await set_tenant(session, d.tenant)
            unit = (
                await session.execute(
                    select(Unit).where(Unit.id == uuid.UUID(d.hedef["id"]))
                )
            ).scalar_one()
            return await esik_kontrol(
                session, tenant_id=uuid.UUID(str(d.tenant)), unit=unit
            )


def _calistir(d, push_kaydi=None):
    """Senkron sarmalayici — `asyncio.run` + havuz hijyeni (P187)."""
    import asyncio

    from app.db import engine

    async def _kos():
        await engine.dispose(close=False)
        try:
            return await _esigi_calistir(d)
        finally:
            await engine.dispose()

    return asyncio.run(_kos())


@pytest.fixture
def push_spy(monkeypatch):
    rec: list[dict] = []
    from app import gurultu_akisi

    monkeypatch.setattr(
        gurultu_akisi, "dispatch_external",
        lambda k, **kw: rec.append({"k": k, **kw}),
    )
    return rec


def _bildirimler(d, tip):
    return d.conn.execute(
        "SELECT user_id, mesaj FROM notification WHERE tenant_id=%s "
        "AND tip=%s::notification_tip", (d.tenant, tip)).fetchall()


# ==================== 1) METIN SIZDIRMIYOR ================================ #

def test_SAKIN_METNINDE_sikayetcinin_IZI_YOK():
    """En sert kural: metin ne kisi, ne daire, ne SAYI icerir.

    Sayi yazmak sakini "kim sikayet etti" aramaya iter (bes kisilik bir
    koridorda bes sikayet herkesi isaret eder); mesajin isi davranisi
    degistirmek, muhasebe yapmak degil.
    """
    metin = METINLER["gurultu_uyari_sakin"]
    assert metin.params == ()
    for dil, govde in metin.govde.items():
        assert "{" not in govde, f"{dil}: sablon alani var (sizinti riski)"
    # YEDI DIL PARITESI (kabul kriteri 9).
    assert set(metin.govde) == {"tr", "en", "ar", "ru", "de", "fr", "es"}
    assert set(metin.baslik) == set(metin.govde)


def test_YONETIM_METNINDE_daire_ve_sayi_VAR_sikayetci_YOK():
    """Yoneticinin isi ilgilenmek: karar verebilmesi icin buyuklugu
    bilmeli. Sikayet EDENIN kimligi burada da YOK."""
    metin = METINLER["gurultu_esik_yonetim"]
    assert set(metin.params) == {"daire", "sayi"}
    assert set(metin.govde) == {"tr", "en", "ar", "ru", "de", "fr", "es"}


# ==================== 2) SAKINE UYARI ===================================== #

def test_ESIK_ASILINCA_SAKINE_uyari_gider(d, push_spy):
    sakin = _sakin_ekle(d, "malik")
    for _ in range(5):
        _sikayet(d)
    kayit = _calistir(d)
    assert kayit is not None

    gonderiler = [p for p in push_spy if p["k"] == "gurultu_uyari_sakin"]
    assert len(gonderiler) == 1
    assert list(gonderiler[0]["target_user_ids"]) == [sakin]
    # ROL HEDEFI YOK: uyari kisiye gider.
    assert gonderiler[0]["target_roles"] is None
    # PARAMETRE YOK: metin sabit, sizdiracak deger de yok.
    assert gonderiler[0]["params"] == {}

    # IN-APP SATIR DA YAZILIR: push kapali/basarisiz olabilir.
    satirlar = _bildirimler(d, "gurultu_uyari_sakin")
    assert len(satirlar) == 1 and satirlar[0][0] == sakin


def test_KIRACI_VARSA_yalniz_kiraciya(d, push_spy):
    """Gurultuyu durdurabilecek kisi ORADA OTURANDIR. Oturmayan malike
    "hakkinizda sikayet var" demek, kiraci hakkindaki sikayeti ev
    sahibine ihbar etmektir."""
    _sakin_ekle(d, "malik")
    kiraci = _sakin_ekle(d, "kiraci")
    for _ in range(5):
        _sikayet(d)
    _calistir(d)

    gonderi = next(p for p in push_spy if p["k"] == "gurultu_uyari_sakin")
    assert list(gonderi["target_user_ids"]) == [kiraci]


def test_SAKIN_YOKSA_yalniz_YONETIM(d, push_spy, owner_conn):
    """Kabul kriteri 5. Daire bos: uyari gidecek kimse yok."""
    # Hic sakin EKLENMEDI: daire bos.
    for _ in range(5):
        _sikayet(d)

    kayit = _calistir(d)
    assert kayit is not None
    assert kayit.sakin_bildirildi is False
    assert not [p for p in push_spy if p["k"] == "gurultu_uyari_sakin"]
    # YONETIM yine haberdar (manuel modda "anonsu yapin" bildirimi).
    assert [p for p in push_spy if p["k"] == "gurultu_uyarisi"]


def test_SAKIN_UYARISI_KAPATILABILIR(d, push_spy):
    """Bazi tesisler bunu yonetim eliyle (kapiya not, telefon) yapmak
    isteyebilir."""
    _sakin_ekle(d, "malik")
    d.conn.execute(
        "UPDATE tenant SET gurultu_sakin_uyarisi=false WHERE id=%s",
        (d.tenant,))
    d.conn.commit()
    for _ in range(5):
        _sikayet(d)
    kayit = _calistir(d)
    assert kayit is not None
    assert kayit.sakin_bildirildi is False
    assert not [p for p in push_spy if p["k"] == "gurultu_uyari_sakin"]


# ==================== 3) PENCERE ========================================== #

def test_PENCERE_DISINDAKI_sikayetler_SAYILMAZ(d, push_spy):
    """Bir yil once acilmis ve kapatilmamis bir sikayet, dun geceki kadar
    agirlik tasimamali."""
    _sakin_ekle(d, "malik")
    for _ in range(4):
        _sikayet(d, gun_once=90)   # pencere DISI (varsayilan 30 gun)
    _sikayet(d, gun_once=1)        # pencere ICI
    assert _calistir(d) is None, "eski sikayetler esigi tetikledi"

    for _ in range(4):
        _sikayet(d, gun_once=2)
    assert _calistir(d) is not None


def test_PENCERE_KAPALIYSA_hepsi_sayilir(d):
    """0 = ESKI DAVRANIS (sinirsiz): mevcut tesisler icin kacis kapisi."""
    _sakin_ekle(d, "malik")
    d.conn.execute(
        "UPDATE tenant SET gurultu_pencere_gun=0 WHERE id=%s", (d.tenant,))
    d.conn.commit()
    for _ in range(5):
        _sikayet(d, gun_once=200)
    assert _calistir(d) is not None


# ==================== 4) SUSMA SURESI ===================================== #

def test_SUSMA_SURESINDE_ikinci_uyari_YOK(d, push_spy):
    """Her gece tekrarlanan bir uyari KENDISI gurultuye donusur."""
    _sakin_ekle(d, "malik")
    for _ in range(5):
        _sikayet(d)
    assert _calistir(d) is not None
    ilk = len([p for p in push_spy if p["k"] == "gurultu_uyari_sakin"])

    for _ in range(5):
        _sikayet(d)
    assert _calistir(d) is None, "susma suresinde ikinci uyari uretildi"
    assert len([p for p in push_spy if p["k"] == "gurultu_uyari_sakin"]) == ilk


def test_SUSMA_SURESI_GECINCE_yeniden_uyarilir(d):
    _sakin_ekle(d, "malik")
    for _ in range(5):
        _sikayet(d)
    assert _calistir(d) is not None
    # Uyariyi 10 gun geriye al (susma 7 gun).
    d.conn.execute(
        "UPDATE unit_uyari SET created_at = now() - interval '10 days' "
        "WHERE unit_id = %s", (d.hedef["id"],))
    d.conn.commit()
    for _ in range(5):
        _sikayet(d)
    assert _calistir(d) is not None


# ==================== 5) DENETIM ========================================== #

def test_UYARI_DENETIME_yazilir_KIMLIKSIZ(d):
    """Kabul kriteri 8. Denetim kaydi da bir SIZINTI YUZEYIDIR: kac
    kisiye gittigi yazar, KIM oldugu yazmaz."""
    _sakin_ekle(d, "malik")
    for _ in range(5):
        _sikayet(d)
    _calistir(d)

    satir = d.conn.execute(
        "SELECT meta FROM audit_log WHERE tenant_id=%s "
        "AND resource_type='unit_uyari' ORDER BY ts DESC LIMIT 1",
        (d.tenant,)).fetchone()
    assert satir is not None, "denetim kaydi yazilmadi"
    meta = satir[0]
    assert meta["islem"] == "gurultu_esik"
    assert meta["sayac"] == 5 and meta["esik"] == 5
    assert meta["sakin_bildirimi"] == 1
    # KIMLIK YOK.
    metin = str(meta)
    assert "user_id" not in metin and "sakin_id" not in metin
