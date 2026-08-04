"""Borclandirma UCLARI (P28) — tekil / toplu / sayac / ice aktarim.

BIRLESTIRME KARARI: paralel bir sistem YOK. Dort yol da mevcut
`dues_assessment` kaydina yazar; mobil "Aidatim", `/units/{id}/dues` ve
`/reports/financial-summary` degismeden calismaya devam eder. Ayri bir
tablo, `dues_payment`in neye baglanacagini ikiye bolerdi.

TEKIL borclandirma icin AYRI BIR UC ACILMADI: `POST /dues/assessments`
zaten odur ve P28 alanlari ona OPSIYONEL olarak eklendi (geriye uyum).

RBAC: yazma admin (mevcut aidat kuralinin aynisi); ayar okuma admin+yonetici.
"""
from __future__ import annotations

import uuid
from datetime import date

from fastapi import APIRouter, Depends, Header
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..borclandirma import (
    Bag,
    esit_dagit,
    hedef_sec,
    sayac_tuketim_dagitimi,
    tipe_gore_dagit,
)
from ..crud_helpers import get_or_404, is_unique_violation, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..hata_metinleri import hata_metni, istek_dili
from ..models import (
    AppUser,
    DuesAssessment,
    GelirGiderTanim,
    SayacAna,
    SayacBolum,
    Tenant,
    Unit,
    UnitResident,
    UnitTip,
)
from ..schemas import (
    BorcIceAktarimIstek,
    BorcIceAktarimSonuc,
    DuesAssessmentResult,
    GecikmeAyarOut,
    GecikmeAyarUpdate,
    SayacBorcIstek,
    TopluBorcIstek,
    TopluBorcOnizleme,
    TopluBorcSatir,
)

router = APIRouter(tags=["aidat"])

_ADMIN = require_role("admin")
_YONETIM = require_role("admin", "yonetici")
# (P128) Gecikme (temerrut) AYARI okunur: tahakkuk ile tahsilat
# arasindaki farkin ne kadarinin gecikme faizi oldugu bu ayardan
# anlasilir. Ayari DEGISTIRMEK `_YONETIM`de kalir.
_AYAR_OKUR = require_role("admin", "yonetici", "denetci")


# --------------------------- ortak yardimcilar ------------------------------ #
async def _tanim(db: AsyncSession, tanim_id: uuid.UUID) -> GelirGiderTanim:
    obj = (
        await db.execute(
            select(GelirGiderTanim).where(GelirGiderTanim.id == tanim_id)
        )
    ).scalar_one_or_none()
    if obj is None:
        raise APIError(422, "invalid_reference", "gelir_gider_tanim_yok")
    if obj.tip == "gelir":
        # Bir GELIR kalemi BORCLANDIRILMAZ; tahsil edilir. Bunu kabul etmek
        # kiraci gelirini sakine borc yazmak olurdu.
        raise APIError(422, "validation_error", "gelir_kalemi_borclandirilmaz")
    return obj


async def _daire_baglari(
    db: AsyncSession, unit_idler: list[uuid.UUID]
) -> dict[uuid.UUID, list[Bag]]:
    """Daire -> AKTIF sakin baglari (P23). TEK sorgu (daire basina N+1 yok)."""
    if not unit_idler:
        return {}
    rows = (
        await db.execute(
            select(UnitResident.unit_id, UnitResident.user_id, UnitResident.rol_tipi)
            .where(
                UnitResident.unit_id.in_(unit_idler),
                UnitResident.bitis.is_(None),
            )
        )
    ).all()
    sonuc: dict[uuid.UUID, list[Bag]] = {}
    for uid, kullanici, rol in rows:
        sonuc.setdefault(uid, []).append(Bag(str(kullanici), rol))
    return sonuc


async def _hedef_adlari(
    db: AsyncSession, idler: set[uuid.UUID]
) -> dict[uuid.UUID, str]:
    if not idler:
        return {}
    return dict(
        (await db.execute(select(AppUser.id, AppUser.ad).where(AppUser.id.in_(idler)))).all()
    )


