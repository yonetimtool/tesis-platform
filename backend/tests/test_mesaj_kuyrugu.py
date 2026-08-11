"""(P154 / Asama 9) MESAJ KUYRUGU — yeniden deneme.

Olculen bes sey:
  1. Basarisiz gonderim ARTIK SON SOZ DEGIL: satir KUYRUGA girer,
  2. Geri cekilme UYGULANIR (vadesi gelmeyen satir denenmez),
  3. MAX_DENEME'de durur ve `basarisiz` olarak KAPANIR — "kuyrukta"
     birakmak, bir daha hic denenmeyecek satiri bekliyor gostermekti,
  4. Basarili yeniden deneme satiri KAPATIR ve hatayi temizler,
  5. Politika KOPYALANMADI: webhook kuyruguyla AYNI egriyi kullanir.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

import pytest

UTC = timezone.utc


# ==================== 5) POLITIKA TEK KAYNAKTAN ============================ #

def test_POLITIKA_webhook_kuyruguyla_AYNI():
    """Iki politika tutmak, "neden SMS 3 kez ama webhook 5 kez deneniyor"
    sorusunu cevapsiz birakirdi."""
    from app import gurultu
    from app.yeniden_deneme import gecikme

    for i in range(4):
        assert gurultu.yeniden_deneme_gecikmesi(i) == gecikme(i)


def test_GERI_CEKILME_katlanir():
    """Sabit aralik, dusmus bir uca dakikada bir vurmak olurdu."""
    from app.yeniden_deneme import gecikme

    assert [int(gecikme(i).total_seconds() // 60) for i in range(3)] == [1, 5, 25]


def test_MAX_DENEMEDE_durur():
    from app.mesaj_kuyruk import MAX_DENEME
    from app.yeniden_deneme import denenmeli

    assert denenmeli(
        deneme=MAX_DENEME, son_deneme_at=None,
        simdi=datetime.now(tz=UTC), max_deneme=MAX_DENEME,
    ) is False


def test_HIC_DENENMEMIS_kayit_HEMEN_denenir():
    from app.yeniden_deneme import denenmeli

    assert denenmeli(
        deneme=0, son_deneme_at=None, simdi=datetime.now(tz=UTC), max_deneme=3
    ) is True


# ==================== 1-4) KUYRUK DAVRANISI (gercek DB) ==================== #

@pytest.fixture
def kuyruk_satiri(owner_conn, world):
    """Kuyrukta bekleyen bir gonderim satiri uretir ve kimligini doner."""
    def _yarat(*, deneme: int = 1, son_deneme_at: datetime | None = None):
        with owner_conn.cursor() as cur:
            cur.execute("SELECT id FROM tenant WHERE slug = %s", (world["slug_a"],))
            tid = cur.fetchone()[0]
            cur.execute(
                "INSERT INTO mesaj_gonderim (tenant_id, kanal, amac, hedef, "
                " govde, durum, deneme, son_deneme_at, hata) "
                "VALUES (%s,'sms'::mesaj_kanal,'operasyonel'::mesaj_amac,%s,"
                " 'deneme',%s,%s,%s,'once dustu') RETURNING id",
                (tid, f"+9053{uuid.uuid4().int % 10**8:08d}",
                 "kuyrukta", deneme, son_deneme_at),
            )
            return tid, cur.fetchone()[0]
    return _yarat


def _durum(owner_conn, kid):
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT durum, deneme, hata FROM mesaj_gonderim WHERE id = %s", (kid,)
        )
        return cur.fetchone()


def _taze_oturum():
    """BU TESTLERE OZEL motor + oturum fabrikasi.

    Paylasilan `app.db.engine` ilk kullanildigi EVENT LOOP'a baglanir;
    tam takimda baska bir test dosyasi onu kendi dongusunde acmis oluyor
    ve buradaki `asyncio.run` "Event loop is closed" ile dusuyordu
    (olculdu: dosya TEK BASINA gecerken tam takimda dusuyordu — yani
    kusur urunde degil, TEST KURULUMUNDA).

    Kendi motorunu kurmak bu baglanmayi tumden ortadan kaldirir.
    """
    from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

    from app.config import settings

    motor = create_async_engine(settings.database_url, poolclass=None)
    return motor, async_sessionmaker(motor, expire_on_commit=False)


class _DusenSaglayici:
    """HER ZAMAN basarisiz donen sahte saglayici.

    NEDEN GEREKLI: gercek saglayici bu ortamda BASARILI donuyor (olculdu)
    ve kuyrugun tukenme yolu hic kosmuyordu — test yanlis bir varsayimla
    yazilmisti. Kuyrugun KARARI saglayicidan bagimsiz olculmeli.
    """

    ad = "sahte"

    def gonder(self, hedef, konu, govde):
        from app.gonderim import GonderimSonucu

        return GonderimSonucu("basarisiz", self.ad, hata="sahte_ariza")


async def _isle_cok(tenant_id, anlar, *, saglayici=None):
    """Birden fazla turu TEK EVENT LOOP icinde kosar.

    Her tur icin ayri `asyncio.run` cagirmak, asyncpg havuzunu ILK
    donguye baglar ve ikinci cagri "Event loop is closed" ile duser —
    olculdu. Bu, urunun degil KOSUMUN kisitidir.
    """
    from sqlalchemy import text

    from app import mesaj_kuyruk
    from app.mesaj_kuyruk import kuyrugu_isle

    motor, SessionLocal = _taze_oturum()
    onceki = mesaj_kuyruk.kanal_saglayicisi
    if saglayici is not None:
        mesaj_kuyruk.kanal_saglayicisi = lambda _kanal: saglayici

    toplam = 0
    try:
      for an in anlar:
        async with SessionLocal() as db:
            await db.execute(
                text("SELECT set_config('app.current_tenant_id', :t, true)"),
                {"t": str(tenant_id)},
            )
            toplam += await kuyrugu_isle(db, simdi=an)
            await db.commit()
    finally:
        mesaj_kuyruk.kanal_saglayicisi = onceki
        await motor.dispose()
    return toplam


async def _isle(tenant_id, simdi):
    from sqlalchemy import text

    from app.mesaj_kuyruk import kuyrugu_isle

    motor, SessionLocal = _taze_oturum()
    try:
        async with SessionLocal() as db:
            await db.execute(
                text("SELECT set_config('app.current_tenant_id', :t, true)"),
                {"t": str(tenant_id)},
            )
            n = await kuyrugu_isle(db, simdi=simdi)
            await db.commit()
            return n
    finally:
        await motor.dispose()


def test_VADESI_GELMEYEN_satir_DENENMEZ(owner_conn, kuyruk_satiri):
    """1. denemeden sonra geri cekilme 1 dakika: hemen tekrar denemek,
    geri cekilmeyi hic uygulamamak olurdu."""
    import asyncio

    simdi = datetime.now(tz=UTC)
    tid, kid = kuyruk_satiri(deneme=1, son_deneme_at=simdi)
    islenen = asyncio.run(_isle(tid, simdi + timedelta(seconds=10)))

    durum, deneme, _ = _durum(owner_conn, kid)
    assert islenen == 0, "vadesi gelmemis satir denendi"
    assert (durum, deneme) == ("kuyrukta", 1)


def test_VADESI_GELEN_satir_DENENIR_ve_MAX_DENEMEDE_kapanir(owner_conn, kuyruk_satiri):
    """Saglayici yapilandirilmamis (test ortami) -> her deneme basarisiz.

    MAX_DENEME'ye ulasinca satir `basarisiz` olur; `kuyrukta` birakmak,
    bir daha HIC denenmeyecek bir satiri "bekliyor" gostermek olurdu.
    """
    import asyncio

    from app.mesaj_kuyruk import MAX_DENEME

    simdi = datetime.now(tz=UTC)
    tid, kid = kuyruk_satiri(deneme=1, son_deneme_at=simdi - timedelta(hours=1))

    # Kalan denemeleri sirayla tuket; her turda vadeyi acikca gecir.
    anlar = [simdi + timedelta(days=g + 1) for g in range(MAX_DENEME)]
    asyncio.run(_isle_cok(tid, anlar, saglayici=_DusenSaglayici()))

    durum, deneme, hata = _durum(owner_conn, kid)
    assert deneme == MAX_DENEME
    assert durum == "basarisiz", "tukenmis satir hâlâ kuyrukta gorunuyor"
    assert hata, "neden basarisiz oldugu yazilmamis"


def test_BASKA_TESISIN_kuyrugu_ISLENMEZ(owner_conn, kuyruk_satiri, world):
    """RLS bootstrap'i: her tenant KENDI baglaminda islenir."""
    import asyncio

    simdi = datetime.now(tz=UTC)
    tid_a, kid = kuyruk_satiri(deneme=1, son_deneme_at=simdi - timedelta(hours=1))
    with owner_conn.cursor() as cur:
        cur.execute("SELECT id FROM tenant WHERE slug = %s", (world["slug_b"],))
        tid_b = cur.fetchone()[0]

    asyncio.run(_isle(tid_b, simdi + timedelta(hours=2)))
    durum, deneme, _ = _durum(owner_conn, kid)
    assert (durum, deneme) == ("kuyrukta", 1), "B tesisi A'nin kuyrugunu isledi"


def test_TUR_BASINA_UST_SINIR_var():
    """Sinirsiz okumak, birikmis bir kuyrukta tek turun dakikalarca
    surmesi ve bir sonraki turla cakismasi demekti."""
    from app.mesaj_kuyruk import TUR_BASINA_UST_SINIR

    assert 0 < TUR_BASINA_UST_SINIR <= 1000


def test_BEAT_gorevi_KAYITLI():
    """Kuyruk yazilip beat'e baglanmazsa hicbir sey islenmez ve bu
    SESSIZ olurdu — satirlar sonsuza dek "kuyrukta" kalirdi."""
    from app.celery_app import celery_app

    assert "mesaj-kuyrugu" in celery_app.conf.beat_schedule
    assert (
        celery_app.conf.beat_schedule["mesaj-kuyrugu"]["task"]
        == "scheduler.mesaj_kuyrugu"
    )
