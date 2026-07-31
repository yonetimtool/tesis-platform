"""Gurultu caydiricisinin AKISI (P37) — esik kontrolu, gonderim, sifirlama.

Cekirdek karar `app.gurultu`dadir (saf); burasi veritabani ve HTTP ile
konusur. Sikayet ucundan cagrilir ve UCU ASLA DUSURMEZ: caydiricinin
basarisiz olmasi sikayetin kaydedilmesini engellememeli — sikayet
kullanicinin beyanidir, caydirici sistemin tepkisidir.
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone

from fastapi.concurrency import run_in_threadpool
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from .crypto import decrypt_secret
from .gurultu import (
    MAX_DENEME,
    esik_asildi,
    govde_uret,
    imzala,
    uyari_metni,
)
from .models import Integration, Tenant, Unit, UnitComplaint, UnitUyari
from .safe_http import SSRFBlocked, send_webhook
from .scheduler.notify import dispatch_external

logger = logging.getLogger(__name__)

#: Manuel modda anonsu yapacak roller.
_MANUEL_ROLLER: tuple[str, ...] = ("admin", "yonetici")


async def acik_gurultu_sayisi(db: AsyncSession, unit_id: uuid.UUID) -> int:
    """YALNIZ `gurultu` kategorisi sayilir.

    Kapi onune ayakkabi birakan bir daireye "gurultu uyarisi" anonsu
    yapmak, caydiriciyi anlamsiz kilardi — P24'un renk skalasi TUM
    kategorileri sayar ama CAYDIRICI gurulyuye ozeldir.
    """
    return (
        await db.execute(
            select(func.count())
            .select_from(UnitComplaint)
            .where(
                UnitComplaint.target_unit_id == unit_id,
                UnitComplaint.kategori == "gurultu",
                UnitComplaint.durum == "acik",
            )
        )
    ).scalar_one()


async def _gonder(
    db: AsyncSession, entegrasyon: Integration, govde: bytes
) -> tuple[bool, str | None]:
    """HMAC imzali webhook gonderimi (SSRF kapisindan gecerek)."""
    zaman = int(datetime.now(tz=timezone.utc).timestamp())
    headers = dict(entegrasyon.headers_json or {})
    headers["Content-Type"] = "application/json"
    headers["X-Yonetio-Timestamp"] = str(zaman)
    if entegrasyon.auth_secret_enc:
        gizli = decrypt_secret(entegrasyon.auth_secret_enc)
        headers["X-Yonetio-Signature"] = f"sha256={imzala(gizli, govde, zaman)}"
    # SIR YOKSA IMZA DA YOK: bos bir sirla imza uretmek, alicinin
    # dogruladigini sanip aslinda hicbir sey dogrulamamasi olurdu.

    try:
        sonuc = await run_in_threadpool(
            send_webhook,
            entegrasyon.http_method or "POST",
            entegrasyon.endpoint_url,
            headers=headers,
            content=govde,
        )
    except SSRFBlocked as exc:
        return False, str(exc)[:300]
    return sonuc.ok, (sonuc.error or None if not sonuc.ok else None)


async def esik_kontrol(
    db: AsyncSession, *, tenant_id: uuid.UUID, unit: Unit
) -> UnitUyari | None:
    """Esik asildiysa uyariyi olustur, gonder ve SAYACI SIFIRLA.

    Donus: olusturulan uyari (yoksa None). Cagiran bunu YOK SAYABILIR —
    sikayet kaydi bu fonksiyonun sonucuna bagli DEGILDIR.
    """
    tenant = (await db.execute(select(Tenant))).scalar_one_or_none()
    if tenant is None:
        return None

    sayac = await acik_gurultu_sayisi(db, unit.id)
    if not esik_asildi(sayac, tenant.gurultu_esigi):
        return None

    metin = uyari_metni(tenant.gurultu_uyari_metni)
    entegrasyon = None
    if tenant.gurultu_integration_id is not None:
        entegrasyon = (
            await db.execute(
                select(Integration).where(
                    Integration.id == tenant.gurultu_integration_id,
                    Integration.aktif.is_(True),
                )
            )
        ).scalar_one_or_none()

    kayit = UnitUyari(
        tenant_id=tenant_id,
        unit_id=unit.id,
        esik=tenant.gurultu_esigi,
        sayac=sayac,
        metin=metin,
        kanal="webhook" if entegrasyon is not None else "manuel",
        durum="manuel_bekliyor",
    )

    if entegrasyon is not None:
        govde = govde_uret(
            daire_no=unit.no, metin=metin,
            zaman=datetime.now(tz=timezone.utc),
        )
        ok, hata = await _gonder(db, entegrasyon, govde)
        kayit.deneme = 1
        kayit.son_deneme_at = datetime.now(tz=timezone.utc)
        kayit.durum = "gonderildi" if ok else "basarisiz"
        kayit.hata = hata
    else:
        # MANUEL MOD: yoneticiye bildirim gider, anonsu o yapar. Bu bir
        # hata durumu DEGIL — cogu sitede entegrasyon hic olmayacak.
        dispatch_external(
            "gurultu_uyarisi",
            tenant_id=tenant_id,
            target_roles=_MANUEL_ROLLER,
            params={"daire": unit.no, "sayi": sayac},
            data={"tip": "gurultu_uyarisi", "unit_id": str(unit.id)},
        )

    db.add(kayit)

    # SIFIRLAMA: kayitlar GECMISTE DURUR, yalnizca durum kapaniyor —
    # silmek, uyarinin dayanagini yok etmek olurdu. P24 renk skalasi ACIK
    # sayisindan hesaplandigi icin daire dogal olarak yesile doner; ayri bir
    # "sifirlama rengi" yoktur.
    await db.execute(
        update(UnitComplaint)
        .where(
            UnitComplaint.target_unit_id == unit.id,
            UnitComplaint.kategori == "gurultu",
            UnitComplaint.durum == "acik",
        )
        .values(durum="kapali", updated_at=func.now())
    )
    await db.flush()
    logger.info(
        "NOISE_DETERRENT tenant=%s unit=%s sayac=%s kanal=%s durum=%s",
        tenant_id, unit.id, sayac, kayit.kanal, kayit.durum,
    )
    return kayit


async def kuyrugu_isle(
    db: AsyncSession, *, simdi: datetime | None = None
) -> int:
    """Basarisiz webhook uyarilarini geri-cekilmeli yeniden dener.

    Istek yolunda DEGIL ayri bir gorevde calisir: kullanicinin sikayet
    kaydini, dis bir ucun yavasligina baglamak olurdu. Donus: yeniden
    denenen satir sayisi.
    """
    from .gurultu import yeniden_denenmeli

    simdi = simdi or datetime.now(tz=timezone.utc)
    bekleyen = (
        (await db.execute(
            select(UnitUyari).where(
                UnitUyari.durum == "basarisiz",
                UnitUyari.deneme < MAX_DENEME,
            ).order_by(UnitUyari.created_at).limit(100)
        )).scalars().all()
    )
    if not bekleyen:
        return 0

    tenant = (await db.execute(select(Tenant))).scalar_one_or_none()
    entegrasyon = None
    if tenant is not None and tenant.gurultu_integration_id is not None:
        entegrasyon = (
            await db.execute(
                select(Integration).where(
                    Integration.id == tenant.gurultu_integration_id
                )
            )
        ).scalar_one_or_none()

    islenen = 0
    for kayit in bekleyen:
        if not yeniden_denenmeli(
            deneme=kayit.deneme, son_deneme_at=kayit.son_deneme_at, simdi=simdi
        ):
            continue
        islenen += 1
        kayit.deneme += 1
        kayit.son_deneme_at = simdi
        if entegrasyon is None:
            # Entegrasyon KALDIRILDI: kuyrukta sonsuza dek beklemek yerine
            # manuel moda dusurulur — is yine de yapilabilsin.
            kayit.durum = "manuel_bekliyor"
            kayit.hata = "entegrasyon_yok"
            continue
        unit = (
            await db.execute(select(Unit).where(Unit.id == kayit.unit_id))
        ).scalar_one_or_none()
        govde = govde_uret(
            daire_no=unit.no if unit else "-", metin=kayit.metin,
            zaman=simdi,
        )
        ok, hata = await _gonder(db, entegrasyon, govde)
        kayit.durum = "gonderildi" if ok else "basarisiz"
        kayit.hata = hata
        # DENEMELER TUKENDIYSE manuel moda dus: sistem sessizce pes etmemeli,
        # is bir insana devredilmelidir.
        if not ok and kayit.deneme >= MAX_DENEME:
            kayit.durum = "manuel_bekliyor"
    await db.flush()
    return islenen
