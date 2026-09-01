"""(P191 §4) BANKA EŞLEŞTİRME — veritabanı katmanı (aday toplama + uygulama).

Karar `banka.py`de (saf çekirdek) verilir; bu modül kararı ÜRÜNÜN KENDİ
YOLLARINDAN uygular:

  * borç kapanışı + muhasebe kaydı -> `finansal_hareket` (TEK DEFTER,
    P192 §1; append-only, DELETE yok). Dağılımdaki HER PAY kendi tahsilat
    satırını alır: tek transfer üç ayı kapatıyorsa defterde üç satır
    vardır ve toplamları transferin tutarına eşittir. Kasa bakiyesi
    şişmez, buna karşılık her ayın kapanışı ayrı ayrı izlenebilir.
  * makbuz         -> `receipt` (+ PDF anahtarı MinIO'da)
  * bildirim       -> `dispatch_external` + `notification` (P191 §2 yolu)

Yeni bir borç/ödeme tablosu AÇILMADI: iki yerde tutulan bakiye, biri
güncellenip diğeri unutulduğunda hangisinin doğru olduğunu belirsiz
bırakırdı.

===========================================================================
İDEMPOTENCY
===========================================================================
Her finansal yazma bir `idempotency_key` taşır ve anahtar HAREKETTEN
türer (`banka:<bank_transaction_id>:<sıra>`). Aynı hareket iki kez
uygulanmaya çalışılırsa ikinci deneme yeni para hareketi ÜRETMEZ.
"""
from __future__ import annotations

import uuid
from collections.abc import Sequence

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from .banka import Aday, Borc, Karar, iban_normalize
from .belge_no import belge_no_ata
from . import defter as defter_modulu
from .models import (
    AppUser,
    BankTransaction,
    DuesAssessment,
    FinansalHareket,
    PaymentMatch,
    Receipt,
    Unit,
    UnitResident,
)


async def _acik_borclar(db: AsyncSession) -> dict[uuid.UUID, list[Borc]]:
    """Daire başına AÇIK tahakkuklar (kalan tutarıyla).

    Kalan = tahakkuk - o tahakkuka yazılmış BAŞARILI ödemeler. Kapanmış
    borçlar listeye GİRMEZ: FIFO'nun "en eski açık borç" tanımı budur.
    """
    # (P192 §1) "Ödenen" tanımı TEK YERDE: `defter.tahsilat_etkisi()`.
    # İkinci bir kopyasını burada yazmak, iade/iptal kurallarının bir gün
    # ayrışması demekti.
    _etki = defter_modulu.tahsilat_etkisi().subquery()
    odenen = (
        select(
            _etki.c.assessment_id.label("aid"),
            func.coalesce(func.sum(_etki.c.etki), 0).label("odenen"),
        )
        .where(_etki.c.assessment_id.isnot(None))
        .group_by(_etki.c.assessment_id)
        .subquery()
    )
    rows = (
        await db.execute(
            select(DuesAssessment, func.coalesce(odenen.c.odenen, 0))
            .outerjoin(odenen, odenen.c.aid == DuesAssessment.id)
            .order_by(DuesAssessment.donem)
        )
    ).all()
    sonuc: dict[uuid.UUID, list[Borc]] = {}
    for tahakkuk, odenen_kurus in rows:
        kalan = int(tahakkuk.tutar_kurus) - int(odenen_kurus or 0)
        if kalan <= 0:
            continue
        sonuc.setdefault(tahakkuk.unit_id, []).append(
            Borc(
                assessment_id=str(tahakkuk.id),
                unit_id=str(tahakkuk.unit_id),
                donem=tahakkuk.donem,
                kalan_kurus=kalan,
                vade=(
                    tahakkuk.son_odeme_tarihi.isoformat()
                    if tahakkuk.son_odeme_tarihi
                    else None
                ),
            )
        )
    return sonuc


