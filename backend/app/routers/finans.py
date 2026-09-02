"""Tahsilat, kasa ve finansal hareketler (P29).

TEK DEFTER: tahsilat / gider / gelir / virman / iade / acilis ayni
`finansal_hareket` kaydinda `tip` ile ayrilir — "kasa bakiyesi = hareket
toplami" tutarliligi ancak TEK kaynak varken kanitlanabilir.

BAKIYE SAKLANMAZ, TURETILIR (`kasa.acilis_bakiye_kurus` + isaretli toplam):
saklanan bir bakiye her yazma yolunda elle guncellenmek zorunda kalir ve bir
yol unutuldugunda defterle bakiye sessizce ayrilir.

RBAC: yazma admin; okuma admin + yonetici. Saha/sakin ERISEMEZ.
"""
from __future__ import annotations

import uuid
from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, Header, Query, Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..belge_no import belge_no_ata
from ..crud_helpers import get_or_404, is_unique_violation, translate_integrity
from .. import defter
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..finans import BankaSatiri, BorcAdayi, banka_eslestir, kasa_bakiye
from ..models import (
    AppUser,
    DuesAssessment,
    FinansalHareket,
    IcraDosyasi,
    Kasa,
)
from ..schemas import (
    AcilisFisi,
    BankaEslestirIstek,
    BankaEslestirOneri,
    BankaEslestirSonuc,
    FinansOzet,
    HareketListResponse,
    HareketOut,
    HareketToplu,
    IadeIstek,
    IptalIstek,
    IcraDosyasiCreate,
    IcraDosyasiListResponse,
    IcraDosyasiOut,
    IcraDosyasiUpdate,
    HareketOnayIstek,
    KasaBakiye,
    KasaBakiyeResponse,
    TahsilatCreate,
    TopluTahsilatIstek,
    VirmanIstek,
)

router = APIRouter(tags=["finans"])

# ===========================================================================
# (P206 §1) FINANSAL YAZMA ARTIK YONETICIDE — `_ADMIN` KALDIRILDI
# ===========================================================================
# OLCULEN KUSUR: yonetici kendi tesisinin finansini YONETEMIYORDU. Rol
# matrisinden cikan tablo (`docs/P206-kararlar.md` §1) on alti finans
# ucunun yoneticiye KAPALI oldugunu gosterdi — tahsilat, gider, gider
# onayi, virman, iade, acilis, toplu borclandirma, sayac
# borclandirmasi, gecikme ayari...
#
# ESKI GEREKCE VE NEDEN GECERSIZ:
#   "Tahakkuk bir BORC YAZMAKTIR ve duzeltilebilir; tahsilat ise PARA
#    ALINDI beyanidir." (P167)
# Ayrim mantikli ama YANLIS YERE cizilmisti: parayi kapida elden alan
# kisi YONETICIDIR, platform admini degil. Platform admininin o
# tahsilati girmesi icin once yoneticiden duymasi gerekir — yani kaydin
# dogrulugu zaten yoneticiye dayaniyordu; yetkiyi ondan almak kaydi
# GECIKTIRMEKTEN baska bir sey yapmiyordu. Modul, yonetici
# kullanamadigi icin fiilen calismiyordu.
#
# DEGISEN SEY YETKI, KAPSAM DEGIL: yonetici yalnizca KENDI tesisinde
# yazar. Uc yerden birden kapali (P167'de olculdu, hâlâ gecerli):
#   1. `get_tenant_db` oturumu token'daki tenant'a RLS ile baglar,
#   2. baska tesisin kasa/daire kimligi 422 `invalid_reference` alir,
#   3. kayit `tenant_id=user.tenant_id` ile yazilir — istekten GELMEZ.
#
# DENETCI DEGISMEDI: salt okuma (`_OKUMA`). Sakin finans uclarina hic
# giremez.

# (P168 §2) ICRA YAZMA YONETICIYE DE ACIK.
#
# Onceki hâl `require_role("admin")`di ve sonucu ekranda gorunuyordu:
# yonetici sayfayi aciyor, "+ Yeni" dugmesi CIZILMIYOR (basilacak ama 403
# alacak bir dugme cizmemek dogru karardi) — yani sayfa yonetici icin
# SALT GORUNTULEMEYDI ve brief'in istedigi olusturma hic yapilamiyordu.
#
# Icra dosyasi acmak TESIS YONETIMI isidir, platform yoneticiligi degil:
# borcu takip eden, avukatla konusan ve dosyayi acan kisi yoneticidir.
# P167 §4'te finansal yazma zaten admin+yonetici'ye acilmisti; icrayi
# disarida birakmak tutarsizdi.
_YAZMA = require_role("admin", "yonetici")
# (P128) `_OKUMA` YALNIZ GET uclarinda kullanilir (hareketler, kasa
# bakiyeleri, ozet, icra dosyalari listesi); denetcinin mali gozetimi tam
# olarak bu kayitlar uzerindedir. Yazan uclar `_YAZMA`dadir (P206 §1:
# admin + yonetici) ve denetci oraya HIC girmez.
_OKUMA = require_role("admin", "yonetici", "denetci")


async def _kasa_var(db: AsyncSession, kasa_id: uuid.UUID) -> None:
    var = (
        await db.execute(select(Kasa.id).where(Kasa.id == kasa_id))
    ).scalar_one_or_none()
    if var is None:
        raise APIError(422, "invalid_reference", "kasa_bulunamadi")


async def _adlarla(
    db: AsyncSession, kayitlar: list[FinansalHareket]
) -> list[HareketOut]:
    """Kasa + kisi adlarini TEK sorguda coz (kayit basina N+1 yok)."""
    if not kayitlar:
        return []
    k_idler = {k.kasa_id for k in kayitlar if k.kasa_id}
    u_idler = {k.user_id for k in kayitlar if k.user_id}
    k_ad = dict(
        (await db.execute(select(Kasa.id, Kasa.ad).where(Kasa.id.in_(k_idler)))).all()
    ) if k_idler else {}
    u_ad = dict(
        (await db.execute(
            select(AppUser.id, AppUser.ad).where(AppUser.id.in_(u_idler))
        )).all()
    ) if u_idler else {}
    return [
        HareketOut.model_validate(k).model_copy(update={
            "kasa_ad": k_ad.get(k.kasa_id), "user_ad": u_ad.get(k.user_id),
        })
        for k in kayitlar
    ]


