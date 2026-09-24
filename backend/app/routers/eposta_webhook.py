"""(P234 §1) RESEND TESLIM WEBHOOK'U — POST /webhooks/eposta/resend.

===========================================================================
NEDEN VAR
===========================================================================
Olculen kusur: panel "gonderildi" yaziyor ama mail bounce olmus olabiliyor
ve BUNU HIC GORMUYORUZ. `gonderildi` bir SAGLAYICIYA TESLIM kaydidir,
ALICIYA TESLIM kaydi degil. Aradaki fark, yoneticinin "davet gitti ama
kimse girmedi" diye gecirdigi gunlerdir.

===========================================================================
GUVENLIK — odeme webhook'uyla AYNI KALIP
===========================================================================
  * PUBLIC uc (jeton YOK) ama IMZA KORUMALI: Svix HMAC-SHA256 dogrulanir,
    gecersizse 401 ve HICBIR SEY yapilmaz. Sahte bir "bounce", bir
    yoneticiyi kendi sakininin adresini silmeye iterdi.
  * ZAMAN PENCERESI: 5 dakikadan eski/ileri imzalar reddedilir — yakalanan
    bir istegin sonsuza kadar tekrar oynatilmasini engeller.
  * TENANT BAGLAMI webhook'ta YOK: mesaj kimliginden SECURITY DEFINER
    fonksiyonla cozulur (`gonderim_tenant_by_saglayici_id`), sonra
    `set_tenant`.
  * IDEMPOTENT: `eposta_webhook_olay` tablosu ayni olayin iki kez
    islenmesini engeller.

===========================================================================
BILINMEYEN OLAY TURU 200 DONER
===========================================================================
Resend yeni olay turleri ekleyebilir. 4xx donmek saglayiciyi TEKRAR
DENEMEYE iter ve sonunda webhook'u DEVRE DISI biraktirir — yani
bilmedigimiz bir olay yuzunden BILDIGIMIZ olaylari da kaybederiz.
Bilinmeyen tur sessizce degil, GUNLUGE yazilarak gecilir.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import logging
import time

from fastapi import APIRouter, Request
from sqlalchemy import select, text

from ..config import settings
from ..db import SessionLocal, set_tenant
from ..errors import APIError
from ..models import Davet, MesajGonderim

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/webhooks/eposta", tags=["webhooks"])

_COZ = text("SELECT public.gonderim_tenant_by_saglayici_id(:m)")
#: (P234 §1) DOGRUDAN INSERT DEGIL, SECURITY DEFINER FONKSIYONU.
#:
#: Tablo PLATFORM TABLOSU desenini tasiyor (RLS ACIK + FORCE, POLITIKA
#: YOK) — `app_rw` ona dogrudan yazamaz. Ilk yazimda tabloyu RLS'siz
#: birakip dogrudan INSERT ediyordum ve `test_rls_kapsam` dustu: depoda
#: "RLS'siz tablo" diye bir sinif YOK ve olmamali.
_OLAY_EKLE = text("SELECT public.eposta_webhook_olay_ekle(:o)")

#: Imza penceresi. Svix'in kendi onerisi 5 dakikadir.
PENCERE_SN = 300

#: Resend olayi -> (durum, hata kodu).
#:
#: `bounced` ve `complained` icin YENI ENUM DEGERI ACILMADI (goc 0135
#: yorumu): ikisi de ayni eyleme cikiyor — bu adrese bir daha yazma — ve
#: enum'a deger eklemek geri alinamaz bir sema degisikligidir.
OLAY_ESLEME: dict[str, tuple[str, str | None]] = {
    "email.sent": ("gonderildi", None),
    "email.delivered": ("iletildi", None),
    "email.opened": ("okundu", None),
    "email.bounced": ("basarisiz", "bounce"),
    "email.complained": ("basarisiz", "spam_sikayeti"),
    # `delivery_delayed` DURUMU DEGISTIRMEZ: mesaj hala yolda ve
    # `basarisiz` demek erken olurdu; kullanici bosuna yeniden gonderirdi.
    "email.delivery_delayed": ("", None),
}

#: Durum GERI GITMEZ. Olaylar SIRASIZ gelebilir (`opened` bazen
#: `delivered`den once dusuyor); sirali bir sayac olmadan tek guvenli
#: kural ILERLEME'dir. Aksi halde panelde "okundu" yazan bir satir
#: sonradan "gonderildi"ye donerdi.
ILERLEME = {"kuyrukta": 0, "gonderildi": 1, "iletildi": 2, "okundu": 3}


def imza_dogrula(ham: bytes, basliklar, sir: str | None) -> str:
    """Svix imzasini dogrular; olay kimligini doner. Gecersizse 401.

    SIR YOKSA DA 401: yapilandirilmamis bir webhook'u "gecerli" saymak,
    ucu herkese acik birakmak olurdu.
    """
    olay_id = basliklar.get("svix-id") or ""
    zaman = basliklar.get("svix-timestamp") or ""
    imzalar = basliklar.get("svix-signature") or ""
    if not (sir and olay_id and zaman and imzalar):
        raise APIError(401, "unauthorized", "webhook_imzasi_gecersiz")

    try:
        fark = abs(time.time() - int(zaman))
    except ValueError:
        raise APIError(401, "unauthorized", "webhook_imzasi_gecersiz") from None
    if fark > PENCERE_SN:
        raise APIError(401, "unauthorized", "webhook_imzasi_gecersiz")

    # `whsec_` oneki Svix'in kendi bicimi; anahtar onun ARDINDAKI base64.
    ham_sir = sir[len("whsec_"):] if sir.startswith("whsec_") else sir
    try:
        anahtar = base64.b64decode(ham_sir)
    except Exception:
        raise APIError(401, "unauthorized", "webhook_imzasi_gecersiz") from None

    imzalanan = f"{olay_id}.{zaman}.".encode() + ham
    beklenen = base64.b64encode(
        hmac.new(anahtar, imzalanan, hashlib.sha256).digest()
    ).decode()

    # Baslik BIRDEN COK imza tasiyabilir ("v1,xxx v1,yyy") — anahtar
    # donusumu sirasinda ikisi birden gecerlidir.
    for parca in imzalar.split():
        _, _, deger = parca.partition(",")
        if deger and hmac.compare_digest(deger, beklenen):
            return olay_id
    raise APIError(401, "unauthorized", "webhook_imzasi_gecersiz")


@router.post("/resend")
async def resend_webhook(request: Request) -> dict:
    ham = await request.body()
    olay_id = imza_dogrula(ham, request.headers, settings.resend_webhook_sirri)

    import json

    try:
        govde = json.loads(ham or b"{}")
    except Exception:
        raise APIError(400, "validation_error", "webhook_govdesi_gecersiz") from None

    tur = str(govde.get("type") or "")
    veri = govde.get("data") or {}
    mesaj_id = str(veri.get("email_id") or veri.get("id") or "")

    esleme = OLAY_ESLEME.get(tur)
    if esleme is None:
        logger.info("[resend-webhook] bilinmeyen olay turu: %s", tur)
        return {"durum": "yoksayildi"}
    yeni_durum, hata_kodu = esleme
    if not yeni_durum:
        return {"durum": "beklemede"}
    if not mesaj_id:
        logger.warning("[resend-webhook] olayda mesaj kimligi yok: %s", tur)
        return {"durum": "yoksayildi"}

    async with SessionLocal() as session:
        async with session.begin():
            ilk_kez = (
                await session.execute(_OLAY_EKLE, {"o": olay_id})
            ).scalar_one()
            if not ilk_kez:
                # Ayni olay daha once islendi — saglayici tekrar gonderdi.
                return {"durum": "tekrar"}

            tenant_id = (
                await session.execute(_COZ, {"m": mesaj_id})
            ).scalar_one_or_none()
            if tenant_id is None:
                # Bizim gondermedigimiz bir mesaj (ya da kayit silinmis).
                # 404 DONMUYORUZ: saglayici bunu basarisizlik sayip tekrar
                # dener ve sonunda webhook'u kapatir.
                logger.info("[resend-webhook] eslesen gonderim yok")
                return {"durum": "eslesmedi"}

            await set_tenant(session, tenant_id)
            kayit = (
                await session.execute(
                    select(MesajGonderim).where(
                        MesajGonderim.saglayici_mesaj_id == mesaj_id
                    )
                )
            ).scalar_one_or_none()
            if kayit is None:
                return {"durum": "eslesmedi"}

            if hata_kodu:
                kayit.durum = yeni_durum
                kayit.hata = hata_kodu
            elif ILERLEME.get(yeni_durum, 0) > ILERLEME.get(kayit.durum, 0):
                kayit.durum = yeni_durum
                kayit.hata = None

            # (E2E 2026-09) DAVET PANELI DE GUNCELLENIR. Panel
            # `davet.son_durum` anlik kopyasini okuyor ve o yalniz gonderim
            # aninda yaziliyordu: geri donen (bounce) bir davet panelde
            # sonsuza kadar "Gonderildi" gorunuyordu. Kapsam dar tutulur:
            # yalniz e-postayla gitmis ve HENUZ KULLANILMAMIS davet —
            # sonraki bir kod e-postasinin geri donmesi kabul edilmis
            # daveti "gonderilemedi"ye cevirmemeli.
            if kayit.user_id is not None and kayit.kanal == "eposta":
                davet = (
                    await session.execute(
                        select(Davet).where(
                            Davet.user_id == kayit.user_id,
                            Davet.used_at.is_(None),
                        )
                    )
                ).scalar_one_or_none()
                if davet is not None and davet.son_kanal == "eposta":
                    davet.son_durum = kayit.durum
                    davet.son_hata = kayit.hata

    return {"durum": "islendi"}