async def _iban_gecmisi(db: AsyncSession) -> dict[uuid.UUID, set[str]]:
    """Kişi -> daha önce ONAYLANMIŞ eşleşmelerde görülen IBAN'lar.

    Ayrı bir tablo açılmadı (kullanıcı kuralı: yalnız üç yeni tablo):
    bilgi zaten `bank_transaction` + `payment_match` birleşiminde duruyor
    ve türetmek, ikinci bir yerde eskiyebilecek kopya tutmaktan iyidir.
    """
    rows = (
        await db.execute(
            select(PaymentMatch.user_id, BankTransaction.karsi_iban)
            .join(
                BankTransaction,
                BankTransaction.id == PaymentMatch.bank_transaction_id,
            )
            .where(
                PaymentMatch.durum == "onaylandi",
                PaymentMatch.user_id.isnot(None),
                BankTransaction.karsi_iban.isnot(None),
            )
        )
    ).all()
    sonuc: dict[uuid.UUID, set[str]] = {}
    for user_id, iban in rows:
        sade = iban_normalize(iban)
        if sade:
            sonuc.setdefault(user_id, set()).add(sade)
    return sonuc


async def adaylari_topla(db: AsyncSession) -> list[Aday]:
    """Eşleştirme adayları: daireye bağlı AKTİF kişiler + açık borçları.

    Daireye bağlı OLMAYAN kullanıcı aday DEĞİLDİR: ona yazılacak bir borç
    da yoktur. Bir kişi ÇOK DAİREYE bağlıysa her daire için ayrı aday
    üretilir — "bir kişi çok daire" senaryosunda hangi dairenin borcunun
    kapandığı belirsiz kalmasın.
    """
    borclar = await _acik_borclar(db)
    ibanlar = await _iban_gecmisi(db)
    rows = (
        await db.execute(
            select(UnitResident.unit_id, AppUser)
            .join(AppUser, AppUser.id == UnitResident.user_id)
            .where(UnitResident.bitis.is_(None), AppUser.is_active.is_(True))
        )
    ).all()
    adaylar: list[Aday] = []
    for unit_id, kullanici in rows:
        adaylar.append(
            Aday(
                user_id=str(kullanici.id),
                ad=kullanici.ad or "",
                unit_id=str(unit_id),
                odeme_kodu=kullanici.odeme_kodu,
                bilinen_ibanlar=tuple(sorted(ibanlar.get(kullanici.id, set()))),
                borclar=tuple(borclar.get(unit_id, [])),
            )
        )
    return adaylar