def _hareket(user: AppUser, **alanlar) -> FinansalHareket:
    tarih = alanlar.pop("tarih", None)
    obj = FinansalHareket(
        tenant_id=user.tenant_id, kaydeden_user_id=user.id, **alanlar
    )
    if tarih is not None:
        obj.tarih = tarih
    return obj


# ============================ IDEMPOTENCY (P64) ============================= #
#
# OLCULEN RISK: panelin dugmesi ucus sirasinda kilitli oldugu icin HIZLI
# CIFT TIKLAMA zaten korunuyordu; korunmayan sey ZAMAN ASIMI SONRASI
# TEKRARDI — istek sunucuya ulasip yanit donmezse kullanici "kaydedilmedi"
# sanip tekrar basar ve kasada IKI hareket olusur. Yonetici bunu ancak
# mutabakatta fark eder.
#
# BASLIK ZORUNLU DEGIL (`dues/payments`ten farkli olarak): bu uclar
# calisan bir prod'da kullaniliyor ve zorunlu kilmak, baslik gondermeyen
# her istemciyi ANINDA kirardi. Gonderildiginde koruma TAM;
# gonderilmediginde eski davranis aynen surer. Panel gonderir.
#
# TEKRAR = AYNI YANIT, YENI KAYIT DEGIL. Govde farkliysa 409: ayni
# kimlikle baska bir tutar gondermek istemci kusurudur ve sessizce eski
# kaydi dondurmek, kullaniciya "kaydedildi" deyip PARAYI KAYDETMEMEK
# olurdu.


def _idem(anahtar: str | None) -> str | None:
    """Basligi normalize et; bos/bosluk = YOK."""
    if anahtar is None:
        return None
    kirpik = anahtar.strip()
    return kirpik or None


def _imza(kayitlar: list[FinansalHareket]) -> list[tuple]:
    """Islemin OZU — tekrar gelen istegin ayni is olup olmadigi buradan.

    Aciklama/belge no gibi serbest metinler DISARIDA: kullanici tekrar
    denerken aciklamayi duzeltmis olabilir; para hareketinin kendisi
    (tip, yon, tutar, kasa) aynıysa bu AYNI islemdir.
    """
    return [(k.tip, k.yon, k.tutar_kurus, str(k.kasa_id)) for k in kayitlar]


async def _idem_mevcut(
    db: AsyncSession, anahtar: str | None
) -> list[FinansalHareket]:
    if anahtar is None:
        return []
    return list(
        (
            await db.execute(
                select(FinansalHareket)
                .where(FinansalHareket.idempotency_key == anahtar)
                .order_by(FinansalHareket.idem_satir)
            )
        ).scalars().all()
    )


async def _idem_yaz(
    db: AsyncSession,
    response: Response,
    anahtar: str | None,
    kayitlar: list[FinansalHareket],
) -> tuple[list[FinansalHareket], bool]:
    """Kayitlari idempotent yaz. Doner: (satirlar, TEKRAR miydi).

    Uc yol:
      1. Kimlik yok  -> eski davranis (duz ekle).
      2. Kimlik daha once gorulmus -> mevcut satirlar, 200, YENI KAYIT YOK.
      3. Kimlik yeni -> yazilir; ARADA baska bir istek ayni kimligi
         yazdiysa benzersizlik ihlali gelir ve o zaman da (2)'ye duseriz.
         Bu ucuncu dal, iki istegin AYNI ANDA gelmesini kapsar — tek
         basina "once oku sonra yaz" yarisi acik birakirdi.
    """
    if anahtar is not None:
        mevcut = await _idem_mevcut(db, anahtar)
        if mevcut:
            if _imza(mevcut) != _imza(kayitlar):
                raise APIError(409, "conflict", "idempotency_key_govde_farkli")
            response.status_code = 200
            return mevcut, True
        for i, k in enumerate(kayitlar):
            k.idempotency_key = anahtar
            k.idem_satir = i
    try:
        async with db.begin_nested():
            db.add_all(kayitlar)
            await db.flush()
    except IntegrityError as exc:
        for k in kayitlar:
            # Savepoint geri alinca nesneler zaten oturumdan dusmus
            # olabilir; `expunge` o zaman atar ve ASIL hatayi golgelerdi.
            try:
                db.expunge(k)
            except Exception:
                pass
        if anahtar is not None and is_unique_violation(exc):
            mevcut = await _idem_mevcut(db, anahtar)
            if mevcut:
                response.status_code = 200
                return mevcut, True
        raise translate_integrity(exc)
    for k in kayitlar:
        await db.refresh(k)
    return kayitlar, False


