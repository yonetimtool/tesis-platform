"""(P252) PERSONEL MAASI — calisma bilgileri ve otomatik maas gideri.

Kararlar ve gerekceler: `docs/P252-kararlar.md` §1–§2.

* ODEME GUNU 1–31. O ayda bu gun yoksa (Subat 29–31, 30 cekan ayda 31)
  odeme AYIN SON GUNU yapilir (`odeme_tarihi`).
* ILK DONEM: maas tanimlandiktan SONRAKI ilk odeme tarihinin ayi
  (`ilk_donem`). Gecmise donuk gider yazilmaz — bugun maasi girilen bes
  yillik personel icin 60 aylik gider olusmasin.
* KISMI AY gun oranli (takvim gunu): ise giris ayinda giristen ay sonuna,
  cikis ayinda ay basindan cikisa. Kismi tutar her zaman ONAY BEKLEYEN
  yazilir (yonetici onaylamadan once duzeltebilir).
* IKI KEZ YAZILMAZ: defter anahtari `maas:<kart>:<YYYY-MM>` +
  `(tenant_id, idempotency_key, idem_satir)` benzersizlik kisiti (goc
  0028). Kartin `son_maas_donem` damgasi ilerler.
* TELAFI: gorev kacirilan aylari SIRAYLA yazar (ilk donemden bugune).
"""
from __future__ import annotations

import calendar
import uuid
from dataclasses import dataclass
from datetime import date

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from . import defter
from .belge_no import belge_no_ata
from .crud_helpers import is_unique_violation
from .models import FinansalHareket, GelirGiderTanim, PersonelKayit, Tenant

#: Sistem kalemleri — ADINDAN degil KODUNDAN bulunur (goc 0167).
KOD_MAAS = "personel_maasi"
KOD_MESAI = "fazla_mesai"
SISTEM_KALEM_ADI = {KOD_MAAS: "Personel maaşı", KOD_MESAI: "Fazla mesai"}
#: Seffaflikta (sakinin gordugu) bu kalemler TEK satirda birlesir.
PERSONEL_KODLARI = (KOD_MAAS, KOD_MESAI)
PERSONEL_GIDERLERI_ADI = "Personel giderleri"

AY_ADLARI = (
    "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
    "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık",
)


# ------------------------------------------------------------------ saf islevler
def donem(gun: date) -> str:
    return f"{gun.year}-{gun.month:02d}"


def donem_coz(d: str) -> tuple[int, int]:
    y, a = d.split("-")
    return int(y), int(a)


def sonraki_donem(d: str) -> str:
    y, a = donem_coz(d)
    return f"{y + (a == 12)}-{1 if a == 12 else a + 1:02d}"


def donem_adi(d: str) -> str:
    """"2026-10" -> "Ekim 2026" (defter aciklamasi Turkce saklanir)."""
    y, a = donem_coz(d)
    return f"{AY_ADLARI[a - 1]} {y}"


def odeme_tarihi(d: str, gun: int) -> date:
    """Donemin odeme tarihi — gun o ayda yoksa AYIN SON GUNU."""
    y, a = donem_coz(d)
    return date(y, a, min(gun, calendar.monthrange(y, a)[1]))


def ilk_donem(tanim_gunu: date, odeme_gunu: int) -> str:
    """Maasin tanimlandigi gunden SONRAKI (ya da ayni gun) ilk odeme ayi.

    Bugun ayin 20'si ve odeme gunu 5 ise bu ayin odemesi GECMISTE kalmistir
    (buyuk olasilikla elle odendi) — ilk otomatik donem gelecek ay.
    Odeme gunu bugunse BU AY yazilir.
    """
    d = donem(tanim_gunu)
    return d if odeme_tarihi(d, odeme_gunu) >= tanim_gunu else sonraki_donem(d)


@dataclass(frozen=True)
class DonemTutari:
    tutar_kurus: int
    kismi: bool
    calisilan_gun: int
    ay_gun: int


def donem_tutari(
    aylik_kurus: int, d: str, giris: date | None, cikis: date | None
) -> DonemTutari | None:
    """Donemin maas tutari — o ay HIC calismadiysa `None`.

    Gun orani: calisilan takvim gunu / ayin gun sayisi; kurusa yuvarlanir.
    """
    y, a = donem_coz(d)
    ay_gun = calendar.monthrange(y, a)[1]
    bas, son = date(y, a, 1), date(y, a, ay_gun)
    ilk = max(bas, giris) if giris else bas
    sonuncu = min(son, cikis) if cikis else son
    if ilk > sonuncu:
        return None
    gun = (sonuncu - ilk).days + 1
    if gun == ay_gun:
        return DonemTutari(aylik_kurus, False, gun, ay_gun)
    return DonemTutari(round(aylik_kurus * gun / ay_gun), True, gun, ay_gun)


def maas_aciklamasi(ad: str, d: str) -> str:
    return f"{ad} — {donem_adi(d)} maaşı"


