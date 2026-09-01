"""TEK DEFTER (P192 §1) — para hareketinin TEK yazma ve TEK okuma yolu.

===========================================================================
NEDEN BU MODUL ACILDI
===========================================================================
`docs/finans-analiz.md` olcumu: para UC ayri deftere yaziliyordu ve her
ekran farkli bir deftere bakiyordu.

    Islem                     dues_payment  finansal_hareket  budget_entry
    POST /dues/payments            yazar          YAZMAZ          yazar
    POST /finans/tahsilat          YAZMAZ         yazar           YAZMAZ
    Banka eslestirme               yazar          yazar           YAZMAZ

Sonuclari sahada olculebilirdi:
  * Vezneden tahsilat girilince sakinin borcu KAPANMIYORDU (daire bakiyesi
    `dues_payment` okuyor, vezne oraya yazmiyordu).
  * `/dues/payments` ile odeme kasa bakiyesini ARTIRMIYORDU.
  * "Tahsilat orani" mobil ana ekranda `dues_payment`ten, panelde
    `finansal_hareket`ten hesaplaniyordu — AYNI metrik, IKI rakam.

===========================================================================
KARAR: TEK DOGRU KAYNAK = `finansal_hareket` (para) + `dues_assessment` (borc)
===========================================================================
Ucu arasindan `finansal_hareket` secildi cunku digerlerinin YAPAMADIGI
seyleri zaten yapiyor:

  * KASA/BANKA baglantisi var (`kasa_id`) — bakiye ondan turetiliyor.
  * APPEND-ONLY: `app_rw`nin DELETE yetkisi goc 0047'de geri alindi.
    `budget_entry` DELETE ediliyordu; para defteri silinemez olmali.
  * DUZELTME YOLU var: `ters_kayit_id` (iptal) ve `iade_edilen_id` (iade)
    ayri ayri modellenmis.
  * MERKEZI BELGE NO (`belge_no`) ve IDEMPOTENCY (`idempotency_key`,
    `idem_satir`) tasiyor.
  * ONAY DURUMU (`durum`) tasiyor.

`dues_payment` ve `budget_entry` bunlarin hicbirini birlikte tasimiyordu;
ikisi de `finansal_hareket`in EKSIK birer kopyasiydi.

BORC ayri kalir: `dues_assessment` borcun kendisidir, para hareketi
degildir. Bakiye = tahakkuk - odenen; ikisi ayri tablodan gelir ve bu
DOGRUDUR (bir borc ile onu kapatan para ayni satir degildir).

===========================================================================
"ODENEN" NASIL HESAPLANIR — TEK TANIM
===========================================================================
    odenen = SUM( isaret(yon) * tutar )
             tip IN ('tahsilat')                       -> +
             tip IN ('iade','iptal') VE ilgili satir tahsilat -> -
             durum = 'odendi' olanlar

`iade`/`iptal` satirlari kendi `unit_id`/`assessment_id` alanlarini
tasimayabilir (eski kayitlar); bu yuzden ilgili orijinal satira JOIN
edilir ve `coalesce` ile atif oradan tamamlanir. Yon uzerinden ayirt
etmek YETMEZDI: bir GELIR iptali de `cikis` yonludur ve tahsilattan
dusulseydi tahsilat toplami yanlis cikardi.

DURUM SUZGECI ZORUNLU: `bekliyor` (karttan donmemis odeme) ve
`onay_bekliyor` (onaylanmamis gider) HENUZ GERCEKLESMEMIS hareketlerdir.
Kasa bakiyesine ve tahsilata katilmalari, olmayan parayi var gostermek
olurdu (bkz. P192 §2.2).
"""
from __future__ import annotations

import uuid
from datetime import date

from sqlalchemy import Select, and_, case, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from .models import DuesAssessment, FinansalHareket, Kasa

