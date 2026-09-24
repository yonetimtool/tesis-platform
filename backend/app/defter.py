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


def gecerli_tahakkuk() -> list:
    """GECERLI borc kosullari — ters kayit CIFTI disarida (P192 §6.3).

    TEK KURAL, TEK YER: "ters kayitlanmis bir tahakkuk da, onu goturen
    ters kayit satiri da BORC DEGILDIR". Ikisi de listelerden ve
    toplamlardan cikar; toplamlari zaten sifir oldugu icin sonuc, iki
    satiri isaretli toplamakla AYNIDIR — ama listelerde de dogru davranir
    (isaretli toplam, listede birbirini goturen iki satir birakirdi ve
    "toplam neden satirlari tutmuyor" sorusu dogardi).

    Duzeltmenin izi KAYBOLMAZ: satirlar tabloda durur ve denetim kaydi
    (`audit_log`) hangi tahakkukun neden duzeltildigini tasir.

    `iptal_edildi` bayragi ALT SORGU YERINE kullaniliyor: ayni kosul kismi
    tekillik indeksinde de gerekiyor ve orada alt sorgu YAZILAMAZ. Iki
    yerde iki farkli tanim olmasin diye tek bayrak.
    """
    return [
        DuesAssessment.ters_kayit_id.is_(None),
        DuesAssessment.iptal_edildi.is_(False),
    ]


def tahakkuk_etkisi() -> Select:
    """Gecerli tahakkuklar: (unit_id, donem, kalem_tipi, hedef_user_id,
    tarih, etki)."""
    return select(
        DuesAssessment.unit_id.label("unit_id"),
        DuesAssessment.donem.label("donem"),
        DuesAssessment.kalem_tipi.label("kalem_tipi"),
        DuesAssessment.hedef_user_id.label("hedef_user_id"),
        DuesAssessment.tarih.label("tarih"),
        DuesAssessment.tutar_kurus.label("etki"),
    ).where(*gecerli_tahakkuk())


async def tahakkuk_toplami(
    db: AsyncSession,
    *,
    donem: str | None = None,
    unit_ids: list[uuid.UUID] | None = None,
    baslangic: date | None = None,
    bitis: date | None = None,
) -> int:
    """Tahakkuk toplami (kurus) — ters kayitlar DUSULMUS."""
    alt = tahakkuk_etkisi().subquery()
    where = []
    if donem is not None:
        where.append(alt.c.donem == donem)
    if unit_ids is not None:
        if not unit_ids:
            return 0
        where.append(alt.c.unit_id.in_(unit_ids))
    if baslangic is not None:
        where.append(alt.c.tarih >= baslangic)
    if bitis is not None:
        where.append(alt.c.tarih <= bitis)
    toplam = (
        await db.execute(
            select(func.coalesce(func.sum(alt.c.etki), 0)).where(*where)
        )
    ).scalar_one()
    return int(toplam)


async def daire_tahakkuk(
    db: AsyncSession,
    unit_ids: list[uuid.UUID] | None = None,
    *,
    donem: str | None = None,
) -> dict[uuid.UUID, int]:
    """Daire basina tahakkuk (kurus). Tahakkuku olmayan daire SOZLUKTE YOK."""
    alt = tahakkuk_etkisi().subquery()
    stmt = select(alt.c.unit_id, func.sum(alt.c.etki))
    if unit_ids is not None:
        if not unit_ids:
            return {}
        stmt = stmt.where(alt.c.unit_id.in_(unit_ids))
    if donem is not None:
        stmt = stmt.where(alt.c.donem == donem)
    rows = (await db.execute(stmt.group_by(alt.c.unit_id))).all()
    return {uid: int(t) for uid, t in rows}


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


async def _acik_kalem_odenen(
    db: AsyncSession, assessment_ids: list[uuid.UUID] | None
) -> dict[uuid.UUID, int]:
    """Yalniz KALEME BAGLI (`assessment_id` tasiyan) tahsilatlarin toplami."""
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


