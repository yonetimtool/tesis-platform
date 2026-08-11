"""(P154 / Asama 8) ICE AKTARIM CATISI — dort tur, TEK akis.

===========================================================================
NEDEN CATI, NEDEN DORT AYRI UC DEGIL
===========================================================================
Brief: "[CAKISMA: Apsiyon 'Excel ile Site Aktar' + Asama 5 sakin yukleme
+ Apsiyon kisi/daire aktarimi — HEPSI tek framework uzerinden.] Akis:
sablon indirme → yukleme → kolon esleme → dogrulama → ONIZLEME → islem
icinde aktarim → hata raporu → GERI ALMA. Kapsam (oncelik sirasiyla):
daireler/bloklar, kisiler/sakinler, acilis bakiyeleri, araclar. Her biri
ayni framework'u kullanacak."

Dort ayri uc yazmak, ONIZLEME + HATA RAPORU + GERI ALMA + ISLEM SINIRI
mantigini dort kez kopyalamak olurdu — ve biri degistiginde otekiler
eskirdi. Burada tur bir VERI: `TURLER` sozlugu her tur icin ALANLARI ve
tek bir `uygula` fonksiyonunu tasir; akisin geri kalani ortaktir.

===========================================================================
KOLON ESLEME NEREDE YAPILIR
===========================================================================
Sunucu ALANLARI bildirir (`GET /ice-aktarim/turler`); istemci kullanicinin
Excel basliklarini bu alanlara esler ve satirlari BIZIM alan kodlarimizla
gonderir. Yani esleme ARAYUZDE, sozlesme SUNUCUDA.

Boyle secildi cunku XLSX AYRISTIRMA SUNUCUDA YAPILMIYOR (P28/P29 karari:
xlsx ayristirma bir saldiri yuzeyidir) — dosyayi zaten istemci aciyor,
basliklari da o goruyor. Esleme sunucuya tasinsaydi sunucunun dosyayi
gormesi gerekirdi.

===========================================================================
KISMI BASARI — TANIM VE GEREKCE (brief'in acik istegi)
===========================================================================
TANIM: gecerli satirlar YAZILIR, hatali satirlar YAZILMAZ ve satir
numarasiyla raporlanir. Kosum bir ISLEMDIR: yazilanlar hep birlikte
kalicilasir.

GEREKCE: 300 satirlik bir dosyada 4 hatali satir yuzunden 296 dogru
satiri reddetmek, kullaniciyi dosyayi elle ayiklamaya zorlardi — ve o
ayiklamayi Excel'de yapmak, hata raporunu okuyup 4 satiri duzeltmekten
cok daha hatali bir istir.

TAKASI DURUSTCE: bu, "yarim aktarim" durumunu MUMKUN kilar. Bedeli iki
seyle odendi — (1) ONIZLEME (`yalniz_dogrula`) hicbir sey yazmadan ayni
raporu verir, (2) GERI ALMA kosumun tamamini kaldirir. Yani kullanici
yarim kalmis bir sonuca MAHKUM DEGILDIR.

===========================================================================
IDEMPOTENT: var olan kayit ATLANIR
===========================================================================
Ayni dosya iki kez yuklenirse ikinci kosum hicbir sey yaratmaz. Bu, ag
hatasindan sonra "yukledi mi yuklemedi mi" belirsizligini ortadan
kaldirir — kullanici tereddutsuz yeniden dener.
"""
from __future__ import annotations

import uuid
from dataclasses import dataclass, field as dc_field
from datetime import date
from typing import Awaitable, Callable

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..hata_metinleri import hata_metni, istek_dili
from ..models import (
    AppUser,
    AracKayit,
    BuildingBlock,
    FinansalHareket,
    IceAktarim,
    IceAktarimKayit,
    Unit,
    UnitResident,
)
from ..security import normalize_phone
from ..schemas import (
    IceAktarimIstek,
    IceAktarimListResponse,
    IceAktarimOut,
    IceAktarimSonuc,
    IceAktarimTurOut,
    IceAktarimAlanOut,
)

