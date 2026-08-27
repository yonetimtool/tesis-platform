"""Scheduler DB islemleri — pencere uretimi + kacirilan tur tespiti.

RLS (KRITIK):
  * Tenant LISTESI app_rw ile okunamaz (tenant tablosunda RLS; baglam yokken
    hicbir satir gorunmez). Bu yuzden tenant enumerasyonu OWNER baglantisiyla
    (salt-okuma: id, timezone) yapilir — gerekce: RLS bootstrap.
  * Asil is (plan/checkpoint/scan okuma, patrol_window yazma) her tenant icin
    APP_RW + `SET LOCAL app.current_tenant_id` ile, RLS altinda yapilir. Boylece
    bir tenant'in verisi digerine sizmaz (izolasyon DB'de zorlanir).

Idempotency:
  * Uretim: INSERT ... ON CONFLICT (patrol_plan_id, pencere_baslangic) DO NOTHING
    (sozlesmedeki uq_patrol_window_plan_baslangic dogal anahtari).
  * Tespit: yalnizca durum='bekliyor' pencereler islenir; tamamlandi/kacirildi
    olanlara dokunulmaz (tekrar notify yok).

"tamamlandi" tanimi (v0): Pencere bitmis (pencere_bitis <= now) ve plana atanmis
TUM AKTIF checkpoint'ler icin, okutma_zamani pencere araliginda [baslangic, bitis)
en az bir scan_event varsa => 'tamamlandi'. En az biri eksikse => 'kacirildi'.
Plana atanmis aktif checkpoint yoksa (bos plan) => vacuously 'tamamlandi'.
"""
from __future__ import annotations

import json
import uuid
from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

import psycopg

from ..config import settings
from ..tur_alarm import gecen_dakika, vadesi_gelen_adim
from ..ceviri import VARSAYILAN_DIL
from ..push_metinleri import push_govdesi
from .notify import dispatch_external, notify_gecikmis_okutma, notify_missed_tour
from .windows import _local_dt, plan_windows

# (P181 Bölüm 10.2) Vardiya özetini alacak roller — spec 10.3: "YÖNETİCİ ...
# devriye vardiya özeti". Alarm (real-time) rollerinden AYRI: özet bir RAPORDUR.
_VARDIYA_OZETI = "vardiya_ozeti"
_VARDIYA_OZETI_ROLLERI: tuple[str, ...] = ("admin", "yonetici")


def _gun_uyar(gun_tipi: str, d: date) -> bool:
    """Vardiya `gun_tipi`'ne göre yerel tarih `d`'de vardiya KOŞAR mı.

    `resmi_tatil`: resmi tatil takvimi YOK → özet üretilmez (yanlış "0/N okundu"
    üretmemek için; sınırlama dökümante — bkz. docs/P181-kararlar.md §10.2).
    """
    if gun_tipi == "her_gun":
        return True
    if gun_tipi == "hafta_ici":
        return d.weekday() < 5
    if gun_tipi == "hafta_sonu":
        return d.weekday() >= 5
    return False  # resmi_tatil (takvim yok)


def _son_biten_vardiya(
    tzname: str, now: datetime, bas: time, bit: time
) -> tuple[datetime, datetime, date] | None:
    """BUGÜN yerel tarihinde BİTMİŞ vardiya oluşumu: (start_utc, end_utc,
    baslama_gunu) — yoksa None.

    Gündüz vardiyası (`bas <= bit`): bugün [bugün+bas, bugün+bit]. Gece vardiyası
    (`bas > bit`): DÜN başlar, BUGÜN biter [dün+bas, bugün+bit]. Yalnız bugünkü
    oluşuma bakılır (geçmiş geri-doldurulmaz); henüz bitmemişse None → erken/
    süren vardiya özetlenmez. `baslama_gunu` özet gün anahtarıdır (dedup + etiket).
    """
    tz = ZoneInfo(tzname)
    bugun = now.astimezone(tz).date()
    if bas > bit:  # gece vardiyası: dün başladı, bugün biter
        baslama_gunu = bugun - timedelta(days=1)
        bitis_gunu = bugun
    else:  # gündüz vardiyası: aynı gün
        baslama_gunu = bugun
        bitis_gunu = bugun
    start_utc = _local_dt(tzname, baslama_gunu, bas).astimezone(timezone.utc)
    end_utc = _local_dt(tzname, bitis_gunu, bit).astimezone(timezone.utc)
    if end_utc <= now:
        return (start_utc, end_utc, baslama_gunu)
    return None


