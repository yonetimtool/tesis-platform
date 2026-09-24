"""(P241 §1) PERIYODIK BAKIM TAKIBI — ekipman, bakim kaydi, yillik ozet.

===========================================================================
NEDEN DEMIRBASTAN AYRI — OLCULEREK KARAR VERILDI
===========================================================================
Bkz. goc `0144_bakim_takibi` ve `docs/P241-kararlar.md` §1. Ozet:
demirbas (`asset`) KIME ZIMMETLENDIGINI takip eder, bu modul NE ZAMAN
BAKILDIGINI. Asansor kimseye zimmetlenmez.

===========================================================================
BAKIM KAYDI UC SEYI BIRDEN YAPAR — TEK ISLEMDE
===========================================================================
Bir bakim yapildiginda: (1) kayit yazilir, (2) ekipmanin `son_bakim`i
guncellenir ve `sonraki_bakim` periyoda gore ILERLER, (3) tutar
girildiyse deftere ONAY BEKLEYEN gider dusulur.

Ucu de AYNI islemde: ikisi yazilip ucuncusu yazilmazsa "bakim yapildi
ama tarih ilerlemedi" ya da "para cikti ama bakim kaydi yok" gibi
kendini gizleyen bir tutarsizlik olusurdu.

BILDIRIM DAMGALARI TEMIZLENIR: yeni donem yeniden bildirilsin.

===========================================================================
ROL: YONETIM YAZAR, SAHA OKUR
===========================================================================
Bakim planini yonetim kurar. Saha personeli (guvenlik, tesis gorevlisi)
listeyi GORUR — "bugun asansor bakimi var, firma gelecek" bilgisi kapida
duran kisinin isine yarar — ama plani DEGISTIREMEZ. Sakin gormez: bu bir
isletme kaydidir, kisisel bir hizmet degil.
"""
from __future__ import annotations

import uuid
from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..bakim import (
    GECIKME_TEKRAR_GUN,
    VARSAYILAN_UYARI_GUN,
    durum as _durum,
    kalan_gun as _kalan,
    sonraki_tarih,
)
from ..crud_helpers import get_or_404
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import (
    AppUser,
    BakimEkipmani,
    BakimKaydi,
    BuildingBlock,
    Firma,
    FinansalHareket,
    Tenant,
)
from ..schemas import (
    BakimEkipmaniCreate,
    BakimEkipmaniListResponse,
    BakimEkipmaniOut,
    BakimEkipmaniUpdate,
    BakimKaydiCreate,
    BakimKaydiListResponse,
    BakimKaydiOut,
    BakimOzetSatiri,
    BakimYillikOzet,
    PageMetaOut,
)

router = APIRouter(prefix="/bakim", tags=["bakim"])

#: Plani KURAN roller.
_YAZAR = require_role("admin", "yonetici")
#: Plani GOREN roller — saha da gorur (kapida duran kisi "bugun asansor
#: bakimi var" bilgisini kullanir), sakin GORMEZ.
_OKUR = require_role(
    "admin", "yonetici", "denetci", "guvenlik_amiri", "security", "tesis_gorevlisi"
)

GECIKME_TEKRAR = GECIKME_TEKRAR_GUN


def _bugun() -> date:
    return datetime.now(timezone.utc).date()


async def _tesis_uyari_gun(db: AsyncSession) -> int:
    v = (
        await db.execute(select(Tenant.bakim_uyari_gun).limit(1))
    ).scalar_one_or_none()
    return VARSAYILAN_UYARI_GUN if v is None else int(v)


def _cikti(
    e: BakimEkipmani,
    *,
    tesis_uyari: int,
    blok_ad: str | None = None,
    firma_ad: str | None = None,
    son_kayit: date | None = None,
    bugun: date | None = None,
) -> BakimEkipmaniOut:
    g = bugun or _bugun()
    etkin = e.uyari_gun if e.uyari_gun is not None else tesis_uyari
    return BakimEkipmaniOut(
        id=e.id, ad=e.ad, tur=e.tur, blok_id=e.blok_id, blok_ad=blok_ad,
        alan=e.alan, periyot=e.periyot, periyot_gun=e.periyot_gun,
        son_bakim=e.son_bakim, sonraki_bakim=e.sonraki_bakim,
        firma_id=e.firma_id, firma_ad=firma_ad, sorumlu_ad=e.sorumlu_ad,
        sorumlu_telefon=e.sorumlu_telefon, yasal=e.yasal,
        uyari_gun=e.uyari_gun, etkin_uyari_gun=etkin, asset_id=e.asset_id,
        notlar=e.notlar, aktif=e.aktif,
        durum=_durum(e.sonraki_bakim, etkin, g),
        kalan_gun=_kalan(e.sonraki_bakim, g),
        son_kayit_tarihi=son_kayit,
    )