def fifo_sirasi(a: DuesAssessment) -> tuple:
    """Kalemlerin MAHSUP SIRASI: once vadesi en eski olan kapanir.

    Vadesiz kalem kendi islem tarihiyle siralanir; esitlikte donem, sonra
    kayit ani ve kimlik (kararli sira — iki kosum ayni dagilimi uretir).
    """
    return (
        a.son_odeme_tarihi or a.tarih or date.max,
        a.donem or "",
        a.created_at.isoformat() if a.created_at else "",
        str(a.id),
    )


async def tahakkuk_odenen(
    db: AsyncSession,
    assessment_ids: list[uuid.UUID] | None = None,
    *,
    fifo: bool = True,
) -> dict[uuid.UUID, int]:
    """Tahakkuk basina odenen tutar (kurus) — KALEM DUZEYINDEKI TEK TANIM.

    (E2E 2026-09, FINANS-04) KALEMSIZ TAHSILAT DA KALEMLERE DAGITILIR.
    Onceden kalem duzeyinde "odenen" yalniz `assessment_id` tasiyan
    tahsilatlardan hesaplaniyordu; web vezne formu kalem GONDERMEDIGI
    icin daire duzeyinde TAMAMEN odenmis bir borc gecikme faizi aldi,
    yaslandirmada "61-90 gun" kovasinda durdu ve banka eslestirmesi onu
    acik sayip malikin parasini kiracinin (odenmis) aidatina yazdi.

    Dagitim HESAPLANIR, YAZILMAZ: kalemsiz tahsilat satiri oldugu gibi
    kalir, her okumada daire icinde FIFO (`fifo_sirasi`) ile kalemlere
    mahsup edilir. Boylece gecmis kayitlar da goc gerekmeden duzelir ve
    daire bakiyesi (`daire_odenen`, net) ile kalem toplami AYNI parayi
    anlatir.

    Dagitim kurali (daire basina):
      1. Kaleme bagli tahsilat once KENDI kalemini kapatir; kalem tutarini
         asan kismi (fazla odeme) daire havuzuna duser.
      2. Kalemsiz tahsilat ODEYEN kisiye gore gruplanir; kisinin havuzu
         once KENDISINE ya da daireye (hedefsiz) yazilmis kalemleri, sonra
         dairenin kalan kalemlerini kapatir. Kisisiz havuz en son, FIFO.
      3. Havuzlarin NET toplami (iade/iptal dusulmus) asilamaz.

    `fifo=False`: yalniz kaleme bagli tahsilatlar (ters kayit / faiz affi
    gibi "bu kaleme DOGRUDAN para yazildi mi" sorusu icin).
    """
    if not fifo:
        return await _acik_kalem_odenen(db, assessment_ids)
    if assessment_ids is not None and not assessment_ids:
        return {}

    # Kapsam DAIRE: istenen kalemlerin daireleri. FIFO daire icinde
    # calistigi icin istenmeyen komsu kalemler de hesaba girmek ZORUNDA
    # (daha eski bir kalem parayi once o yer).
    k_stmt = select(DuesAssessment).where(*gecerli_tahakkuk())
    if assessment_ids is not None:
        daireler = select(DuesAssessment.unit_id).where(
            DuesAssessment.id.in_(assessment_ids)
        )
        k_stmt = k_stmt.where(DuesAssessment.unit_id.in_(daireler))
    kalemler = list((await db.execute(k_stmt)).scalars().all())
    if not kalemler:
        # Gecerli olmayan (ters kayitli) kalemler icin eski tanim.
        return await _acik_kalem_odenen(db, assessment_ids)

    unit_idler = list({k.unit_id for k in kalemler})
    acik = await _acik_kalem_odenen(db, [k.id for k in kalemler])

    alt = tahsilat_etkisi().subquery()
    havuz_rows = (
        await db.execute(
            select(alt.c.unit_id, alt.c.user_id, func.sum(alt.c.etki))
            .where(alt.c.assessment_id.is_(None), alt.c.unit_id.in_(unit_idler))
            .group_by(alt.c.unit_id, alt.c.user_id)
        )
    ).all()
    havuzlar: dict[uuid.UUID, list[tuple[uuid.UUID | None, int]]] = {}
    for uid, kisi, toplam in havuz_rows:
        havuzlar.setdefault(uid, []).append((kisi, int(toplam)))

    daire_kalemleri: dict[uuid.UUID, list[DuesAssessment]] = {}
    for k in kalemler:
        daire_kalemleri.setdefault(k.unit_id, []).append(k)

    sonuc: dict[uuid.UUID, int] = {}
    for uid, liste in daire_kalemleri.items():
        liste.sort(key=fifo_sirasi)
        kalan: dict[uuid.UUID, int] = {}
        fazla = 0
        for k in liste:
            dogrudan = acik.get(k.id, 0)
            kapanan = min(max(dogrudan, 0), k.tutar_kurus)
            sonuc[k.id] = kapanan
            kalan[k.id] = k.tutar_kurus - kapanan
            fazla += max(dogrudan - k.tutar_kurus, 0)
        gruplar = havuzlar.get(uid, [])
        butce = fazla + sum(t for _, t in gruplar)
        if butce <= 0:
            continue
        # Kisili havuzlar once (kendi kalemlerine), kisisiz ve fazla odeme
        # en son. Sira kararli: kisi kimligine gore.
        sirali = sorted(
            [(kisi, t) for kisi, t in gruplar if t > 0 and kisi is not None],
            key=lambda g: str(g[0]),
        )
        kisisiz = sum(t for kisi, t in gruplar if t > 0 and kisi is None) + fazla
        if kisisiz > 0:
            sirali.append((None, kisisiz))
        for kisi, tutar in sirali:
            tutar = min(tutar, butce)
            if tutar <= 0:
                break
            butce -= tutar
            oncelikli = [
                k for k in liste
                if kisi is not None
                and (k.hedef_user_id == kisi or k.hedef_user_id is None)
            ]
            for k in oncelikli + [k for k in liste if k not in oncelikli]:
                if tutar <= 0:
                    break
                pay = min(kalan[k.id], tutar)
                if pay <= 0:
                    continue
                kalan[k.id] -= pay
                sonuc[k.id] += pay
                tutar -= pay

    if assessment_ids is not None:
        istenen = set(assessment_ids)
        sonuc = {aid: t for aid, t in sonuc.items() if aid in istenen}
        # Ters kayitli (gecerli olmayan) istenen kalemler eski tanimla.
        eksik = [aid for aid in assessment_ids if aid not in sonuc]
        if eksik:
            sonuc.update(await _acik_kalem_odenen(db, eksik))
    return {aid: t for aid, t in sonuc.items() if t}


