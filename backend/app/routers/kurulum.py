"""(P154 / Asama 7.3) KURULUM SIHIRBAZI — sekiz adimin durumu.

===========================================================================
TEK UC, SEKIZ SAYIM — istemcide sekiz istek DEGIL
===========================================================================
Brief: "Adim adim kurulum sihirbazi: Blok → Kat/daire → Daire tipleri →
Sakinler → Personel → Gorev alanlari → NFC noktalari → Aidat tanimi.
Ilerleme gostergesi, atlanabilir adimlar, yarim birakip devam edebilme,
tamamlananlarin kalici isaretlenmesi, bitince ayarlardan tekrar
acilabilme."

Sihirbaz her adim icin "yapildi mi" sorusunu yanitlamali. Istemci bunu
sekiz ayri liste ucuna giderek de cikarabilirdi ama:
  * sekiz gidis-donus olurdu (sihirbaz ilk acilista bekler),
  * uclarin yanit SEKILLERI ayni degil (kimi `meta.total` doner, kimi duz
    liste) — istemci sekiz farkli ayiklama yazardi,
  * ve en onemlisi "bu adim bitti mi" KARARI sekiz yere dagilirdi.

Bu yuzden karar SUNUCUDA ve TEK YERDE: asagidaki `ADIMLAR` tablosu.

===========================================================================
TAMAMLANMA SAYILIR, SAKLANMAZ
===========================================================================
Hicbir adim icin "tamamlandi" bayragi tutulmuyor. Her adimin ciktisi zaten
veritabaninda: blok satiri, daire, daire tipi, sakin, personel, gorev
kategorisi, NFC noktasi, aidat tahakkuku. Bayrak tutmak ayni gercegin
IKINCI kaynagini uretir ve ayrisir — yonetici tek blogunu silince bayrak
"tamamlandi" demeye devam ederdi.

ATLAMA ise veriden turetilemez ve `tenant.kurulum_atlanan`da durur
(goc 0044'un basligi bunu anlatiyor).

===========================================================================
YETKI: KURULUM YONETIM ISIDIR
===========================================================================
Okuma da yazma da admin + yonetici. Denetci SALT-OKUR bir roldur ve
kurulum onun isi degildir; saha ve sakin zaten bu ekranlari gormez.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Awaitable, Callable

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql import Select

from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..gonderim import saglayici as kanal_saglayicisi, tenant_ayari
from ..mesajlasma import LogEpostaSaglayici
from ..models import (
    AppUser,
    BuildingBlock,
    Checkpoint,
    DuesAssessment,
    Kasa,
    OrtakAlan,
    PersonelKayit,
    SayacAna,
    TaskCategory,
    Tenant,
    Unit,
    UnitTip,
)
from ..schemas import KurulumAtlaIstek, KurulumDurumOut, KurulumAdimOut

router = APIRouter(prefix="/kurulum", tags=["kurulum"])

_YONETIM = require_role("admin", "yonetici")


@dataclass(frozen=True)
class _Adim:
    """Bir kurulum adimi.

    `sayim` bir SORGU URETICISIDIR, sorgu DEGIL: sorgular istek aninda
    kurulmali (oturum/tenant baglamı o zaman belli).

    (P193 §2) `zorunlu`: adim MINIMUM CALISIR KURULUMUN parcasi mi.
    Karar burada, istemcide degil — "bu tesis calisir hâlde mi" sorusu
    tamamlanma sorusuyla ayni tabloya ait. Istemci bunu kendi listesinden
    turetseydi, yeni bir adim eklendiginde iki liste ayrisirdi.

    (P193 §2) `olcu`: SAYILAMAYAN adimlar icin. E-posta gonderimi bir
    tablo satiri degildir — tesis ayari YOKSA genel (ENV) ayardan
    calisiyor olabilir. Bu adimin cevabi ancak saglayici secimi
    calistirilarak bulunur.
    """

    kod: str
    sayim: Callable[[], Select] | None = None
    zorunlu: bool = False
    olcu: Callable[[AsyncSession, Tenant], Awaitable[int]] | None = None


def _say(model, *kosullar) -> Callable[[], Select]:
    return lambda: select(func.count()).select_from(model).where(*kosullar)


async def _eposta_hazir(db: AsyncSession, tenant: Tenant) -> int:
    """E-posta gonderimi CALISIR durumda mi (1) degil mi (0).

    OLCUT `routers/mesajlar.py`teki rozetle AYNI: saglayici secimi
    calistirilir ve LOG saglayicisi donerse gonderim yok demektir. Ayri
    bir olcut yazmak ("smtp_host dolu mu"), tesis ayari bos ama ENV'de
    calisan bir SMTP varken sihirbazi YANLIS uyarmak olurdu — bu tam da
    P172 §1'de kapatilan kusur sinifi.
    """
    ayar = await tenant_ayari(db, tenant.id)
    return 0 if isinstance(kanal_saglayicisi("eposta", ayar), LogEpostaSaglayici) else 1


#: ADIMLAR — SIRA ANLAMLIDIR: blok olmadan daire,
#: daire olmadan sakin, sakin olmadan aidat tanimlanamaz. Sihirbaz bu
#: sirayi cizer; kullanici yine de istedigi adima gidebilir (adimlar
#: KILITLI DEGIL — kilitlemek, yarim birakip devam edebilmeyi engellerdi).
ADIMLAR: tuple[_Adim, ...] = (
    _Adim("blok", _say(BuildingBlock), zorunlu=True),
    _Adim("daire", _say(Unit), zorunlu=True),
    _Adim("daire_tipi", _say(UnitTip), zorunlu=True),
    # SAKIN ve PERSONEL ayni tabloda ama AYRI adimlar: brief ikisini ayri
    # sayiyor ve gercekten ayri isler (biri tasinanlari girer, oteki
    # calisanlari).
    _Adim("sakin", _say(AppUser, AppUser.role == "resident"), zorunlu=True),
    # (P193 §2) E-POSTA — BURADA, SAKINDEN HEMEN SONRA.
    #
    # Kurulumun en kritik bagimliligi ve sihirbazin hicbir adiminda
    # gecmiyordu (rehber, eksik 13). Davetler e-postayla gidiyor; e-posta
    # calismiyorsa yonetici yuzlerce hesap acar ve HICBIRI giremez —
    # ustelik bunu ancak birisi sikayet edince ogrenir.
    #
    # SIRA ANLAMLI: sakin adiminin HEMEN ARDINDA, cunku ilk toplu davet
    # oradan cikar. Once sakinleri girip sonra "e-postam calismiyormus"
    # demek, davetleri tek tek yeniden gondermek demektir.
    _Adim("eposta", zorunlu=True, olcu=_eposta_hazir),
    _Adim("personel", _say(PersonelKayit)),
    # "Gorev alanlari" = gorev KATEGORILERI (P153: sabit tip enum'u
    # kaldirildi, tip artik yonetici-tanimli kategoridir).
    _Adim("gorev_alani", _say(TaskCategory)),
    _Adim("nfc_noktasi", _say(Checkpoint)),
    # (P193 §2) KASA — AIDATTAN ONCE ve ZORUNLU.
    #
    # Rehber, eksik 11: tahakkuk yazmak yetmiyor, tahsilat bir kasaya
    # yazilir. Kasasiz bir tesiste yonetici ilk tahsilati girmeye
    # calisinca ogreniyordu. Adim, ogrenmenin ilk tahsilattan ONCE
    # olmasi icin buraya kondu.
    _Adim("kasa", _say(Kasa), zorunlu=True),
    # "Aidat tanimi": tahakkuk URETILMIS mi. Daire tipindeki varsayilan
    # tutar TEK BASINA yetmez — tanimli ama hic isletilmemis bir aidat,
    # kimseye borc yazmaz.
    _Adim("aidat", _say(DuesAssessment), zorunlu=True),
    # (P193 §2) ISTEGE BAGLI MODUL TANIMLARI (rehber, eksik 12).
    #
    # Bu iki modul tanim yapilmadan SESSIZCE BOS gorunuyor: rezervasyon
    # ekrani "alan yok" der, sayac okuma ekrani bos liste. Kullanici
    # modulun bozuk oldugunu sanir. Zorunlu DEGILLER (havuzu olmayan bir
    # site de calisan bir tesistir) ama gorunur olmalilar — atlama
    # dugmesi zaten burada.
    _Adim("rezervasyon_alani", _say(OrtakAlan, OrtakAlan.aktif.is_(True))),
    _Adim("sayac", _say(SayacAna)),
)

#: MINIMUM CALISIR KURULUM — `zorunlu=True` adimlarin sayisi. Sihirbazin
#: sonundaki ozet bunu kullanir: "7 adimin 5'i tamam" degil, "calisir hâle
#: gelmek icin SU 2 sey eksik ve sunu engelliyor".
ZORUNLU_KODLAR = frozenset(a.kod for a in ADIMLAR if a.zorunlu)

_KODLAR = frozenset(a.kod for a in ADIMLAR)


async def _durum(db: AsyncSession, tenant: Tenant) -> KurulumDurumOut:
    atlanan = set(tenant.kurulum_atlanan or [])
    adimlar: list[KurulumAdimOut] = []
    for a in ADIMLAR:
        if a.olcu is not None:
            sayi = await a.olcu(db, tenant)
        else:
            assert a.sayim is not None
            sayi = (await db.execute(a.sayim())).scalar_one()
        adimlar.append(
            KurulumAdimOut(
                kod=a.kod,
                sayi=sayi,
                tamam=sayi > 0,
                atlandi=a.kod in atlanan,
                zorunlu=a.zorunlu,
            )
        )
    # ILERLEME: atlanan adim da "gecilmis" sayilir. Aksi hâlde bilincli
    # atlayan bir tesis %100'e ASLA ulasamaz ve gosterge kalici bir
    # sitem hâline gelirdi.
    gecilen = sum(1 for a in adimlar if a.tamam or a.atlandi)
    # (P193 §2) EKSIK ZORUNLULAR — ATLAMA BURADA SAYILMAZ.
    #
    # Bilincli atlama ILERLEME gostergesini rahatlatir (yukaridaki not)
    # ama "bu tesis calisir mi" sorusunu degistirmez: kasasi olmayan bir
    # tesis, yonetici adimi atladi diye tahsilat yapamaz. Ozet bu yuzden
    # yalniz `tamam`a bakar.
    eksik = [a.kod for a in adimlar if a.zorunlu and not a.tamam]
    return KurulumDurumOut(
        adimlar=adimlar,
        toplam=len(adimlar),
        gecilen=gecilen,
        zorunlu_toplam=len(ZORUNLU_KODLAR),
        eksik_zorunlular=eksik,
        calisir=not eksik,
    )


@router.get("", response_model=KurulumDurumOut)
async def durum(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> KurulumDurumOut:
    """Sekiz adimin durumu — sayim + atlanma."""
    tenant = (
        await db.execute(select(Tenant).where(Tenant.id == user.tenant_id))
    ).scalar_one()
    return await _durum(db, tenant)


@router.patch("", response_model=KurulumDurumOut)
async def atla(
    body: KurulumAtlaIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> KurulumDurumOut:
    """Bir adimi atla / atlamayi geri al.

    GERI ALINABILIR olmasi sart: "NFC yok" diyen bir tesis sonradan NFC
    kurabilir ve o zaman adimi geri getirebilmeli. Tek yonlu bir atlama,
    sihirbazi bir daha tam gosteremezdi.
    """
    if body.kod not in _KODLAR:
        raise APIError(422, "validation_error", "kurulum_adimi_gecersiz")
    tenant = (
        await db.execute(select(Tenant).where(Tenant.id == user.tenant_id))
    ).scalar_one()
    mevcut = set(tenant.kurulum_atlanan or [])
    if body.atla:
        mevcut.add(body.kod)
    else:
        mevcut.discard(body.kod)
    # SIRA KORUNUR: kumeyi oldugu gibi yazmak, her yazmada JSON dizisinin
    # sirasini degistirir ve `goc-uyum` disi bir gurultu uretirdi.
    tenant.kurulum_atlanan = [a.kod for a in ADIMLAR if a.kod in mevcut]
    await db.flush()
    return await _durum(db, tenant)
