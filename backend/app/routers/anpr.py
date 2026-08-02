"""ANPR girisi (P16) — kaynaktan bagimsiz plaka okuma ucu + onay kuyrugu.

Uc grup uc:

  * `POST /integrations/anpr/events`  — KAMERA KUTUSU yazar. Kimlik JWT
    DEGIL, tenant basina API ANAHTARI ile kurulur (`X-ANPR-Key`): kamera
    kutusunun kullanici oturumu yoktur ve token yenileyemez.
  * `GET  /integrations/anpr/events`  — olay defteri (admin + security).
  * `POST /integrations/anpr/events/{id}/onay` — DUSUK GUVENLI okumanin
    insan karari (kabul/ret + plaka duzeltme).
  * `/integrations/anpr/keys` (GET/POST/DELETE) — anahtar yonetimi (admin).

TASARIM — NEDEN AYRI BIR KIMLIK YOLU:
Kutu bir kullanici degildir. JWT verirsek ya suresiz token uretiriz (kotu) ya
da kutuya yenileme mantigi yazariz (yapamayiz — Frigate'in webhook'u sabit
baslik gonderir). Anahtar `<kimlik>.<sir>` bicimindedir; sunucu YALNIZ `sir`in
sha256'sini saklar. Cozumleme `anpr_key_coz` SECURITY DEFINER fonksiyonuyla
yapilir: istek geldiginde tenant HENUZ BILINMEDIGI icin RLS baglami kurulamaz
(mevcut `audit_log_list` deseni).

AKIS FEED'I: ANPR gecisleri AYRI bir akis dali GEREKTIRMEZ — `vehicle_pass`
satiri olarak acildiklari icin `/activity`nin mevcut `arac_giris`/`arac_cikis`
dallarindan zaten akarlar. Bu bilincli: "sayim ile kayit asla ayrisamaz"
ilkesinin akis karsiligi.
"""
from __future__ import annotations

import hashlib
import secrets
import uuid
from datetime import UTC, datetime
from decimal import Decimal
from typing import Any

from fastapi import APIRouter, Depends, Header, Query, Response
from sqlalchemy import select, text, update
from sqlalchemy.ext.asyncio import AsyncSession

from .. import anpr as anpr_core
from ..audit import Action, audit_user
from ..db import SessionLocal, set_tenant
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AnprApiKey, AnprEvent, AppUser, Tenant, VehiclePass
from ..schemas import (
    AnprApiKeyCreate,
    AnprApiKeyCreated,
    AnprApiKeyOut,
    AnprEventIn,
    AnprEventListResponse,
    AnprEventOut,
    AnprOnayIn,
    PageMetaOut,
)

router = APIRouter(prefix="/integrations/anpr", tags=["anpr"])

# Okuma + onay: admin + security (arac gecisi listesiyle AYNI kume — plaka
# kisisel veriye baglanabilir, KVKK).
_OKUYUCU = require_role("admin", "security")
# Anahtar yonetimi YALNIZ admin: anahtar tenant'in tum gecis akisini yazma
# yetkisidir; site yoneticisine acilmaz.
_ANAHTAR_YONETICI = require_role("admin")


def _sir_hash(sir: str) -> str:
    return hashlib.sha256(sir.encode()).hexdigest()


async def anpr_tenant_db(
    x_anpr_key: str | None = Header(None, alias="X-ANPR-Key"),
):
    """API anahtarindan tenant baglamli oturum kurar.

    `get_tenant_db`in ANAHTAR karsiligi. Sirasiyla: anahtari ayristir →
    SECURITY DEFINER ile cozumle → oturuma tenant baglamini kur.

    Basarisiz her durum AYNI 401'i doner (anahtar yok / bicim bozuk /
    bulunamadi / pasif): hangi asamada dustugunu soylemek, gecerli bir
    `kimlik` bulmaya calisan birine bilgi verir.
    """
    if not x_anpr_key or "." not in x_anpr_key:
        raise APIError(401, "unauthorized", "anpr_anahtar_gecersiz")
    kimlik, _, sir = x_anpr_key.partition(".")
    if not kimlik or not sir:
        raise APIError(401, "unauthorized", "anpr_anahtar_gecersiz")

    async with SessionLocal() as session:
        async with session.begin():
            satir = (
                await session.execute(
                    text(
                        "SELECT tenant_id, key_id FROM public.anpr_key_coz("
                        ":kimlik, :sir_hash)"
                    ),
                    {"kimlik": kimlik, "sir_hash": _sir_hash(sir)},
                )
            ).mappings().first()
            if satir is None:
                raise APIError(401, "unauthorized", "anpr_anahtar_gecersiz")
            await set_tenant(session, satir["tenant_id"])
            # Kullanim damgasi: fonksiyon STABLE kalsin diye ORADA degil
            # BURADA atilir (her istekte bir UPDATE, ama transaction zaten var).
            await session.execute(
                update(AnprApiKey)
                .where(AnprApiKey.id == satir["key_id"])
                .values(son_kullanim=datetime.now(tz=UTC))
            )
            yield session, satir["tenant_id"]


