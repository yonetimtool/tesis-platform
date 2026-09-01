"""(P149) Telefon kodu — kayit, giris ve hesap silme icin TEK mekanizma.

Guvenlik ozellikleri burada TEK YERDE duruyor; her cagiran ayni korumayi
alir:
  * kod DUZ METIN tutulmaz (bcrypt hash) ve gunluge yazilmaz (P134),
  * sureli,
  * deneme sayaci AYRI OTURUMDA kalicilastirilir — ayni islemde tutmak
    onu geri sardiriyordu ve koruma HIC CALISMIYORDU (P148'de olculdu),
  * `amac` ayrimi: giris icin uretilen kod hesap silmeyi ONAYLAYAMAZ.
"""
from __future__ import annotations

import logging
import secrets
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import text, update
from sqlalchemy.ext.asyncio import AsyncSession

from .db import SessionLocal, set_tenant
from .errors import APIError
from .gunlukleme import maskele_kimlik
from .mesajlasma import GonderimSonucu, sms_saglayicisi
from .models import KayitDogrulama, MesajGonderim
from .security import hash_password, verify_password

logger = logging.getLogger(__name__)

KOD_OMRU_DK = 10
MAX_DENEME = 5

#: Adimlari ayirt ETTIRMEYEN tek hata. "kod yanlis" ile "boyle kullanici yok"
#: arasindaki fark, kayitli numaralarin disariya sizmasi demekti.
GECERSIZ = APIError(422, "invalid_code", "kod_gecersiz")