def summarize_ended_shifts(
    *,
    now: datetime | None = None,
    owner_dsn: str | None = None,
    app_dsn: str | None = None,
) -> int:
    """(P181 Bölüm 10.2) Biten vardiyalar için TEK özet bildirim.

    Devriye okutmaları TEK TEK push üretmez; vardiya BİTTİĞİNDE tek özet
    ("X/Y nokta okutuldu") yönetime gider. Sayım: vardiyanın aktif planlarının
    DISTINCT aktif checkpoint'leri (beklenen) ve bunlardan vardiya aralığında
    en az bir kez okutulanlar (okutulan). IDEMPOTENT: (vardiya, başlama günü)
    başına tek kayıt (`dedup_key`); beat sık koşsa da tekrar üretmez.

    Dönüş: yeni yazılan özet sayısı.
    """
    now = _now(now)
    owner_dsn = owner_dsn or settings.owner_dsn
    app_dsn = app_dsn or settings.app_dsn

    yazilan = 0
    tenants = _list_tenants(owner_dsn)
    with psycopg.connect(app_dsn, connect_timeout=10) as conn:
        for tenant_id, tzname in tenants:
            with conn.transaction():
                conn.execute(
                    "SELECT set_config('app.current_tenant_id', %s, true)", (str(tenant_id),)
                )
                shifts = conn.execute(
                    "SELECT id, ad, baslangic_saat, bitis_saat, gun_tipi FROM shift"
                ).fetchall()
                for shift_id, ad, bas, bit, gun_tipi in shifts:
                    oluşum = _son_biten_vardiya(tzname, now, bas, bit)
                    if oluşum is None:
                        continue  # henüz bitmiş oluşum yok
                    start_utc, end_utc, baslama_gunu = oluşum
                    if not _gun_uyar(gun_tipi, baslama_gunu):
                        continue  # bu gün bu vardiya koşmaz (hafta içi/sonu/tatil)

                    # Vardiyanın aktif planlarının DISTINCT aktif checkpoint'leri.
                    beklenen_ids = [
                        r[0]
                        for r in conn.execute(
                            "SELECT DISTINCT c.id "
                            "FROM patrol_plan p "
                            "JOIN patrol_plan_checkpoint ppc ON ppc.patrol_plan_id = p.id "
                            "JOIN checkpoint c ON c.id = ppc.checkpoint_id AND c.aktif = true "
                            "WHERE p.shift_id = %s AND p.aktif = true",
                            (shift_id,),
                        ).fetchall()
                    ]
                    beklenen = len(beklenen_ids)
                    if beklenen == 0:
                        continue  # vardiyaya bağlı okutulacak nokta yok → özet anlamsız

                    okutulan = conn.execute(
                        "SELECT count(DISTINCT se.checkpoint_id) FROM scan_event se "
                        "WHERE se.checkpoint_id = ANY(%s) "
                        "AND se.okutma_zamani >= %s AND se.okutma_zamani < %s",
                        ([str(c) for c in beklenen_ids], start_utc, end_utc),
                    ).fetchone()[0]

                    veri = {
                        "vardiya": ad,
                        "gun": baslama_gunu.strftime("%d-%m"),
                        "okutulan": int(okutulan),
                        "beklenen": beklenen,
                    }
                    dedup = f"{_VARDIYA_OZETI}:{shift_id}:{baslama_gunu.isoformat()}"
                    mesaj = push_govdesi(_VARDIYA_OZETI, VARSAYILAN_DIL, veri)
                    cur = conn.execute(
                        "INSERT INTO notification (tenant_id, tip, dedup_key, mesaj, "
                        "mesaj_kimlik, mesaj_veri) "
                        "VALUES (%s, 'vardiya_ozeti', %s, %s, %s, %s::jsonb) "
                        "ON CONFLICT (tenant_id, dedup_key) DO NOTHING",
                        (tenant_id, dedup, mesaj, _VARDIYA_OZETI, json.dumps(veri)),
                    )
                    if cur.rowcount == 0:
                        continue  # bu vardiya-günü zaten özetlendi
                    dispatch_external(
                        _VARDIYA_OZETI,
                        tenant_id=tenant_id,
                        target_roles=_VARDIYA_OZETI_ROLLERI,
                        params=veri,
                        data={"tip": _VARDIYA_OZETI, "shift_id": str(shift_id)},
                    )
                    yazilan += 1
    return yazilan


