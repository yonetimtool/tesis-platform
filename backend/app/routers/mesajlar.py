"""Mesaj sablonlari + gonderim (P32) — `/mesaj-sablonlari`, `/mesajlar/...`.

RIZA DENETIMI: `amac='pazarlama'` sablonlar YALNIZCA rizasi olan kisilere
gonderilir. Riza kaydi P36'nin isidir; o gelene kadar bu uc PAZARLAMA
gonderimini HIC yapmaz ve atlananlari SAYAR. "Simdilik gonderelim, rizayi
sonra ekleriz" demek, KVKK ihlalini urune yerlestirmek olurdu.

OPERASYONEL finansal bildirim AYRI bir hukuki dayanaktir (KMK yukumluluk)
ve riza gerektirmez — bu ayrim sablonun `amac` alaninda tasinir.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..config import settings
from ..crud_helpers import get_or_404, translate_integrity
from .. import defter
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..gonderim import (
    SaglayiciAyari,
    kota_kontrol,
    saglayici as kanal_saglayicisi,
    tenant_ayari,
)
from ..mesajlasma import (
    sms_saglayicisi,
    KapaliSmsSaglayici,
    LogEpostaSaglayici,
    LogSmsSaglayici,
    SmtpEpostaSaglayici,
    bilinmeyen_etiketler,
    etiketleri_coz,
    kullanilan_etiketler,
    sms_olc,
)
from ..models import (
    AppUser,
    DuesAssessment,
    MesajGonderim,
    MesajSablonu,
    MesajYapilandirma,
    Tenant,
    Unit,
    UnitResident,
)
from ..schemas import (
    MesajGonderIstek,
    MesajGonderSonuc,
    MesajGonderimListResponse,
    MesajGonderimOut,
    MesajOnizlemeIstek,
    MesajOnizlemeOut,
    MesajSablonuCreate,
    MesajSablonuListResponse,
    MesajSablonuOut,
    MesajSablonuUpdate,
    MesajTestGonderim,
    MesajTestSonuc,
    MesajYapilandirmaOut,
    MesajYapilandirmaUpdate,
    SmsOlcumOut,
)

router = APIRouter(tags=["mesajlar"])

_YONETIM = require_role("admin", "yonetici")

#: Toplu gonderimde tek istekte en fazla alici. Sinirsiz birakmak, tek
#: istegin dakikalarca surmesine ve zaman asimiyla YARIM gonderilmis bir
#: kampanyaya yol acardi.
_TOPLU_UST_SINIR = 500


# (P154 / Asama 9) Kanal secimi BU DOSYADAN CIKTI: `gonderim.saglayici()`
# artik dort kanalin da TEK giris noktasi. Burada satir ici kalmasi,
# e-posta gondermek isteyen ikinci bir yolun (orn. gecici kod e-postasi)
# SMTP yapilandirmasini KOPYALAMASI demekti.


def _cikti(obj: MesajSablonu) -> MesajSablonuOut:
    return MesajSablonuOut.model_validate(obj).model_copy(update={
        "etiketler": kullanilan_etiketler(f"{obj.konu or ''} {obj.govde}"),
        "bilinmeyen_etiketler": bilinmeyen_etiketler(
            f"{obj.konu or ''} {obj.govde}"
        ),
    })


# ============================== SABLON CRUD ================================= #
@router.get("/mesaj-sablonlari", response_model=MesajSablonuListResponse)
async def sablon_listesi(
    kanal: str | None = Query(None),
    aktif: bool | None = Query(None),
    limit: int = Query(100, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> MesajSablonuListResponse:
    q = select(MesajSablonu)
    if kanal is not None:
        q = q.where(MesajSablonu.kanal == kanal)
    if aktif is not None:
        q = q.where(MesajSablonu.aktif == aktif)
    total = (
        await db.execute(select(func.count()).select_from(q.subquery()))
    ).scalar_one()
    kayitlar = (
        (await db.execute(
            q.order_by(MesajSablonu.kanal, MesajSablonu.ad, MesajSablonu.id)
            .limit(limit).offset(offset)
        )).scalars().all()
    )
    return MesajSablonuListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_cikti(k) for k in kayitlar],
    )


@router.post("/mesaj-sablonlari", response_model=MesajSablonuOut, status_code=201)
async def sablon_olustur(
    body: MesajSablonuCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> MesajSablonuOut:
    obj = MesajSablonu(tenant_id=user.tenant_id, **body.model_dump())
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.MESAJ_SABLON_UPSERT, resource_type="mesaj_sablonu",
        resource_id=obj.id, meta={"kanal": obj.kanal, "ad": obj.ad},
    )
    return _cikti(obj)


@router.patch("/mesaj-sablonlari/{sablon_id}", response_model=MesajSablonuOut)
async def sablon_guncelle(
    sablon_id: uuid.UUID,
    body: MesajSablonuUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> MesajSablonuOut:
    obj = await get_or_404(db, MesajSablonu, sablon_id)
    veri = body.model_dump(exclude_unset=True)
    for alan, deger in veri.items():
        setattr(obj, alan, deger)
    obj.updated_at = func.now()
    # BIRLESIK kural: kanal degismez ama konu SMS'e eklenmeye calisilabilir.
    if obj.kanal == "sms" and obj.konu:
        raise APIError(422, "validation_error", "sms_sablonunda_konu_olmaz")
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.MESAJ_SABLON_UPSERT, resource_type="mesaj_sablonu",
        resource_id=obj.id, meta={"alanlar": sorted(veri)},
    )
    return _cikti(obj)


@router.delete("/mesaj-sablonlari/{sablon_id}", status_code=204, response_model=None)
async def sablon_sil(
    sablon_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> None:
    """Sablonu siler; GECMIS DURUR (gonderim kaydi metni kopyaladi)."""
    obj = await get_or_404(db, MesajSablonu, sablon_id)
    await audit_user(
        db, user, Action.MESAJ_SABLON_SIL, resource_type="mesaj_sablonu",
        resource_id=obj.id, meta={"ad": obj.ad},
    )
    await db.delete(obj)
    await db.flush()


# =============================== ONIZLEME =================================== #
async def _degerler(
    db: AsyncSession, tenant: Tenant, user_id: uuid.UUID | None
) -> dict[str, str]:
    """Etiket degerleri. Kisi verilmezse ORNEK degerler doner (onizleme)."""
    from datetime import datetime, timezone

    bugun = datetime.now(timezone.utc).date().strftime("%d.%m.%Y")
    if user_id is None:
        return {
            "adi_soyadi": "Ad Soyad", "adres": "A-12", "site_adi": tenant.ad,
            "tarih": bugun, "bakiye": "1.250,50", "borc": "500,00",
            "aidat_tutari": "750,00", "kiraci_bakiyesi": "0,00",
            "bakiye_detayli": "Aidat: 750,00 · Elektrik: 500,50",
            "borcu_detayli": "Temmuz 2026 aidat: 750,00",
            "odeme_linki": "https://ornek/ode",
        }

    kisi = (
        await db.execute(select(AppUser).where(AppUser.id == user_id))
    ).scalar_one_or_none()
    daire = (
        await db.execute(
            select(Unit.no).join(
                UnitResident,
                (UnitResident.unit_id == Unit.id)
                & (UnitResident.user_id == user_id)
                & (UnitResident.bitis.is_(None)),
            ).limit(1)
        )
    ).scalar_one_or_none()
    # (P192 §6.3) Ters kayit cifti borc DEGILDIR.
    borc = int((
        await db.execute(
            select(func.coalesce(func.sum(DuesAssessment.tutar_kurus), 0))
            .where(DuesAssessment.hedef_user_id == user_id,
                   *defter.gecerli_tahakkuk())
        )
    ).scalar_one())
    # (P192 §1) TEK TANIM: iade/iptal dusulur, yalniz gerceklesmis satirlar.
    odenen = await defter.tahsilat_toplami(db, user_id=user_id)
    from ..raporlar import kurus_metin

    bakiye = max(borc - odenen, 0)
    return {
        "adi_soyadi": kisi.ad if kisi else "",
        "adres": daire or "",
        "site_adi": tenant.ad,
        "tarih": bugun,
        "bakiye": kurus_metin(bakiye),
        "borc": kurus_metin(borc),
        "aidat_tutari": kurus_metin(borc),
        "kiraci_bakiyesi": kurus_metin(bakiye),
        "bakiye_detayli": f"Toplam borç: {kurus_metin(borc)} · "
                          f"Tahsil edilen: {kurus_metin(odenen)}",
        "borcu_detayli": f"Kalan bakiye: {kurus_metin(bakiye)}",
        # Odeme linki sakinin uygulamadaki "Öde" ekranina isaret eder;
        # tenant basina ayri bir alan ACILMADI (bkz. P30 IBAN kararı).
        # (P120) BIZE AIT OLMAYAN bir alan adi kullaniliyordu — bkz.
        # `Settings.portal_base_url` gerekcesi.
        "odeme_linki": f"{settings.portal_base_url}/ode",
    }


@router.post("/mesajlar/onizleme", response_model=MesajOnizlemeOut)
async def onizleme(
    body: MesajOnizlemeIstek,
    kanal: str = Query("sms", description="sms | eposta"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> MesajOnizlemeOut:
    """Etiketleri COZULMUS onizleme + SMS sayaci.

    Sayac ONIZLEMEDE verilir, kaydetmede degil: kullanici yazarken parca
    sayisinin arttigini GORMELI — kaydettikten sonra ogrenmek gec.
    """
    tenant = (
        await db.execute(select(Tenant).where(Tenant.id == user.tenant_id))
    ).scalar_one()
    degerler = await _degerler(db, tenant, body.user_id)
    govde = etiketleri_coz(body.govde, degerler)
    konu = etiketleri_coz(body.konu, degerler) if body.konu else None
    ham = f"{body.konu or ''} {body.govde}"
    olcum = None
    if kanal == "sms":
        o = sms_olc(govde)
        olcum = SmsOlcumOut(
            karakter=o.karakter, unicode_mi=o.unicode_mi, parca=o.parca,
            kalan=o.kalan, zorlayan=o.zorlayan,
        )
    return MesajOnizlemeOut(
        konu=konu, govde=govde,
        etiketler=kullanilan_etiketler(ham),
        bilinmeyen_etiketler=bilinmeyen_etiketler(ham),
        sms=olcum,
    )


# =============================== GONDERIM =================================== #
async def _alicilar(
    db: AsyncSession, body: MesajGonderIstek
) -> list[uuid.UUID]:
    if body.user_ids:
        return list(dict.fromkeys(body.user_ids))[:_TOPLU_UST_SINIR]

    # (P154 / Asama 9) ROL BAZLI segment AYRI SORGUDUR ve erken doner.
    # Sebep: asagidaki suzgecler SAKIN listesinden turuyor
    # (`unit_resident` join'i), oysa `security` / `tesis_gorevlisi` gibi
    # roller daireye bagli DEGILDIR ve o listede HIC gorunmezler.
    # Rol segmentini oraya iliştirmek, "guvenlige duyuru gonder"
    # dendiginde SESSIZCE bos liste uretirdi.
    if body.rol:
        idler = list(
            (
                await db.execute(
                    select(AppUser.id).where(
                        AppUser.role == body.rol,
                        AppUser.is_active.is_(True),
                    )
                )
            ).scalars().all()
        )
        return idler[:_TOPLU_UST_SINIR]

    q = (
        select(UnitResident.user_id)
        .join(Unit, Unit.id == UnitResident.unit_id)
        .where(UnitResident.bitis.is_(None))
    )
    if body.blok:
        q = q.where(Unit.blok == body.blok)
    idler = list(dict.fromkeys((await db.execute(q)).scalars().all()))

    if body.borc_durumu == "borclu":
        borclu = set(
            (await db.execute(
                select(DuesAssessment.hedef_user_id)
                .where(DuesAssessment.hedef_user_id.is_not(None),
                       *defter.gecerli_tahakkuk())
                .group_by(DuesAssessment.hedef_user_id)
                .having(func.sum(DuesAssessment.tutar_kurus) > 0)
            )).scalars().all()
        )
        idler = [i for i in idler if i in borclu]
    return idler[:_TOPLU_UST_SINIR]


@router.post("/mesajlar/gonder", response_model=MesajGonderSonuc, status_code=201)
async def gonder(
    body: MesajGonderIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> MesajGonderSonuc:
    """Bireysel + toplu gonderim TEK UCTAN.

    Iki ayri uc, ayni riza/gecmis mantigini iki kez yazmak olurdu.

    SESSIZ DUSURME YOK: rizasi olmayan ve adresi olmayan aliciler AYRI
    SAYILIR ve yanitta doner — "gonderdim" deyip 40 kisiyi atlamak,
    yonetimin haberi olmadan bildirimsiz kalmasi demekti.
    """
    sablon = await get_or_404(db, MesajSablonu, body.sablon_id)
    if not sablon.aktif:
        raise APIError(422, "validation_error", "sablon_pasif")

    tenant = (
        await db.execute(select(Tenant).where(Tenant.id == user.tenant_id))
    ).scalar_one()
    idler = await _alicilar(db, body)
    kisiler = {
        k.id: k for k in (
            await db.execute(select(AppUser).where(AppUser.id.in_(idler)))
        ).scalars().all()
    } if idler else {}

    # (P154 / Asama 9) GUNLUK KOTA — gonderim BASLAMADAN kontrol edilir.
    # YARIM GONDERIM YERINE HIC: 300 kisilik bir listede 50. alicida
    # kotaya takilmak, kime gidip kime gitmedigini kullaniciya aciklamasi
    # zor bir durum birakirdi.
    await kota_kontrol(db, user.tenant_id, len(idler))

    # (P168 §4) GONDERIM YOLU DA TESIS AYARINI KULLANIR. ENV'e sabitli
    # kalsaydi, "Ayarlar" sekmesine girilen saglayici hicbir sey
    # degistirmez ve kullanici kaydettigi ayarin ise yaramadigini ancak
    # mesaj gitmeyince anlardi.
    ayar = await tenant_ayari(db, user.tenant_id)
    saglayici = kanal_saglayicisi(sablon.kanal, ayar)
    gonderildi = basarisiz = riza_yok = adres_yok = 0

    for kid in idler:
        kisi = kisiler.get(kid)
        if kisi is None:
            continue
        # (P177 §4) TICARI ILETI KANALI KAPALIYSA RIZA BILE YETMEZ.
        #
        # `TICARI_ILETI_AKTIF=false` (varsayilan) iken pazarlama amacli
        # hicbir gonderim yapilmaz — kisinin rizasi OLSA BILE. Sebep
        # teknik degil hukuki: sirket ve IYS (Ileti Yonetim Sistemi)
        # kaydi yok ve IYS'ye islenmemis bir rizayla ticari ileti
        # gondermek idari para cezasi sebebidir.
        #
        # `riza_yok` SAYACINA YAZILIYOR ve bu bilincli: yoneticiye
        # gorunen ozet "gonderilmedi" demeli. Ayri bir sayac eklemek
        # ozeti ve arayuzu degistirmek olurdu; onemli olan mesajin
        # GITMEDIGINI dogru raporlamak.
        if sablon.amac == "pazarlama" and not settings.ticari_ileti_aktif:
            riza_yok += 1
            continue
        # PAZARLAMA -> RIZA ZORUNLU (P36 ile GERCEK riza kaydi baglandi).
        # Riza KANAL BAZLIDIR: e-postaya izin veren kisi SMS'e izin vermis
        # sayilmaz — tek bir "pazarlama" bayragi bunu kaybederdi.
        if sablon.amac == "pazarlama":
            izinli = (
                kisi.pazarlama_sms if sablon.kanal == "sms"
                else kisi.pazarlama_eposta
            )
            if not izinli:
                riza_yok += 1
                continue
        hedef = (
            kisi.telefon if sablon.kanal == "sms" else kisi.email
        )
        if not hedef:
            adres_yok += 1
            continue

        degerler = await _degerler(db, tenant, kid)
        govde = etiketleri_coz(sablon.govde, degerler)
        konu = etiketleri_coz(sablon.konu, degerler) if sablon.konu else None
        sonuc = saglayici.gonder(hedef, konu, govde)
        # (P154 / Asama 9) BASARISIZ ARTIK SON SOZ DEGIL: satir KUYRUGA
        # alinir ve `mesaj_kuyruk` katlanan geri cekilmeyle yeniden dener.
        # Eskiden saglayicinin bes saniyelik bir kesintisi, uc yuz kisilik
        # bir duyurunun KALICI olarak eksik gitmesi demekti.
        #
        # Ilk deneme BURADA yapildi; sayac 1'den baslar ki kuyruk ikinci
        # denemeyi bir dakika sonraya koysun (sifirdan baslasaydi HEMEN
        # tekrar denerdi — yani geri cekilme hic olmazdi).
        kuyrukta = sonuc.durum == "basarisiz"
        db.add(MesajGonderim(
            tenant_id=user.tenant_id, sablon_id=sablon.id, kanal=sablon.kanal,
            amac=sablon.amac, user_id=kid, hedef=hedef, konu=konu,
            govde=govde,
            durum="kuyrukta" if kuyrukta else sonuc.durum,
            hata=sonuc.hata,
            saglayici=sonuc.saglayici, gonderen_user_id=user.id,
            deneme=1, son_deneme_at=func.now(),
        ))
        if kuyrukta:
            basarisiz += 1
        else:
            gonderildi += 1

    await db.flush()
    await audit_user(
        db, user, Action.MESAJ_GONDER, resource_type="mesaj_gonderim",
        resource_id=sablon.id,
        meta={"kanal": sablon.kanal, "amac": sablon.amac,
              "gonderildi": gonderildi, "riza_yok": riza_yok,
              "adres_yok": adres_yok, "basarisiz": basarisiz},
    )
    return MesajGonderSonuc(
        gonderildi=gonderildi, basarisiz=basarisiz,
        riza_yok=riza_yok, adres_yok=adres_yok,
    )


# ============================ (P168 §4.4) AYARLAR =========================== #
async def _bugun_gonderilen(db: AsyncSession) -> int:
    """Bugun GERCEKTEN gonderilmis mesaj sayisi.

    `yapilandirilmadi` SAYILMAZ: hicbir sey gonderilmediyse kotadan da
    dusmemeli — yoksa ayarlari doldurmamis bir tesis, hic mesaj
    gondermeden kotasini tuketirdi.
    """
    return (
        await db.execute(
            select(func.count()).select_from(MesajGonderim).where(
                MesajGonderim.durum.in_(["gonderildi", "iletildi", "okundu"]),
                MesajGonderim.created_at >= func.current_date(),
            )
        )
    ).scalar_one()


def ayar_kaynagi(tesiste: bool, hazir: bool) -> str:
    """(P173 §4) Kanal HANGI ayardan calisiyor: `tesis` | `genel` | `yok`.

    MODUL DUZEYINDE ve SAF: kural bir kapanisin icinde saklandiginda
    yalnizca HTTP uzerinden olculebiliyordu — ve testler CANLI SUNUCUYA
    gittigi icin ENV dali test surecinden `monkeypatch` ile surulemiyordu
    (olculdu). Saf bir islev, uc dali da dogrudan olcturur.

    Olcut `_ayardan_veya_env` ile AYNI: tesisin o kanal icin kendi degeri
    varsa "tesis". Farkli bir olcut yazmak, rozetle gercek saglayici
    seciminin bir gun ayrismasi demekti.
    """
    if not hazir:
        return "yok"
    return "tesis" if tesiste else "genel"


@router.get("/mesaj-ayarlari", response_model=MesajYapilandirmaOut)
async def mesaj_ayarlari(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> MesajYapilandirmaOut:
    """Tesisin mesaj ayarlari — SIRLAR DONMEZ, yalnizca VARLIKLARI."""
    y = await db.get(MesajYapilandirma, user.tenant_id)
    ayar = await tenant_ayari(db, user.tenant_id)
    # HAZIRLIK KANAL BAZINDA OLCULUR ve gercek secim fonksiyonuyla ayni
    # yoldan gecer: "ayarlar dolu mu" diye ayrica kontrol etseydik, o
    # kontrol bir gun gercek secimden ayrisirdi.
    # (P177 §6) KANAL KAPALIYSA "HAZIR" DEGILDIR.
    #
    # OLCULEN KUSUR: ana salter (`SMS_AKTIF=false`) eklendiginde
    # `sms_saglayicisi()` `KapaliSmsSaglayici` donmeye basladi — ve o,
    # `LogSmsSaglayici` OLMADIGI icin bu satir "hazir" diyordu. Panel
    # yarim yapilandirilmis bir tesise "SMS hazır" gosteriyor, rozet de
    # "genel ayardan çalışıyor" diyordu; ikisi de yanlisti.
    #
    # P168'de kapatilan kusur sinifinin ta kendisi: gonderilmeyecek bir
    # mesaji gonderilecekmis gibi gostermek. Iki sinif da "gonderemem"
    # der; rozet ikisini de HAZIR DEGIL saymali.
    sms_hazir = not isinstance(
        kanal_saglayicisi("sms", ayar), (LogSmsSaglayici, KapaliSmsSaglayici)
    )
    eposta_hazir = not isinstance(kanal_saglayicisi("eposta", ayar), LogEpostaSaglayici)

    # (P173 §4) KAYNAK DA BILDIRILIR — "hazir" tek basina YANILTICIYDI.
    #
    # Alanlar BOS gorunurken rozet "hazir" diyor ve kullanici "ben bir
    # sey girmedim, nasil hazir?" diye soruyordu. Sebep dogru ama
    # gorunmuyordu: kanal ENV'deki GENEL ayardan calisiyor.
    #
    # Karar KANAL BASINA ve `_ayardan_veya_env` ile AYNI olcutle:
    # tesisin o kanal icin kendi degeri VARSA "tesis", yoksa calisan bir
    # sey varsa "genel". Farkli bir olcut yazmak, rozetle gercek secimin
    # bir gun ayrismasi demekti.
    return MesajYapilandirmaOut(
        sms_saglayici=y.sms_saglayici if y else None,
        sms_kullanici=y.sms_kullanici if y else None,
        sms_baslik=y.sms_baslik if y else None,
        sms_parola_var=bool(y and y.sms_parola),
        smtp_host=y.smtp_host if y else None,
        smtp_port=y.smtp_port if y else 587,
        smtp_kullanici=y.smtp_kullanici if y else None,
        smtp_parola_var=bool(y and y.smtp_parola),
        smtp_gonderen=y.smtp_gonderen if y else None,
        gunluk_kota=y.gunluk_kota if y else None,
        bugun_gonderilen=await _bugun_gonderilen(db),
        sms_hazir=sms_hazir,
        eposta_hazir=eposta_hazir,
        sms_kaynak=ayar_kaynagi(bool(y and y.sms_saglayici), sms_hazir),
        eposta_kaynak=ayar_kaynagi(bool(y and y.smtp_host), eposta_hazir),
    )


@router.put("/mesaj-ayarlari", response_model=MesajYapilandirmaOut)
async def mesaj_ayarlari_kaydet(
    body: MesajYapilandirmaUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> MesajYapilandirmaOut:
    """Ayarlari kaydet.

    BOS BIRAKILAN PAROLA MEVCUDU KORUR: arayuz parolayi hic gormedigi
    icin (bkz. `MesajYapilandirmaOut`), formu her kaydedisde parolayi
    yeniden yazmak zorunda kalmak kullaniciyi parolayi bir yere
    kopyalayip yapistirmaya iterdi. Acikca BOS DIZGE gonderilirse
    TEMIZLENIR — silmenin de bir yolu olmali.
    """
    y = await db.get(MesajYapilandirma, user.tenant_id)
    if y is None:
        y = MesajYapilandirma(tenant_id=user.tenant_id)
        db.add(y)
    veri = body.model_dump(exclude_unset=True)
    for alan, deger in veri.items():
        if alan in ("sms_parola", "smtp_parola") and deger is None:
            continue  # "degistirme"
        setattr(y, alan, deger)
    await db.flush()
    await audit_user(
        db, user, Action.MESAJ_SABLON_UPSERT, resource_type="mesaj_yapilandirma",
        resource_id=user.tenant_id,
        # SIR DENETIME DE YAZILMAZ — yalnizca HANGI alanlarin degistigi.
        meta={"alanlar": sorted(veri)},
    )
    return await mesaj_ayarlari(db=db, user=user)


@router.post("/mesaj-ayarlari/test", response_model=MesajTestSonuc)
async def mesaj_ayar_testi(
    body: MesajTestGonderim,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> MesajTestSonuc:
    """(P168 §4.4) TEST GONDERIMI.

    NEDEN GERCEKTEN GONDERIR: "ayarlar dolu mu" diye bakmak, yanlis
    parolayi ya da yanlis basligi YAKALAMAZ — saglayici reddedene kadar
    her sey dogru gorunur. Tek durust olcum gercek bir istektir.

    GECMISE YAZILMAZ: test bir bildirim degildir; gonderim gecmisine
    dusmesi, "kime ne gonderdik" defterini kirletirdi.
    """
    ayar = await tenant_ayari(db, user.tenant_id)
    sonuc = kanal_saglayicisi(body.kanal, ayar).gonder(
        body.hedef, "Test", "Yonetio test mesaji."
    )
    return MesajTestSonuc(
        durum=sonuc.durum, saglayici=sonuc.saglayici, hata=sonuc.hata
    )


@router.get("/mesajlar/gecmis", response_model=MesajGonderimListResponse)
async def gecmis(
    kanal: str | None = Query(None),
    user_id: uuid.UUID | None = Query(None),
    durum: str | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> MesajGonderimListResponse:
    q = select(MesajGonderim)
    if kanal is not None:
        q = q.where(MesajGonderim.kanal == kanal)
    if user_id is not None:
        q = q.where(MesajGonderim.user_id == user_id)
    if durum is not None:
        q = q.where(MesajGonderim.durum == durum)
    total = (
        await db.execute(select(func.count()).select_from(q.subquery()))
    ).scalar_one()
    kayitlar = (
        (await db.execute(
            q.order_by(MesajGonderim.created_at.desc(), MesajGonderim.id.desc()).limit(limit).offset(offset)
        )).scalars().all()
    )
    idler = {k.user_id for k in kayitlar if k.user_id}
    adlar = dict(
        (await db.execute(
            select(AppUser.id, AppUser.ad).where(AppUser.id.in_(idler))
        )).all()
    ) if idler else {}
    return MesajGonderimListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[
            MesajGonderimOut.model_validate(k).model_copy(
                update={"user_ad": adlar.get(k.user_id)}
            )
            for k in kayitlar
        ],
    )
