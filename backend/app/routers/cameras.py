"""Kamera yonetimi — admin/yonetici CRUD + ROL BAZLI gorunurluk.

Akis (urun sahibi sabit):
  1. Yonetim kamera ekler: ad + opsiyonel konum + yayin URL'i + tur
     (hls|mp4|rtsp) + aktif + `sakin_gorebilir`.
  2. `sakin_gorebilir` TEK anahtardir: sakin/tesis gorevlisi YALNIZ
     `aktif=true AND sakin_gorebilir=true` kameralari gorur. Varsayilan
     KAPALI — kamera mahremiyet tasir (KVKK), gorunurluk acik karardir.
  3. Suzgec SUNUCUDA uygulanir: istemci "hangi kamerayi gorebilirim"
     hesabini yapmaz ve gizli kamera yaniti HIC terk etmez.

RBAC (auth.md §4): YAZMA admin+yonetici (duyuru/kamera deseni — panel ve
mobil yonetici ayni yetkiyi tasir). OKUMA:
  * admin + yonetici + security -> TUM kameralar (pasifler dahil; operasyon)
  * resident + tesis_gorevlisi   -> yalniz aktif + sakin_gorebilir

Not (onceki davranistan sapma): resident/tesis_gorevlisi eskiden /cameras'a
403 aliyordu. Artik 200 alir ama YALNIZ yonetimin acik ettigi kameralari
gorur — varsayilan `sakin_gorebilir=false` oldugu icin mevcut kayitlarin
gorunurlugu DEGISMEZ (kapali kalir).

Yayin turu: hls/mp4 istemcide oynar; rtsp SAKLANIR ama istemci natively
oynatamaz -> yanit `oynatilabilir=false` isaretler (ileride medya gecidi).
URL semasi tur ile tutarli olmali (hls/mp4 -> http(s), rtsp -> rtsp://).
Backend yayini HIC cekmez (istemci oynatir) => SSRF yuzeyi yok.
"""
from __future__ import annotations

import asyncio
import base64
import logging
import re
import uuid

import httpx
import redis.asyncio as aioredis
from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404, translate_integrity
from ..config import settings
from ..deps import get_redis, get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Camera
from ..schemas import (
    KameraTestIstek,
    KameraTestSonuc,
    CameraCreate,
    CameraListResponse,
    CameraOut,
    CameraUpdate,
    URL_UST_SINIR,
    UrlCokUzun,
    UrlTurUyusmazligi,
    dogrula_restream,
    dogrula_snapshot,
    dogrula_url_tur,
    oynatilabilir_mi,
)

router = APIRouter(prefix="/cameras", tags=["cameras"])

_READER = require_role(
    "admin", "yonetici", "security", "tesis_gorevlisi", "resident",
    # (P35) Kamera izleme guvenlik hizmetinin CEKIRDEGIDIR; amiri disarida
    # birakmak, guvenligi yurutene isini yapamayacagi bir sistem vermekti.
    "guvenlik_amiri",
)
_WRITER = require_role("admin", "yonetici")

# Tum kameralari (pasif/gizli dahil) goren roller — operasyon + yonetim.
_TAM_GORUS: frozenset[str] = frozenset(
    {"admin", "yonetici", "security", "guvenlik_amiri"}
)


def _out(obj: Camera, rol: str | None = None) -> CameraOut:
    out = CameraOut.model_validate(obj)
    # (P190 §6) YONETILEN CANLI YOL: RTSP kamera, MediaMTX yapilandirildiysa
    # backend vekili uzerinden izlenebilir (kimlik-kapili; RTSP adresi
    # istemciye gitmez). `oynatilabilir` buna gore genisler.
    if obj.tur == "rtsp" and settings.mediamtx_url:
        out.canli_yol = f"/cameras/{obj.id}/canli/index.m3u8"
    out.oynatilabilir = (
        oynatilabilir_mi(obj.tur, obj.restream_url) or out.canli_yol is not None
    )
    # (P190 §6) KIMLIK BILGISI SIZINTISI: RTSP `stream_url` kullanici adi/
    # parola tasiyabilir ve istemci onu ZATEN oynatamaz. Yonetim disi rollere
    # (izleyiciler) MASKELENIR; yonetici/admin duzenleme formu icin gorur.
    if obj.tur == "rtsp" and rol not in ("admin", "yonetici"):
        out.stream_url = "rtsp://***"
    return out


