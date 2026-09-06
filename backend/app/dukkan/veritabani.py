"""Dukkan'in KENDI veritabani baglantisi — `dukkan_app` roluyle.

===========================================================================
NEDEN AYRI ENGINE
===========================================================================
Yonetiyor'un engine'i (`app.db.engine`) `app_rw` roluyle baglanir ve o rol
`public` semasindaki her seyi okuyup yazabilir. Dukkan o engine'i
kullansaydi, "Yonetiyor veritabanina dokunma" kisiti yalnizca bir kod
inceleme kuralina indirgenirdi.

Ayri engine + ayri rol, kisiti VERITABANINA gomuyor:
    SELECT * FROM public.app_user  ->  permission denied for table app_user
(`tests/test_dukkan_sinir.py` bunu olcuyor.)

===========================================================================
HAVUZ BOYUTU AYRI VE KUCUK
===========================================================================
Dukkan `api` sureci icinde yasiyor ve ayni PostgreSQL'e ikinci bir havuz
aciyor. Yonetiyor'un havuzuyla ayni boyutta olsaydi toplam baglanti
IKIYE KATLANIRDI — ve tek sunucuda baglanti kit kaynak: P187'de prod'da
idle-in-transaction 90/100 goruldu, kok neden buydu.

Bu yuzden varsayilan havuz KUCUK. SEO trafigi olculdukten sonra
buyutulebilir; once olcum, sonra buyutme.
"""
from __future__ import annotations

from collections.abc import AsyncIterator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from ..config import settings

engine = create_async_engine(
    settings.dukkan_database_url,
    echo=settings.sql_echo,
    pool_pre_ping=True,
    pool_size=settings.dukkan_db_pool_size,
    max_overflow=settings.dukkan_db_max_overflow,
    pool_timeout=settings.db_pool_timeout,
    pool_recycle=settings.db_pool_recycle,
    connect_args={
        "server_settings": {
            "idle_in_transaction_session_timeout": str(settings.db_idle_tx_timeout_ms),
            # Dukkan tablolari `dukkan` semasinda. `search_path`i burada
            # sabitlemek, her sorguda sema adini yazma zorunlulugunu
            # kaldirir AMA `public`i BILEREK disarida birakir: bir sorgu
            # yanlislikla Yonetiyor tablosuna uzanirsa "relation does not
            # exist" alir ve hata GORULUR. `public`i search_path'e koymak,
            # o hatayi sessiz bir izin hatasina cevirirdi.
            "search_path": "dukkan",
        }
    },
)

SessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)


async def get_dukkan_session() -> AsyncIterator[AsyncSession]:
    """FastAPI bagimliligi — Dukkan oturumu.

    Yonetiyor'un `get_session`i gibi transaction'li; ancak `set_tenant`
    YOK: Dukkan cok-kiracili degil (bkz. docs/dukkan/00-mimari.md K4).
    Izolasyon sinirI `isletme.sahip_kullanici_id` uzerinden acik
    kontrolle saglaniyor ve her ozel uc icin IDOR testi zorunlu.
    """
    async with SessionLocal() as session:
        async with session.begin():
            yield session