async def _tenant_ayarlari(db: AsyncSession) -> tuple[Decimal, bool]:
    satir = (
        await db.execute(
            select(Tenant.anpr_guven_esigi, Tenant.anpr_otomatik_cikis)
        )
    ).first()
    if satir is None:
        # RLS altinda tenant satiri her zaman gorunur; yine de savunma.
        return Decimal("0.850"), True
    return Decimal(str(satir[0])), bool(satir[1])


async def _acik_gecis(db: AsyncSession, plaka: str) -> VehiclePass | None:
    return (
        await db.execute(
            select(VehiclePass)
            .where(VehiclePass.plaka == plaka)
            .where(VehiclePass.cikis_zamani.is_(None))
            .order_by(VehiclePass.giris_zamani.desc(), VehiclePass.id.desc())
            .limit(1)
        )
    ).scalar_one_or_none()


@router.post("/events", response_model=AnprEventOut, status_code=201)
async def olay_al(
    govde: AnprEventIn,
    oturum=Depends(anpr_tenant_db),
) -> AnprEventOut:
    """Plaka okuma olayini al, deftere yaz ve gecise cevir.

    IDEMPOTENT: ayni `(kaynak, kaynak_olay_id)` ikinci kez gelirse YENI kayit
    acilmaz, MEVCUT olay doner (200 degil 201 doner — istemci acisindan
    "kabul edildi" ayni sonuctur ve Frigate tekrarlarinda gurultu olmaz).

    Olay HER ZAMAN deftere yazilir: gecersiz plaka bile `hata` durumuyla
    kaydedilir ki saha "kamera sacmaliyor" diyebilsin. Istek DUSURULMEZ —
    kutunun yeniden denemesi bir sey duzeltmez.
    """
    db, tenant_id = oturum
    ham_govde: dict[str, Any] = govde.model_dump(mode="json")

    # 1) Adaptor — kaynaga ozgu bicimden normalize gövdeye.
    try:
        olay = anpr_core.coz(govde.kaynak, ham_govde)
    except APIError as e:
        # Bilinmeyen kaynak SOZLESME hatasidir (422) — deftere yazmayiz,
        # cunku hangi tenant'in hangi kamerasi oldugunu bilemeyiz.
        if e.mesaj == "anpr_kaynak_bilinmiyor":
            raise
        # Veri hatasi (plaka/zaman): DEFTERE yaz, 201 don.
        kayit = AnprEvent(
            tenant_id=tenant_id,
            kaynak=govde.kaynak,
            kaynak_olay_id=(govde.kaynak_olay_id or uuid.uuid4().hex),
            # Plaka NOT NULL + CHECK: cozulemedi ise yer tutucu.
            plaka="XX",
            plaka_ham=govde.plaka,
            zaman=govde.zaman or datetime.now(tz=UTC),
            kamera=govde.kamera,
            # Kisa KOD saklanir (PII yok): `mesaj` alani hata KIMLIGIDIR.
            yon=anpr_core.YON_BILINMIYOR,
            durum=anpr_core.DURUM_HATA,
            durum_nedeni=e.mesaj,
            ham=ham_govde,
        )
        db.add(kayit)
        await db.flush()
        return AnprEventOut.model_validate(kayit)

    # 2) Idempotency — ayni kaynak olayi daha once geldi mi?
    mevcut = (
        await db.execute(
            select(AnprEvent)
            .where(AnprEvent.kaynak == olay.kaynak)
            .where(AnprEvent.kaynak_olay_id == olay.kaynak_olay_id)
        )
    ).scalar_one_or_none()
    if mevcut is not None:
        return AnprEventOut.model_validate(mevcut)

    # 3) Karar.
    esik, otomatik_cikis = await _tenant_ayarlari(db)
    acik = await _acik_gecis(db, olay.plaka)
    karar = anpr_core.karar_ver(
        olay,
        acik_gecis_var=acik is not None,
        esik=esik,
        otomatik_cikis=otomatik_cikis,
    )

    kayit = AnprEvent(
        tenant_id=tenant_id,
        kaynak=olay.kaynak,
        kaynak_olay_id=olay.kaynak_olay_id,
        plaka=olay.plaka,
        plaka_ham=olay.plaka_ham,
        zaman=olay.zaman,
        kamera=olay.kamera,
        yon=olay.yon,
        guven=olay.guven,
        foto_key=olay.foto_key,
        durum=karar.durum,
        durum_nedeni=karar.neden,
        ham=olay.ham,
    )
    db.add(kayit)

    # 4) Eylem.
    if karar.eylem == anpr_core.EYLEM_GIRIS_AC:
        gecis = VehiclePass(
            tenant_id=tenant_id,
            plaka=olay.plaka,
            giris_zamani=olay.zaman,
            ziyaretci_mi=False,
            # ANPR gecisini BIR INSAN KAYDETMEZ (0011).
            kaydeden_user_id=None,
            kaynak="anpr",
        )
        db.add(gecis)
        await db.flush()
        kayit.vehicle_pass_id = gecis.id
    elif karar.eylem == anpr_core.EYLEM_CIKIS_KAPAT and acik is not None:
        acik.cikis_zamani = olay.zaman
        kayit.vehicle_pass_id = acik.id

    await db.flush()
    return AnprEventOut.model_validate(kayit)


