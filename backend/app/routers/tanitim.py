"""(P127.2) Tanitim sitesi iletisim formu — PUBLIC gonderim + admin okuma.

KAYIT ONCE, BILDIRIM SONRA (portal formuyla AYNI ilke, P38): mesaj once
veritabanina yazilir, sonra e-posta DENENIR. Tersi yapilsaydi SMTP
yapilandirilmamis bir kurulumda musteri adayi SESSIZCE KAYBOLURDU —
"iletisim formu calisiyor mu?" sorusunun cevabi da olmazdi.

TENANT YOK: yazan kisinin bir tesisi yoktur. Kayit `tanitim_iletisim`
tablosuna gider ve o tabloda RLS acik, POLITIKA YOK — app_rw dogrudan
okuyamaz/yazamaz. Yazma/okuma SECURITY DEFINER fonksiyonlarindan gecer
(goc 0033). Boylece kimliksiz uc, tablonun tamamini okuyabilecek bir yetki
TASIMAZ: form gonderen biri baska adaylarin adini/telefonunu goremez.

HIZ SINIRI: uc kimliksizdir, yani acik bir spam yuzeyidir. Sabit pencere
(IP basina) Redis'te tutulur. Sinir ASILINCA 429 doner ve mesaj YAZILMAZ.
Redis erisilemezse istek REDDEDILMEZ (kayit yine yazilir): iletisim
formunu bir onbellek arizasi yuzunden kapatmak, korumanin kendisinden
pahali olurdu.
"""
from __future__ import annotations

import logging
import uuid

import redis.asyncio as aioredis
from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy import text

from .mesajlar import _saglayici
from ..config import settings
from ..db import SessionLocal
from ..deps import get_redis, require_role
from ..errors import APIError
from ..ceviri import DESTEKLENEN_DILLER
from ..models import AppUser
from ..schemas import (
    TanitimIletisimIstek,
    TanitimIletisimListResponse,
    TanitimIletisimOkunduIstek,
    TanitimIletisimOut,
)

log = logging.getLogger(__name__)

router = APIRouter(tags=["tanitim"])

_ADMIN = require_role("admin")

#: Sabit pencere: IP basina 60 dakikada 5 gonderim.
#:
#: Neden bu kadar dusuk: gercek bir ziyaretci gunde bir kez yazar. Sinir
#: DEMO TALEBINI engellemeyecek kadar yuksek, betikle doldurmayi
#: caydiracak kadar dusuk secildi.
_PENCERE_SN = 3600
_SINIR = 5


async def _hiz_siniri(redis: aioredis.Redis, ip: str) -> None:
    """Sinir asildiysa 429. Redis yoksa SESSIZCE gecer (bkz. modul notu)."""
    anahtar = f"tanitim_iletisim:{ip}"
    try:
        sayi = await redis.incr(anahtar)
        if sayi == 1:
            await redis.expire(anahtar, _PENCERE_SN)
    except Exception as exc:  # noqa: BLE001 — onbellek arizasi formu kapatmaz
        log.warning("tanitim iletisim hiz siniri okunamadi: %s", exc)
        return
    if sayi > _SINIR:
        raise APIError(429, "rate_limited", "cok_fazla_istek")


def _istemci_ip(req: Request) -> str:
    """Caddy arkasindayiz: gercek IP `X-Forwarded-For`un ILK degeridir.

    Basligi ISTEMCI de gonderebilir; ama bu deger YALNIZ hiz siniri
    anahtari uretmek icin kullanilir — yetki karari degildir. En kotu
    durumda saldirgan kendi sayacini boler, baskasinin sayacini SIFIRLAYAMAZ
    (yeni anahtar acar).
    """
    xff = req.headers.get("x-forwarded-for", "")
    if xff:
        return xff.split(",")[0].strip()[:64]
    return (req.client.host if req.client else "bilinmiyor")[:64]