async def karari_uygula(
    db: AsyncSession,
    *,
    yonetici: AppUser,
    hareket: BankTransaction,
    karar: Karar,
    kasa_id: uuid.UUID | None = None,
) -> list[PaymentMatch]:
    """Kararı yazar: borç kapanışı + defter + makbuz + eşleşme satırları.

    TEK DEFTER SATIRI, ÇOK BORÇ KAPANIŞI: bir transfer üç ayı kapatsa
    bile kasaya giren para BİR kez girmiştir. Defterde üç satır yazmak,
    kasa bakiyesini üçe katlamak olurdu; borç kapanışı `dues_payment`
    satırlarıyla ayrı ayrı izlenir.
    """
    if karar.user_id is None or not karar.dagilim:
        return []
    user_id = uuid.UUID(karar.user_id)
    # (P191) KAÇINCI DENEME. Bir eşleşme geri alınıp hareket YENİDEN
    # eşleştirilebilir; idempotency anahtarı yalnız harekete dayansaydı
    # ikinci uygulama tekillik kısıtına takılırdı (ölçüldü). Aynı deneme
    # içindeki bir tekrar hâlâ engellenir: uçlar `eslesti` durumundaki
    # hareketi zaten 409 ile reddediyor.
    deneme = (
        await db.execute(
            select(func.count())
            .select_from(PaymentMatch)
            .where(PaymentMatch.bank_transaction_id == hareket.id)
        )
    ).scalar_one() + 1
    unit_id = uuid.UUID(karar.unit_id) if karar.unit_id else None

    # (P192 §2.1) BANKA PARASI BANKA HESABINA. Önceden `kasa_id` NULL
    # geçilebiliyordu ve o satır hiçbir kasa bakiyesinde görünmüyor ama
    # genel toplamda sayılıyordu — kasa toplamları genel toplamla
    # tutmuyordu.
    hedef_kasa = await defter_modulu.kasa_coz(
        db, yonetici.tenant_id, kasa_id, banka=True
    )

    aidat_kategori = await defter_modulu.aidat_kategori_id(db, yonetici.tenant_id)

    # 1) DEFTER — dağılımdaki her pay için BİR tahsilat satırı.
    #    `None` anahtarlı pay FAZLA ÖDEMEDİR: tahakkuka bağlanmaz, daire
    #    alacağında bekler ve bir sonraki borçtan mahsup edilir (bakiye
    #    hesabı zaten "tahakkuk - ödeme" olduğu için kendiliğinden).
    satirlar: list[FinansalHareket] = []
    for sira, (assessment_id, pay) in enumerate(karar.dagilim, start=1):
        donem = None
        if assessment_id is not None:
            donem = (
                await db.execute(
                    select(DuesAssessment.donem).where(
                        DuesAssessment.id == uuid.UUID(assessment_id)
                    )
                )
            ).scalar_one_or_none()
        satir = FinansalHareket(
            tenant_id=yonetici.tenant_id,
            tip="tahsilat",
            yon="giris",
            tutar_kurus=pay,
            tarih=hareket.islem_tarihi,
            kasa_id=hedef_kasa,
            user_id=user_id,
            unit_id=unit_id,
            assessment_id=uuid.UUID(assessment_id) if assessment_id else None,
            donem=donem,
            yontem="havale",
            durum="odendi",
            provider="banka",
            # `uq_hareket_provider_ref` TEKİLDİR ve bir hareket BİRDEN ÇOK
            # satır yazar (FIFO); referansa sıra eklenmeseydi ikinci satır
            # kısıta takılır ve tek transferle iki ay kapatmak İMKANSIZ
            # olurdu.
            provider_ref=f"{hareket.external_transaction_id}#{deneme}.{sira}",
            aciklama=(hareket.aciklama or "")[:500] or None,
            kaydeden_user_id=yonetici.id,
            idempotency_key=f"banka:{hareket.id}:{deneme}",
            idem_satir=sira,
            budget_category_id=aidat_kategori,
            belge_no=await belge_no_ata(
                db, yonetici.tenant_id, "tahsilat", None, hareket.islem_tarihi
            ),
        )
        db.add(satir)
        satirlar.append(satir)
    await db.flush()

    # 2) MAKBUZ — transferin TAMAMI için tek makbuz (sakin bir transfer
    #    yaptı, üç değil). Belge numarası İLK defter satırıyla aynı:
    #    makbuz o kaydı belgeler.
    makbuz = Receipt(
        tenant_id=yonetici.tenant_id,
        user_id=user_id,
        unit_id=unit_id,
        bank_transaction_id=hareket.id,
        belge_no=satirlar[0].belge_no,
        tutar_kurus=hareket.tutar_kurus,
    )
    db.add(makbuz)
    await db.flush()

    # 4) EŞLEŞME SATIRLARI — payı ayrı ayrı izlenebilir tut.
    eslesmeler: list[PaymentMatch] = []
    for satir, (assessment_id, pay) in zip(satirlar, karar.dagilim):
        eslesme = PaymentMatch(
            tenant_id=yonetici.tenant_id,
            bank_transaction_id=hareket.id,
            user_id=user_id,
            unit_id=unit_id,
            assessment_id=uuid.UUID(assessment_id) if assessment_id else None,
            tutar_kurus=pay,
            confidence_score=min(100, max(0, karar.confidence)),
            match_type=karar.match_type,
            durum="onaylandi",
            finansal_hareket_id=satir.id,
            # (P192 §1) `dues_payment` ARTIK YAZILMIYOR — borç kapanışı
            # defter satırının kendisidir. Sütun geçmiş satırlar için
            # yerinde durur.
            dues_payment_id=None,
            receipt_id=makbuz.id,
            karar_veren_user_id=yonetici.id,
        )
        db.add(eslesme)
        eslesmeler.append(eslesme)
    hareket.durum = "eslesti"
    hareket.karar_veren_user_id = yonetici.id
    await db.flush()
    return eslesmeler


