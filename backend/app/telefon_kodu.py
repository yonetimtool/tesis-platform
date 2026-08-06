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
from .mesajlasma import LogSmsSaglayici
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
) -> None:
    """Ayni amac icin bekleyen kodu EZER ve yenisini gonderir.

    Ezme bilincli: art arda istenen kodlarin HEPSININ gecerli kalmasi,
    saldirgana ayni anda bes gecerli hedef verirdi.
    """
    kod = f"{secrets.randbelow(1_000_000):06d}"
    await session.execute(
        text(
            "DELETE FROM kayit_dogrulama WHERE telefon = :p AND amac = :a "
            "AND durum = 'telefon_bekliyor'"
        ),
        {"p": telefon, "a": amac},
    )
    session.add(
        KayitDogrulama(
            tenant_id=tenant_id,
            unit_id=unit_id,
            telefon=telefon,
            amac=amac,
            kod_hash=hash_password(kod),
            son_gecerlilik=datetime.now(timezone.utc)
            + timedelta(minutes=KOD_OMRU_DK),
        )
    )
    # SMS saglayici bugun LOG saglayicisidir: kod kullaniciya ULASMAZ.
    # Gercek gecit baglanmasi YAPILANDIRMA isidir (mesajlasma.MesajSaglayici).
    LogSmsSaglayici().gonder(
        telefon, None, f"Yönetio doğrulama kodunuz: {kod} ({KOD_OMRU_DK} dk)"
    )


async def kodu_dogrula(
    session: AsyncSession, *, telefon: str, kod: str, amac: str
) -> KayitDogrulama:
    """Dogru ise kaydi doner; her basarisiz yolda `GECERSIZ` firlatir."""
    from sqlalchemy import select

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
