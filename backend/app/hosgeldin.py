"""(P250 §3) Hos geldiniz e-postasi — kayit tamamlaninca, BIR KEZ.

KAYDIN TAMAMLANDIGI YERLER (her biri bunu cagirir, ayni oturumda):
  * `POST /auth/set-password`  — e-posta/telefon ile rol kaydinin son adimi,
  * `POST /davet/parola`, `POST /davet/sosyal` — davetle gelen kisi,
  * `oauth._rol_tamamla_baglan` — SSO ile rol kaydi,
  * `kayit.yonetici_tesis`, `kayit.tesis_olustur` — yeni tesis acan yonetici
    (e-postada Tesis ID ve web paneli adresi de var).

BIR KEZ: `UPDATE app_user SET hosgeldin_at = now() WHERE id = :id AND
hosgeldin_at IS NULL RETURNING id`. Satir donmezse e-posta zaten gitmistir
(ya da goc 0162 hesabi "karsilanmis" saymistir). Es zamanli iki tamamlama
istegi yalniz BIR e-posta uretir. Rol degisimi ve tekrar kayit isareti
silmez.

KAYDI DUSURMEZ: gonderim hatasi (saglayici dusuk, adres sentetik) kaydi
GERI ALMAZ. Saglayici basarisizsa satir kuyruga duser ve yeniden denenir;
adres yoksa e-posta atlanir ama isaret yine konur — o kisiye ikinci bir
"hos geldiniz" firsati beklemenin anlami yok.
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from . import islem_epostasi
from .config import settings
from .gonderim import tenant_ayari
from .hosgeldin_eposta import hosgeldin_eposta
from .models import AppUser, Tenant

_log = logging.getLogger(__name__)

TUR = "hosgeldin"


async def bir_kez_gonder(
    db: AsyncSession,
    user: AppUser,
    *,
    dil: str,
    tesis_kodu: str | None = None,
) -> bool:
    """Isareti koyar ve (gonderilebiliyorsa) e-postayi yollar.

    Cagiran `app.current_tenant_id`i AYARLAMIS olmali (RLS). Doner: bu
    cagri isareti KOYDU mu (yani e-posta bu cagrida mi denendi).
    """
    koydu = (
        await db.execute(
            text(
                "UPDATE app_user SET hosgeldin_at = now() "
                "WHERE id = :id AND hosgeldin_at IS NULL RETURNING id"
            ),
            {"id": user.id},
        )
    ).scalar_one_or_none()
    if koydu is None:
        return False
    if islem_epostasi.gonderilemez_sebebi(user, tercihe_uy=False):
        return True
    try:
        async with db.begin_nested():
            await _gonder(db, user, dil=dil, tesis_kodu=tesis_kodu)
    except Exception:  # pragma: no cover - kaydi asla dusurmez
        # Hos geldiniz e-postasi KAYDIN PARCASI DEGIL: burada patlayan bir
        # sey (savepoint geri alinir) kullanicinin parolasini/oturumunu geri
        # aldirmamali.
        _log.exception("hos geldiniz e-postasi gonderilemedi user=%s", user.id)
    return True


async def _gonder(
    db: AsyncSession, user: AppUser, *, dil: str, tesis_kodu: str | None
) -> None:
    tenant = (
        await db.execute(select(Tenant).where(Tenant.id == user.tenant_id))
    ).scalar_one()
    diller = await islem_epostasi.alici_dili(db, [user.id], dil)
    konu, metin, html = hosgeldin_eposta(
        dil=diller[user.id],
        rol=user.role,
        tesis_ad=tenant.ad,
        ad=user.ad,
        yil=datetime.now(tz=timezone.utc).year,
        tesis_kodu=tesis_kodu,
        web_url=settings.portal_base_url.rstrip("/") or None,
    )
    islem_epostasi.hemen_gonder(
        db,
        ayar=await tenant_ayari(db, user.tenant_id),
        tenant_id=user.tenant_id,
        kisi=user,
        tur=TUR,
        konu=konu,
        metin=metin,
        html=html,
        gonderen_id=None,
    )
    await db.flush()
