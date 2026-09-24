"""(P240 §4) PERIYODIK ENTEGRASYON SAGLIK KONTROLU — beat isi.

Her tesisin AKTIF entegrasyonlarina TCP baglantisi dener (HTTP istegi
GONDERMEZ — bkz. `entegrasyon_saglik` modul basligi) ve durumu yazar.

===========================================================================
KOPUSTA BIR KEZ BILDIRIM
===========================================================================
`kopus_bildirildi_at` damgasi olmadan bu gorev, kopuk bir entegrasyon
icin GUNDE 96 bildirim gonderirdi (15 dakikada bir). Damga bir kopus
OLAYINI isaretler; baglanti geri gelince temizlenir ve bir sonraki kopus
yeniden bildirilir.

===========================================================================
PASIF ENTEGRASYON KONTROL EDILMEZ
===========================================================================
`aktif=false` olan bir entegrasyon bilincli olarak kapatilmistir;
"kopuk" demek, kullanicinin kendi kararini hata gibi gostermek olurdu.
"""
from __future__ import annotations

import datetime as dt
import logging
import uuid

import psycopg

from .config import settings
from .entegrasyon_saglik import baglanti_dene, simdi
from .push_metinleri import push_govdesi
from .scheduler.notify import dispatch_external

logger = logging.getLogger(__name__)

#: Bildirim alan roller — entegrasyonu yonetenler.
BILDIRIM_ROLLERI: tuple[str, ...] = ("admin", "yonetici")


def _tenantlar(owner_dsn: str) -> list[uuid.UUID]:
    with psycopg.connect(owner_dsn, autocommit=True, connect_timeout=10) as conn:
        return [r[0] for r in conn.execute("SELECT id FROM tenant").fetchall()]


