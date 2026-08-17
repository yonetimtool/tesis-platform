"""KVKK saklama & imha motoru (WP2) — retention task + sakin anonimlestirme.

Zaman "dondurma": satirlar owner_conn ile GERI TARIHLI (esik otesi) ve GUNCEL
olarak eklenir; run_retention() gercek now() - make_interval ile calisir, boylece
YALNIZ esigi gecenler islenir. run_retention app.retention'dan dogrudan cagrilir
(pytest api container'inda kosar; OWNER_DSN/APP_DSN env'de).
"""
from __future__ import annotations

import uuid

import pytest

from app.retention import run_retention


def _uid(owner_conn, tid, role):
    return owner_conn.execute(
        "SELECT id FROM app_user WHERE tenant_id=%s AND role=%s LIMIT 1", (str(tid), role)
    ).fetchone()[0]


def _exists(owner_conn, table, row_id):
    return owner_conn.execute(
        f"SELECT count(*) FROM {table} WHERE id=%s", (str(row_id),)
    ).fetchone()[0]


def test_retention_siler_ve_anonimlestirir_esik_hassas(world, owner_conn):
    tid = world["a"]
    admin_id = _uid(owner_conn, tid, "admin")
    resident_id = _uid(owner_conn, tid, "resident")

    unit_id = owner_conn.execute(
        "INSERT INTO unit (tenant_id, no, blok) VALUES (%s, %s, 'A') RETURNING id",
        (str(tid), f"RT-{uuid.uuid4().hex[:5]}"),
    ).fetchone()[0]

    old_visitor = uuid.uuid4()
    new_visitor = uuid.uuid4()
    for vid, age in ((old_visitor, "30 months"), (new_visitor, "1 month")):
        owner_conn.execute(
            "INSERT INTO visitor (id, tenant_id, unit_id, ziyaretci_ad, "
            "kaydeden_user_id, target_resident_user_id, created_at) "
            f"VALUES (%s, %s, %s, 'Ziyaretci', %s, %s, now() - interval '{age}')",
            (str(vid), str(tid), str(unit_id), str(admin_id), str(resident_id)),
        )

    # (P141.6) Talep FOTOGRAFLARI da 36 ayda silinir — metinle AYNI pencere.
    # Once bu tablo ATLANMISTI: metin arsivleniyor, fotograf suresiz
    # kaliyordu. Bu test o eksigin geri gelmesini engeller.
    # Cozulmus talep (36 ay otesi) -> anonimlestirilecek; guncel cozulmus KALIR.
    old_complaint = uuid.uuid4()
    new_complaint = uuid.uuid4()
    for cid, age in ((old_complaint, "40 months"), (new_complaint, "1 month")):
        owner_conn.execute(
            "INSERT INTO complaint (id, tenant_id, acan_user_id, baslik, mesaj, durum, "
            "created_at, updated_at) "
            f"VALUES (%s, %s, %s, 'Gizli Baslik', 'Gizli mesaj icerigi', 'cozuldu', "
            f"now() - interval '{age}', now() - interval '{age}')",
            (str(cid), str(tid), str(resident_id)),
        )

    # Her iki talebe de birer fotograf.
    for cid in (old_complaint, new_complaint):
        owner_conn.execute(
            "INSERT INTO complaint_photo (tenant_id, complaint_id, foto_key, sira) "
            "VALUES (%s, %s, %s, 1)",
            (str(tid), str(cid), f"{tid}/talep/{uuid.uuid4().hex}.jpg"),
        )

    # Eski denetim satiri (24 ay otesi) -> purge; guncel KALIR.
    old_audit = uuid.uuid4()
    owner_conn.execute(
        "INSERT INTO audit_log (id, tenant_id, action, ts) "
        "VALUES (%s, %s, 'login_ok', now() - interval '30 months')",
        (str(old_audit), str(tid)),
    )

    result = run_retention()

    # Ziyaretci: eski gitti, yeni kaldi (esik hassasiyeti).
    assert _exists(owner_conn, "visitor", old_visitor) == 0
    assert _exists(owner_conn, "visitor", new_visitor) == 1

    # Talep: eski anonimlestirildi (satir KALIR), yeni dokunulmadi.
    old_row = owner_conn.execute(
        "SELECT baslik, mesaj FROM complaint WHERE id=%s", (str(old_complaint),)
    ).fetchone()
    assert old_row == ("(arşivlendi)", "(arşivlendi)")
    new_row = owner_conn.execute(
        "SELECT baslik, mesaj FROM complaint WHERE id=%s", (str(new_complaint),)
    ).fetchone()
    assert new_row == ("Gizli Baslik", "Gizli mesaj icerigi")

    # (P141.6) FOTOGRAF DA GITMIS OLMALI: metni arsivleyip gorseli birakmak
    # arsivlemeyi yarim birakirdi — "(arşivlendi)" yazan bir talebin
    # fotografi hala olayi anlatirdi.
    def _foto(cid):
        return owner_conn.execute(
            "SELECT count(*) FROM complaint_photo WHERE complaint_id = %s",
            (str(cid),),
        ).fetchone()[0]

    assert _foto(old_complaint) == 0, "36 ayi gecen talebin fotografi kalmis"
    assert _foto(new_complaint) == 1, "guncel talebin fotografi SILINMEMELI"

    # Denetim: eski purge edildi + erasure_run sistem kaydi yazildi.
    assert _exists(owner_conn, "audit_log", old_audit) == 0
    er = owner_conn.execute(
        "SELECT count(*) FROM audit_log WHERE action='erasure_run' "
        "AND actor_rol='system' AND tenant_id IS NULL"
    ).fetchone()[0]
    assert er >= 1
    assert result["visitors"] >= 1 and result["tickets_anonymized"] >= 1