async def _hedef_daireler(
    db: AsyncSession, suzgec
) -> list[tuple[uuid.UUID, str, uuid.UUID | None]]:
    """Suzgece uyan AKTIF daireler: (id, no, unit_tip_id)."""
    q = select(Unit.id, Unit.no, Unit.unit_tip_id).where(Unit.aktif.is_(True))
    if suzgec.unit_ids:
        # Elle secim suzgeci EZER: kullanici tek tek sectiyse blok/tip
        # kisitlarini ayrica uygulamak "sectigim daire neden yok" uretirdi.
        q = select(Unit.id, Unit.no, Unit.unit_tip_id).where(
            Unit.id.in_(suzgec.unit_ids)
        )
    else:
        if suzgec.blok is not None:
            q = q.where(Unit.blok == suzgec.blok)
        if suzgec.unit_tip_id is not None:
            q = q.where(Unit.unit_tip_id == suzgec.unit_tip_id)
        if suzgec.unit_grup_id is not None:
            q = q.where(Unit.unit_grup_id == suzgec.unit_grup_id)
    return [(r[0], r[1], r[2]) for r in (await db.execute(q.order_by(Unit.no))).all()]


async def _tip_varsayilanlari(db: AsyncSession) -> dict[uuid.UUID, int | None]:
    rows = (
        await db.execute(select(UnitTip.id, UnitTip.varsayilan_aidat_kurus))
    ).all()
    return {r[0]: r[1] for r in rows}


async def _toplu_plan(
    db: AsyncSession, body: TopluBorcIstek, tanim: GelirGiderTanim
) -> list[TopluBorcSatir]:
    """Onizleme ve isleme AYNI plani kullanir — gorulen ile yazilan ayni olsun."""
    daireler = await _hedef_daireler(db, body.suzgec)
    if not daireler:
        return []
    idler = [d[0] for d in daireler]
    baglar = await _daire_baglari(db, idler)

    if body.tutar_kurus is not None:
        tutarlar: list[int | None] = [body.tutar_kurus] * len(daireler)
    else:
        varsayilanlar = await _tip_varsayilanlari(db)
        tutarlar = tipe_gore_dagit(
            [varsayilanlar.get(d[2]) if d[2] else None for d in daireler],
            body.yedek_tutar_kurus,
        )

    hedefler = {
        d[0]: hedef_sec(baglar.get(d[0], []), tanim.hedef_kurali) for d in daireler
    }
    adlar = await _hedef_adlari(
        db, {uuid.UUID(h) for h in hedefler.values() if h}
    )

    satirlar: list[TopluBorcSatir] = []
    for (uid, no, _), tutar in zip(daireler, tutarlar):
        hedef = hedefler[uid]
        satirlar.append(
            TopluBorcSatir(
                unit_id=uid,
                unit_no=no,
                tutar_kurus=tutar,
                hedef_user_id=uuid.UUID(hedef) if hedef else None,
                hedef_ad=adlar.get(uuid.UUID(hedef)) if hedef else None,
                # Tutari cozulemeyen daire ATLANIR: sessizce 0 borclandirmak,
                # yonetimin fark etmedigi eksik tahakkuk uretirdi.
                atlama_nedeni=None if tutar else "tutar_cozulemedi",
            )
        )
    return satirlar