async def eposta_kodu_uret_ve_gonder(
    session: AsyncSession,
    *,
    tenant_id: uuid.UUID,
    eposta: str,
    amac: str,
    ayar=None,
) -> GonderimSonucu:
    """(P172 §5) AYNI KOD MEKANIZMASI, E-POSTA KIMLIGIYLE.

    =======================================================================
    NEDEN AYRI BIR SISTEM DEGIL
    =======================================================================
    Sure (`KOD_OMRU_DK`), deneme siniri (`MAX_DENEME`) ve kodun hash'lenip
    duz metin tutulmamasi BU MODULDE tek yerde duruyor. E-posta icin
    ikinci bir akis yazmak, bu ucunu ikinci kez — ve bir gun eksik —
    yazmak olurdu. Degisen tek sey KIMLIK ve TESLIMAT KANALI.

    =======================================================================
    TEMIZLIK DUZ `DELETE` — CAPRAZ-TENANT FONKSIYON GEREKMEZ
    =======================================================================
    Telefon PLATFORM GENELINDE benzersiz oldugu icin oradaki ezme
    `SECURITY DEFINER` bir fonksiyonla yapiliyor (baska tenant'in satiri
    RLS altinda GORULEMEZ). E-posta ise TENANT ICINDE benzersizdir; ezme
    kendi tenant'imizin satirlarina dokunur ve duz `DELETE` yeter.
    Daha az yetki, daha az yuzey.
    """
    from .gonderim import saglayici as kanal_saglayicisi

    kod = f"{secrets.randbelow(1_000_000):06d}"
    await session.execute(
        text(
            "DELETE FROM kayit_dogrulama WHERE eposta = :e AND amac = :a "
            "AND durum = 'telefon_bekliyor'"
        ),
        {"e": eposta, "a": amac},
    )
    session.add(
        KayitDogrulama(
            tenant_id=tenant_id,
            eposta=eposta,
            amac=amac,
            kod_hash=hash_password(kod),
            son_gecerlilik=datetime.now(timezone.utc)
            + timedelta(minutes=KOD_OMRU_DK),
        )
    )
    # GONDERIM HATASI KAYDI KIRMAZ: kod yazilmistir, kullanici "tekrar
    # gonder" diyebilir. Yapilandirma yoksa saglayici `yapilandirilmadi`
    # doner ve SESSIZCE "gonderildi" DEMEZ.
    # (P181 Bölüm 5) Amaç başına markalı şablon: kullanıcı kodun NE İÇİN
    # olduğunu görür ve kimlik-avı savunma satırı alır.
    from .eposta_sablonlari import eposta_kod_metni

    konu, govde = eposta_kod_metni(amac, kod, KOD_OMRU_DK)
    sonuc = kanal_saglayicisi("eposta", ayar).gonder(eposta, konu, govde)

    # =====================================================================
    # (P196) SONUC ARTIK DONUYOR — VE BASARISIZLIK LOGLANIYOR
    # =====================================================================
    # OLCULEN KUSUR: bu satirin donus degeri ATILIYORDU. Yukaridaki not
    # "SESSIZCE 'gonderildi' DEMEZ" diyor ama pratikte tam olarak o
    # oluyordu: saglayici `durum='yapilandirilmadi'` donuyor, fonksiyon
    # `None` donuyor, uc kullaniciya `{"durum": "gonderildi"}` yaziyordu.
    # Kullanici "kod gonderildi" ekranini goruyor, posta kutusuna hicbir
    # sey gelmiyordu — ve hicbir yerde iz yoktu.
    #
    # LOG BURADA, cagirida DEGIL: her cagiran ayni satiri yazmak zorunda
    # kalsaydi biri unuturdu. Alici adresi MASKELI (KVKK; `gunlukleme`
    # kuralinin aynisi).
    if sonuc.durum != "gonderildi":
        logger.error(
            "e-posta kodu GONDERILEMEDI amac=%s hedef=%s saglayici=%s hata=%s",
            amac, maskele_kimlik(eposta), sonuc.saglayici, sonuc.hata,
        )

    # =====================================================================
    # (P196) GONDERIM GECMISINE DE YAZ — AYRI OTURUMDA
    # =====================================================================
    # Bu akislar `mesaj_gonderim`e HIC yazmiyordu; tablo yalniz mesajlasma
    # modulunun kaydiydi. Sonuc: operator "kod gitti mi" sorusunu
    # YANITLAYAMIYORDU — kusur ancak kullanicinin sikayetiyle ve tablodaki
    # BOSLUGU yorumlayarak bulundu.
    #
    # NEDEN AYRI OTURUM (`SessionLocal`), cagiranin `session`i DEGIL:
    # OLCULDU. Gonderim basarisiz oldugunda cagiran `APIError` firlatiyor,
    # istek transaction'i GERI ALINIYOR ve ayni transaction'a yazilan
    # teshis kaydi da siliniyordu — kayit tam da EN GEREKLI oldugu anda
    # kayboluyordu. Ilk yazimda tam olarak bu oldu: 502 dondu,
    # `mesaj_gonderim` BOS kaldi.
    #
    # KOD GOVDEYE YAZILMAZ. Tablonun sozlesmesi "gonderilen metin
    # kopyalanir" der ama bir DOGRULAMA KODU sirdir: veritabaninda duz
    # metin tutmak, kodun `kod_hash` olarak saklanmasini anlamsiz
    # kilardi. Govdeye yer tutucu yazilir; olculen sey METIN degil
    # "gonderildi mi" sorusudur.
    try:
        async with SessionLocal() as kayit_oturumu:
            async with kayit_oturumu.begin():
                await set_tenant(kayit_oturumu, tenant_id)
                kayit_oturumu.add(
                    MesajGonderim(
                        tenant_id=tenant_id,
                        kanal="eposta",
                        amac="operasyonel",
                        hedef=eposta,
                        konu=konu,
                        # TASIYICI ADI GOVDEDE: "gonderildi" yazan bir
                        # satirin gercekte nereye gittigi gecmisten
                        # okunabilmeli (orn. dev'de `konsol-eposta`).
                        govde=f"[dogrulama kodu: {amac} · tasiyici={sonuc.saglayici}]",
                        durum=(
                            "gonderildi"
                            if sonuc.durum == "gonderildi"
                            else "basarisiz"
                        ),
                        hata=sonuc.hata,
                    )
                )
    except Exception:  # noqa: BLE001
        # TESHIS KAYDI ASIL ISI DUSURMEZ: yazilamazsa bile gonderim sonucu
        # cagirana dogru doner. Log yukarida zaten atildi.
        logger.exception("gonderim gecmisi yazilamadi amac=%s", amac)

    return sonuc