#: GERCEKLESMIS hareket. Bakiye/tahsilat/gider toplamlarinin HEPSI bu
#: suzgeci kullanir; tek bir yerde tanimli olmasi, bir sorgunun sessizce
#: bekleyen hareketleri saymasini engeller.
GERCEKLESEN = "odendi"

#: Tahsilat toplamina giren tipler (isaret `yon`dan gelir).
_TAHSILAT_TIPLERI = ("tahsilat",)
_TERS_TIPLER = ("iade", "iptal")

#: Ilk tahsilatta acilan varsayilan kasa. Yonetici kasa acmadan tahsilat
#: girebilmeli; aksi halde "once kasa ac" adimi, tahsilatin kasaya
#: yansimamasi kadar kotu bir sonuc uretirdi (para defterde, kasa bos).
VARSAYILAN_KASA_KOD = "KASA"
VARSAYILAN_KASA_AD = "Merkez Kasa"
VARSAYILAN_BANKA_KOD = "BANKA"
VARSAYILAN_BANKA_AD = "Banka Hesabi"


def iptal_edilmis():
    """Ters kayitla IPTAL EDILMIS satirlarin kimlikleri (alt sorgu).

    Toplamlarda gerek yoktur (iptal satiri isaretiyle zaten goturur) ama
    LISTELERDE gerekir: iptal edilmis bir gideri listede birakmak,
    "silindi" denen satirin ekranda durmasi olurdu.
    """
    return (
        select(FinansalHareket.ters_kayit_id)
        .where(FinansalHareket.ters_kayit_id.isnot(None))
        .scalar_subquery()
    )


def isaret():
    """`yon` -> +1/-1 SQL ifadesi."""
    return case((FinansalHareket.yon == "giris", 1), else_=-1)


async def kasa_coz(
    db: AsyncSession,
    tenant_id: uuid.UUID,
    kasa_id: uuid.UUID | None = None,
    *,
    banka: bool = False,
) -> uuid.UUID:
    """Kasayi coz; verilmediyse varsayilani BUL ya da AC.

    `banka=True` banka hesabi ister (P192 §2.1: banka tahsilati bir BANKA
    HESABINA yazilmali, `kasa_id=NULL` ile hicbir bakiyede gorunmeyen bir
    satir olarak degil).
    """
    if kasa_id is not None:
        return kasa_id
    kod = VARSAYILAN_BANKA_KOD if banka else VARSAYILAN_KASA_KOD
    mevcut = (
        await db.execute(
            select(Kasa.id)
            .where(Kasa.aktif.is_(True), Kasa.banka_mi.is_(banka))
            .order_by(
                # Varsayilan kod once; yoksa en eski aktif kasa.
                case((Kasa.kod == kod, 0), else_=1),
                Kasa.created_at,
                Kasa.id,
            )
            .limit(1)
        )
    ).scalar_one_or_none()
    if mevcut is not None:
        return mevcut
    yeni = Kasa(
        tenant_id=tenant_id,
        kod=kod,
        ad=VARSAYILAN_BANKA_AD if banka else VARSAYILAN_KASA_AD,
        banka_mi=banka,
    )
    db.add(yeni)
    await db.flush()
    return yeni.id


# --------------------------------------------------------------------------- #
#                                  OKUMA                                       #
# --------------------------------------------------------------------------- #
def tahsilat_etkisi() -> Select:
    """Tahsilat etkisi olan satirlar: (unit_id, assessment_id, user_id,
    donem, tarih, etki).

    Modul belgesindeki "ODENEN" tanimini SQL'e ceviren TEK yer.
    """
    orj = aliased(FinansalHareket)
    ilgili = func.coalesce(
        FinansalHareket.iade_edilen_id, FinansalHareket.ters_kayit_id
    )
    return (
        select(
            func.coalesce(FinansalHareket.unit_id, orj.unit_id).label("unit_id"),
            func.coalesce(
                FinansalHareket.assessment_id, orj.assessment_id
            ).label("assessment_id"),
            func.coalesce(FinansalHareket.user_id, orj.user_id).label("user_id"),
            func.coalesce(FinansalHareket.donem, orj.donem).label("donem"),
            FinansalHareket.tarih.label("tarih"),
            (isaret() * FinansalHareket.tutar_kurus).label("etki"),
        )
        .outerjoin(orj, orj.id == ilgili)
        .where(
            FinansalHareket.durum == GERCEKLESEN,
            or_(
                FinansalHareket.tip.in_(_TAHSILAT_TIPLERI),
                and_(
                    FinansalHareket.tip.in_(_TERS_TIPLER),
                    orj.tip.in_(_TAHSILAT_TIPLERI),
                ),
            ),
        )
    )


