"""(P154 / Asama 9) MESAJ KUYRUGU — basarisiz gonderimleri yeniden dener.

===========================================================================
NEDEN ISTEK YOLUNDA DEGIL
===========================================================================
Brief: "Kuyruk + yeniden deneme."

Bugune kadar gonderim ISTEK ICINDE senkron yapiliyordu ve saglayici bir
kez basarisiz olunca kayit `basarisiz` yazilip BIRAKILIYORDU. Yani
saglayicinin bes saniyelik bir kesintisi, uc yuz kisilik bir duyurunun
kalici olarak eksik gitmesi demekti.

Yeniden denemeyi istegin icine koymak da cozum DEGILDI: yoneticinin
tarayicisini saglayicinin geri-cekilme suresi boyunca bekletirdi.

===========================================================================
POLITIKA KOPYALANMADI
===========================================================================
Geri cekilme egrisi P37'de (caydirici webhook kuyrugu) zaten yaziliydi ve
`yeniden_deneme.py`ye tasindi; burasi onu KULLANIR. Iki politika tutmak,
"neden SMS 3 kez ama webhook 5 kez deneniyor" sorusunu cevapsiz
birakirdi.

MAX_DENEME AYRI: webhook bir DIS SISTEME, SMS bir SAGLAYICIYA gider.
Ortak olan ZAMANLAMA egrisi, sayi degil.

===========================================================================
KALICI HATA AYIRT EDILEMIYOR — DURUSTCE
===========================================================================
"Numara gecersiz" ile "saglayici dustu" bizim icin AYNI gorunuyor:
`GonderimSonuc` bir hata METNI tasiyor, sinif degil. Bu yuzden deneme
sayisi DUSUK tutuldu (3): kalici bir hatada uc kez denemek, sinirsiz
denemekten cok daha ucuz ve gecici bir kesintiyi de fazlasiyla asar.
Saglayici hata taksonomisi eklendiginde dogru yer burasidir.

===========================================================================
KOTA: DENEME DEGIL MESAJ SAYILIR
===========================================================================
Yeniden deneme YENI BIR SATIR ACMAZ, var olani gunceller — dolayisiyla
gunluk kota (`gonderim.kota_kontrol`, `mesaj_gonderim` satirlarini sayar)
yeniden denemelerden ETKILENMEZ. Bilincli: kota "kac kisiye ulastik"
sorusunun siniridir, "kac kez denedik" sorusunun degil. Aksi hâlde dusuk
bir saglayici, kotayi kendi arizasiyla tuketirdi.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

import psycopg
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from .config import settings
from .db import SessionLocal
from .gonderim import saglayici as kanal_saglayicisi
from .models import MesajGonderim
from .yeniden_deneme import denenmeli

#: Bkz. modul basligi — kalici hata ayirt edilemedigi icin DUSUK tutuldu.
MAX_DENEME = 3

#: Tek turda islenecek en fazla satir. Sinirsiz okumak, birikmis bir
#: kuyrukta tek bir turun dakikalarca surmesi ve bir sonraki turla
#: cakismasi demekti.
TUR_BASINA_UST_SINIR = 200


async def kuyrugu_isle(db: AsyncSession, *, simdi: datetime | None = None) -> int:
    """TEK TENANT baglaminda vadesi gelmis kuyruk satirlarini dener.

    Cagiran `app.current_tenant_id`i AYARLAMIS olmali (RLS).
    Doner: islenen satir sayisi.
    """
    an = simdi or datetime.now(tz=timezone.utc)
    satirlar = (
        (await db.execute(
            select(MesajGonderim)
            .where(
                MesajGonderim.durum == "kuyrukta",
                MesajGonderim.deneme < MAX_DENEME,
            )
            .order_by(MesajGonderim.created_at)
            .limit(TUR_BASINA_UST_SINIR)
        )).scalars().all()
    )

    islenen = 0
    for kayit in satirlar:
        if not denenmeli(
            deneme=kayit.deneme,
            son_deneme_at=kayit.son_deneme_at,
            simdi=an,
            max_deneme=MAX_DENEME,
        ):
            continue

        sonuc = kanal_saglayicisi(kayit.kanal).gonder(
            kayit.hedef, kayit.konu, kayit.govde
        )
        kayit.deneme += 1
        kayit.son_deneme_at = an
        kayit.saglayici = sonuc.saglayici
        if sonuc.durum == "basarisiz":
            kayit.hata = sonuc.hata
            # SON DENEMEDEYSE ARTIK KUYRUKTA DEGIL: `kuyrukta` birakmak,
            # bir daha hic denenmeyecek bir satiri "bekliyor" gostermek
            # olurdu ve kullanici bosuna beklerdi.
            if kayit.deneme >= MAX_DENEME:
                kayit.durum = "basarisiz"
        else:
            kayit.durum = sonuc.durum
            kayit.hata = None
        islenen += 1

    await db.flush()
    return islenen


def _tenant_idler() -> list[uuid.UUID]:
    """Tenant LISTESI app_rw ile okunamaz (baglam yokken hicbir satir
    gorunmez); enumerasyon OWNER baglantisiyla yapilir."""
    with psycopg.connect(
        settings.owner_dsn, autocommit=True, connect_timeout=10
    ) as conn:
        return [r[0] for r in conn.execute("SELECT id FROM tenant").fetchall()]


async def tum_tenantlar_icin() -> int:
    """Butun tenantlarin kuyrugunu isler — her biri KENDI baglaminda.

    Ayrim RLS bootstrap'i icindir (P37'deki `gurultu_kuyruk` ile ayni
    gerekce): bir tenant'in kuyrugu digerine sizmaz.
    """
    toplam = 0
    for tenant_id in _tenant_idler():
        async with SessionLocal() as db:
            await db.execute(
                text("SELECT set_config('app.current_tenant_id', :t, true)"),
                {"t": str(tenant_id)},
            )
            toplam += await kuyrugu_isle(db)
            await db.commit()
    return toplam