def _now(now: datetime | None) -> datetime:
    return now or datetime.now(tz=timezone.utc)


def _list_tenants(owner_dsn: str) -> list[tuple[uuid.UUID, str]]:
    """Tum tenant (id, timezone) — OWNER ile (RLS bootstrap, salt-okuma)."""
    with psycopg.connect(owner_dsn, autocommit=True, connect_timeout=10) as conn:
        return [
            (row[0], row[1])
            for row in conn.execute("SELECT id, timezone FROM tenant").fetchall()
        ]


def _list_tenants_alarm(owner_dsn: str) -> list[tuple[uuid.UUID, int, int]]:
    """(P34) Tenant + tur alarm ayarlari — OWNER ile (RLS bootstrap).

    Ayar TENANT BASINADIR: 10 dakika bir sitede makul, kampus buyuklugunde
    bir yerlesimde erken alarm demektir.
    """
    with psycopg.connect(owner_dsn, autocommit=True, connect_timeout=10) as conn:
        return [
            (row[0], row[1], row[2])
            for row in conn.execute(
                "SELECT id, tur_gecikme_toleransi_dk, tur_alarm_tekrar_sayisi "
                "FROM tenant"
            ).fetchall()
        ]


def materialize_windows(
    *,
    now: datetime | None = None,
    horizon_days: int | None = None,
    owner_dsn: str | None = None,
    app_dsn: str | None = None,
) -> int:
    """Aktif planlar icin pencereleri 'bekliyor' olarak onceden uretir.

    Donus: yeni eklenen pencere sayisi (idempotent; tekrarlar 0 ekler).
    """
    now = _now(now)
    horizon_days = horizon_days if horizon_days is not None else settings.scheduler_horizon_days
    owner_dsn = owner_dsn or settings.owner_dsn
    app_dsn = app_dsn or settings.app_dsn

    created = 0
    tenants = _list_tenants(owner_dsn)
    with psycopg.connect(app_dsn, connect_timeout=10) as conn:
        for tenant_id, tzname in tenants:
            with conn.transaction():
                conn.execute(
                    "SELECT set_config('app.current_tenant_id', %s, true)", (str(tenant_id),)
                )
                plans = conn.execute(
                    "SELECT id, baslangic_saat, bitis_saat, periyot_dakika "
                    "FROM patrol_plan WHERE aktif = true"
                ).fetchall()
                for plan_id, baslangic, bitis, periyot in plans:
                    for w_start, w_end in plan_windows(
                        tzname, now, horizon_days, baslangic, bitis, periyot
                    ):
                        cur = conn.execute(
                            "INSERT INTO patrol_window "
                            "(tenant_id, patrol_plan_id, pencere_baslangic, pencere_bitis, durum) "
                            "VALUES (%s, %s, %s, %s, 'bekliyor') "
                            "ON CONFLICT (patrol_plan_id, pencere_baslangic) DO NOTHING",
                            (tenant_id, plan_id, w_start, w_end),
                        )
                        created += cur.rowcount  # 1 eklendi, 0 zaten vardi
    return created


