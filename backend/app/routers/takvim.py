"""(P167 Asama 2) TAKVIM + KISISEL HATIRLATMA — Ozet sayfasinin takvimi.

===========================================================================
NEDEN TEK UC, ALTI AYRI UC DEGIL
===========================================================================
Takvim alti kaynaktan besleniyor: etkinlik · devriye penceresi · aidat son
odeme · gorev teslim · rezervasyon · kisisel hatirlatma. Istemcinin bunlari
tek tek cekmesi demek, kullanici her ay okunu tikladiginda ALTI gidis-donus
demekti — ve alti yanitin ucu gelip ucu gelmediginde takvim yarim cizilirdi.

Birlestirme SUNUCUDA cunku PENCERE (baslangic/bitis) hepsine AYNI sekilde
uygulaniyor ve alti farkli tablo alti farkli kolon adi tasiyor
(`tarih`, `pencere_baslangic`, `son_odeme_tarihi`, `sonraki_planlanan`...).
Bu ceviriyi istemciye birakmak, cizim kodunun alti veri seklini bilmesi
demekti.

===========================================================================
GORUNURLUK — HER KAYNAK KENDI KURALINI TASIR
===========================================================================
Takvim bir OKUMA BIRLESTIRICISIDIR, yeni bir yetki kapisi DEGIL. Her
kaynak, kendi ucundaki kurali burada da uygular:

  * hatirlatma -> YALNIZ SAHIBI (`user_id`); ayni tesisteki baska bir
    yonetici bile gormez.
  * aidat / gorev / devriye -> yonetim gorunumu; saha ve sakin rollerine
    KAPALI (uc `_YONETIM`).
  * etkinlik / rezervasyon -> tesis geneli, zaten tum rollere acik.

Ucun tamami `_YONETIM`e kapatildi ve bu bilincli bir SADELESTIRME: Ozet
sayfasi (brief §2) yonetici ekranidir. Sakine takvim gerekirse AYRI bir uc
acilir — tek ucu role gore daraltmak, alti kaynagin her birinde ayri bir
kosul demekti ve biri unutuldugunda sizinti SESSIZ olurdu.
"""
from __future__ import annotations

import uuid
from datetime import datetime, time, timedelta, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..deps import get_current_user, get_tenant_db, require_role
from ..errors import APIError
from ..models import (
    AppUser,
    DuesAssessment,
    Etkinlik,
    Hatirlatma,
    PatrolPlan,
    PatrolWindow,
    Rezervasyon,
    Task,
    Unit,
)
from ..schemas import (
    HatirlatmaCreate,
    HatirlatmaOut,
    HatirlatmaUpdate,
    TakvimOgesi,
    TakvimResponse,
)

router = APIRouter(tags=["takvim"])

_YONETIM = require_role("admin", "yonetici")

#: Pencere UST SINIRI. Takvim en fazla "ay" gorunumu cizer; bir yillik
#: pencere istemek, alti tablonun tamamini tek istekte suzdurmek olurdu.
#: 120 gun, uc aylik gorunume + tasma paylarina yeter.
MAKS_PENCERE_GUN = 120

#: Tekrar eden hatirlatmada pencere basina uretilecek EN COK ornek.
#: Gunluk tekrar + 120 gunluk pencere = 120 satir; sinir onu asan bir
#: kuralin (ileride saatlik vb.) takvimi bogmasini engeller.
MAKS_TEKRAR_ORNEK = 200


