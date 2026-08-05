"""GET /dashboard/live — canli panel ozeti — /contracts/openapi.yaml.

RBAC (auth.md §4): admin + security (tesis_gorevlisi/resident degil).
tenant token'dan; RLS ile izole. N+1'den kacinmak icin set-tabanli 3 sorgu:
  1) tenant.timezone (bugunun yerel sinirlarini UTC'ye cevirmek icin)
  2) aktif_turlar: bugunku patrol_window'lar + beklenen/okutulan checkpoint sayilari
  3) alarm_gruplari: `notification` tablosundan, devriye adiyla birlikte
     (tek LEFT JOIN — ad icin olay basina sorgu YOK)

(P133.3) SOZLESME DEGISTI: `son_alarmlar` (duz liste) yerine
`alarm_gruplari` doner. Neden: pano alti neredeyse AYNI satiri yan yana
ciziyordu — `notification`da (tenant, tip, pencere) tekil oldugu icin bir
planin alti penceresi alti satir uretiyor. Yonetici icin bunlar TEK bir
olgudur ("E-Devriye'de 6 gecikme"), alti ayri olay degil.

TUKETICI OLCULDU (uydurulmadi): mobil `/dashboard/live`dan yalniz
`aktif_turlar` okuyor; `son_alarmlar`in tek tuketicisi web panosuydu.
Alan bu yuzden BIRAKILMADI — iki bicimi birden donmek, kucultmesi gereken
govdeyi buyuturdu.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, Header, Query
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from ..deps import get_tenant_db, require_role
from ..hata_metinleri import istek_dili
from ..models import AppUser
from ..push_metinleri import push_govdesi
from ..schemas import (
    ALARM_ONEMI,
    AktifTurOut,
    AlarmGrubuOut,
    AlarmOlayiOut,
    DashboardLiveOut,
)

router = APIRouter(prefix="/dashboard", tags=["dashboard"])

_VIEWER = require_role("admin", "yonetici", "security", "guvenlik_amiri")

#: Panodaki MALI alani gorebilen roller (bkz. `aidat_tahsilat_orani`).
#: Kume `reports.py`deki `_YONETIM` ile AYNI olmali; oradan alinir ki
#: mali gorunurluk iki yerde tanimlanmasin.
_MALI_ROLLER = frozenset({"admin", "yonetici"})

# Bugunku pencereler + beklenen (atanmis aktif checkpoint) ve okutulan
# (pencere araliginda okutulmus, beklenen) sayilari — tek set-tabanli sorgu.
_AKTIF_TURLAR_SQL = text(
    """
    SELECT w.id              AS patrol_window_id,
           w.patrol_plan_id  AS patrol_plan_id,
           p.ad              AS patrol_plan_ad,
           w.pencere_baslangic,
           w.pencere_bitis,
           w.durum,
           count(DISTINCT c.id)           AS beklenen,
           count(DISTINCT s.checkpoint_id) AS okutulan
    FROM patrol_window w
    JOIN patrol_plan p ON p.id = w.patrol_plan_id
    LEFT JOIN patrol_plan_checkpoint ppc ON ppc.patrol_plan_id = w.patrol_plan_id
    LEFT JOIN checkpoint c ON c.id = ppc.checkpoint_id AND c.aktif = true
    LEFT JOIN scan_event s ON s.checkpoint_id = c.id
         AND s.okutma_zamani >= w.pencere_baslangic
         AND s.okutma_zamani <  w.pencere_bitis
    WHERE w.pencere_baslangic >= :day_start AND w.pencere_baslangic < :day_end
    GROUP BY w.id, w.patrol_plan_id, p.ad, w.pencere_baslangic, w.pencere_bitis, w.durum
    ORDER BY w.pencere_baslangic
    """
)

# Alarmlar KALICI notification tablosundan okunur.
# Yalniz sozlesmedeki Alarm.tip degerleri; peyzaj_* hatirlatmalari panele alarm
# olarak DUSMEZ (onlar /notifications altinda gorulur).
#
# (P133.3) DEVRIYE ADI ICIN JOIN — N+1 YOK. Grup basligi "hangi devriye"
# demek zorunda; adi olay basina ayri sorguyla cekmek, alti alarmda alti
# sorgu ederdi. Tek LEFT JOIN yeter (plan silinmisse FK zaten SET NULL
# oldugu icin ad da NULL gelir ve istemci "Devriye" yazmaz).
#
# GRUPLAMA SQL'DE DEGIL PYTHON'DA: LIMIT alarm SAYISINA uygulanmali
# (gruplama sonrasi degil), yoksa "son 20 olay" ile "son 20 grup" farkli
# seylerdir ve ikincisi gruplama oncesi/sonrasi karsilastirmayi anlamsiz
# kilardi. Satirlar zaten sirali geliyor; toplama tek gecistir.
_ALARMLAR_SQL = text(
    """
    SELECT n.tip, n.patrol_window_id, n.patrol_plan_id, p.ad AS patrol_plan_ad,
           n.checkpoint_id, n.mesaj, n.mesaj_kimlik, n.mesaj_veri, n.created_at
    FROM notification n
    LEFT JOIN patrol_plan p ON p.id = n.patrol_plan_id
    WHERE n.tip IN ('kacirilan_tur', 'eksik_checkpoint', 'gecikmis_okutma')
    -- Tum alarmlar esit oncelikli => en yeni ustte. (Oncelik yukseltmesi
    -- yalniz SOS alarmi icindi; o ozellik kaldirildi.)
    ORDER BY n.created_at DESC
    LIMIT :alarm_limit
    """
)


@router.get("/live", response_model=DashboardLiveOut)
async def dashboard_live(
    alarm_limit: int = Query(20, ge=1, le=100),
    accept_language: str | None = Header(None, alias="Accept-Language"),
    db: AsyncSession = Depends(get_tenant_db),
    kullanici: AppUser = Depends(_VIEWER),
) -> DashboardLiveOut:
    now = datetime.now(tz=timezone.utc)
    dil = istek_dili(accept_language)

    # tenant.timezone (RLS: kendi tenant satiri gorunur) -> bugunun yerel siniri
    tzname = (
        await db.execute(text("SELECT timezone FROM tenant"))
    ).scalar_one_or_none() or "UTC"
    tz = ZoneInfo(tzname)
    now_local = now.astimezone(tz)
    day_start_local = datetime(now_local.year, now_local.month, now_local.day, tzinfo=tz)
    day_start = day_start_local.astimezone(timezone.utc)
    day_end = (day_start_local + timedelta(days=1)).astimezone(timezone.utc)

    tur_rows = (
        await db.execute(_AKTIF_TURLAR_SQL, {"day_start": day_start, "day_end": day_end})
    ).mappings().all()
    aktif_turlar = [
        AktifTurOut(
            patrol_window_id=r["patrol_window_id"],
            patrol_plan_id=r["patrol_plan_id"],
            patrol_plan_ad=r["patrol_plan_ad"],
            pencere_baslangic=r["pencere_baslangic"],
            pencere_bitis=r["pencere_bitis"],
            durum=r["durum"],
            beklenen_checkpoint_sayisi=int(r["beklenen"]),
            okutulan_checkpoint_sayisi=int(r["okutulan"]),
        )
        for r in tur_rows
    ]

    alarm_rows = (
        await db.execute(_ALARMLAR_SQL, {"alarm_limit": alarm_limit})
    ).mappings().all()

    # (P133.3) TOPLAMA: (tip, devriye) ikilisiyle grupla.
    #
    # NEDEN: pano alti neredeyse ayni satir ciziyordu ("E-Devriye turunda N
    # dakikadir okutma yok" x 6) — `notification`da (tenant, tip, pencere)
    # tekil oldugu icin AYNI planin alti PENCERESI alti satir uretiyor.
    # Yonetici icin bunlar tek bir olgudur: "E-Devriye'de 6 gecikme".
    #
    # SIRA KORUNUR: sozluk ekleme sirasini tutar ve satirlar zaten
    # `created_at DESC` geliyor — yani gruplar da en yenisi ustte cikar,
    # ayrica siralamaya gerek yok.
    gruplar: dict[tuple[str, uuid.UUID | None], AlarmGrubuOut] = {}
    for r in alarm_rows:
        # TUR 62: metin ISTEGIN dilinde uretilir.
        #
        # Kayit tur 16'dan beri METIN DEGIL KIMLIK tasiyor (`mesaj_kimlik` +
        # `mesaj_veri`) — tam olarak "ilk yazanin dili kalici olmasin" diye.
        # `/notifications` bunu kullaniyordu, bu uc ise DEPRECATED `mesaj`
        # kolonunu donuyordu; sonuc: panonun alarm listesi ALTI DILDE
        # Turkce goruntuluyordu.
        metin = (
            push_govdesi(r["mesaj_kimlik"], dil, r["mesaj_veri"] or {})
            if r["mesaj_kimlik"]
            else r["mesaj"]
        )
        olay = AlarmOlayiOut(
            olusma_zamani=r["created_at"],
            patrol_window_id=r["patrol_window_id"],
            checkpoint_id=r["checkpoint_id"],
        )
        anahtar = (r["tip"], r["patrol_plan_id"])
        grup = gruplar.get(anahtar)
        if grup is None:
            gruplar[anahtar] = AlarmGrubuOut(
                tip=r["tip"],
                patrol_plan_id=r["patrol_plan_id"],
                patrol_plan_ad=r["patrol_plan_ad"],
                # Satirlar DESC geldigi icin grubun ILK gordugu olay en
                # yenisidir; temsili metin odur.
                mesaj=metin,
                sayi=1,
                # Satirlar DESC geldigi icin grubun ILK gordugu olay en
                # yenisidir.
                en_son=r["created_at"],
                onem=ALARM_ONEMI.get(r["tip"], "orta"),
                olaylar=[olay],
            )
        else:
            grup.sayi += 1
            grup.olaylar.append(olay)

    alarm_gruplari = list(gruplar.values())

    # (P133.2) Aidat tahsilat orani — YALNIZ mali yetkisi olan role.
    #
    # Bu uc `security` ve `guvenlik_amiri`ne de acik; tahsilat orani MALI
    # veridir. Rol yetmiyorsa sorgu HIC calistirilmaz (hem sizinti hem
    # gereksiz is olmaz) ve alan `null` doner.
    #
    # AYRI UC ACILMADI: panonun ek gidis-donusu olmamali. Hesap
    # `reports._tahsilat_ozet`ten AYNEN kullanilir — tahsilat oraninin
    # ikinci bir tanimi olmasin diye.
    # NFC nokta sayisi — tesis blogu icin. Ayri `/checkpoints` istegi
    # acmamak adina buraya bindirildi; yalniz AKTIF noktalar sayilir
    # (pasif nokta sahada okutulmaz, sayiya girmesi yaniltici olurdu).
    nfc_sayisi = int(
        (
            await db.execute(
                text("SELECT count(*) FROM checkpoint WHERE aktif = true")
            )
        ).scalar_one()
    )

    tahsilat_orani: int | None = None
    if kullanici.role in _MALI_ROLLER:
        from .reports import _tahsilat_ozet

        tahsilat_orani = (await _tahsilat_ozet(db, None)).tahsilat_orani_yuzde

    return DashboardLiveOut(
        generated_at=now,
        aktif_turlar=aktif_turlar,
        alarm_gruplari=alarm_gruplari,
        aidat_tahsilat_orani=tahsilat_orani,
        nfc_nokta_sayisi=nfc_sayisi,
    )