async def kod_uret_ve_gonder(
    session: AsyncSession,
    *,
    tenant_id: uuid.UUID,
    telefon: str,
    amac: str,
    unit_id: uuid.UUID | None = None,
    user_id: uuid.UUID | None = None,
) -> GonderimSonucu:
    """Ayni amac icin bekleyen kodu EZER ve yenisini gonderir.

    Ezme bilincli: art arda istenen kodlarin HEPSININ gecerli kalmasi,
    saldirgana ayni anda bes gecerli hedef verirdi.
    """
    kod = f"{secrets.randbelow(1_000_000):06d}"
    # (P154) EZME TENANT SINIRINI GECER — bu yuzden duz DELETE degil,
    # SECURITY DEFINER fonksiyon. `uq_kayit_acik_basvuru` KISMI ve GLOBAL
    # bir benzersizlik indeksidir: bir telefon TUM PLATFORMDA tek acik
    # basvuru tasiyabilir. Kisi A sitesinde kayda baslayip B sitesinde
    # kaydolmaya calisirsa B'nin INSERT'i A'nin satiriyla catisir.
    # RLS acildiktan sonra duz DELETE yalniz KENDI tenant'ini gorur, A'nin
    # satirini SILEMEZ ve INSERT benzersizlik ihlaliyle 500 verirdi.
    # Fonksiyonun semantigi eski DELETE ile BIRE BIR ayni (ayni telefon,
    # ayni amac, yalniz `telefon_bekliyor`); degisen tek sey tenant
    # sinirini gecmesi. Bkz. goc 0042.
    await session.execute(
        text("SELECT public.kayit_dogrulama_acik_temizle(:p, :a)"),
        {"p": telefon, "a": amac},
    )
    session.add(
        KayitDogrulama(
            tenant_id=tenant_id,
            unit_id=unit_id,
            # (P154) `user_id` DOLU ise satir bir ROL KAYDIDIR (hesap var,
            # sahipleniliyor); NULL ise P148 basvurusudur (hesap henuz yok).
            # Iki akis ayni tabloyu ve ayni `amac` degerini paylasir; ayrim
            # bu sutundadir. Bkz. routers/auth.py rol-kayit bolumu.
            user_id=user_id,
            telefon=telefon,
            amac=amac,
            kod_hash=hash_password(kod),
            son_gecerlilik=datetime.now(timezone.utc)
            + timedelta(minutes=KOD_OMRU_DK),
        )
    )
    # (P150) Saglayici YAPILANDIRMADAN gelir: `SMS_SAGLAYICI` verilmemisse
    # LOG'dur ve kod kullaniciya ULASMAZ. Gonderim hatasi kaydi KIRMAZ —
    # kod yazilmistir, kullanici "tekrar gonder" diyebilir.
    #
    # (P196) SONUC DONUYOR ve basarisizlik LOGLANIYOR: SMS varsayilan
    # olarak KAPALI oldugu icin bu yol pratikte hep `yapilandirilmadi`
    # doner — ve cagiran kullaniciya "kod gonderildi" diyordu.
    sonuc = sms_saglayicisi().gonder(
        telefon, None, f"Yönetiyor doğrulama kodunuz: {kod} ({KOD_OMRU_DK} dk)"
    )
    if sonuc.durum != "gonderildi":
        logger.error(
            "SMS kodu GONDERILEMEDI amac=%s hedef=%s saglayici=%s hata=%s",
            amac, maskele_kimlik(telefon), sonuc.saglayici, sonuc.hata,
        )
    return sonuc


