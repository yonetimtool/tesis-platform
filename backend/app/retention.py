"""KVKK saklama & imha motoru (WP2) — gecelik retention/imha.

Sync psycopg (scheduler/service.py deseni). Tenant enumerasyonu OWNER ile (RLS
bootstrap); tenant-kapsamli DELETE/ANONYMIZE app_rw + set_config('app.current_
tenant_id') ile (RLS izolasyonu). audit_log purge + sistem `erasure_run` kaydi
OWNER ile yazilir (append-only: app_rw audit satirini SILEMEZ; ayrica tenant-siz
sistem kaydi RLS'i bypass gerektirir).

Idempotent + partili (batch): esik gecen satirlar tekrar calistiginda zaten
gitmis olur. Foto (kargo) once MinIO'dan silinir, sonra DB satiri — depo/DB
tutarli kalir (MinIO erisilemezse o tenant'in kargo satirlari BU GECE silinmez).

meta/erasure_run: YALNIZ SAYILAR — kisisel veri yok.
"""
from __future__ import annotations

import json

import psycopg

from . import storage
from .config import settings


def _list_tenant_ids(owner_dsn: str) -> list[str]:
    """Tum tenant id'leri — OWNER ile (RLS bootstrap, salt-okuma)."""
    with psycopg.connect(owner_dsn, autocommit=True, connect_timeout=10) as conn:
        return [str(r[0]) for r in conn.execute("SELECT id FROM tenant").fetchall()]


