"""POST /scans — tur kaniti alimi (idempotent) + NTAG424 SDM dogrulamasi.

RBAC (auth.md §4): admin/security/tesis_gorevlisi gonderebilir; resident -> 403.
tenant + guard_id token'dan turetilir (istekten ALINMAZ).

Idempotency (offline outbox cift gonderimi):
  * Idempotency-Key header ZORUNLU; yoksa 400.
  * SIRA (SDM nedeniyle kritik): ONCE idempotency_key SELECT — kayit varsa govde
    karsilastir (200/409) ve SDM dogrulamasi ATLANIR (sayac zaten ilerledigi icin
    tekrar dogrulama yanlis replay uretirdi). Yoksa dogrula + insert; SAVEPOINT'li
    insert es zamanli yaris icin yine durur (unique ihlalinde idempotent yol).

SDM/SUN (imza_dogrulandi): deger YALNIZ SUNUCUDA belirlenir (nfc_sdm.verify_sdm)
— govdedeki imza_dogrulandi DEPRECATED ve YOK SAYILIR. Karar tablosu README /
openapi'de. Replay korumasi: yarissiz sayac guncellemesi
(UPDATE ... WHERE sdm_son_sayac < :ctr; 0 satir -> replay) scan insert ile AYNI
transaction'da — 422'de kayit da geri alinir.

Pencere durum gecisi BURADA YAPILMAZ — bu scheduler'in detect task'inin isidir
(tek sorumluluk). Burada yalnizca scan dogru kaydedilir; patrol_window_id verildiyse
dogrulanir, verilmediyse scheduler zaman-tabanli eslestirir (bkz. README scheduler).
"""
from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Header
from fastapi.responses import JSONResponse
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import settings
from ..crud_helpers import norm_nfc, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Checkpoint, PatrolWindow, ScanEvent
from ..nfc_sdm import decrypt_key, verify_sdm
from ..schemas import ScanCreate, ScanEventOut

router = APIRouter(prefix="/scans", tags=["scans"])

_SCANNER = require_role("admin", "security", "tesis_gorevlisi")


def _is_unique_violation(exc: IntegrityError) -> bool:
    orig = getattr(exc, "orig", None)
    code = getattr(orig, "sqlstate", None) or getattr(orig, "pgcode", None)
    return code == "23505"


def _coord_eq(a, b) -> bool:
    if a is None or b is None:
        return a is b
    return round(float(a), 6) == round(float(b), 6)


def _same_request(existing: ScanEvent, *, guard_id, checkpoint_id, patrol_window_id,
                  nfc_tag_uid, okutma_zamani, gps_lat, gps_lng, foto_url) -> bool:
    """Idempotent tekrar mi (ayni govde) yoksa cakisma mi (farkli govde)?

    imza_dogrulandi KARSILASTIRILMAZ: artik sunucu-turetilmis deger (govde girdisi
    yok sayilir). sdm_picc_data/sdm_cmac da karsilastirilamaz — scan_event'te
    persist edilmiyorlar (onayli tablo degisikligi yalniz checkpoint'te); tekrar
    yolunda SDM dogrulamasi zaten atlanir, kalan tum persist alanlar karsilastirilir.
    """
    return (
        existing.guard_id == guard_id
        and existing.checkpoint_id == checkpoint_id
        and existing.patrol_window_id == patrol_window_id
        and existing.nfc_tag_uid == nfc_tag_uid
        and existing.okutma_zamani == okutma_zamani
        and _coord_eq(existing.gps_lat, gps_lat)
        and _coord_eq(existing.gps_lng, gps_lng)
        and existing.foto_url == foto_url
    )


async def _verify_sdm_or_422(
    db: AsyncSession, checkpoint: Checkpoint, body: ScanCreate
) -> tuple[bool, int | None]:
    """Karar tablosu (tasarim §4) -> (imza_dogrulandi, kabul edilen sayac | None).

    | anahtar | SDM alanlari        | sonuc                                  |
    |---------|---------------------|----------------------------------------|
    | yok     | yok/var             | false (gecis donemi)                   |
    | var     | yok                 | false (zorlama YOK)                    |
    | var     | gecersiz            | 422 invalid_signature (kayit yok)      |
    | var     | sayac ilerlememis   | 422 replay_detected  (kayit yok)       |
    | var     | gecerli             | true + sayac                           |
    """
    if checkpoint.sdm_key_sifreli is None:
        return False, None
    if body.sdm_picc_data is None and body.sdm_cmac is None:
        return False, None
    if body.sdm_picc_data is None or body.sdm_cmac is None:
        raise APIError(422, "invalid_signature", "sdm_picc_data ve sdm_cmac birlikte gonderilmeli.")
    try:
        key = decrypt_key(checkpoint.sdm_key_sifreli, settings.sdm_kek)
    except Exception:
        # KEK degismis/yanlis: anahtar cozulemiyor — istemci hatasi degil.
        raise APIError(500, "config_error", "SDM anahtari cozulemedi (SDM_KEK yapilandirmasini kontrol edin).")
    res = verify_sdm(key, checkpoint.nfc_tag_uid, body.sdm_picc_data, body.sdm_cmac, checkpoint.sdm_son_sayac)
    if res.neden == "replay":
        raise APIError(422, "replay_detected", "SDM okuma sayaci ilerlememis (tekrar oynatma).")
    if not res.ok:
        # cmac/uid/format ayrintisi sizdirilmaz (tasarim: hata yonetimi).
        raise APIError(422, "invalid_signature", "SDM imzasi dogrulanamadi.")
    return True, res.sayac