def _bildir(kayit_id: uuid.UUID, body: TanitimIletisimIstek) -> None:
    """Platform ekibine e-posta DENER; basarisizlik kaydi ETKILEMEZ.

    Hedef `smtp_from`dur: ayri bir "satis adresi" ayari eklemek, bugun
    kimsenin doldurmayacagi ikinci bir yapilandirma alani olurdu. SMTP
    yapilandirilmamissa saglayici LOG'a yazar (bkz. `_saglayici`).
    """
    hedef = getattr(settings, "smtp_from", None)
    if not hedef:
        log.info("tanitim iletisim %s: e-posta hedefi yapilandirilmamis", kayit_id)
        return
    govde = (
        f"Yeni tanitim formu mesaji.\n\n"
        f"Ad: {body.ad}\nE-posta: {body.email or '-'}\n"
        f"Telefon: {body.telefon or '-'}\nDil: {body.dil or '-'}\n\n{body.mesaj}"
    )
    try:
        _saglayici("eposta").gonder(hedef, "Yönetio — yeni iletişim mesajı", govde)
    except Exception as exc:  # noqa: BLE001 — kayit zaten atildi
        log.warning("tanitim iletisim %s bildirimi basarisiz: %s", kayit_id, exc)


@router.post("/public/tanitim-iletisim", status_code=201, response_model=dict)
async def tanitim_iletisim_gonder(
    body: TanitimIletisimIstek,
    request: Request,
    redis: aioredis.Redis = Depends(get_redis),
) -> dict:
    await _hiz_siniri(redis, _istemci_ip(request))

    # Bilinmeyen dil SAKLANMAZ: "tr-TR-x-hack" gibi bir deger listede
    # gorunur ve donuste kime hangi dilde yazilacagini bulandirirdi.
    dil = body.dil if body.dil in DESTEKLENEN_DILLER else None

    async with SessionLocal() as db:
        async with db.begin():
            kayit_id = (
                await db.execute(
                    text(
                        "SELECT public.tanitim_iletisim_ekle("
                        ":ad, :email, :telefon, :mesaj, :dil)"
                    ),
                    {
                        "ad": body.ad.strip(),
                        "email": (body.email or "").strip() or None,
                        "telefon": (body.telefon or "").strip() or None,
                        "mesaj": body.mesaj.strip(),
                        "dil": dil,
                    },
                )
            ).scalar_one()
    # Bildirim TRANSACTION DISINDA: SMTP yavaslarsa/duserse kayit yine de
    # commit edilmis olur.
    _bildir(kayit_id, body)
    return {"ok": True}


@router.get("/tanitim-iletisim", response_model=TanitimIletisimListResponse)
async def tanitim_iletisim_listele(
    okundu: bool | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    _: AppUser = Depends(_ADMIN),
) -> TanitimIletisimListResponse:
    """Gelen musteri adaylari — YALNIZ platform admini.

    Tenant kapsamli DEGIL (kayitlarin tenant'i yok); bu yuzden `SessionLocal`
    ciplak kullanilir ve okuma SECURITY DEFINER fonksiyonundan gecer —
    `audit_log_list` / `support_ticket_list` deseni.
    """
    async with SessionLocal() as db:
        async with db.begin():
            satirlar = (
                await db.execute(
                    text(
                        "SELECT * FROM public.tanitim_iletisim_listele("
                        ":okundu, :lim, :off)"
                    ),
                    {"okundu": okundu, "lim": limit, "off": offset},
                )
            ).mappings().all()
    toplam = int(satirlar[0]["total"]) if satirlar else 0
    return TanitimIletisimListResponse(
        meta={"limit": limit, "offset": offset, "total": toplam},
        items=[TanitimIletisimOut(**{k: v for k, v in r.items() if k != "total"}) for r in satirlar],
    )


@router.patch("/tanitim-iletisim/{kayit_id}", response_model=TanitimIletisimOut)
async def tanitim_iletisim_okundu(
    kayit_id: uuid.UUID,
    body: TanitimIletisimOkunduIstek,
    _: AppUser = Depends(_ADMIN),
) -> TanitimIletisimOut:
    """Okundu isaretle — listeyi eritmenin tek yolu (silme YOK).

    Silme bilincli olarak yok: gelen bir ticari iletisim kaydini tek
    tiklamayla yok etmek, "kim ne zaman yazdi" sorusunu cevapsiz birakirdi.
    Saklama suresi bir IS karari olarak KVKK belgesine yazildi.
    """
    async with SessionLocal() as db:
        async with db.begin():
            satir = (
                await db.execute(
                    text(
                        "SELECT * FROM public.tanitim_iletisim_okundu(:id, :okundu)"
                    ),
                    {"id": kayit_id, "okundu": body.okundu},
                )
            ).mappings().first()
    if satir is None:
        raise APIError(404, "not_found", "kayit_bulunamadi")
    return TanitimIletisimOut(**dict(satir))
