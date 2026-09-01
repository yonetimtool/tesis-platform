"""(P191 §4) BANKA ENTEGRASYONU — uçlar.

===========================================================================
AKIŞ
===========================================================================
  1. `POST /banka/ice-aktar`   — ekstre (yapılandırılmış satır ya da MT940)
     -> `bank_transaction` (mükerrer koruması: external_transaction_id)
  2. `POST /banka/eslestir`    — motoru çalıştırır; güven eşiğini geçenleri
     UYGULAR (borç kapanışı + defter + makbuz + bildirim), geçmeyenleri
     `manuel_inceleme`ye bırakır
  3. `GET  /banka/hareketler`  — eşleşmeyenler ekranı (durum süzgeciyle)
  4. `POST /banka/hareketler/{id}/manuel-eslestir` — yönetici elle atar
  5. `POST /banka/hareketler/{id}/isaretle` — ilgisiz gelir / banka masrafı
  6. `POST /banka/hareketler/{id}/geri-al`  — yanlış eşleşmeyi TERS KAYITLA
     geri al (borç yeniden açılır)
  7. `GET  /banka/makbuz/{id}` — makbuz PDF'i (presigned)

===========================================================================
GÜVENLİK
===========================================================================
* Uçların HEPSİ yalnız `admin`/`yonetici` (rol matrisi kilidi).
* Tesis izolasyonu RLS'te; hiçbir sorgu `tenant_id` süzgecini elle taşımaz.
* IBAN yanıtlarda MASKELİDİR (son 4 hane). Tam IBAN yalnız veritabanında
  ve yalnız eşleştirme motorunun geçmiş sorgusunda kullanılır.
* Her finansal yazma idempotenttir; hiçbir şey SİLİNMEZ, ters kayıt yazılır.
* TESİSLER ARASI TAŞIMA YOK: yanlış tesise düşen bir hareket başka tesise
  aktarılamaz (RLS zaten engeller) — o hareket `ilgisiz_gelir` işaretlenir
  ve doğru tesiste yeniden içe aktarılır.
"""
from __future__ import annotations