# =========================================================================== #
# HATIRLATMA CRUD — kayit YALNIZ sahibinindir
# =========================================================================== #
async def _kendi_hatirlatmasi(
    db: AsyncSession, user: AppUser, hid: uuid.UUID
) -> Hatirlatma:
    """Sahiplik kapisi TEK YERDE.

    `user_id` sorgunun ICINDE: once kaydi cekip sonra sahibini
    karsilastirmak, "var mi yok mu" bilgisini sizdiran bir zamanlama
    farki birakirdi. Bulunamayan kayit 404 — baskasinin kaydi da ayni
    cevabi alir, cunku "senin degil" demek o kaydin VAR OLDUGUNU
    dogrulamak olurdu.
    """
    kayit = (
        await db.execute(
            select(Hatirlatma).where(
                Hatirlatma.id == hid, Hatirlatma.user_id == user.id
            )
        )
    ).scalar_one_or_none()
    if kayit is None:
        raise APIError(404, "not_found", "hatirlatma_bulunamadi")
    return kayit


@router.get("/hatirlatmalar", response_model=list[HatirlatmaOut])
async def hatirlatmalarim(
    user: AppUser = Depends(_YONETIM),
    db: AsyncSession = Depends(get_tenant_db),
) -> list[Hatirlatma]:
    """Kendi hatirlatmalarim — yakin tarih ustte.

    `id` KIRICI: ayni ana kurulmus iki hatirlatma kararsiz sira verirdi
    ve liste her tazelemede yer degistirirdi (bkz. `/me/etkinlik`).
    """
    rows = (
        await db.execute(
            select(Hatirlatma)
            .where(Hatirlatma.user_id == user.id)
            .order_by(Hatirlatma.baslangic.asc(), Hatirlatma.id.asc())
        )
    ).scalars().all()
    return list(rows)


@router.post("/hatirlatmalar", response_model=HatirlatmaOut, status_code=201)
async def hatirlatma_ekle(
    body: HatirlatmaCreate,
    user: AppUser = Depends(_YONETIM),
    db: AsyncSession = Depends(get_tenant_db),
) -> Hatirlatma:
    """Kisisel takvim notu ekle.

    `user_id` ISTEKTEN ALINMAZ, token'dan gelir — alinsaydi bir yonetici
    baskasinin takvimine not birakabilirdi.
    """
    kayit = Hatirlatma(
        tenant_id=user.tenant_id,
        user_id=user.id,
        **body.model_dump(),
    )
    db.add(kayit)
    await db.flush()
    await db.refresh(kayit)
    await audit_user(
        db, user, Action.HATIRLATMA_CREATE, resource_type="hatirlatma",
        resource_id=kayit.id,
    )
    return kayit


@router.patch("/hatirlatmalar/{hatirlatma_id}", response_model=HatirlatmaOut)
async def hatirlatma_guncelle(
    hatirlatma_id: uuid.UUID,
    body: HatirlatmaUpdate,
    user: AppUser = Depends(_YONETIM),
    db: AsyncSession = Depends(get_tenant_db),
) -> Hatirlatma:
    kayit = await _kendi_hatirlatmasi(db, user, hatirlatma_id)
    veri = body.model_dump(exclude_unset=True)
    for alan, deger in veri.items():
        setattr(kayit, alan, deger)
    # ARALIK KISMI GUNCELLEMEDE DE DENETLENIR: istemci yalniz `bitis`
    # gonderdiginde sema onu tek basina gorur ve kaydin MEVCUT
    # `baslangic`i ile karsilastiramaz. Kontrol burada, birlesmis deger
    # uzerinde yapiliyor — yoksa hata veritabani kisitindan 500 olarak
    # donerdi ve sebebi ekranda hic gorunmezdi.
    if kayit.bitis is not None and kayit.bitis < kayit.baslangic:
        raise APIError(422, "validation_error", "hatirlatma_ters_aralik")
    kayit.updated_at = func.now()
    await audit_user(
        db, user, Action.HATIRLATMA_UPDATE, resource_type="hatirlatma",
        resource_id=kayit.id, meta={"alanlar": sorted(veri)},
    )
    return kayit