@router.get("/events", response_model=AnprEventListResponse)
async def olay_listesi(
    durum: str | None = Query(None),
    plaka: str | None = Query(None, min_length=1, max_length=64),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_OKUYUCU),
) -> AnprEventListResponse:
    """Olay defteri (created_at DESC). `?durum=onay_bekliyor` onay kuyrugudur."""
    if durum is not None and durum not in (
        anpr_core.DURUM_ISLENDI,
        anpr_core.DURUM_ONAY_BEKLIYOR,
        anpr_core.DURUM_YOK_SAYILDI,
        anpr_core.DURUM_HATA,
    ):
        raise APIError(422, "validation_error", "anpr_durum_gecersiz")

    kosullar = []
    if durum is not None:
        kosullar.append(AnprEvent.durum == durum)
    if plaka:
        norm = anpr_core.norm_plaka_yumusak(plaka)
        # Gecersiz arama metni BOS SONUC verir (422 degil): arama kutusuna
        # yarim plaka yazmak hata degildir.
        kosullar.append(AnprEvent.plaka.startswith(norm or "\x00"))

    temel = select(AnprEvent)
    for k in kosullar:
        temel = temel.where(k)
    toplam = (
        await db.execute(
            select(text("count(*)")).select_from(temel.subquery())
        )
    ).scalar_one()
    satirlar = (
        await db.execute(
            temel.order_by(AnprEvent.created_at.desc(), AnprEvent.id.desc()).limit(limit).offset(offset)
        )
    ).scalars().all()
    return AnprEventListResponse(
        meta=PageMetaOut(limit=limit, offset=offset, total=int(toplam)),
        items=[AnprEventOut.model_validate(s) for s in satirlar],
    )


