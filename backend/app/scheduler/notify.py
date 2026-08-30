"""Bildirim kancasi — kacirilan turu KALICI notification kaydina yazar.

Idempotent: ON CONFLICT (tenant_id, tip, patrol_window_id) DO NOTHING — ayni
kacirilan pencere icin tekrar kayit uretmez. (0023'ten sonra bu teklik KISMI
bir indekstir: `gecikmis_okutma` haric — o alarm TEKRAR ETMEK ZORUNDADIR ve
idempotencysi `dedup_key` = tip:pencere:ADIM ile saglanir.) Yazma, cagiranin (scheduler) ACTIVE
psycopg baglantisi + tenant context'i (SET LOCAL app.current_tenant_id) icinde
yapilir; boylece RLS WITH CHECK saglanir.

Gercek push: `dispatch_external` kancasi FCM'e baglanir (app/push.py). In-app
notification'i ETKILEMEZ — push EK gonderimdir; hatasi bildirim akisini kirmaz.
"""
from __future__ import annotations

import json
import logging
import uuid
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from datetime import datetime

import psycopg

from .. import push
from ..config import settings
from ..gunlukleme import guvenli_alanlar
from ..push_metinleri import dil_normalize, push_basligi, push_govdesi
from ..ceviri import VARSAYILAN_DIL

logger = logging.getLogger("scheduler.notify")

# Alarm bildirimlerini push olarak alacak roller (dashboard alarm mantigiyla tutarli).
# (P35) Amir de alarm alir: dis sirket modunda turun sahibi odur.
_ALARM_ROLES: tuple[str, ...] = ("admin", "security", "guvenlik_amiri")

# Bildirim kimligi = `notification.tip` = `data.tip` (tek deger, uc yerde ayni).
_KACIRILAN_TUR = "kacirilan_tur"
_GECIKMIS_OKUTMA = "gecikmis_okutma"
# (P34) Gecikme alarmini ROL olarak alanlar. Gorevlinin KENDISI ayrica
# KISI olarak hedeflenir (asagida) — rol yayinina birakmak, o vardiyada
# olmayan tum guvenlik personelini de titretirdi.
# (P35) Yonetim VE amir: hangi mod aktif olursa olsun izleyen taraf
# haberdar olmali — mod'a gore daraltmak, mod yanlis ayarlandiginda
# alarmi kimsenin gormemesi demekti.
_GECIKME_ROLLERI: tuple[str, ...] = ("admin", "yonetici", "guvenlik_amiri")


def dispatch_external(
    kimlik: str,
    *,
    tenant_id: uuid.UUID | None = None,
    target_roles: Sequence[str] | None = None,
    target_user_ids: Sequence[uuid.UUID] | None = None,
    params: Mapping[str, object] | None = None,
    data: Mapping[str, str] | None = None,
) -> None:
    """Gercek-gonderim kancasi (FCM push) — EK gonderim, in-app'i etkilemez.

    METIN DEGIL KIMLIK (tur 16): cagiran cumle degil `kimlik` + `params`
    verir; baslik/govde CIHAZIN dilinde burada uretilir
    (`push_metinleri.METINLER`). Push asenkron oldugu icin istegin
    `Accept-Language` basligi YOKTUR — dil `user_device.dil`den okunur ve
    gonderim DILE GORE gruplanir (ayni olay, farkli dilde iki batch).

    Hedef: `target_user_ids` verilirse YALNIZ o kullanicilarin cihazlari
    (orn. talep yaniti -> talebi acan sakin); yoksa `target_roles`. Ikisi de
    yoksa (veya tenant_id yoksa) eski no-op davranisi (yalniz log). Push
    hatasi bildirim akisini KIRMAZ (try/except + log).
    """
    # Log OPERATORE hitap eder: kimlik + parametre ADLARI, cumle degil.
    #
    # (P134) DEGERLER YAZILMAZ: sablon alanlari arasinda `ad` ve `daire`
    # var, ikisi de bir haneyi isaret eder. Operatorun ihtiyaci "hangi
    # bildirim, hangi alanlarla kuruldu"dur; degerler `notification`
    # tablosunda zaten duruyor ve orasi KVKK saklama gorevine BAGLI.
    logger.info("EXTERNAL_NOTIFY: %s %s", kimlik, guvenli_alanlar(params))
    try:
        _push_to_devices(
            tenant_id=tenant_id,
            target_roles=target_roles,
            target_user_ids=target_user_ids,
            kimlik=kimlik,
            params=params,
            data=data,
        )
    except Exception:  # savunma: push cokerse in-app bildirim akisi devam eder
        logger.exception("push gonderimi basarisiz (in-app bildirimi etkilenmez)")


