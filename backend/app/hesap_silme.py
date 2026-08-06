"""HESAP SILME / ANONIMLESTIRME cekirdegi (P112) — TEK KAYNAK.

Ayni is IKI yerden tetiklenir:
  * yonetim: `DELETE /residents/{id}` (yonetici bir sakini cikarir),
  * SELF-SERVIS: `POST /me/hesap-sil` (App Store 5.1.1(v) — kullanici KENDI
    hesabini uygulama icinden siler).

Ikisini ayri ayri yazmak, KVKK ayrimini iki yerde tutmak demekti; birinde
duzeltilip digerinde unutulan bir alan **silinmis sanilan bir kisisel veri**
birakirdi. Bu yuzden karar tek yerde:

KVKK AYRIMI (P112'nin belgelenmis kurali)
-----------------------------------------
**SILINIR / ANONIMLESTIRILIR (kisisel veri):**
  ad -> yer tutucu · e-posta, telefon -> NULL · parola ve gecici kod
  hash'leri -> NULL (kimlik dogrulama gecersizlesir) · avatar -> NULL ·
  cihaz/push kayitlari (`user_device`) -> SILINIR · aktif daire-sakin
  baglantilari -> KAPATILIR · `is_active` -> false.

**KALIR (yasal saklama / defter butunlugu):**
  finansal satirlar (`dues_assessment`, `dues_payment`, `finansal_hareket`),
  denetim kaydi (`audit_log`, append-only), talep/sikayet ve tur/okutma
  kayitlari. Bunlar artik **anonim** bir kullaniciya isaret eder.

  NEDEN: 6102 sayili TTK ve vergi mevzuati defterlerin saklanmasini
  emreder; KVKK md. 7 "silme" hakki **baska bir kanunun ongordugu saklama
  yukumlulugunu** ortadan kaldirmaz (md. 28 ve Kurul kararlari). Yani
  seciyoruz degil, mecburuz: alternatif — odemeyi silmek — kasa bakiyesini
  gecmise donuk degistirirdi ve **baska sakinlerin** mutabakatini bozardi.

IKI MOD
-------
  * `deleted=True`  — TAM SILME. Gecmisi olmayan hesap (yeni acilmis, hic
    islem yapmamis) satirdan tamamen kalkar.
  * `deleted=False` — ANONIMLESTIRME. FK RESTRICT bir gecmis oldugunu
    soyluyorsa satir KALIR ama kimlik alanlari temizlenir.

Hangisi olacagi TAHMIN EDILMEZ, DENENIR: once `DELETE` bir SAVEPOINT icinde
denenir; `IntegrityError` gelirse savepoint geri alinir ve anonimlestirmeye
dusulur. Tahmin etmek (once "gecmisi var mi" diye saymak) yeni bir tabloyu
listeye eklemeyi unutunca **sessizce yanlis mod** secerdi.
"""
from __future__ import annotations

import uuid

from sqlalchemy import delete as sa_delete, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

import logging

logger = logging.getLogger(__name__)

from . import storage
from .models import AppUser, HesapSilmeKaydi, UnitResident, UserDevice

#: KVKK anonimlestirme yer tutucusu.
#:
#: NEDEN SABIT METIN, NULL DEGIL: `app_user.ad` NOT NULL'dur ve bu deger
#: baska sakinlerin ekraninda (eski talep, karar defteri) GORUNUR. Bos
#: birakmak orada bir bosluk cizerdi; yer tutucu "bu hesap silindi"
#: bilgisini tasir. Cevrilmemesi BILINCLIDIR (README §15 istisna tablosu):
#: bu bir arayuz sabiti degil, veritabanina yazilan bir VERI degeridir ve
#: yazildigi andaki dile gore donmemelidir.
ANONYMIZED_NAME = "Silinmiş Kullanıcı"


async def hesabi_sil_veya_anonimlestir(
    db: AsyncSession,
    hedef: AppUser,
    *,
    kendi_istegi: bool,
) -> bool:
    """Hesabi sil ya da anonimlestir. Doner: **tam silindi mi**.

    [kendi_istegi] yalnizca kalici KAYDA yazilir (KVKK kaniti); davranisi
    degistirmez — kullanicinin kendi sildigi hesapla yonetimin sildigi hesap
    ayni kurala tabidir.

    ONEMLI: cagiran taraf denetim kaydini (`audit_user`) KENDI yazar —
    aktor (kim yapti) cagirana gore degisir ve buraya gomulemez.
    """
    hedef_id = hedef.id
    tenant_id = hedef.tenant_id
    rol = hedef.role

    try:
        async with db.begin_nested():
            await db.execute(sa_delete(AppUser).where(AppUser.id == hedef_id))
        await _kayit_yaz(
            db, tenant_id=tenant_id, user_id=hedef_id, rol=rol,
            mod="hard_delete", kendi_istegi=kendi_istegi,
        )
        return True
    except IntegrityError:
        # Gecmis kayitlari var (FK RESTRICT) -> savepoint geri alindi.
        await _anonimlestir(db, hedef)
        await _kayit_yaz(
            db, tenant_id=tenant_id, user_id=hedef_id, rol=rol,
            mod="anonymize", kendi_istegi=kendi_istegi,
        )
        return False