async def tenant_baglamini_kur(
    session: AsyncSession, *, telefon: str, amac: str
) -> uuid.UUID | None:
    """(P154) KIMLIK ONCESI tenant baglamini kurar; kuramazsa `None`.

    `kayit_dogrulama` artik RLS altinda (goc 0042) ve bu tablo, kullanicinin
    HENUZ OTURUMU YOKKEN okunuyor. Satiri gormek icin once tenant baglami
    gerekiyor, tenant'i ogrenmek icin de satiri gormek — dongu, YALNIZ
    tenant kimligi donduren bir SECURITY DEFINER fonksiyonla kirilir
    (`tenant_id_by_slug` / `tenant_id_by_phone` ile ayni desen).

    OTURUMUN BAGLAMI ZATEN VARSA DEGISTIRILMEZ, DOGRULANIR: `/me/*`
    uclari `get_tenant_db` ile gelir ve baglami kuruludur. Orada baglami
    ezmek, bir kullanicinin baska bir tesisin satirina ulasmasina acilan
    kapi olurdu. Uyusmuyorsa `None` doneriz ve cagiran "gecersiz kod" der —
    ayrimi disariya SIZDIRMADAN.
    """
    mevcut = (
        await session.execute(
            text("SELECT current_setting('app.current_tenant_id', true)")
        )
    ).scalar()
    cozulen = (
        await session.execute(
            text("SELECT public.kayit_dogrulama_tenant_coz(:p, :a)"),
            {"p": telefon, "a": amac},
        )
    ).scalar_one_or_none()
    if cozulen is None:
        return None
    if mevcut:
        return cozulen if str(cozulen) == str(mevcut) else None
    await set_tenant(session, cozulen)
    return cozulen


async def eposta_kodunu_dogrula(
    session: AsyncSession,
    *,
    tenant_id: uuid.UUID,
    eposta: str,
    kod: str,
    amac: str,
) -> KayitDogrulama:
    """(P172 §5) E-posta kodunu dogrular — telefon yolunun AYNI kurallari.

    TENANT CAGIRANDAN GELIR: e-posta global benzersiz DEGIL, tenant icinde
    benzersizdir; kimden geldigini bilmeden dogrulamak, ayni adresi
    kullanan iki tesisin kodlarini KARISTIRMAK olurdu.
    """
    from sqlalchemy import select

    await set_tenant(session, tenant_id)
    kayit = (
        await session.execute(
            select(KayitDogrulama).where(
                KayitDogrulama.eposta == eposta,
                KayitDogrulama.amac == amac,
                KayitDogrulama.durum == "telefon_bekliyor",
            )
        )
    ).scalar_one_or_none()
    return await _kodu_karsilastir(kayit, kod)


async def _kodu_karsilastir(
    kayit: KayitDogrulama | None, kod: str
) -> KayitDogrulama:
    """Sure / deneme / eslesme denetimi — IKI KIMLIK YOLU ICIN ORTAK.

    Ayri ayri yazilsaydi, bir gun birinde deneme sayaci artirilir otekinde
    unutulurdu ve o kanal kaba kuvvete acik kalirdi.
    """
    if kayit is None:
        raise GECERSIZ
    if kayit.son_gecerlilik < datetime.now(timezone.utc):
        raise GECERSIZ
    if kayit.deneme >= MAX_DENEME:
        raise GECERSIZ
    if not verify_password(kod, kayit.kod_hash):
        # SAYAC AYRI OTURUMDA: bu istek hata ile bitecek ve cagiranin
        # islemi geri sarilacak — ayni oturumda tutmak sayaci SIFIRLARDI.
        async with SessionLocal() as s2:
            async with s2.begin():
                await set_tenant(s2, kayit.tenant_id)
                await s2.execute(
                    update(KayitDogrulama)
                    .where(KayitDogrulama.id == kayit.id)
                    .values(deneme=KayitDogrulama.deneme + 1)
                )
        raise GECERSIZ
    return kayit


async def kodu_dogrula(
    session: AsyncSession, *, telefon: str, kod: str, amac: str
) -> KayitDogrulama:
    """Dogru ise kaydi doner; her basarisiz yolda `GECERSIZ` firlatir."""
    from sqlalchemy import select

    if await tenant_baglamini_kur(session, telefon=telefon, amac=amac) is None:
        raise GECERSIZ

    kayit = (
        await session.execute(
            select(KayitDogrulama).where(
                KayitDogrulama.telefon == telefon,
                KayitDogrulama.amac == amac,
                KayitDogrulama.durum == "telefon_bekliyor",
            )
        )
    ).scalar_one_or_none()
    return await _kodu_karsilastir(kayit, kod)