def test_retention_SILINMIS_dokumani_supurur_ARSIVE_DOKUNMAZ(world, owner_conn):
    """(P167 §6.3) Supurulen sey ARSIV DEGIL, SILINMIS OLANIN ARTIGI.

    =========================================================================
    NEDEN BU AYRIM ONEMLI
    =========================================================================
    Yonetim plani, butce ve genel kurul tutanagi KISISEL VERI DEGIL,
    tesisin KENDI ARSIVIDIR. KVKK'nin saklama sinirlamasi kisisel veri
    icindir; site arsivini YASLA silmek, mevzuatin istemedigi ve GERI
    ALINAMAZ bir kayip yaratirdi.

    Gercek eksik baskaydi: `DELETE /dokumanlar/{id}` kaydi siliyor ama
    MinIO objesini birakiyordu — ve artik hicbir uygulama yolundan
    erisilemedigi icin kimse fark etmiyordu.

    Bu test IKI YONLU: silinmis ve suresi dolmus olan GITMELI, canli olan
    ve HENUZ suresi dolmamis olan KALMALI. Tek yonlu olsaydi, "hepsini
    sil" diyen bir regresyon testten gecerdi.
    """
    tid = world["a"]
    admin_id = _uid(owner_conn, tid, "admin")

    canli, yeni_silinen, eski_silinen = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    # (id, silindi_at ifadesi)
    kayitlar = (
        (canli, "NULL"),
        (yeni_silinen, "now() - interval '2 days'"),
        (eski_silinen, "now() - interval '90 days'"),
    )
    for did, silindi in kayitlar:
        owner_conn.execute(
            "INSERT INTO tenant_dokuman (id, tenant_id, ad, obje_anahtari, "
            "yukleyen_user_id, silindi_at) "
            f"VALUES (%s, %s, 'Yonetim Plani', %s, %s, {silindi})",
            (str(did), str(tid), f"{tid}/dokuman/{uuid.uuid4().hex}.pdf", str(admin_id)),
        )

    run_retention()

    # ARSIV DURUYOR — silinmemis dokuman hicbir kosulda supurulmez.
    assert _exists(owner_conn, "tenant_dokuman", canli) == 1, (
        "canli arsiv dokumani silinmis — retention ARSIVE DOKUNMAMALI"
    )
    # GERI DONUS PENCERESI ISLIYOR: yeni silinen henuz durur.
    assert _exists(owner_conn, "tenant_dokuman", yeni_silinen) == 1, (
        "yanlislikla-sildim penceresi calismamis"
    )
    # SURESI DOLAN GITTI.
    assert _exists(owner_conn, "tenant_dokuman", eski_silinen) == 0, (
        "suresi dolmus silinmis dokuman supurulmemis — depo sizintisi surer"
    )