def detect_missed(
    *,
    now: datetime | None = None,
    owner_dsn: str | None = None,
    app_dsn: str | None = None,
) -> dict[str, int]:
    """Bitmis 'bekliyor' pencereleri tamamlandi/kacirildi olarak isaretler.

    Donus: {"tamamlandi": n, "kacirildi": m}. Kacirildi'da notify_missed_tour cagrilir.
    """
    now = _now(now)
    owner_dsn = owner_dsn or settings.owner_dsn
    app_dsn = app_dsn or settings.app_dsn

    summary = {"tamamlandi": 0, "kacirildi": 0}
    tenants = _list_tenants(owner_dsn)
    with psycopg.connect(app_dsn, connect_timeout=10) as conn:
        for tenant_id, _tz in tenants:
            with conn.transaction():
                conn.execute(
                    "SELECT set_config('app.current_tenant_id', %s, true)", (str(tenant_id),)
                )
                # Plan ADI da cekilir: bildirim metni artik pencere ISO
                # damgasi degil PLAN ADI + eksik sayisi tasir (tur 16).
                windows = conn.execute(
                    "SELECT w.id, w.patrol_plan_id, w.pencere_baslangic, "
                    "       w.pencere_bitis, p.ad "
                    "FROM patrol_window w "
                    "JOIN patrol_plan p ON p.id = w.patrol_plan_id "
                    "WHERE w.durum = 'bekliyor' AND w.pencere_bitis <= %s",
                    (now,),
                ).fetchall()

                for window_id, plan_id, w_start, w_end, plan_adi in windows:
                    expected = [
                        r[0]
                        for r in conn.execute(
                            "SELECT c.id FROM patrol_plan_checkpoint ppc "
                            "JOIN checkpoint c ON c.id = ppc.checkpoint_id "
                            "WHERE ppc.patrol_plan_id = %s AND c.aktif = true",
                            (plan_id,),
                        ).fetchall()
                    ]
                    missing = [
                        cid
                        for cid in expected
                        if conn.execute(
                            "SELECT 1 FROM scan_event "
                            "WHERE checkpoint_id = %s "
                            "AND okutma_zamani >= %s AND okutma_zamani < %s LIMIT 1",
                            (cid, w_start, w_end),
                        ).fetchone()
                        is None
                    ]

                    if missing:
                        conn.execute(
                            "UPDATE patrol_window SET durum = 'kacirildi', updated_at = now() "
                            "WHERE id = %s",
                            (window_id,),
                        )
                        notify_missed_tour(
                            conn=conn,
                            tenant_id=tenant_id,
                            plan_id=plan_id,
                            window_id=window_id,
                            pencere_baslangic=w_start,
                            pencere_bitis=w_end,
                            missing_checkpoints=missing,
                            plan_adi=plan_adi,
                        )
                        summary["kacirildi"] += 1
                    else:
                        conn.execute(
                            "UPDATE patrol_window SET durum = 'tamamlandi', updated_at = now() "
                            "WHERE id = %s",
                            (window_id,),
                        )
                        summary["tamamlandi"] += 1
    return summary