def tum_tenantlar_icin(
    *, owner_dsn: str | None = None, app_dsn: str | None = None
) -> dict:
    """Donus: {"kontrol": n, "kopuk": m, "bildirim": k}."""
    owner_dsn = owner_dsn or settings.owner_dsn
    app_dsn = app_dsn or settings.app_dsn
    ozet = {"kontrol": 0, "kopuk": 0, "bildirim": 0}
    an = simdi()
    bekleyen: list[tuple] = []

    with psycopg.connect(app_dsn, connect_timeout=10) as conn:
        for tenant_id in _tenantlar(owner_dsn):
            with conn.transaction():
                conn.execute(
                    "SELECT set_config('app.current_tenant_id', %s, true)",
                    (str(tenant_id),),
                )
                satirlar = conn.execute(
                    "SELECT id, ad, endpoint_url, saglik, kopus_bildirildi_at "
                    "FROM integration WHERE aktif = true"
                ).fetchall()
                for ent_id, ad, url, onceki, bildirildi in satirlar:
                    sonuc = baglanti_dene(url)
                    ozet["kontrol"] += 1
                    if sonuc.bagli:
                        conn.execute(
                            "UPDATE integration SET saglik = 'bagli', "
                            "son_kontrol_at = %s, son_basarili_at = %s, "
                            "son_hata_kod = NULL, son_hata_ayrinti = NULL, "
                            "kopus_bildirildi_at = NULL WHERE id = %s",
                            (an, an, ent_id),
                        )
                        continue

                    ozet["kopuk"] += 1
                    conn.execute(
                        "UPDATE integration SET saglik = 'hata', "
                        "son_kontrol_at = %s, son_hata_kod = %s, "
                        "son_hata_ayrinti = %s WHERE id = %s",
                        (an, sonuc.hata_kod, sonuc.ayrinti, ent_id),
                    )
                    if bildirildi is not None:
                        continue  # bu kopus ZATEN bildirildi

                    veri = {"ad": ad or ""}
                    conn.execute(
                        "UPDATE integration SET kopus_bildirildi_at = %s "
                        "WHERE id = %s",
                        (an, ent_id),
                    )
                    # TEK SATIR, `user_id = NULL` — YONETIM ALARMI.
                    #
                    # Ilk yazimda her yoneticiye AYRI satir yazildi ve
                    # hicbiri GORUNMEDI: `routers/notifications._kapsam`
                    # yonetim rollerine YALNIZ `user_id IS NULL`
                    # satirlarini gosterir (kisiye ozel akis sakinindir).
                    # Yani kayit yaziliyordu ama kimse goremiyordu —
                    # test bunu yakaladi.
                    #
                    # Model de bunu soyluyor: entegrasyon kopmasi
                    # KISISEL bir olay degil, "kacirilan tur" gibi
                    # TESISE ait bir alarmdir.
                    conn.execute(
                        "INSERT INTO notification "
                        "(tenant_id, user_id, tip, mesaj, mesaj_kimlik, "
                        " mesaj_veri) "
                        "VALUES (%s, NULL, 'entegrasyon_koptu', %s, "
                        "        'entegrasyon_koptu', %s::jsonb)",
                        (
                            tenant_id,
                            push_govdesi("entegrasyon_koptu", "tr", veri),
                            _json(veri),
                        ),
                    )
                    # PUSH ROL UZERINDEN: kisi listesi burada cozulmez —
                    # rol degisirse liste de degismeli.
                    dispatch_external(
                        "entegrasyon_koptu",
                        tenant_id=tenant_id,
                        target_roles=list(BILDIRIM_ROLLERI),
                        params=veri,
                        data={"tip": "entegrasyon_koptu",
                              "integration_id": str(ent_id)},
                    )
                    ozet["bildirim"] += 1

                # (E2E 2026-09) DIYAFON + AKILLI EV KOPRUSU DA IZLENIR —
                # once TOPLANIR, sonra hepsi BIRLIKTE yoklanir (asagida).
                bekleyen.extend(
                    (tenant_id, tablo, anahtar, satir)
                    for tablo, anahtar, sorgu in _CIHAZ_TABLOLARI
                    for satir in conn.execute(sorgu).fetchall()
                )

        # PARALEL YOKLAMA: SIP OPTIONS'a yanit vermeyen bir panel 3 sn
        # bekletir; yuz cihazi sirayla yoklamak beat isini dakikalarca
        # surdururdu. Yoklama DB baglantisi disinda, sonuclar tenant
        # baglaminda yazilir.
        sonuclar = _paralel_yokla(bekleyen)
        tenant_basina: dict[uuid.UUID, list] = {}
        for (tid, tablo, anahtar, satir), sonuc in zip(bekleyen, sonuclar):
            tenant_basina.setdefault(tid, []).append((tablo, anahtar, satir, sonuc))
        for tid, kayitlar in tenant_basina.items():
            with conn.transaction():
                conn.execute(
                    "SELECT set_config('app.current_tenant_id', %s, true)",
                    (str(tid),),
                )
                for tablo, anahtar, satir, sonuc in kayitlar:
                    _cihaz_sonucu_yaz(conn, tid, tablo, anahtar, satir, sonuc, an, ozet)
    return ozet


#: (E2E 2026-09) Izlenen saha cihazi tablolari.
#:
#: OLCULEN KUSUR (TESIS-15): is yalniz `integration` tablosunu tariyordu.
#: Diyafon ve kopru ayni saglik sutunlarini (`saglik`, `kopus_bildirildi_at`)
#: P240'tan beri TASIYORDU ama onlari dolduran tek sey yoneticinin elle
#: bastigi "Test et" dugmesiydi — yani P240'in kendi gerekcesi ("aksam
#: kopan diyafon sabah fark edilir") bu iki cihaz icin hic karsilanmiyordu.
#:
#: TETIKLEMEZ: diyafonda SIP OPTIONS / TCP, kopruda `GET /api/` —
#: saglayicilarin `saglik()` yolu, zil calmaz, kapi acmaz (P240 §4).
#: MQTT koprusu ATLANIR: bu surumde uygulanmadi ve her kosumda
#: "yapilandirma eksik" diye alarm uretirdi.
_CIHAZ_TABLOLARI: tuple[tuple[str, str, str], ...] = (
    # (tablo, kimlik anahtari, sorgu)
    (
        "diyafon", "diyafon_id",
        "SELECT id, ad, kopus_bildirildi_at, yontem, host, port, kullanici, "
        "sifre_enc, hedef, zil_yolu, kapi_yolu FROM diyafon WHERE aktif = true",
    ),
    (
        "akilli_ev_kopru", "kopru_id",
        "SELECT id, ad, kopus_bildirildi_at, tur, host, port, token_enc "
        "FROM akilli_ev_kopru WHERE aktif = true AND tur::text <> 'mqtt'",
    ),
)