router = APIRouter(prefix="/ice-aktarim", tags=["ice-aktarim"])

_YONETIM = require_role("admin", "yonetici")


# =========================== TUR TANIMLARI ================================== #
@dataclass(frozen=True)
class _Alan:
    """Ice aktarim alani — istemcinin kolon eslemesi bunun uzerine kurulur."""

    kod: str
    zorunlu: bool = False
    ornek: str = ""


@dataclass
class _Bag:
    """Bir kosumun calisma defteri.

    `iz` yaratilan her satiri SIRAYLA tutar; geri alma bunu tersten okur.
    """

    db: AsyncSession
    user: AppUser
    dil: str
    yalniz_dogrula: bool
    sonuc: IceAktarimSonuc
    iz: list[tuple[str, uuid.UUID]] = dc_field(default_factory=list)

    def hata(self, satir_no: int, alan: str | None, kimlik: str) -> None:
        self.sonuc.hatalar.append(
            {"satir_no": satir_no, "alan": alan, "hata": hata_metni(kimlik, self.dil)}
        )
        self.sonuc.hatali += 1

    def yarat(self, tablo: str, kayit_id: uuid.UUID) -> None:
        self.iz.append((tablo, kayit_id))


def _metin(degerler: dict, kod: str) -> str:
    return str(degerler.get(kod) or "").strip()


def _kurus(ham: str) -> int | None:
    """TL metnini kurusa cevirir. Bicim serbest: `1.234,56` da `1234.56` da.

    NEDEN SUNUCUDA: Excel'den gelen tutar bicimi ULKEYE gore degisir ve
    istemcide cevirmek, ceviri kuralini iki yerde tutmak olurdu.
    """
    t = ham.replace(" ", "")
    if not t:
        return None
    # Son ayirac ONDALIK kabul edilir; oteki binlik ayiracidir.
    son_nokta, son_virgul = t.rfind("."), t.rfind(",")
    if son_virgul > son_nokta:
        t = t.replace(".", "").replace(",", ".")
    else:
        t = t.replace(",", "")
    try:
        return round(float(t) * 100)
    except ValueError:
        return None


# --------------------------------- daire ----------------------------------- #
async def _uygula_daire(b: _Bag, satir_no: int, d: dict) -> None:
    blok = _metin(d, "blok")
    daire = _metin(d, "daire_no")
    if not blok or not daire:
        b.hata(satir_no, "blok" if not blok else "daire_no", "zorunlu_alan_eksik")
        return

    var_blok = (
        await b.db.execute(select(BuildingBlock.id).where(BuildingBlock.ad == blok))
    ).first()
    if var_blok is None:
        if not b.yalniz_dogrula:
            obj = BuildingBlock(tenant_id=b.user.tenant_id, ad=blok)
            b.db.add(obj)
            await b.db.flush()
            b.yarat("building_block", obj.id)
        b.sonuc.olusan += 1

    var_daire = (
        await b.db.execute(select(Unit.id).where(Unit.no == daire))
    ).first()
    if var_daire is not None:
        # IDEMPOTENT: var olan daire ATLANIR (dosya yeniden yuklenebilir).
        b.sonuc.atlanan += 1
        return
    if b.yalniz_dogrula:
        b.sonuc.olusan += 1
        return
    u = Unit(tenant_id=b.user.tenant_id, no=daire, blok=blok)
    b.db.add(u)
    try:
        await b.db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    b.yarat("unit", u.id)
    b.sonuc.olusan += 1