@dataclass(frozen=True)
class Cihaz:
    """Hedef cihaz — token + dil + SAHIBI.

    (P191 §2) `user_id` eklendi: teshis satiri "kime" sorusunu cevaplamali;
    token tek basina bir insani gostermez.
    """

    token: str
    dil: str
    user_id: uuid.UUID
    platform: str | None


#: Saglayici TOPLAM durumu -> teshis durumu (token bazinda sonuc yoksa yedek).
_TOPLAM_DURUM = {
    "sent": "gonderildi",
    "noop": "noop",
    "push_unconfigured": "yapilandirilmadi",
    "basarisiz": "basarisiz",
}


def _push_to_devices(
    *,
    tenant_id: uuid.UUID | None,
    target_roles: Sequence[str] | None,
    target_user_ids: Sequence[uuid.UUID] | None = None,
    kimlik: str,
    params: Mapping[str, object] | None,
    data: Mapping[str, str] | None,
) -> None:
    provider = push.get_push_provider()
    if tenant_id is None or not (target_roles or target_user_ids):
        return  # hedef bilgisi yok -> gonderim yapma (eski no-op)
    # (P181 Bölüm 10.3) ROL + KISI hedefi BIRLIKTE cozulur ve TOKEN bazinda
    # DEDUP edilir: cok-rollu / hem-kisi-hem-rol hedeflenen kullanici TEK push
    # alir. Eskiden roller ve kisiler AYRI cagrilarla gonderiliyordu; ayni kisi
    # hem gorevli hem yonetici ise iki bildirim duyardi. Kanal tercihi
    # (`bildirim_mobil`, göç 0055) fetch SQL'inde uygulanir.
    cihazlar: dict[str, Cihaz] = {}  # token -> cihaz (ilk goren kazanir)
    if target_roles:
        for c in _fetch_device_tokens(tenant_id, target_roles):
            cihazlar.setdefault(c.token, c)
    if target_user_ids:
        for c in _fetch_device_tokens_for_users(tenant_id, target_user_ids):
            cihazlar.setdefault(c.token, c)
    if not cihazlar:
        # (P191 §2) SESSIZ KALMA. "Push hic tetiklenmedi" ile "tetiklendi ama
        # gonderilecek cihaz yok" TAMAMEN farkli iki arizadir ve teshis eden
        # kisi ikisini ayirt edebilmelidir. Neden ayrica sayilir: cihaz kaydi
        # mi yok, yoksa herkes mobil bildirimi mi kapatmis?
        kapali, cihazsiz = _hedef_yok_nedeni(tenant_id, target_roles, target_user_ids)
        logger.warning(
            "PUSH hedef yok: kimlik=%s tenant=%s roller=%s kisi=%s | "
            "aktif cihazi olan ama bildirim_mobil KAPALI: %d, hic aktif cihazi "
            "olmayan: %d",
            kimlik, tenant_id, list(target_roles or ()), len(list(target_user_ids or ())),
            kapali, cihazsiz,
        )
        _teshis_yaz(
            tenant_id,
            [(kimlik, None, None, None, provider.name, "hedef_yok",
              "tercih_kapali" if kapali else "cihaz_yok")],
        )
        return
    # DILE GORE GRUPLA: tek bir metinle gondermek, cihazin dilini yok saymak
    # olurdu. Gruplama gonderim SAYISINI degil, metin SAYISINI artirir.
    gruplar: dict[str, list[str]] = {}
    for token, c in cihazlar.items():
        gruplar.setdefault(dil_normalize(c.dil), []).append(token)
    gecersiz: list[str] = []
    satirlar: list[tuple] = []
    for dil, tokenlar in gruplar.items():
        sonuc = provider.send(
            tokenlar,
            title=push_basligi(kimlik, dil),
            body=push_govdesi(kimlik, dil, params),
            data=dict(data or {}),
        )
        # FCM'in KALICI gecersiz dedigi token'lar -> budanacak. `getattr`
        # savunmasi: noop/eski saglayici None ya da alansiz sonuc dondurebilir.
        gecersiz.extend(getattr(sonuc, "gecersiz", None) or [])
        # (P191 §2) TOKEN BASINA IZ. `token_sonuc` yoksa (eski saglayici)
        # toplam durumdan tek bir degere duseriz — satir KAYBOLMAZ.
        token_sonuc = getattr(sonuc, "token_sonuc", None) or {}
        for token in tokenlar:
            durum, hata = token_sonuc.get(
                token, (_TOPLAM_DURUM.get(getattr(sonuc, "status", ""), "basarisiz"), None)
            )
            c = cihazlar[token]
            satirlar.append(
                (kimlik, c.user_id, token[-6:], c.platform, provider.name, durum, hata)
            )
    logger.info(
        "PUSH sonuc: kimlik=%s tenant=%s saglayici=%s cihaz=%d | %s",
        kimlik, tenant_id, provider.name, len(cihazlar),
        {d: sum(1 for r in satirlar if r[5] == d) for d in {r[5] for r in satirlar}},
    )
    _teshis_yaz(tenant_id, satirlar)
    if gecersiz:
        _prune_device_tokens(tenant_id, gecersiz)


