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

from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, Header, Query
from fastapi.responses import JSONResponse
from sqlalchemy import func, select, text, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from ..config import settings
from ..crud_helpers import get_or_404, norm_nfc, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..uzak_okutma import uzak_okutma_alarmi
from ..models import AppUser, Checkpoint, PatrolWindow, ScanEvent, Tenant
from ..nfc_sdm import decrypt_key, verify_sdm
from ..schemas import (
    ScanCreate,
    ScanEventOut,
    ScanReportItem,
    ScanReportResponse,
    SimuleScanCreate,
)

router = APIRouter(prefix="/scans", tags=["scans"])

_SCANNER = require_role(
    "admin", "security", "tesis_gorevlisi", "guvenlik_amiri"
)
# Gun-gun tarama raporu (yonetici takibi) — okuma admin + yonetici.
# (P35) Amir de okur: kendi ekibinin turlerini denetleyen kisidir.
_REPORT_READER = require_role("admin", "yonetici", "guvenlik_amiri")


@router.get("", response_model=ScanReportResponse)
async def list_scans(
    tarih: date | None = Query(
        None, description="YYYY-MM-DD (tenant timezone); verilmezse bugun"
    ),
    konumsuz: bool = Query(
        False, description="(P34) yalniz konumu olmayan okutmalar"
    ),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_REPORT_READER),
) -> ScanReportResponse:
    """Gun-gun tarama raporu (yonetici takibi): secilen gunun (tenant tz) TUM
    taramalari — KIM (guard_ad), HANGI NOKTA (checkpoint_ad), NE ZAMAN
    (okutma_zamani). Okutma zamanina gore sirali. RBAC admin + yonetici."""
    tz_name = (
        await db.execute(select(Tenant.timezone))
    ).scalar_one_or_none() or "Europe/Istanbul"
    try:
        tz = ZoneInfo(tz_name)
    except Exception:
        tz = ZoneInfo("Europe/Istanbul")
    day = tarih or datetime.now(tz).date()
    start = datetime(day.year, day.month, day.day, tzinfo=tz)
    end = start + timedelta(days=1)

    guard = aliased(AppUser)
    kosullar = [ScanEvent.okutma_zamani >= start, ScanEvent.okutma_zamani < end]
    # (P34) Sayi SUZGECTEN BAGIMSIZ: `konumsuz=true` ile listeyi daraltan amir
    # "kac tanesi" sorusunu satirlari sayarak yanitlamak zorunda kalmasin.
    konumsuz_sayisi = (
        await db.execute(
            select(func.count())
            .select_from(ScanEvent)
            .where(*kosullar, ScanEvent.konum_durumu != "var")
        )
    ).scalar_one()
    if konumsuz:
        kosullar.append(ScanEvent.konum_durumu != "var")
    rows = (
        await db.execute(
            select(ScanEvent, Checkpoint.ad, guard.ad)
            .join(Checkpoint, Checkpoint.id == ScanEvent.checkpoint_id)
            .join(guard, guard.id == ScanEvent.guard_id)
            .where(*kosullar)
            .order_by(ScanEvent.okutma_zamani)
        )
    ).all()
    return ScanReportResponse(
        tarih=day,
        konumsuz_sayisi=konumsuz_sayisi,
        items=[
            ScanReportItem(
                id=s.id,
                checkpoint_id=s.checkpoint_id,
                checkpoint_ad=cad,
                guard_id=s.guard_id,
                guard_ad=gad,
                okutma_zamani=s.okutma_zamani,
                gps_lat=float(s.gps_lat) if s.gps_lat is not None else None,
                gps_lng=float(s.gps_lng) if s.gps_lng is not None else None,
                konum_durumu=s.konum_durumu,
                gps_dogruluk_m=(
                    float(s.gps_dogruluk_m) if s.gps_dogruluk_m is not None else None
                ),
                imza_dogrulandi=s.imza_dogrulandi,
            )
            for s, cad, gad in rows
        ],
    )


def _konum_durumu(body: ScanCreate) -> str:
    """(P34) Istemci soylemediyse SUNUCU TURETIR.

    Eski istemciler `konum_durumu` gondermez; koordinat varsa 'var',
    yoksa 'bilinmiyor'. Yoklugu 'izin_yok' saymak, OLMAYAN bir izin
    reddini raporlamak olurdu.
    """
    if body.konum_durumu is not None:
        return body.konum_durumu
    return "var" if (body.gps_lat is not None and body.gps_lng is not None) else "bilinmiyor"