async def daire_odenen(
    db: AsyncSession,
    unit_ids: list[uuid.UUID] | None = None,
    *,
    donem: str | None = None,
) -> dict[uuid.UUID, int]:
    """Daire basina odenen tutar (kurus). Odemesi olmayan daire SOZLUKTE YOK."""
    alt = tahsilat_etkisi().subquery()
    stmt = select(alt.c.unit_id, func.sum(alt.c.etki)).where(
        alt.c.unit_id.isnot(None)
    )
    if unit_ids is not None:
        if not unit_ids:
            return {}
        stmt = stmt.where(alt.c.unit_id.in_(unit_ids))
    if donem is not None:
        stmt = stmt.where(alt.c.donem == donem)
    rows = (await db.execute(stmt.group_by(alt.c.unit_id))).all()
    return {uid: int(toplam) for uid, toplam in rows}


async def tahakkuk_odenen(
    db: AsyncSession, assessment_ids: list[uuid.UUID] | None = None
) -> dict[uuid.UUID, int]:
    """Tahakkuk basina odenen tutar (kurus) — FIFO mahsubunun kaynagi."""
    alt = tahsilat_etkisi().subquery()
    stmt = select(alt.c.assessment_id, func.sum(alt.c.etki)).where(
        alt.c.assessment_id.isnot(None)
    )
    if assessment_ids is not None:
        if not assessment_ids:
            return {}
        stmt = stmt.where(alt.c.assessment_id.in_(assessment_ids))
    rows = (await db.execute(stmt.group_by(alt.c.assessment_id))).all()
    return {aid: int(toplam) for aid, toplam in rows}


async def tahsilat_toplami(
    db: AsyncSession,
    *,
    donem: str | None = None,
    baslangic: date | None = None,
    bitis: date | None = None,
    unit_id: uuid.UUID | None = None,
    user_id: uuid.UUID | None = None,
) -> int:
    """Tahsilat toplami (kurus) — TEK KAYNAK.

    "Tahsilat orani" hesaplayan HER ekran bunu cagirir: rapor, panel ozeti,
    seffaflik, mobil ana ekran. Iki ekranin iki rakam gostermesinin kok
    nedeni, bu toplamin iki ayri yerde iki ayri tablodan hesaplanmasiydi.

    `donem` MUHASEBE DONEMIDIR (tahsilatin atfedildigi ay), `baslangic`/
    `bitis` ise ISLEM TARIHIDIR. Ikisi ayni sey degildir: Ocak aidatinin
    tahsilati Subat'ta yapilabilir.
    """
    alt = tahsilat_etkisi().subquery()
    where = []
    if donem is not None:
        where.append(alt.c.donem == donem)
    if baslangic is not None:
        where.append(alt.c.tarih >= baslangic)
    if bitis is not None:
        where.append(alt.c.tarih <= bitis)
    if unit_id is not None:
        where.append(alt.c.unit_id == unit_id)
    if user_id is not None:
        where.append(alt.c.user_id == user_id)
    toplam = (
        await db.execute(
            select(func.coalesce(func.sum(alt.c.etki), 0)).where(*where)
        )
    ).scalar_one()
    return int(toplam)