def run_retention() -> dict:
    """Tum tenant'larda saklama sinirini gecen kisisel veriyi siler/anonimlestirir.
    Sonuc: sinif basina islenen satir sayilari (denetime yazilir)."""
    owner_dsn = settings.owner_dsn
    app_dsn = settings.app_dsn
    m = settings  # kisayol

    totals = {
        "visitors": 0,
        "kargo": 0,
        "kargo_photos": 0,
        "reservations": 0,
        "tickets_anonymized": 0,
        "talep_photos": 0,
        "dokuman_objeleri": 0,
        "dokumanlar": 0,
        "rapor_dosyalari": 0,
        "rapor_isleri": 0,
        "audit_purged": 0,
    }

    tenant_ids = _list_tenant_ids(owner_dsn)

    # 1) Tenant-kapsamli veri (app_rw + RLS).
    with psycopg.connect(app_dsn, connect_timeout=10) as conn:
        for tid in tenant_ids:
            with conn.transaction():
                conn.execute(
                    "SELECT set_config('app.current_tenant_id', %s, true)", (tid,)
                )

                # Ziyaretci LOG'u (24 ay) — foto yok, dogrudan sil.
                totals["visitors"] += conn.execute(
                    "DELETE FROM visitor "
                    "WHERE created_at < now() - make_interval(months => %s)",
                    (m.retention_visitors_months,),
                ).rowcount

                # Kargo (24 ay): once foto anahtarlarini MinIO'dan sil, sonra satir.
                keys = [
                    row[0]
                    for row in conn.execute(
                        "SELECT foto_key FROM kargo "
                        "WHERE foto_key IS NOT NULL "
                        "AND created_at < now() - make_interval(months => %s)",
                        (m.retention_kargo_months,),
                    ).fetchall()
                ]
                photos_ok = True
                if keys:
                    try:
                        totals["kargo_photos"] += storage.delete_objects(keys)
                    except Exception:
                        # MinIO erisilemedi -> satirlari BU GECE silme (sonraki gece
                        # tekrar denenir; foto asla DB'siz ortada kalmaz).
                        photos_ok = False
                if photos_ok:
                    totals["kargo"] += conn.execute(
                        "DELETE FROM kargo "
                        "WHERE created_at < now() - make_interval(months => %s)",
                        (m.retention_kargo_months,),
                    ).rowcount

                # Rezervasyon (gecmis 24 ay) — tamamlanmis/iptal fark etmez, gecmis.
                totals["reservations"] += conn.execute(
                    "DELETE FROM rezervasyon "
                    "WHERE tarih < (current_date - make_interval(months => %s))",
                    (m.retention_reservations_months,),
                ).rowcount

                # (P141.6) Talep FOTOGRAFLARI (36 ay) — metinle AYNI pencerede.
                #
                # Onceki surumde bu tablo ATLANMISTI: metin arsivleniyor ama
                # fotograflar SURESIZ kaliyordu. Sessiz bir eksikti — Play
                # veri guvenligi envanterinde bulundu (bkz.
                # docs/play-console-veri-guvenligi.md).
                #
                # AYNI PENCERE (36 ay) BILINCLI: metin arsivlenip fotograf
                # kalsaydi, "arsivlendi" yazan bir talebin gorseli hala
                # olayi anlatiyor olurdu — arsivleme yarim kalirdi.
                #
                # Kargo desenin AYNISI: once MinIO, sonra satir. MinIO
                # erisilemezse satirlar BU GECE silinmez ve sonraki gece
                # tekrar denenir — foto asla DB kaydi olmadan ortada kalmaz.
                talep_keys = [
                    row[0]
                    for row in conn.execute(
                        "SELECT p.foto_key FROM complaint_photo p "
                        "JOIN complaint c ON c.id = p.complaint_id "
                        "WHERE p.foto_key IS NOT NULL "
                        "AND c.durum IN ('cozuldu', 'reddedildi', 'geri_alindi') "
                        "AND c.updated_at < now() - make_interval(months => %s)",
                        (m.retention_tickets_months,),
                    ).fetchall()
                ]
                talep_foto_ok = True
                if talep_keys:
                    try:
                        totals["talep_photos"] += storage.delete_objects(talep_keys)
                    except Exception:
                        talep_foto_ok = False
                if talep_foto_ok:
                    conn.execute(
                        "DELETE FROM complaint_photo p "
                        "USING complaint c "
                        "WHERE c.id = p.complaint_id "
                        "AND c.durum IN ('cozuldu', 'reddedildi', 'geri_alindi') "
                        "AND c.updated_at < now() - make_interval(months => %s)",
                        (m.retention_tickets_months,),
                    )

                # Talep/sikayet (cozuldu/reddedildi, 36 ay) -> ANONIMLESTIR (satir
                # is-emri/defter butunlugu icin kalir; serbest metin arsivlenir).
                totals["tickets_anonymized"] += conn.execute(
                    "UPDATE complaint "
                    "SET baslik = '(arşivlendi)', mesaj = '(arşivlendi)', "
                    "    updated_at = now() "
                    "WHERE durum IN ('cozuldu', 'reddedildi') "
                    "AND updated_at < now() - make_interval(months => %s) "
                    "AND mesaj <> '(arşivlendi)'",
                    (m.retention_tickets_months,),
                ).rowcount

                # (P167 §6.3) SILINMIS DOKUMANLAR — GUN cinsinden.
                #
                # SILINEN SUPURULUR, ARSIV DEGIL. Yonetim plani, butce ve
                # genel kurul tutanagi KISISEL VERI DEGIL tesisin kendi
                # arsividir; yasa gore silinmesi gereken bir sey degildir
                # ve yasla silmek GERI ALINAMAZ bir kayip yaratirdi.
                # Burada supurulen sey yalnizca KULLANICININ SILDIGI
                # kaydin artigi: onceki tasarimda satir siliniyor ama
                # MinIO objesi sonsuza kadar depoda kaliyordu.
                #
                # AY DEGIL GUN: bu bir saklama siniri degil, "yanlislikla
                # sildim" penceresi.
                #
                # Kargo/talep fotografiyla AYNI DESEN: once depo, sonra
                # satir. Depo erisilemezse satirlar BU GECE silinmez ve
                # obje asla kayitsiz kalmaz.
                dok_keys = [
                    row[0]
                    for row in conn.execute(
                        "SELECT obje_anahtari FROM tenant_dokuman "
                        "WHERE silindi_at IS NOT NULL "
                        "AND silindi_at < now() - make_interval(days => %s)",
                        (m.retention_dokuman_grace_days,),
                    ).fetchall()
                ]
                dok_ok = True
                if dok_keys:
                    try:
                        totals["dokuman_objeleri"] += storage.delete_objects(dok_keys)
                    except Exception:
                        dok_ok = False
                if dok_ok:
                    totals["dokumanlar"] += conn.execute(
                        "DELETE FROM tenant_dokuman "
                        "WHERE silindi_at IS NOT NULL "
                        "AND silindi_at < now() - make_interval(days => %s)",
                        (m.retention_dokuman_grace_days,),
                    ).rowcount

                # (P167 §5) URETILMIS RAPOR CIKTILARI — GUN cinsinden.
                #
                # NEDEN BURADA: goc 0059 `ix_rapor_isi_sahip` indeksini
                # kurdu ama TEMIZLIK ISINI KURMADI ve bunu tur raporunda
                # yazili birakmistim. Dokumanlarin sizintisini kapatip
                # bunu birakmak TUTARSIZ olurdu: iki yol da MinIO'ya
                # yaziyor, ikisi de erisilemez obje birakiyordu.
                #
                # ARSIV DEGIL TURETME: rapor ciktisi kaybolursa AYNISI
                # yeniden uretilebilir (parametre kayitta duruyordu ama
                # kayit da gidiyor — cunku kaydin tek isi "hazir mi,
                # indirebilir miyim" sorusunu yanitlamakti).
                #
                # SATIR DA SILINIR, YALNIZ DOSYA DEGIL: `ck_rapor_isi_hazir`
                # kisiti "durum=hazir iken dosya_key NOT NULL" diyor.
                # Dosyayi silip satiri birakmak o kisiti ihlal ederdi;
                # durumu degistirmek ise kullaniciya "hazirdi, artik
                # degil" diyen anlamsiz bir satir birakirdi.
                #
                # BEKLEYEN/URETILEN ISLERE DOKUNULMAZ: yalnizca
                # `created_at` esigi gecmis olanlar taranir; suresi
                # dolmamis bir isin dosyasini silmek, kullanicinin tam o
                # an indirdigi seyi elinden almak olurdu.
                rapor_keys = [
                    row[0]
                    for row in conn.execute(
                        "SELECT dosya_key FROM rapor_isi "
                        "WHERE dosya_key IS NOT NULL "
                        "AND created_at < now() - make_interval(days => %s)",
                        (m.retention_rapor_isi_days,),
                    ).fetchall()
                ]
                rapor_ok = True
                if rapor_keys:
                    try:
                        totals["rapor_dosyalari"] += storage.delete_objects(rapor_keys)
                    except Exception:
                        # Kargo/talep/dokuman deseninin AYNISI: depo
                        # erisilemezse satirlar BU GECE silinmez ve obje
                        # asla kayitsiz kalmaz.
                        rapor_ok = False
                if rapor_ok:
                    totals["rapor_isleri"] += conn.execute(
                        "DELETE FROM rapor_isi "
                        "WHERE created_at < now() - make_interval(days => %s)",
                        (m.retention_rapor_isi_days,),
                    ).rowcount

    # 2) audit_log purge (24 ay) + sistem erasure_run kaydi — OWNER ile.
    #    (app_rw audit_log'da DELETE yapamaz; tenant-siz kayit RLS bypass ister.)
    with psycopg.connect(owner_dsn, autocommit=True, connect_timeout=10) as conn:
        # (P191 §2) push_gonderim — ISLETIM TELEMETRISI, 30 gun.
        #
        # Denetim kaydi DEGILDIR: "bildirim gelmedi" sorusu gunler icinde
        # sorulur, aylar sonra degil; sinirsiz buyumek, toplu duyuru basina
        # yuzlerce satir yazan bir tabloyu kalici yuke cevirirdi.
        #
        # OWNER BAGLANTISI: tablo RLS FORCE tasiyor ve tenant baglami
        # OLMAYAN bir app_rw silmesi HICBIR SATIR silmez (politika NULL'a
        # duser) — sessizce hicbir sey yapmayan bir temizlik olurdu.
        totals["push_gonderim"] = conn.execute(
            "DELETE FROM push_gonderim WHERE created_at < now() - interval '30 days'"
        ).rowcount
        totals["audit_purged"] = conn.execute(
            "DELETE FROM audit_log WHERE ts < now() - make_interval(months => %s)",
            (m.retention_audit_months,),
        ).rowcount
        conn.execute(
            "INSERT INTO audit_log "
            "(tenant_id, actor_user_id, actor_rol, action, resource_type, meta) "
            "VALUES (NULL, NULL, 'system', 'erasure_run', 'retention', %s::jsonb)",
            (json.dumps(totals),),
        )

    return totals
