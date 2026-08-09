"""(P149) Telefon kodu — kayit, giris ve hesap silme icin TEK mekanizma.

Guvenlik ozellikleri burada TEK YERDE duruyor; her cagiran ayni korumayi
alir:
  * kod DUZ METIN tutulmaz (bcrypt hash) ve gunluge yazilmaz (P134),
  * sureli,
  * deneme sayaci AYRI OTURUMDA kalicilastirilir — ayni islemde tutmak
    onu geri sardiriyordu ve koruma HIC CALISMIYORDU (P148'de olculdu),
  * `amac` ayrimi: giris icin uretilen kod hesap silmeyi ONAYLAYAMAZ.
"""
from __future__ import annotations

import secrets
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import text, update
from sqlalchemy.ext.asyncio import AsyncSession

from .db import SessionLocal, set_tenant
from .errors import APIError
from .mesajlasma import sms_saglayicisi
from .models import KayitDogrulama
from .security import hash_password, verify_password

KOD_OMRU_DK = 10
MAX_DENEME = 5

#: Adimlari ayirt ETTIRMEYEN tek hata. "kod yanlis" ile "boyle kullanici yok"
#: arasindaki fark, kayitli numaralarin disariya sizmasi demekti.
GECERSIZ = APIError(422, "invalid_code", "kod_gecersiz")


async def kod_uret_ve_gonder(
    session: AsyncSession,
    *,
    tenant_id: uuid.UUID,
    telefon: str,
    amac: str,
    unit_id: uuid.UUID | None = None,
    user_id: uuid.UUID | None = None,
) -> None:
    """Ayni amac icin bekleyen kodu EZER ve yenisini gonderir.

    Ezme bilincli: art arda istenen kodlarin HEPSININ gecerli kalmasi,
    saldirgana ayni anda bes gecerli hedef verirdi.
    """
    kod = f"{secrets.randbelow(1_000_000):06d}"
    # (P154) EZME TENANT SINIRINI GECER — bu yuzden duz DELETE degil,
    # SECURITY DEFINER fonksiyon. `uq_kayit_acik_basvuru` KISMI ve GLOBAL
    # bir benzersizlik indeksidir: bir telefon TUM PLATFORMDA tek acik
    # basvuru tasiyabilir. Kisi A sitesinde kayda baslayip B sitesinde
    # kaydolmaya calisirsa B'nin INSERT'i A'nin satiriyla catisir.
    # RLS acildiktan sonra duz DELETE yalniz KENDI tenant'ini gorur, A'nin
    # satirini SILEMEZ ve INSERT benzersizlik ihlaliyle 500 verirdi.
    # Fonksiyonun semantigi eski DELETE ile BIRE BIR ayni (ayni telefon,
    # ayni amac, yalniz `telefon_bekliyor`); degisen tek sey tenant
    # sinirini gecmesi. Bkz. goc 0042.
    await session.execute(
        text("SELECT public.kayit_dogrulama_acik_temizle(:p, :a)"),
        {"p": telefon, "a": amac},
    )
    session.add(
        KayitDogrulama(
            tenant_id=tenant_id,
            unit_id=unit_id,
            # (P154) `user_id` DOLU ise satir bir ROL KAYDIDIR (hesap var,
            # sahipleniliyor); NULL ise P148 basvurusudur (hesap henuz yok).
            # Iki akis ayni tabloyu ve ayni `amac` degerini paylasir; ayrim
            # bu sutundadir. Bkz. routers/auth.py rol-kayit bolumu.
            user_id=user_id,
            telefon=telefon,
            amac=amac,
            kod_hash=hash_password(kod),
            son_gecerlilik=datetime.now(timezone.utc)
            + timedelta(minutes=KOD_OMRU_DK),
        )
    )
    # (P150) Saglayici YAPILANDIRMADAN gelir: `SMS_SAGLAYICI` verilmemisse
    # LOG'dur ve kod kullaniciya ULASMAZ. Gonderim hatasi kaydi KIRMAZ —
    # kod yazilmistir, kullanici "tekrar gonder" diyebilir.
    sms_saglayicisi().gonder(
        telefon, None, f"Yönetio doğrulama kodunuz: {kod} ({KOD_OMRU_DK} dk)"
    )


async def tenant_baglamini_kur(
    session: AsyncSession, *, telefon: str, amac: str
) -> uuid.UUID | None:
    """(P154) KIMLIK ONCESI tenant baglamini kurar; kuramazsa `None`.

    `kayit_dogrulama` artik RLS altinda (goc 0042) ve bu tablo, kullanicinin
    HENUZ OTURUMU YOKKEN okunuyor. Satiri gormek icin once tenant baglami
    gerekiyor, tenant'i ogrenmek icin de satiri gormek — dongu, YALNIZ
    tenant kimligi donduren bir SECURITY DEFINER fonksiyonla kirilir
    (`tenant_id_by_slug` / `tenant_id_by_phone` ile ayni desen).

    OTURUMUN BAGLAMI ZATEN VARSA DEGISTIRILMEZ, DOGRULANIR: `/me/*`
    uclari `get_tenant_db` ile gelir ve baglami kuruludur. Orada baglami
    ezmek, bir kullanicinin baska bir tesisin satirina ulasmasina acilan
    kapi olurdu. Uyusmuyorsa `None` doneriz ve cagiran "gecersiz kod" der —
    ayrimi disariya SIZDIRMADAN.
    """
    mevcut = (
        await session.execute(
            text("SELECT current_setting('app.current_tenant_id', true)")
        )
    ).scalar()
    cozulen = (
        await session.execute(
            text("SELECT public.kayit_dogrulama_tenant_coz(:p, :a)"),
            {"p": telefon, "a": amac},
        )
    ).scalar_one_or_none()
    if cozulen is None:
        return None
    if mevcut:
        return cozulen if str(cozulen) == str(mevcut) else None
    await set_tenant(session, cozulen)
    return cozulen


async def kodu_dogrula(
    session: AsyncSession, *, telefon: str, kod: str, amac: str
) -> KayitDogrulama:
    """Dogru ise kaydi doner; her basarisiz yolda `GECERSIZ` firlatir."""
    from sqlalchemy import select

    if await tenant_baglamini_kur(session, telefon=telefon, amac=amac) is None:
        raise GECERSIZ

    kayit = (
        await session.execute(
            select(KayitDogrulama).where(
                KayitDogrulama.telefon == telefon,
                KayitDogrulama.amac == amac,
                KayitDogrulama.durum == "telefon_bekliyor",
            )
        )
    ).scalar_one_or_none()
    if kayit is None:
        raise GECERSIZ
    if kayit.son_gecerlilik < datetime.now(timezone.utc):
        raise GECERSIZ
    if kayit.deneme >= MAX_DENEME:
        raise GECERSIZ
    if not verify_password(kod, kayit.kod_hash):
        # SAYAC AYRI OTURUMDA: bu istek hata ile bitecek ve cagiranin
        # islemi geri sarilacak — ayni oturumda tutmak sayaci SIFIRLARDI.
        async with SessionLocal() as s2:
            async with s2.begin():
                await set_tenant(s2, kayit.tenant_id)
                await s2.execute(
                    update(KayitDogrulama)
                    .where(KayitDogrulama.id == kayit.id)
                    .values(deneme=KayitDogrulama.deneme + 1)
                )
        raise GECERSIZ
    return kayit