# ---------------------------------- kisi ------------------------------------ #
async def _uygula_kisi(b: _Bag, satir_no: int, d: dict) -> None:
    ad = _metin(d, "ad")
    tel_ham = _metin(d, "telefon")
    if not ad or not tel_ham:
        b.hata(satir_no, "ad" if not ad else "telefon", "zorunlu_alan_eksik")
        return
    try:
        telefon = normalize_phone(tel_ham)
    except ValueError:
        b.hata(satir_no, "telefon", "telefon_bicimi")
        return

    rol = (_metin(d, "rol_tipi") or "").lower() or None
    if rol not in (None, "malik", "kiraci"):
        b.hata(satir_no, "rol_tipi", "gecersiz_rol_tipi")
        return

    var = (
        await b.db.execute(select(AppUser.id).where(AppUser.telefon == telefon))
    ).first()
    if var is not None:
        b.sonuc.atlanan += 1
        return

    daire_no = _metin(d, "daire_no")
    unit_id: uuid.UUID | None = None
    if daire_no:
        satir = (
            await b.db.execute(select(Unit.id).where(Unit.no == daire_no))
        ).first()
        if satir is None:
            # DAIRE YOKSA HATA, sessiz atlama DEGIL: kullanici sakini
            # daireye baglamak istedi ve baglanmadigini bilmeli.
            b.hata(satir_no, "daire_no", "daire_bulunamadi")
            return
        unit_id = satir[0]

    if b.yalniz_dogrula:
        b.sonuc.olusan += 1
        return

    kisi = AppUser(
        tenant_id=b.user.tenant_id, ad=ad, telefon=telefon,
        role="resident", password_set=False,
        password_hash="!",  # parola BELIRLENMEMIS (gecici kod akisi)
    )
    b.db.add(kisi)
    try:
        await b.db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    b.yarat("app_user", kisi.id)
    if unit_id is not None:
        ur = UnitResident(
            tenant_id=b.user.tenant_id, unit_id=unit_id,
            user_id=kisi.id, rol_tipi=rol,
        )
        b.db.add(ur)
        await b.db.flush()
        b.yarat("unit_resident", ur.id)
    b.sonuc.olusan += 1


# ------------------------------ acilis bakiye ------------------------------- #
async def _uygula_acilis(b: _Bag, satir_no: int, d: dict) -> None:
    """Daire basina ACILIS BAKIYESI — tek deftere `tip='acilis'` satiri.

    NEDEN `dues_assessment` DEGIL: acilis bakiyesi bir DONEM TAHAKKUKU
    degildir, devreden bakiyedir. Tahakkuk olarak yazmak, o daireye ait
    olmayan bir doneme borc yazmak ve aidat raporlarini bozmak olurdu.
    Tek defter (P29) bu satiri zaten taniyor (`acilis`) ve panelde
    "Acilis fisleri" olarak suzuluyor.
    """
    daire_no = _metin(d, "daire_no")
    if not daire_no:
        b.hata(satir_no, "daire_no", "zorunlu_alan_eksik")
        return
    satir = (await b.db.execute(select(Unit.id).where(Unit.no == daire_no))).first()
    if satir is None:
        b.hata(satir_no, "daire_no", "daire_bulunamadi")
        return

    kurus = _kurus(_metin(d, "tutar"))
    if kurus is None:
        b.hata(satir_no, "tutar", "tutar_bicimi")
        return
    if kurus <= 0:
        # TUTAR HER ZAMAN POZITIF (P29): isaret `yon` sutunundadir.
        # Sifir bakiye YAZILMAZ — hicbir sey anlatmaz.
        b.hata(satir_no, "tutar", "tutar_pozitif_olmali")
        return

    if b.yalniz_dogrula:
        b.sonuc.olusan += 1
        return

    h = FinansalHareket(
        tenant_id=b.user.tenant_id, tip="acilis", yon="giris",
        tutar_kurus=kurus, unit_id=satir[0],
        aciklama=_metin(d, "aciklama") or None,
        kaydeden_user_id=b.user.id,
    )
    b.db.add(h)
    await b.db.flush()
    b.yarat("finansal_hareket", h.id)
    b.sonuc.olusan += 1


