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
from datetime import datetime, timezone

import psycopg
from sqlalchemy import select

from .config import settings
from .db import tenant_session
from .models import RaporIsi
from .rapor_ciktilari import excel_uret, metin_pdf, pdf_uret
from .schemas import RaporParametre
from .storage import sunucudan_yukle

log = logging.getLogger(__name__)

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

    async with tenant_session(tenant_id) as db:
        isim = (
            await db.execute(select(RaporIsi).where(RaporIsi.id == is_id))
        ).scalar_one_or_none()
        if isim is None:
            return {"durum": "bulunamadi"}
        # ZATEN ISLENMIS ISI TEKRAR URETME: Celery "en az bir kez" teslim
        # eder; ayni gorev iki kez calisabilir. Yeniden uretmek, ayni
        # dosyayi ikinci kez yazip MinIO'da coplenmis bir obje birakirdi.
        if isim.durum in ("hazir", "uretiliyor"):
            return {"durum": isim.durum}

        isim.durum = "uretiliyor"
        await db.flush()

        try:
            from .models import AppUser
            from .routers.rapor_motoru import _param, _tenant, _uret

            kullanici = (
                await db.execute(select(AppUser).where(AppUser.id == isim.user_id))
            ).scalar_one()
            p = _param(RaporParametre(**isim.parametre))
            sonuc = await _uret(db, kullanici, isim.kod, p)
            tenant = await _tenant(db, kullanici)

            if isim.bicim == "excel":
                icerik = excel_uret(sonuc, tenant.ad, p.baslangic, p.bitis)
                tur, uzanti = EXCEL_TURU, "xlsx"
            else:
                icerik = (
                    metin_pdf(sonuc.baslik, sonuc.metin or "", tenant.ad)
                    if not sonuc.sutunlar
                    else pdf_uret(sonuc, tenant.ad, p.baslangic, p.bitis)
                )
                tur, uzanti = PDF_TURU, "pdf"

            gun = datetime.now(timezone.utc).strftime("%Y%m%d")
            dosya_adi = f"{isim.kod}-{gun}.{uzanti}"
            # ANAHTAR TENANT ONEKLI: `make_foto_key` ile ayni kural —
            # oneksiz bir anahtar, tenant izolasyonunu obje deposunda
            # kaybetmek olurdu.
            key = f"{tenant_id}/raporlar/{is_id}.{uzanti}"
            sunucudan_yukle(key, icerik, tur)

            isim.dosya_key = key
            isim.dosya_adi = dosya_adi
            isim.durum = "hazir"
            isim.biten_at = datetime.now(timezone.utc)
            return {"durum": "hazir", "boyut": len(icerik)}
        except Exception as exc:  # noqa: BLE001 — sebebi KAYDEDILIYOR
            # YIGIN IZI LOG'A, KULLANICIYA KISA METIN: yigin izi arayuze
            # sizarsa hem okunmaz hem de ic yapiyi disari verir.
            log.exception("rapor isi basarisiz: %s", is_id)
            isim.durum = "hata"
            isim.hata = type(exc).__name__
            isim.biten_at = datetime.now(timezone.utc)
            return {"durum": "hata"}