async def _yaz(
    db: AsyncSession,
    user: AppUser,
    *,
    unit_id: uuid.UUID,
    donem: str,
    tutar_kurus: int,
    tanim_id: uuid.UUID | None,
    hedef_user_id: uuid.UUID | None,
    son_odeme_tarihi: date | None,
    tarih: date | None,
    aciklama: str | None,
    gecikme_uygula: bool,
    kaynak: str,
) -> bool:
    """Tek satir yaz; benzersizlik carpismasinda ATLA (False doner).

    SAVEPOINT: tek satirin carpismasi tum toplu islemi dusurmemeli — mevcut
    `create_assessments` ile ayni desen.
    """
    obj = DuesAssessment(
        tenant_id=user.tenant_id,
        unit_id=unit_id,
        donem=donem,
        tutar_kurus=tutar_kurus,
        gelir_gider_tanim_id=tanim_id,
        hedef_user_id=hedef_user_id,
        son_odeme_tarihi=son_odeme_tarihi,
        aciklama=aciklama,
        gecikme_uygula=gecikme_uygula,
        kaynak=kaynak,
        **({"tarih": tarih} if tarih is not None else {}),
    )
    try:
        async with db.begin_nested():
            db.add(obj)
            await db.flush()
    except IntegrityError as exc:
        try:
            db.expunge(obj)
        except Exception:
            pass
        if is_unique_violation(exc):
            return False
        raise translate_integrity(exc)
    return True


# ============================ TOPLU BORCLANDIRMA ============================ #
@router.post("/borclandirma/toplu/onizleme", response_model=TopluBorcOnizleme)
async def toplu_onizleme(
    body: TopluBorcIstek,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_ADMIN),
) -> TopluBorcOnizleme:
    """NE OLACAGINI gosterir, HICBIR SEY YAZMAZ.

    "500 daireden 3'u tipsiz" bilgisi islemeden ONCE gorulmelidir; sonra
    fark edilirse eksik tahakkuk sessizce yayilir.
    """
    tanim = await _tanim(db, body.gelir_gider_tanim_id)
    satirlar = await _toplu_plan(db, body, tanim)
    islenecek = [s for s in satirlar if s.atlama_nedeni is None]
    return TopluBorcOnizleme(
        satirlar=satirlar,
        islenecek=len(islenecek),
        atlanacak=len(satirlar) - len(islenecek),
        toplam_kurus=sum(s.tutar_kurus or 0 for s in islenecek),
    )