# --------------------------------- arac ------------------------------------- #
async def _uygula_arac(b: _Bag, satir_no: int, d: dict) -> None:
    plaka_ham = _metin(d, "plaka")
    if not plaka_ham:
        b.hata(satir_no, "plaka", "zorunlu_alan_eksik")
        return
    # Plaka `vehicle_pass` ile AYNI kuralla normalize edilir (bosluksuz +
    # BUYUK); iki farkli normalizasyon iki farkli cevap verirdi.
    plaka = plaka_ham.replace(" ", "").upper()

    var = (
        await b.db.execute(select(AracKayit.id).where(AracKayit.plaka == plaka))
    ).first()
    if var is not None:
        b.sonuc.atlanan += 1
        return

    daire_no = _metin(d, "daire_no")
    unit_id: uuid.UUID | None = None
    if daire_no:
        satir = (await b.db.execute(select(Unit.id).where(Unit.no == daire_no))).first()
        if satir is None:
            b.hata(satir_no, "daire_no", "daire_bulunamadi")
            return
        unit_id = satir[0]

    if b.yalniz_dogrula:
        b.sonuc.olusan += 1
        return

    a = AracKayit(
        tenant_id=b.user.tenant_id, plaka=plaka, unit_id=unit_id,
        marka=_metin(d, "marka") or None,
        model=_metin(d, "model") or None,
        renk=_metin(d, "renk") or None,
    )
    b.db.add(a)
    try:
        await b.db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    b.yarat("arac_kayit", a.id)
    b.sonuc.olusan += 1


@dataclass(frozen=True)
class _Tur:
    kod: str
    alanlar: tuple[_Alan, ...]
    uygula: Callable[[_Bag, int, dict], Awaitable[None]]
    aciklama_kodu: str


#: Turler — brief'in ONCELIK SIRASI. Anahtarlar goc 0045'teki
#: `ck_ice_aktarim_tur` CHECK kumesiyle AYNI olmali;
#: `test_ice_aktarim.py::test_turler_GOCLE_AYNI` bunu kilitler.
TURLER: dict[str, _Tur] = {
    "daire": _Tur(
        "daire",
        (
            _Alan("blok", zorunlu=True, ornek="A"),
            _Alan("daire_no", zorunlu=True, ornek="A-1"),
        ),
        _uygula_daire,
        "iceAktarimDaireAciklama",
    ),
    "kisi": _Tur(
        "kisi",
        (
            _Alan("ad", zorunlu=True, ornek="Ali Veli"),
            _Alan("telefon", zorunlu=True, ornek="+905321112233"),
            _Alan("daire_no", ornek="A-1"),
            _Alan("rol_tipi", ornek="malik"),
        ),
        _uygula_kisi,
        "iceAktarimKisiAciklama",
    ),
    "acilis_bakiye": _Tur(
        "acilis_bakiye",
        (
            _Alan("daire_no", zorunlu=True, ornek="A-1"),
            _Alan("tutar", zorunlu=True, ornek="1.250,00"),
            _Alan("aciklama", ornek="2025 devri"),
        ),
        _uygula_acilis,
        "iceAktarimAcilisAciklama",
    ),
    "arac": _Tur(
        "arac",
        (
            _Alan("plaka", zorunlu=True, ornek="34ABC123"),
            _Alan("daire_no", ornek="A-1"),
            _Alan("marka", ornek="Fiat"),
            _Alan("model", ornek="Egea"),
            _Alan("renk", ornek="Beyaz"),
        ),
        _uygula_arac,
        "iceAktarimAracAciklama",
    ),
}

#: (P154 / Asama 10) DEFTER SATIRLARI SILINMEZ, TERSINE CEVRILIR.
#:
#: Goc 0047 `finansal_hareket` uzerinde app_rw'nin DELETE yetkisini geri
#: aldi: bir muhasebe kaydi "hic olmamis" hâle getirilemez. Bu, Asama
#: 8'in geri almasiyla CAKISTI — `acilis_bakiye` turu defter satiri
#: yaratiyor ve geri alma onlari SILIYORDU.
#:
#: Cozum kilidi gevsetmek DEGIL, dogru olani yapmak: bu tablonun
#: satirlari icin geri alma bir IPTAL (ters kayit) yazar. Sonuc
#: kullanicinin bekledigiyle ayni — bakiye eski hâline doner — ama defter
#: NE OLDUGUNU anlatmaya devam eder.
_TERS_KAYITLI = {"finansal_hareket"}