# =============================== TAHSILAT =================================== #
@router.post("/finans/tahsilat", response_model=HareketOut, status_code=201)
async def tahsilat(
    body: TahsilatCreate,
    response: Response,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZMA),
) -> HareketOut:
    """Tekil tahsilat — kasaya GIRIS.

    (P192 §1) `POST /dues/payments` ILE AYNI DEFTERE yazar. Onceden bu iki
    uc iki ayri tabloya yaziyordu: vezneden girilen tahsilat kasayi
    artirip SAKININ BORCUNU KAPATMIYOR, aidat ucundan girilen odeme borcu
    kapatip KASAYI ARTIRMIYORDU. Artik ikisi de ayni satiri uretir;
    `assessment_id` verildiginde borc da kapanir.
    """
    await _kasa_var(db, body.kasa_id)
    donem = body.donem
    if body.assessment_id is not None:
        tahakkuk = await get_or_404(db, DuesAssessment, body.assessment_id)
        # (P192 §1) DONEM TAHAKKUKTAN TURER: vezneden girilen tahsilat
        # donemsiz kalirsa "bu ayin tahsilat orani" hesabina giremez ve
        # ayni para panelde gorunup raporda gorunmezdi.
        if donem is None:
            donem = tahakkuk.donem
    obj = _hareket(
        user, tip="tahsilat", yon="giris", tutar_kurus=body.tutar_kurus,
        kasa_id=body.kasa_id, user_id=body.user_id, unit_id=body.unit_id,
        assessment_id=body.assessment_id, donem=donem,
        yontem=body.yontem or "elden",
        # (P167 Asama 4) BELGE NO MERKEZDEN. Kullanici yazdiysa o korunur
        # (elindeki gercek makbuz numarasi olabilir); bos biraktiysa seri
        # `belge_no.py`den gelir. Benzersizligi `uq_hareket_belge_no`
        # koruyor — elle var olan bir numara yazilirsa istek 409 doner.
        belge_no=await belge_no_ata(
            db, user.tenant_id, "tahsilat", body.belge_no, body.tarih
        ),
        aciklama=body.aciklama, tarih=body.tarih,
    )
    satirlar, tekrar = await _idem_yaz(db, response, _idem(idempotency_key), [obj])
    # TEKRAR DENETIME YAZILMAZ: hicbir yeni para hareketi olusmadi ve
    # denetim kaydi "iki tahsilat girildi" gibi okunurdu.
    if not tekrar:
        await audit_user(
            db, user, Action.FINANS_HAREKET_CREATE,
            resource_type="finansal_hareket",
            resource_id=satirlar[0].id,
            meta={"tip": "tahsilat", "tutar": satirlar[0].tutar_kurus},
        )
    return (await _adlarla(db, satirlar))[0]


@router.post("/finans/tahsilat/toplu", response_model=HareketListResponse, status_code=201)
async def toplu_tahsilat(
    body: TopluTahsilatIstek,
    response: Response,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZMA),
) -> HareketListResponse:
    """Cok satirli tahsilat — TEK ISLEMDE ya hepsi ya hicbiri.

    Kismi basari, kullaniciya "kac satir gecti" diye saydirmak ve kalanlari
    elle tekrar girdirmek demekti; tahsilatta bu, ayni parayi iki kez
    kaydetme riskidir.
    """
    await _kasa_var(db, body.kasa_id)
    kayitlar = []
    for satir in body.satirlar:
        obj = _hareket(
            user, tip="tahsilat", yon="giris", tutar_kurus=satir.tutar_kurus,
            kasa_id=body.kasa_id, user_id=satir.user_id, unit_id=satir.unit_id,
            assessment_id=satir.assessment_id, aciklama=satir.aciklama,
            tarih=body.tarih, donem=satir.donem, yontem="elden",
            # HER SATIR KENDI NUMARASINI ALIR: toplu tahsilat N ayri
            # makbuzdur, tek belge degil. Fis basina tek numara vermek,
            # sakinin kendi makbuzunu bulmasini imkansiz kilardi.
            belge_no=await belge_no_ata(
                db, user.tenant_id, "tahsilat", None, body.tarih
            ),
        )
        kayitlar.append(obj)
    satirlar, tekrar = await _idem_yaz(
        db, response, _idem(idempotency_key), kayitlar
    )
    if not tekrar:
        await audit_user(
            db, user, Action.FINANS_HAREKET_CREATE,
            resource_type="finansal_hareket",
            meta={"tip": "tahsilat_toplu", "adet": len(satirlar)},
        )
    return HareketListResponse(
        meta={"limit": len(satirlar), "offset": 0, "total": len(satirlar)},
        items=await _adlarla(db, satirlar),
    )


# ========================= GIDER / GELIR HAREKETI =========================== #
@router.post("/finans/hareketler", response_model=HareketListResponse, status_code=201)
async def hareket_ekle(
    body: HareketToplu,
    response: Response,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZMA),
) -> HareketListResponse:
    """Cok satirli gider/gelir girisi ("Yeni Satır" akisi)."""
    kayitlar = []
    for satir in body.satirlar:
        await _kasa_var(db, satir.kasa_id)
        kayitlar.append(_hareket(
            user, tip=satir.tip,
            # GIDER kasadan CIKAR, GELIR kasaya GIRER — yon istemciden
            # alinmaz; alinsaydi "giris yonlu gider" gibi imkansiz bir
            # satir yazilabilirdi.
            yon="cikis" if satir.tip == "gider" else "giris",
            tutar_kurus=satir.tutar_kurus, kasa_id=satir.kasa_id,
            firma_id=satir.firma_id,
            gelir_gider_tanim_id=satir.gelir_gider_tanim_id,
            belge_no=await belge_no_ata(
                db, user.tenant_id, satir.tip, satir.belge_no, satir.tarih
            ),
            aciklama=satir.aciklama, tarih=satir.tarih,
            # (P167 Asama 2) Satir bazinda durum: ayni fiste bir kalem
            # odenmis, oteki onay bekliyor olabilir. Fis basina tek durum,
            # kullaniciyi fisi bolmeye zorlardi.
            durum=satir.durum,
        ))
    satirlar, tekrar = await _idem_yaz(
        db, response, _idem(idempotency_key), kayitlar
    )
    if not tekrar:
        await audit_user(
            db, user, Action.FINANS_HAREKET_CREATE,
            resource_type="finansal_hareket",
            meta={"adet": len(satirlar)},
        )
    return HareketListResponse(
        meta={"limit": len(satirlar), "offset": 0, "total": len(satirlar)},
        items=await _adlarla(db, satirlar),
    )


@router.get("/finans/hareketler", response_model=HareketListResponse)
async def hareket_listesi(
    tip: str | None = Query(None),
    kasa_id: uuid.UUID | None = Query(None),
    user_id: uuid.UUID | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_OKUMA),
) -> HareketListResponse:
    q = select(FinansalHareket)
    if tip is not None:
        q = q.where(FinansalHareket.tip == tip)
    if kasa_id is not None:
        q = q.where(FinansalHareket.kasa_id == kasa_id)
    if user_id is not None:
        q = q.where(FinansalHareket.user_id == user_id)
    total = (
        await db.execute(select(func.count()).select_from(q.subquery()))
    ).scalar_one()
    rows = (
        (await db.execute(
            q.order_by(FinansalHareket.tarih.desc(),
                       FinansalHareket.created_at.desc(),
                       FinansalHareket.id.desc())
            .limit(limit).offset(offset)
        )).scalars().all()
    )
    return HareketListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=await _adlarla(db, list(rows)),
    )