#: (P34) Okutmanin dustugu AKTIF pencere — baslangic fotografi kapisi bunu
#: kullanir. `patrol_window_id` gonderilmemis olsa da bulunur: kapinin
#: istemcinin gonullu bir alan doldurmasina bagli olmasi, kapiyi alani
#: bos birakarak asmak demekti.
_PENCERE_BUL_SQL = text(
    """
    SELECT w.id, w.pencere_baslangic, w.pencere_bitis
    FROM patrol_window w
    JOIN patrol_plan_checkpoint ppc ON ppc.patrol_plan_id = w.patrol_plan_id
    WHERE ppc.checkpoint_id = :cp_id
      AND :okutma >= w.pencere_baslangic
      AND :okutma <  w.pencere_bitis
    ORDER BY w.pencere_baslangic
    LIMIT 1
    """
)


async def _foto_kapisi(
    db: AsyncSession, *, user: AppUser, checkpoint_id, okutma, foto_url: str | None
) -> None:
    """(P34) Tenant acmissa: turun ILK okutmasi fotografsiz kabul edilmez.

    NEDEN FOTOGRAF: NTAG424 SDM zaten etiketin FIZIKSEL varligini
    kriptografik olarak kanitliyor — "1 metre gidip gel" turu bir hareket
    kanitina gerek yok. Fotografin ekledigi sey BASKA bir boyut: ortam ve
    gunun saati (gunduz/gece) kanidi; GPS de konumu ekler. Ucu birlikte
    "etiket oradaydi + kisi oradaydi + o saatte oradaydi" der.

    YALNIZ ILK OKUTMA: her noktada fotograf istemek turu iki katina
    cikarirdi ve gorevliyi cezalandirirdi.
    """
    if foto_url:
        return
    ayar = (
        await db.execute(select(Tenant.tur_baslangic_foto_zorunlu))
    ).scalar_one_or_none()
    if not ayar:
        return
    pencere = (
        await db.execute(
            _PENCERE_BUL_SQL, {"cp_id": checkpoint_id, "okutma": okutma}
        )
    ).first()
    if pencere is None:
        return  # plansiz/pencere disi okutma — tur baslangici degil
    _, w_start, w_end = pencere
    onceki = (
        await db.execute(
            select(ScanEvent.id).where(
                ScanEvent.guard_id == user.id,
                ScanEvent.okutma_zamani >= w_start,
                ScanEvent.okutma_zamani < w_end,
            ).limit(1)
        )
    ).scalar_one_or_none()
    if onceki is None:
        # AYRI KOD: istemci bunu "govde gecersiz"den ayirt edebilmeli —
        # yapilacak sey belli (fotograf cek, ayni anahtarla yeniden gonder)
        # ve genel bir dogrulama hatasi bu eylemi gizlerdi.
        raise APIError(422, "foto_gerekli", "tur_baslangic_fotografi_gerekli")


def _is_unique_violation(exc: IntegrityError) -> bool:
    orig = getattr(exc, "orig", None)
    code = getattr(orig, "sqlstate", None) or getattr(orig, "pgcode", None)
    return code == "23505"


def _dogruluk_eq(a, b) -> bool:
    if a is None or b is None:
        return a is b
    return round(float(a), 1) == round(float(b), 1)


def _coord_eq(a, b) -> bool:
    if a is None or b is None:
        return a is b
    return round(float(a), 6) == round(float(b), 6)


# Aninda tamamlanma: taranan checkpoint'in planlarina ait, taramanin zaman
# araligini iceren AKTIF ('bekliyor') pencereler icin — planin TUM aktif
# checkpoint'leri o pencerede taranmissa pencere HEMEN 'tamamlandi' olur.
# Bos plan (aktif checkpoint yok) dokunulmaz (scheduler bitiste vacuously yapar).
_COMPLETE_WINDOWS_SQL = text(
    """
    UPDATE patrol_window w
    SET durum = 'tamamlandi', updated_at = now()
    WHERE w.durum = 'bekliyor'
      AND :okutma >= w.pencere_baslangic AND :okutma < w.pencere_bitis
      AND w.patrol_plan_id IN (
          SELECT patrol_plan_id FROM patrol_plan_checkpoint WHERE checkpoint_id = :cp_id
      )
      AND EXISTS (
          SELECT 1 FROM patrol_plan_checkpoint ppc
          JOIN checkpoint c ON c.id = ppc.checkpoint_id AND c.aktif = true
          WHERE ppc.patrol_plan_id = w.patrol_plan_id
      )
      AND NOT EXISTS (
          SELECT 1 FROM patrol_plan_checkpoint ppc
          JOIN checkpoint c ON c.id = ppc.checkpoint_id AND c.aktif = true
          WHERE ppc.patrol_plan_id = w.patrol_plan_id
            AND NOT EXISTS (
                SELECT 1 FROM scan_event se
                WHERE se.checkpoint_id = ppc.checkpoint_id
                  AND se.okutma_zamani >= w.pencere_baslangic
                  AND se.okutma_zamani <  w.pencere_bitis
            )
      )
    """
)


