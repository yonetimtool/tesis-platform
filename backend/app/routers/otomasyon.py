"""(P192 §4) FINANS OTOMASYONU UCLARI — plan, hatirlatma, duzenli gider, gunluk.

Is mantigi `app/otomasyon.py`de (Celery gorevi de ayni fonksiyonlari
cagirir); bu modul YALNIZ HTTP kabugudur. Ikisini ayirmak zorunlu:
otomasyon istek yolundan DEGIL beat'ten kosar ve router'a gomulu bir
mantik oradan cagrilamazdi.

RBAC: yazma admin+yonetici (tesisin kendi isi), okuma + denetci.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from .. import girdi_siniri as _G
from ..audit import Action, audit_user
from ..crud_helpers import get_or_404, is_unique_violation, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import (
    AidatPlani,
    AppUser,
    DuzenliGider,
    GelirGiderTanim,
    HatirlatmaAyari,
    Kasa,
    OtomasyonGunlugu,
    Tenant,
)
from ..schemas import (
    MaasAyariGuncelle,
    MaasAyariOut,
    MaasCalistirmaSonucu,
    MaasKuralGrubu,
    AidatPlaniCreate,
    AidatPlaniErtele,
    AidatPlaniListResponse,
    AidatPlaniOut,
    AidatPlaniUpdate,
    DuzenliGiderCreate,
    DuzenliGiderListResponse,
    DuzenliGiderOut,
    DuzenliGiderUpdate,
    HatirlatmaAyariOut,
    HatirlatmaAyariUpdate,
    KuralOnizleme,
    KuralSonCalisma,
    KuralSonCalismaListesi,
    OtomasyonGunlukListResponse,
    OtomasyonGunlukOut,
)

router = APIRouter(tags=["otomasyon"])

_YONETIM = require_role("admin", "yonetici")
# (P128) Denetci OKUR: "otomatik tahakkuk ne zaman kostu, ne yazdi"
# sorusu denetimin ta kendisi.
_OKUR = require_role("admin", "yonetici", "denetci")


# ============================== AIDAT PLANI ================================= #
async def _tanim_dogrula(db: AsyncSession, tanim_id: uuid.UUID) -> None:
    obj = (
        await db.execute(
            select(GelirGiderTanim).where(GelirGiderTanim.id == tanim_id)
        )
    ).scalar_one_or_none()
    if obj is None:
        raise APIError(422, "invalid_reference", "gelir_gider_tanim_yok")
    if obj.tip == "gelir":
        # Bir GELIR kalemi BORCLANDIRILMAZ; tahsil edilir.
        raise APIError(422, "validation_error", "gelir_kalemi_borclandirilmaz")


@router.post("/aidat-planlari/onizleme", response_model=KuralOnizleme)
async def plan_onizleme(
    body: AidatPlaniCreate,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> KuralOnizleme:
    """(P250 §9) KAYDETMEDEN: "bu kural bugun calissaydi N daireye X TL
    borc yazilirdi". Gorevin kullandigi AYNI plan hesabi (`toplu_plan`)
    kullanilir; onizleme ile gercek yazim ayrisamaz. Hicbir sey yazilmaz.
    """
    from datetime import date as _date

    from .. import otomasyon as oto
    from ..toplu_tahakkuk import toplu_plan

    await _tanim_dogrula(db, body.gelir_gider_tanim_id)
    tanim = (
        await db.execute(
            select(GelirGiderTanim).where(GelirGiderTanim.id == body.gelir_gider_tanim_id)
        )
    ).scalar_one()
    bugun = _date.today()
    donem = oto.donem_metni(bugun)
    # Gecici plan: ORM nesnesi DEGIL (oturuma karisma ihtimali bile
    # olmasin); `_plan_istegi` yalniz alanlari okur.
    from types import SimpleNamespace

    plan = SimpleNamespace(**body.model_dump())
    vade = oto.tahakkuk_tarihi(donem, plan.tahakkuk_gunu)
    satirlar = await toplu_plan(db, oto._plan_istegi(plan, donem, vade), tanim)
    yazilacak = [s for s in satirlar if s.tutar_kurus and not s.atlama_nedeni]
    # Ilk calisma: yeni plan bu ayin gunu GECMISSE bu gece, degilse o gun.
    ilk = (
        bugun if bugun.day >= plan.tahakkuk_gunu
        else oto.tahakkuk_tarihi(donem, plan.tahakkuk_gunu)
    )
    return KuralOnizleme(
        adet=len(yazilacak),
        toplam_kurus=sum(s.tutar_kurus or 0 for s in yazilacak),
        atlanan=len(satirlar) - len(yazilacak),
        donem=donem,
        ilk_tarih=ilk,
    )


@router.get("/aidat-planlari", response_model=AidatPlaniListResponse)
async def plan_listesi(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_OKUR),
) -> AidatPlaniListResponse:
    rows = (
        await db.execute(select(AidatPlani).order_by(AidatPlani.ad))
    ).scalars().all()
    return AidatPlaniListResponse(items=list(rows))


@router.post("/aidat-planlari", response_model=AidatPlaniOut, status_code=201)
async def plan_olustur(
    body: AidatPlaniCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> AidatPlani:
    """Otomatik aylik tahakkuk plani.

    Yonetici BIR KEZ tanimlar; sistem her ay tahakkuk eder. Onceden
    `beat_schedule`da aidat gorevi yoktu ve yonetici unutursa o ay borc
    olusmuyordu.
    """
    await _tanim_dogrula(db, body.gelir_gider_tanim_id)
    obj = AidatPlani(tenant_id=user.tenant_id, **body.model_dump())
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "aidat_plani_ad_var")
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_CREATE, resource_type="aidat_plani",
        resource_id=obj.id, meta={"ad": obj.ad, "dagitim": obj.dagitim},
    )
    return obj


@router.patch("/aidat-planlari/{plan_id}", response_model=AidatPlaniOut)
async def plan_guncelle(
    plan_id: uuid.UUID,
    body: AidatPlaniUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> AidatPlani:
    obj = await get_or_404(db, AidatPlani, plan_id)
    veri = body.model_dump(exclude_unset=True)
    for k, v in veri.items():
        setattr(obj, k, v)
    # TUTAR/DAGITIM TUTARLILIGI: kismi guncelleme ikisini AYRI AYRI
    # degistirebilir; kural son duruma gore yeniden dogrulanir (CHECK
    # kisiti da ayni sey, ama 500 yerine 422 dondurmek daha dogru).
    if obj.dagitim == "daire_basina" and obj.tutar_kurus is None:
        raise APIError(422, "validation_error", "plan_tutar_gerekli")
    if obj.dagitim != "daire_basina" and obj.toplam_tutar_kurus is None:
        raise APIError(422, "validation_error", "plan_toplam_tutar_gerekli")
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "aidat_plani_ad_var")
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_UPDATE, resource_type="aidat_plani",
        resource_id=obj.id, meta={"degisen": sorted(veri)},
    )
    return obj


@router.post("/aidat-planlari/{plan_id}/ertele", response_model=AidatPlaniOut)
async def plan_ertele(
    plan_id: uuid.UUID,
    body: AidatPlaniErtele,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> AidatPlani:
    """Bir donemi ATLA (plani KAPATMADAN).

    Plani pasife almak gelecek aylari da kapatirdi; yonetici genelde
    "bu ay olmasin" demek ister.
    """
    obj = await get_or_404(db, AidatPlani, plan_id)
    if obj.son_donem == body.donem:
        # Zaten islenmis bir donem ERTELENEMEZ: borc yazildi, geri almak
        # ters kayitla olur (§6.3). Sessizce "ertelendi" demek, yazilmis
        # borcun kalktigi izlenimi verirdi.
        raise APIError(409, "conflict", "donem_zaten_islendi")
    obj.ertelenen_donem = body.donem
    obj.updated_at = func.now()
    await db.flush()
    await db.refresh(obj)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_UPDATE, resource_type="aidat_plani",
        resource_id=obj.id, meta={"ertelenen_donem": body.donem},
    )
    return obj


@router.delete("/aidat-planlari/{plan_id}", status_code=204, response_model=None)
async def plan_sil(
    plan_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> Response:
    """Plani sil. YAZILMIS TAHAKKUKLAR ETKILENMEZ.

    Plan bir KURALDIR, para degil: silinmesi gecmis borclari geri almaz
    (onun yolu ters kayit). Bu yuzden gercek DELETE — ters kayit gerekmez.
    """
    obj = await get_or_404(db, AidatPlani, plan_id)
    await db.delete(obj)
    await db.flush()
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_DELETE, resource_type="aidat_plani",
        resource_id=plan_id, meta={"ad": obj.ad},
    )
    return Response(status_code=204)


# ============================ HATIRLATMA AYARI ============================== #
async def _ayar(db: AsyncSession, tenant_id: uuid.UUID) -> HatirlatmaAyari:
    """Tesisin ayari — yoksa VARSAYILANLA acilir (get-or-create).

    Ayari "yok" diye dondurmek, istemciyi once POST sonra PATCH yapmaya
    zorlardi; ayar tesise ait TEK bir kayittir ve varsayilani vardir.
    """
    obj = (await db.execute(select(HatirlatmaAyari))).scalar_one_or_none()
    if obj is None:
        obj = HatirlatmaAyari(tenant_id=tenant_id)
        db.add(obj)
        await db.flush()
        await db.refresh(obj)
    return obj


@router.get("/hatirlatma-ayari", response_model=HatirlatmaAyariOut)
async def hatirlatma_ayari(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
) -> HatirlatmaAyari:
    return await _ayar(db, user.tenant_id)


@router.get("/hatirlatma-ayari/onizleme", response_model=KuralOnizleme)
async def hatirlatma_onizleme(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
) -> KuralOnizleme:
    """(P250 §9) "Bu kural bugun calissaydi N kisiye hatirlatma giderdi".

    Kayitli ayarla, gonderimin kullandigi AYNI hedef hesabi
    (`hatirlatma_hedefleri`). Kural KAPALIYKEN de hesaplanir: yonetici
    acmadan once ne olacagini gorebilmeli. Hicbir sey gonderilmez.
    """
    from datetime import date as _date

    from .. import otomasyon as oto

    ayar = await _ayar(db, user.tenant_id)
    _, kisi, _, alicisiz = await oto.hatirlatma_hedefleri(
        db, vade_oncesi_gun=ayar.vade_oncesi_gun, kademeler=ayar.kademeler or [],
        bugun=_date.today(),
    )
    return KuralOnizleme(
        adet=len(kisi),
        toplam_kurus=sum(k for k, _ in kisi.values()),
        atlanan=alicisiz,
    )


@router.patch("/hatirlatma-ayari", response_model=HatirlatmaAyariOut)
async def hatirlatma_ayari_guncelle(
    body: HatirlatmaAyariUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> HatirlatmaAyari:
    """Borc hatirlatmasi: acik/kapali, vade oncesi gun, kademeler, metin."""
    obj = await _ayar(db, user.tenant_id)
    veri = body.model_dump(exclude_unset=True)
    # (P250 §7) Duz ayar (ilk/tekrar/aralik) semada `kademeler`e cevrildi;
    # kendileri sutun degil.
    for k in ("ilk_gun", "tekrar_sayisi", "aralik_gun"):
        if veri.pop(k, None) is not None:
            veri["kademeler"] = body.kademeler
    for k, v in veri.items():
        setattr(obj, k, v)
    obj.updated_at = func.now()
    # (P199) KURULUM SIHIRBAZI: otomasyon tercihi KAYDEDILDI.
    #
    # `_ayar` get-or-create oldugu icin SATIRIN VARLIGI karar sayilamaz
    # (GET de yaratir). Karar yalniz burada, KAYDETME aninda olusur.
    tenant = await db.get(Tenant, user.tenant_id)
    if tenant is not None:
        tenant.kurulum_otomasyon_karari = True
    await db.flush()
    await db.refresh(obj)
    await audit_user(
        db, user, Action.MUHASEBE_AYAR_UPDATE, resource_type="hatirlatma_ayari",
        resource_id=obj.tenant_id, meta={"degisen": sorted(veri)},
    )
    return obj


# ============================= DUZENLI GIDER ================================ #
async def _kasa_dogrula(db: AsyncSession, kasa_id: uuid.UUID | None) -> None:
    if kasa_id is None:
        return
    var = (await db.execute(select(Kasa.id).where(Kasa.id == kasa_id))).scalar_one_or_none()
    if var is None:
        raise APIError(422, "invalid_reference", "kasa_bulunamadi")


@router.get("/duzenli-giderler", response_model=DuzenliGiderListResponse)
async def gider_listesi(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_OKUR),
) -> DuzenliGiderListResponse:
    rows = (
        await db.execute(
            select(DuzenliGider).order_by(DuzenliGider.sonraki_tarih, DuzenliGider.ad)
        )
    ).scalars().all()
    return DuzenliGiderListResponse(items=list(rows))


@router.post("/duzenli-giderler", response_model=DuzenliGiderOut, status_code=201)
async def gider_olustur(
    body: DuzenliGiderCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> DuzenliGider:
    """Tekrar eden gider (kapici maasi, asansor bakimi, sigorta).

    `otomatik_onay=false` (varsayilan) ise vadesi gelen gider ONAY
    BEKLEYEN yazilir ve yoneticiye bildirim gider.
    """
    await _kasa_dogrula(db, body.kasa_id)
    obj = DuzenliGider(tenant_id=user.tenant_id, **body.model_dump())
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "duzenli_gider_ad_var")
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_CREATE, resource_type="duzenli_gider",
        resource_id=obj.id,
        meta={"ad": obj.ad, "tutar_kurus": obj.tutar_kurus, "periyot": obj.periyot},
    )
    return obj


@router.patch("/duzenli-giderler/{gider_id}", response_model=DuzenliGiderOut)
async def gider_guncelle(
    gider_id: uuid.UUID,
    body: DuzenliGiderUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> DuzenliGider:
    obj = await get_or_404(db, DuzenliGider, gider_id)
    veri = body.model_dump(exclude_unset=True)
    if "kasa_id" in veri:
        await _kasa_dogrula(db, veri["kasa_id"])
    for k, v in veri.items():
        setattr(obj, k, v)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "duzenli_gider_ad_var")
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_UPDATE, resource_type="duzenli_gider",
        resource_id=obj.id, meta={"degisen": sorted(veri)},
    )
    return obj


@router.delete("/duzenli-giderler/{gider_id}", status_code=204, response_model=None)
async def gider_sil(
    gider_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> Response:
    """Tekrar KURALINI sil — YAZILMIS gider hareketleri etkilenmez.

    Defterdeki satirlar silinemez (0047); burada silinen sey bir takvim
    kaydidir, para degil.
    """
    obj = await get_or_404(db, DuzenliGider, gider_id)
    await db.delete(obj)
    await db.flush()
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_DELETE, resource_type="duzenli_gider",
        resource_id=gider_id, meta={"ad": obj.ad},
    )
    return Response(status_code=204)


# ============================ KURAL SON CALISMA ============================= #
#: Tekil kurallarin (tesis basina bir tane) gunluk turleri.
_TEKIL_KURALLAR = ("borc_hatirlatma", "gecikme_faizi", "maas")


# ============================ (P252) MAAS ==================================== #
async def _maas_ayari(db: AsyncSession, tenant_id: uuid.UUID) -> MaasAyariOut:
    from ..models import PersonelKayit, Tenant

    tesis = (await db.execute(select(Tenant).where(Tenant.id == tenant_id))).scalar_one()
    satirlar = (
        await db.execute(
            select(PersonelKayit.odeme_gunu, func.count(), func.sum(PersonelKayit.maas_kurus))
            .where(
                PersonelKayit.aktif.is_(True),
                PersonelKayit.maas_kurus > 0,
                PersonelKayit.odeme_gunu.is_not(None),
            )
            .group_by(PersonelKayit.odeme_gunu)
            .order_by(PersonelKayit.odeme_gunu)
        )
    ).all()
    gruplar = [
        MaasKuralGrubu(odeme_gunu=g, personel_sayisi=n, aylik_toplam_kurus=int(t or 0))
        for g, n, t in satirlar
    ]
    return MaasAyariOut(
        aktif=tesis.maas_otomasyonu_aktif,
        otomatik_onay=tesis.maas_otomatik_onay,
        gruplar=gruplar,
        personel_sayisi=sum(g.personel_sayisi for g in gruplar),
        aylik_toplam_kurus=sum(g.aylik_toplam_kurus for g in gruplar),
    )


@router.get("/otomasyon/maas-ayari", response_model=MaasAyariOut)
async def maas_ayari(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> MaasAyariOut:
    """(P252 §2) Maas otomasyonu: acik mi, otomatik onay, odeme gunu gruplari.

    YALNIZ YONETIM (denetci dahil degil): grup toplamlari ucret bilgisidir.
    """
    return await _maas_ayari(db, user.tenant_id)


@router.patch("/otomasyon/maas-ayari", response_model=MaasAyariOut)
async def maas_ayari_guncelle(
    body: MaasAyariGuncelle,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> MaasAyariOut:
    from ..models import Tenant

    tesis = (await db.execute(select(Tenant).where(Tenant.id == user.tenant_id))).scalar_one()
    veri = body.model_dump(exclude_unset=True)
    if "aktif" in veri and veri["aktif"] is not None:
        tesis.maas_otomasyonu_aktif = veri["aktif"]
    if "otomatik_onay" in veri and veri["otomatik_onay"] is not None:
        tesis.maas_otomatik_onay = veri["otomatik_onay"]
    await db.flush()
    await audit_user(
        db, user, Action.MUHASEBE_AYAR_UPDATE, resource_type="maas_otomasyonu",
        resource_id=user.tenant_id, meta={"alanlar": sorted(veri)},
    )
    return await _maas_ayari(db, user.tenant_id)


@router.post("/otomasyon/maaslar/calistir", response_model=MaasCalistirmaSonucu)
async def maaslari_simdi_calistir(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> MaasCalistirmaSonucu:
    """(P252 §2) "Simdi calistir" — gunluk gorevle AYNI islev, ayni kurallar.

    Iki kez basilsa da ikinci kosum yazmaz (defter anahtari + damga);
    sonucun `yazilan: 0` donmesi tam da bunun kaniti.
    """
    from datetime import date

    from ..otomasyon import maas_otomasyonu

    sonuc = await maas_otomasyonu(db, user.tenant_id, date.today())
    return MaasCalistirmaSonucu(
        yazilan=sonuc["yazilan"],
        toplam_kurus=sonuc["toplam_kurus"],
        onay_bekleyen=sonuc.get("onay_bekleyen", 0),
        donemler=sonuc.get("donemler") or {},
    )


@router.get("/otomasyon/son-calismalar", response_model=KuralSonCalismaListesi)
async def son_calismalar(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_OKUR),
) -> KuralSonCalismaListesi:
    """(P250 §9) Her kuralin EN SON calismasi ve sonucu — kural basina.

    Gunluk satiri kurali `sonuc` icinde tasir: aidat plani `plan`,
    duzenli gider `giderler` (P250 oncesi satirlarda yok; o giderin son
    calismasi bilinmiyor diye GOSTERILMEZ, uydurulmaz). Son 400 gun.
    """
    from datetime import datetime, timedelta, timezone

    esik = datetime.now(timezone.utc) - timedelta(days=400)
    rows = (
        await db.execute(
            select(OtomasyonGunlugu)
            .where(
                OtomasyonGunlugu.calisma_zamani >= esik,
                OtomasyonGunlugu.tur.in_(
                    ("aidat_tahakkuk", "duzenli_gider", *_TEKIL_KURALLAR)
                ),
            )
            .order_by(OtomasyonGunlugu.calisma_zamani.desc(), OtomasyonGunlugu.id.desc())
            .limit(2000)
        )
    ).scalars().all()
    gorulen: dict[str, KuralSonCalisma] = {}
    for r in rows:
        sonuc = r.sonuc or {}
        if r.tur == "aidat_tahakkuk":
            anahtarlar = [sonuc["plan"]] if sonuc.get("plan") else []
        elif r.tur == "duzenli_gider":
            anahtarlar = list(sonuc.get("giderler") or [])
        else:
            anahtarlar = [r.tur]
        for a in anahtarlar:
            if a in gorulen:
                continue
            gorulen[a] = KuralSonCalisma(
                kural=a, tur=r.tur, zaman=r.calisma_zamani,
                adet=r.adet if r.tur != "duzenli_gider" else 1,
                tutar_kurus=r.tutar_kurus if r.tur != "duzenli_gider" else 0,
                durum=sonuc.get("durum"),
            )
    return KuralSonCalismaListesi(items=list(gorulen.values()))


# =========================== OTOMASYON GUNLUGU ============================== #
@router.get("/otomasyon-gunlugu", response_model=OtomasyonGunlukListResponse)
async def gunluk(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    tur: str | None = Query(None, max_length=_G.KOD),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_OKUR),
) -> OtomasyonGunlukListResponse:
    """Otomasyon NE ZAMAN NE YAPTI.

    Bu liste olmadan "gorev calisti ama hicbir sey uretmedi" durumu — ki
    asil merak edilen odur — gorunmez kalirdi.
    """
    where = [] if tur is None else [OtomasyonGunlugu.tur == tur]
    total = (
        await db.execute(
            select(func.count()).select_from(OtomasyonGunlugu).where(*where)
        )
    ).scalar_one()
    rows = (
        await db.execute(
            select(OtomasyonGunlugu).where(*where)
            .order_by(
                OtomasyonGunlugu.calisma_zamani.desc(), OtomasyonGunlugu.id.desc()
            )
            .limit(limit).offset(offset)
        )
    ).scalars().all()
    return OtomasyonGunlukListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[OtomasyonGunlukOut.model_validate(r) for r in rows],
    )