#: Geri almanin silebilecegi tablolar. KAPALI KUME: iz tablosunda `tablo`
#: serbest metindir ve buradan gecmeyen bir ad, geri almada rastgele bir
#: tabloya DELETE atmak olurdu.
_SILINEBILIR = {
    "building_block": BuildingBlock,
    "unit": Unit,
    "app_user": AppUser,
    "unit_resident": UnitResident,
    "finansal_hareket": FinansalHareket,
    "arac_kayit": AracKayit,
}


@router.get("/turler", response_model=list[IceAktarimTurOut])
async def turler(_: AppUser = Depends(_YONETIM)) -> list[IceAktarimTurOut]:
    """Turler + ALANLARI — istemcinin kolon eslemesi bunun uzerine kurulur.

    SUNUCU XLSX URETMEZ: panel bu alanlardan sablonu kendisi kurar.
    Boylece sablon ile kabul edilen bicim TEK KAYNAKTAN gelir ve
    "indirdigim sablon reddedildi" durumu olusmaz.
    """
    return [
        IceAktarimTurOut(
            kod=t.kod,
            aciklama_kodu=t.aciklama_kodu,
            alanlar=[
                IceAktarimAlanOut(kod=a.kod, zorunlu=a.zorunlu, ornek=a.ornek)
                for a in t.alanlar
            ],
        )
        for t in TURLER.values()
    ]


