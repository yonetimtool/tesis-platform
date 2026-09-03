"""Gurultu caydiricisinin AKISI (P37) — esik kontrolu, gonderim, sifirlama.

Cekirdek karar `app.gurultu`dadir (saf); burasi veritabani ve HTTP ile
konusur. Sikayet ucundan cagrilir ve UCU ASLA DUSURMEZ: caydiricinin
basarisiz olmasi sikayetin kaydedilmesini engellememeli — sikayet
kullanicinin beyanidir, caydirici sistemin tepkisidir.
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta, timezone

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
from .audit import Action, record_audit
from .models import (
    Integration,
    Notification,
    Tenant,
    Unit,
    UnitComplaint,
    UnitResident,
    UnitUyari,
)
from .safe_http import SSRFBlocked, send_webhook
from .push_metinleri import push_govdesi
from .sakin_bildirimi import sakin_bildirimi_yaz
from .scheduler.notify import dispatch_external

logger = logging.getLogger(__name__)

#: Manuel modda anonsu yapacak roller.
_MANUEL_ROLLER: tuple[str, ...] = ("admin", "yonetici")


async def acik_gurultu_sayisi(
    db: AsyncSession, unit_id: uuid.UUID, *, pencere_gun: int = 0
) -> int:
    """YALNIZ `gurultu` kategorisi, YALNIZ PENCERE ICINDE.

    Kapi onune ayakkabi birakan bir daireye "gurultu uyarisi" anonsu
    yapmak, caydiriciyi anlamsiz kilardi — P24'un renk skalasi TUM
    kategorileri sayar ama CAYDIRICI gurulyuye ozeldir.

    (P208 §1) PENCERE EKLENDI. Onceden `durum='acik'` olan HER sikayet
    sayiliyordu: bir yil once acilmis ve kimsenin kapatmadigi bir
    sikayet, dun geceki kadar agirlik tasiyordu. `pencere_gun=0` ESKI
    DAVRANISTIR (sinirsiz) ve mevcut tesisler icin kacis kapisidir.
    """
    kosullar = [
        UnitComplaint.target_unit_id == unit_id,
        UnitComplaint.kategori == "gurultu",
        UnitComplaint.durum == "acik",
    ]
    if pencere_gun and pencere_gun > 0:
        sinir = datetime.now(tz=timezone.utc) - timedelta(days=pencere_gun)
        kosullar.append(UnitComplaint.created_at >= sinir)
    return (
        await db.execute(
            select(func.count()).select_from(UnitComplaint).where(*kosullar)
        )
    ).scalar_one()


async def _uyarilacak_sakinler(
    db: AsyncSession, unit_id: uuid.UUID
) -> list[uuid.UUID]:
    """(P208 §1) Uyarinin gidecegi kisiler — OTURAN KISI.

    =======================================================================
    KIRACI VARSA YALNIZ KIRACIYA
    =======================================================================
    Gurultu daireden cikar ve onu durdurabilecek kisi ORADA OTURANDIR.
    Oturmayan malike "hakkinizda gurultu sikayeti var" demek, hem yanlis
    kisiyi uyarmak hem de kiraci hakkindaki sikayeti ev sahibine ihbar
    etmektir — sistemin gorevi olmayan ve kiraci-malik iliskisini
    zedeleyen bir sey.

    Kiraci bagi YOKSA malik(ler)e gider: o durumda oturan kisi odur.
    AKTIF BAG: `bitis IS NULL` ya da gelecekte. Tasinmis birine uyari
    gondermek, gecmisteki bir komsuluk icin bugun rahatsiz etmekti.
    """
    simdi = datetime.now(tz=timezone.utc)
    satirlar = (
        await db.execute(
            select(UnitResident.user_id, UnitResident.rol_tipi).where(
                UnitResident.unit_id == unit_id,
                (UnitResident.bitis.is_(None)) | (UnitResident.bitis > simdi),
            )
        )
    ).all()
    kiracilar = [uid for uid, rol in satirlar if rol == "kiraci"]
    if kiracilar:
        return kiracilar
    return [uid for uid, _ in satirlar]


async def _susma_suresinde_mi(
    db: AsyncSession, unit_id: uuid.UUID, susma_gun: int
) -> bool:
    """(P208 §1) Bu daire yakin zamanda UYARILDI mi?

    Her gece tekrarlanan bir uyari KENDISI gurultuye donusur ve okunmaz
    olur; uyarinin isi davranisi degistirmek ve buna zaman tanimak.
    Kayit YINE YAZILIR (asagida) — susan sey BILDIRIMDIR, defter degil:
    tekrarlanan esik asimlari yoneticinin escalation dayanagidir.
    """
    if susma_gun <= 0:
        return False
    sinir = datetime.now(tz=timezone.utc) - timedelta(days=susma_gun)
    son = (
        await db.execute(
            select(UnitUyari.id)
            .where(UnitUyari.unit_id == unit_id, UnitUyari.created_at >= sinir)
            .limit(1)
        )
    ).scalar_one_or_none()
    return son is not None


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

    sayac = await acik_gurultu_sayisi(
        db, unit.id, pencere_gun=tenant.gurultu_pencere_gun
    )
    if not esik_asildi(sayac, tenant.gurultu_esigi):
        return None

    # (P208 §1) SUSMA SURESI: yakin zamanda uyarilmis daire YENIDEN
    # uyarilmaz. Kontrol SIFIRLAMADAN ONCE yapilir ve `None` doner —
    # sikayetleri kapatmak, uyari gonderilmeden sayaci sifirlamak
    # olurdu ve daire kalici olarak "temiz" gorunurdu.
    if await _susma_suresinde_mi(db, unit.id, tenant.gurultu_susma_gun):
        logger.info(
            "NOISE_DETERRENT SUSMA tenant=%s unit=%s sayac=%s (son uyari "
            "%s gun icinde)", tenant_id, unit.id, sayac, tenant.gurultu_susma_gun,
        )
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
        # MANUEL MOD: yoneticiye "anonsu yapin" bildirimi gider. Bu bir
        # hata durumu DEGIL — cogu sitede entegrasyon hic olmayacak.
        dispatch_external(
            "gurultu_uyarisi",
            tenant_id=tenant_id,
            target_roles=_MANUEL_ROLLER,
            params={"daire": unit.no, "sayi": sayac},
            data={"tip": "gurultu_uyarisi", "unit_id": str(unit.id)},
        )

    # ================= (P208 §1) SAKINE UYARI ========================= #
    #
    # OLCULEN EKSIK: esik asilinca uyari ya anons cihazina ya yoneticiye
    # gidiyordu; UYARILMASI GEREKEN KISIYE hicbir sey gitmiyordu.
    #
    # METINDE SIKAYET EDENIN IZI YOK: ne kisi, ne daire, ne SAYI
    # (bkz. `push_metinleri.gurultu_uyari_sakin` basligi).
    sakinler = await _uyarilacak_sakinler(db, unit.id)
    if sakinler and tenant.gurultu_sakin_uyarisi:
        # IN-APP SATIR DA YAZILIR: push kapali/basarisiz olabilir ve o
        # zaman uyari HIC ULASMAMIS olurdu. Bildirim listesi, "bana
        # uyari geldi mi" sorusunun kalici yaniti.
        sakin_bildirimi_yaz(
            db, tenant_id=tenant_id, tip="gurultu_uyari_sakin",
            user_ids=sakinler, veri={},
        )
        dispatch_external(
            "gurultu_uyari_sakin",
            tenant_id=tenant_id,
            target_roles=None,
            target_user_ids=sakinler,
            params={},
            data={"tip": "gurultu_uyari_sakin", "unit_id": str(unit.id)},
        )
    kayit.sakin_bildirildi = bool(sakinler) and tenant.gurultu_sakin_uyarisi

    # ============== YONETIME AYRI BILDIRIM (her modda) ================ #
    #
    # Webhook modunda yonetici bugune kadar HICBIR SEY DUYMUYORDU: anons
    # cihaza gidiyor, kayit veritabaninda duruyordu. "O daireyle
    # ilgilenmem gerekebilir" bilgisi bildirimle gelmeliydi.
    #
    # MANUEL MODDA IKINCI BILDIRIM GONDERILMEZ: yukaridaki
    # `gurultu_uyarisi` zaten yoneticinin telefonunu caldirdi; ayni
    # olay icin iki bildirim, ikisinin de okunmamasiyla biterdi.
    if entegrasyon is not None:
        # YONETIM SATIRI `user_id=NULL` ile yazilir: bildirim listesinde
        # yonetim gozu (`admin`/`yonetici`) SAHIPSIZ satirlari gorur
        # (bkz. `routers/notifications._kapsam`). Kisi kisi yazmak,
        # ayni olayi yonetici sayisi kadar cogaltmak olurdu.
        db.add(Notification(
            tenant_id=tenant_id,
            tip="gurultu_esik_yonetim",
            mesaj=push_govdesi(
                "gurultu_esik_yonetim", "tr",
                {"daire": unit.no, "sayi": sayac},
            ),
            mesaj_kimlik="gurultu_esik_yonetim",
            mesaj_veri={"daire": unit.no, "sayi": sayac},
        ))
        dispatch_external(
            "gurultu_esik_yonetim",
            tenant_id=tenant_id,
            target_roles=_MANUEL_ROLLER,
            params={"daire": unit.no, "sayi": sayac},
            data={"tip": "gurultu_esik_yonetim", "unit_id": str(unit.id)},
        )

    db.add(kayit)
    # DENETIME YAZILIR: "bu daireye uyari gonderildi mi, ne zaman,
    # kacinci sikayette" sorusu bir anlasmazlikta sorulacak ILK sorudur.
    # SAKINLERIN KIMLIGI meta'ya YAZILMAZ — denetim kaydi da bir sizinti
    # yuzeyidir; kac kisiye gittigi yeter.
    await record_audit(
        db,
        action=Action.UYARI_MANUEL if entegrasyon is None else Action.UYARI_MANUEL,
        tenant_id=tenant_id,
        resource_type="unit_uyari",
        resource_id=unit.id,
        meta={
            "islem": "gurultu_esik",
            "sayac": sayac,
            "esik": tenant.gurultu_esigi,
            "pencere_gun": tenant.gurultu_pencere_gun,
            "kanal": kayit.kanal,
            "sakin_bildirimi": len(sakinler) if kayit.sakin_bildirildi else 0,
        },
    )

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