async def _mark_completed_windows(db: AsyncSession, checkpoint_id, okutma) -> None:
    """Bu tarama bir aktif pencerenin son eksik noktasiysa pencereyi 'tamamlandi'
    yapar (RLS ile tenant-ici). Yeni scan ile ayni transaction'da calisir."""
    await db.execute(_COMPLETE_WINDOWS_SQL, {"cp_id": checkpoint_id, "okutma": okutma})


def _same_request(existing: ScanEvent, *, guard_id, checkpoint_id, patrol_window_id,
                  nfc_tag_uid, okutma_zamani, gps_lat, gps_lng, foto_url,
                  konum_durumu, gps_dogruluk_m) -> bool:
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
        # (P34) Konum alanlari da govdenin parcasidir: ayni anahtarla
        # "konumsuz" gonderip sonra konum eklemek SESSIZCE yutulmamali.
        and existing.konum_durumu == konum_durumu
        and _dogruluk_eq(existing.gps_dogruluk_m, gps_dogruluk_m)
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
        raise APIError(422, "invalid_signature", "sdm_alanlari_birlikte_gonderilmeli")
    try:
        key = decrypt_key(checkpoint.sdm_key_sifreli, settings.sdm_kek)
    except Exception:
        # KEK degismis/yanlis: anahtar cozulemiyor — istemci hatasi degil.
        raise APIError(500, "config_error", "SDM anahtari cozulemedi (SDM_KEK yapilandirmasini kontrol edin).")
    res = verify_sdm(key, checkpoint.nfc_tag_uid, body.sdm_picc_data, body.sdm_cmac, checkpoint.sdm_son_sayac)
    if res.neden == "replay":
        raise APIError(422, "replay_detected", "sdm_tekrar_oynatma")
    if not res.ok:
        # cmac/uid/format ayrintisi sizdirilmaz (tasarim: hata yonetimi).
        raise APIError(422, "invalid_signature", "sdm_imza_dogrulanamadi")
    return True, res.sayac


@router.post("/simule")
async def simule_scan(
    body: SimuleScanCreate,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_SCANNER),
) -> JSONResponse:
    """SIMULE OKUTMA (P115) — YALNIZ demo modundaki tesiste.

    NEDEN VAR: App Store denetcisi ne fiziksel NFC etiketimizi okutabilir
    ne de bir sitede durabilir. Uygulamanin omurgasi (devriye turu)
    donanima bagli oldugu icin denetci onu HIC goremeden reddedebilir.

    KAPI TENANT BAYRAGINDA (`tenant.demo_mod`), istemcide DEGIL: istemci
    bayragi olsaydi herhangi bir kullanici gercek bir tesiste sahte tur
    kaydi uretebilir ve tur kaydinin KANIT degeri sifirlanirdi.

    KAPALIYKA 404, 403 DEGIL: "yetkin yok" demek, ucun VARLIGINI ve
    dolayisiyla boyle bir yolun bulundugunu sizdirirdi. Demo tesisi
    disinda bu uc YOKTUR.

    GERCEK YOLDAN AYRILMAZ: govde `checkpoint_id`den etiketin UID'sini
    cozer ve AYNI `create_scan` islevini cagirir. Ayri bir yazma yolu
    yazmak, denetciye urunun GERCEK akisini degil onun taklidini
    gostermek olurdu — ve iki yolun zamanla ayrismasi kacinilmazdi.

    SDM imzasi YOKTUR: kayit `imza_dogrulandi = false` olarak duser, yani
    simule okutma gercek bir okutmadan AYIRT EDILEBILIR kalir.
    """
    tenant = (await db.execute(select(Tenant))).scalar_one_or_none()
    if tenant is None or not tenant.demo_mod:
        raise APIError(404, "not_found", "uc_bulunamadi")

    checkpoint = await get_or_404(db, Checkpoint, body.checkpoint_id)
    return await create_scan(
        ScanCreate(
            nfc_tag_uid=checkpoint.nfc_tag_uid,
            checkpoint_id=checkpoint.id,
            patrol_window_id=body.patrol_window_id,
            okutma_zamani=body.okutma_zamani or datetime.now(tz=timezone.utc),
            gps_lat=body.gps_lat,
            gps_lng=body.gps_lng,
        ),
        idempotency_key=idempotency_key,
        db=db,
        user=user,
    )