async def kalem_kalanlari(
    db: AsyncSession, kalemler: list[DuesAssessment]
) -> dict[uuid.UUID, int]:
    """Kalem basina KALAN borc (kurus, >= 0) — FIFO dagitimli."""
    if not kalemler:
        return {}
    odenen = await tahakkuk_odenen(db, [k.id for k in kalemler])
    return {
        k.id: max(k.tutar_kurus - odenen.get(k.id, 0), 0) for k in kalemler
    }


async def donem_tahsil_edilen(
    db: AsyncSession, *, donem: str | None = None
) -> dict[str, int]:
    """Donem basina TAHSIL EDILMIS BORC (kurus) — TAHSILAT ORANININ PAYI.

    (E2E 2026-09, FINANS-07) Tahsilat orani onceden
    `tahsilat_toplami(donem=...)` ile hesaplaniyordu: yani tahsilat
    SATIRININ `donem` alanina bakiyordu. Web vezne formu ve kalemsiz
    `/dues/payments` donem YAZMADIGI icin Eylul'un 18 tahsilatindan 15'i
    hicbir doneme girmedi; gosterge ve SAKINE yayinlanan seffaflik %3
    diyordu (gercek ~%28), "odeyen daire 0".

    Artik oranin payi "o donemin kalemlerinden ne kadari kapandi"dir —
    kalem duzeyindeki TEK tanimdan (FIFO dahil). Tahsilat satirinin
    donem alani dolu olsa da olmasa da AYNI sonucu verir ve oran %100'u
    asamaz. Gosterge, seffaflik ve Tahsilat Performansi raporu bunu
    cagirir.
    """
    where = list(gecerli_tahakkuk())
    if donem is not None:
        where.append(DuesAssessment.donem == donem)
    kalemler = list(
        (await db.execute(select(DuesAssessment).where(*where))).scalars().all()
    )
    if not kalemler:
        return {}
    odenen = await tahakkuk_odenen(db, [k.id for k in kalemler])
    sonuc: dict[str, int] = {}
    for k in kalemler:
        sonuc[k.donem] = sonuc.get(k.donem, 0) + min(
            odenen.get(k.id, 0), k.tutar_kurus
        )
    return sonuc