@router.get("/ekipmanlar", response_model=BakimEkipmaniListResponse)
async def ekipman_liste(
    durum: str | None = Query(None, pattern="^(gecikti|bugun|yaklasti|planli)$"),
    tur: str | None = Query(None, max_length=100),
    aktif: bool | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
) -> BakimEkipmaniListResponse:
    """Varsayilan sira: EN YAKIN TARIH USTTE.

    Gecikmis kayitlar tarihleri gecmiste oldugu icin dogal olarak en
    ustte kalir — ayri bir siralama kuralina gerek yok ve olsaydi
    "gecikmis ama 3 ay once" bir kaydi, "bugun" olan bir kaydin ustune
    cikarirdi.
    """
    kosullar = []
    if tur:
        kosullar.append(BakimEkipmani.tur == tur)
    if aktif is not None:
        kosullar.append(BakimEkipmani.aktif.is_(aktif))

    tesis_uyari = await _tesis_uyari_gun(db)
    toplam = int(
        (
            await db.execute(
                select(func.count()).select_from(BakimEkipmani).where(*kosullar)
            )
        ).scalar_one()
    )
    satirlar = (
        await db.execute(
            select(BakimEkipmani, BuildingBlock.ad, Firma.ad)
            .join(
                BuildingBlock,
                BuildingBlock.id == BakimEkipmani.blok_id,
                isouter=True,
            )
            .join(Firma, Firma.id == BakimEkipmani.firma_id, isouter=True)
            .where(*kosullar)
            .order_by(BakimEkipmani.sonraki_bakim.asc(), BakimEkipmani.id)
            .limit(limit)
            .offset(offset)
        )
    ).all()
    g = _bugun()
    items = [
        _cikti(e, tesis_uyari=tesis_uyari, blok_ad=b, firma_ad=f, bugun=g)
        for e, b, f in satirlar
    ]
    # DURUM SUZGECI SUNUCUDA, SAYFALAMADAN SONRA UYGULANMAZ: turetilmis
    # bir alan oldugu icin SQL'de suzulemiyor; bu yuzden suzgec varken
    # sayfa boyu kadar degil TUM kayitlar okunur ve sonra suzulur.
    # Sessizce yarim liste dondurmek, "gecikmis yok" yanilgisi uretirdi.
    if durum is not None:
        hepsi = (
            await db.execute(
                select(BakimEkipmani, BuildingBlock.ad, Firma.ad)
                .join(
                    BuildingBlock,
                    BuildingBlock.id == BakimEkipmani.blok_id,
                    isouter=True,
                )
                .join(Firma, Firma.id == BakimEkipmani.firma_id, isouter=True)
                .where(*kosullar)
                .order_by(BakimEkipmani.sonraki_bakim.asc(), BakimEkipmani.id)
            )
        ).all()
        suzulmus = [
            _cikti(e, tesis_uyari=tesis_uyari, blok_ad=b, firma_ad=f, bugun=g)
            for e, b, f in hepsi
        ]
        suzulmus = [x for x in suzulmus if x.durum == durum]
        toplam = len(suzulmus)
        items = suzulmus[offset : offset + limit]
    return BakimEkipmaniListResponse(
        meta=PageMetaOut(limit=limit, offset=offset, total=toplam), items=items
    )


