"""(P167 Asama 5) RAPOR KUYRUGU — agir raporlarin arka plan uretimi.

===========================================================================
NEDEN ISTEK YOLUNDA DEGIL
===========================================================================
Brief: "PDF ve Excel uretimi sunucu tarafinda olsun; buyuk raporlar
kuyruga girsin ve hazir olunca indirilebilsin (senkron uretim tarayiciyi
kilitler)."

`borc_alacak` ve `detayli_borc` TUM defteri tarar: 500 daireli bir sitede
her dairenin butun tahakkuk/tahsilat gecmisi okunur ve gecikme tazminati
tek tek hesaplanir. Istek yolunda bu, tarayicinin yanit gelene kadar
beklemesi ve zaman asiminda ISIN YARIM KALMASI demek — kullanici neyin
oldugunu bilmez, yeniden dener, sunucu ayni isi bir kez daha yapar.

===========================================================================
UC KATMAN, UCU DE AYRI YERDE
===========================================================================
  * `routers/rapor_motoru.py` — isi ACAR (durum: bekliyor) ve 202 doner.
  * `tasks.py`                — Celery gorevi; bu modulu cagirir.
  * BU MODUL                  — isi URETIR, MinIO'ya yazar, durumu gunceller.

Uretim mantigi `_uret` ile AYNI fonksiyondan geciyor: kuyruk ayri bir
hesaplama yolu DEGIL, ayni hesaplamanin baska bir zamanlamasi. Ikinci bir
uretici yazsaydik, senkron ve kuyruk ciktilari bir gun ayrisirdi ve bunu
kimse fark etmezdi.
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta, timezone

import psycopg
from sqlalchemy import select, update

from .config import settings
from .db import tenant_session
from .models import RaporIsi
from .makbuz import adres_satiri
from .rapor_ciktilari import excel_uret, metin_pdf, pdf_uret
from .schemas import RaporParametre
from .storage import sunucudan_yukle

log = logging.getLogger(__name__)

#: (P227 §1) SINIF ADI TESHIS DEGILDIR.
#:
#: Prod'da uc rapor da "SSLError" diye dustu. Yonetici bu kelimeyle ne
#: yapacagini bilemez. Gercek sebep sunucunun KENDI genel adresine
#: cikmaya calismasiydi (bkz. config.minio_internal_endpoint) — yani
#: duzeltilecek yer SUNUCU YAPILANDIRMASI, kullanicinin dokunabilecegi
#: hicbir sey degil.
#:
#: Metin NE OLDUGUNU ve KIMIN duzeltecegini soyler; teknik sinif adi
#: parantez icinde KALIR, cunku yonetici onu destege iletebilmeli.
_HATA_METINLERI: tuple[tuple[tuple[str, ...], str], ...] = (
    (
        ("SSLError", "SSLCertVerificationError", "EndpointConnectionError",
         "ConnectTimeoutError", "ConnectionClosedError"),
        "Dosya deposuna ulasilamadi. Bu bir SUNUCU YAPILANDIRMA sorunudur; "
        "rapor verisiyle ilgisi yok. Sistem yoneticisine bildirin",
    ),
    (
        ("NoCredentialsError", "ClientError", "ParamValidationError"),
        "Dosya deposu istegi reddetti (kimlik/yetki). Sunucu "
        "yapilandirmasi kontrol edilmeli",
    ),
    (
        ("OperationalError", "InterfaceError", "DBAPIError"),
        "Veritabanina erisilemedi; raporu birkac dakika sonra tekrar deneyin",
    ),
    (
        ("MemoryError",),
        "Rapor cok buyuk. Tarih araligini daraltip tekrar deneyin",
    ),
)


#: (P252 §4) Bu sureden uzun `uretiliyor`da kalan is YETIM sayilir (isci
#: olduruldu) ve yeniden teslimde yeniden uretilir.
YETIM_SURESI = timedelta(minutes=30)


def _hata_metni(exc: Exception) -> str:
    """Istisnayi yoneticinin ANLAYACAGI bir cumleye cevirir."""
    ad = type(exc).__name__
    for adlar, metin in _HATA_METINLERI:
        if ad in adlar:
            return f"{metin} ({ad})"
    # BILINMEYEN HATA: sinif adi YINE verilir — "bilinmeyen hata" demek,
    # destege iletilebilecek TEK ipucunu da silmek olurdu.
    return f"Rapor uretilemedi ({ad})"



EXCEL_TURU = (
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
)
PDF_TURU = "application/pdf"


async def isi_uret(is_id: uuid.UUID) -> dict:
    """Bir rapor isini uret ve sonucu kaydet.

    HATA YUTULMAZ, KAYDEDILIR: gorev cokerse Celery yeniden dener ve
    kullanici sonsuza kadar "uretiliyor" gorur. Hata metni satira yazilip
    durum `hata`ya cekilirse kullanici NE OLDUGUNU okur ve yeniden
    deneyip denemeyecegine kendisi karar verir.
    """
    # ISI ONCE OWNER ILE BULUYORUZ: `tenant_session` bir tenant kimligi
    # ISTER, ama gorev yalnizca is kimligini biliyor. Bu ilk okuma RLS
    # disindadir ve YALNIZCA tenant'i cozmek icindir — tek sutun, tek
    # satir. Asil is ondan sonra tenant baglami altinda yapilir ve o
    # noktadan itibaren RLS yeniden devrededir.
    #
    # OWNER BAGLANTISI SYNC (`psycopg`): `gurultu_kuyruk.py`deki
    # `_tenant_idler` ile ayni desen. Ikinci bir async owner motoru
    # acmak, yalnizca bir `SELECT` icin bir baglanti havuzu daha demekti.
    with psycopg.connect(
        settings.owner_dsn, autocommit=True, connect_timeout=10
    ) as conn:
        satir = conn.execute(
            "SELECT tenant_id FROM rapor_isi WHERE id = %s", (str(is_id),)
        ).fetchone()
    if satir is None:
        return {"durum": "bulunamadi"}
    tenant_id = satir[0]

    # =====================================================================
    # (P252 §4) UC KISA ISLEM — uretim ve yukleme ISLEM DISINDA.
    # =====================================================================
    # Eskiden tek islemdi: `uretiliyor` yazilir, rapor uretilir, dosya
    # MinIO'ya yuklenir, ayni satir `hazir` yapilirdi. Iki kusur olculdu:
    #
    #  1. KILITLENME. Satirin son surumu AYNI islemin yazdigi surum
    #     oldugundan Postgres ikinci UPDATE'te yabanci anahtar denetimini
    #     yeniden calistirir (anahtar degismese de) ve tenant/app_user
    #     satirina KEY SHARE ister. Tesis silinirken (cascade) silme o
    #     satirlari tutup bu `rapor_isi` satirini beklediginden ikisi
    #     birbirini bekliyordu — `test_rapor_kuyruk` tam kosuda her seferinde
    #     (db gunlugu: `DELETE FROM tenant` <-> `UPDATE rapor_isi`).
    #     Prod'da tesis silme ve saklama temizligi ayni yarisa girer.
    #  2. 60 SN SINIRI. PDF/Excel uretimi ve yukleme sirasinda sorgu yok:
    #     oturum "idle in transaction" sayilir ve goc 0074'un 60 sn
    #     siniri agir bir raporda oturumu keserdi.
    #
    # Simdi: (1) `uretiliyor` yaz ve BITIR; (2) veriyi oku ve BITIR;
    # (3) dosyayi islem disinda uret/yukle; (4) sonucu ayri bir islemde
    # yaz. Satir arada silindiyse (tesis silindi) sessizce birakilir.
    async with tenant_session(tenant_id) as db:
        # FOR UPDATE: es zamanli ikinci teslim burada bekler ve `uretiliyor`
        # gorup cekilir (eskiden ikisi de `bekliyor` okuyup uretebiliyordu).
        isim = (
            await db.execute(
                select(RaporIsi).where(RaporIsi.id == is_id).with_for_update()
            )
        ).scalar_one_or_none()
        if isim is None:
            return {"durum": "bulunamadi"}
        # ZATEN ISLENMIS ISI TEKRAR URETME: Celery "en az bir kez" teslim
        # eder; ayni gorev iki kez calisabilir. Yeniden uretmek, ayni
        # dosyayi ikinci kez yazip MinIO'da coplenmis bir obje birakirdi.
        #
        # YETIM IS ISTISNASI: `uretiliyor` artik AYRI islemde yaziliyor;
        # isci olduruldugunde (OOM) geri alinmaz. `task_acks_late` gorevi
        # yeniden teslim eder ve uzun suredir `uretiliyor`da kalan is
        # yeniden uretilir — yoksa kullanici sonsuza kadar "uretiliyor"
        # gorurdu.
        yetim = (
            isim.durum == "uretiliyor"
            and isim.created_at is not None
            and datetime.now(timezone.utc) - isim.created_at > YETIM_SURESI
        )
        if isim.durum == "hazir" or (isim.durum == "uretiliyor" and not yetim):
            return {"durum": isim.durum}
        isim.durum = "uretiliyor"
        kod, bicim, parametre, user_id = isim.kod, isim.bicim, isim.parametre, isim.user_id

    try:
        from .models import AppUser
        from .routers.rapor_motoru import KATALOG_KAYITLARI, _param, _tenant, _uret

        async with tenant_session(tenant_id) as db:
            kullanici = (
                await db.execute(select(AppUser).where(AppUser.id == user_id))
            ).scalar_one()
            p = _param(RaporParametre(**parametre))
            sonuc = await _uret(db, kullanici, kod, p)
            tenant = await _tenant(db, kullanici)
            site = {
                "ad": tenant.ad,
                "adres": adres_satiri(tenant.adres, tenant.ilce, tenant.il, tenant.posta_kodu),
            }

        # (P181 Bölüm 8) Katalogdaki grafik yapılandırması Excel/PDF'e gömülür.
        _kayit = KATALOG_KAYITLARI.get(sonuc.kod)
        grafik = _kayit.grafik if _kayit else None
        if bicim == "excel":
            icerik = excel_uret(sonuc, site["ad"], p.baslangic, p.bitis, grafik=grafik)
            tur, uzanti = EXCEL_TURU, "xlsx"
        else:
            icerik = (
                metin_pdf(sonuc.baslik, sonuc.metin or "", site["ad"])
                if not sonuc.sutunlar
                else pdf_uret(
                    sonuc, site["ad"], p.baslangic, p.bitis, grafik=grafik,
                    site_adres=site["adres"],
                )
            )
            tur, uzanti = PDF_TURU, "pdf"

        gun = datetime.now(timezone.utc).strftime("%Y%m%d")
        dosya_adi = f"{kod}-{gun}.{uzanti}"
        # ANAHTAR TENANT ONEKLI: `make_foto_key` ile ayni kural —
        # oneksiz bir anahtar, tenant izolasyonunu obje deposunda
        # kaybetmek olurdu.
        key = f"{tenant_id}/raporlar/{is_id}.{uzanti}"
        sunucudan_yukle(key, icerik, tur)
        sonuc_alanlari = {
            "dosya_key": key, "dosya_adi": dosya_adi, "durum": "hazir",
            "biten_at": datetime.now(timezone.utc),
        }
        donus = {"durum": "hazir", "boyut": len(icerik)}
    except Exception as exc:  # noqa: BLE001 — sebebi KAYDEDILIYOR
        # YIGIN IZI LOG'A, KULLANICIYA KISA METIN: yigin izi arayuze
        # sizarsa hem okunmaz hem de ic yapiyi disari verir.
        log.exception("rapor isi basarisiz: %s", is_id)
        sonuc_alanlari = {
            "durum": "hata", "hata": _hata_metni(exc),
            "biten_at": datetime.now(timezone.utc),
        }
        donus = {"durum": "hata"}

    async with tenant_session(tenant_id) as db:
        guncellenen = (
            await db.execute(
                update(RaporIsi).where(RaporIsi.id == is_id).values(**sonuc_alanlari)
            )
        ).rowcount
    if not guncellenen:
        # Is (ya da tesis) uretim sirasinda silindi: yazacak satir yok.
        return {"durum": "bulunamadi"}
    return donus