@router.post("")
async def create_scan(
    body: ScanCreate,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_SCANNER),
) -> JSONResponse:
    if not idempotency_key or not idempotency_key.strip():
        raise APIError(400, "bad_request", "idempotency_key_zorunlu")

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
        raise APIError(404, "not_found", "nfc_checkpoint_eslesmedi")
    if body.checkpoint_id is not None and body.checkpoint_id != checkpoint.id:
        raise APIError(422, "invalid_reference", "checkpoint_nfc_eslesmiyor")

    # 2) patrol_window_id verildiyse dogrula (durum DEGISTIRILMEZ — scheduler isi).
    if body.patrol_window_id is not None:
        exists = (
            await db.execute(
                select(PatrolWindow.id).where(PatrolWindow.id == body.patrol_window_id)
            )
        ).scalar_one_or_none()
        if exists is None:
            raise APIError(422, "invalid_reference", "patrol_window_bulunamadi")

    okutma = body.okutma_zamani
    if okutma.tzinfo is None:  # zamanlar UTC (konvansiyon)
        okutma = okutma.replace(tzinfo=timezone.utc)

    # (P34) Fotograf: yeni istemciler DEPO ANAHTARI gonderir (dogrulanir),
    # eski `foto_url` alani dogrulanmadan kabul edilir (geriye donuk uyum).
    if body.foto_key is not None and not body.foto_key.startswith(
        f"{user.tenant_id}/"
    ):
        # Baska tenant'in objesini tur kaniti diye baglamak IDOR olurdu.
        raise APIError(422, "invalid_foto_key", "foto_key_alan_disi")
    foto = body.foto_key or body.foto_url

    # (P34) Konum durumu: istemci soylemediyse turetilir. 'var' dendiyse
    # koordinat ZORUNLUDUR — aksi halde rapor "konumu var" deyip
    # gosteremezdi (CHECK de ayni sozu DB'de tutar).
    konum_durumu = _konum_durumu(body)
    if konum_durumu == "var" and (body.gps_lat is None or body.gps_lng is None):
        raise APIError(422, "validation_error", "konum_var_ama_koordinat_yok")

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
            foto_url=foto,
            konum_durumu=konum_durumu,
            gps_dogruluk_m=body.gps_dogruluk_m,
        ):
            return JSONResponse(
                status_code=200, content=ScanEventOut.model_validate(existing).model_dump(mode="json")
            )
        raise APIError(409, "conflict", "idempotency_key_govde_farkli")

    # 3) ONCE idempotent tekrar kontrolu (SDM'den once — kritik): sayac ilk
    # gonderimde ilerledigi icin tekrar dogrulama yanlis replay uretirdi.
    existing = (
        await db.execute(select(ScanEvent).where(ScanEvent.idempotency_key == idempotency_key))
    ).scalar_one_or_none()
    if existing is not None:
        return _idempotent_yanit(existing)

    # 4) BASLANGIC FOTOGRAFI KAPISI — SDM'DEN ONCE: reddedilecek bir
    # okutma icin SDM sayacini ilerletmek, etiketi bir sonraki gecerli
    # okutmada replay saydirabilirdi.
    await _foto_kapisi(
        db, user=user, checkpoint_id=checkpoint.id, okutma=okutma,
        foto_url=foto,
    )

    # 5) SDM dogrulamasi (karar tablosu) — imza_dogrulandi YALNIZ buradan.
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
        konum_durumu=konum_durumu,
        gps_dogruluk_m=body.gps_dogruluk_m,
        foto_url=foto,
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
                raise APIError(422, "replay_detected", "sdm_tekrar_oynatma")
        # 7) ANINDA TAMAMLANMA: bu tarama bir aktif ('bekliyor') pencerenin SON
        # eksik noktasiysa pencere HEMEN 'tamamlandi' olur (scheduler'in bitiste
        # yaptigi tamamlandi tanimiyla ayni; ama pencere-bitisini beklemez).
        await _mark_completed_windows(db, checkpoint.id, okutma)
        # 8) (P160) UZAK OKUTMA ALARMI — AYNI TRANSACTION. Okutma geri
        # alinirsa alarm da geri alinir; olmayan bir okutma icin alarm
        # uretmek yoneticiyi var olmayan bir olaya yollamakti. Karar
        # icin gereken her sey (iki koordinat + tesis esigi) BU ANDA
        # elimizde; zamanlayiciya birakmak alarmi dakikalarca
        # geciktirir ve ayni veriyi ikinci kez okurdu.
        await uzak_okutma_alarmi(db, scan=obj, checkpoint=checkpoint)
        await db.refresh(obj)
        return JSONResponse(
            status_code=201, content=ScanEventOut.model_validate(obj).model_dump(mode="json")
        )

    # es zamanli yaris: baska istek ayni key ile once insert etti
    existing = (
        await db.execute(select(ScanEvent).where(ScanEvent.idempotency_key == idempotency_key))
    ).scalar_one()
    return _idempotent_yanit(existing)