# ================================ VIRMAN ==================================== #
@router.post("/finans/virman", response_model=HareketListResponse, status_code=201)
async def virman(
    body: VirmanIstek,
    response: Response,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZMA),
) -> HareketListResponse:
    """Hesaplar arasi virman — IKI SATIR (cikis + giris), ayni gruba bagli.

    Tek satirla iki kasayi etkilemek, "bu kasadan ne cikti" sorgusunu kasa
    basina degil hareket basina cevaplamak zorunda birakirdi; bakiye
    turetimi de iki farkli kural isterdi.
    """
    await _kasa_var(db, body.kaynak_kasa_id)
    await _kasa_var(db, body.hedef_kasa_id)
    grup = uuid.uuid4()
    # VIRMANIN IKI SATIRI AYNI BELGE NUMARASINI PAYLASIR ve bu bilincli:
    # ikisi TEK BIR ISLEMDIR (bir kasadan cikip otekine giren ayni para).
    # Ayri numara vermek, ekstrede iki bagimsiz fis gibi gorunmelerine ve
    # "bu cikisin karsiligi hangi giris?" sorusunun ancak `virman_grup_id`
    # okunarak cevaplanmasina yol acardi — o alan ise ciktilarda yok.
    #
    # BENZERSIZLIK KISITI BUNU ENGELLEMEZ: `uq_hareket_belge_no`
    # (tenant, belge_no) uzerinde ve iki satir ayni degeri tasidigi icin
    # catisirdi. Bu yuzden virman satirlari numarayi ALMAZ — numara
    # `virman_grup_id`ye baglanir ve ciktida ondan uretilir.
    #
    # KARAR: virmanda `belge_no` NULL kalir. Kisit `WHERE belge_no IS NOT
    # NULL` oldugu icin bu gecerlidir ve ekstrede iki satir ZATEN
    # `virman_grup_id` ile eslesir.
    cikis = _hareket(
        user, tip="virman", yon="cikis", tutar_kurus=body.tutar_kurus,
        kasa_id=body.kaynak_kasa_id, virman_grup_id=grup,
        aciklama=body.aciklama, tarih=body.tarih,
    )
    giris = _hareket(
        user, tip="virman", yon="giris", tutar_kurus=body.tutar_kurus,
        kasa_id=body.hedef_kasa_id, virman_grup_id=grup,
        aciklama=body.aciklama, tarih=body.tarih,
    )
    satirlar, tekrar = await _idem_yaz(
        db, response, _idem(idempotency_key), [cikis, giris]
    )
    if not tekrar:
        await audit_user(
            db, user, Action.FINANS_HAREKET_CREATE,
            resource_type="finansal_hareket",
            resource_id=satirlar[0].id,
            meta={"tip": "virman", "grup": str(grup), "tutar": body.tutar_kurus},
        )
    return HareketListResponse(
        meta={"limit": len(satirlar), "offset": 0, "total": len(satirlar)},
        items=await _adlarla(db, satirlar),
    )


# ================================= IADE ===================================== #
@router.post("/finans/iade", response_model=HareketOut, status_code=201)
async def iade(
    body: IadeIstek,
    response: Response,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZMA),
) -> HareketOut:
    """Odeme iadesi — TERS YONLU yeni bir hareket.

    Orijinal kayit SILINMEZ ya da degistirilmez: defter APPEND-ONLY okunur,
    silinen bir tahsilat gecmis raporlari geriye donuk degistirirdi.
    Kismi iade serbest ama TOPLAM iade orijinali ASAMAZ.
    """
    orijinal = await get_or_404(db, FinansalHareket, body.hareket_id)
    if orijinal.tip == "iade":
        raise APIError(422, "validation_error", "iade_iade_edilemez")

    onceki = (
        await db.execute(
            select(func.coalesce(func.sum(FinansalHareket.tutar_kurus), 0))
            .where(FinansalHareket.iade_edilen_id == orijinal.id)
        )
    ).scalar_one()
    tutar = body.tutar_kurus or (orijinal.tutar_kurus - onceki)
    if tutar <= 0 or onceki + tutar > orijinal.tutar_kurus:
        raise APIError(422, "validation_error", "iade_tutari_asiyor")

    obj = _hareket(
        user, tip="iade",
        # TERS yon: giris olan bir tahsilatin iadesi kasadan CIKAR.
        yon="cikis" if orijinal.yon == "giris" else "giris",
        tutar_kurus=tutar, kasa_id=orijinal.kasa_id, user_id=orijinal.user_id,
        unit_id=orijinal.unit_id, iade_edilen_id=orijinal.id,
        # (P192 §1) BORC ATFI TASINIR: iade edilen tahsilat hangi borca
        # sayildiysa, iade de o borcu YENIDEN ACAR. Tasinmasaydi para
        # kasadan cikar ama borc kapali kalirdi.
        assessment_id=orijinal.assessment_id, donem=orijinal.donem,
        belge_no=await belge_no_ata(db, user.tenant_id, "iade", None, body.tarih),
        aciklama=body.aciklama, tarih=body.tarih,
    )
    satirlar, tekrar = await _idem_yaz(db, response, _idem(idempotency_key), [obj])
    if not tekrar:
        await audit_user(
            db, user, Action.FINANS_HAREKET_CREATE,
            resource_type="finansal_hareket",
            resource_id=satirlar[0].id,
            meta={"tip": "iade", "orijinal": str(orijinal.id)},
        )
    return (await _adlarla(db, satirlar))[0]