async def daire_bakiye(
    db: AsyncSession, unit_ids: list[uuid.UUID]
) -> dict[uuid.UUID, tuple[int, int]]:
    """Daire basina (tahakkuk, odenen) kurus ikilisi.

    Bakiye = tahakkuk - odenen; cagirana cikarma birakilir cunku bazi
    ekranlar iki bileseni AYRI gosterir.
    """
    if not unit_ids:
        return {}
    tahakkuk_rows = (
        await db.execute(
            select(
                DuesAssessment.unit_id,
                func.coalesce(func.sum(DuesAssessment.tutar_kurus), 0),
            )
            .where(DuesAssessment.unit_id.in_(unit_ids))
            .group_by(DuesAssessment.unit_id)
        )
    ).all()
    tahakkuk = {uid: int(t) for uid, t in tahakkuk_rows}
    odenen = await daire_odenen(db, unit_ids)
    return {
        uid: (tahakkuk.get(uid, 0), odenen.get(uid, 0)) for uid in unit_ids
    }


async def hareket_toplami(
    db: AsyncSession,
    tip: str,
    *,
    baslangic: date | None = None,
    bitis: date | None = None,
    durum: str | None = GERCEKLESEN,
) -> int:
    """Bir hareket tipinin ISARETLI toplami (iptal/iade dusulmus).

    Gelir/gider toplamlari da tahsilat gibi TEK yerden okunur: `budget_entry`
    ayri bir gider defteri tutarken seffaflik raporu ile finans ozeti ayni
    ayda farkli gider gosterebiliyordu.
    """
    orj = aliased(FinansalHareket)
    ilgili = func.coalesce(
        FinansalHareket.iade_edilen_id, FinansalHareket.ters_kayit_id
    )
    where = [
        or_(
            FinansalHareket.tip == tip,
            and_(FinansalHareket.tip.in_(_TERS_TIPLER), orj.tip == tip),
        )
    ]
    if durum is not None:
        where.append(FinansalHareket.durum == durum)
    if baslangic is not None:
        where.append(FinansalHareket.tarih >= baslangic)
    if bitis is not None:
        where.append(FinansalHareket.tarih <= bitis)
    toplam = (
        await db.execute(
            select(
                func.coalesce(
                    func.sum(isaret() * FinansalHareket.tutar_kurus), 0
                )
            )
            .select_from(FinansalHareket)
            .outerjoin(orj, orj.id == ilgili)
            .where(*where)
        )
    ).scalar_one()
    # GIDER/GELIR toplami MUTLAK deger olarak okunur: bir gider "eksi para"
    # degil, "harcanan para"dir. Isaret yalnizca iptal/iadeyi DUSMEK icin
    # kullanildi.
    return abs(int(toplam))


#: Deftere gelir olarak yansiyan tipler. AIDAT TAHSILATI DA GELIRDIR:
#: eskiden `budget_entry`e `kaynak='aidat_odeme'` satiri olarak yaziliyordu
#: ve seffaflik raporunun "toplam gelir"i onu iceriyordu. Tek deftere
#: gecerken bu davranis KORUNDU; disarida biraksaydik sitenin geliri bir
#: gecede aidat kadar dusuk gorunurdu.
GELIR_TIPLERI = ("gelir", "tahsilat")

#: Kategorisiz hareketlerin rapor basligi.
KATEGORISIZ = "Diğer"


async def gelir_toplami(
    db: AsyncSession,
    *,
    baslangic: date | None = None,
    bitis: date | None = None,
) -> int:
    toplam = 0
    for tip in GELIR_TIPLERI:
        toplam += await hareket_toplami(
            db, tip, baslangic=baslangic, bitis=bitis
        )
    return toplam


async def gider_toplami(
    db: AsyncSession,
    *,
    baslangic: date | None = None,
    bitis: date | None = None,
) -> int:
    return await hareket_toplami(db, "gider", baslangic=baslangic, bitis=bitis)


