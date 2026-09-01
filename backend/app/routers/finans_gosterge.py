"""(P192 §5) YONETICININ GORMESI GEREKENLER — yaslandirma, gosterge, toplu islem.

Uc soru, uc uc:
  * "Kim ne kadar suredir borclu?"     -> `GET /finans/yaslandirma`
  * "Bu ay ne kadarini tahsil ettik?"  -> `GET /finans/tahsilat-gostergesi`
  * "Bu borclulara ne yapabilirim?"    -> `POST /finans/borclulara/...`

HESAP BURADA DEGIL: yaslandirma `app/yaslandirma.py`de, tahsilat toplami
`app/defter.py`de. Router yalnizca kabuktur — ayni hesap rapor
katalogundan da cagriliyor ve iki kopya, iki farkli "90+ gun" tanimi
demekti.
"""
from __future__ import annotations

import uuid
from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from .. import defter, yaslandirma
from ..akis_metinleri import _tl
from ..audit import Action, audit_user
from ..deps import get_tenant_db, require_role
from ..models import AppUser, DuesAssessment, Notification
from ..sakin_bildirimi import sakin_bildirimi_yaz
from ..schemas import (
    BorcluTopluIstek,
    HatirlatmaGecmisi,
    HatirlatmaGecmisiSatiri,
    OdemePlaniIstek,
    OdemePlaniSonuc,
    TahsilatGostergesi,
    TopluFaizAffiSonuc,
    TopluHatirlatmaSonuc,
    YaslandirmaDaire,
    YaslandirmaKovasi,
    YaslandirmaResponse,
)

router = APIRouter(tags=["finans"])

_YONETIM = require_role("admin", "yonetici")
# (P128) Denetci yaslandirmayi ve gostergeyi OKUR; toplu islem yapamaz.
_OKUR = require_role("admin", "yonetici", "denetci")


def _donem_metni(gun: date) -> str:
    return f"{gun.year}-{gun.month:02d}"


def _onceki_donem(donem: str) -> str:
    yil, ay = int(donem[:4]), int(donem[5:7])
    return f"{yil - 1}-12" if ay == 1 else f"{yil}-{ay - 1:02d}"


# ============================ 5.1 YASLANDIRMA =============================== #
@router.get("/finans/yaslandirma", response_model=YaslandirmaResponse)
async def borc_yaslandirma(
    ozet: bool = Query(
        False, description="true = daire listeleri BOS doner (kart gorunumu)"
    ),
    kova: str | None = Query(None, description="Yalniz bu kovanin daireleri"),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_OKUR),
) -> YaslandirmaResponse:
    """Kim ne kadar suredir borclu: 0-30 / 31-60 / 61-90 / 90+ gun.

    DAIRE BASINA TEK KOVA: bir dairenin uc gecikmis borcu varsa uc kovaya
    birden dagitmak, "kac daire 90+ gundur borclu" sorusunu toplami daire
    sayisini asan bir sayiyla yanitlardi.
    """
    kovalar = await yaslandirma.hesapla(db)
    items = []
    for k in kovalar:
        gorunur = (
            [] if ozet or (kova is not None and kova != k.kova) else k.daireler
        )
        items.append(
            YaslandirmaKovasi(
                kova=k.kova, daire=k.daire, kalan_kurus=k.kalan_kurus,
                daireler=[YaslandirmaDaire(**vars(d)) for d in gorunur],
            )
        )
    return YaslandirmaResponse(
        kovalar=items,
        toplam_kalan_kurus=sum(k.kalan_kurus for k in kovalar),
        toplam_daire=sum(k.daire for k in kovalar),
    )


# ========================= 5.2 TAHSILAT GOSTERGESI ========================== #
@router.get("/finans/tahsilat-gostergesi", response_model=TahsilatGostergesi)
async def tahsilat_gostergesi(
    donem: str | None = Query(None, description="'YYYY-MM'; bos = bu ay"),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_OKUR),
) -> TahsilatGostergesi:
    """Bu ay ne kadari tahsil edildi, gecen aya gore nasil.

    TEK KAYNAK (P192 §1): tahakkuk `defter.tahakkuk_toplami`, tahsilat
    `defter.tahsilat_toplami`. Rapor, seffaflik ve mobil ana ekran da
    ayni fonksiyonlari cagirir.
    """
    su_an = donem or _donem_metni(date.today())
    onceki = _onceki_donem(su_an)

    async def _oran(d: str) -> tuple[int, int, int | None]:
        tahakkuk = await defter.tahakkuk_toplami(db, donem=d)
        tahsilat = await defter.tahsilat_toplami(db, donem=d)
        return tahakkuk, tahsilat, (
            round(100 * tahsilat / tahakkuk) if tahakkuk > 0 else None
        )

    tahakkuk, tahsilat, oran = await _oran(su_an)
    _, _, onceki_oran = await _oran(onceki)
    return TahsilatGostergesi(
        donem=su_an,
        tahakkuk_kurus=tahakkuk,
        tahsilat_kurus=tahsilat,
        oran_yuzde=oran,
        onceki_donem=onceki,
        onceki_oran_yuzde=onceki_oran,
        degisim_puan=(
            oran - onceki_oran
            if oran is not None and onceki_oran is not None
            else None
        ),
    )