async def _anonimlestir(db: AsyncSession, hedef: AppUser) -> None:
    """Kimlik alanlarini temizle; defter satirlarina DOKUNMA."""
    now = func.now()
    baglar = (
        await db.execute(
            select(UnitResident).where(
                UnitResident.user_id == hedef.id,
                UnitResident.bitis.is_(None),
            )
        )
    ).scalars().all()
    for bag in baglar:
        bag.bitis = now
    # Cihaz/push kayitlari SILINIR: hem kisisel veridir hem de silinmis bir
    # hesaba bildirim gitmesi (yeni sahibine dusen cihazda) sizinti olurdu.
    await db.execute(sa_delete(UserDevice).where(UserDevice.user_id == hedef.id))

    hedef.ad = ANONYMIZED_NAME
    hedef.email = None
    hedef.telefon = None
    hedef.password_hash = None
    hedef.temp_code_hash = None
    hedef.password_set = False
    hedef.aranabilir = False
    hedef.is_active = False
    # Avatar da kisisel veridir; anahtarin kalmasi nesnenin adresini
    # birakmak demekti.
    # (P141.6) OBJEYI DE SIL, yalniz referansi degil. Once burada sadece
    # `avatar_key = None` vardi ve dosya MinIO'da YETIM KALIYORDU: kayit
    # "silindi" gorunuyor ama kisinin yuz fotografi depoda duruyordu.
    # Bir avatar operasyonel/denetim kaydi DEGILDIR — devriye fotografi
    # gibi savunulabilir bir saklama gerekcesi yok.
    #
    # HATA KAYDI KIRMAZ: MinIO erisilemezse silme islemi geri sarilmaz;
    # kullanicinin hesabi silinir ve obje gecelik retention'a kalir.
    # Tersi, depo arizasinda kullanicinin hesabini silememesi olurdu.
    if hedef.avatar_key:
        try:
            storage.delete_objects([hedef.avatar_key])
        except Exception:
            logger.warning("[hesap-silme] avatar objesi silinemedi")
    hedef.avatar_key = None
    hedef.updated_at = now
    await db.flush()


async def _kayit_yaz(
    db: AsyncSession,
    *,
    tenant_id: uuid.UUID,
    user_id: uuid.UUID,
    rol: str,
    mod: str,
    kendi_istegi: bool,
) -> None:
    """KALICI silme kaydi (0029).

    NEDEN `audit_log` YETMIYOR: denetim kaydi saklama politikasi geregi
    24 ayda bir PURGE edilir (`retention_audit_months`). Silme kaniti ise
    talep gelirse **daha sonra** gosterilmek zorundadir — purge sonrasi
    "sildik" diyebilmenin dayanagi kalmazdi. Bu tablo purge edilmez ve
    icinde **kisisel veri YOKTUR**: yalniz kimlikler, rol, mod ve zaman.
    """
    db.add(
        HesapSilmeKaydi(
            tenant_id=tenant_id,
            user_id=user_id,
            rol=rol,
            mod=mod,
            kendi_istegi=kendi_istegi,
        )
    )
    await db.flush()


async def son_admin_mi(db: AsyncSession, user: AppUser) -> bool:
    """Bu kullanici tesisin SON aktif admin/yoneticisi mi?

    NEDEN ENGEL: son yonetici kendini silerse tesis **sahipsiz** kalir —
    kimse yeni yonetici atayamaz, sakin ekleyemez, aidat isleyemez. Kurtarma
    ancak platform operatoru elle mudahale ederse olur. Apple 5.1.1(v)
    "hesap silinebilmeli" der; "tesisi kullanilamaz birak" demez — cozum
    silmeyi engellemek degil, ONCE DEVRETMEYI istemektir (hata mesaji bunu
    soyler).

    Kapsam admin+yonetici: ikisi de tesisi yonetebilir, dolayisiyla biri
    duruyorsa tesis sahipsiz degildir.
    """
    if user.role not in ("admin", "yonetici"):
        return False
    kalan = (
        await db.execute(
            select(func.count())
            .select_from(AppUser)
            .where(
                AppUser.role.in_(("admin", "yonetici")),
                AppUser.is_active.is_(True),
                AppUser.id != user.id,
            )
        )
    ).scalar_one()
    return kalan == 0