@router.post("/ekipmanlar", response_model=BakimEkipmaniOut, status_code=201)
async def ekipman_ekle(
    body: BakimEkipmaniCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> BakimEkipmaniOut:
    """`sonraki_bakim` verilmezse HESAPLANIR.

    Kullanici yalniz "son bakim 1 Mart, periyot 6 aylik" bilgisini
    giriyorsa sonraki tarihi ona hesaplatmak, her ekipmanda tekrar eden
    bir zihinsel is yuklerdi.
    """
    veri = body.model_dump()
    sonraki = veri.pop("sonraki_bakim", None)
    if sonraki is None:
        temel = body.son_bakim or _bugun()
        sonraki = sonraki_tarih(temel, body.periyot, body.periyot_gun)
    obj = BakimEkipmani(tenant_id=user.tenant_id, sonraki_bakim=sonraki, **veri)
    db.add(obj)
    await db.flush()
    await db.refresh(obj)
    await audit_user(
        db, user, Action.BAKIM_YAZ, resource_type="bakim_ekipmani",
        resource_id=obj.id, meta={"ad": obj.ad, "periyot": obj.periyot},
    )
    return _cikti(obj, tesis_uyari=await _tesis_uyari_gun(db))


@router.patch("/ekipmanlar/{ekipman_id}", response_model=BakimEkipmaniOut)
async def ekipman_guncelle(
    ekipman_id: uuid.UUID,
    body: BakimEkipmaniUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> BakimEkipmaniOut:
    obj = await get_or_404(db, BakimEkipmani, ekipman_id)
    alanlar = body.model_dump(exclude_unset=True)
    # PERIYOT TUTARLILIGI: sema tek alan geldiginde karsilastiramaz
    # (yalniz `periyot` gelirse `periyot_gun` gorulmez), bu yuzden
    # BIRLESIK durum burada denetlenir. Denetlenmeseydi DB CHECK'i
    # 500 ile patlardi.
    yeni_periyot = alanlar.get("periyot", obj.periyot)
    yeni_gun = alanlar.get("periyot_gun", obj.periyot_gun)
    if yeni_periyot == "gun" and yeni_gun is None:
        raise APIError(422, "validation_error", "bakim_periyot_gun_gerekli")
    if yeni_periyot != "gun" and yeni_gun is not None:
        raise APIError(422, "validation_error", "bakim_periyot_gun_gecersiz")
    eski_sonraki = obj.sonraki_bakim
    for k, v in alanlar.items():
        setattr(obj, k, v)
    # (E2E 2026-09) PERIYOT DEGISINCE SONRAKI TARIH YENIDEN HESAPLANIR.
    #
    # Olculen: yillik -> aylik yapilan asansorun `sonraki_bakim`i eski
    # (bir yil sonraki) tarihte kaldi; yani periyodu kisaltmak 11 ay
    # boyunca hicbir sey degistirmiyordu. Kural: yonetici tarihi ACIKCA
    # vermediyse ve bir temel (son bakim) varsa, tarih yeni periyottan
    # turetilir. Son bakim hic yoksa tahmin uretilmez — mevcut tarih kalir.
    periyot_degisti = ("periyot" in alanlar or "periyot_gun" in alanlar
                       or "son_bakim" in alanlar)
    if (
        periyot_degisti
        and "sonraki_bakim" not in alanlar
        and obj.son_bakim is not None
    ):
        obj.sonraki_bakim = sonraki_tarih(
            obj.son_bakim, obj.periyot, obj.periyot_gun
        )
    obj.updated_at = func.now()
    # TARIH DEGISTIYSE DAMGALAR TEMIZLENIR: yoneticinin elle ileri
    # aldigi bir tarih icin eski "gecikti" damgasi kalsaydi, yeni tarih
    # geldiginde HIC bildirim gitmezdi.
    if obj.sonraki_bakim != eski_sonraki:
        obj.yaklasti_bildirildi_at = None
        obj.bugun_bildirildi_at = None
        obj.gecikme_bildirildi_at = None
    await db.flush()
    await db.refresh(obj)
    await audit_user(
        db, user, Action.BAKIM_YAZ, resource_type="bakim_ekipmani",
        resource_id=obj.id, meta={"alanlar": sorted(alanlar)},
    )
    return _cikti(obj, tesis_uyari=await _tesis_uyari_gun(db))


@router.delete("/ekipmanlar/{ekipman_id}", status_code=204)
async def ekipman_sil(
    ekipman_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> Response:
    obj = await get_or_404(db, BakimEkipmani, ekipman_id)
    await audit_user(
        db, user, Action.BAKIM_YAZ, resource_type="bakim_ekipmani",
        resource_id=obj.id, meta={"silindi": True, "ad": obj.ad},
    )
    await db.delete(obj)
    return Response(status_code=204)


@router.get("/kayitlar", response_model=BakimKaydiListResponse)
async def kayit_liste(
    ekipman_id: uuid.UUID | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
) -> BakimKaydiListResponse:
    """Gecmis bakimlar — ekipman bazinda suzulebilir."""
    kosullar = []
    if ekipman_id is not None:
        kosullar.append(BakimKaydi.ekipman_id == ekipman_id)
    toplam = int(
        (
            await db.execute(
                select(func.count()).select_from(BakimKaydi).where(*kosullar)
            )
        ).scalar_one()
    )
    satirlar = (
        await db.execute(
            select(BakimKaydi, BakimEkipmani.ad, Firma.ad, AppUser.ad)
            .join(BakimEkipmani, BakimEkipmani.id == BakimKaydi.ekipman_id)
            .join(Firma, Firma.id == BakimKaydi.firma_id, isouter=True)
            .join(AppUser, AppUser.id == BakimKaydi.yapan_user_id, isouter=True)
            .where(*kosullar)
            .order_by(BakimKaydi.tarih.desc(), BakimKaydi.id)
            .limit(limit)
            .offset(offset)
        )
    ).all()
    return BakimKaydiListResponse(
        meta=PageMetaOut(limit=limit, offset=offset, total=toplam),
        items=[
            BakimKaydiOut(
                id=k.id, ekipman_id=k.ekipman_id, ekipman_ad=ead, tarih=k.tarih,
                firma_id=k.firma_id, firma_ad=fad,
                yapan_user_id=k.yapan_user_id,
                # KIM YAPTI: personel secildiyse SISTEMDEKI ad, yoksa
                # elle yazilan ad. Ikisini ayri sutunda tutup tek alanda
                # sunmak, arayuzde her yerde ayni `??` zincirini
                # tekrarlamaktan iyi.
                yapan_ad=uad or k.yapan_ad,
                islem=k.islem, tutar_kurus=k.tutar_kurus,
                hareket_id=k.hareket_id, created_at=k.created_at,
            )
            for k, ead, fad, uad in satirlar
        ],
    )


@router.post(
    "/ekipmanlar/{ekipman_id}/kayitlar",
    response_model=BakimKaydiOut,
    status_code=201,
)
async def kayit_ekle(
    ekipman_id: uuid.UUID,
    body: BakimKaydiCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> BakimKaydiOut:
    """Bakim yapildi: kayit + tarih ilerlemesi + (istege bagli) gider."""
    ekipman = await get_or_404(db, BakimEkipmani, ekipman_id)
    # (E2E 2026-09) GELECEK TARIHLI KAYIT REDDEDILIR.
    #
    # Olculen: 01.01.2030 tarihli bir kayit 201 aldi ve yasal asansor
    # muayenesini `sonraki=2030-02-01, planli` yapti — bir yazim hatasi
    # zorunlu bakimi yillarca gizliyordu. "Bakim yapildi" gecmise dair bir
    # beyandir. BIR GUN TOLERANS: `_bugun` UTC; Turkiye UTC+3 oldugu icin
    # gece 00:00-03:00 arasi girilen "bugun" kaydi UTC'de yarin gorunur.
    if body.tarih > _bugun() + timedelta(days=1):
        raise APIError(422, "validation_error", "bakim_tarihi_gelecekte")
    kayit = BakimKaydi(
        tenant_id=user.tenant_id,
        ekipman_id=ekipman.id,
        tarih=body.tarih,
        firma_id=body.firma_id,
        yapan_user_id=body.yapan_user_id,
        yapan_ad=body.yapan_ad,
        islem=body.islem,
        tutar_kurus=body.tutar_kurus,
        olusturan_user_id=user.id,
    )
    db.add(kayit)

    # TUTAR VARSA DEFTERE ONAY BEKLEYEN GIDER (P192 TEK DEFTER).
    #
    # `odendi` YAZILMAZ: kaydi giren kisi (bakimi yapan personel de
    # olabilir) harcamayi ONAYLAMIS sayilmamali. Onay/red uclari
    # `finans`ta zaten var.
    if body.gidere_yaz and body.tutar_kurus:
        hareket = FinansalHareket(
            tenant_id=user.tenant_id,
            tip="gider",
            yon="cikis",
            tutar_kurus=body.tutar_kurus,
            tarih=body.tarih,
            firma_id=body.firma_id,
            aciklama=f"{ekipman.ad} — bakım",
            durum="onay_bekliyor",
            kaydeden_user_id=user.id,
        )
        db.add(hareket)
        await db.flush()
        kayit.hareket_id = hareket.id

    # TARIH ILERLER: yeni `sonraki_bakim` ya verilen deger ya periyottan.
    #
    # (E2E 2026-09) YALNIZ ILERI. Olculen: 20.09 bakimindan sonra
    # unutulmus 15.08 kaydi girilince `son_bakim` 15.08'e, `sonraki`
    # 15.09'a GERI dustu ve az once bakimi yapilmis asansor "gecikti"
    # gorundu. Eski tarihli kayit GECMISE eklenir (yillik ozette sayilir,
    # gideri deftere duser) ama plani geri almaz.
    if ekipman.son_bakim is None or body.tarih >= ekipman.son_bakim:
        ekipman.son_bakim = body.tarih
        ekipman.sonraki_bakim = body.sonraki_bakim or sonraki_tarih(
            body.tarih, ekipman.periyot, ekipman.periyot_gun
        )
        # YENI DONEM YENIDEN BILDIRILSIN.
        ekipman.yaklasti_bildirildi_at = None
        ekipman.bugun_bildirildi_at = None
        ekipman.gecikme_bildirildi_at = None
        ekipman.updated_at = func.now()

    await db.flush()
    await db.refresh(kayit)
    await audit_user(
        db, user, Action.BAKIM_KAYIT, resource_type="bakim_kaydi",
        resource_id=kayit.id,
        meta={
            "ekipman": ekipman.ad,
            "tarih": body.tarih.isoformat(),
            "tutar_kurus": body.tutar_kurus,
            "hareket_id": str(kayit.hareket_id) if kayit.hareket_id else None,
        },
    )
    return BakimKaydiOut(
        id=kayit.id, ekipman_id=kayit.ekipman_id, ekipman_ad=ekipman.ad,
        tarih=kayit.tarih, firma_id=kayit.firma_id, firma_ad=None,
        yapan_user_id=kayit.yapan_user_id, yapan_ad=kayit.yapan_ad,
        islem=kayit.islem, tutar_kurus=kayit.tutar_kurus,
        hareket_id=kayit.hareket_id, created_at=kayit.created_at,
    )


@router.get("/ozet", response_model=BakimYillikOzet)
async def yillik_ozet(
    yil: int = Query(..., ge=2000, le=2200),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(require_role("admin", "yonetici", "denetci")),
) -> BakimYillikOzet:
    """Yillik bakim ozeti — denetime verilebilecek kalitede.

    `yasal_eksik`: yasal zorunlu oldugu halde YIL ICINDE HIC BAKIM
    GORMEMIS ekipmanlar. Denetimin ilk soracagi sey budur ve toplamlarin
    arasinda kaybolmamali — bu yuzden AYRI alan.

    DENETCI OKUR: rapor site isletmesinin belgesidir.
    """
    bas = date(yil, 1, 1)
    bit = date(yil, 12, 31)
    ekipmanlar = (
        await db.execute(
            select(BakimEkipmani).order_by(BakimEkipmani.ad, BakimEkipmani.id)
        )
    ).scalars().all()
    sayimlar = dict(
        (
            (r[0], (r[1], r[2]))
            for r in (
                await db.execute(
                    select(
                        BakimKaydi.ekipman_id,
                        func.count(),
                        func.coalesce(func.sum(BakimKaydi.tutar_kurus), 0),
                    )
                    .where(BakimKaydi.tarih >= bas, BakimKaydi.tarih <= bit)
                    .group_by(BakimKaydi.ekipman_id)
                )
            ).all()
        )
    )
    satirlar: list[BakimOzetSatiri] = []
    toplam = 0
    eksik: list[str] = []
    for e in ekipmanlar:
        adet, tutar = sayimlar.get(e.id, (0, 0))
        toplam += int(tutar)
        satirlar.append(
            BakimOzetSatiri(
                ekipman_id=e.id, ad=e.ad, tur=e.tur, yasal=e.yasal,
                bakim_sayisi=int(adet), toplam_kurus=int(tutar),
                son_bakim=e.son_bakim, sonraki_bakim=e.sonraki_bakim,
            )
        )
        if e.yasal and e.aktif and adet == 0:
            eksik.append(e.ad)
    return BakimYillikOzet(
        yil=yil, satirlar=satirlar, toplam_kurus=toplam, yasal_eksik=eksik
    )
