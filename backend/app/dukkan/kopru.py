"""KOPRU — Dukkan'in Yonetiyor'a bakan TEK kapisi.

===========================================================================
BU DOSYANIN SOZLESMESI
===========================================================================
1. Dukkan paketindeki BASKA HICBIR modul Yonetiyor'u ithal edemez.
   Yalnizca bu dosya eder. Sinir tek yerde ve GORUNUR.
2. YALNIZ OKUMA. Bu dosyada yazma fonksiyonu YOKTUR ve olmayacaktir.
   (`tests/test_dukkan_kopru_siniri.py` bunu da olcuyor: INSERT/UPDATE/
   DELETE iceren bir SQL metni burada bulunursa test duser.)
3. Her fonksiyon NE DONDURDUGUNU acikca belgeler.
4. Fonksiyon sayisi DAR tutulur. Su an 2 tane. Ucuncuyu eklemeden once
   "Dukkan bunu gercekten Yonetiyor'dan mi almali?" diye sorulmali —
   cogu zaman cevap "hayir, Dukkan kendi kaydinda tutmali".

===========================================================================
NEDEN SUREC ICI CAGRI, HTTP DEGIL
===========================================================================
Kisit soyleydi: "Yonetiyor'un veritabanina DOGRUDAN YAZMA. Okuma da API
uzerinden." Alternatif, `api`'nin kendi kendine HTTP istegi yapmasiydi.
O secenek gercek bir ag atlamasi, ek gecikme ve ek hata yolu getirir;
ayni surec ve ayni kod oldugu icin SIFIR ek guvenlik saglar.

Kisitin amaci — Dukkan'in Yonetiyor veritabanina bulasmamasi — iki
mekanizmayla zaten saglaniyor:
  * `dukkan_app` rolunun `public` semasinda hicbir yetkisi yok,
  * Dukkan kodu Yonetiyor modellerini ithal edemiyor (AST testi).
Bu karar kullaniciya soruldu ve (a) secenegi onaylandi.

===========================================================================
NE DONDURULUYOR, NE DONDURULMUYOR
===========================================================================
Dukkan'in Yonetiyor'dan ihtiyaci OLCULDU ve uc sey cikti — hepsi GIRIS
ANINDA BIR KEZ gerekiyor, sonrasinda Dukkan kendi kaydinda tutuyor:
    1. dogrulanmis telefon  (kimlik capasi)
    2. ad soyad             (profil gosterimi)
    3. tesisin il/ilce'si   (bolge on-doldurma)

DONDURULMEYENLER ve sebebi: daire numarasi, acik adres, e-posta, rol,
borc/aidat durumu, oturdugu blok. Dukkan'in bunlara ihtiyaci YOK ve
KVKK acisindan bir isletmeye sizabilecek en hassas alanlar bunlar
(docs/dukkan/02-kimlik-ve-yetki.md §6.1).
"""
from __future__ import annotations

import uuid
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

# ISTISNA: kopru.py Yonetiyor'u ithal EDEBILEN tek dosyadir. Paketin
# geri kalani icin bu satir yasak (bkz. __init__.py ve AST testi).
from ..models import AppUser, Tenant


@dataclass(frozen=True)
class YonetiyorKimligi:
    """Kopruden donen TEK veri sekli.

    Alanlar:
      telefon    E.164 telefon. `None` OLABILIR — olculdu: 3104 kullanicinin
                 837'sinde (%27) telefon YOK. Bu nadir bir durum degil,
                 SSO'nun ana yollarindan biri; cagiran taraf `None` halini
                 gercek bir akis olarak ele almali (Dukkan telefonu bir kez
                 kendisi sorar).
      ad_soyad   Gosterim adi. Bos olabilir.
      il         Kullanicinin bagli oldugu tesisin ili. NEREDEYSE HER ZAMAN
                 `None`: 2239 tesisin YALNIZ 1'inde `il` dolu (olculdu).
                 Bu yuzden bolge on-doldurma bir GARANTI degil "en iyi
                 caba"dir ve bos hali akisin NORMAL hâlidir.
      ilce       Ayni kosul.
    """

    telefon: str | None
    ad_soyad: str
    il: str | None
    ilce: str | None


async def yonetiyor_kimligi(
    session: AsyncSession,
    *,
    user_id: uuid.UUID | str,
    tenant_id: uuid.UUID | str,
) -> YonetiyorKimligi | None:
    """Yonetiyor kullanicisinin Dukkan'in ihtiyac duydugu ALANLARINI doner.

    SALT OKUNUR. Tek bir SELECT yapar.

    `session` YONETIYOR oturumudur (`app.db.get_session`), Dukkan'in
    kendi oturumu DEGIL — Dukkan'in oturumu bu tablolari zaten okuyamaz.
    Cagiran (`/dukkan/auth/yonetiyor` ucu) her iki oturumu da alir.

    Doner:
      YonetiyorKimligi  kullanici bulunduysa
      None              bulunamadiysa (silinmis kullanici, yanlis tenant)

    `None` donusu SESSIZ BIR HATA DEGILDIR: cagiran taraf bunu 401'e
    cevirmek zorundadir. Bos bir kimlikle devam etmek, kimligi
    dogrulanmamis birine Dukkan jetonu vermek olurdu.
    """
    satir = (
        await session.execute(
            select(
                AppUser.telefon,
                # AppUser'da TEK ad alani var (`soyad` YOK — olculdu).
                # Dukkan tarafinda `ad_soyad` tek metin olarak tutuluyor;
                # ikiye bolmeye calismak ("Ali Veli Kaya" -> ?) bilgi
                # uretmeye calismak olurdu.
                AppUser.ad,
                Tenant.il,
                Tenant.ilce,
            )
            .join(Tenant, Tenant.id == AppUser.tenant_id)
            .where(AppUser.id == user_id, AppUser.tenant_id == tenant_id)
        )
    ).first()

    if satir is None:
        return None

    telefon, ad, il, ilce = satir
    return YonetiyorKimligi(
        telefon=telefon,
        ad_soyad=(ad or "").strip(),
        il=il,
        ilce=ilce,
    )


async def tesis_bolgesi(
    session: AsyncSession, *, tenant_id: uuid.UUID | str
) -> tuple[str | None, str | None]:
    """Tesisin (il, ilce) ikilisini doner. SALT OKUNUR.

    `yonetiyor_kimligi` zaten bunu iceriyor; bu fonksiyon, kullanici
    baglami OLMADAN tesis bolgesi gerektigi durum icin ayri duruyor
    (orn. yonetici panelindeki "Yerel Isletmeler" sayfasi acilirken).

    Doner: (il, ilce) — ikisi de `None` olabilir ve OLACAKTIR
    (2239 tesisin 1'inde dolu). Cagiran bunu hata saymamali.
    """
    satir = (
        await session.execute(
            select(Tenant.il, Tenant.ilce).where(Tenant.id == tenant_id)
        )
    ).first()
    if satir is None:
        return (None, None)
    return (satir[0], satir[1])
