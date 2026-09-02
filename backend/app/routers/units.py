"""Unit (daire) CRUD + sakin atama — /contracts/openapi.yaml.

RBAC (D-viz Rev-1): daire CRUD + yerlesim (list/get/create/update/delete/layout)
admin + YONETICI (bina yerlesimi yonetimi). Sakin atama (residents alt-kaynagi)
ile aidat YALNIZ admin (yonetim/muhasebe islemi).
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404, is_unique_violation, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import (
    AppUser,
    BuildingBlock,
    DuesAssessment,
    FinansalHareket,
    Rezervasyon,
    Unit,
    UnitComplaint,
    UnitGrup,
    UnitResident,
    UnitTip,
)
from ..schemas import (
    DaireAramaOut,
    ArsaPayiOzet,
    ArsaPayiToplu,
    KatSilOnizleme,
    ResidentAssign,
    UnitBulkCreate,
    UnitBulkResult,
    TopluIslemSonuc,
    TopluSilSonuc,
    KatSilIstek,
    UnitSiralama,
    UnitTopluGuncelle,
    UnitCreate,
    UnitLayoutUpdate,
    UnitListResponse,
    UnitOut,
    UnitResidentBriefOut,
    UnitResidentOut,
    UnitUpdate,
)

router = APIRouter(prefix="/units", tags=["aidat"])


async def _tanim_dogrula(
    db: AsyncSession, tip_id: uuid.UUID | None, grup_id: uuid.UUID | None
) -> None:
    """Verilen tip/grup BU TENANT'ta var mi (P26).

    Bilesik FK zaten baska tenant'in tanimina baglanmayi engelliyor, ama o
    ihlal bir IntegrityError uretir ve kullaniciya "veri butunlugu" gibi
    okunur. Burada ONCEDEN olculur ve 422 `invalid_reference` doner.
    """
    for kimlik, model, metin in (
        (tip_id, UnitTip, "daire_tipi_bulunamadi"),
        (grup_id, UnitGrup, "daire_grubu_bulunamadi"),
    ):
        if kimlik is None:
            continue
        var = (
            await db.execute(select(model.id).where(model.id == kimlik))
        ).scalar_one_or_none()
        if var is None:
            raise APIError(422, "invalid_reference", metin)


async def _adlarla(db: AsyncSession, unitler: list[Unit]) -> list[UnitOut]:
    """Daireleri tip/grup ADLARIYLA birlikte serilestir (P26).

    Adlar TEK sorguda cozulur: liste basina daire x 2 istek (N+1) yapmak,
    200 daire cizen panelde 400 ek sorgu demekti. Ad yoksa (siniflandirmasiz
    ya da tanim silinmis daire) `null` doner — uydurma etiket YOK.
    """
    tip_idler = {u.unit_tip_id for u in unitler if u.unit_tip_id}
    grup_idler = {u.unit_grup_id for u in unitler if u.unit_grup_id}
    tip_ad: dict[uuid.UUID, str] = {}
    grup_ad: dict[uuid.UUID, str] = {}
    if tip_idler:
        tip_ad = dict(
            (await db.execute(
                select(UnitTip.id, UnitTip.ad).where(UnitTip.id.in_(tip_idler))
            )).all()
        )
    if grup_idler:
        grup_ad = dict(
            (await db.execute(
                select(UnitGrup.id, UnitGrup.ad).where(UnitGrup.id.in_(grup_idler))
            )).all()
        )
    return [
        UnitOut.model_validate(u).model_copy(update={
            "unit_tip_ad": tip_ad.get(u.unit_tip_id),
            "unit_grup_ad": grup_ad.get(u.unit_grup_id),
        })
        for u in unitler
    ]

_ADMIN = require_role("admin")
# Fiziksel yerlesim (blok/kat/sira) girisi — yonetim: admin + yonetici.
# (Genel daire CRUD admin-only kalir; yalniz yerlesim yonetici'ye acilir.)
_LAYOUT_EDITOR = require_role("admin", "yonetici")
# Yerlesim OKUMA: yonetim + saha (security/tesis_gorevlisi) — "Bina Duzenleme"
# ekranini SALT-OKUMA gorurler (yazma yine _LAYOUT_EDITOR = 403).
_LAYOUT_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi")
# SAKIN-DAIRE BAGI (P23a) — admin + yonetici.
#
# Gerekce: sakin CRUD'u (`/residents`) ZATEN admin+yonetici. "Kim nerede
# oturuyor" ayni sinif veridir; bagi admin-only birakmak, mobilde sakin
# yoneten yoneticinin var olan bir sakine daire ATAYAMAMASI demekti — yani
# P23(a) uygulamadan ULASILAMAZ kaliyordu. Genel daire CRUD'u admin-only
# KALIR; acilan yalniz bagdir.
_BAG_YONETICI = require_role("admin", "yonetici")
# Hedef sakin secicisi (guvenlik ziyaretci kaydinda kullanir) — okuma
# guvenlik + yonetim; sakin komsularini LISTELEYEMEZ (403).
_RESIDENT_LISTER = require_role("security", "admin", "yonetici")


@router.get("", response_model=UnitListResponse)
async def list_units(
    # (P187) le 200 -> 1000: yeni kullanici formundaki BLOK->DAIRE secici TUM
    # daireleri tek cagrida ister (limit=1000). 200 tavani, 200'den cok daireli
    # sitede listeyi bos dondurup (422) sakin eklemeyi kilitliyordu. Istemci ve
    # tavan artik uyumlu; 1000 pratikte her konut sitesini kapsar.
    limit: int = Query(50, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    blok: str | None = Query(None),
    aktif: bool | None = Query(None),
    unit_tip_id: uuid.UUID | None = Query(
        None, description="(P26) Tipe gore suzgec"
    ),
    unit_grup_id: uuid.UUID | None = Query(
        None, description="(P26) Gruba gore suzgec"
    ),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_LAYOUT_READER),
) -> UnitListResponse:
    where = []
    if blok is not None:
        where.append(Unit.blok == blok)
    if aktif is not None:
        where.append(Unit.aktif == aktif)
    if unit_tip_id is not None:
        where.append(Unit.unit_tip_id == unit_tip_id)
    if unit_grup_id is not None:
        where.append(Unit.unit_grup_id == unit_grup_id)
    total = (await db.execute(select(func.count()).select_from(Unit).where(*where))).scalar_one()
    rows = (
        await db.execute(select(Unit).where(*where).order_by(Unit.no, Unit.id).limit(limit).offset(offset))
    ).scalars().all()
    return UnitListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=await _adlarla(db, list(rows)),
    )


# SIRA ONEMLI — BU UC `/{unit_id}`DEN ONCE DURMALI.
#
# ILK YAZIMDA DOSYANIN ALTINDAYDI ve SESSIZCE OLUYDU: FastAPI rotalari
# TANIM SIRASINDA dener, `/units/{unit_id}` once eslesir ve "kat-onizleme"
# bir UUID sanilirdi (422). Kusuru `test_rol_matrisi_kilidi` yakaladi —
# ucun izin sutunlari `_LAYOUT_EDITOR`in degil `/{unit_id}`in matrisini
# gosteriyordu. Web testleri yakalayamazdi: orada fetch taklit ediliyor.
#
# AYNI SINIF KUSUR P163'te 405 olarak cikmisti (BFF'te statik segment
# dinamikten sonra geliyordu). Statik yol dinamik yoldan ONCE yazilir.
@router.get("/kat-onizleme", response_model=KatSilOnizleme)
async def kat_onizleme(
    blok: str = Query(..., min_length=1, max_length=8),
    kat: int = Query(...),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_LAYOUT_EDITOR),
) -> KatSilOnizleme:
    """(P165) Kat silinirse NE KAYBEDILECEK — sayar, silmez.

    ISTEMCIDE HESAPLANAMAZ: daire basina sakin/tahakkuk/talep saymak,
    elli daireli bir katta elli istek demekti. Tek sorgu, tek yanit.

    KAPI SILME ILE AYNI (`_LAYOUT_EDITOR`): ozet, silme yetkisi olmayana
    gosterilecek bir bilgi degil — kac sakini oldugunu ogrenmek de bir
    okuma yetkisidir.
    """
    daire_idler = (
        (await db.execute(
            select(Unit.id).where(Unit.blok == blok, Unit.kat == kat)
        )).scalars().all()
    )
    if not daire_idler:
        # BOS KAT DA GECERLI BIR CEVAPTIR: 404 donmek, arayuzu "kat yok"
        # demeye zorlardi; oysa kullanici o kati EKRANDA goruyor olabilir
        # (yerel onizleme kati). Sifirlarla donmek dogru olan.
        return KatSilOnizleme(
            blok=blok, kat=kat, daire=0, sakin=0, tahakkuk=0,
            odeme=0, talep=0, rezervasyon=0, mali_kayit=False,
        )

    async def _say(model, alan, *ek) -> int:
        return int(
            (await db.execute(
                select(func.count()).select_from(model)
                .where(alan.in_(daire_idler), *ek)
            )).scalar_one()
        )

    sakin = await _say(UnitResident, UnitResident.unit_id)
    tahakkuk = await _say(DuesAssessment, DuesAssessment.unit_id)
    # (P192 §1) Tahsilat artik `dues_payment`te degil defterde.
    odeme = await _say(
        FinansalHareket, FinansalHareket.unit_id, FinansalHareket.tip == "tahsilat"
    )
    talep = await _say(UnitComplaint, UnitComplaint.target_unit_id)
    rezervasyon = await _say(Rezervasyon, Rezervasyon.unit_id)

    return KatSilOnizleme(
        blok=blok,
        kat=kat,
        daire=len(daire_idler),
        sakin=sakin,
        tahakkuk=tahakkuk,
        odeme=odeme,
        talep=talep,
        rezervasyon=rezervasyon,
        # MALI KAYIT AYRI ISARETLENIR: digerleri yeniden olusturulabilir,
        # bir tahsilat kaydi olusturulamaz.
        mali_kayit=tahakkuk > 0 or odeme > 0,
    )


# NOT: BU IKI YOL `/{unit_id}` YAKALAYICISINDAN ONCE TANIMLANIR.
# FastAPI yollari SIRAYLA dener; asagida tanimlansaydi "arsa-payi-ozeti"
# bir `unit_id` sanilir ve uc 422 "gecersiz UUID" donerdi (olculdu).
# ==================== (P193 §6) ARSA PAYI — TOPLU GIRIS ==================== #
#
# Rehberde eksik 6: arsa payi YALNIZ tek tek girilebiliyordu. 100 daireli
# bir sitede bu 100 ayri form demekti ve arsa payi girilmemis daire, arsa
# payina gore dagitimin DISINDA kaliyordu — yani eksik giris sessiz bir
# yanlis paylasima donusuyordu.
@router.get("/arsa-payi-ozeti", response_model=ArsaPayiOzet)
async def arsa_payi_ozeti(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_BAG_YONETICI),
) -> ArsaPayiOzet:
    """Arsa payi TOPLAMI + kac dairede girilmis/girilmemis.

    TOPLAM AYRI BIR UCTAN GELIR, ekranda toplanmaz: daire listesi
    SAYFALIDIR ve gorunen 25 satirin toplami "toplam arsa payi" DEGILDIR.
    Yanlis bir toplam, dogru gorunen bir hatadir.
    """
    satir = (
        await db.execute(
            select(
                func.count(Unit.id),
                func.count(Unit.arsa_payi),
                func.coalesce(func.sum(Unit.arsa_payi), 0),
            ).where(Unit.aktif.is_(True))
        )
    ).one()
    return ArsaPayiOzet(
        daire_sayisi=int(satir[0]),
        girilmis=int(satir[1]),
        girilmemis=int(satir[0]) - int(satir[1]),
        toplam=float(satir[2]),
    )


@router.patch("/arsa-payi", response_model=TopluIslemSonuc)
async def arsa_payi_toplu(
    body: ArsaPayiToplu,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_LAYOUT_EDITOR),
) -> TopluIslemSonuc:
    """DAIRE BASINA FARKLI arsa payini TEK ISTEKTE yazar.

    `PATCH /units/toplu` ile ayni sey DEGIL: o secili dairelerin HEPSINE
    ayni degeri yazar. Arsa payi ise dogasi geregi daire basina
    farklidir; tek tek PATCH atmak 100 istek, 100 denetim kaydi ve
    yarim kalabilen bir yazma demekti.

    `arsa_payi: null` degeri KALDIRIR — ticari birim ya da ortak alan
    dagitim disinda birakilabilmeli.
    """
    kimlikler = [s.id for s in body.satirlar]
    kayitlar = {
        k.id: k
        for k in (
            await db.execute(select(Unit).where(Unit.id.in_(kimlikler)))
        ).scalars().all()
    }
    for satir in body.satirlar:
        k = kayitlar.get(satir.id)
        if k is None:
            continue
        k.arsa_payi = satir.arsa_payi
        k.updated_at = func.now()
    await db.flush()
    await audit_user(
        db, user, Action.UNIT_UPDATE, resource_type="unit",
        meta={"adet": len(kayitlar), "alanlar": ["arsa_payi"]},
    )
    return TopluIslemSonuc(
        etkilenen=len(kayitlar),
        atlanan=[str(i) for i in kimlikler if i not in kayitlar],
    )


@router.get("/ara", response_model=list[DaireAramaOut])
async def daire_ara(
    q: str = Query("", max_length=100),
    limit: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_RESIDENT_LISTER),
) -> list[DaireAramaOut]:
    """(P203 §3) Daire ARAMA — numara VEYA SAKIN ADIYLA.

    =======================================================================
    NEDEN VAR: KAPIDAKI GOREVLI DAIRE NUMARASINI BILMEYEBILIR
    =======================================================================
    Ziyaretci kaydinda daire ELLE yaziliyordu. Kapida duran gorevli
    cogu zaman "Ayse Hanim'a geldim" cumlesini duyar, "A-12'ye geldim"
    cumlesini degil. Numarayi bilmedigi icin ya sakini arayip soruyor ya
    da yanlis daire yaziyordu — ikincisi SESSIZ bir kusurdur: kayit
    olusur, bildirim BASKA BIR SAKINE gider.

    =======================================================================
    KVKK: YENI BIR IFSA DEGIL, AYNI VERININ BASKA INDEKSI
    =======================================================================
    Guvenlik ZATEN `/units/by-no/{no}/residents` ile bir dairenin aktif
    sakinlerinin adini goruyor. Bu uc ayni kumeyi ADLA da aranabilir
    kiliyor. AMAC SINIRLI kalsin diye:
      * yalniz AKTIF baglantilar (bitis IS NULL),
      * yalniz `user_id` + `ad` doner — telefon/e-posta/borc YOK,
      * BOS SORGU BOS LISTE doner: uc, "tum sakinleri dok" araci
        DEGILDIR; en az iki karakter aranir,
      * `limit` tavani 50.

    RBAC `by-no/.../residents` ile AYNI (`_RESIDENT_LISTER`): security +
    admin + yonetici. Guvenlige yeni bir yetki VERILMIYOR.
    """
    aranan = q.strip()
    # BOS/TEK HARF SORGU BOS DONER: aksi hâlde uc, tek istekle butun
    # daire ve sakin listesini veren bir dokum araci olurdu.
    if len(aranan) < 2:
        return []
    kalip = f"%{aranan.lower()}%"

    # Daire NO'suna gore eslesen daireler.
    no_eslesen = select(Unit.id).where(func.lower(Unit.no).like(kalip))
    # SAKIN ADINA gore eslesen daireler (yalniz AKTIF baglanti).
    ad_eslesen = (
        select(UnitResident.unit_id)
        .join(AppUser, AppUser.id == UnitResident.user_id)
        .where(func.lower(AppUser.ad).like(kalip), UnitResident.bitis.is_(None))
    )
    daireler = (
        await db.execute(
            select(Unit)
            .where(Unit.id.in_(no_eslesen.union(ad_eslesen)))
            .order_by(Unit.blok, Unit.no)
            .limit(limit)
        )
    ).scalars().all()
    if not daireler:
        return []

    # Sakinleri TEK SORGUDA topla: daire basina ayri sorgu, 20 daire icin
    # 20 gidis-donus demekti (arama her tusta cagriliyor).
    kimlikler = [d.id for d in daireler]
    satirlar = (
        await db.execute(
            select(UnitResident.unit_id, AppUser.id, AppUser.ad)
            .join(AppUser, AppUser.id == UnitResident.user_id)
            .where(
                UnitResident.unit_id.in_(kimlikler),
                UnitResident.bitis.is_(None),
            )
            .order_by(AppUser.ad)
        )
    ).all()
    sakinler: dict[uuid.UUID, list[UnitResidentBriefOut]] = {}
    for unit_id, uid, ad in satirlar:
        sakinler.setdefault(unit_id, []).append(
            UnitResidentBriefOut(user_id=uid, ad=ad)
        )
    return [
        DaireAramaOut(
            id=d.id,
            no=d.no,
            blok=d.blok,
            sakinler=sakinler.get(d.id, []),
        )
        for d in daireler
    ]


# (P203 §3) SIRA ANLAMLI: `/ara` `/{unit_id}`DEN ONCE tanimlanmali.
# Aksi hâlde FastAPI "ara" metnini `unit_id` sanip UUID dogrulamasina
# sokar ve uc 422 doner — ILK YAZIMDA tam olarak bu oldu ve testler
# yakaladi. Ayni sinif `admin-web`de `[id]` dinamik segmentinde de
# olculmustu (P189).
@router.get("/{unit_id}", response_model=UnitOut)
async def get_unit(
    unit_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_LAYOUT_READER),
) -> UnitOut:
    obj = await get_or_404(db, Unit, unit_id)
    return (await _adlarla(db, [obj]))[0]


@router.get("/by-no/{unit_no}/residents", response_model=list[UnitResidentBriefOut])
async def list_unit_residents_by_no(
    unit_no: str,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_RESIDENT_LISTER),
) -> list[UnitResidentBriefOut]:
    """Bir dairenin AKTIF sakinleri (user_id + ad) — hedef sakin secicisi.

    Guvenlik daire NUMARASINI bilir (unit_id yetkisi yok); unit_no tenant
    icinde cozulur (RLS), bulunamazsa 404. Yalniz AKTIF baglantilar
    (bitis IS NULL). RBAC: security + admin + yonetici; resident 403.
    """
    unit = (
        await db.execute(select(Unit).where(Unit.no == unit_no))
    ).scalar_one_or_none()
    if unit is None:
        raise APIError(404, "not_found", "daire_bulunamadi")
    rows = (
        await db.execute(
            select(AppUser.id, AppUser.ad)
            .join(UnitResident, UnitResident.user_id == AppUser.id)
            .where(UnitResident.unit_id == unit.id, UnitResident.bitis.is_(None))
            .order_by(AppUser.ad)
        )
    ).all()
    return [UnitResidentBriefOut(user_id=r.id, ad=r.ad) for r in rows]


async def _blok_kaydini_gerektir(
    db: AsyncSession, user: AppUser, blok: str | None
) -> None:
    """(P167 Asama 3) Daire bir bloga baglaniyorsa BLOGUN KAYDI DA OLSUN.

    ===================================================================
    BILDIRILEN KUSUR
    ===================================================================
    Web'den toplu olusturulan daireler editorde "kayitsiz (yalnizca
    dairede)" ibaresiyle geliyor, duzenlenemiyor ve silinemiyordu.
    Mobilden ayni islem duzgun calisiyordu.

    KOK NEDEN: iki istemci AYNI ucu AYNI govdeyle cagiriyor; fark
    ONCESINDE. Mobil diyalogu bir blogun ICINDEN aciyor (blok kaydi
    `POST /blocks` ile zaten acilmis), web ise blok adini SERBEST METIN
    yazdirip dogrudan buraya gonderiyordu — `building_block` satiri hic
    olusmuyordu.

    `unit.blok` ZAYIF bir metin bagidir (hard FK YOK ve bu bilincli:
    blok-suz ve blok-tabanli siteler birlikte desteklenir, bkz. goc
    0001). Kaydi olmayan bir etiket bu yuzden "gecerli ama yonetilemez"
    bir ara duruma dusuyordu: editor `block.id` olmadan Duzenle/Sil
    dugmesi cizemez.

    ===================================================================
    NEDEN ISTEMCIDE DEGIL BURADA DUZELTILDI
    ===================================================================
    Web'i mobile benzetmek ORNEGI duzeltirdi, SINIFI degil. Ayni delige
    ice aktarim, dogrudan API kullanan bir musteri ve ileride yazilacak
    her yeni ekran duserdi — ve dustugunde yine sessiz olurdu: istek
    201 doner, kayit "calisir" gorunur, kusur ancak editor acilinca
    fark edilir.

    KURAL SUNUCUDA: "bir daire bir bloga baglaniyorsa o blogun kaydi
    vardir." Kurali veriyi yazan yerde tutmak, onu her istemci icin bir
    kez saglar.

    ===================================================================
    NE YAPMAZ
    ===================================================================
    * Blok kaydi ZATEN varsa hicbir sey yapmaz (sorgu once bakar).
    * `kat_sayisi` DOLDURMAZ. Dairelerden turetmek yanlis olurdu:
      bodrumlu bir binada katlar -2'den baslar, yani en yuksek kat
      numarasi kat SAYISI degildir. Alan opsiyonel; uydurma bir sayi,
      kullanicinin duzeltmesi gereken sessiz bir yanlis olurdu.
    * `blok` bos ya da NULL ise hicbir sey yapmaz — blok-suz daireler
      editorde kendi kovasinda gorunur ve onlara blok UYDURMAK,
      kullanicinin gormedigi bir yapi degisikligi olurdu.
    """
    etiket = (blok or "").strip()
    if not etiket:
        return
    # `ON CONFLICT DO NOTHING`, "once bak sonra yaz" YERINE.
    #
    # Once SELECT edip sonra INSERT etmek, iki es zamanli toplu olusturma
    # arasinda bir yaris birakirdi: ikisi de "yok" gorur, ikincisi benzersiz
    # kisiti ihlal eder. O ihlali `except`te yakalayip yutmak da yetmezdi —
    # SQLAlchemy oturumu o noktada kirilir ve toparlamak icin `rollback`
    # gerekir; oysa bu fonksiyon CAGIRANIN islemi icinde calisiyor ve onun
    # o ana kadarki yazmalarini geri almaya HAKKI YOK.
    #
    # Tek ifadelik upsert yarisi veritabanina birakir: catisma sessizce
    # gecilir, islem KIRILMAZ.
    yeni_id = (
        await db.execute(
            pg_insert(BuildingBlock)
            .values(tenant_id=user.tenant_id, ad=etiket)
            .on_conflict_do_nothing(constraint="uq_building_block_tenant_ad")
            .returning(BuildingBlock.id)
        )
    ).scalar_one_or_none()
    # `None` = blok ZATEN vardi. Denetime yalnizca GERCEKTEN acilan kayit
    # yazilir; yoksa her toplu olusturma sahte bir "blok olusturuldu"
    # satiri birakirdi.
    if yeni_id is None:
        return
    await audit_user(
        db, user, Action.BLOCK_CREATE, resource_type="building_block",
        resource_id=yeni_id, meta={"otomatik": True, "kaynak": "unit"},
    )


@router.post("", response_model=UnitOut, status_code=201)
async def create_unit(
    body: UnitCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_LAYOUT_EDITOR),
) -> UnitOut:
    await _tanim_dogrula(db, body.unit_tip_id, body.unit_grup_id)
    await _blok_kaydini_gerektir(db, user, body.blok)
    obj = Unit(tenant_id=user.tenant_id, **body.model_dump(exclude_unset=True))
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "daire_no_zaten_kayitli")
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(db, user, Action.UNIT_CREATE, resource_type="unit", resource_id=obj.id)
    return (await _adlarla(db, [obj]))[0]


@router.post("/bulk", response_model=UnitBulkResult, status_code=201)
async def bulk_create_units(
    body: UnitBulkCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_LAYOUT_EDITOR),
) -> UnitBulkResult:
    """Toplu daire olustur: kat_sayisi × kat_basi_daire adet, baslangic_no'dan
    ARDISIK (kat kat dolar). no = blok varsa '{blok}-{n}' yoksa '{n}'; zaten var
    olan no'lar ATLANIR (kalanlar olusturulur). Katlar 1..kat_sayisi, sira
    1..kat_basi_daire. RBAC admin+yonetici (create ile ayni).

    (P26) `unit_tip_id` / `unit_grup_id` verilirse PARTININ TAMAMINA uygulanir:
    toplu olusturmada daire basina tip secmek anlamsizdir, bir blok genelde
    tek tiptir. Daire basi istisnalar sonradan PATCH ile duzeltilir."""
    await _tanim_dogrula(db, body.unit_tip_id, body.unit_grup_id)
    # (P167 Asama 3) BLOK KAYDI ONCE: daireler yazildiktan sonra acmak,
    # arada dusen bir istekte "kayitsiz blok" durumunu tam olarak yeniden
    # uretirdi.
    await _blok_kaydini_gerektir(db, user, body.blok)
    # Plani kur: (no, kat, sira) — kat kat, ardisik numaralandirma.
    plan: list[tuple[str, int, int]] = []
    n = body.baslangic_no
    # (P154 / Asama 5) BASLANGIC KATI: eskiden katlar HER ZAMAN 1'den
    # basliyordu ve bodrumlu bir binada kat numaralari bir kaydirmayla
    # yaziliyordu — veri binanin kendisini anlatmiyordu.
    ilk = body.baslangic_kat
    for kat in range(ilk, ilk + body.kat_sayisi):
        for sira in range(1, body.kat_basi_daire + 1):
            no = f"{body.blok}-{n}"  # blok ZORUNLU (schema) => her zaman prefix'li
            plan.append((no, kat, sira))
            n += 1

    # Zaten var olan no'lari bul (RLS -> tenant-ici); onlari atla.
    nolar = [p[0] for p in plan]
    mevcut = set(
        (await db.execute(select(Unit.no).where(Unit.no.in_(nolar)))).scalars().all()
    )

    olusturulan: list[Unit] = []
    atlanan: list[str] = []
    for no, kat, sira in plan:
        if no in mevcut:
            atlanan.append(no)
            continue
        obj = Unit(
            tenant_id=user.tenant_id, no=no, blok=body.blok, kat=kat, sira=sira,
            unit_tip_id=body.unit_tip_id, unit_grup_id=body.unit_grup_id,
            # (P193 §6) PARTI BASINA arsa payi/metrekare: tip dairelerde
            # (ayni kat plani) hepsi aynidir ve 100 daireyi tek tek
            # dolasmak gereksiz. Istisnalar sonradan
            # `PATCH /units/arsa-payi` ile duzeltilir.
            arsa_payi=body.arsa_payi, metrekare=body.metrekare,
        )
        db.add(obj)
        olusturulan.append(obj)

    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            # es zamanli baska istek ayni no'lari eklemis olabilir.
            raise APIError(409, "conflict", "daire_no_cakismasi")
        raise translate_integrity(exc)
    for obj in olusturulan:
        await db.refresh(obj)

    return UnitBulkResult(
        olusturulan=await _adlarla(db, olusturulan),
        atlanan=atlanan,
        bitis_no=body.bitis_no,
    )



# ===================== (P154 / Asama 5) TOPLU YAPI ISLEMLERI ================ #
@router.patch("/toplu", response_model=TopluIslemSonuc)
async def toplu_guncelle(
    body: UnitTopluGuncelle,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_LAYOUT_EDITOR),
) -> TopluIslemSonuc:
    """Secili dairelerin niteligini TOPLU degistirir.

    Brief: "daire numaralarini virgulle toplu secme ve secilenlerin
    niteligini toplu degistirme".

    ARALIK AYRISTIRMASI ("3,5,7-12") ARAYUZDE: ifade kullanicinin EKRANDA
    GORDUGU listeye gore anlam kazanir (suzgec acikken "7-12" baska
    daireleri gosterir). Sunucuda cozmek, istemcinin gordugu kume ile
    sunucunun anladigi kumenin ayrismasi demekti — ve yanlis daireye toplu
    islem uygulamak geri alinmasi zor bir hatadir.

    ATLANANLAR RAPORLANIR: RLS baska tenant'in kimligini zaten gostermez;
    bulunamayan kimlik SESSIZCE dusmez, sayida gorunur.
    """
    await _tanim_dogrula(db, body.unit_tip_id, body.unit_grup_id)
    alanlar = body.model_dump(exclude_unset=True, exclude={"unit_ids"})
    if not alanlar:
        raise APIError(422, "validation_error", "guncellenecek_alan_yok")

    kayitlar = (
        (await db.execute(select(Unit).where(Unit.id.in_(body.unit_ids))))
        .scalars().all()
    )
    for k in kayitlar:
        for ad, deger in alanlar.items():
            setattr(k, ad, deger)
        k.updated_at = func.now()
    await db.flush()
    await audit_user(
        db, user, Action.UNIT_UPDATE, resource_type="unit",
        meta={"adet": len(kayitlar), "alanlar": sorted(alanlar)},
    )
    bulunan = {k.id for k in kayitlar}
    return TopluIslemSonuc(
        etkilenen=len(kayitlar),
        atlanan=[str(i) for i in body.unit_ids if i not in bulunan],
    )


@router.patch("/siralama", response_model=TopluIslemSonuc)
async def siralama_guncelle(
    body: UnitSiralama,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_LAYOUT_EDITOR),
) -> TopluIslemSonuc:
    """Surukle-birak sonrasi yeni yerlesim — TEK ISTEKTE.

    Her daire icin ayri PATCH atmak, yirmi dairelik bir katta yirmi istek
    ve ARADA KESILME riski demekti: yarim uygulanmis bir siralama,
    kullanicinin gordugu duzenle veritabanindakini ayirirdi. Tek istek =
    tek islem.
    """
    harita = {s.id: s for s in body.satirlar}
    kayitlar = (
        (await db.execute(select(Unit).where(Unit.id.in_(list(harita)))))
        .scalars().all()
    )
    for k in kayitlar:
        yeni = harita[k.id]
        k.kat, k.sira = yeni.kat, yeni.sira
        k.updated_at = func.now()
    await db.flush()
    await audit_user(
        db, user, Action.UNIT_UPDATE, resource_type="unit",
        meta={"siralama": len(kayitlar)},
    )
    bulunan = {k.id for k in kayitlar}
    return TopluIslemSonuc(
        etkilenen=len(kayitlar),
        atlanan=[str(i) for i in harita if i not in bulunan],
    )


@router.post("/kat-sil", response_model=TopluSilSonuc)
async def kat_sil(
    body: KatSilIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_LAYOUT_EDITOR),
) -> TopluSilSonuc:
    """Bir katin TUM dairelerini siler.

    KAZA KORUMASI blok silmedekiyle AYNI: daireler varsa `cascade=false`
    409 doner ve UI once onay ister. Bir kati yanlislikla silmek, o kattaki
    sakinlerin, tahakkuklarin ve rezervasyonlarin da gitmesi demektir
    (DB seviyesinde ON DELETE CASCADE).
    """
    kayitlar = (
        (await db.execute(
            select(Unit).where(Unit.blok == body.blok, Unit.kat == body.kat)
        )).scalars().all()
    )
    if not kayitlar:
        raise APIError(404, "not_found", "kayit_bulunamadi")
    if not body.cascade:
        raise APIError(
            409, "conflict", "kat_silme_onayi_gerekli", kullanan=len(kayitlar)
        )
    for k in kayitlar:
        await db.delete(k)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await audit_user(
        db, user, Action.UNIT_DELETE, resource_type="unit",
        meta={"blok": body.blok, "kat": body.kat, "adet": len(kayitlar)},
    )
    return TopluSilSonuc(silinen=len(kayitlar))


@router.patch("/{unit_id}", response_model=UnitOut)
async def update_unit(
    unit_id: uuid.UUID,
    body: UnitUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_LAYOUT_EDITOR),
) -> UnitOut:
    obj = await get_or_404(db, Unit, unit_id)
    veri = body.model_dump(exclude_unset=True)
    # `null` GONDERILDIYSE siniflandirma KALDIRILIR; gonderilmediyse dokunulmaz
    # (`exclude_unset` ikisini ayirir). Dogrulama yalniz DOLU degerler icin.
    await _tanim_dogrula(db, veri.get("unit_tip_id"), veri.get("unit_grup_id"))
    for key, value in veri.items():
        setattr(obj, key, value)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "daire_no_zaten_kayitli")
        raise translate_integrity(exc)
    await db.refresh(obj)
    return (await _adlarla(db, [obj]))[0]


@router.patch("/{unit_id}/layout", response_model=UnitOut)
async def update_unit_layout(
    unit_id: uuid.UUID,
    body: UnitLayoutUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_LAYOUT_EDITOR),
) -> Unit:
    """Daire fiziksel yerlesimini (blok/kat/sira) gunceller — bina semasi girisi.
    RBAC: admin + yonetici (digerleri 403). Yerlesim anonimligi etkilemez."""
    obj = await get_or_404(db, Unit, unit_id)
    for key, value in body.model_dump(exclude_unset=True).items():
        setattr(obj, key, value)
    obj.updated_at = func.now()
    await db.flush()
    await db.refresh(obj)
    return obj


@router.delete("/{unit_id}", status_code=204)
async def delete_unit(
    unit_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_LAYOUT_EDITOR),
) -> Response:
    obj = await get_or_404(db, Unit, unit_id)
    await db.delete(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await audit_user(db, user, Action.UNIT_DELETE, resource_type="unit", resource_id=unit_id)
    return Response(status_code=204)


# ------------------------------ sakinler ----------------------------------- #
@router.get("/{unit_id}/residents", response_model=list[UnitResidentOut])
async def list_residents(
    unit_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_BAG_YONETICI),
) -> list[UnitResidentOut]:
    await get_or_404(db, Unit, unit_id)
    # (P181 Bölüm 6.1) Sakinin ADINI da getir (AppUser join) — arayüz UUID
    # yerine ad-soyad göstersin. LEFT JOIN: kullanıcı silinmişse satır düşmesin.
    rows = (
        await db.execute(
            select(UnitResident, AppUser.ad)
            .join(AppUser, AppUser.id == UnitResident.user_id, isouter=True)
            .where(UnitResident.unit_id == unit_id)
            .order_by(UnitResident.created_at)
        )
    ).all()
    out: list[UnitResidentOut] = []
    for ur, ad in rows:
        o = UnitResidentOut.model_validate(ur)
        o.user_ad = ad
        out.append(o)
    return out


async def daire_rolu_dolu_mu(
    db: AsyncSession, unit_id: uuid.UUID, rol_tipi: str | None
) -> bool:
    """(P154 / Asama 5) Bu dairede BU ROLDEN aktif bir sakin var mi?

    Kilitli kural 4 ("bir daire icin en fazla 1 hesap") ROL BASINA
    uygulanir: bir dairede en fazla bir MALIK ve bir KIRACI olabilir.

    NEDEN ROL BASINA — OLCULDU: kuralin harfi (rol'e bakmadan tek sakin)
    tam takimda 1 kirik + 104 hata uretti. Kirilan test
    `test_hedefleme_KIRACI_VAR_YOK_IKISI_BIRDEN`'di; `borclandirma.
    hedef_sec`in `kiraci_oncelikli` kurali bir dairede malik VE kiraci
    bulunabilmesi uzerine kurulu. Kerem A secenegini onayladi
    (rapor §4.47-§4.53).

    "AKTIF" olculur (`bitis IS NULL`), "hic" degil: gecmis sakinler
    sayilsaydi bir daire EL DEGISTIREMEZDI — kiraci cikip yenisi
    girdiginde daire sonsuza dek dolu gorunurdu.

    NULL'U DA BIR DEGER SAYAR ve bu, indeksten DAHA SIKI olmasinin
    bilincli sebebidir: PostgreSQL benzersiz indekslerde NULL'lari
    catistirmaz, yani `uq_unitresident_daire_rol` rolsuz iki sakini
    gecirir. Uctan gecen hicbir yazma o boslugu kullanamasin diye
    kontrol BURADA kapatiliyor. (Boslugu veritabaninda kapatmak da
    denendi: `COALESCE(rol_tipi::text,...)` IMMUTABLE degil, ayri bir
    kismi indeks ise 37 testi kirdi — goc 0049'un basligi.)

    ORTAK YARDIMCI: ayni kural hem bu router'da hem ICE AKTARIMDA
    gerekiyor; iki yere yazmak, birinde unutulmasi demekti.
    """
    kosul = (
        UnitResident.rol_tipi.is_(None)
        if rol_tipi is None
        else UnitResident.rol_tipi == rol_tipi
    )
    var = (
        await db.execute(
            select(UnitResident.id).where(
                UnitResident.unit_id == unit_id,
                UnitResident.bitis.is_(None),
                kosul,
            )
        )
    ).first()
    return var is not None


@router.post("/{unit_id}/residents", response_model=UnitResidentOut, status_code=201)
async def assign_resident(
    unit_id: uuid.UUID,
    body: ResidentAssign,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_BAG_YONETICI),
) -> UnitResident:
    await get_or_404(db, Unit, unit_id)
    target = (
        await db.execute(select(AppUser).where(AppUser.id == body.user_id))
    ).scalar_one_or_none()
    if target is None:
        raise APIError(422, "invalid_reference", "user_id_bulunamadi")
    if target.role not in ("resident", "yonetici"):
        raise APIError(422, "invalid_reference", "atanacak_kullanici_resident_olmali")
    if await daire_rolu_dolu_mu(db, unit_id, body.rol_tipi):
        raise APIError(409, "conflict", "daire_zaten_dolu")

    obj = UnitResident(
        tenant_id=user.tenant_id,
        unit_id=unit_id,
        user_id=body.user_id,
        rol_tipi=body.rol_tipi,
        baslangic=body.baslangic,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "kullanici_daireye_zaten_bagli")
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.RESIDENT_ASSIGN, resource_type="app_user",
        resource_id=body.user_id, meta={"unit_id": str(unit_id)},
    )
    return obj


@router.delete("/{unit_id}/residents/{user_id}", status_code=204)
async def remove_resident(
    unit_id: uuid.UUID,
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_BAG_YONETICI),
) -> Response:
    await get_or_404(db, Unit, unit_id)
    binding = (
        await db.execute(
            select(UnitResident).where(
                UnitResident.unit_id == unit_id,
                UnitResident.user_id == user_id,
                UnitResident.bitis.is_(None),
            )
        )
    ).scalar_one_or_none()
    if binding is None:
        raise APIError(404, "not_found", "aktif_sakin_baglantisi_yok")
    binding.bitis = datetime.now(tz=timezone.utc)
    await db.flush()
    await audit_user(
        db, user, Action.RESIDENT_UNASSIGN, resource_type="app_user",
        resource_id=user_id, meta={"unit_id": str(unit_id)},
    )
    return Response(status_code=204)