import logging
import uuid
from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from .. import storage
from ..audit import Action, audit_user
from ..banka import ESIK_OTOMATIK, Karar, iban_maskele
from ..belge_no import belge_no_ata
from ..banka_kaynak import KaynakHatasi, ekstre_satirlarindan, mt940_ayristir
from ..banka_servis import adaylari_topla, geri_al, karari_uygula, kararlari_uret
from ..crud_helpers import get_or_404
from .. import defter
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..makbuz import makbuz_pdf
from ..models import (
    AppUser,
    BankTransaction,
    DuesAssessment,
    FinansalHareket,
    Kasa,
    PaymentMatch,
    Receipt,
    Tenant,
    Unit,
)
from ..sakin_bildirimi import sakin_bildirimi_yaz
from ..scheduler.notify import dispatch_external
from ..schemas import (
    BankaKosumSonuc,
    BankaHareketListesi,
    BankaHareketOut,
    BankaIceAktarIstek,
    BankaIceAktarSonuc,
    BankaIsaretIstek,
    BankaManuelEslestirIstek,
    BankaMakbuzOut,
    BankaEslesmeOut,
    PageMetaOut,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/banka", tags=["banka"])

_YONETIM = require_role("admin", "yonetici")

_DURUMLAR = ("yeni", "eslesti", "manuel_inceleme", "ilgisiz_gelir", "masraf", "ters_kayit")


def _out(h: BankTransaction, eslesmeler: list[PaymentMatch] | None = None) -> BankaHareketOut:
    return BankaHareketOut(
        id=h.id,
        kaynak=h.kaynak,
        external_transaction_id=h.external_transaction_id,
        islem_tarihi=h.islem_tarihi,
        tutar_kurus=int(h.tutar_kurus),
        yon=h.yon,
        para_birimi=h.para_birimi,
        aciklama=h.aciklama,
        karsi_ad=h.karsi_ad,
        # TAM IBAN DÖNMEZ — güvenlik maddesi.
        karsi_iban_maskeli=iban_maskele(h.karsi_iban),
        durum=h.durum,
        not_metni=h.not_metni,
        created_at=h.created_at,
        eslesmeler=[
            BankaEslesmeOut(
                id=e.id,
                user_id=e.user_id,
                unit_id=e.unit_id,
                assessment_id=e.assessment_id,
                tutar_kurus=int(e.tutar_kurus),
                confidence_score=int(e.confidence_score),
                match_type=e.match_type,
                durum=e.durum,
                receipt_id=e.receipt_id,
            )
            for e in (eslesmeler or [])
        ],
    )


# ============================== 1) İÇE AKTARMA ============================== #
@router.post("/ice-aktar", response_model=BankaIceAktarSonuc, status_code=201)
async def ice_aktar(
    body: BankaIceAktarIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> BankaIceAktarSonuc:
    """Ekstreyi içe aktarır. AYNI EKSTRE İKİ KEZ YÜKLENEBİLİR.

    Mükerrer satırlar sessizce ATLANIR (yeni satır açılmaz) ve sayısı
    yanıtta döner: "yükledim ama bir şey olmadı" ile "zaten yüklüydü"
    ayrımı kullanıcıya görünür olmalı.
    """
    try:
        if body.mt940:
            hareketler = mt940_ayristir(body.mt940)
        else:
            hareketler = ekstre_satirlarindan([s.model_dump() for s in (body.satirlar or [])])
    except KaynakHatasi as exc:
        raise APIError(422, "validation_error", "banka_ekstre_okunamadi", ayrinti=str(exc)) from exc
    if not hareketler:
        raise APIError(422, "validation_error", "banka_ekstre_bos")

    # (P192 §2.1) Hedef banka hesabi BIR KEZ cozulur: satir basina cozmek
    # ayni ekstre icin N kez ayni sorguyu calistirmak olurdu.
    if body.kasa_id is not None:
        if (await db.execute(
            select(Kasa.id).where(Kasa.id == body.kasa_id)
        )).scalar_one_or_none() is None:
            raise APIError(422, "invalid_reference", "kasa_bulunamadi")
    hedef_kasa = await defter.kasa_coz(db, user.tenant_id, body.kasa_id, banka=True)

    eklenen = 0
    yinelenen = 0
    for ham in hareketler:
        obj = BankTransaction(
            tenant_id=user.tenant_id,
            kaynak=body.kaynak,
            external_transaction_id=ham.external_transaction_id,
            islem_tarihi=ham.islem_tarihi,
            tutar_kurus=ham.tutar_kurus,
            yon=ham.yon,
            para_birimi=ham.para_birimi,
            aciklama=ham.aciklama or None,
            karsi_ad=ham.karsi_ad,
            karsi_iban=ham.karsi_iban,
            raw_data=dict(ham.raw),
            kasa_id=hedef_kasa,
        )
        try:
            async with db.begin_nested():
                db.add(obj)
                await db.flush()
            eklenen += 1
        except IntegrityError:
            # UNIQUE (tenant_id, external_transaction_id) — AYNI HAREKET.
            # Bu bir hata değil, idempotency'nin çalıştığının kanıtıdır.
            try:
                db.expunge(obj)
            except Exception:  # noqa: BLE001
                pass
            yinelenen += 1
    await audit_user(
        db, user, Action.FINANS_HAREKET_CREATE, resource_type="bank_transaction",
        meta={"kaynak": body.kaynak, "eklenen": eklenen, "yinelenen": yinelenen},
    )
    return BankaIceAktarSonuc(
        eklenen=eklenen, yinelenen=yinelenen, toplam=len(hareketler)
    )


# ============================== 2) EŞLEŞTİRME =============================== #
async def _bildir_ve_makbuz(
    db: AsyncSession, *, user: AppUser, hareket: BankTransaction, eslesmeler: list[PaymentMatch]
) -> None:
    """Makbuz PDF'i üret + sakine bildirim. İKİSİ DE YAN İŞTİR.

    Depo/bildirim aksaklığı TAHSİLATI DÜŞÜRMEZ: para hareketi ve borç
    kapanışı zaten yazıldı. Makbuz üretilemezse `pdf_key` boş kalır ve
    yönetici yeniden üretebilir.
    """
    if not eslesmeler:
        return
    makbuz_id = eslesmeler[0].receipt_id
    if makbuz_id is None:
        return
    makbuz = (await db.execute(select(Receipt).where(Receipt.id == makbuz_id))).scalar_one_or_none()
    if makbuz is None:
        return
    odeyen = (
        await db.execute(select(AppUser).where(AppUser.id == makbuz.user_id))
    ).scalar_one_or_none()
    site_ad = (
        await db.execute(select(Tenant.ad).where(Tenant.id == user.tenant_id))
    ).scalar_one_or_none() or ""
    daire_no = None
    if makbuz.unit_id:
        daire_no = (
            await db.execute(select(Unit.no).where(Unit.id == makbuz.unit_id))
        ).scalar_one_or_none()
    kalemler: list[tuple[str, int]] = []
    for e in eslesmeler:
        if e.assessment_id:
            donem = (
                await db.execute(
                    select(DuesAssessment.donem).where(DuesAssessment.id == e.assessment_id)
                )
            ).scalar_one_or_none()
            kalemler.append((donem or "-", int(e.tutar_kurus)))
        else:
            kalemler.append(("Alacak (fazla ödeme)", int(e.tutar_kurus)))
    try:
        pdf = makbuz_pdf(
            site_ad=site_ad,
            belge_no=makbuz.belge_no,
            tarih=hareket.islem_tarihi,
            odeyen_ad=(odeyen.ad if odeyen else "") or "",
            daire_no=daire_no,
            tutar_kurus=int(makbuz.tutar_kurus),
            aciklama=hareket.aciklama,
            kalemler=kalemler,
        )
        key = f"{user.tenant_id}/makbuz/{makbuz.id.hex}.pdf"
        storage.sunucudan_yukle(key, pdf, "application/pdf")
        makbuz.pdf_key = key
        await db.flush()
    except Exception:  # noqa: BLE001 — makbuz YAN İŞ; tahsilatı düşürmez
        pass

    # (P192 §4.4) E-POSTA — push'un KALICI ikizi. Sakin bildirimi kacirsa
    # ya da telefonunu degistirse bile makbuzun kopyasi posta kutusunda
    # durur. YAN IS: gonderilemezse tahsilat DUSMEZ.
    if odeyen is not None and odeyen.email:
        try:
            from ..eposta_sablonlari import makbuz_metni
            from ..gonderim import saglayici as kanal_saglayicisi, tenant_ayari
            from ..raporlar import kurus_metin

            baglanti = (
                storage.presign_get(makbuz.pdf_key) if makbuz.pdf_key else None
            )
            konu, govde = makbuz_metni(
                site_ad=site_ad,
                belge_no=makbuz.belge_no,
                tutar=kurus_metin(int(makbuz.tutar_kurus)),
                baglanti=baglanti,
            )
            ayar = await tenant_ayari(db, user.tenant_id)
            kanal_saglayicisi("eposta", ayar).gonder(odeyen.email, konu, govde)
        except Exception:  # noqa: BLE001 — e-posta YAN IS
            logger.warning("[banka] makbuz e-postasi gonderilemedi (makbuz=%s)", makbuz.id)

    if makbuz.user_id:
        veri = {"donem": kalemler[0][0] if kalemler else "-", "tutar": ""}
        dispatch_external(
            "aidat_odendi",
            tenant_id=user.tenant_id,
            target_user_ids=(makbuz.user_id,),
            params=veri,
            data={"tip": "aidat_odendi", "receipt_id": str(makbuz.id)},
        )
        sakin_bildirimi_yaz(
            db, tenant_id=user.tenant_id, tip="aidat_odendi",
            user_ids=(makbuz.user_id,), veri=veri,
        )


async def _uygula(
    db: AsyncSession, user: AppUser, hareket: BankTransaction, karar: Karar
) -> list[PaymentMatch]:
    """Kararı yazar. EŞ ZAMANLI İKİNCİ UYGULAMA 500 DEĞİL, sessizce boştur.

    İki yönetici aynı anda "Eşleştir" derse ikisi de hareketi `yeni`
    görür; ikinci yazma `uq_payment_tenant_idempotency`e takılır. Bu bir
    KORUMADIR (para iki kez yazılmadı) ama kullanıcıya 500 göstermek onu
    "kayıt bozuldu mu?" diye düşündürürdü. SAVEPOINT içinde denenir;
    çakışmada hareket manuel incelemeye bırakılır.
    """
    try:
        async with db.begin_nested():
            eslesmeler = await karari_uygula(
                db, yonetici=user, hareket=hareket, karar=karar,
                # (P192 §2.1) Para EKSTRENIN AIT OLDUGU hesaba girer.
                kasa_id=hareket.kasa_id,
            )
    except IntegrityError:
        logger.warning(
            "[banka] es zamanli uygulama cakismasi (hareket=%s) -> manuel", hareket.id
        )
        hareket.durum = "manuel_inceleme"
        hareket.not_metni = "es_zamanli_islem"
        await db.flush()
        return []
    if eslesmeler:
        await _bildir_ve_makbuz(db, user=user, hareket=hareket, eslesmeler=eslesmeler)
        await audit_user(
            db, user, Action.DUES_PAYMENT_RECORD, resource_type="payment_match",
            resource_id=eslesmeler[0].id,
            meta={
                "bank_transaction_id": str(hareket.id),
                "match_type": karar.match_type,
                "confidence": karar.confidence,
            },
        )
    return eslesmeler


async def _cikis_gideri_yaz(
    db: AsyncSession, user: AppUser, hareket: BankTransaction
) -> None:
    """(P192 §4.3) Bankadan cikan parayi ONAY BEKLEYEN gider olarak yazar.

    IDEMPOTENT: `idempotency_key` harekete dayanir; ayni ekstre satiri
    ikinci kez islenirse ikinci gider olusmaz.
    """
    kasa_id = await defter.kasa_coz(db, user.tenant_id, hareket.kasa_id, banka=True)
    obj = FinansalHareket(
        tenant_id=user.tenant_id,
        tip="gider",
        yon="cikis",
        tutar_kurus=hareket.tutar_kurus,
        tarih=hareket.islem_tarihi,
        kasa_id=kasa_id,
        # ONAY BEKLIYOR: banka masrafi otomatik defterlenmez.
        durum="onay_bekliyor",
        aciklama=(hareket.aciklama or "")[:500] or None,
        kaydeden_user_id=user.id,
        provider="banka",
        provider_ref=f"cikis:{hareket.external_transaction_id}",
        idempotency_key=f"banka-cikis:{hareket.id}",
        idem_satir=0,
        belge_no=await belge_no_ata(
            db, user.tenant_id, "gider", None, hareket.islem_tarihi
        ),
    )
    try:
        async with db.begin_nested():
            db.add(obj)
            await db.flush()
    except IntegrityError:
        try:
            db.expunge(obj)
        except Exception:  # noqa: BLE001
            pass
    hareket.durum = "eslesti"
    hareket.karar_veren_user_id = user.id
    await db.flush()


@router.post("/eslestir", response_model=BankaKosumSonuc)
async def eslestir_uc(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> BankaEslestirSonuc:
    """Bekleyen hareketleri eşleştirir.

    OTOMATİK UYGULAMA EŞİĞİ `ESIK_OTOMATIK` (80). Altındaki her şey
    `manuel_inceleme`dir ve yöneticinin önüne düşer — ad eşleşmesi tek
    başına asla yeterli değildir (kullanıcının açık kuralı).
    """
    bekleyenler = (
        await db.execute(
            select(BankTransaction)
            .where(BankTransaction.durum.in_(("yeni", "manuel_inceleme")))
            .order_by(BankTransaction.islem_tarihi)
        )
    ).scalars().all()
    if not bekleyenler:
        return BankaKosumSonuc(incelenen=0, otomatik=0, manuel=0)

    otomatik = 0
    manuel = 0
    for hareket in bekleyenler:
        # ADAYLAR HER HAREKETTE YENİDEN toplanır: bir önceki hareket bir
        # borcu kapatmış olabilir ve bayat listeyle çalışmak AYNI borcu
        # iki kez kapatmaya çalışmak olurdu.
        adaylar = await adaylari_topla(db)
        # (P192 §4.3) BANKADAN CIKAN PARA GIDERDIR.
        #
        # Onceden `cikis` yonlu satirlar sonsuza kadar "manuel_inceleme"de
        # bekliyordu: eslestirme motoru yalnizca BORC kapatmayi biliyor ve
        # bir cikis hicbir borcu kapatmaz. Oysa defterde karsiliginin
        # olmamasi, banka bakiyesi ile kasa bakiyesinin ayrismasi demekti.
        #
        # OTOMATIK "ODENDI" YAZILMAZ: banka masrafi da, bilinmeyen bir
        # havale de yoneticinin ONAYINA duser (kullanicinin acik kurali:
        # "banka masrafi -> gider, yonetici onayina dussun, otomatik
        # yazma"). Onay/red uclari §2.3'te.
        if hareket.yon == "cikis":
            await _cikis_gideri_yaz(db, user, hareket)
            otomatik += 1
            continue
        karar = kararlari_uret([hareket], adaylar)[hareket.id]
        if karar.sonuc == "otomatik" and karar.confidence >= ESIK_OTOMATIK:
            await _uygula(db, user, hareket, karar)
            otomatik += 1
        else:
            hareket.durum = "manuel_inceleme"
            hareket.not_metni = karar.neden
            manuel += 1
            await db.flush()
    return BankaKosumSonuc(
        incelenen=len(bekleyenler), otomatik=otomatik, manuel=manuel
    )


# ============================ 3) LİSTE / EKRAN ============================== #
@router.get("/hareketler", response_model=BankaHareketListesi)
async def hareketler(
    durum: str | None = Query(None, description="yeni|eslesti|manuel_inceleme|ilgisiz_gelir|masraf|ters_kayit"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> BankaHareketListesi:
    where = []
    if durum:
        if durum not in _DURUMLAR:
            raise APIError(422, "validation_error", "banka_durum_gecersiz")
        where.append(BankTransaction.durum == durum)
    toplam = (
        await db.execute(select(func.count()).select_from(BankTransaction).where(*where))
    ).scalar_one()
    satirlar = (
        await db.execute(
            select(BankTransaction)
            .where(*where)
            # KARARLI SIRALAMA: eşit tarih/saatte satır sırası sayfadan
            # sayfaya değişirse bir kayıt İKİ KEZ görünür, bir başkası HİÇ
            # görünmez. `id` son kırıcıdır (depo kuralı, test_sayfalama).
            .order_by(
                BankTransaction.islem_tarihi.desc(),
                BankTransaction.created_at.desc(),
                BankTransaction.id,
            )
            .limit(limit)
            .offset(offset)
        )
    ).scalars().all()
    idler = [s.id for s in satirlar]
    eslesmeler: dict[uuid.UUID, list[PaymentMatch]] = {}
    if idler:
        for e in (
            await db.execute(
                select(PaymentMatch).where(PaymentMatch.bank_transaction_id.in_(idler))
            )
        ).scalars().all():
            eslesmeler.setdefault(e.bank_transaction_id, []).append(e)
    return BankaHareketListesi(
        meta=PageMetaOut(limit=limit, offset=offset, total=toplam),
        items=[_out(s, eslesmeler.get(s.id, [])) for s in satirlar],
    )


# =========================== 4) MANUEL EŞLEŞTİRME =========================== #
@router.post("/hareketler/{hareket_id}/manuel-eslestir", response_model=BankaHareketOut)
async def manuel_eslestir(
    hareket_id: uuid.UUID,
    body: BankaManuelEslestirIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> BankaHareketOut:
    """Yönetici hareketi bir kişiye ELLE atar; dağıtım yine FIFO'dur.

    `confidence_score = 100` ve `match_type='manuel'`: karar insanındır,
    motorun tahmini değil — ikisini aynı puanla yazmak, sonradan "bunu
    kim seçti" sorusunu cevapsız bırakırdı.
    """
    hareket = await get_or_404(db, BankTransaction, hareket_id)
    if hareket.durum == "eslesti":
        raise APIError(409, "conflict", "banka_zaten_eslesti")
    if hareket.yon != "giris":
        raise APIError(422, "validation_error", "banka_cikis_eslestirilemez")
    adaylar = [a for a in await adaylari_topla(db) if a.user_id == str(body.user_id)]
    if not adaylar:
        raise APIError(422, "invalid_reference", "banka_aday_bulunamadi")
    aday = adaylar[0]
    if body.unit_id is not None:
        secili = [a for a in adaylar if a.unit_id == str(body.unit_id)]
        if not secili:
            raise APIError(422, "invalid_reference", "banka_daire_bulunamadi")
        aday = secili[0]
    from ..banka import fifo_dagit

    karar = Karar(
        hareket_id=str(hareket.id),
        user_id=aday.user_id,
        unit_id=aday.unit_id,
        match_type="manuel",
        confidence=100,
        sonuc="otomatik",
        neden="manuel",
        dagilim=fifo_dagit(int(hareket.tutar_kurus), aday.borclar),
    )
    eslesmeler = await _uygula(db, user, hareket, karar)
    return _out(hareket, eslesmeler)


# ====================== 5) İLGİSİZ GELİR / BANKA MASRAFI ==================== #
@router.post("/hareketler/{hareket_id}/isaretle", response_model=BankaHareketOut)
async def isaretle(
    hareket_id: uuid.UUID,
    body: BankaIsaretIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> BankaHareketOut:
    """`ilgisiz_gelir` | `masraf` | `ters_kayit` işaretlemesi.

    BANKA MASRAFI OTOMATİK GİDER YAZMAZ (kullanıcının açık kuralı): burada
    yalnız İŞARETLENİR. Gideri deftere yazmak ayrı ve bilinçli bir karardır
    — yönetici Finans > Giderler ekranından girer. Sessizce gider yazan bir
    sistem, banka masrafını kimsenin görmediği bir yerde biriktirirdi.
    """
    if body.durum not in ("ilgisiz_gelir", "masraf", "ters_kayit"):
        raise APIError(422, "validation_error", "banka_durum_gecersiz")
    hareket = await get_or_404(db, BankTransaction, hareket_id)
    if hareket.durum == "eslesti":
        raise APIError(409, "conflict", "banka_zaten_eslesti")
    hareket.durum = body.durum
    hareket.not_metni = body.not_metni
    hareket.karar_veren_user_id = user.id
    await db.flush()
    await audit_user(
        db, user, Action.FINANS_HAREKET_CREATE, resource_type="bank_transaction",
        resource_id=hareket.id, meta={"isaret": body.durum},
    )
    return _out(hareket)


# ============================== 6) GERİ ALMA ================================ #
@router.post("/hareketler/{hareket_id}/geri-al", response_model=BankaHareketOut)
async def geri_al_uc(
    hareket_id: uuid.UUID,
    body: BankaIsaretIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> BankaHareketOut:
    """Yanlış eşleşmeyi geri alır: SİLMEZ, ters kayıt yazar, borç açılır."""
    hareket = await get_or_404(db, BankTransaction, hareket_id)
    sayi = await geri_al(db, yonetici=user, hareket=hareket, sebep=body.not_metni)
    if sayi == 0:
        raise APIError(409, "conflict", "banka_geri_alinacak_eslesme_yok")
    await audit_user(
        db, user, Action.FINANS_HAREKET_CREATE, resource_type="bank_transaction",
        resource_id=hareket.id, meta={"geri_alinan": sayi},
    )
    return _out(hareket)


# =============================== 7) MAKBUZ ================================== #
@router.get("/makbuz/{receipt_id}", response_model=BankaMakbuzOut)
async def makbuz_getir(
    receipt_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> BankaMakbuzOut:
    """Makbuz kaydı + (varsa) PDF için kısa ömürlü indirme adresi."""
    makbuz = await get_or_404(db, Receipt, receipt_id)
    url = None
    if makbuz.pdf_key:
        try:
            url = storage.presign_get(makbuz.pdf_key)
        except Exception:  # noqa: BLE001 — depo erişilemezse kayıt yine dönsün
            url = None
    return BankaMakbuzOut(
        id=makbuz.id,
        belge_no=makbuz.belge_no,
        tutar_kurus=int(makbuz.tutar_kurus),
        user_id=makbuz.user_id,
        unit_id=makbuz.unit_id,
        created_at=makbuz.created_at,
        pdf_url=url,
    )


#: Tarih tipi şemada kullanılıyor; import'un görünür kalması için.
_ = date