async def gider_kategori_kirilimi(
    db: AsyncSession,
    *,
    baslangic: date | None = None,
    bitis: date | None = None,
    limit: int | None = None,
) -> list[tuple[str, int]]:
    """Gider toplaminin kategori kirilimi — (ad, kurus), buyukten kucuge.

    IKI TAKSONOMI VAR ve ikisi de gecerlidir: `budget_category` (butce
    modulu) ve `gelir_gider_tanim` (P27 muhasebe tanimlari). Defter
    birlestirildiginde ikisini TEK bir yeni taksonomiye zorlamak, gecmis
    kayitlarin kategorisini kaybetmek olurdu; bu yuzden ad `coalesce` ile
    hangisi doluysa oradan okunur.
    """
    from .models import BudgetCategory, GelirGiderTanim  # dairesel import yok

    ad = func.coalesce(BudgetCategory.ad, GelirGiderTanim.ad, KATEGORISIZ)
    where = [
        FinansalHareket.tip == "gider",
        FinansalHareket.durum == GERCEKLESEN,
        # Iptal EDILMIS gider kategori kiriliminda gorunmemeli; iptal
        # satirinin kendisi de (tip='iptal') zaten disarida.
        FinansalHareket.ters_kayit_id.is_(None),
    ]
    if baslangic is not None:
        where.append(FinansalHareket.tarih >= baslangic)
    if bitis is not None:
        where.append(FinansalHareket.tarih <= bitis)
    where.append(FinansalHareket.id.notin_(iptal_edilmis()))
    stmt = (
        select(ad, func.sum(FinansalHareket.tutar_kurus))
        .select_from(FinansalHareket)
        .outerjoin(
            BudgetCategory,
            BudgetCategory.id == FinansalHareket.budget_category_id,
        )
        .outerjoin(
            GelirGiderTanim,
            GelirGiderTanim.id == FinansalHareket.gelir_gider_tanim_id,
        )
        .where(*where)
        .group_by(ad)
        # (P108) Kararli kuyruk GRUPLAMA ANAHTARIDIR: esit tutarli iki
        # kategori her kosumda ayni sirada gelir.
        .order_by(func.sum(FinansalHareket.tutar_kurus).desc(), ad)
    )
    if limit is not None:
        stmt = stmt.limit(limit)
    return [(k, int(t)) for k, t in (await db.execute(stmt)).all()]


#: Aidat tahsilatlarinin butce kirilimindeki kategori adi. Kategori
#: `budget_category`de yasar: aidat geliri butce raporunda "Aidat" olarak
#: gorunmeye devam etsin diye (eskiden `ensure_dues_income_entry` ayni adi
#: kullaniyordu). Kategori olmasa satirlar "kategorisiz" dusup butce
#: kirilimini bosaltirdi.
AIDAT_KATEGORI_AD = "Aidat"


async def aidat_kategori_id(db: AsyncSession, tenant_id: uuid.UUID) -> uuid.UUID:
    """'Aidat' gelir kategorisini bul ya da ac (get-or-create)."""
    from .models import BudgetCategory

    mevcut = (
        await db.execute(
            select(BudgetCategory.id).where(
                BudgetCategory.ad == AIDAT_KATEGORI_AD,
                BudgetCategory.tip == "gelir",
            )
        )
    ).scalar_one_or_none()
    if mevcut is not None:
        return mevcut
    yeni = BudgetCategory(
        tenant_id=tenant_id, ad=AIDAT_KATEGORI_AD, tip="gelir"
    )
    db.add(yeni)
    await db.flush()
    return yeni.id


def donem_araligi(donem: str) -> tuple[date, date]:
    """'YYYY-MM' -> (ayin ilk gunu, ayin son gunu). Bicim hatasi -> 422."""
    import calendar

    from .errors import APIError

    try:
        y, m = donem.split("-")
        yil, ay = int(y), int(m)
        ilk = date(yil, ay, 1)
    except (ValueError, TypeError):
        raise APIError(422, "validation_error", "donem_bicimi")
    return ilk, date(yil, ay, calendar.monthrange(yil, ay)[1])