@router.post(
    "/finans/hareketler/{hareket_id}/iptal",
    response_model=HareketOut,
    status_code=201,
)
async def hareket_iptal(
    hareket_id: uuid.UUID,
    body: IptalIstek,
    response: Response,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZMA),
) -> HareketOut:
    """(P154 / Asama 10) YANLIS GIRILEN KAYDI TERS KAYITLA IPTAL EDER.

    KAYIT SILINMEZ — silinemez de: `finansal_hareket` uzerinde app_rw'nin
    DELETE yetkisi goc 0047'de GERI ALINDI. Bir muhasebe kaydi "hic
    olmamis" hâle getirilemez; gecmis raporlari geriye donuk degistirirdi.

    IPTAL ILE IADE AYRI SEYLER ve ayri tiplerdir:
      * IADE  — musteriye para donusu. GERCEK bir hareket, kismi olabilir.
      * IPTAL — kayit duzeltmesi. Tam tutar, ters yon, kismi OLMAZ.
    Ikisini ayni tiple yazmak, "bu ay ne kadar iade verdik" sorusunu
    yanlis yanitlardi.

    IKINCI KEZ IPTAL EDILEMEZ (409): iki ters kayit, orijinali geri
    getirmis gibi gorunen bir bakiye uretirdi.
    """
    orijinal = await get_or_404(db, FinansalHareket, hareket_id)
    if orijinal.tip == "iptal":
        raise APIError(422, "validation_error", "iptal_iptal_edilemez")

    zaten = (
        await db.execute(
            select(FinansalHareket.id)
            .where(FinansalHareket.ters_kayit_id == orijinal.id)
        )
    ).first()
    if zaten is not None:
        raise APIError(409, "conflict", "hareket_zaten_iptal")

    obj = _hareket(
        user, tip="iptal",
        # TERS yon: girisi olan bir kaydin iptali kasadan CIKAR.
        yon="cikis" if orijinal.yon == "giris" else "giris",
        tutar_kurus=orijinal.tutar_kurus, kasa_id=orijinal.kasa_id,
        user_id=orijinal.user_id, unit_id=orijinal.unit_id,
        firma_id=orijinal.firma_id,
        gelir_gider_tanim_id=orijinal.gelir_gider_tanim_id,
        budget_category_id=orijinal.budget_category_id,
        assessment_id=orijinal.assessment_id, donem=orijinal.donem,
        ters_kayit_id=orijinal.id,
        # IPTAL KENDI SERISINI kullanir (`IPT-...`). Iptal edilen belgeyle
        # AYNI numarayi tasisaydi defterde iki satir ayni belgeye isaret
        # eder ve "hangisi gecerli" sorusu numaradan cevaplanamazdi;
        # ayrica benzersizlik kisiti da catisirdi.
        belge_no=await belge_no_ata(db, user.tenant_id, "iptal", None, body.tarih),
        aciklama=body.aciklama, tarih=body.tarih,
    )
    satirlar, tekrar = await _idem_yaz(db, response, _idem(idempotency_key), [obj])
    if not tekrar:
        # ESKI/YENI DEGER `meta`ya yazilir, ayri sutuna DEGIL: `audit_log`
        # semasi geneldir ve finans icin sutun eklemek onu tek bir modulun
        # tablosuna cevirirdi (yol haritasi §8.2).
        await audit_user(
            db, user, Action.FINANS_HAREKET_CREATE,
            resource_type="finansal_hareket",
            resource_id=satirlar[0].id,
            meta={
                "tip": "iptal",
                "iptal_edilen": str(orijinal.id),
                "eski": {"tip": orijinal.tip, "yon": orijinal.yon,
                         "tutar_kurus": orijinal.tutar_kurus},
                "yeni": {"tip": "iptal", "yon": satirlar[0].yon,
                         "tutar_kurus": satirlar[0].tutar_kurus},
            },
        )
    return (await _adlarla(db, satirlar))[0]


# ========================= (P192 §2.3) HARCAMA ONAYI ======================== #
#
# ================================================================
# NEDEN ACILDI
# ================================================================
# `durum='onay_bekliyor'` P167'de eklendi, panel "Onay Bekleyen Hareketler"
# kartinda sayiyordu ama ONAYLAYAN UC YOKTU: onaya dusen bir gider
# sonsuza kadar bekliyordu. `docs/finans-analiz.md` bunu "yarim kalmis
# ozellik" olarak raporladi.
#
# ================================================================
# ONAY = GERCEKLESTI, RED = HIC OLMADI
# ================================================================
# Onay `odendi` yazar ve hareket O AN kasa bakiyesine girer (bakiye
# yalniz gerceklesmis satirlari sayar, bkz. §2.2). Red `iptal` yazar:
# TERS KAYIT DEGIL, cunku ters kayit GERCEKLESMIS bir hareketi duzeltir;
# reddedilen gider ise hic gerceklesmedi ve kasadan hic cikmadi. Ters
# kayit yazsaydik defterde birbirini goturen iki sahte satir olurdu.
#
# ================================================================
# SILME YOK
# ================================================================
# Reddedilen satir SILINMEZ: "bu harcama talebi reddedildi" bilgisi
# denetimin konusudur ve silinirse bir daha sorulamaz.


def _onaylanabilir(hareket: FinansalHareket) -> None:
    if hareket.durum != "onay_bekliyor":
        raise APIError(409, "conflict", "hareket_onay_beklemiyor")


@router.post(
    "/finans/hareketler/{hareket_id}/onayla",
    response_model=HareketOut,
)
async def hareket_onayla(
    hareket_id: uuid.UUID,
    body: HareketOnayIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZMA),
) -> HareketOut:
    """Onay bekleyen hareketi ONAYLA — o an gerceklesmis sayilir."""
    obj = await get_or_404(db, FinansalHareket, hareket_id)
    _onaylanabilir(obj)
    obj.durum = "odendi"
    if body.aciklama:
        obj.aciklama = body.aciklama
    await db.flush()
    await audit_user(
        db, user, Action.FINANS_HAREKET_ONAY, resource_type="finansal_hareket",
        resource_id=obj.id,
        meta={"tip": obj.tip, "tutar_kurus": obj.tutar_kurus},
    )
    return (await _adlarla(db, [obj]))[0]