def _saglayici_uret(tablo: str, satir) -> object:
    from types import SimpleNamespace

    if tablo == "diyafon":
        from .diyafon import saglayici

        (_, _, _, yontem, host, port, kullanici, sifre_enc, hedef,
         zil, kapi) = satir
        return saglayici(SimpleNamespace(
            yontem=str(yontem), host=host, port=port, kullanici=kullanici,
            sifre_enc=sifre_enc, hedef=hedef, zil_yolu=zil, kapi_yolu=kapi,
        ))
    from .akilli_ev import kopru

    _, _, _, tur, host, port, token_enc = satir
    return kopru(SimpleNamespace(
        tur=str(tur), host=host, port=port, token_enc=token_enc,
    ))


def _tek_yokla(is_: tuple) -> tuple[bool, str | None, str | None]:
    _, tablo, _, satir = is_
    try:
        sonuc = _saglayici_uret(tablo, satir).saglik()
        return sonuc.ok, sonuc.kod, sonuc.ayrinti
    except Exception as exc:  # sifre cozulemedi vb. — tek cihaz isi dusurmez
        logger.warning("saha cihazi saglik hatasi %s %s: %s",
                       tablo, satir[0], type(exc).__name__)
        return False, None, type(exc).__name__


def _paralel_yokla(isler: list[tuple]) -> list[tuple[bool, str | None, str | None]]:
    if not isler:
        return []
    from concurrent.futures import ThreadPoolExecutor

    with ThreadPoolExecutor(max_workers=min(32, len(isler))) as havuz:
        return list(havuz.map(_tek_yokla, isler))


def _cihaz_sonucu_yaz(
    conn, tenant_id: uuid.UUID, tablo: str, anahtar: str, satir,
    sonuc: tuple[bool, str | None, str | None], an: dt.datetime, ozet: dict,
) -> None:
    """Diyafon + kopru: integration dongusuyle AYNI damga ve bildirim kurali."""
    cid, ad, bildirildi = satir[0], satir[1], satir[2]
    bagli, kod, ayrinti = sonuc
    ozet["kontrol"] += 1
    if bagli:
        conn.execute(
            f"UPDATE {tablo} SET saglik = 'bagli', son_kontrol_at = %s, "
            "son_basarili_at = %s, son_hata_kod = NULL, "
            "son_hata_ayrinti = NULL, kopus_bildirildi_at = NULL "
            "WHERE id = %s",
            (an, an, cid),
        )
        return
    ozet["kopuk"] += 1
    conn.execute(
        f"UPDATE {tablo} SET saglik = 'hata', son_kontrol_at = %s, "
        "son_hata_kod = %s, son_hata_ayrinti = %s WHERE id = %s",
        (an, kod, (ayrinti or "")[:200] or None, cid),
    )
    if bildirildi is not None:
        return  # bu kopus ZATEN bildirildi
    conn.execute(
        f"UPDATE {tablo} SET kopus_bildirildi_at = %s WHERE id = %s",
        (an, cid),
    )
    veri = {"ad": ad or ""}
    # Ayni tip (`entegrasyon_koptu`) ve ayni `user_id = NULL` yonetim
    # satiri: yonetici icin "bir baglanti koptu" TEK kavramdir; ayri tip
    # acmak 7 dilde ikinci metin + mobil/web yonlendirme kaydi demekti ve
    # bilgi eklemezdi.
    conn.execute(
        "INSERT INTO notification "
        "(tenant_id, user_id, tip, mesaj, mesaj_kimlik, mesaj_veri) "
        "VALUES (%s, NULL, 'entegrasyon_koptu', %s, "
        "        'entegrasyon_koptu', %s::jsonb)",
        (tenant_id, push_govdesi("entegrasyon_koptu", "tr", veri), _json(veri)),
    )
    dispatch_external(
        "entegrasyon_koptu",
        tenant_id=tenant_id,
        target_roles=list(BILDIRIM_ROLLERI),
        params=veri,
        data={"tip": "entegrasyon_koptu", anahtar: str(cid)},
    )
    ozet["bildirim"] += 1


def _json(veri: dict) -> str:
    import json

    return json.dumps(veri)


def _simdi_utc() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)
