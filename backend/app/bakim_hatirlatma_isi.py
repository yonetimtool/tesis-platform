"""(P241 §1) PERIYODIK BAKIM HATIRLATMASI — beat isi (gunde bir).

===========================================================================
UC KADEME, UC DAMGA
===========================================================================
`yaklasti` / `bugun` / `gecikti` ayri ayri damgalanir. TEK damga
olsaydi, "yaklasiyor" bildirimi gonderilen bir ekipman icin "bugun"
bildirimi HIC gitmezdi — yani en onemli gun sessiz gecerdi.

===========================================================================
GECIKMEDE HER GUN DEGIL, HAFTADA BIR
===========================================================================
Istek "gecikti: her gun mu hatirlatsin? bildirim yorgunlugunu gozet"
diye soruyor. Yanit: HAYIR.

Gunluk hatirlatma, unutulmus bir yangin tupu icin ayda 30 bildirim
demektir. Sonuc unutulmus tupun bakilmasi degil, kullanicinin bildirimi
KAPATMASIDIR — ve kapatilan kanal panik alarmini da tasiyor. Haftalik
tekrar (`GECIKME_TEKRAR_GUN`) hatirlatmaya yetiyor, kapatmaya itmiyor.

===========================================================================
GUNDE BIR KOSAR — VE BU YETER
===========================================================================
Bakim tarihleri GUN cozunurluklu. 15 dakikada bir kosmak ayni gun icinde
hicbir yeni bilgi uretmezdi.
"""
from __future__ import annotations

import datetime as dt
import json
import logging
import uuid

import psycopg

from .bakim import GECIKME_TEKRAR_GUN, VARSAYILAN_UYARI_GUN
from .config import settings
from .push_metinleri import push_govdesi
from .scheduler.notify import dispatch_external

logger = logging.getLogger(__name__)

#: Bildirim alan roller.
#:
#: YONETIM KESIN (istek boyle diyor). SAHA DA ALIR ama yalniz `bugun`
#: kademesini: kapida duran guvenlik gorevlisi "bugun asansor firmasi
#: gelecek" bilgisini KULLANIR (gelen kisiyi iceri alir). "3 hafta sonra
#: bakim var" bilgisi ise onun isine yaramaz, yalniz bildirim kutusunu
#: doldurur. SAKIN HIC ALMAZ: bu bir isletme kaydidir.
YONETIM_ROLLERI: tuple[str, ...] = ("admin", "yonetici")
BUGUN_ROLLERI: tuple[str, ...] = (
    "admin", "yonetici", "guvenlik_amiri", "security", "tesis_gorevlisi",
)

KADEME_TIP = {
    "yaklasti": "bakim_yaklasti",
    "bugun": "bakim_bugun",
    "gecikti": "bakim_gecikti",
}
KADEME_DAMGA = {
    "yaklasti": "yaklasti_bildirildi_at",
    "bugun": "bugun_bildirildi_at",
    "gecikti": "gecikme_bildirildi_at",
}


def _tenantlar(owner_dsn: str) -> list[tuple[uuid.UUID, int]]:
    with psycopg.connect(owner_dsn, autocommit=True, connect_timeout=10) as conn:
        return [
            (r[0], int(r[1]) if r[1] is not None else VARSAYILAN_UYARI_GUN)
            for r in conn.execute(
                "SELECT id, bakim_uyari_gun FROM tenant"
            ).fetchall()
        ]


def _kademe(sonraki: dt.date, uyari_gun: int, bugun: dt.date) -> str | None:
    if sonraki < bugun:
        return "gecikti"
    if sonraki == bugun:
        return "bugun"
    if (sonraki - bugun).days <= uyari_gun:
        return "yaklasti"
    return None


def _gonderilsin_mi(kademe: str, damga: dt.datetime | None, an: dt.datetime) -> bool:
    """Damgasiz kademe her zaman gonderilir; GECIKME haftada bir tekrarlar."""
    if damga is None:
        return True
    if kademe != "gecikti":
        return False
    return (an - damga).days >= GECIKME_TEKRAR_GUN