# (P181 Bölüm 10.3) KANAL TERCIHI (göç 0055): `bildirim_mobil = false` diyen
# kullanici FCM push ALMAZ (in-app bildirim yine yazilir — push EK gonderimdir).
# Tercih zaten `/me/bildirim-tercihleri` ile yonetiliyor; eksik olan gonderimin
# ONA UYMASIYDI.
_KANAL_KOSULU = " AND u.bildirim_mobil = true"


def _fetch_device_tokens(
    tenant_id: uuid.UUID, roles: Sequence[str]
) -> list[Cihaz]:
    """Hedef rollerdeki, MOBIL BILDIRIMI ACIK, aktif kullanicilarin aktif
    cihazlari: (token, DIL).

    Kendi kisa-omurlu app_rw baglantisini acar + tenant context set eder (RLS-safe);
    boylece hem sync (scheduler) hem async cagiran icin ayni kod calisir.
    """
    with psycopg.connect(settings.app_dsn, connect_timeout=10) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT set_config('app.current_tenant_id', %s, true)", (str(tenant_id),)
            )
            cur.execute(
                "SELECT d.fcm_token, d.dil, d.user_id, d.platform FROM user_device d "
                "JOIN app_user u ON u.id = d.user_id "
                "WHERE d.aktif = true AND u.is_active = true AND u.role::text = ANY(%s)"
                + _KANAL_KOSULU,
                (list(roles),),
            )
            return [Cihaz(r[0], r[1], r[2], r[3]) for r in cur.fetchall()]


def _fetch_device_tokens_for_users(
    tenant_id: uuid.UUID, user_ids: Sequence[uuid.UUID]
) -> list[Cihaz]:
    """Belirli, MOBIL BILDIRIMI ACIK, aktif kullanicilarin aktif cihazlari:
    (token, DIL) (RLS-safe).

    Rol yerine kisi hedefleme: orn. talep yaniti yalniz talebi acan sakine
    gider — tenant'taki diger sakinlere sizmaz.
    """
    with psycopg.connect(settings.app_dsn, connect_timeout=10) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT set_config('app.current_tenant_id', %s, true)", (str(tenant_id),)
            )
            cur.execute(
                "SELECT d.fcm_token, d.dil, d.user_id, d.platform FROM user_device d "
                "JOIN app_user u ON u.id = d.user_id "
                "WHERE d.aktif = true AND u.is_active = true "
                "AND u.id = ANY(%s::uuid[])" + _KANAL_KOSULU,
                ([str(u) for u in user_ids],),
            )
            return [Cihaz(r[0], r[1], r[2], r[3]) for r in cur.fetchall()]


