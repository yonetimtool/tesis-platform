"""(P209) SIKAYET TIPLERININ SAYACLARI BIRBIRINE KARISMAZ.

===========================================================================
ONCE OLCUM: DURUM ZATEN BOYLEYDI (kismen)
===========================================================================
Kod okundu ve olculdu:
  * `acik_gurultu_sayisi` YALNIZ `kategori='gurultu'` sayiyor,
  * esik sonrasi SIFIRLAMA da yalniz `gurultu` satirlarini kapatiyor,
  * harita/yogunluk (`/unit-complaints/density`) TUM kategorileri
    sayiyor ve bu DEGISMEDI.
Yani "bir tipteki sikayet baska tipin sayacini artirmasin" kurali
zaten geceriydi. EKSIK OLAN sey kapinin CAGRI YERINDE gorunmesiydi:
uc, kategori ne olursa olsun `esik_kontrol` cagiriyordu.

Bu dosya kurali KILITLER: davranis bugun dogru ama hicbir test
"gorunutu sikayeti gurultu sayacini artirmaz" demiyordu — yani kural
bir sonraki turda sessizce bozulabilirdi.

===========================================================================
SURULEN UC SENARYO (istekteki dogrulama listesi)
===========================================================================
  1. 5 GORUNTU sikayeti  -> sesli uyari YOK, gurultu sayaci 0
  2. 5 GURULTU sikayeti  -> sesli uyari VAR
  3. 3 GURULTU + 3 GORUNTU -> hicbiri esigi asmaz
"""
from __future__ import annotations

import uuid

import pytest

from app.gurultu_akisi import CAYDIRICI_KATEGORI

# Sikayet uc(lar)i: hedef daireye kategori bazli sikayet yazip
# `esik_kontrol`u ucun kendi yolundan gecirmek icin `test_p208`in
# yardimcilarini yeniden kullaniyoruz (ayni kurulum, ayni oturum
# hijyeni — P187 dersi).
from .test_p208_gurultu_sakin import (  # noqa: F401 — fixture'lar
    _kullanici,
    _sakin_ekle,
    d,
    push_spy,
)


def _sikayet_yaz(d, kategori: str, adet: int = 1) -> None:
    """Hedef daireye `adet` kadar `kategori` sikayeti yazar."""
    for _ in range(adet):
        uid = _kullanici(d)
        d.conn.execute(
            "INSERT INTO unit_complaint (id, tenant_id, target_unit_id, "
            "complainant_user_id, kategori, durum) "
            "VALUES (%s,%s,%s,%s,%s::unit_complaint_kategori,'acik')",
            (uuid.uuid4(), d.tenant, d.hedef["id"], uid, kategori))
    d.conn.commit()


def _acik(d, kategori: str) -> int:
    return d.conn.execute(
        "SELECT count(*) FROM unit_complaint WHERE target_unit_id=%s "
        "AND kategori=%s::unit_complaint_kategori AND durum='acik'",
        (d.hedef["id"], kategori)).fetchone()[0]


def _calistir(d, kategori: str | None = None):
    """`esik_kontrol`u KENDI dongusunde calistirir (P187)."""
    import asyncio

    from sqlalchemy import select

    from app.db import SessionLocal, engine, set_tenant
    from app.gurultu_akisi import esik_kontrol
    from app.models import Unit

    async def _kos():
        await engine.dispose(close=False)
        try:
            async with SessionLocal() as session:
                async with session.begin():
                    await set_tenant(session, d.tenant)
                    unit = (
                        await session.execute(
                            select(Unit).where(Unit.id == uuid.UUID(d.hedef["id"]))
                        )
                    ).scalar_one()
                    return await esik_kontrol(
                        session, tenant_id=uuid.UUID(str(d.tenant)),
                        unit=unit, kategori=kategori,
                    )
        finally:
            await engine.dispose()

    return asyncio.run(_kos())


def _sesli_gonderiler(push_spy):
    return [p for p in push_spy if p["k"] in (
        "gurultu_uyari_sakin", "gurultu_uyarisi", "gurultu_esik_yonetim")]


# =================== 1) GORUNTU SIKAYETI ESIGI ASMAZ ====================== #

def test_BES_GORUNTU_sikayeti_SESLI_UYARI_URETMEZ(d, push_spy):
    """Kapi onune ayakkabi birakan bir daireye "gurultu uyarisi" anonsu
    yapmak, caydiriciyi anlamsiz kilardi."""
    _sakin_ekle(d, "malik")
    _sikayet_yaz(d, "goruntu_kirliligi", 5)

    assert _calistir(d, "goruntu_kirliligi") is None
    assert _sesli_gonderiler(push_spy) == []
    # GURULTU SAYACI 0 KALDI.
    assert _acik(d, CAYDIRICI_KATEGORI) == 0
    # GORUNTU KAYITLARI DURUYOR: sifirlama onlara DOKUNMADI (harita ve
    # bildirim listesi bu satirlardan besleniyor).
    assert _acik(d, "goruntu_kirliligi") == 5