@router.post("/borclandirma/toplu", response_model=DuesAssessmentResult, status_code=201)
async def toplu_borclandir(
    body: TopluBorcIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> DuesAssessmentResult:
    """Onizlemedeki plani ISLER (ayni govde, ayni plan)."""
    tanim = await _tanim(db, body.gelir_gider_tanim_id)
    satirlar = await _toplu_plan(db, body, tanim)
    olusan = 0
    atlanan = 0
    for s in satirlar:
        if s.atlama_nedeni is not None or not s.tutar_kurus:
            atlanan += 1
            continue
        yazildi = await _yaz(
            db, user,
            unit_id=s.unit_id, donem=body.donem, tutar_kurus=s.tutar_kurus,
            tanim_id=tanim.id, hedef_user_id=s.hedef_user_id,
            son_odeme_tarihi=body.son_odeme_tarihi, tarih=body.tarih,
            aciklama=body.aciklama, gecikme_uygula=body.gecikme_uygula,
            kaynak="toplu",
        )
        olusan += 1 if yazildi else 0
        atlanan += 0 if yazildi else 1
    if olusan:
        await audit_user(
            db, user, Action.DUES_ASSESSMENT_CREATE,
            resource_type="dues_assessment",
            meta={"kaynak": "toplu", "count": olusan, "skipped": atlanan,
                  "tanim": str(tanim.id)},
        )
    # `created` BOS doner: 500 satirlik bir yanit istemciyi bogar ve onizleme
    # zaten ayrintiyi verdi. Sayilar tek dogruluk kaynagidir.
    return DuesAssessmentResult(created=[], atlanan=atlanan)


# ========================= SAYAC ILE BORCLANDIRMA =========================== #
@router.post("/borclandirma/sayac", response_model=DuesAssessmentResult, status_code=201)
async def sayac_ile_borclandir(
    body: SayacBorcIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> DuesAssessmentResult:
    """Sihirbazin 4. adimi: tuketim -> borc.

    Ilk uc adim (dagitim sekli, ana sayac, tuketim degerleri) istemcide
    toplanir ve sunucuya TEK istek gelir — ara adimlarda sunucu durumu
    tutmak, yarim kalmis sihirbazlari temizlemek zorunda birakirdi.
    """
    tanim = await _tanim(db, body.gelir_gider_tanim_id)
    ana = (
        await db.execute(select(SayacAna).where(SayacAna.id == body.ana_sayac_id))
    ).scalar_one_or_none()
    if ana is None:
        raise APIError(422, "invalid_reference", "ana_sayac_bulunamadi")

    sayaclar = (
        (
            await db.execute(
                select(SayacBolum).where(
                    SayacBolum.id.in_(list(body.bolum_tuketimleri.keys()))
                )
            )
        ).scalars().all()
    )
    if len(sayaclar) != len(body.bolum_tuketimleri):
        raise APIError(422, "invalid_reference", "bolum_sayaci_bulunamadi")

    tuketimler = [float(body.bolum_tuketimleri[s.id]) for s in sayaclar]
    borclar, _ortak = sayac_tuketim_dagitimi(
        float(body.ana_tuketim),
        tuketimler,
        body.birim_fiyat_kurus,
        float(ana.ortak_alan_yuzde) if ana.ortak_alan_yuzde is not None else None,
    )

    unit_idler = [s.unit_id for s in sayaclar]
    baglar = await _daire_baglari(db, unit_idler)
    olusan = 0
    atlanan = 0
    for sayac, borc in zip(sayaclar, borclar):
        if borc <= 0:
            # SIFIR tuketim SIFIR borc: `tutar_kurus > 0` kisiti zaten
            # reddederdi; burada acikca atlanir ki sayim dogru olsun.
            atlanan += 1
            continue
        hedef = hedef_sec(baglar.get(sayac.unit_id, []), tanim.hedef_kurali)
        yazildi = await _yaz(
            db, user,
            unit_id=sayac.unit_id, donem=body.donem, tutar_kurus=borc,
            tanim_id=tanim.id,
            hedef_user_id=uuid.UUID(hedef) if hedef else None,
            son_odeme_tarihi=body.son_odeme_tarihi, tarih=body.tarih,
            aciklama=body.aciklama or ana.ad,
            gecikme_uygula=True, kaynak="sayac",
        )
        olusan += 1 if yazildi else 0
        atlanan += 0 if yazildi else 1
    if olusan:
        await audit_user(
            db, user, Action.DUES_ASSESSMENT_CREATE,
            resource_type="dues_assessment",
            meta={"kaynak": "sayac", "count": olusan, "ana_sayac": str(ana.id)},
        )
    return DuesAssessmentResult(created=[], atlanan=atlanan)


# ============================== ICE AKTARIM ================================= #
@router.post(
    "/borclandirma/ice-aktarim", response_model=BorcIceAktarimSonuc, status_code=201
)
async def ice_aktarim(
    body: BorcIceAktarimIstek,
    accept_language: str | None = Header(None, alias="Accept-Language"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> BorcIceAktarimSonuc:
    """Satir listesinden borclandirma — SATIR BAZLI HATA RAPORU ile.

    BOZUK SATIR TUM ICE AKTARIMI DUSURMEZ: 400 satirlik bir dosyada 3 hatali
    satir yuzunden 397 dogru satiri reddetmek, kullaniciyi dosyayi elle
    ayiklamaya zorlardi. Hatalar `hatalar[]` icinde satir numarasiyla doner.

    DOSYA AYRISTIRMA ISTEMCIDE: sunucu XLSX ayristirmaz. Gerekce — xlsx
    ayristirma bir SALDIRI YUZEYIDIR (zip bombasi, XXE, formul enjeksiyonu)
    ve panel dosyayi zaten okuyup kullaniciya onizleme gostermek zorunda.
    Sunucu YAPILANDIRILMIS satir listesi alir ve her satiri dogrular.
    """
    dil = istek_dili(accept_language)
    tanim = await _tanim(db, body.gelir_gider_tanim_id)
    # Daire no -> id: TEK sorgu (satir basina arama N+1 olurdu).
    no_id = dict(
        (await db.execute(select(Unit.no, Unit.id).where(Unit.aktif.is_(True)))).all()
    )
    idler = list(no_id.values())
    baglar = await _daire_baglari(db, idler)

    olusturulan = 0
    atlanan = 0
    hatalar = []
    for satir in body.satirlar:
        no = (satir.unit_no or "").strip()
        unit_id = no_id.get(no)
        if unit_id is None:
            hatalar.append({
                "satir_no": satir.satir_no, "unit_no": no or None,
                "hata": hata_metni("daire_bulunamadi", dil),
            })
            atlanan += 1
            continue
        if not satir.tutar_kurus or satir.tutar_kurus <= 0:
            hatalar.append({
                "satir_no": satir.satir_no, "unit_no": no,
                "hata": hata_metni("tutar_pozitif_olmali", dil),
            })
            atlanan += 1
            continue
        hedef = hedef_sec(baglar.get(unit_id, []), tanim.hedef_kurali)
        yazildi = await _yaz(
            db, user,
            unit_id=unit_id, donem=body.donem, tutar_kurus=satir.tutar_kurus,
            tanim_id=tanim.id,
            hedef_user_id=uuid.UUID(hedef) if hedef else None,
            son_odeme_tarihi=body.son_odeme_tarihi, tarih=body.tarih,
            aciklama=satir.aciklama, gecikme_uygula=True, kaynak="ice_aktarim",
        )
        if yazildi:
            olusturulan += 1
        else:
            atlanan += 1
            hatalar.append({
                "satir_no": satir.satir_no, "unit_no": no,
                "hata": hata_metni("tahakkuk_zaten_var", dil),
            })
    if olusturulan:
        await audit_user(
            db, user, Action.DUES_ASSESSMENT_CREATE,
            resource_type="dues_assessment",
            meta={"kaynak": "ice_aktarim", "count": olusturulan,
                  "hatali": len(hatalar)},
        )
    return BorcIceAktarimSonuc(
        olusturulan=olusturulan, atlanan=atlanan, hatalar=hatalar
    )


# ============================== GECIKME AYARI =============================== #
@router.get("/borclandirma/gecikme-ayari", response_model=GecikmeAyarOut)
async def gecikme_ayari(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_AYAR_OKUR),
) -> GecikmeAyarOut:
    obj = await get_or_404(db, Tenant, user.tenant_id)
    return GecikmeAyarOut(gecikme_aylik_yuzde=float(obj.gecikme_aylik_yuzde))


@router.patch("/borclandirma/gecikme-ayari", response_model=GecikmeAyarOut)
async def gecikme_ayari_guncelle(
    body: GecikmeAyarUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> GecikmeAyarOut:
    """Aylik gecikme tazminati orani.

    Tazminat TUTARI SAKLANMAZ; raporlama/tahsilat aninda hesaplanir. Oran
    degistiginde gecmis kayitlar da yeni orana gore okunur — saklansaydi
    ayni borc iki farkli yerde iki farkli tutar gosterirdi.
    """
    obj = await get_or_404(db, Tenant, user.tenant_id)
    obj.gecikme_aylik_yuzde = body.gecikme_aylik_yuzde
    await db.flush()
    await db.refresh(obj)
    await audit_user(
        db, user, Action.MUHASEBE_AYAR_UPDATE, resource_type="tenant",
        resource_id=obj.id, meta={"gecikme_aylik_yuzde": body.gecikme_aylik_yuzde},
    )
    return GecikmeAyarOut(gecikme_aylik_yuzde=float(obj.gecikme_aylik_yuzde))