# ==================== 4.2 HATIRLATMA GECMISI (gorunur iz) =================== #
@router.get("/finans/hatirlatma-gecmisi", response_model=HatirlatmaGecmisi)
async def hatirlatma_gecmisi(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_OKUR),
) -> HatirlatmaGecmisi:
    """(P192 §4.2) Kac hatirlatma gitti, KIM ACTI.

    Sayilar `otomasyon_gunlugu`nda da var ama orasi "gorev ne yapti"
    sorusunu yanitlar; burasi "kime ulasti"yi. Okundu bilgisi ALICIYA
    aittir (alici basina ayri `notification` satiri), yoksa bir
    kullanicinin okumasi otekininkini de okundu yapardi.

    ELLE ve OTOMATIK hatirlatmalar AYNI listede: sakin acisindan ikisi de
    ayni bildirimdir ve ayirmak, "bu kisiye kac kez yazdik" sorusunu iki
    ekrana bolerdi.
    """
    where = [
        Notification.tip == "aidat_hatirlatma",
        Notification.silindi_at.is_(None),
    ]
    total = (
        await db.execute(
            select(func.count()).select_from(Notification).where(*where)
        )
    ).scalar_one()
    okunan = (
        await db.execute(
            select(func.count()).select_from(Notification)
            .where(*where, Notification.okundu.is_(True))
        )
    ).scalar_one()
    rows = (
        await db.execute(
            select(Notification, AppUser.ad)
            .outerjoin(AppUser, AppUser.id == Notification.user_id)
            .where(*where)
            .order_by(Notification.created_at.desc(), Notification.id.desc())
            .limit(limit).offset(offset)
        )
    ).all()
    return HatirlatmaGecmisi(
        meta={"limit": limit, "offset": offset, "total": total},
        gonderilen=int(total),
        okunan=int(okunan),
        items=[
            HatirlatmaGecmisiSatiri(
                id=n.id,
                user_id=n.user_id,
                ad=ad,
                gonderim_zamani=n.created_at,
                okundu=n.okundu,
                tutar=(n.mesaj_veri or {}).get("tutar"),
            )
            for n, ad in rows
        ],
    )


# ========================== 5.3 TOPLU ISLEMLER ============================== #
async def _secili_borclular(
    db: AsyncSession, unit_ids: list[uuid.UUID]
) -> list[yaslandirma.DaireYaslandirma]:
    """Secilen dairelerin ACIK borc durumu.

    KAPANMIS DAIRE LISTEDE YOKTUR: kullanici ekranda gordugu listeyi
    seciyor ama arada odeme gelmis olabilir; kapanmis borca hatirlatma
    gondermek, odemis sakini rahatsiz etmek olurdu.
    """
    kovalar = await yaslandirma.hesapla(db)
    secili = set(unit_ids)
    return [
        d for k in kovalar for d in k.daireler if d.unit_id in secili
    ]