@router.delete("/hatirlatmalar/{hatirlatma_id}", status_code=204)
async def hatirlatma_sil(
    hatirlatma_id: uuid.UUID,
    user: AppUser = Depends(_YONETIM),
    db: AsyncSession = Depends(get_tenant_db),
):
    """Hatirlatma GERCEKTEN silinir — ters kayit yok.

    Finansal satirlardan farki: hatirlatma bir DEFTER KAYDI degil kisisel
    bir nottur. Silinen bir notun izini tutmak, kullanicinin kendi
    ekranini temizleyememesi demekti.
    """
    from fastapi import Response

    kayit = await _kendi_hatirlatmasi(db, user, hatirlatma_id)
    await audit_user(
        db, user, Action.HATIRLATMA_DELETE, resource_type="hatirlatma",
        resource_id=kayit.id,
    )
    await db.delete(kayit)
    return Response(status_code=204)


# =========================================================================== #
# TAKVIM — alti kaynagin birlesik okumasi
# =========================================================================== #
def _tekrar_ornekleri(
    kayit: Hatirlatma, baslangic: datetime, bitis: datetime
) -> list[datetime]:
    """Tekrar KURALINI pencereye genislet.

    Kayit COGALTILMAZ (goc 0056'nin notu): "her hafta" bir kuraldir ve her
    ornegini satir olarak yazmak, kurali degistirmeyi yuzlerce satir
    guncellemeye cevirirdi. Genisletme burada, YALNIZCA istenen pencere
    kadar yapilir.
    """
    ilk = kayit.baslangic
    if kayit.tekrar == "yok":
        return [ilk] if baslangic <= ilk <= bitis else []

    adim = {"gunluk": timedelta(days=1), "haftalik": timedelta(days=7)}.get(
        kayit.tekrar
    )
    cikti: list[datetime] = []

    if adim is not None:
        an = ilk
        # PENCEREYE ATLAYARAK GIRILIR: gunluk bir kural on yil once
        # basladiysa, birer birer ilerlemek yuz binlerce donguydu.
        if an < baslangic:
            atlanan = (baslangic - an) // adim
            an = an + adim * atlanan
        while an <= bitis and len(cikti) < MAKS_TEKRAR_ORNEK:
            if an >= baslangic:
                cikti.append(an)
            an = an + adim
        return cikti

    # AYLIK — sabit bir gun sayisi YOK, o yuzden takvim ayiyla ilerlenir.
    # AYIN 31'I OLMAYAN AYLAR: kayit ayin son gunune cekilir. Atlamak,
    # "her ayin 31'i" diyen bir hatirlatmanin subatta HIC gorunmemesi
    # demekti; ileri kaydirmak ise onu marta tasirdi.
    yil, ay = ilk.year, ilk.month
    while len(cikti) < MAKS_TEKRAR_ORNEK:
        gun_sayisi = _ayin_gunu(yil, ay)
        an = ilk.replace(year=yil, month=ay, day=min(ilk.day, gun_sayisi))
        if an > bitis:
            break
        if an >= baslangic:
            cikti.append(an)
        ay += 1
        if ay > 12:
            ay, yil = 1, yil + 1
    return cikti


def _ayin_gunu(yil: int, ay: int) -> int:
    import calendar

    return calendar.monthrange(yil, ay)[1]