def test_BES_DIGER_sikayeti_de_SESLI_UYARI_URETMEZ(d, push_spy):
    _sakin_ekle(d, "malik")
    _sikayet_yaz(d, "diger", 5)
    assert _calistir(d, "diger") is None
    assert _sesli_gonderiler(push_spy) == []
    assert _acik(d, CAYDIRICI_KATEGORI) == 0


# ====================== 2) GURULTU ESIGI CALISIR ========================== #

def test_BES_GURULTU_sikayeti_SESLI_UYARI_URETIR(d, push_spy):
    _sakin_ekle(d, "malik")
    _sikayet_yaz(d, CAYDIRICI_KATEGORI, 5)

    kayit = _calistir(d, CAYDIRICI_KATEGORI)
    assert kayit is not None and kayit.sayac == 5
    assert [p["k"] for p in _sesli_gonderiler(push_spy)]
    # SIFIRLAMA YALNIZ GURULTUYU kapatti.
    assert _acik(d, CAYDIRICI_KATEGORI) == 0


def test_GORUNTU_SIKAYETLERI_GURULTU_ESIGINI_ETKILEMEZ(d, push_spy):
    """EN KRITIK KILIT: iki tip AYNI dairede birikiyor. Gorunutu
    satirlari gurultu sayacini ne ARTIRIR ne de esikten sonra KAPANIR."""
    _sakin_ekle(d, "malik")
    _sikayet_yaz(d, "goruntu_kirliligi", 4)
    _sikayet_yaz(d, CAYDIRICI_KATEGORI, 5)

    kayit = _calistir(d, CAYDIRICI_KATEGORI)
    assert kayit is not None
    # SAYAC 5 — 9 DEGIL. Gorunutu satirlari sayima girseydi 9 olurdu.
    assert kayit.sayac == 5, "gorunutu sikayetleri gurultu sayacina girdi"
    assert _acik(d, "goruntu_kirliligi") == 4, "gorunutu satirlari kapandi"


# ================== 3) KARISIK GIRIS: HICBIRI ASMAZ ======================= #

def test_UC_ARTI_UC_hicbir_esigi_ASMAZ(d, push_spy):
    """3 gurultu + 3 gorunutu = 6 acik sikayet ama HICBIR TIP 5'e
    ulasmadi. Tipler toplansaydi esik asilir ve daire haksiz yere
    uyarilirdi."""
    _sakin_ekle(d, "malik")
    _sikayet_yaz(d, CAYDIRICI_KATEGORI, 3)
    _sikayet_yaz(d, "goruntu_kirliligi", 3)

    assert _calistir(d, CAYDIRICI_KATEGORI) is None
    assert _calistir(d, "goruntu_kirliligi") is None
    assert _sesli_gonderiler(push_spy) == []
    # ALTI KAYIT DA DURUYOR (harita bunlari sayiyor — degismedi).
    assert _acik(d, CAYDIRICI_KATEGORI) == 3
    assert _acik(d, "goruntu_kirliligi") == 3


# ================== 4) KAPI CAGRI YERINDE (P209) ========================== #

def test_GURULTU_DISI_KATEGORIDE_ESIK_HESABI_HIC_CALISMAZ(d, push_spy):
    """Kategori kapisi: gurultu disi sikayette esik hesabi HIC
    calismamali (bes sorgu bosuna kosmasin). Gurultu sayaci esikte
    OLSA BILE gorunutu sikayetiyle tetiklenmez."""
    _sakin_ekle(d, "malik")
    # Gurultu sayaci ZATEN esikte:
    _sikayet_yaz(d, CAYDIRICI_KATEGORI, 5)

    # ...ama gelen sikayet GORUNTU: uyari URETILMEZ.
    assert _calistir(d, "goruntu_kirliligi") is None
    assert _sesli_gonderiler(push_spy) == []
    assert _acik(d, CAYDIRICI_KATEGORI) == 5, "gurultu satirlari kapandi"

    # Ayni durumda GURULTU sikayeti gelirse uyari URETILIR.
    assert _calistir(d, CAYDIRICI_KATEGORI) is not None


# ====================== 5) HARITA DEGISMEDI =============================== #

def test_HARITA_TUM_KATEGORILERI_SAYMAYA_devam_ediyor(d, client, world):
    """Istegin acik sarti: "harita degismesin". Yogunluk TUM acik
    sikayetleri sayar — tip ayrimi YALNIZ sesli caydiricidadir."""
    _sikayet_yaz(d, CAYDIRICI_KATEGORI, 2)
    _sikayet_yaz(d, "goruntu_kirliligi", 2)
    _sikayet_yaz(d, "diger", 1)

    yog = client.get("/unit-complaints/density", headers=d.yonetici).json()
    satir = next(x for x in yog["items"]
                 if x["target_unit_id"] == d.hedef["id"])
    assert satir["acik_sayisi"] == 5, "harita kategoriye gore daraldi"