def detect_gecikmis(
    *,
    now: datetime | None = None,
    owner_dsn: str | None = None,
    app_dsn: str | None = None,
) -> int:
    """(P34) ACIK pencerede tolerans asildi ve HIC okutma yok -> tekrarli alarm.

    `detect_missed`DEN AYRI: o, pencere BITTIKTEN sonra kacirildi damgasi
    vurur ve yapilacak bir sey kalmamistir. Bu ise pencere ACIKKEN calisir;
    tur HALA KURTARILABILIR — alarmin amaci damgalamak degil TURU
    BASLATMAKTIR.

    DURDURMA KOSULLARI (ikisi de dogal): ilk okutma geldiginde sorgu
    pencereyi artik secmez; pencere bittiginde `vadesi_gelen_adim` None
    doner. Ayrica bitmis pencere zaten `kacirildi` alarmina konudur —
    ikisini birden gondermek ayni olayi iki kez bildirmek olurdu.

    Donus: gonderilen yeni alarm sayisi (idempotent; ayni adim tekrar
    gonderilmez).
    """
    now = _now(now)
    owner_dsn = owner_dsn or settings.owner_dsn
    app_dsn = app_dsn or settings.app_dsn

    gonderilen = 0
    with psycopg.connect(app_dsn, connect_timeout=10) as conn:
        for tenant_id, tolerans, tekrar in _list_tenants_alarm(owner_dsn):
            if tolerans <= 0 or tekrar <= 0:
                continue  # alarm kapali (gecerli tercih)
            with conn.transaction():
                conn.execute(
                    "SELECT set_config('app.current_tenant_id', %s, true)",
                    (str(tenant_id),),
                )
                # ACIK pencereler + planin aktif checkpoint'lerinde HIC
                # okutma yok. "Hic" bilerek: kismi ilerleme turun
                # BASLADIGINI gosterir ve alarm konusu degildir (eksik
                # noktalar pencere bitiminde `kacirildi` ile yakalanir).
                windows = conn.execute(
                    """
                    SELECT w.id, w.patrol_plan_id, w.pencere_baslangic,
                           w.pencere_bitis, p.ad, p.shift_id
                    FROM patrol_window w
                    JOIN patrol_plan p ON p.id = w.patrol_plan_id
                    WHERE w.durum = 'bekliyor'
                      AND w.pencere_baslangic <= %s
                      AND w.pencere_bitis > %s
                      AND EXISTS (
                          SELECT 1 FROM patrol_plan_checkpoint ppc
                          JOIN checkpoint c ON c.id = ppc.checkpoint_id
                                           AND c.aktif = true
                          WHERE ppc.patrol_plan_id = w.patrol_plan_id
                      )
                      AND NOT EXISTS (
                          SELECT 1 FROM scan_event se
                          JOIN patrol_plan_checkpoint ppc
                               ON ppc.checkpoint_id = se.checkpoint_id
                              AND ppc.patrol_plan_id = w.patrol_plan_id
                          WHERE se.okutma_zamani >= w.pencere_baslangic
                            AND se.okutma_zamani <  w.pencere_bitis
                      )
                    """,
                    (now, now),
                ).fetchall()

                for window_id, plan_id, w_start, w_end, plan_adi, shift_id in windows:
                    adim = vadesi_gelen_adim(
                        pencere_baslangic=w_start,
                        pencere_bitis=w_end,
                        simdi=now,
                        tolerans_dk=tolerans,
                        tekrar=tekrar,
                    )
                    if adim is None:
                        continue
                    # Alarmin MUHATABI: plana bagli vardiyaya atanmis
                    # personel. Vardiya yoksa liste bostur ve alarm yalniz
                    # yonetime gider (sessiz kalmaktan iyidir).
                    gorevliler = (
                        [
                            r[0]
                            for r in conn.execute(
                                "SELECT user_id FROM shift_assignment "
                                "WHERE shift_id = %s",
                                (shift_id,),
                            ).fetchall()
                        ]
                        if shift_id
                        else []
                    )
                    if notify_gecikmis_okutma(
                        conn=conn,
                        tenant_id=tenant_id,
                        plan_id=plan_id,
                        window_id=window_id,
                        plan_adi=plan_adi,
                        dakika=gecen_dakika(w_start, now),
                        adim=adim,
                        gorevli_ids=gorevliler,
                    ):
                        gonderilen += 1
    return gonderilen