def _url_tur_dogrula(stream_url: str, tur: str) -> None:
    """Sema/tur tutarliligi — ValueError'i 422 API hatasina cevirir."""
    try:
        dogrula_url_tur(stream_url, tur)
    except UrlCokUzun as exc:
        raise _cok_uzun(exc) from exc
    except UrlTurUyusmazligi as exc:
        raise APIError(
            422,
            "invalid_stream_url",
            "kamera_url_semasi",
            tur=exc.tur,
            semalar=" / ".join(exc.semalar),
        ) from exc


def _cok_uzun(exc: UrlCokUzun) -> APIError:
    """Uzunluk asimi -> katalog metniyle 422 (P25).

    Pydantic'in `max_length`i yerine burada olculur: onun uretecegi 422 ham
    Ingilizce bir cumle olurdu ve kullanici NE KADAR uzun oldugunu gormezdi.
    """
    return APIError(
        422, "invalid_stream_url", "kamera_url_cok_uzun",
        uzunluk=exc.uzunluk, sinir=URL_UST_SINIR,
    )


def _restream_dogrula(restream_url: str | None) -> None:
    """Restream YALNIZ http(s) — katalog metniyle 422.

    Sema katmani da dogrular (pydantic), ama oradaki hata GENERIK bir 422
    verir; kullaniciya gosterilecek cumle burada, istegin dilinde uretilir
    (`stream_url` ile ayni desen).
    """
    try:
        dogrula_restream(restream_url)
    except UrlCokUzun as exc:
        raise _cok_uzun(exc) from exc
    except UrlTurUyusmazligi as exc:
        raise APIError(
            422, "invalid_stream_url", "kamera_restream_semasi",
            tur=exc.tur, semalar=" / ".join(exc.semalar),
        ) from exc


def _snapshot_dogrula(snapshot_url: str | None) -> None:
    """Anlik kare adresi YALNIZ http(s) — katalog metniyle 422 (0031/P121).

    `_restream_dogrula` ile ayni desen. Ayri bir mesaj anahtari var cunku
    kullanici ayri bir ALANI doldurmustur; "restream adresi" diye uyarmak
    onu yanlis alana bakmaya gonderirdi.
    """
    try:
        dogrula_snapshot(snapshot_url)
    except UrlCokUzun as exc:
        raise _cok_uzun(exc) from exc
    except UrlTurUyusmazligi as exc:
        raise APIError(
            422, "invalid_stream_url", "kamera_snapshot_semasi",
            tur=exc.tur, semalar=" / ".join(exc.semalar),
        ) from exc


@router.get("", response_model=CameraListResponse)
async def list_cameras(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    aktif: bool | None = Query(
        None,
        description=(
            "Yonetim/operasyon suzgeci. Sakin ve tesis gorevlisi icin YOK "
            "SAYILIR: o roller her durumda yalniz aktif+gorunur kameralari alir."
        ),
    ),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> CameraListResponse:
    stmt = select(Camera)
    sayim = select(func.count()).select_from(Camera)

    if user.role not in _TAM_GORUS:
        # KVKK kapisi: sakin/tesis gorevlisi icin suzgec ZORUNLU ve
        # istemciden gelen `aktif` parametresi bunu genisletemez.
        kosul = (Camera.aktif.is_(True)) & (Camera.sakin_gorebilir.is_(True))
        stmt = stmt.where(kosul)
        sayim = sayim.where(kosul)
    elif aktif is not None:
        stmt = stmt.where(Camera.aktif.is_(aktif))
        sayim = sayim.where(Camera.aktif.is_(aktif))

    total = (await db.execute(sayim)).scalar_one()
    rows = (
        await db.execute(stmt.order_by(Camera.ad, Camera.id).limit(limit).offset(offset))
    ).scalars().all()
    return CameraListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_out(r, user.role) for r in rows],
    )