@router.post(
    "/finans/hareketler/{hareket_id}/reddet",
    response_model=HareketOut,
)
async def hareket_reddet(
    hareket_id: uuid.UUID,
    body: HareketOnayIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZMA),
) -> HareketOut:
    """Onay bekleyen hareketi REDDET — hic gerceklesmemis sayilir."""
    obj = await get_or_404(db, FinansalHareket, hareket_id)
    _onaylanabilir(obj)
    obj.durum = "iptal"
    if body.aciklama:
        obj.aciklama = body.aciklama
    await db.flush()
    await audit_user(
        db, user, Action.FINANS_HAREKET_RED, resource_type="finansal_hareket",
        resource_id=obj.id,
        meta={"tip": obj.tip, "tutar_kurus": obj.tutar_kurus,
              "sebep": body.aciklama},
    )
    return (await _adlarla(db, [obj]))[0]


# ============================== ACILIS FISI ================================= #
@router.post("/finans/acilis", response_model=HareketOut, status_code=201)
async def acilis_fisi(
    body: AcilisFisi,
    response: Response,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZMA),
) -> HareketOut:
    """Acilis fisi — kisi/kasa baslangic bakiyesi defterde bir HAREKETTIR.

    Kasa tanimindaki `acilis_bakiye_kurus` KASANIN kendi acilisidir; bu fis
    ise KISI bazli acilis (devreden borc/alacak) icindir ve ikisi ayni
    toplama girer.
    """
    await _kasa_var(db, body.kasa_id)
    obj = _hareket(
        user, tip="acilis", yon=body.yon, tutar_kurus=body.tutar_kurus,
        kasa_id=body.kasa_id, user_id=body.user_id, aciklama=body.aciklama,
        tarih=body.tarih,
        belge_no=await belge_no_ata(db, user.tenant_id, "acilis", None, body.tarih),
    )
    satirlar, tekrar = await _idem_yaz(db, response, _idem(idempotency_key), [obj])
    if not tekrar:
        await audit_user(
            db, user, Action.FINANS_HAREKET_CREATE,
            resource_type="finansal_hareket",
            resource_id=satirlar[0].id, meta={"tip": "acilis"},
        )
    return (await _adlarla(db, satirlar))[0]


# ============================== KASA BAKIYE ================================= #
@router.get("/finans/kasa-bakiyeleri", response_model=KasaBakiyeResponse)
async def kasa_bakiyeleri(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_OKUMA),
) -> KasaBakiyeResponse:
    """Kasa bakiyeleri — SAKLANMAZ, defterden TURETILIR.

    (P192 §2.2) BAKIYE YALNIZ GERCEKLESMIS hareketleri sayar. Onceden
    `durum` suzgeci YOKTU: onay bekleyen bir gider ve saglayicidan
    donmemis bir kart odemesi bakiyeye ANINDA yansiyordu. Yonetici
    onaylamadigi bir odemeyi kasadan dusulmus goruyordu.

    Bekleyen tutarlar KAYBOLMAZ, AYRI dondurulur: "bakiye X, bekleyen Y"
    tek rakamdan daha dogru bir tablodur.
    """
    kasalar = (await db.execute(select(Kasa).order_by(Kasa.kod))).scalars().all()
    hareketler = (
        await db.execute(
            select(
                FinansalHareket.kasa_id,
                FinansalHareket.yon,
                FinansalHareket.durum,
                func.sum(FinansalHareket.tutar_kurus),
            ).group_by(
                FinansalHareket.kasa_id, FinansalHareket.yon,
                FinansalHareket.durum,
            )
        )
    ).all()
    gerceklesen: dict[uuid.UUID, list[tuple[str, int]]] = {}
    bekleyen: dict[uuid.UUID, dict[str, int]] = {}
    for kid, yon, durum, toplam in hareketler:
        if kid is None:
            continue
        if durum == defter.GERCEKLESEN:
            gerceklesen.setdefault(kid, []).append((yon, int(toplam)))
        elif durum != "iptal":
            # `iptal` DISARIDA: gerceklesmeyecegi belli olmus bir hareket
            # "bekleyen" degildir; bekleyende birakmak, hicbir zaman
            # gelmeyecek parayi yoneticiye beklenti olarak gosterirdi.
            kova = bekleyen.setdefault(kid, {"giris": 0, "cikis": 0})
            kova[yon] += int(toplam)

    items = []
    for k in kasalar:
        satirlar = gerceklesen.get(k.id, [])
        bakiye = kasa_bakiye(k.acilis_bakiye_kurus, satirlar)
        bek = bekleyen.get(k.id, {"giris": 0, "cikis": 0})
        items.append(KasaBakiye(
            kasa_id=k.id, kod=k.kod, ad=k.ad,
            acilis_bakiye_kurus=k.acilis_bakiye_kurus,
            hareket_kurus=bakiye - k.acilis_bakiye_kurus,
            bakiye_kurus=bakiye,
            banka_mi=k.banka_mi,
            iban=k.iban,
            bekleyen_cikis_kurus=bek["cikis"],
            bekleyen_giris_kurus=bek["giris"],
        ))
    return KasaBakiyeResponse(
        items=items,
        genel_toplam_kurus=sum(i.bakiye_kurus for i in items),
        bekleyen_cikis_toplam_kurus=sum(i.bekleyen_cikis_kurus for i in items),
    )