async def acik_borc_toplami(db: AsyncSession) -> int:
    """TESISIN ACIK BORCU (kurus) — daire bakiyelerinin toplami.

    (E2E 2026-09, FINANS-06) Ayni ad ("acik borc") dort ekranda dort
    rakamdi. Tanim: her dairenin `tahakkuk - odenen` bakiyesi, ALACAKLI
    daire SIFIR sayilarak toplanir — bir dairenin fazla odemesi baska
    dairenin borcunu kapatmaz. Daireye baglanmamis tahsilat (unit_id
    NULL) hicbir dairenin borcunu kapatmadigi icin buraya da girmez.
    """
    tahakkuk = await daire_tahakkuk(db)
    if not tahakkuk:
        return 0
    odenen = await daire_odenen(db, list(tahakkuk))
    return sum(max(t - odenen.get(uid, 0), 0) for uid, t in tahakkuk.items())


async def kalemsiz_tahsilat_donemi(
    db: AsyncSession, unit_id: uuid.UUID | None, tarih: date | None
) -> str:
    """Kaleme baglanmamis tahsilatin MUHASEBE DONEMI.

    (E2E 2026-09, FINANS-07) Donemsiz tahsilat donem bazli listelerde ve
    `/dues/payments?donem=` suzgecinde kayboluyordu. Donem, dairenin FIFO
    ile ilk kapanacak ACIK kaleminin donemidir; acik kalem yoksa (pesin /
    fazla odeme) islem tarihinin ayidir.
    """
    if unit_id is not None:
        kalemler = list(
            (
                await db.execute(
                    select(DuesAssessment).where(
                        DuesAssessment.unit_id == unit_id, *gecerli_tahakkuk()
                    )
                )
            ).scalars().all()
        )
        kalan = await kalem_kalanlari(db, kalemler)
        for k in sorted(kalemler, key=fifo_sirasi):
            if kalan.get(k.id, 0) > 0:
                return k.donem
    gun = tarih or date.today()
    return f"{gun.year}-{gun.month:02d}"


async def tahsilat_dairesi_coz(
    db: AsyncSession,
    *,
    unit_id: uuid.UUID | None,
    user_id: uuid.UUID | None,
    assessment_id: uuid.UUID | None = None,
) -> uuid.UUID | None:
    """Tahsilatin DAIRESI — verilmediyse kalemden ya da kisiden cozulur.

    (E2E 2026-09, FINANS-01) Daire secilmeden alinan tahsilat (web "pesin
    odeme" kutusu, borclu listesinden gelip daireyi bosaltmak, mobil
    `unit_id` opsiyonel) `unit_id=NULL` yaziliyordu: para kasaya girdi ama
    HICBIR dairenin borcu kapanmadi, sakin borcunu hala gordu.

    KARAR: sessizce tahmin YOK.
      * kalem verilmisse daire kalemin dairesidir,
      * kisinin TEK aktif dairesi varsa o daire,
      * kisinin birden cok aktif dairesi varsa 422 — secim zorunlu (yanlis
        dairenin borcunu kapatmak, dogru dairenin borcunu acik birakirdi),
      * kisi de daire de yoksa daireye bagli OLMAYAN tahsilat serbesttir
        (ornegin kira/baz istasyonu tahsilati) ve NULL kalir.
    """
    from .errors import APIError
    from .models import UnitResident

    if unit_id is not None:
        return unit_id
    if assessment_id is not None:
        kalem_daire = (
            await db.execute(
                select(DuesAssessment.unit_id).where(
                    DuesAssessment.id == assessment_id
                )
            )
        ).scalar_one_or_none()
        if kalem_daire is not None:
            return kalem_daire
    if user_id is None:
        return None
    daireler = list(
        dict.fromkeys(
            (
                await db.execute(
                    select(UnitResident.unit_id).where(
                        UnitResident.user_id == user_id,
                        UnitResident.bitis.is_(None),
                    )
                )
            ).scalars().all()
        )
    )
    if len(daireler) == 1:
        return daireler[0]
    if len(daireler) > 1:
        raise APIError(422, "validation_error", "tahsilat_daire_secilmeli")
    return None