@router.post(
    "/finans/borclulara/hatirlat", response_model=TopluHatirlatmaSonuc
)
async def toplu_hatirlat(
    body: BorcluTopluIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> TopluHatirlatmaSonuc:
    """Secilen borclulara ELLE hatirlatma.

    Otomatik hatirlatmadan (§4.2) AYRIDIR ve onun gunluk damgasina
    DOKUNMAZ: yonetici bilincli olarak "simdi gonder" diyor ve bunun
    otomatik akisi susturmasi beklenmez.
    """
    from ..scheduler.notify import dispatch_external

    hedefler = await _secili_borclular(db, body.unit_ids)
    gonderilen = 0
    for daire in hedefler:
        if daire.borclu_user_id is None:
            continue
        params = {"tutar": _tl(daire.kalan_kurus), "vade": str(daire.en_eski_gun)}
        dispatch_external(
            "aidat_hatirlatma",
            tenant_id=user.tenant_id,
            target_user_ids=(daire.borclu_user_id,),
            params=params,
            data={"tip": "aidat_hatirlatma"},
        )
        sakin_bildirimi_yaz(
            db, tenant_id=user.tenant_id, tip="aidat_hatirlatma",
            user_ids=(daire.borclu_user_id,), veri=params,
        )
        gonderilen += 1
    await audit_user(
        db, user, Action.MESAJ_GONDER, resource_type="dues_assessment",
        meta={"islem": "toplu_hatirlatma", "gonderilen": gonderilen},
    )
    return TopluHatirlatmaSonuc(
        gonderilen=gonderilen, atlanan=len(body.unit_ids) - gonderilen
    )


@router.post(
    "/finans/borclulara/faiz-affi", response_model=TopluFaizAffiSonuc
)
async def toplu_faiz_affi(
    body: BorcluTopluIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> TopluFaizAffiSonuc:
    """Secilen dairelerin ACIK faiz kalemlerini TERS KAYITLA affeder.

    SILME YOK: af bir KARARDIR ve izi kalmali (kime, ne zaman, ne kadar).
    Ters kayit ciftinin toplami sifirdir; borc "hic yazilmamis" hale
    gelmez, AFFEDILMIS olur.
    """
    faizler = (
        await db.execute(
            select(DuesAssessment).where(
                DuesAssessment.unit_id.in_(body.unit_ids),
                DuesAssessment.kalem_tipi == "faiz",
                *defter.gecerli_tahakkuk(),
            )
        )
    ).scalars().all()
    odenen = await defter.tahakkuk_odenen(db, [f.id for f in faizler])

    affedilen = 0
    toplam = 0
    for faiz in faizler:
        if odenen.get(faiz.id, 0) > 0:
            # ODENMIS FAIZ AFFEDILEMEZ: alinmis parayi karsiliksiz
            # birakmak, daireyi ALACAKLI gosterirdi (§6.3 ile ayni kural).
            continue
        db.add(
            DuesAssessment(
                tenant_id=user.tenant_id,
                unit_id=faiz.unit_id,
                donem=faiz.donem,
                tutar_kurus=faiz.tutar_kurus,
                kalem_tipi="faiz",
                kaynak_assessment_id=faiz.kaynak_assessment_id,
                hedef_user_id=faiz.hedef_user_id,
                ters_kayit_id=faiz.id,
                gecikme_uygula=False,
                aciklama="Faiz affi",
                kaynak=faiz.kaynak,
            )
        )
        faiz.iptal_edildi = True
        affedilen += 1
        toplam += faiz.tutar_kurus
    await db.flush()
    if affedilen:
        await audit_user(
            db, user, Action.DUES_ASSESSMENT_CREATE,
            resource_type="dues_assessment",
            meta={"islem": "toplu_faiz_affi", "adet": affedilen,
                  "toplam_kurus": toplam},
        )
    return TopluFaizAffiSonuc(affedilen_kalem=affedilen, toplam_kurus=toplam)


@router.post(
    "/finans/borclulara/odeme-plani", response_model=OdemePlaniSonuc
)
async def toplu_odeme_plani(
    body: OdemePlaniIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> OdemePlaniSonuc:
    """Vade YAPILANDIRMASI — acik borclarin vadelerini aya yayar.

    ===================================================================
    NEDEN YENI BORC URETILMIYOR
    ===================================================================
    "Odeme plani" denince akla borcu N taksite BOLMEK gelir. Uründe bu,
    eski borclari ters kayitlayip N yeni kalem yazmak demekti — ve KISMI
    ODENMIS bir borcu ters kayitlamak alinmis parayi karsiliksiz
    birakirdi (daire ALACAKLI gorunurdu).

    Bu yuzden plan borcun KENDISINE degil VADESINE dokunur: acik borclar
    en eskiden yeniye siralanir ve vadeleri `ilk_vade`den baslayarak
    aylik olarak dagitilir. Sonuc sakin acisindan aynidir (odeme
    takvimi degisti) ama defter tutarli kalir.

    YAN ETKI (bilincli): vade ileri atildigi icin GECIKME FAIZI de
    yeniden hesaplanir ve azalir — bir odeme planinin zaten beklenen
    davranisi budur.
    """
    from ..otomasyon import ay_ekle

    daireler = await _secili_borclular(db, body.unit_ids)
    if not daireler:
        return OdemePlaniSonuc(daire=0, guncellenen_borc=0)

    borclar = (
        await db.execute(
            select(DuesAssessment)
            .where(
                DuesAssessment.unit_id.in_([d.unit_id for d in daireler]),
                DuesAssessment.son_odeme_tarihi.isnot(None),
                *defter.gecerli_tahakkuk(),
            )
            .order_by(DuesAssessment.son_odeme_tarihi, DuesAssessment.id)
        )
    ).scalars().all()
    odenen = await defter.tahakkuk_odenen(db, [b.id for b in borclar])

    daire_bazli: dict[uuid.UUID, list[DuesAssessment]] = {}
    for borc in borclar:
        if borc.tutar_kurus - odenen.get(borc.id, 0) <= 0:
            continue
        daire_bazli.setdefault(borc.unit_id, []).append(borc)

    guncellenen = 0
    for acik in daire_bazli.values():
        for sira, borc in enumerate(acik):
            # TAKSIT SAYISINI ASAN borclar SON taksite yigilir: uc taksitlik
            # bir plan bes borcu bes aya yaymamali, kullanici uc ay dedi.
            ay = min(sira, body.taksit_sayisi - 1)
            borc.son_odeme_tarihi = ay_ekle(body.ilk_vade, ay)
            guncellenen += 1
    await db.flush()
    await audit_user(
        db, user, Action.DUES_ASSESSMENT_CREATE,
        resource_type="dues_assessment",
        meta={"islem": "odeme_plani", "daire": len(daire_bazli),
              "taksit": body.taksit_sayisi,
              "ilk_vade": body.ilk_vade.isoformat()},
    )
    return OdemePlaniSonuc(daire=len(daire_bazli), guncellenen_borc=guncellenen)