def _teshis_yaz(tenant_id: uuid.UUID, satirlar: Sequence[tuple]) -> None:
    """(P191 §2) `push_gonderim`e deneme izini yazar.

    HATA YUTULUR: teshis kaydi yan-istir. Teshisin kendisi bildirimi
    dusurseydi, tesahis eklemek yeni bir ariza sinifi acmis olurdu.

    Satir bicimi: (kimlik, user_id, token_son6, platform, saglayici, durum,
    hata_kodu).
    """
    if not satirlar:
        return
    try:
        with psycopg.connect(settings.app_dsn, connect_timeout=10) as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT set_config('app.current_tenant_id', %s, true)",
                    (str(tenant_id),),
                )
                cur.executemany(
                    "INSERT INTO push_gonderim (tenant_id, kimlik, user_id, "
                    "token_son6, platform, saglayici, durum, hata_kodu) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
                    [(str(tenant_id), *r) for r in satirlar],
                )
    except Exception:
        logger.exception("push teshis kaydi yazilamadi (gonderimi etkilemez)")


def _hedef_yok_nedeni(
    tenant_id: uuid.UUID,
    roles: Sequence[str] | None,
    user_ids: Sequence[uuid.UUID] | None,
) -> tuple[int, int]:
    """Hedef bulunamadi — NEDEN? (bildirim_mobil KAPALI kisi, cihazsiz kisi).

    Operatorun ilk sorusu budur ve iki cevabin eylemi FARKLIDIR: tercih
    kapaliysa kullanici acar; cihaz yoksa uygulamaya giris/izin gerekir.
    """
    try:
        with psycopg.connect(settings.app_dsn, connect_timeout=10) as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT set_config('app.current_tenant_id', %s, true)",
                    (str(tenant_id),),
                )
                kosul = []
                params: list[object] = []
                if roles:
                    kosul.append("u.role::text = ANY(%s)")
                    params.append(list(roles))
                if user_ids:
                    kosul.append("u.id = ANY(%s::uuid[])")
                    params.append([str(u) for u in user_ids])
                if not kosul:
                    return (0, 0)
                cur.execute(
                    "SELECT "
                    " count(*) FILTER (WHERE u.bildirim_mobil = false AND EXISTS ("
                    "   SELECT 1 FROM user_device d WHERE d.user_id = u.id AND d.aktif)), "
                    " count(*) FILTER (WHERE NOT EXISTS ("
                    "   SELECT 1 FROM user_device d WHERE d.user_id = u.id AND d.aktif)) "
                    "FROM app_user u WHERE u.is_active = true AND ("
                    + " OR ".join(kosul)
                    + ")",
                    params,
                )
                r = cur.fetchone()
                return (int(r[0] or 0), int(r[1] or 0))
    except Exception:
        logger.exception("push hedef teshisi okunamadi")
        return (0, 0)


def _prune_device_tokens(tenant_id: uuid.UUID, tokens: Sequence[str]) -> None:
    """FCM'in KALICI gecersiz dedigi cihaz token'larini pasiflestir (RLS-safe).

    Silmek yerine `aktif = false`: /devices kaydinin gecmisi korunur ve ayni
    token yeniden kaydedilirse upsert calisir (bkz. me.py). Budama, olu
    cihazlara sonsuza dek push denemesini onler. Hata YUTULUR: budama
    yan-istir, asil bildirim akisini (ve cagirani) dusurmemeli.
    """
    if not tokens:
        return
    try:
        with psycopg.connect(settings.app_dsn, connect_timeout=10) as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT set_config('app.current_tenant_id', %s, true)", (str(tenant_id),)
                )
                cur.execute(
                    "UPDATE user_device SET aktif = false "
                    "WHERE aktif = true AND fcm_token = ANY(%s)",
                    (list(tokens),),
                )
    except Exception:
        logger.exception("cihaz token budama basarisiz (push akisi etkilenmez)")