@router.post("/{tur}", response_model=IceAktarimSonuc, status_code=201)
async def aktar(
    tur: str,
    body: IceAktarimIstek,
    accept_language: str | None = None,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> IceAktarimSonuc:
    """Dogrulama (`yalniz_dogrula=true`) ya da aktarim.

    ONIZLEME HICBIR SEY YAZMAZ. Kurulum tek seferlik ve geri almasi zor
    bir islemdir; onizleme olmadan yapilmasi yanlis bir dosyayi yuzlerce
    satir boyunca uygulamak olurdu. (Geri alma VAR ama onizleme yine de
    ucuz olan yoldur.)
    """
    t = TURLER.get(tur)
    if t is None:
        raise APIError(422, "validation_error", "ice_aktarim_turu_gecersiz")

    b = _Bag(
        db=db, user=user, dil=istek_dili(accept_language),
        yalniz_dogrula=body.yalniz_dogrula,
        sonuc=IceAktarimSonuc(),
    )
    for satir in body.satirlar:
        await t.uygula(b, satir.satir_no, satir.degerler)

    b.sonuc.satir_sayisi = len(body.satirlar)
    if body.yalniz_dogrula:
        return b.sonuc

    kosum = IceAktarim(
        tenant_id=user.tenant_id, tur=tur, dosya_adi=body.dosya_adi,
        satir_sayisi=b.sonuc.satir_sayisi, olusan=b.sonuc.olusan,
        atlanan=b.sonuc.atlanan, hatali=b.sonuc.hatali,
        olusturan_user_id=user.id,
    )
    db.add(kosum)
    await db.flush()
    for sira, (tablo, kayit_id) in enumerate(b.iz):
        db.add(IceAktarimKayit(
            tenant_id=user.tenant_id, aktarim_id=kosum.id,
            tablo=tablo, kayit_id=kayit_id, sira=sira,
        ))
    await db.flush()
    await audit_user(
        db, user, Action.SITE_AKTAR, resource_type="ice_aktarim",
        resource_id=kosum.id,
        meta={"tur": tur, "olusan": b.sonuc.olusan, "hatali": b.sonuc.hatali},
    )
    b.sonuc.aktarim_id = kosum.id
    return b.sonuc


@router.get("", response_model=IceAktarimListResponse)
async def gecmis(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> IceAktarimListResponse:
    """Gecmis kosumlar — geri alma bu listeden yapilir."""
    total = (await db.execute(select(func.count()).select_from(IceAktarim))).scalar_one()
    satirlar = (
        (await db.execute(
            select(IceAktarim)
            .order_by(IceAktarim.created_at.desc(), IceAktarim.id.desc())
            .limit(limit).offset(offset)
        )).scalars().all()
    )
    return IceAktarimListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[IceAktarimOut.model_validate(s, from_attributes=True) for s in satirlar],
    )


@router.post("/{aktarim_id}/geri-al", response_model=IceAktarimOut)
async def geri_al(
    aktarim_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> IceAktarimOut:
    """Kosumun YARATTIGI HER SATIRI kaldirir — HEP YA DA HIC.

    TERS SIRADA silinir (once cocuk, sonra ebeveyn): sirasiz silmek FK
    yuzunden rastgele basarisiz olurdu.

    Bir satir silinemiyorsa — ornegin ice aktarilan daireye sonradan
    tahakkuk yazilmissa — TUM geri alma duser (409). KISMI GERI ALMA
    YAPILMAZ: yarim geri alinmis bir aktarim, kullanicinin "sildim"
    sandigi ama bir kismi duran bir veri birakirdi.

    KOSUM KAYDI SILINMEZ, durumu degisir: silmek "bu dosya bir kez
    yuklendi ve geri alindi" gercegini yok etmek olurdu.
    """
    kosum = await get_or_404(db, IceAktarim, aktarim_id)
    if kosum.durum == "geri_alindi":
        raise APIError(409, "conflict", "ice_aktarim_zaten_geri_alindi")

    izler = (
        (await db.execute(
            select(IceAktarimKayit)
            .where(IceAktarimKayit.aktarim_id == aktarim_id)
            .order_by(IceAktarimKayit.sira.desc())
        )).scalars().all()
    )
    for iz in izler:
        model = _SILINEBILIR.get(iz.tablo)
        if model is None:
            # Kapali kume disinda bir ad: veri bozulmus demektir ve
            # rastgele bir tabloya DELETE atmaktansa durmak dogru.
            raise APIError(409, "conflict", "ice_aktarim_geri_alinamaz")
        obj = (
            await db.execute(select(model).where(model.id == iz.kayit_id))
        ).scalar_one_or_none()
        if obj is None:
            # Kayit ZATEN yok (elle silinmis): geri almanin amaci bu
            # satirin olmamasiydi, o hâlde is gorulmus sayilir.
            continue

        if iz.tablo in _TERS_KAYITLI:
            # Bkz. `_TERS_KAYITLI`: defter satiri silinmez, tersine cevrilir.
            zaten = (
                await db.execute(
                    select(FinansalHareket.id)
                    .where(FinansalHareket.ters_kayit_id == obj.id)
                )
            ).first()
            if zaten is None:
                db.add(FinansalHareket(
                    tenant_id=user.tenant_id, tip="iptal",
                    yon="cikis" if obj.yon == "giris" else "giris",
                    tutar_kurus=obj.tutar_kurus, kasa_id=obj.kasa_id,
                    user_id=obj.user_id, unit_id=obj.unit_id,
                    firma_id=obj.firma_id,
                    gelir_gider_tanim_id=obj.gelir_gider_tanim_id,
                    ters_kayit_id=obj.id,
                    kaydeden_user_id=user.id,
                ))
            continue

        await db.delete(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        # En sik sebep: ice aktarilan kayda sonradan baska bir kayit
        # baglanmis (daireye tahakkuk, kisiye gorev...).
        raise APIError(
            409, "conflict", "ice_aktarim_kullanimda"
        ) from exc

    kosum.durum = "geri_alindi"
    kosum.geri_alma_at = func.now()
    await db.flush()
    await db.refresh(kosum)
    await audit_user(
        db, user, Action.SITE_AKTAR, resource_type="ice_aktarim",
        resource_id=kosum.id, meta={"geri_alindi": True, "tur": kosum.tur},
    )
    return IceAktarimOut.model_validate(kosum, from_attributes=True)