# --------------------------------------------------------------- veritabani
async def sistem_kalemi(db: AsyncSession, tenant_id: uuid.UUID, kod: str) -> GelirGiderTanim:
    """Sistem kodlu gider kalemini getir; yoksa olustur.

    Ayni adli (yonetici acmis) bir kalem varsa ONA kod verilir — ikinci bir
    "Personel maasi" kalemi acmak, tanimlar listesinde ikiz uretirdi.
    """
    kalem = (
        await db.execute(select(GelirGiderTanim).where(GelirGiderTanim.sistem_kodu == kod))
    ).scalar_one_or_none()
    if kalem is not None:
        return kalem
    ad = SISTEM_KALEM_ADI[kod]
    kalem = (
        await db.execute(
            select(GelirGiderTanim).where(
                GelirGiderTanim.ad == ad,
                GelirGiderTanim.tip == "gider",
                GelirGiderTanim.sistem_kodu.is_(None),
            ).limit(1)
        )
    ).scalar_one_or_none()
    if kalem is not None:
        kalem.sistem_kodu = kod
    else:
        kalem = GelirGiderTanim(tenant_id=tenant_id, ad=ad, tip="gider", sistem_kodu=kod)
        db.add(kalem)
    await db.flush()
    return kalem


@dataclass
class MaasSonucu:
    yazilan: int = 0
    toplam_kurus: int = 0
    onay_bekleyen: int = 0
    #: donem -> (personel sayisi, toplam kurus) — bildirim ozeti icin.
    donemler: dict[str, list[int]] | None = None
    kartlar: list[str] | None = None


async def maaslari_isle(db: AsyncSession, tenant_id: uuid.UUID, bugun: date) -> MaasSonucu:
    """Odeme gunu gelmis (ya da gecmis, telafi) maaslari deftere yazar.

    Tesis ayari kapaliysa hicbir sey yapmaz. Bildirim ve gunluk CAGIRANIN
    (otomasyon) isidir; bu islev yalniz deftere yazar ve ozet dondurur.
    """
    sonuc = MaasSonucu(donemler={}, kartlar=[])
    tesis = (await db.execute(select(Tenant).where(Tenant.id == tenant_id))).scalar_one()
    if not tesis.maas_otomasyonu_aktif:
        return sonuc
    kartlar = (
        await db.execute(
            select(PersonelKayit).where(
                PersonelKayit.aktif.is_(True),
                PersonelKayit.maas_kurus.is_not(None),
                PersonelKayit.maas_kurus > 0,
                PersonelKayit.odeme_gunu.is_not(None),
                PersonelKayit.maas_ilk_donem.is_not(None),
            ).order_by(PersonelKayit.ad, PersonelKayit.id)
        )
    ).scalars().all()
    if not kartlar:
        return sonuc
    kalem = await sistem_kalemi(db, tenant_id, KOD_MAAS)
    bu_donem = donem(bugun)
    for kart in kartlar:
        d = kart.maas_ilk_donem
        if kart.son_maas_donem and kart.son_maas_donem >= d:
            d = sonraki_donem(kart.son_maas_donem)
        while d <= bu_donem and odeme_tarihi(d, kart.odeme_gunu) <= bugun:
            tutar = donem_tutari(kart.maas_kurus, d, kart.giris_tarihi, kart.cikis_tarihi)
            if tutar is None:
                # Giristen ONCE: sonraki aya gec. Cikistan SONRA: bu kart
                # bitti — damga ilerlemez, dongu biter (sonraki aylar hep bos).
                if kart.cikis_tarihi and odeme_tarihi(d, 1) > kart.cikis_tarihi:
                    break
                kart.son_maas_donem = d
                d = sonraki_donem(d)
                continue
            tarih = odeme_tarihi(d, kart.odeme_gunu)
            onayli = tesis.maas_otomatik_onay and not tutar.kismi
            hareket = FinansalHareket(
                tenant_id=tenant_id,
                tip="gider",
                yon="cikis",
                tutar_kurus=tutar.tutar_kurus,
                tarih=tarih,
                kasa_id=await defter.kasa_coz(db, tenant_id, kart.kasa_id),
                gelir_gider_tanim_id=kalem.id,
                user_id=kart.app_user_id,
                personel_kayit_id=kart.id,
                donem=d,
                durum="odendi" if onayli else "onay_bekliyor",
                aciklama=maas_aciklamasi(kart.ad, d)
                + (f" (kısmi: {tutar.calisilan_gun}/{tutar.ay_gun} gün)" if tutar.kismi else ""),
                belge_no=await belge_no_ata(db, tenant_id, "gider", None, tarih),
                idempotency_key=f"maas:{kart.id}:{d}",
                idem_satir=0,
            )
            try:
                async with db.begin_nested():
                    db.add(hareket)
                    await db.flush()
            except IntegrityError as exc:
                try:
                    db.expunge(hareket)
                except Exception:  # noqa: BLE001
                    pass
                if not is_unique_violation(exc):
                    raise
                # Zaten yazilmis (es zamanli kosum) — damgayi ilerlet.
                kart.son_maas_donem = d
                d = sonraki_donem(d)
                continue
            sonuc.yazilan += 1
            sonuc.toplam_kurus += tutar.tutar_kurus
            sonuc.onay_bekleyen += 0 if onayli else 1
            ozet = sonuc.donemler.setdefault(d, [0, 0])
            ozet[0] += 1
            ozet[1] += tutar.tutar_kurus
            sonuc.kartlar.append(str(kart.id))
            kart.son_maas_donem = d
            d = sonraki_donem(d)
    await db.flush()
    return sonuc