@router.get("/takvim", response_model=TakvimResponse)
async def takvim(
    baslangic: datetime = Query(..., description="Pencere basi (dahil)"),
    bitis: datetime = Query(..., description="Pencere sonu (dahil)"),
    user: AppUser = Depends(_YONETIM),
    db: AsyncSession = Depends(get_tenant_db),
) -> TakvimResponse:
    """Verilen pencerede takvime dusen HER SEY — tek yanitta.

    PENCERE ZORUNLU ve sinirli (`MAKS_PENCERE_GUN`): sinirsiz bir aralik,
    alti tablonun tamamini tek istekte suzdurmek olurdu.
    """
    if bitis < baslangic:
        raise APIError(422, "validation_error", "takvim_ters_aralik")
    if (bitis - baslangic).days > MAKS_PENCERE_GUN:
        raise APIError(422, "validation_error", "takvim_pencere_genis")

    items: list[TakvimOgesi] = []

    # --- 1. ETKINLIKLER ----------------------------------------------------
    for e in (
        await db.execute(
            select(Etkinlik).where(
                Etkinlik.tarih >= baslangic, Etkinlik.tarih <= bitis
            )
        )
    ).scalars().all():
        items.append(TakvimOgesi(
            tip="etkinlik", id=e.id, baslik=e.baslik,
            baslangic=e.tarih, bitis=e.bitis_zamani,
            hedef="/etkinlik-yonetimi",
        ))

    # --- 2. DEVRIYE PENCERELERI -------------------------------------------
    # Plan adi JOIN ile geliyor: pencere basina ayri sorgu, bir aylik
    # gorunumde yuzlerce gidis-donus olurdu (N+1).
    for pencere, plan_ad in (
        await db.execute(
            select(PatrolWindow, PatrolPlan.ad)
            .join(PatrolPlan, PatrolPlan.id == PatrolWindow.patrol_plan_id)
            .where(
                PatrolWindow.pencere_baslangic >= baslangic,
                PatrolWindow.pencere_baslangic <= bitis,
            )
        )
    ).all():
        items.append(TakvimOgesi(
            tip="devriye", id=pencere.id, baslik=plan_ad,
            baslangic=pencere.pencere_baslangic, bitis=pencere.pencere_bitis,
            hedef="/patrol-plans",
        ))

    # --- 3. AIDAT SON ODEME TARIHLERI -------------------------------------
    # TARIH BAZINDA GRUPLANIR, daire basina satir DEGIL: 200 daireli bir
    # sitede ayni gun 200 kayit, takvimi okunamaz kilardi. Kullanicinin
    # sordugu soru "bu ayin son odeme gunu ne zaman", "hangi daire" degil.
    for son_tarih, adet in (
        await db.execute(
            select(
                DuesAssessment.son_odeme_tarihi, func.count()
            )
            .where(
                DuesAssessment.son_odeme_tarihi.is_not(None),
                DuesAssessment.son_odeme_tarihi >= baslangic.date(),
                DuesAssessment.son_odeme_tarihi <= bitis.date(),
            )
            .group_by(DuesAssessment.son_odeme_tarihi)
        )
    ).all():
        an = datetime.combine(son_tarih, time(0, 0), tzinfo=timezone.utc)
        items.append(TakvimOgesi(
            # KIMLIK TARIHTEN TURETILIR: gruplanmis satirin bir kayit
            # kimligi yoktur ama takvimin `key`e ihtiyaci vardir. `uuid5`
            # ayni tarih icin ayni degeri uretir (kararli).
            tip="aidat", id=uuid.uuid5(uuid.NAMESPACE_URL, f"aidat/{son_tarih}"),
            baslik=str(adet), baslangic=an, hedef="/dues",
        ))

    # --- 4. GOREV TESLIM TARIHLERI ----------------------------------------
    for g in (
        await db.execute(
            select(Task).where(
                Task.aktif.is_(True),
                Task.sonraki_planlanan.is_not(None),
                Task.sonraki_planlanan >= baslangic,
                Task.sonraki_planlanan <= bitis,
            )
        )
    ).scalars().all():
        items.append(TakvimOgesi(
            tip="gorev", id=g.id, baslik=g.ad,
            baslangic=g.sonraki_planlanan, hedef="/tasks",
        ))

    # --- 5. REZERVASYONLAR -------------------------------------------------
    # IPTAL EDILENLER DISARIDA: iptal, slotu bosaltir; takvimde gostermek
    # dolu olmayan bir saati dolu gibi okuturdu.
    for r, unit_no in (
        await db.execute(
            select(Rezervasyon, Unit.no)
            .join(Unit, Unit.id == Rezervasyon.unit_id)
            .where(
                Rezervasyon.durum == "onaylandi",
                Rezervasyon.tarih >= baslangic.date(),
                Rezervasyon.tarih <= bitis.date(),
            )
        )
    ).all():
        items.append(TakvimOgesi(
            tip="rezervasyon", id=r.id, baslik=unit_no,
            baslangic=datetime.combine(r.tarih, r.baslangic, tzinfo=timezone.utc),
            bitis=datetime.combine(r.tarih, r.bitis, tzinfo=timezone.utc),
            hedef="/rezervasyonlarim",
        ))

    # --- 6. KISISEL HATIRLATMALAR -----------------------------------------
    # TEKRAR EDENLER PENCEREDE GENISLETILIR. Sorgu `baslangic <= bitis`
    # ile suzuyor ama UST SINIR YOK: on yil once baslamis GUNLUK bir
    # kural bugunku pencereye duser ve `baslangic >= pencere` kosulu onu
    # ELERDI.
    for h in (
        await db.execute(
            select(Hatirlatma).where(
                Hatirlatma.user_id == user.id,
                Hatirlatma.baslangic <= bitis,
            )
        )
    ).scalars().all():
        sure = (h.bitis - h.baslangic) if h.bitis else None
        for an in _tekrar_ornekleri(h, baslangic, bitis):
            items.append(TakvimOgesi(
                tip="hatirlatma", id=h.id, baslik=h.baslik,
                baslangic=an, bitis=(an + sure) if sure else None,
                renk=h.renk, hedef=None,
            ))

    # TEK SIRALAMA SUNUCUDA: alti kaynak alti ayri sorgudan geliyor ve
    # istemciye sirasiz bir yigin gondermek, cizim kodunu yeniden
    # siralamaya zorlardi. `tip` kirici — ayni ana dusen iki olay her
    # cagrida ayni sirada gorunsun.
    items.sort(key=lambda o: (o.baslangic, o.tip, str(o.id)))
    return TakvimResponse(items=items)