async def geri_al(
    db: AsyncSession, *, yonetici: AppUser, hareket: BankTransaction, sebep: str | None
) -> int:
    """Yanlış eşleşmeyi geri alır. SİLMEZ — TERS KAYIT yazar.

    * Deftere `tip='iptal'` bir ÇIKIŞ satırı yazılır; borç KENDİLİĞİNDEN
      yeniden açılır çünkü "ödenen" hesabı iptal satırını düşer
      (P192 §1, `defter.tahsilat_etkisi`).
    * İptal satırı, iptal ettiği
      satırı `ters_kayit_id` ile gösterir — "bu para nereye gitti"
      sorusu açıklama metnine bırakılmaz.
    * `payment_match.durum = 'geri_alindi'` -> tahakkuk üzerindeki kısmi
      benzersizlik serbest kalır ve borç yeniden eşleştirilebilir.

    Dönüş: geri alınan eşleşme sayısı.
    """
    eslesmeler = (
        await db.execute(
            select(PaymentMatch).where(
                PaymentMatch.bank_transaction_id == hareket.id,
                PaymentMatch.durum == "onaylandi",
            )
        )
    ).scalars().all()
    if not eslesmeler:
        return 0

    defter_idleri = {e.finansal_hareket_id for e in eslesmeler if e.finansal_hareket_id}

    for defter_id in defter_idleri:
        asil = (
            await db.execute(
                select(FinansalHareket).where(FinansalHareket.id == defter_id)
            )
        ).scalar_one_or_none()
        if asil is None:
            continue
        belge = await belge_no_ata(db, yonetici.tenant_id, "iptal", None, None)
        db.add(
            FinansalHareket(
                tenant_id=yonetici.tenant_id,
                tip="iptal",
                yon="cikis",
                tutar_kurus=asil.tutar_kurus,
                tarih=asil.tarih,
                kasa_id=asil.kasa_id,
                user_id=asil.user_id,
                unit_id=asil.unit_id,
                assessment_id=asil.assessment_id,
                donem=asil.donem,
                belge_no=belge,
                aciklama=(sebep or "")[:500] or None,
                ters_kayit_id=asil.id,
                kaydeden_user_id=yonetici.id,
                idempotency_key=f"banka-iptal:{hareket.id}:{asil.id}",
                idem_satir=1,
            )
        )

    for eslesme in eslesmeler:
        eslesme.durum = "geri_alindi"
        eslesme.karar_veren_user_id = yonetici.id
    hareket.durum = "manuel_inceleme"
    hareket.not_metni = sebep
    hareket.karar_veren_user_id = yonetici.id
    await db.flush()
    return len(eslesmeler)


async def daire_adi(db: AsyncSession, unit_id: uuid.UUID | None) -> str | None:
    if unit_id is None:
        return None
    return (
        await db.execute(select(Unit.no).where(Unit.id == unit_id))
    ).scalar_one_or_none()


def kararlari_uret(hareketler: Sequence[BankTransaction], adaylar: list[Aday]) -> dict[uuid.UUID, Karar]:
    """Her hareket için karar üretir (saf çekirdeği çağırır)."""
    from .banka import Hareket, eslestir

    sonuc: dict[uuid.UUID, Karar] = {}
    for hareket in hareketler:
        sonuc[hareket.id] = eslestir(
            Hareket(
                id=str(hareket.id),
                tutar_kurus=int(hareket.tutar_kurus),
                aciklama=hareket.aciklama or "",
                karsi_ad=hareket.karsi_ad,
                karsi_iban=hareket.karsi_iban,
                yon=hareket.yon,
            ),
            adaylar,
        )
    return sonuc