# ============================ BANKA ESLESTIRME ============================== #
@router.post("/finans/banka-eslestir", response_model=BankaEslestirSonuc)
async def banka_eslestirme(
    body: BankaEslestirIstek,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YAZMA),
) -> BankaEslestirSonuc:
    """Banka ekstresi satirlarina ESLESTIRME ONERISI uret.

    ONERI'dir, otomatik tahsilat DEGILDIR: banka aciklamasi serbest metindir
    ve yanlis eslesen bir satir, baskasinin borcunu kapatip gercek borclunun
    borcunu acik birakirdi. Kullanici tek tikla onaylar.

    DOSYA AYRISTIRMA ISTEMCIDE (P28 ice aktarimla ayni gerekce: xlsx
    ayristirma bir saldiri yuzeyidir). BANKA API ENTEGRASYONU KOD DEGIL
    BELGE NOTUDUR (kapsam boyle diyor) — her bankanin ayri sozlesmesi ve
    kimlik akisi var; once bir banka secilmeli.
    """
    # Acik borclu adaylari: hedeflenmis borclar (P28) + kalan tutar.
    rows = (
        await db.execute(
            # NOT: ORNEK BIR `assessment_id` DONULMEZ. (a) Postgres'te
            # `min(uuid)` yoktur — bu sorgu 500 veriyordu; (b) daha onemlisi
            # oneri KISIYI hedefler: hangi borcun kapatilacagi tahsilat
            # ekraninin isidir, cunku bir odeme birden fazla borca yayilabilir.
            select(
                DuesAssessment.hedef_user_id,
                AppUser.ad,
                func.sum(DuesAssessment.tutar_kurus),
                # (P30) Havale kodu — aciklamada gecerse eslestirme KESIN.
                func.max(AppUser.odeme_kodu),
            )
            .join(AppUser, AppUser.id == DuesAssessment.hedef_user_id)
            .where(DuesAssessment.hedef_user_id.is_not(None))
            .group_by(DuesAssessment.hedef_user_id, AppUser.ad)
        )
    ).all()
    tahsil = dict(
        (
            await db.execute(
                select(
                    FinansalHareket.user_id,
                    func.sum(FinansalHareket.tutar_kurus),
                )
                .where(
                    FinansalHareket.tip == "tahsilat",
                    FinansalHareket.user_id.is_not(None),
                )
                .group_by(FinansalHareket.user_id)
            )
        ).all()
    )
    adaylar = []
    for uid, ad, borc, kod in rows:
        kalan = int(borc) - int(tahsil.get(uid, 0))
        if kalan > 0:
            adaylar.append(BorcAdayi(str(uid), ad, kalan, odeme_kodu=kod))

    oneriler = banka_eslestir(
        [BankaSatiri(s.satir_no, s.aciklama, s.tutar_kurus) for s in body.satirlar],
        adaylar,
    )
    adlar = {a.user_id: a.ad for a in adaylar}
    return BankaEslestirSonuc(oneriler=[
        BankaEslestirOneri(
            satir_no=o.satir_no,
            user_id=uuid.UUID(o.user_id) if o.user_id else None,
            user_ad=adlar.get(o.user_id) if o.user_id else None,
            assessment_id=uuid.UUID(o.assessment_id) if o.assessment_id else None,
            guven=o.guven, neden=o.neden,
        )
        for o in oneriler
    ])


# =============================== ICRA DOSYASI =============================== #
async def _icra_zenginlestir(
    db: AsyncSession, kayitlar: list[IcraDosyasi]
) -> list[IcraDosyasiOut]:
    """Kisi adi + ACIK BORC — borc dosyaya KOPYALANMAZ, anlik okunur.

    Iki yerde tutulan borc, biri guncellenip digeri unutuldugunda hangi
    rakamin dogru oldugunu belirsiz birakirdi.
    """
    if not kayitlar:
        return []
    idler = {k.user_id for k in kayitlar}
    adlar = dict(
        (await db.execute(
            select(AppUser.id, AppUser.ad).where(AppUser.id.in_(idler))
        )).all()
    )
    borclar = dict(
        (await db.execute(
            select(DuesAssessment.hedef_user_id,
                   func.sum(DuesAssessment.tutar_kurus))
            .where(DuesAssessment.hedef_user_id.in_(idler))
            .group_by(DuesAssessment.hedef_user_id)
        )).all()
    )
    tahsil = dict(
        (await db.execute(
            select(FinansalHareket.user_id,
                   func.sum(FinansalHareket.tutar_kurus))
            .where(FinansalHareket.tip == "tahsilat",
                   FinansalHareket.user_id.in_(idler))
            .group_by(FinansalHareket.user_id)
        )).all()
    )
    return [
        IcraDosyasiOut.model_validate(k).model_copy(update={
            "user_ad": adlar.get(k.user_id),
            "acik_borc_kurus": max(
                int(borclar.get(k.user_id, 0)) - int(tahsil.get(k.user_id, 0)), 0
            ),
        })
        for k in kayitlar
    ]


@router.get("/finans/icra-dosyalari", response_model=IcraDosyasiListResponse)
async def icra_listesi(
    durum: str | None = Query(None),
    user_id: uuid.UUID | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_OKUMA),
) -> IcraDosyasiListResponse:
    q = select(IcraDosyasi)
    if durum is not None:
        q = q.where(IcraDosyasi.durum == durum)
    if user_id is not None:
        q = q.where(IcraDosyasi.user_id == user_id)
    total = (
        await db.execute(select(func.count()).select_from(q.subquery()))
    ).scalar_one()
    rows = (
        (await db.execute(
            q.order_by(IcraDosyasi.created_at.desc(), IcraDosyasi.id.desc()).limit(limit).offset(offset)
        )).scalars().all()
    )
    return IcraDosyasiListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=await _icra_zenginlestir(db, list(rows)),
    )


@router.post("/finans/icra-dosyalari", response_model=IcraDosyasiOut, status_code=201)
async def icra_olustur(
    body: IcraDosyasiCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZMA),
) -> IcraDosyasiOut:
    var = (
        await db.execute(select(AppUser.id).where(AppUser.id == body.user_id))
    ).scalar_one_or_none()
    if var is None:
        raise APIError(422, "invalid_reference", "kullanici_bulunamadi_veya_pasif")
    obj = IcraDosyasi(tenant_id=user.tenant_id, **body.model_dump())
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.ICRA_DOSYA_CREATE, resource_type="icra_dosyasi",
        resource_id=obj.id, meta={"dosya_no": obj.dosya_no},
    )
    return (await _icra_zenginlestir(db, [obj]))[0]


@router.patch("/finans/icra-dosyalari/{dosya_id}", response_model=IcraDosyasiOut)
async def icra_guncelle(
    dosya_id: uuid.UUID,
    body: IcraDosyasiUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZMA),
) -> IcraDosyasiOut:
    obj = await get_or_404(db, IcraDosyasi, dosya_id)
    veri = body.model_dump(exclude_unset=True)
    for alan, deger in veri.items():
        setattr(obj, alan, deger)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.ICRA_DOSYA_UPDATE, resource_type="icra_dosyasi",
        resource_id=obj.id, meta={"alanlar": sorted(veri)},
    )
    return (await _icra_zenginlestir(db, [obj]))[0]