def notify_missed_tour(
    *,
    conn,
    tenant_id: uuid.UUID,
    plan_id: uuid.UUID,
    window_id: uuid.UUID,
    pencere_baslangic: datetime,
    pencere_bitis: datetime,
    missing_checkpoints: list[uuid.UUID],
    plan_adi: str | None = None,
) -> None:
    """Kacirilan tur icin kalici notification yaz (idempotent) + log + push.

    KAYIT METIN DEGIL KIMLIK TASIR (tur 16): `mesaj_kimlik` + `mesaj_veri`.
    Cumleyi kayda dondurmak, ilk yazan kullanicinin dilini kalici hale
    getirirdi; in-app liste metni OKUMA aninda istegin dilinde uretir.
    `mesaj` DEPRECATED olarak (NOT NULL kolon) ayni yapisal veriden uretilir.
    """
    veri = {"plan": plan_adi or "-", "eksik": len(missing_checkpoints)}
    # Eski kolon: guncellenmemis istemciler icin Turkce ozet (bkz. 0008).
    mesaj = push_govdesi(_KACIRILAN_TUR, VARSAYILAN_DIL, veri)
    conn.execute(
        "INSERT INTO notification (tenant_id, tip, patrol_window_id, patrol_plan_id, "
        "mesaj, mesaj_kimlik, mesaj_veri) "
        "VALUES (%s, 'kacirilan_tur', %s, %s, %s, %s, %s::jsonb) "
        # KISMI indeks (0023): cikarim icin WHERE yuklemi de verilir.
        "ON CONFLICT (tenant_id, tip, patrol_window_id) "
        "WHERE tip <> 'gecikmis_okutma'::notification_tip DO NOTHING",
        (tenant_id, window_id, plan_id, mesaj, _KACIRILAN_TUR, json.dumps(veri)),
    )
    logger.warning(
        "MISSED_TOUR tenant=%s plan=%s window=%s missing=%s",
        tenant_id, plan_id, window_id, [str(c) for c in missing_checkpoints],
    )
    dispatch_external(
        _KACIRILAN_TUR,
        tenant_id=tenant_id,
        target_roles=_ALARM_ROLES,
        params=veri,
        data={"tip": _KACIRILAN_TUR, "patrol_window_id": str(window_id)},
    )


def notify_gecikmis_okutma(
    *,
    conn,
    tenant_id: uuid.UUID,
    plan_id: uuid.UUID,
    window_id: uuid.UUID,
    plan_adi: str | None,
    dakika: int,
    adim: int,
    gorevli_ids: Sequence[uuid.UUID],
) -> bool:
    """(P34) Pencere acik ama okutma gelmedi — TEKRARLI alarm.

    IDEMPOTENCY `dedup_key` ILEDIR, (tip, window) ile DEGIL: kacirilan tur
    icin pencere basina TEK kayit dogruydu, burada AMAC tekrar etmektir.
    Anahtara `adim` girer; boylece scheduler ayni dakikada iki kez kossa
    bile ayni adim iki bildirim uretmez.

    Donus: yeni bildirim yazildi mi (True) — cagiran sayaci buna gore artirir.
    """
    veri = {"plan": plan_adi or "-", "dakika": dakika}
    mesaj = push_govdesi(_GECIKMIS_OKUTMA, VARSAYILAN_DIL, veri)
    dedup = f"{_GECIKMIS_OKUTMA}:{window_id}:{adim}"
    cur = conn.execute(
        "INSERT INTO notification (tenant_id, tip, patrol_window_id, patrol_plan_id, "
        "dedup_key, mesaj, mesaj_kimlik, mesaj_veri) "
        "VALUES (%s, 'gecikmis_okutma', %s, %s, %s, %s, %s, %s::jsonb) "
        "ON CONFLICT (tenant_id, dedup_key) DO NOTHING",
        (tenant_id, window_id, plan_id, dedup, mesaj, _GECIKMIS_OKUTMA,
         json.dumps(veri)),
    )
    if cur.rowcount == 0:
        return False  # bu adim zaten bildirildi
    logger.warning(
        "LATE_PATROL tenant=%s plan=%s window=%s adim=%s dakika=%s",
        tenant_id, plan_id, window_id, adim, dakika,
    )
    data = {"tip": _GECIKMIS_OKUTMA, "patrol_window_id": str(window_id)}
    # (P181 Bölüm 10.3) TEK CAGRI — kisi + rol BIRLIKTE, token bazinda dedup.
    # GOREVLI (kisi olarak): alarmin muhatabi turu yapacak kisidir. YONETIM
    # (rol olarak): gorevli duymuyorsa devralabilsin. Gorevli AYNI ZAMANDA
    # yonetici ise ARTIK TEK push alir (eskiden iki ayri cagri iki bildirim
    # duyururdu).
    dispatch_external(
        _GECIKMIS_OKUTMA,
        tenant_id=tenant_id,
        target_user_ids=list(gorevli_ids) if gorevli_ids else None,
        target_roles=_GECIKME_ROLLERI,
        params=veri,
        data=data,
    )
    return True