@router.post("/events/{event_id}/onay", response_model=AnprEventOut)
async def onayla(
    event_id: uuid.UUID,
    govde: AnprOnayIn,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUYUCU),
) -> AnprEventOut:
    """Dusuk guvenli okumanin INSAN karari.

    `onay=true`  → okuma kabul edilir ve normal karar akisi UYGULANIR
                   (giris ac / cikis kapat). `plaka` verilirse OCR duzeltilir.
    `onay=false` → okuma reddedilir, olay `yok_sayildi` olur.

    YALNIZ `onay_bekliyor` durumundaki olay karara acilir; islenmis bir olayi
    yeniden karara sokmak cift gecis uretirdi (409).
    """
    kayit = (
        await db.execute(select(AnprEvent).where(AnprEvent.id == event_id))
    ).scalar_one_or_none()
    if kayit is None:
        raise APIError(404, "not_found", "kayit_bulunamadi")
    if kayit.durum != anpr_core.DURUM_ONAY_BEKLIYOR:
        raise APIError(409, "conflict", "anpr_olay_onay_beklemiyor")

    if not govde.onay:
        kayit.durum = anpr_core.DURUM_YOK_SAYILDI
        kayit.durum_nedeni = "elle_reddedildi"
        await audit_user(
            db, user, Action.ANPR_ONAY, resource_type="anpr_event",
            resource_id=kayit.id, meta={"onay": False},
        )
        await db.flush()
        return AnprEventOut.model_validate(kayit)

    if govde.plaka:
        norm = anpr_core.norm_plaka_yumusak(govde.plaka)
        if norm is None:
            raise APIError(422, "validation_error", "anpr_plaka_bicimi")
        kayit.plaka = norm

    esik, otomatik_cikis = await _tenant_ayarlari(db)
    acik = await _acik_gecis(db, kayit.plaka)
    # Insan onayladi: GUVEN ESIGI ARTIK UYGULANMAZ (esik zaten insani cagirmak
    # icindi). Karar yalniz yon/acik-gecis kurallariyla verilir.
    olay = anpr_core.AnprOlay(
        kaynak=kayit.kaynak,
        kaynak_olay_id=kayit.kaynak_olay_id,
        plaka=kayit.plaka,
        plaka_ham=kayit.plaka_ham,
        zaman=kayit.zaman,
        kamera=kayit.kamera,
        yon=kayit.yon,
        guven=None,
        foto_key=kayit.foto_key,
    )
    karar = anpr_core.karar_ver(
        olay,
        acik_gecis_var=acik is not None,
        esik=esik,
        otomatik_cikis=otomatik_cikis,
    )
    kayit.durum = karar.durum
    kayit.durum_nedeni = karar.neden

    if karar.eylem == anpr_core.EYLEM_GIRIS_AC:
        gecis = VehiclePass(
            tenant_id=kayit.tenant_id,
            plaka=kayit.plaka,
            giris_zamani=kayit.zaman,
            ziyaretci_mi=False,
            kaydeden_user_id=None,
            kaynak="anpr",
        )
        db.add(gecis)
        await db.flush()
        kayit.vehicle_pass_id = gecis.id
    elif karar.eylem == anpr_core.EYLEM_CIKIS_KAPAT and acik is not None:
        acik.cikis_zamani = kayit.zaman
        kayit.vehicle_pass_id = acik.id

    await audit_user(
        db, user, Action.ANPR_ONAY, resource_type="anpr_event",
        resource_id=kayit.id, meta={"onay": True, "eylem": karar.eylem},
    )
    await db.flush()
    return AnprEventOut.model_validate(kayit)


# --------------------------------------------------------------------------- #
# Anahtar yonetimi (admin)
# --------------------------------------------------------------------------- #
@router.get("/keys", response_model=list[AnprApiKeyOut])
async def anahtar_listesi(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_ANAHTAR_YONETICI),
) -> list[AnprApiKeyOut]:
    """Anahtarlar — `anahtar` alani DONMEZ (yalniz `kimlik` yarisi gorunur)."""
    satirlar = (
        await db.execute(
            select(AnprApiKey).order_by(AnprApiKey.created_at.desc())
        )
    ).scalars().all()
    return [AnprApiKeyOut.model_validate(s) for s in satirlar]


@router.post("/keys", response_model=AnprApiKeyCreated, status_code=201)
async def anahtar_uret(
    govde: AnprApiKeyCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ANAHTAR_YONETICI),
) -> AnprApiKeyCreated:
    """Yeni anahtar uret. Deger YALNIZ BURADA, BIR KEZ doner.

    Sunucuda `sir`in sha256'si saklanir; anahtarin kendisi hicbir yerde
    tutulmaz. Kaybedilirse yenisi uretilir — bu, sizan bir yedekten anahtarin
    geri uretilememesi icin bilincli bir bedeldir.
    """
    kimlik = secrets.token_hex(8)
    sir = secrets.token_urlsafe(32)
    kayit = AnprApiKey(
        tenant_id=user.tenant_id,
        ad=govde.ad,
        kimlik=kimlik,
        sir_hash=_sir_hash(sir),
    )
    db.add(kayit)
    await db.flush()
    await audit_user(
        db, user, Action.ANPR_KEY_CREATE, resource_type="anpr_api_key",
        resource_id=kayit.id, meta={"ad": govde.ad},
    )
    return AnprApiKeyCreated(
        id=kayit.id, ad=kayit.ad, kimlik=kayit.kimlik, aktif=kayit.aktif,
        son_kullanim=kayit.son_kullanim, created_at=kayit.created_at,
        anahtar=f"{kimlik}.{sir}",
    )


@router.delete("/keys/{key_id}", status_code=204)
async def anahtar_sil(
    key_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ANAHTAR_YONETICI),
) -> Response:
    """Anahtari PASIFLESTIR (satir silinmez — kim ne zaman kullandi izi kalir)."""
    kayit = (
        await db.execute(select(AnprApiKey).where(AnprApiKey.id == key_id))
    ).scalar_one_or_none()
    if kayit is None:
        raise APIError(404, "not_found", "kayit_bulunamadi")
    kayit.aktif = False
    await audit_user(
        db, user, Action.ANPR_KEY_REVOKE, resource_type="anpr_api_key",
        resource_id=kayit.id,
    )
    await db.flush()
    return Response(status_code=204)