@router.delete(
    "/finans/icra-dosyalari/{dosya_id}", status_code=204, response_model=None
)
async def icra_sil(
    dosya_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZMA),
) -> None:
    """(P168 §2) Icra dosyasini SIL.

    ===========================================================================
    NEDEN BURADA SILME VAR, OYSA FINANS SATIRLARI SILINMIYOR
    ===========================================================================
    "Finansal kayit silinmez" ilkesi DEFTER icindir: bir tahsilat ya da
    gider satirini silmek gecmis raporlari geriye donuk degistirir.

    Icra dosyasi DEFTER SATIRI DEGIL, bir SUREC KAYDIDIR. Borcun kendisi
    `dues_assessment`ta durur ve buraya KOPYALANMAZ (P29 karari); acik
    borc her satirda ANLIK okunur. Dosyayi silmek hicbir finansal tutari
    yok etmez — yalnizca "bu borc icin icra sureci baslatilmisti" bilgisi
    gider.

    Yanlis acilmis bir dosyayi silememek, listeyi kalici copla yasamaya
    mahkum ederdi; brief de satir menusunde "Sil" istiyor.

    DENETIME YAZILIR: dosya no ve kisi meta'ya girer, cunku silinen
    kaydin ne oldugu sonradan yalnizca denetimden okunabilir.
    """
    obj = await get_or_404(db, IcraDosyasi, dosya_id)
    await audit_user(
        db, user, Action.ICRA_DOSYA_UPDATE, resource_type="icra_dosyasi",
        resource_id=obj.id,
        meta={"silindi": True, "dosya_no": obj.dosya_no, "user_id": str(obj.user_id)},
    )
    await db.delete(obj)
    await db.flush()


# ================================ OZET ====================================== #
@router.get("/finans/ozet", response_model=FinansOzet)
async def finans_ozet(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_OKUMA),
) -> FinansOzet:
    """Panel ozet kartlari — hepsi DEFTERDEN okunur, hicbiri saklanmaz."""
    bugun = datetime.now(timezone.utc).date()
    ay_basi = date(bugun.year, bugun.month, 1)

    # (P192 §6.3) Ters kayit cifti borc DEGILDIR.
    borclandirilan = await defter.tahakkuk_toplami(db, baslangic=ay_basi)
    # (P192 §1) TEK KAYNAK: rapor, seffaflik ve mobil ana ekran da bunu
    # cagirir; iade/iptal dusulur ve yalniz gerceklesmis satirlar sayilir.
    tahsil_ay = await defter.tahsilat_toplami(db, baslangic=ay_basi)
    toplam_borc = await defter.tahakkuk_toplami(db)
    toplam_tahsil = await defter.tahsilat_toplami(db)
    bakiyeler = await kasa_bakiyeleri(db=db, _=None)  # type: ignore[arg-type]
    icra_acik = (
        await db.execute(
            select(func.count()).select_from(IcraDosyasi)
            # (P168 §2) "ACIK DOSYA" = KAPANMAMIS olan. Yeni sozlukte
            # dort deger kapanmamis sayilir; tek tek saymak yerine
            # "kapandi degil" demek, altinci bir durum eklendiginde bu
            # sayacin SESSIZCE eskimesini engeller.
            .where(IcraDosyasi.durum != "kapandi")
        )
    ).scalar_one()

    # ---------------------- (P167 §2.2) UC YENI KART ----------------------
    #
    # "BORCLARIM" — sitenin DISARIYA borcu. `acik_borc_kurus`un aynasi
    # DEGIL TERSI: o sakinin bize, bu bizim firmaya. Ikisini tek kartta
    # toplamak kimin kime borclu oldugunu okunamaz kilardi.
    #
    # `iptal` TIPI DISARIDA: ters kayit bir DUZELTMEDIR, odenmemis bir
    # borc degil. Iceri alsaydik iptal edilen her gider "borcum var" diye
    # sayilirdi.
    borc = (
        await db.execute(
            select(func.coalesce(func.sum(FinansalHareket.tutar_kurus), 0))
            .where(FinansalHareket.tip == "gider",
                   # (P192 §2.3) `!= 'odendi'` YETMEZ: `iptal` de o kumeye
                   # girerdi ve REDDEDILMIS bir harcama "borcum var" diye
                   # sayilirdi.
                   FinansalHareket.durum.in_(("bekliyor", "onay_bekliyor")),
                   FinansalHareket.ters_kayit_id.is_(None))
        )
    ).scalar_one()
    # ADET, TUTAR DEGIL: yonetici burada "ne kadar" degil "kac is
    # bekliyor" sorusunu soruyor; tutar tiklayinca acilan listede.
    onay_bekleyen = (
        await db.execute(
            select(func.count()).select_from(FinansalHareket)
            .where(FinansalHareket.durum == "onay_bekliyor")
        )
    ).scalar_one()
    # "ODENMIS FATURALAR (bu ay)" — tarihe gore, kayit zamanina gore
    # DEGIL: gecen ayin faturasi bu ay girilmis olabilir ve onu bu ayin
    # gideri saymak defterle celisirdi.
    odenmis_fatura_ay = (
        await db.execute(
            select(func.coalesce(func.sum(FinansalHareket.tutar_kurus), 0))
            .where(FinansalHareket.tip == "gider",
                   FinansalHareket.durum == "odendi",
                   FinansalHareket.ters_kayit_id.is_(None),
                   FinansalHareket.tarih >= ay_basi)
        )
    ).scalar_one()

    return FinansOzet(
        borclandirilan_ay_kurus=int(borclandirilan),
        tahsil_edilen_ay_kurus=int(tahsil_ay),
        acik_borc_kurus=max(int(toplam_borc) - int(toplam_tahsil), 0),
        kasa_toplam_kurus=bakiyeler.genel_toplam_kurus,
        icra_acik_dosya=int(icra_acik),
        borc_kurus=int(borc),
        onay_bekleyen_adet=int(onay_bekleyen),
        odenmis_fatura_ay_kurus=int(odenmis_fatura_ay),
    )