def tum_tenantlar_icin(
    *,
    owner_dsn: str | None = None,
    app_dsn: str | None = None,
    bugun: dt.date | None = None,
) -> dict:
    """Donus: {"taranan": n, "bildirim": k, "kademeler": {...}}."""
    owner_dsn = owner_dsn or settings.owner_dsn
    app_dsn = app_dsn or settings.app_dsn
    an = dt.datetime.now(dt.timezone.utc)
    g = bugun or an.date()
    ozet = {"taranan": 0, "bildirim": 0,
            "kademeler": {"yaklasti": 0, "bugun": 0, "gecikti": 0}}

    with psycopg.connect(app_dsn, connect_timeout=10) as conn:
        for tenant_id, tesis_uyari in _tenantlar(owner_dsn):
            with conn.transaction():
                conn.execute(
                    "SELECT set_config('app.current_tenant_id', %s, true)",
                    (str(tenant_id),),
                )
                satirlar = conn.execute(
                    "SELECT id, ad, sonraki_bakim, uyari_gun, yasal, "
                    "       yaklasti_bildirildi_at, bugun_bildirildi_at, "
                    "       gecikme_bildirildi_at "
                    "FROM bakim_ekipmani WHERE aktif = true"
                ).fetchall()
                for (
                    eid, ad, sonraki, uyari, yasal,
                    d_yaklasti, d_bugun, d_gecikti,
                ) in satirlar:
                    ozet["taranan"] += 1
                    esik = int(uyari) if uyari is not None else tesis_uyari
                    kademe = _kademe(sonraki, esik, g)
                    if kademe is None:
                        continue
                    damga = {
                        "yaklasti": d_yaklasti,
                        "bugun": d_bugun,
                        "gecikti": d_gecikti,
                    }[kademe]
                    if not _gonderilsin_mi(kademe, damga, an):
                        continue

                    tip = KADEME_TIP[kademe]
                    gun = abs((sonraki - g).days)
                    veri = {"ekipman": ad or "", "gun": str(gun)}
                    conn.execute(
                        f"UPDATE bakim_ekipmani SET {KADEME_DAMGA[kademe]} = %s "
                        "WHERE id = %s",
                        (an, eid),
                    )
                    # TEK SATIR, `user_id = NULL` — TESIS ALARMI.
                    # `notifications._kapsam` yonetim rollerine yalniz
                    # tenant-kapsamli satirlari gosterir (P240 §4'te
                    # olculmustu); kisi basina satir GORUNMEZ olurdu.
                    conn.execute(
                        "INSERT INTO notification "
                        "(tenant_id, user_id, tip, mesaj, mesaj_kimlik, "
                        " mesaj_veri) "
                        "VALUES (%s, NULL, %s, %s, %s, %s::jsonb)",
                        (
                            tenant_id, tip,
                            push_govdesi(tip, "tr", veri), tip,
                            json.dumps(veri),
                        ),
                    )
                    # (E2E 2026-09) "BUGUN" SAHAYA KISI SATIRIYLA DA YAZILIR.
                    #
                    # Olculen (TESIS-15): `user_id = NULL` satirini
                    # `notifications._kapsam` yalniz `_YONETIM_GOZU`
                    # rollerine gosteriyor; `tesis_gorevlisi` orada YOK.
                    # Push'u kaciran gorevli "bugun asansor firmasi gelecek"
                    # bilgisini listede HIC bulamiyordu — oysa bu kademenin
                    # saha icin var olma sebebi tam olarak o. Gorevliye
                    # KENDI satiri yazilir (kisi akisini gorur).
                    #
                    # `security`/`guvenlik_amiri` NULL satiri zaten goruyor.
                    # Onlarin "yaklasti/gecikti"yi de gormesi (karar disi)
                    # `notifications._kapsam`in tip suzmemesinden geliyor;
                    # o dosya bu turun kapsami disinda — raporda not edildi.
                    if kademe == "bugun":
                        gorevliler = conn.execute(
                            "SELECT id FROM app_user WHERE role = "
                            "'tesis_gorevlisi' AND is_active = true"
                        ).fetchall()
                        for (uid,) in gorevliler:
                            conn.execute(
                                "INSERT INTO notification "
                                "(tenant_id, user_id, tip, mesaj, "
                                " mesaj_kimlik, mesaj_veri) "
                                "VALUES (%s, %s, %s, %s, %s, %s::jsonb)",
                                (
                                    tenant_id, uid, tip,
                                    push_govdesi(tip, "tr", veri), tip,
                                    json.dumps(veri),
                                ),
                            )
                    roller = (
                        BUGUN_ROLLERI if kademe == "bugun" else YONETIM_ROLLERI
                    )
                    dispatch_external(
                        tip,
                        tenant_id=tenant_id,
                        target_roles=list(roller),
                        params=veri,
                        data={"tip": tip, "ekipman_id": str(eid)},
                    )
                    ozet["bildirim"] += 1
                    ozet["kademeler"][kademe] += 1
    return ozet