@router.post("", response_model=CameraOut, status_code=201)
async def create_camera(
    body: CameraCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> CameraOut:
    # URL kurallari TEK YERDE, burada (P25): semadaki bir `model_validator`
    # pydantic'in ham Ingilizce `validation_error`ini uretirdi.
    _url_tur_dogrula(body.stream_url, body.tur)
    _restream_dogrula(body.restream_url)
    _snapshot_dogrula(body.snapshot_url)
    obj = Camera(tenant_id=user.tenant_id, **body.model_dump())
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await audit_user(db, user, Action.CAMERA_CREATE, resource_type="camera",
                     resource_id=obj.id,
                     meta={"ad": obj.ad, "tur": obj.tur,
                           "sakin_gorebilir": obj.sakin_gorebilir})
    await db.refresh(obj)
    return _out(obj, user.role)


@router.patch("/{camera_id}", response_model=CameraOut)
async def update_camera(
    camera_id: uuid.UUID,
    body: CameraUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> CameraOut:
    obj = await get_or_404(db, Camera, camera_id)
    alanlar = body.model_dump(exclude_unset=True)
    # URL/tur tutarliligi MEVCUT kayitla birlestirilerek dogrulanir: yalniz
    # `tur` degistirilse bile eski URL'in semasi yeni ture uymak zorundadir.
    _url_tur_dogrula(
        alanlar.get("stream_url", obj.stream_url),
        alanlar.get("tur", obj.tur),
    )
    if "restream_url" in alanlar:
        _restream_dogrula(alanlar["restream_url"])
    if "snapshot_url" in alanlar:
        _snapshot_dogrula(alanlar["snapshot_url"])
    for key, value in alanlar.items():
        setattr(obj, key, value)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await audit_user(db, user, Action.CAMERA_UPDATE, resource_type="camera",
                     resource_id=obj.id, meta={"alanlar": sorted(alanlar)})
    await db.refresh(obj)
    return _out(obj, user.role)


@router.delete("/{camera_id}", status_code=204)
async def delete_camera(
    camera_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> Response:
    obj = await get_or_404(db, Camera, camera_id)
    await db.delete(obj)
    await db.flush()
    await audit_user(db, user, Action.CAMERA_DELETE, resource_type="camera",
                     resource_id=camera_id)
    return Response(status_code=204)


# =========================================================================== #
# (P190 §6) RTSP GORUNTULEME — SUNUCU TARAFI KARE + CANLI (HLS) VEKILI
#
# ESKI KARAR ("backend yayini HIC cekmez => SSRF yok") BILINCLI DEGISTI:
# RTSP tarayicida/moblide DOGRUDAN oynatilamaz ve kameralarin cogu RTSP.
# Kimlik bilgileri `stream_url` icinde olabilir — istemciye SIZDIRILMAZ:
# baglantiyi SUNUCU kurar, istemci yalniz bizim kimlik-kapili ucumuzu gorur.
#
# SSRF SINIRI: sunucu YALNIZ `rtsp://` kaynaklara baglanir (tur=rtsp yazim
# aninda dogrulaniyor; asagida ikinci kontrol). http(s) kaynaklar icin
# sunucu-tarafi cekim YOK — onlar zaten istemcide oynar.
#
#   * KARE  (`GET /cameras/{id}/kare`): ffmpeg tek kare (JPEG). Izgara karolari
#     icin. Redis'te 10 sn onbellek (cok izleyici tek cekim), basarisiz deneme
#     5 sn negatif-onbellek (olu kameraya cekic yok), surec basina en cok
#     3 es-zamanli ffmpeg (semafor).
#   * CANLI (`GET /cameras/{id}/canli/{dosya}`): MediaMTX gecidine HLS vekili.
#     Gecit `sourceOnDemand` ile YALNIZ izleyici varken RTSP ceker; okuyucu
#     kalmayinca kaynak KAPANIR. Ayni anda en cok `kamera_canli_sinir` kamera
#     donusturulur (Redis sayaci, 429). MediaMTX yapilandirilmamissa canli
#     kapali kalir (kare calismaya devam eder).
# =========================================================================== #

logger = logging.getLogger(__name__)

# --------------------------------------------------------------------------- #
# (P191 §3) HATA TESHISI — "Yayın açılamadı" TEK BASINA ISE YARAMAZ.
#
# OLCULEN KUSUR: panelde her arizanin karsiligi ayni cumleydi ("Yayın
# açılamadı. Adresi ve ağ erişimini kontrol edin") ve izgarada "Görüntü yok".
# Yoneticinin elinde EYLEM yoktu: adres mi yanlis, parola mi, kamera mi
# kapali, sunucudaki ffmpeg mi eksik — hepsi ayni gorunuyordu.
#
# ffmpeg'in stderr'i bunlarin hepsini SOYLUYOR; tek yapmamiz gereken onu
# yutmayi birakmak (`stderr=DEVNULL` idi) ve sinifa cevirmek. Ham cikti
# ISTEMCIYE VERILMEZ: icinde `stream_url` (yani kamera parolasi) gecebilir.
# Istemci bir HATA KIMLIGI alir, operator loglarda ayrintiyi gorur.
# --------------------------------------------------------------------------- #
#: (desen, hata kimligi) — SIRA ONEMLI: ilk eslesen kazanir, ozelden genele.
_FFMPEG_TESHIS: tuple[tuple[str, str], ...] = (
    ("401 unauthorized", "kamera_kimlik_hatali"),
    ("authentication", "kamera_kimlik_hatali"),
    ("unauthorized", "kamera_kimlik_hatali"),
    ("404 not found", "kamera_yol_bulunamadi"),
    ("stream not found", "kamera_yol_bulunamadi"),
    ("connection refused", "kamera_ulasilamiyor"),
    ("no route to host", "kamera_ulasilamiyor"),
    ("network is unreachable", "kamera_ulasilamiyor"),
    ("name or service not known", "kamera_adres_cozulemedi"),
    ("failed to resolve", "kamera_adres_cozulemedi"),
    ("connection timed out", "kamera_zaman_asimi"),
    ("timed out", "kamera_zaman_asimi"),
    ("invalid data found", "kamera_yayin_okunamadi"),
    ("immediate exit requested", "kamera_zaman_asimi"),
)


def _ffmpeg_teshis(stderr: bytes | None, zaman_asimi: bool) -> str:
    """ffmpeg ciktisindan HATA KIMLIGI. Bilinmeyen cikti -> genel kimlik."""
    if zaman_asimi:
        return "kamera_zaman_asimi"
    metin = (stderr or b"").decode("utf-8", "replace").lower()
    for desen, kimlik in _FFMPEG_TESHIS:
        if desen in metin:
            return kimlik
    return "kamera_baglanti_yok"


def _kare_hatasi(kimlik: str) -> APIError:
    """Teshis kimligini HTTP hatasina cevirir.

    Kimlik/yapilandirma hatalari 502 DEGIL: 502 "karsi taraf bozuk" der ve
    yoneticiyi ag aramaya gonderir; oysa parola yanlissa duzeltilecek yer
    KAYITTIR, sunucudaki ffmpeg eksikse duzeltilecek yer DAGITIMDIR.
    """
    if kimlik == "kamera_kimlik_hatali":
        return APIError(502, "bad_gateway", kimlik)
    if kimlik == "kamera_ffmpeg_yok":
        return APIError(503, "service_unavailable", kimlik)
    return APIError(502, "bad_gateway", kimlik)


_KARE_SEMAFOR = asyncio.Semaphore(3)
_KARE_TTL_SN = 10
_KARE_NEG_TTL_SN = 5
_KARE_ZAMAN_ASIMI_SN = 8
_KARE_YOK = "YOK"

_CANLI_TTL_SN = 30  # aktif-izleyici kaydinin omru (playlist istegiyle tazelenir)


async def _gorunur_kamera(
    db: AsyncSession, user: AppUser, camera_id: uuid.UUID
) -> Camera:
    """Kamerayi ROL GORUNURLUGUYLE getirir — liste ile AYNI kural: sakin/
    tesis gorevlisi yalniz aktif+sakin_gorebilir kamerayi gorur (aksi 404;
    varligi da sizdirilmaz)."""
    obj = await get_or_404(db, Camera, camera_id)
    if user.role not in _TAM_GORUS and not (obj.aktif and obj.sakin_gorebilir):
        raise APIError(404, "not_found", "kayit_bulunamadi")
    return obj


def _rtsp_dogrula(obj: Camera) -> None:
    """Sunucu-tarafi cekim YALNIZ rtsp:// — SSRF siniri (yukaridaki blok)."""
    if obj.tur != "rtsp" or not obj.stream_url.lower().startswith("rtsp"):
        raise APIError(422, "validation_error", "kamera_kare_yalniz_rtsp")


# --------------------------------------------------------------------------- #
# (P191 §3) BAGLANTI TESTI — kaydetmeden once dene.
#
# YOL SIRASI ONEMLI: `/test-baglanti` `/{camera_id}`den ONCE tanimlanir,
# yoksa FastAPI onu bir kamera kimligi sanip 422 verirdi.
#
# SSRF: yalniz `rtsp://` (kayit yolundaki kuralin AYNISI) ve YALNIZ yonetim
# rolleri. Hiz siniri var: aksi halde uc, ic agi taramak icin kullanilabilecek
# bir arac olurdu.
# --------------------------------------------------------------------------- #
_TEST_SINIR = 20  # tesis basina / dakika


@router.post("/test-baglanti", response_model=KameraTestSonuc)
async def kamera_test(
    body: KameraTestIstek,
    user: AppUser = Depends(_WRITER),
    redis: aioredis.Redis = Depends(get_redis),
) -> KameraTestSonuc:
    """Verilen RTSP adresinden tek kare cekmeyi dener; KAYIT YAPMAZ.

    Basarisizlikta hata TANILIDIR (`kamera_kimlik_hatali`,
    `kamera_ulasilamiyor`, `kamera_yol_bulunamadi`, ...) — yonetici ne
    duzeltecegini bilir.
    """
    _url_tur_dogrula(body.stream_url, body.tur)
    if body.tur != "rtsp" or not body.stream_url.lower().startswith("rtsp"):
        raise APIError(422, "validation_error", "kamera_kare_yalniz_rtsp")

    anahtar = f"kamera:test:{user.tenant_id}"
    sayi = await redis.incr(anahtar)
    if sayi == 1:
        await redis.expire(anahtar, 60)
    if sayi > _TEST_SINIR:
        raise APIError(429, "rate_limited", "kamera_test_sinir")

    async with _KARE_SEMAFOR:
        veri, kimlik = await _kare_cek(body.stream_url)
    if not veri:
        raise _kare_hatasi(kimlik or "kamera_baglanti_yok")
    return KameraTestSonuc(basarili=True, kare_bayt=len(veri))


@router.get("/{camera_id}/kare")
async def kamera_kare(
    camera_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
    redis: aioredis.Redis = Depends(get_redis),
) -> Response:
    """(P190 §6) RTSP kameradan TEK KARE (JPEG) — izgara karosu icin.

    Kimlik bilgisi iceren `stream_url` istemciye HIC gitmez; ffmpeg'i sunucu
    calistirir. Basarisizlik "bos kutu" DEGIL acik hatadir: 502
    `kamera_baglanti_yok` — istemci karoda "baglanti yok" cizer.
    """
    obj = await _gorunur_kamera(db, user, camera_id)
    _rtsp_dogrula(obj)

    anahtar = f"kamera:kare:{obj.id}"
    onbellek = await redis.get(anahtar)
    if onbellek and onbellek.startswith(_KARE_YOK):
        # (P191 §3) NEGATIF ONBELLEK TESHISI TASIR: `YOK:<kimlik>`. Eskiden
        # yalniz "YOK" yaziliyordu ve 5 saniyelik pencere icindeki her istek
        # sebebini KAYBEDIYORDU — kullanici "parola yanlis" yerine yine genel
        # hatayi goruyordu.
        raise _kare_hatasi(onbellek.partition(":")[2] or "kamera_baglanti_yok")
    if onbellek:
        return Response(
            base64.b64decode(onbellek),
            media_type="image/jpeg",
            headers={"Cache-Control": "private, max-age=5"},
        )

    async with _KARE_SEMAFOR:
        # Semafor beklerken baska istek doldurmus olabilir — yeniden bak.
        onbellek = await redis.get(anahtar)
        if onbellek and onbellek.startswith(_KARE_YOK):
            raise _kare_hatasi(onbellek.partition(":")[2] or "kamera_baglanti_yok")
        if onbellek:
            return Response(
                base64.b64decode(onbellek),
                media_type="image/jpeg",
                headers={"Cache-Control": "private, max-age=5"},
            )
        veri, kimlik = await _kare_cek(obj.stream_url)

    if not veri:
        # Olu/ulasilamayan kamera: kisa negatif-onbellek (cekic yok) + panel
        # icin ACIK durum. Sessiz bos kutu YOK (P190 §6 sart) ve artik
        # SEBEBI de tasiyor (P191 §3).
        await redis.set(anahtar, f"{_KARE_YOK}:{kimlik}", ex=_KARE_NEG_TTL_SN)
        raise _kare_hatasi(kimlik or "kamera_baglanti_yok")

    await redis.set(anahtar, base64.b64encode(veri).decode(), ex=_KARE_TTL_SN)
    return Response(
        veri, media_type="image/jpeg",
        headers={"Cache-Control": "private, max-age=5"},
    )


async def _kare_cek(stream_url: str) -> tuple[bytes, str]:
    """RTSP'den tek kare + TESHIS KIMLIGI. Basarida `(veri, "")`.

    `stderr` ARTIK YUTULMUYOR (`DEVNULL` idi): arizanin adini yalnizca o
    soyluyor. Ham cikti loglara gider, istemciye GITMEZ — icinde
    `stream_url` (yani kamera parolasi) gecebilir.
    """
    try:
        proc = await asyncio.create_subprocess_exec(
            "ffmpeg", "-nostdin", "-loglevel", "error",
            "-rtsp_transport", "tcp",
            "-i", stream_url,
            "-frames:v", "1", "-q:v", "5", "-f", "image2", "pipe:1",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
    except FileNotFoundError:
        # ffmpeg imajda yok — DAGITIM kusuru; operatore acik log + AYRI kimlik.
        # Eskiden bu da "kameraya baglanilamadi" diyordu ve yonetici olmayan
        # bir ag sorununu arardi.
        logger.error(
            "[kamera] ffmpeg BULUNAMADI — api imajinda ffmpeg yok. "
            "Dagitim: infra/RUNBOOK-PROD.md kamera bolumu."
        )
        return b"", "kamera_ffmpeg_yok"
    zaman_asimi = False
    try:
        veri, hata = await asyncio.wait_for(
            proc.communicate(), timeout=_KARE_ZAMAN_ASIMI_SN
        )
    except (TimeoutError, asyncio.TimeoutError):
        proc.kill()
        await proc.wait()
        veri, hata, zaman_asimi = b"", b"", True
    if veri:
        return veri, ""
    kimlik = _ffmpeg_teshis(hata, zaman_asimi)
    # HAM CIKTI YALNIZ LOGDA (ve kirpilmis): teshisin ayrintisi operatorun,
    # kimlik bilgisi kimsenin isi degil.
    logger.warning(
        "[kamera] kare alinamadi: teshis=%s ffmpeg=%r",
        kimlik,
        (hata or b"").decode("utf-8", "replace")[:300],
    )
    return b"", kimlik


def api_adresi() -> str:
    """MediaMTX API adresi — LOG icin. Sir icermez (ic ag adresi)."""
    return settings.mediamtx_api_url or "(tanimsiz)"


async def _canli_yolu_kaydet(obj: Camera) -> None:
    """MediaMTX'e `cam<id>` yolunu (idempotent) kaydeder.

    `sourceOnDemand=true`: gecit RTSP'yi YALNIZ okuyucu varken ceker ve
    okuyucu kalmayinca kapatir — kimse izlemezken kamera baglantisi ACIK
    TUTULMAZ (kaynak karari, §6). Yol zaten varsa MediaMTX hata doner ve
    bu BASARI sayilir.
    """
    api = settings.mediamtx_api_url.rstrip("/")
    async with httpx.AsyncClient(timeout=5) as istemci:
        yanit = await istemci.post(
            f"{api}/v3/config/paths/add/cam{obj.id.hex}",
            json={"source": obj.stream_url, "sourceOnDemand": True},
        )
        # 200 = eklendi; MediaMTX var olan yol icin 4xx doner — idempotent
        # kabul: kaynak URL degistiyse guncelle (patch) dene.
        if yanit.status_code >= 400:
            await istemci.patch(
                f"{api}/v3/config/paths/patch/cam{obj.id.hex}",
                json={"source": obj.stream_url, "sourceOnDemand": True},
            )


#: (P190 §6 guvenlik) HLS dosya adi TEK bilesendir: harf/rakam/._- + uzanti.
#: `:path` KULLANILMAZ (egik cizgiyi router reddeder) ve desen ".." gibi
#: gezinti parcalarini da eler — `dosya` dogrudan gecit URL'ine eklendigi
#: icin serbest birakmak, izleyicinin BASKA kameranin (cam<id> yolunun)
#: yayinini cekmesine izin verirdi (IDOR/path traversal).
_CANLI_DOSYA = re.compile(r"^[A-Za-z0-9._-]+\.(m3u8|ts|mp4)$")


@router.get("/{camera_id}/canli/{dosya}")
async def kamera_canli(
    camera_id: uuid.UUID,
    dosya: str,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
    redis: aioredis.Redis = Depends(get_redis),
) -> Response:
    """(P190 §6) CANLI izleme — MediaMTX HLS vekili (playlist + segmentler).

    Istemci hicbir zaman MediaMTX'i ya da RTSP adresini gormez; bu uc rol
    gorunurlugunu uygular ve gecide vekillik eder. Es-zamanlilik SINIRLI:
    ayni anda en cok `kamera_canli_sinir` FARKLI kamera donusturulur
    (asimda 429 `kamera_canli_sinir` — kullanici acik mesaj gorur).
    """
    if not settings.mediamtx_url:
        raise APIError(503, "service_unavailable", "kamera_canli_kapali")
    obj = await _gorunur_kamera(db, user, camera_id)
    _rtsp_dogrula(obj)

    # Yol dogrulama: TEK bilesenli HLS dosyasi (playlist/segment). Egik cizgi,
    # ters egik cizgi ve ".." REDDEDILIR — `dosya` gecit URL'ine dogrudan
    # eklendigi icin gezinti, baska kameranin yolunu cekmek olurdu.
    if (
        "/" in dosya
        or "\\" in dosya
        or ".." in dosya
        or not _CANLI_DOSYA.match(dosya)
    ):
        raise APIError(404, "not_found", "kayit_bulunamadi")

    # Es-zamanlilik: aktif kume Redis'te; playlist istekleri kaydi tazeler.
    if dosya.endswith(".m3u8"):
        aktifler = await redis.keys("kamera:canli:*")
        benim = f"kamera:canli:{obj.id}"
        if benim not in aktifler and len(aktifler) >= settings.kamera_canli_sinir:
            raise APIError(429, "rate_limited", "kamera_canli_sinir")
        await redis.set(benim, "1", ex=_CANLI_TTL_SN)
        try:
            await _canli_yolu_kaydet(obj)
        except httpx.HTTPError:
            # (P191 §3) GECIT ULASILAMIYOR — kamera degil MEDIAMTX sorunu.
            # Ikisini ayni mesajla anlatmak, yoneticiyi kamerayi kontrol
            # etmeye gonderiyordu; oysa duzeltilecek yer SUNUCUDUR.
            logger.error("[kamera] MediaMTX API'sine ulasilamadi (%s)", api_adresi())
            raise APIError(502, "bad_gateway", "kamera_gecit_yok")

    hedef = f"{settings.mediamtx_url.rstrip('/')}/cam{obj.id.hex}/{dosya}"
    try:
        async with httpx.AsyncClient(timeout=15) as istemci:
            yanit = await istemci.get(hedef)
    except httpx.HTTPError:
        logger.error("[kamera] MediaMTX HLS gecidine ulasilamadi (%s)", api_adresi())
        raise APIError(502, "bad_gateway", "kamera_gecit_yok")
    if yanit.status_code >= 400:
        # Gecit AYAKTA ama yayin yok: kaynak RTSP'ye baglanamamis demektir.
        # 404 bu durumda "yol henuz hazir degil" anlamina da gelir; ikisini
        # ayirmak icin ilk deneme icin KARE cekimi bir teshis verir — panel
        # zaten karo cekimini de yapiyor ve oradaki kimlik gosterilir.
        logger.warning(
            "[kamera] gecit %s icin %s dondu", obj.id, yanit.status_code
        )
        raise APIError(502, "bad_gateway", "kamera_yayin_hazir_degil")
    icerik_turu = yanit.headers.get(
        "content-type",
        "application/vnd.apple.mpegurl" if dosya.endswith(".m3u8") else "video/mp2t",
    )
    return Response(
        yanit.content, media_type=icerik_turu,
        headers={"Cache-Control": "no-store"},
    )