# --------------------------------------------------------------------------- #
#                 (E2E 2026-09) SAKININ GORDUGU BORC — TEK TANIM              #
# --------------------------------------------------------------------------- #
async def sakin_kalemleri(
    db: AsyncSession, user_id: uuid.UUID
) -> list[tuple[DuesAssessment, int]]:
    """Sakinin GORDUGU borc kalemleri ve her birinin KALANI (kurus).

    (E2E 2026-09, YETKI-06 / TESIS-08 / FINANS-19) Iki sakin ucu iki ayri
    borc anlatiyordu: `/me/dues` dairenin TUM kalemlerini (malikin
    demirbasi dahil, onceki sakinin borcu dahil) gosterirken
    `/me/odeme-bilgileri` P218 kuralini uyguluyordu. Ayrilan sakin kendi
    borcunu hic goremiyordu. Artik IKI UC DA bunu cagirir.

    Kural:
      * HEDEFI BEN olan kalem — daire bagim bitmis olsa bile (ayrilan
        sakinin borcu kendisinde kalir, yeni sakine gecmez).
      * HEDEFSIZ (daireye yazilmis) kalem — yalniz AKTIF daire bagimda:
          - kiraci icin tanimi `malik` diyen kalem gorunmez (P218 §D),
            tanimsiz eski kalemler gorunur.
          - BAG BASLANGICINA GORE SUZULMEZ (bilincli): `baslangic` kaydin
            acildigi andir, tasinma tarihi degil; ice aktarilan sakinin
            eski hedefsiz aidatini gizlemek odenmesi gereken borcu
            saklamak olurdu. Onceki sakinin borcu zaten HEDEFLIDIR (P28)
            ve yukaridaki kuralla ona kalir.
      * Baskasina hedeflenmis kalem GORUNMEZ.
    Kalan FIFO dagitimli kalem duzeyindeki tanimdan (`tahakkuk_odenen`).
    """
    from .models import GelirGiderTanim, UnitResident

    baglar = (
        await db.execute(
            select(UnitResident.unit_id, UnitResident.rol_tipi).where(
                UnitResident.user_id == user_id, UnitResident.bitis.is_(None)
            )
        )
    ).all()
    kosul = DuesAssessment.hedef_user_id == user_id
    if baglar:
        malik_tanimlari = select(GelirGiderTanim.id).where(
            GelirGiderTanim.hedef_kurali == "malik"
        )
        for unit_id, rol in baglar:
            daire_kosulu = and_(
                DuesAssessment.unit_id == unit_id,
                DuesAssessment.hedef_user_id.is_(None),
            )
            if rol == "kiraci":
                # `NULL NOT IN (...)` SQL'de NULL'dur ve satiri ELER;
                # tanimsiz kalem ACIKCA dahil (YETKI-07).
                daire_kosulu = and_(
                    daire_kosulu,
                    or_(
                        DuesAssessment.gelir_gider_tanim_id.is_(None),
                        DuesAssessment.gelir_gider_tanim_id.notin_(
                            malik_tanimlari
                        ),
                    ),
                )
            kosul = or_(kosul, daire_kosulu)
    kalemler = list(
        (
            await db.execute(
                select(DuesAssessment).where(kosul, *gecerli_tahakkuk())
            )
        ).scalars().all()
    )
    kalemler.sort(key=fifo_sirasi)
    kalan = await kalem_kalanlari(db, kalemler)
    return [(k, kalan.get(k.id, 0)) for k in kalemler]