def test_retention_ESKI_rapor_ciktisini_siler_YENISINI_birakir(world, owner_conn):
    """(P167 §5) Uretilmis rapor ciktilari sonsuza kadar kalmaz.

    =========================================================================
    NEDEN DOKUMANDAN AYRI VE DAHA KISA
    =========================================================================
    Dokuman tesisin ARSIVIDIR; rapor ciktisi GECICI BIR TURETMEDIR —
    kaybolursa aynisi yeniden uretilebilir. Saklamanin tek amaci
    "kullanici indirmeye firsat bulsun".

    KVKK acisindan da dar olmali: `borc_alacak` ciktisi daire daire ad ve
    borc tasir; yeniden uretilebilen bir dosyayi aylarca tutmak amac
    sinirliligiyla bagdasmazdi.

    IKI YONLU: suresi dolan GITMELI, henuz dolmayan KALMALI. Tek yonlu
    olsaydi "hepsini sil" diyen bir regresyon testten gecerdi.
    """
    tid = world["a"]
    admin_id = _uid(owner_conn, tid, "admin")

    yeni_is, eski_is = uuid.uuid4(), uuid.uuid4()
    for rid, yas in ((yeni_is, "1 day"), (eski_is, "30 days")):
        owner_conn.execute(
            "INSERT INTO rapor_isi (id, tenant_id, user_id, kod, bicim, "
            "durum, dosya_key, dosya_adi, created_at) "
            "VALUES (%s, %s, %s, 'borc_alacak', 'excel', 'hazir', %s, "
            f"'borc_alacak.xlsx', now() - interval '{yas}')",
            (str(rid), str(tid), str(admin_id), f"{tid}/raporlar/{rid}.xlsx"),
        )

    run_retention()

    assert _exists(owner_conn, "rapor_isi", yeni_is) == 1, (
        "suresi dolmamis rapor isi silinmis — kullanicinin tam o an "
        "indirdigi dosya elinden alinirdi"
    )
    # SATIR DA GIDER, yalniz dosya degil: `ck_rapor_isi_hazir` kisiti
    # "durum=hazir iken dosya_key NOT NULL" diyor; dosyayi silip satiri
    # birakmak o kisiti ihlal ederdi.
    assert _exists(owner_conn, "rapor_isi", eski_is) == 0, (
        "suresi dolmus rapor isi supurulmemis — depo sizintisi surer"
    )


def test_resident_erasure_anonimlestirir_defteri_korur(world, client, owner_conn):
    """KVKK silme: ledger referansi olan sakin ANONIMLESTIRILIR (silinmez);
    kimlik alanlari temizlenir, finansal/ticket satiri KALIR, audit yazilir."""
    tid = world["a"]
    resident_id = _uid(owner_conn, tid, "resident")

    # Ledger referansi yarat: sakin bir talep acmis (acan_user_id RESTRICT) ->
    # hard-delete bloklanir, anonimlestirme yoluna dusulur.
    complaint_id = uuid.uuid4()
    owner_conn.execute(
        "INSERT INTO complaint (id, tenant_id, acan_user_id, baslik, mesaj, durum) "
        "VALUES (%s, %s, %s, 'Arizali asansor', 'Detay', 'acik')",
        (str(complaint_id), str(tid), str(resident_id)),
    )

    admin = {
        "Authorization": "Bearer "
        + client.post(
            "/auth/login",
            json={"tenant_slug": world["slug_a"], "email": world["admin_a"]["email"],
                  "password": world["admin_a"]["password"]},
        ).json()["access_token"]
    }
    r = client.delete(f"/residents/{resident_id}", headers=admin)
    assert r.status_code == 200, r.text
    assert r.json()["deleted"] is False  # ledger var -> anonimlestirildi

    ad, email, telefon, aktif, pset = owner_conn.execute(
        "SELECT ad, email, telefon, is_active, password_set FROM app_user WHERE id=%s",
        (str(resident_id),),
    ).fetchone()
    assert ad == "Silinmiş Kullanıcı"
    assert email is None and telefon is None
    assert aktif is False and pset is False

    # Ledger/ticket KORUNDU (yazar anonim kullaniciya isaret eder).
    assert _exists(owner_conn, "complaint", complaint_id) == 1

    # Denetim: resident_erasure yazildi.
    assert owner_conn.execute(
        "SELECT count(*) FROM audit_log WHERE tenant_id=%s AND action='resident_erasure' "
        "AND resource_id=%s",
        (str(tid), str(resident_id)),
    ).fetchone()[0] == 1
