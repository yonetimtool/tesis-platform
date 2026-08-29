"""(P155 / §7) DAVET UCLARI — cozme, tamamlama (parola/sosyal), panel.

IKI KITLE, TEK PREFIX:
  * PUBLIC (oturumsuz): /davet/coz · /davet/parola · /davet/sosyal.
    Davetle gelen kullanicinin henuz oturumu YOKTUR; baglam jetonla
    (RLS bypass `davet_coz`) kurulur.
  * YONETICI (oturumlu): GET /davet · POST /davet/{user_id}/yeniden.
    Yonetici gitmeyen davetleri gorur ve yeniden gonderir.

JETON KIMLIK DOGRULAMA ARACI DEGIL (sartname kisiti): jeton yalniz KAYDI
kolaylastirir. Kullanici yine KENDI kimligini olusturur — parola belirler
ya da kendi sosyal hesabini baglar. Jeton "su daireye kaydolabilirsin"
der; "sen busun" DEMEZ.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

import redis.asyncio as aioredis
from fastapi import APIRouter, Depends
from fastapi.responses import HTMLResponse
from sqlalchemy import select, text, update
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user, record_audit
from ..davet import (
    davet_gonder,
    davet_olustur_veya_tazele,
    davet_vazgec_coz,
    jeton_hashle,
)
from ..db import SessionLocal, set_tenant
from ..deps import get_redis, get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Davet
from ..schemas import (
    DavetCozRequest,
    DavetCozResponse,
    DavetDurumListResponse,
    DavetDurumOut,
    DavetParolaRequest,
    DavetSosyalRequest,
    TokenPair,
)
from ..security import hash_password
from .auth import _issue_token_pair
from .oauth import _baglama_coz, _kimligi_bagla

router = APIRouter(prefix="/davet", tags=["davet"])

# Cozme/tamamlama hatalari AYIRT EDILIR (kayit ucunun aksine): davet zaten
# yoneticinin ACIKCA yarattigi bir sey, "sizdirma" kaygisi yok. Ayirt etmek
# kullaniciya NE yapacagini soyler (yeniden davet iste / bag bitti).
_DAVET_YOK = APIError(404, "not_found", "davet_bulunamadi")
_DAVET_SURESI = APIError(410, "gone", "davet_suresi_doldu")
_DAVET_KULLANILMIS = APIError(410, "gone", "davet_kullanilmis")
_DAVET_GECERSIZ = APIError(410, "gone", "davet_gecersiz")

_YONETIM = require_role("admin", "yonetici")

#: (P190) List-Unsubscribe tek-tik onay sayfasi (minimal; RFC 8058 SHOULD).
_VAZGEC_SAYFA = (
    "<!doctype html><html lang='tr'><head><meta charset='utf-8'>"
    "<meta name='viewport' content='width=device-width,initial-scale=1'>"
    "<title>Yönetiyor</title></head>"
    "<body style='font-family:Arial,Helvetica,sans-serif;max-width:520px;"
    "margin:48px auto;padding:0 20px;color:#102060'>"
    "<h2 style='color:#102060'>Yönetiyor</h2>{govde}</body></html>"
)


@router.post("/vazgec/{jeton}", response_class=HTMLResponse)
async def davet_eposta_vazgec(jeton: str) -> HTMLResponse:
    """(P190) List-Unsubscribe TEK-TIK (RFC 8058). Posta istemcisi bu uca body
    `List-Unsubscribe=One-Click` ile POST atar; kisi davet E-POSTALARINDAN
    cikarilir (app_user.davet_vazgecti=true), yeniden gonderimde bile atlanir.

    KIMLIK ONCESIDIR (oturum yok): yetki, jetonun jwt_secret ile HMAC imzasidir
    (baskasini iptal ettirmeye kapali). Tenant baglami JETONDAN cozulur ve RLS
    o baglamla saglanir — SECURITY DEFINER gerekmez. Gecersiz jetonda da 200
    (varlik/gecerlilik sizdirmamak icin), gorunur sayfa metni farklidir."""
    coz = davet_vazgec_coz(jeton)
    if coz is None:
        return HTMLResponse(
            _VAZGEC_SAYFA.format(govde="<p>Bağlantı geçersiz.</p>"),
            status_code=200,
        )
    user_id, tenant_id = coz
    async with SessionLocal() as session:
        async with session.begin():
            # Tenant baglami jetondan; RLS UPDATE'i bu tenant'in satirina siner.
            await set_tenant(session, tenant_id)
            await session.execute(
                update(AppUser)
                .where(AppUser.id == user_id)
                .values(davet_vazgecti=True)
            )
    return HTMLResponse(
        _VAZGEC_SAYFA.format(
            govde="<p>Davet e-postalarından çıkarıldınız.</p>"
        ),
        status_code=200,
    )


def _maskele(telefon: str) -> str:
    if len(telefon) <= 6:
        return "*" * len(telefon)
    return f"{telefon[:5]}***{telefon[-3:]}"


async def _coz_ve_dogrula(session: AsyncSession, jeton: str):
    """Jetonu cozer ve ZAMAN/KULLANIM/HESAP kontrolunu yapar; satiri doner.

    Kontroller TEK YERDE: uc uc (coz/parola/sosyal) ayni kurala uymali,
    yoksa biri suresi dolmus jetonu kabul edip otekisi reddederdi."""
    jhash = jeton_hashle(jeton.strip())
    row = (
        await session.execute(
            text(
                "SELECT davet_id, tenant_id, tenant_ad, user_id, rol, ad, "
                "telefon, daire_no, son_gecerlilik, used_at, password_set, "
                "is_active FROM public.davet_coz(:h)"
            ),
            {"h": jhash},
        )
    ).one_or_none()
    if row is None:
        raise _DAVET_YOK
    if not row.is_active:
        raise _DAVET_GECERSIZ
    if row.used_at is not None:
        raise _DAVET_KULLANILMIS
    if row.son_gecerlilik < datetime.now(timezone.utc):
        raise _DAVET_SURESI
    # PAROLASI OLAN HESAP: davet zaten tuketilmis sayilir (kullanici
    # girebiliyor). Bu, `used_at` yazilmadan hesabin baska yoldan
    # tamamlandigi kenar durumu kapatir.
    if row.password_set:
        raise _DAVET_KULLANILMIS
    return row


@router.post("/coz", response_model=DavetCozResponse)
async def davet_coz(body: DavetCozRequest) -> DavetCozResponse:
    """Jetonu cozer; tesis/rol/daire/telefon(maskeli)/ad doner.

    COZME JETONU TUKETMEZ: bag tarayicida acilip sonra uygulamada da
    acilabilsin (ertelenmis derin baglanti). Tuketim tamamlamada olur."""
    async with SessionLocal() as session:
        async with session.begin():
            row = await _coz_ve_dogrula(session, body.jeton)
            return DavetCozResponse(
                tesis_ad=row.tenant_ad,
                rol=row.rol,
                ad=row.ad,
                telefon_maskeli=_maskele(row.telefon),
                daire_no=row.daire_no,
            )


@router.post("/parola", response_model=TokenPair)
async def davet_parola(
    body: DavetParolaRequest,
    redis: aioredis.Redis = Depends(get_redis),
) -> TokenPair:
    """Davetle gelen kullanici PAROLA belirler; oturum acilir.

    SMS YOK: davet jetonu, yoneticinin bu kisiyi ekledigi kanittir."""
    async with SessionLocal() as session:
        async with session.begin():
            row = await _coz_ve_dogrula(session, body.jeton)
            await set_tenant(session, row.tenant_id)
            user = (
                await session.execute(
                    select(AppUser).where(AppUser.id == row.user_id)
                )
            ).scalar_one_or_none()
            if user is None or not user.is_active or user.password_set:
                raise _DAVET_GECERSIZ

            user.password_hash = hash_password(body.new_password)
            user.password_set = True
            user.temp_code_hash = None
            if body.ad:
                user.ad = body.ad.strip()

            davet = (
                await session.execute(
                    select(Davet).where(Davet.user_id == user.id)
                )
            ).scalar_one()
            davet.used_at = datetime.now(timezone.utc)

            await record_audit(
                session, action=Action.PASSWORD_SET, tenant_id=row.tenant_id,
                actor_user_id=user.id, actor_rol=user.role,
                resource_type="app_user", resource_id=user.id,
                meta={"method": "davet_parola"},
            )
            await session.flush()

    return await _issue_token_pair(redis, user)


@router.post("/sosyal", response_model=TokenPair)
async def davet_sosyal(
    body: DavetSosyalRequest,
    redis: aioredis.Redis = Depends(get_redis),
) -> TokenPair:
    """Davetle gelen kullanici SOSYAL hesabini baglar; oturum acilir.

    SMS YOK (sartname §7): davet jetonu + saglayici kimligi birlikte SMS'in
    yerini tutar. Saglayici telefon vermez ama davet zaten telefonu bilir."""
    kimlik = _baglama_coz(body.baglama_jetonu)
    async with SessionLocal() as session:
        async with session.begin():
            row = await _coz_ve_dogrula(session, body.jeton)
            await set_tenant(session, row.tenant_id)
            user = (
                await session.execute(
                    select(AppUser).where(AppUser.id == row.user_id)
                )
            ).scalar_one_or_none()
            if user is None or not user.is_active:
                raise _DAVET_GECERSIZ

            await _kimligi_bagla(
                session, user=user, saglayici=kimlik["saglayici"],
                subject=kimlik["subject"], eposta=kimlik.get("eposta"),
            )
            # Sosyal yolda parola belirlenmez; hesap yine de "tamamlandi"
            # sayilir (kimlik baglandi). `password_set` FALSE kalir — bu
            # kasitli: kullanici parola YOLUYLA giremez, yalniz saglayiciyla.
            if body.ad:
                user.ad = body.ad.strip()

            davet = (
                await session.execute(
                    select(Davet).where(Davet.user_id == user.id)
                )
            ).scalar_one()
            davet.used_at = datetime.now(timezone.utc)

            await record_audit(
                session, action=Action.LOGIN_OK, tenant_id=row.tenant_id,
                actor_user_id=user.id, actor_rol=user.role,
                resource_type="app_user", resource_id=user.id,
                meta={"method": f"davet_sosyal:{kimlik['saglayici']}"},
            )
            await session.flush()
            return await _issue_token_pair(redis, user)


# ======================= YONETICI: DAVET PANELI =========================== #


@router.get("", response_model=DavetDurumListResponse)
async def davet_listesi(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> DavetDurumListResponse:
    """Tesisin TUM davetleri + son gonderim durumu (gitmeyeni gormek icin).

    Tamamlanmislar da listelenir (used_at dolu) ama panel onlari ayirir;
    yoneticinin sorusu "kimin daveti gitmedi / bekliyor"dur."""
    rows = (
        await db.execute(
            text(
                """
                SELECT d.user_id, u.ad, u.role::text AS rol, u.telefon,
                       d.son_kanal::text, d.son_durum::text, d.son_hata,
                       d.son_gonderim_at, d.used_at, d.son_gecerlilik,
                       (SELECT un.no FROM unit_resident r
                          JOIN unit un ON un.id = r.unit_id
                         WHERE r.user_id = u.id AND r.bitis IS NULL
                         ORDER BY r.created_at LIMIT 1) AS daire_no
                FROM davet d
                JOIN app_user u ON u.id = d.user_id
                ORDER BY d.updated_at DESC
                """
            )
        )
    ).all()
    # `db` tenant baglaminda (RLS): `tenant` yalniz cagiranin tesisini doner.
    tesis_kodu = (
        await db.execute(text("SELECT kayit_kodu FROM tenant LIMIT 1"))
    ).scalar_one_or_none()
    return DavetDurumListResponse(
        tesis_kodu=tesis_kodu,
        items=[
            DavetDurumOut(
                user_id=r.user_id, ad=r.ad, rol=r.rol, telefon=r.telefon,
                daire_no=r.daire_no, son_kanal=r.son_kanal,
                son_durum=r.son_durum, son_hata=r.son_hata,
                son_gonderim_at=r.son_gonderim_at, used_at=r.used_at,
                son_gecerlilik=r.son_gecerlilik,
            )
            for r in rows
        ]
    )


@router.post("/{user_id}/yeniden", response_model=DavetDurumOut)
async def davet_yeniden_gonder(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> DavetDurumOut:
    """Bir kullanicinin davetini TAZELER ve yeniden gonderir.

    Yeni jeton uretilir (eski bag olur); saglayici artik hazirsa bu sefer
    gider. Hedef kullanici PAROLASIZ olmali (davetin anlami budur)."""
    hedef = (
        await db.execute(select(AppUser).where(AppUser.id == user_id))
    ).scalar_one_or_none()
    if hedef is None:
        raise APIError(404, "not_found", "kullanici_bulunamadi")
    if hedef.password_set:
        raise APIError(409, "conflict", "kullanici_zaten_kayitli")

    tenant_ad = (
        await db.execute(
            text("SELECT ad FROM tenant WHERE id = :t"),
            {"t": str(user.tenant_id)},
        )
    ).scalar_one()

    davet, duz = await davet_olustur_veya_tazele(
        db, user=hedef, olusturan_id=user.id
    )
    await davet_gonder(
        db, davet=davet, duz_jeton=duz, user=hedef,
        tenant_ad=tenant_ad, gonderen_id=user.id,
    )
    await audit_user(
        db, user, Action.RESIDENT_CREATE, resource_type="davet",
        resource_id=hedef.id, meta={"eylem": "davet_yeniden"},
    )

    daire = (
        await db.execute(
            text(
                "SELECT un.no FROM unit_resident r JOIN unit un ON un.id = r.unit_id "
                "WHERE r.user_id = :u AND r.bitis IS NULL "
                "ORDER BY r.created_at LIMIT 1"
            ),
            {"u": str(hedef.id)},
        )
    ).scalar_one_or_none()
    return DavetDurumOut(
        user_id=hedef.id, ad=hedef.ad, rol=hedef.role, telefon=hedef.telefon,
        daire_no=daire, son_kanal=davet.son_kanal, son_durum=davet.son_durum,
        son_hata=davet.son_hata, son_gonderim_at=davet.son_gonderim_at,
        used_at=davet.used_at, son_gecerlilik=davet.son_gecerlilik,
    )