async def sakin_borc_kurus(db: AsyncSession, user_id: uuid.UUID) -> int:
    """Sakinin ACIK borcu — `sakin_kalemleri`nin kalan toplami."""
    return sum(k for _, k in await sakin_kalemleri(db, user_id))


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
    tahakkuk = await daire_tahakkuk(db, unit_ids)
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
    # GIDER "harcanan para"dir ve POZITIF okunur: gider `cikis` oldugu icin
    # isaret cevrilir. (E2E 2026-09, FINANS-11) `abs` KULLANILMAZ: yalniz
    # onceki ayin giderinin iptalini tasiyan bir ayda net NEGATIFTIR ve
    # `abs` onu "gider" diye POZITIF gosteriyordu (kirilimla da tutmuyordu).
    return (-1 if tip == "gider" else 1) * int(toplam)


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
    return await kategori_kirilimi(
        db, ("gider",), baslangic=baslangic, bitis=bitis, limit=limit
    )


async def kategori_kirilimi(
    db: AsyncSession,
    tipler: tuple[str, ...],
    *,
    baslangic: date | None = None,
    bitis: date | None = None,
    limit: int | None = None,
) -> list[tuple[str, int]]:
    """Gelir ya da gider toplaminin kategori kirilimi — (ad, kurus).

    (E2E 2026-09, FINANS-11) KIRILIMIN TOPLAMI = `hareket_toplami`.
    Onceden kirilim "iptal EDILMIS satiri disla" kuraliyla, toplam ise
    "iptal satirini isaretiyle dus" kuraliyla hesaplaniyordu; Agustos'ta
    girilip Eylul'de iptal edilen bir gider iki rakami ayirdi ve sakine
    yayinlanan gider dagiliminin yuzdeleri %116 tuttu. Artik AYNI kural:
    orijinal satir + ters satirlar (iade/iptal) isaretiyle, TERS SATIRIN
    tarihinde. Ters satir kategoriyi orijinalden alir.
    """
    from .models import BudgetCategory, GelirGiderTanim  # dairesel import yok

    orj = aliased(FinansalHareket)
    ilgili = func.coalesce(
        FinansalHareket.iade_edilen_id, FinansalHareket.ters_kayit_id
    )
    kat_id = func.coalesce(
        FinansalHareket.budget_category_id, orj.budget_category_id
    )
    tanim_id = func.coalesce(
        FinansalHareket.gelir_gider_tanim_id, orj.gelir_gider_tanim_id
    )
    ad = func.coalesce(BudgetCategory.ad, GelirGiderTanim.ad, KATEGORISIZ)
    where = [
        FinansalHareket.durum == GERCEKLESEN,
        or_(
            FinansalHareket.tip.in_(tipler),
            and_(FinansalHareket.tip.in_(_TERS_TIPLER), orj.tip.in_(tipler)),
        ),
    ]
    if baslangic is not None:
        where.append(FinansalHareket.tarih >= baslangic)
    if bitis is not None:
        where.append(FinansalHareket.tarih <= bitis)
    # Gider "cikis"tir: isaret ceviriciyle POZITIF okunur. `abs` KULLANILMAZ:
    # yalniz iptali dusen (net eksi) bir kategori, toplami dusururken
    # kirilimi ARTIRIRDI ve kirilim toplami yine tutmazdi.
    carpan = -1 if set(tipler) <= {"gider"} else 1
    isaretli = carpan * isaret() * FinansalHareket.tutar_kurus
    toplam = func.sum(isaretli)
    stmt = (
        select(ad, toplam)
        .select_from(FinansalHareket)
        .outerjoin(orj, orj.id == ilgili)
        .outerjoin(BudgetCategory, BudgetCategory.id == kat_id)
        .outerjoin(GelirGiderTanim, GelirGiderTanim.id == tanim_id)
        .where(*where)
        .group_by(ad)
        # Tamamen iptal edilmis kategori (toplam 0) listede durmaz.
        .having(func.sum(isaretli) != 0)
        # (P108) Kararli kuyruk GRUPLAMA ANAHTARIDIR: esit tutarli iki
        # kategori her kosumda ayni sirada gelir.
        .order_by(toplam.desc(), ad)
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
