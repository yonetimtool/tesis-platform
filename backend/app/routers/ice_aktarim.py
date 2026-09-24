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

import re
import uuid
from dataclasses import dataclass, field as dc_field
from datetime import date
from typing import Awaitable, Callable

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..hata_metinleri import hata_metni, istek_dili
from ..davet import davet_olustur_ve_gonder
from ..models import (
    AppUser,
    AracKayit,
    BuildingBlock,
    FinansalHareket,
    IceAktarim,
    IceAktarimKayit,
    Tenant,
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
    # (P186 §3.1) Kisi aktariminda davet e-postasi/SMS'i icin tesis adi —
    # kosum basinda BIR KEZ okunur (satir basina sorgu olmasin).
    tenant_ad: str = ""
    iz: list[tuple[str, uuid.UUID]] = dc_field(default_factory=list)
    # (E2E 2026-09 / TESIS-10) DOSYA ICI BELLEK — ONIZLEME = SONUC.
    #
    # Kuru kosum hicbir sey yazmadigi icin DB'ye bakan her kontrol dosya
    # icindeki yinelemeyi GORMUYORDU: ayni telefon iki satirda gelince
    # onizleme ikisini de "olusacak" sayiyor, gercek aktarim ikinciyi
    # ancak yazarken "zaten var" diye (satir no'suz) atliyordu. Olculen:
    # onizleme `olusan:3, atlanan:2`, sonuc `olusan:2, atlanan:3`.
    # Asagidaki kumeler IKI kosumda da ayni kurali uygular.
    dosya_telefon: dict[str, int] = dc_field(default_factory=dict)
    dosya_eposta: dict[str, int] = dc_field(default_factory=dict)
    dosya_daire_rol: set[tuple[str, str, str | None]] = dc_field(default_factory=set)
    dosya_blok: set[str] = dc_field(default_factory=set)
    dosya_daire: set[str] = dc_field(default_factory=set)

    def hata(self, satir_no: int, alan: str | None, kimlik: str, **params) -> None:
        self.sonuc.hatalar.append(
            {"satir_no": satir_no, "alan": alan,
             "hata": hata_metni(kimlik, self.dil, params or None)}
        )
        self.sonuc.hatali += 1

    def atla(self, satir_no: int, alan: str | None, kimlik: str) -> None:
        """(E2E 2026-09 / TESIS-10) Atlanan satir SAYI degil KAYIT: satir no +
        sebep. Sessiz "zaten var" sayaci hangi satirin neden yazilmadigini
        soylemiyordu."""
        self.sonuc.atlananlar.append(
            {"satir_no": satir_no, "alan": alan, "hata": hata_metni(kimlik, self.dil)}
        )
        self.sonuc.atlanan += 1

    def yarat(self, tablo: str, kayit_id: uuid.UUID) -> None:
        self.iz.append((tablo, kayit_id))


#: Excel e-posta sutunu icin HAFIF bicim kontrolu (import kapisi). Tam
#: dogrulama (EmailStr) davet/DB katmaninda; burada amac bariz bozuk adresi
#: satir hatasi olarak raporlamak.
_EPOSTA_KALIBI = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


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


def _ondalik(ham: str) -> float | None:
    """(P193 §6) Arsa payi / metrekare metnini sayiya cevirir.

    `_kurus` YENIDEN KULLANILMADI: o para icindir ve 100 ile carpar. Arsa
    payi bir PAY'dir (0,0125 gibi) ve kurusa cevirmek anlamsiz olurdu.
    Bicim yine serbest: `0,0125` de `0.0125` de kabul edilir — Excel'in
    ondalik ayiraci ulkeye gore degisir.
    """
    t = ham.replace(" ", "")
    if not t:
        return None
    son_nokta, son_virgul = t.rfind("."), t.rfind(",")
    if son_virgul > son_nokta:
        t = t.replace(".", "").replace(",", ".")
    else:
        t = t.replace(",", "")
    try:
        return float(t)
    except ValueError:
        return None


# --------------------------------- daire ----------------------------------- #
async def _uygula_daire(b: _Bag, satir_no: int, d: dict) -> None:
    blok = _metin(d, "blok")
    daire = _metin(d, "daire_no")
    if not blok or not daire:
        b.hata(satir_no, "blok" if not blok else "daire_no", "zorunlu_alan_eksik")
        return

    # (P193 §6) ARSA PAYI ve METREKARE — opsiyonel sutunlar.
    #
    # Rehberde eksik 6: arsa payi ne toplu olusturmada ne aktarimda
    # vardi; 100 daireli bir sitede 100 ayri form demekti. Deger
    # OKUNAMIYORSA satir HATALIDIR: sessizce `None` yazmak, kullanicinin
    # girdigi sayiyi yok saymak ve arsa payi dagitimini fark edilmeden
    # eksik birakmak olurdu.
    sayilar: dict[str, float | None] = {}
    for alan in ("arsa_payi", "metrekare"):
        ham = _metin(d, alan)
        if not ham:
            continue
        deger = _ondalik(ham)
        if deger is None or deger < 0:
            b.hata(satir_no, alan, "sayi_gecersiz")
            return
        sayilar[alan] = deger

    var_blok = (
        await b.db.execute(select(BuildingBlock.id).where(BuildingBlock.ad == blok))
    ).first()
    # (E2E 2026-09 / TESIS-10) Kuru kosumda blok yazilmadigi icin ayni yeni
    # blok HER satirda "olusacak" sayiliyordu; gercek kosum bir kez yaratir.
    if var_blok is None and blok not in b.dosya_blok:
        if not b.yalniz_dogrula:
            obj = BuildingBlock(tenant_id=b.user.tenant_id, ad=blok)
            b.db.add(obj)
            await b.db.flush()
            b.yarat("building_block", obj.id)
        b.sonuc.olusan += 1
    b.dosya_blok.add(blok)

    mevcut = (
        await b.db.execute(select(Unit).where(Unit.no == daire))
    ).scalar_one_or_none()
    if mevcut is not None:
        # (P193 §6) VAR OLAN DAIREDE ARSA PAYI/METREKARE GUNCELLENIR.
        #
        # Eskiden var olan daire kosulsuz ATLANIYORDU. Gercek akis tam da
        # bunu kiriyordu: yonetici once 100 daireyi TOPLU OLUSTURUYOR,
        # sonra arsa paylarini iceren dosyayi yukluyor — ve dosyanin
        # tamami "zaten kayitli" diye atlanip hicbir arsa payi
        # yazilmiyordu. Kimlik alanlari (no, blok) DEGISMEZ; yalnizca
        # verilen sayisal alanlar yazilir.
        if sayilar and not b.yalniz_dogrula:
            for alan, deger in sayilar.items():
                setattr(mevcut, alan, deger)
            await b.db.flush()
        if sayilar:
            b.sonuc.guncellenen += 1
        else:
            # IDEMPOTENT: yeni bilgi tasimayan satir ATLANIR (dosya
            # yeniden yuklenebilir) — ama satir no + sebeple (TESIS-10).
            b.atla(satir_no, "daire_no", "ice_aktarim_daire_zaten_kayitli")
        # (P243 §3) VAR OLAN DAIREYE DE SAKIN YAZILIR: "once daireleri
        # olustur, sonra sakinleri ekle" akisi tam da budur.
        await _daire_sakini(b, satir_no, d, unit_id=mevcut.id)
        return
    if b.yalniz_dogrula:
        # (E2E 2026-09 / TESIS-10) Dosyada ayni yeni daire ikinci kez: gercek
        # kosumda ikinci satir "var olan daire" dalina duser; kuru kosum da
        # oyle saymali.
        if daire in b.dosya_daire:
            if sayilar:
                b.sonuc.guncellenen += 1
            else:
                b.atla(satir_no, "daire_no", "ice_aktarim_daire_zaten_kayitli")
        else:
            b.sonuc.olusan += 1
        b.dosya_daire.add(daire)
        await _daire_sakini(b, satir_no, d, unit_id=None)
        return
    u = Unit(tenant_id=b.user.tenant_id, no=daire, blok=blok, **sayilar)
    b.db.add(u)
    try:
        await b.db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    b.yarat("unit", u.id)
    b.sonuc.olusan += 1
    await _daire_sakini(b, satir_no, d, unit_id=u.id)


async def _daire_sakini(
    b: _Bag, satir_no: int, d: dict, *, unit_id: uuid.UUID | None
) -> None:
    """(P243 §3) Daire satirindaki SAKIN sutunlari.

    =======================================================================
    NEDEN AYNI SATIRDA
    =======================================================================
    Yoneticinin elindeki liste zaten "A-1 / Ali Veli / ali@..."
    bicimindedir. Daireyi bir dosyadan, sakini baska dosyadan yuklemek
    ayni satiri ikiye bolup daire numarasini IKI KEZ yazdirmakti.

    =======================================================================
    BOS SUTUN HATA DEGIL
    =======================================================================
    Bos daire de bir gercektir; o satir yalniz daireyi yaratir. Hata
    yalniz YARIM doldurulmus satirda uretilir (ad var e-posta yok gibi) —
    sessizce yarim kisi yaratmak, sahiplenilemeyen bir hesap birakirdi.
    """
    ad = _metin(d, "sakin_ad")
    eposta = _metin(d, "sakin_eposta")
    if not ad and not eposta:
        return
    if not eposta:
        # E-POSTA KIMLIKTIR (P197) ve davetin TEK kanalidir.
        b.hata(satir_no, "sakin_eposta", "zorunlu_alan_eksik")
        return
    if not ad:
        b.hata(satir_no, "sakin_ad", "zorunlu_alan_eksik")
        return
    # KISI TURUNUN KENDISI CAGRILIYOR: ad/e-posta dogrulama, davet
    # gonderimi, rol esleme ve daire bagi ORADA yazili. Ikinci bir kopya,
    # birinde duzeltilen kuralin otekinde eskimesi demekti.
    await _uygula_kisi(
        b,
        satir_no,
        {
            "ad": ad,
            "eposta": eposta,
            "telefon": _metin(d, "sakin_telefon"),
            "blok": _metin(d, "blok"),
            "daire_no": _metin(d, "daire_no"),
            "rol_tipi": _metin(d, "rol_tipi"),
        },
        daire_hazir=True,
    )


# ---------------------------------- kisi ------------------------------------ #
async def _uygula_kisi(
    b: _Bag, satir_no: int, d: dict, *, daire_hazir: bool = False
) -> None:
    """`daire_hazir`: daire AYNI SATIRDA yaratiliyor (P243 §3).

    KURU KOSUMDA DAIRE HENUZ YAZILMAMISTIR. Bayrak olmasaydi onizleme,
    kusursuz bir dosya icin "daire bulunamadi" derdi ve P193 kurali
    geregi TUM aktarim iptal olurdu — yani ozellik kendi kendini
    engellerdi. (Bu tam olarak yasandi ve olculdu.)
    """
    ad = _metin(d, "ad")
    if not ad:
        b.hata(satir_no, "ad", "zorunlu_alan_eksik")
        return

    # (P234 §2) TELEFON OPSIYONEL — gerekce tur tanimindaki notta.
    # Doldurulduysa BICIMI dogrulanir: sessizce bozuk numara yazmak,
    # sonradan hicbir kanaldan ulasilamayan bir kayit birakirdi.
    tel_ham = _metin(d, "telefon")
    telefon: str | None = None
    if tel_ham:
        try:
            telefon = normalize_phone(tel_ham)
        except ValueError:
            b.hata(satir_no, "telefon", "telefon_bicimi")
            return

    # (P234 §2) `malik_oturan` UCUNCU BIR ROL DEGIL: malik + oturuyor.
    # Kullanicinin yazma bicimleri (tire/alt tire/bosluk) normallestirilir —
    # "malik-oturan" yazip hata almak, sutunun kendisini kullanilmaz kilardi.
    ham_rol = (_metin(d, "rol_tipi") or "").lower().replace("-", "_")
    ham_rol = "_".join(ham_rol.split()) or None
    oturuyor = ham_rol == "malik_oturan"
    rol = "malik" if oturuyor else ham_rol
    if rol not in (None, "malik", "kiraci"):
        b.hata(satir_no, "rol_tipi", "gecersiz_rol_tipi")
        return

    # (P193 §1) E-POSTA ZORUNLU — gerekce tur tanimindaki notta.
    eposta = _metin(d, "eposta") or None
    if eposta is None:
        b.hata(satir_no, "eposta", "zorunlu_alan_eksik")
        return
    if not _EPOSTA_KALIBI.match(eposta):
        b.hata(satir_no, "eposta", "eposta_gecersiz")
        return

    # (P234 §2) MUKERRER KONTROLU IKI ANAHTARA BAKAR.
    #
    # Once yalniz TELEFONA bakiliyordu ve telefon zorunluydu. Telefon
    # opsiyonel olunca o kontrol telefonsuz satirlarda HIC CALISMAZDI:
    # ayni dosya iki kez yuklense ayni kisi iki kez acilirdi ve
    # "idempotent: var olan kayit ATLANIR" sozu sessizce bozulurdu.
    #
    # ANAHTARLARIN KAPSAMI FARKLI (P228'de olculdu ve belgelendi):
    #   * telefon  -> PLATFORM GENELINDE benzersiz,
    #   * e-posta  -> TESIS ICINDE benzersiz.
    # Bu yuzden e-posta sorgusu TENANT'A daraltilir; daraltmazsak baska
    # bir tesisin ayni adresli kullanicisi yuzunden satiri atlardik.
    # (E2E 2026-09 / TESIS-10) DOSYA ICI YINELEME — iki kosumda da AYNI.
    # Ikinci satir HATADIR (satir no'suyla, ilk satiri da soyleyerek):
    # sessizce atlamak, yoneticinin dosyada ayni numarayi iki kisiye
    # yazdigini hic fark etmemesi demekti.
    eposta_k = eposta.lower()
    if eposta_k in b.dosya_eposta:
        b.hata(satir_no, "eposta", "ice_aktarim_dosyada_yineleniyor",
               satir=b.dosya_eposta[eposta_k])
        return
    if telefon and telefon in b.dosya_telefon:
        b.hata(satir_no, "telefon", "ice_aktarim_dosyada_yineleniyor",
               satir=b.dosya_telefon[telefon])
        return
    b.dosya_eposta[eposta_k] = satir_no
    if telefon:
        b.dosya_telefon[telefon] = satir_no

    daire_no = _metin(d, "daire_no")
    blok = _metin(d, "blok")

    kosullar = [func.lower(AppUser.email) == eposta_k]
    if telefon:
        kosullar.append(AppUser.telefon == telefon)
    var = (
        await b.db.execute(
            select(AppUser.id, AppUser.ad, AppUser.email, AppUser.telefon).where(
                or_(*kosullar),
                AppUser.tenant_id == b.user.tenant_id,
            )
        )
    ).first()
    if var is None and telefon:
        # Telefon GLOBAL benzersiz: baska tesiste ayni numara varsa
        # olusturma 409 verir. (E2E 2026-09 / TESIS-10) Eskiden sessizce
        # "zaten var" sayiliyordu; oysa bu tesiste o kisi YOK — satir
        # hicbir zaman yazilamaz ve yonetici bunu bilmeli: HATA.
        baska = (
            await b.db.execute(
                select(AppUser.id).where(AppUser.telefon == telefon)
            )
        ).first()
        if baska is not None:
            b.hata(satir_no, "telefon", "ice_aktarim_telefon_baska_kisi")
            return
    if var is not None:
        # (E2E 2026-09 / TESIS-10) "AYNI KISI" ile "CAKISAN KISI" AYRILDI.
        #
        # Olculen: farkli ad + farkli daire, yalniz telefonu/e-postasi
        # baska bir sakinle ayni satir "zaten var" sayacina dusuyordu.
        # Idempotent yeniden yukleme (ayni ad; daire verildiyse o daireye
        # zaten bagli) ATLANIR ve sebebiyle listelenir; geri kalani
        # HATADIR — dosyadaki kisi yazilmadi ve yazilamaz.
        ayni_ad = (var.ad or "").strip().casefold() == ad.strip().casefold()
        bagli = True
        if daire_no:
            sorgu = (
                select(UnitResident.id)
                .join(Unit, Unit.id == UnitResident.unit_id)
                .where(
                    UnitResident.user_id == var.id,
                    UnitResident.bitis.is_(None),
                    Unit.no == daire_no,
                )
            )
            if blok:
                sorgu = sorgu.where(Unit.blok == blok)
            # Kuru kosumda ayni satirin YENI dairesi henuz yok -> bagli
            # degil; gercek kosumda da kisi o yeni daireye BAGLANMAZ. Iki
            # kosum ayni sonucu verir (cakisma).
            bagli = (await b.db.execute(sorgu)).first() is not None
        if ayni_ad and bagli:
            b.atla(satir_no, "eposta", "ice_aktarim_kisi_zaten_kayitli")
        else:
            cakisan = (
                "eposta"
                if (var.email or "").lower() == eposta_k
                else "telefon"
            )
            b.hata(satir_no, cakisan, "ice_aktarim_kisi_cakisiyor")
        return

    unit_id: uuid.UUID | None = None
    if daire_no:
        sorgu = select(Unit.id).where(Unit.no == daire_no)
        if blok:
            # (P234 §2) BLOK VERILDIYSE ARAMA DARALIR. Verilmezse eski
            # davranis korunur — mevcut dosyalar bozulmasin.
            sorgu = sorgu.where(Unit.blok == blok)
        satir = (await b.db.execute(sorgu)).first()
        if satir is None and daire_hazir:
            # AYNI SATIRIN DAIRESI: kuru kosumda henuz yazilmadi.
            # Gercek kosumda ZATEN yazilmis olur ve bu dal calismaz.
            # (E2E 2026-09 / TESIS-10) Kisi gercek kosumda OLUSACAK; kuru
            # kosum da saymali (eskiden sayilmiyordu: onizleme != sonuc).
            anahtar = (daire_no, blok, rol)
            if anahtar in b.dosya_daire_rol:
                b.hata(satir_no, "daire_no", "daire_zaten_dolu")
                return
            b.dosya_daire_rol.add(anahtar)
            b.sonuc.olusan += 1
            return
        if satir is None:
            # DAIRE YOKSA HATA, sessiz atlama DEGIL: kullanici sakini
            # daireye baglamak istedi ve baglanmadigini bilmeli.
            b.hata(satir_no, "daire_no", "daire_bulunamadi")
            return
        unit_id = satir[0]
        # (P154 / Asama 5) DAIREDE HER ROLDEN TEK HESAP — kilitli kural 4,
        # rol basina uygulaniyor (goc 0049; karar rapor §4.51).
        #
        # EXCEL'DE AYNI DAIREYE AYNI ROLDEN IKI SATIR GELIRSE: ILKI
        # KAZANIR, ikincisi HATA olarak raporlanir. Uzerine yazmak, ilk
        # satiri kullaniciya hic soylemeden atmak olurdu; ikisini de
        # baglamak ise kurali cignerdi. Dosyanin sirasi kullanicinin
        # kendi sirasidir.
        #
        # FARKLI ROL (malik + kiraci) GECER ve bu dogru: `hedef_sec`
        # tam olarak o durumu cozmek icin var.
        from .units import daire_rolu_dolu_mu

        # (E2E 2026-09 / TESIS-10) Dosya ici ayni daire+rol: kuru kosum
        # sakini yazmadigi icin DB kontrolu ikinciyi goremiyordu.
        anahtar = (daire_no, blok, rol)
        if anahtar in b.dosya_daire_rol:
            b.hata(satir_no, "daire_no", "daire_zaten_dolu")
            return
        if await daire_rolu_dolu_mu(b.db, unit_id, rol):
            b.hata(satir_no, "daire_no", "daire_zaten_dolu")
            return
        b.dosya_daire_rol.add(anahtar)

    if b.yalniz_dogrula:
        b.sonuc.olusan += 1
        return

    kisi = AppUser(
        tenant_id=b.user.tenant_id, ad=ad, telefon=telefon, email=eposta,
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
            # (P234 §2) `malik_oturan` burada iki alana ayrilir.
            oturuyor=oturuyor,
        )
        b.db.add(ur)
        await b.db.flush()
        b.yarat("unit_resident", ur.id)
    # (P186 §3.1) DAVET: tekil eklemeyle AYNI akis — parolasiz acilan kisiye
    # jetonlu kayit bagi (SMS + varsa HTML e-posta) gonderilir. Eskiden Excel
    # ile eklenenlere HIC davet gitmiyordu (kabul 9). Gonderim hatasi kisiyi
    # olusturmayi geri ALMAZ: hesap acildi, yonetici gitmeyen daveti panelden
    # yeniden gonderebilir.
    # (P193 §1) DAVET SONUCU SAYILIYOR. Onceden donus degeri atiliyordu:
    # yonetici "50 kisi eklendi" goruyor ama kacina davet ULASTIGINI
    # bilmiyordu. Gonderim hatasi kisiyi olusturmayi geri ALMAZ — hesap
    # acildi, davet panelden yeniden gonderilebilir.
    if await davet_olustur_ve_gonder(
        b.db, user=kisi, tenant_ad=b.tenant_ad, gonderen_id=b.user.id,
        dil=b.dil,
    ):
        b.sonuc.davet_gonderildi += 1
    else:
        b.sonuc.davet_basarisiz += 1
        b.sonuc.davet_hatalari.append({
            "satir_no": satir_no, "alan": "eposta",
            "hata": hata_metni("davet_gonderilemedi", b.dil),
        })
    # (P243 §3) AYNI SATIRDAKI ARAC — `arac` turu buraya katlandi.
    #
    # KISI YARATILDIKTAN SONRA: plaka hatasi kisiyi geri ALMAZ. Ters
    # olsaydi bir yazim hatasi yuzunden kisi de eklenmezdi ve yonetici
    # "50 satirin 3'u neden atlandi" diye ararrdi.
    await _arac_satiri(b, satir_no, d, unit_id=unit_id)
    b.sonuc.olusan += 1


async def _arac_satiri(
    b: _Bag, satir_no: int, d: dict, *, unit_id: uuid.UUID | None
) -> None:
    """Satirdaki plaka doluysa arac kaydi yaratir. Bos ise SESSIZ.

    Sessizlik burada dogru: aracsiz kisi OLAGAN durumdur, eksik veri
    degil. Hata yalniz DOLU ama gecersiz bir plakada uretilir.
    """
    plaka_ham = _metin(d, "plaka")
    if not plaka_ham:
        return
    plaka = plaka_ham.replace(" ", "").upper()
    var = (
        await b.db.execute(select(AracKayit.id).where(AracKayit.plaka == plaka))
    ).first()
    if var is not None:
        return  # ZATEN KAYITLI: ikinci kez eklemek cakisma uretirdi
    if b.yalniz_dogrula:
        return
    a = AracKayit(
        tenant_id=b.user.tenant_id, plaka=plaka, unit_id=unit_id,
        marka=_metin(d, "arac_marka") or None,
        model=_metin(d, "arac_model") or None,
    )
    b.db.add(a)
    try:
        await b.db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    b.yarat("arac_kayit", a.id)


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
        b.atla(satir_no, "plaka", "ice_aktarim_plaka_zaten_kayitli")
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
            # (P193 §6) Arsa payi ve metrekare OPSIYONEL sutunlar. Var
            # olan daireye de yazilir (bkz. `_uygula_daire`): asil akis
            # "once toplu olustur, sonra paylari yukle"dir.
            _Alan("arsa_payi", ornek="0,0125"),
            _Alan("metrekare", ornek="120"),
            # =============================================================
            # (P243 §3) SAKIN SUTUNLARI — "DAIRELER VE SAKINLER"
            # =============================================================
            # Yoneticinin elindeki liste zaten "A-1 / Ali Veli /
            # ali@..." bicimindedir. Daireyi bir dosyadan, sakini baska
            # dosyadan yuklemek, ayni satiri ikiye bolup daire numarasini
            # IKI KEZ yazdirmakti.
            #
            # BOS BIRAKILABILIR: bos daire de bir gercektir ve o satir
            # yalniz daireyi yaratir.
            _Alan("sakin_ad", ornek="Ali Veli"),
            _Alan("sakin_eposta", ornek="ali@ornek.com"),
            _Alan("sakin_telefon", ornek="+905321112233"),
            _Alan("rol_tipi", ornek="malik | kiraci | malik_oturan"),
        ),
        _uygula_daire,
        "iceAktarimDaireAciklama",
    ),
    "kisi": _Tur(
        "kisi",
        (
            _Alan("ad", zorunlu=True, ornek="Ali Veli"),
            # =============================================================
            # (P234 §2) TELEFON ZORUNLULUGU KALDIRILDI — OLCULEN CELISKI
            # =============================================================
            # P212-ek §2'de TEKIL ekleme ucunda (`UserCreate.telefon`)
            # zorunluluk KALDIRILMISTI; gerekcesi: `uq_app_user_telefon`
            # telefonu PLATFORM GENELINDE benzersiz kilar, yani ayni kisi
            # ikinci bir tesise ancak UYDURMA bir numarayla eklenebiliyordu.
            # Kimlik P197'den beri E-POSTADIR.
            #
            # Excel yolu o degisiklikten HABERSIZ kaldi: ayni veri iki
            # farkli kuralla giriliyordu — P193 §1'in duzelttigi kusurun
            # TERS YONDE aynisi. Telefonu olmayan bir sakin listesi
            # yukleyen yonetici her satirda "zorunlu_alan_eksik" goruyordu.
            #
            # BICIM DENETIMI DURUYOR: doldurulduysa gecerli olmali.
            _Alan("telefon", ornek="+905321112233"),
            # (P193 §1) E-POSTA ZORUNLU OLDU.
            #
            # P186'da opsiyoneldi ve gerekcesi "verilirse HTML e-posta da
            # gider, yoksa yalniz SMS"ti. O gerekce SMS acikken gecerliydi;
            # SMS varsayilan olarak KAPALI (`settings.sms_aktif=False`) ve
            # kapaliyken HIC denenmiyor. Yani e-postasiz eklenen kisiye
            # davet HICBIR KANALDAN gitmiyor ve Tesis ID'yi asla
            # ogrenemiyor — hesap acilmis ama sahiplenilemez durumda
            # kaliyor. Tekil ekleme (`UserCreate.email`) zaten zorunlu
            # tutuyordu; ayni veri iki farkli kuralla giriliyordu.
            _Alan("eposta", zorunlu=True, ornek="ali@ornek.com"),
            # (P234 §2) BLOK SUTUNU — P220'de blok bazli duzen geldi.
            #
            # `daire` turunde blok ZATEN vardi; `kisi` turunde yoktu ve
            # daire YALNIZ numarasindan araniyordu. Iki blokta ayni
            # numarali daire varsa esleme RASTGELE bir satira dusuyordu.
            # Blok verilirse arama ONA GORE daraltilir; verilmezse eski
            # davranis (yalniz numara) korunur — mevcut dosyalar bozulmasin.
            _Alan("blok", ornek="A"),
            _Alan("daire_no", ornek="A-1"),
            # (P234 §2) UCUNCU DEGER KABUL EDILIR: `malik_oturan`.
            #
            # P218'de olculmustu: "malik ve oturan" UCUNCU BIR ROL DEGIL,
            # malikin oturuyor olmasidir (`rol_tipi='malik'` +
            # `oturuyor=true`). Modele ucuncu bir enum degeri eklemek
            # "malikler" sorgusunu iki degeri birden aramaya zorlardi ve
            # unutuldugu yerde sessizce yanlis calisirdi.
            #
            # Ama KULLANICI Excel'e "malik-oturan" yazar. Sutunda ucunu de
            # kabul edip modele DOGRU cevirmek, kullaniciya modelin ic
            # ayrimini ogretmekten iyidir.
            _Alan("rol_tipi", ornek="malik | kiraci | malik_oturan"),
            # =============================================================
            # (P243 §3) ARAC TURU BURAYA KATLANDI
            # =============================================================
            # Once AYRI bir `arac` turu vardi ve yonetici ayni insan icin
            # IKI dosya hazirliyordu: once kisiler, sonra plakalar — ve
            # ikincisinde daireyi TEKRAR yaziyordu. Arac bir KISIYE (ya
            # da daireye) aittir; ayri bir tur, ayni satiri ikiye bolmekti.
            #
            # BOS BIRAKILABILIR: aracsiz kisi olagan durumdur.
            _Alan("plaka", ornek="34ABC123"),
            _Alan("arac_marka", ornek="Fiat"),
            _Alan("arac_model", ornek="Egea"),
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
    # (P243 §3) "arac" TURU LISTEDEN KALDIRILDI — yetenegi `kisi`ye
    # katlandi (plaka/marka/model sutunlari). Kod SILINMEDI: `ice_aktarim`
    # gecmisinde `tur='arac'` satirlar var ve goc CHECK'i onlari tutuyor;
    # kodu kaldirmak gecmis kayitlari okunamaz kilardi. Yalnizca YENI
    # aktarimlarda secilemiyor.
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

    tenant_ad = (
        await db.execute(select(Tenant.ad).where(Tenant.id == user.tenant_id))
    ).scalar_one_or_none() or ""
    dil = istek_dili(accept_language)

    async def _kosum(yalniz_dogrula: bool) -> tuple[_Bag, IceAktarimSonuc]:
        bag = _Bag(
            db=db, user=user, dil=dil, yalniz_dogrula=yalniz_dogrula,
            sonuc=IceAktarimSonuc(), tenant_ad=tenant_ad,
        )
        for satir in body.satirlar:
            await t.uygula(bag, satir.satir_no, satir.degerler)
        bag.sonuc.satir_sayisi = len(body.satirlar)
        return bag, bag.sonuc

    if body.yalniz_dogrula:
        _, sonuc = await _kosum(True)
        return sonuc

    # (P193 §1) ONCE KURU KOSUM, SONRA YAZMA.
    #
    # Sorunlu satir varken aktarimi durdurmak icin hatalari YAZMADAN ONCE
    # bilmek gerekiyor. Tek gecisi SAVEPOINT'e alip geri sarmak
    # yetmezdi: kisi aktariminda satir basina DAVET E-POSTASI gidiyor ve
    # veritabanini geri almak gonderilmis bir e-postayi geri getirmez.
    # Kuru kosum hicbir yan etki uretmez.
    _, kuru = await _kosum(True)
    if kuru.hatali > 0 and not body.sorunlulari_atla:
        kuru.uygulanmadi = True
        return kuru

    b, _ = await _kosum(False)

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
        meta={"tur": tur, "olusan": b.sonuc.olusan, "hatali": b.sonuc.hatali,
              "davet_gonderildi": b.sonuc.davet_gonderildi,
              "davet_basarisiz": b.sonuc.davet_basarisiz},
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