# =========================================================================== #
# PANO TERCIHI — kullanicinin kendi ekran duzeni
# =========================================================================== #
@router.get("/me/pano-tercihi")
async def pano_tercihim(
    user: AppUser = Depends(get_current_user),
) -> dict:
    """Kendi Ozet sayfasi duzenim.

    BOS NESNE = "varsayilani kullan". Sunucu bir varsayilan URETMEZ:
    varsayilan kume role gore degisiyor (menude gorunen ilk alti sayfa) ve
    onu burada hesaplamak, ayni karari menuden sonra IKINCI bir yerde daha
    vermek olurdu. Istemci `menuGruplari` ile zaten biliyor.
    """
    return dict(user.pano_tercihi or {})


@router.put("/me/pano-tercihi")
async def pano_tercihi_yaz(
    body: dict,
    user: AppUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_tenant_db),
) -> dict:
    """Duzeni KAYDET — PUT cunku kayit bir BUTUNDUR.

    PATCH olsaydi "widget listesini degistir ama bolum sirasina dokunma"
    gibi kismi bir sozlesme gerekirdi; oysa istemci duzeni her zaman tam
    olarak biliyor ve kismi yazma, iki sekme acikken birinin otekinin
    duzenini yarim ezmesine kapi acardi.

    SEMA DOGRULAMASI BURADA: `PanoTercihi` tanimadigi anahtari ATAR, yani
    JSONB serbestligi bir sozlesme bosllugu degildir.
    """
    from ..schemas import PanoTercihi

    try:
        temiz = PanoTercihi.model_validate(body)
    except Exception as exc:  # pydantic ValidationError
        raise APIError(422, "validation_error", "pano_tercihi_gecersiz") from exc
    user.pano_tercihi = temiz.model_dump(exclude_none=True)
    user.updated_at = func.now()
    return dict(user.pano_tercihi)