@router.post("")
async def create_scan(
    body: ScanCreate,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_SCANNER),
) -> JSONResponse:
    if not idempotency_key or not idempotency_key.strip():
        raise APIError(400, "bad_request", "Idempotency-Key header zorunlu.")

    # 1) nfc_tag_uid -> checkpoint (RLS ile tenant-scoped). Capraz-tenant/bilinmeyen -> 404.
    # Eslesme normalize (strip+upper) — task completion / asset ile ayni davranis (mobil §11 #3).
    checkpoint = (
        await db.execute(
            select(Checkpoint).where(
                func.upper(func.btrim(Checkpoint.nfc_tag_uid)) == norm_nfc(body.nfc_tag_uid)
            )
        )
    ).scalar_one_or_none()
    if checkpoint is None:
        raise APIError(404, "not_found", "nfc_tag_uid hicbir checkpoint ile eslesmedi.")
    if body.checkpoint_id is not None and body.checkpoint_id != checkpoint.id:
        raise APIError(422, "invalid_reference", "checkpoint_id nfc_tag_uid ile eslesmiyor.")

    # 2) patrol_window_id verildiyse dogrula (durum DEGISTIRILMEZ — scheduler isi).
    if body.patrol_window_id is not None:
        exists = (
            await db.execute(
                select(PatrolWindow.id).where(PatrolWindow.id == body.patrol_window_id)
            )
        ).scalar_one_or_none()
        if exists is None:
            raise APIError(422, "invalid_reference", "patrol_window_id bu tenant'ta bulunamadi.")

    okutma = body.okutma_zamani
    if okutma.tzinfo is None:  # zamanlar UTC (konvansiyon)
        okutma = okutma.replace(tzinfo=timezone.utc)

    def _idempotent_yanit(existing: ScanEvent) -> JSONResponse:
        if _same_request(
            existing,
            guard_id=user.id,
            checkpoint_id=checkpoint.id,
            patrol_window_id=body.patrol_window_id,
            nfc_tag_uid=body.nfc_tag_uid,
            okutma_zamani=okutma,
            gps_lat=body.gps_lat,
            gps_lng=body.gps_lng,
            foto_url=body.foto_url,
        ):
            return JSONResponse(
                status_code=200, content=ScanEventOut.model_validate(existing).model_dump(mode="json")
            )
        raise APIError(409, "conflict", "Ayni Idempotency-Key farkli govde ile gonderildi.")

    # 3) ONCE idempotent tekrar kontrolu (SDM'den once — kritik): sayac ilk
    # gonderimde ilerledigi icin tekrar dogrulama yanlis replay uretirdi.
    existing = (
        await db.execute(select(ScanEvent).where(ScanEvent.idempotency_key == idempotency_key))
    ).scalar_one_or_none()
    if existing is not None:
        return _idempotent_yanit(existing)

    # 4) SDM dogrulamasi (karar tablosu) — imza_dogrulandi YALNIZ buradan.
    imza_dogrulandi, sdm_sayac = await _verify_sdm_or_422(db, checkpoint, body)

    obj = ScanEvent(
        tenant_id=user.tenant_id,
        guard_id=user.id,
        checkpoint_id=checkpoint.id,
        patrol_window_id=body.patrol_window_id,
        nfc_tag_uid=body.nfc_tag_uid,
        okutma_zamani=okutma,
        gps_lat=body.gps_lat,
        gps_lng=body.gps_lng,
        foto_url=body.foto_url,
        imza_dogrulandi=imza_dogrulandi,
        idempotency_key=idempotency_key,
    )

    # 5) race-safe insert (SAVEPOINT). Unique ihlalinde idempotent yola gec.
    created = True
    try:
        async with db.begin_nested():
            db.add(obj)
            await db.flush()
    except IntegrityError as exc:
        if not _is_unique_violation(exc):
            raise translate_integrity(exc)
        created = False
        try:
            db.expunge(obj)
        except Exception:
            pass

    if created:
        # 6) yarissiz sayac guncellemesi — scan insert ile AYNI transaction.
        # Kosullu UPDATE kaybedilen yarisi yakalar; 422 tum transaction'i (insert
        # dahil) geri alir -> kayit olusmaz.
        if sdm_sayac is not None:
            upd = await db.execute(
                update(Checkpoint)
                .where(Checkpoint.id == checkpoint.id, Checkpoint.sdm_son_sayac < sdm_sayac)
                .values(sdm_son_sayac=sdm_sayac)
            )
            if upd.rowcount == 0:
                raise APIError(422, "replay_detected", "SDM okuma sayaci ilerlememis (tekrar oynatma).")
        await db.refresh(obj)
        return JSONResponse(
            status_code=201, content=ScanEventOut.model_validate(obj).model_dump(mode="json")
        )

    # es zamanli yaris: baska istek ayni key ile once insert etti
    existing = (
        await db.execute(select(ScanEvent).where(ScanEvent.idempotency_key == idempotency_key))
    ).scalar_one()
    return _idempotent_yanit(existing)
