"""(P115) APP STORE DENETIM TESISI — tohumlama.

KOSUM (dev VE prod, AYNI bicim — `worker`, `api` DEGIL):

    docker compose -f infra/docker-compose.prod.yml --env-file infra/.env.prod \
        run --rm -e DEMO_PAROLA='<parola>' worker python -m scripts.demo_tenant

NEDEN `worker`: bu betik RLS'i bypass etmek icin OWNER (superuser)
baglantisi ister ve prod'da `OWNER_DSN` **yalniz** `migrate`/`worker`/
`beat` servislerinde tanimlidir — `api`ye superuser DSN'i BILINCLI olarak
verilmez (bkz. docker-compose.prod.yml basligi). `create_admin.py` ile
ayni sinir; komut bicimi de kasten ayni.

NE YAPAR: `demo_mod = true` olan bir tesis acar, her rol icin BIR hesap
kurar ve denetcinin gorecegi ekranlarin BOS KALMAMASI icin en az veriyi
yazar (blok/daire, tur plani ve noktalari, bir duyuru, bir aidat).

NEDEN AYRI BIR BETIK (dev seed'e eklemek yerine): dev seed her
gelistiricinin veritabaninda kosar ve `demo_mod` orada ASLA acilmamali.
Demo modu, tur kaydinin kanit degerini askiya alan bir bayraktir; onu
"herkesin kosturdugu" bir betige koymak, bir gun prod'da acilmis
bulunmasinin en kisa yoludur.

IDEMPOTENT: slug ve (tenant_id, email) benzersizligi uzerinden UPSERT.
Denetim turlari arasinda tekrar kosulabilir.

PAROLA: `DEMO_PAROLA` ile verilir ve VARSAYILANI YOKTUR (bkz. asagida).
App Store Connect'e girilen parola ile AYNI olmalidir; degeri
`docs/app-store/review-notes.md` §1'de degil, App Store Connect'in
parola alaninda tutulur.
"""
from __future__ import annotations

import os
import sys
from datetime import datetime, timedelta, timezone

import psycopg

from app.security import hash_password

# OWNER_DSN'in SABIT KODLU bir yedegi YOK — `create_admin.py` ile ayni
# gerekce (tur 72'de orada duzeltilmisti, bu betik onu YENIDEN URETMISTI):
# dev parolasini ("owner_secret_change_me") iceren bir yedek, dev'de kaza
# eseri dogru oldugu icin calisir; prod'da ise sessizce YANLIS parolayla
# baglanmayi deneyip anlasilmaz bir kimlik hatasi verir
# ("password authentication failed for user"). Eksikse ERKEN ve NET patlar.
OWNER_DSN = os.getenv("OWNER_DSN", "")

SLUG = os.getenv("DEMO_SLUG", "demo")

# PAROLANIN DA VARSAYILANI YOK. Bir varsayilan, PROD'da internete acik bir
# tenant'ta HERKESIN BILDIGI bir parola birakirdi — hem de tam olarak
# denetciye verilen hesaplarda. Komut zaten `-e DEMO_PAROLA=...` ile
# cagriliyor (bkz. modul basligi ve review-notes.md §1).
PAROLA = os.getenv("DEMO_PAROLA", "")

#: Her rol icin BIR hesap. Denetci rolleri tek tek gormek isteyebilir;
#: tek hesap vermek "yonetici ekranlarini gosteremedik" demek olurdu.
HESAPLAR = [
    ("Demo Yönetici", "yonetici@demo.yonetio.site", "yonetici", "+905000000101"),
    ("Demo Güvenlik", "guvenlik@demo.yonetio.site", "security", "+905000000102"),
    ("Demo Görevli", "gorevli@demo.yonetio.site", "tesis_gorevlisi", "+905000000103"),
    ("Demo Sakin", "sakin@demo.yonetio.site", "resident", "+905000000104"),
    # (P143) GUVENLIK AMIRI — enum'da vardi ama PROD'DA TEK KULLANICISI
    # YOKTU: rol bugune kadar hic denenmemis, "6 karo goruyor" raporunu
    # kimse EKRANDA gormemisti. Hesap olmadan bir rolun dogru calistigini
    # soylemek, calistigini VARSAYMAKTIR.
    ("Demo Güvenlik Amiri", "amir@demo.yonetio.site", "guvenlik_amiri",
     "+905000000105"),
]

#: Tur noktalari. UID'ler SABIT: denetim notlarindaki "simule okutma"
#: adimlari bu noktalara isaret eder.
NOKTALAR = [
    ("Ana Kapı", "DEMO-NFC-0001"),
    ("Otopark Girişi", "DEMO-NFC-0002"),
    ("Bahçe", "DEMO-NFC-0003"),
]


def main() -> int:
    if not OWNER_DSN:
        print(
            "OWNER_DSN tanimsiz. Bu betik RLS'i bypass etmek icin OWNER "
            "(superuser) baglantisi ister.\n"
            "  Prod: `run --rm -e DEMO_PAROLA=... worker python -m "
            "scripts.demo_tenant` (api DEGIL — api'de superuser DSN'i "
            "bilincli olarak yoktur).\n"
            "  Elle: OWNER_DSN=postgresql://<owner>:<parola>@db:5432/<db>",
            file=sys.stderr,
        )
        return 2
    if len(PAROLA) < 8:
        print(
            "DEMO_PAROLA gerekli (en az 8 karakter). Varsayilan YOKTUR: "
            "sabit bir parola, prod'da herkesin bildigi bir demo hesabi "
            "birakirdi.\n"
            "  Ornek: run --rm -e DEMO_PAROLA='<parola>' worker "
            "python -m scripts.demo_tenant",
            file=sys.stderr,
        )
        return 2

    with psycopg.connect(OWNER_DSN, autocommit=True) as conn:
        tenant_id = conn.execute(
            """
            INSERT INTO tenant (ad, slug, timezone, demo_mod, kurulum_tamamlandi,
                                yonetim_email, otopark_kapasite)
            VALUES (%s, %s, 'Europe/Istanbul', true, true, %s, 50)
            ON CONFLICT (slug) DO UPDATE
                SET ad = EXCLUDED.ad, demo_mod = true,
                    kurulum_tamamlandi = true,
                    yonetim_email = EXCLUDED.yonetim_email
            RETURNING id
            """,
            ("Yönetio Demo Sitesi", SLUG, "demo@yonetio.site"),
        ).fetchone()[0]
        print(f"[demo] tenant '{SLUG}' -> {tenant_id} (demo_mod=true)")

        pw = hash_password(PAROLA)
        for ad, email, rol, tel in HESAPLAR:
            conn.execute(
                """
                INSERT INTO app_user (tenant_id, ad, email, password_hash,
                                      password_set, role, is_active, telefon,
                                      aranabilir, birincil)
                VALUES (%s, %s, %s, %s, true, %s::user_role, true, %s, false, false)
                ON CONFLICT (tenant_id, lower(email)) DO UPDATE
                    SET ad = EXCLUDED.ad, password_hash = EXCLUDED.password_hash,
                        password_set = true, role = EXCLUDED.role,
                        is_active = true, telefon = EXCLUDED.telefon
                """,
                (tenant_id, ad, email, pw, rol, tel),
            )
        print(f"[demo] {len(HESAPLAR)} hesap (parola env: DEMO_PAROLA)")

        # Daire — sakin ekraninin bos kalmamasi icin.
        unit_id = conn.execute(
            """
            INSERT INTO unit (tenant_id, no, blok, aktif)
            VALUES (%s, 'A-1', 'A', true)
            ON CONFLICT (tenant_id, no) DO UPDATE SET blok = EXCLUDED.blok
            RETURNING id
            """,
            (tenant_id,),
        ).fetchone()[0]
        sakin_id = conn.execute(
            "SELECT id FROM app_user WHERE tenant_id = %s AND role = 'resident'",
            (tenant_id,),
        ).fetchone()[0]
        conn.execute(
            """
            INSERT INTO unit_resident (tenant_id, unit_id, user_id, rol_tipi)
            VALUES (%s, %s, %s, 'malik')
            ON CONFLICT DO NOTHING
            """,
            (tenant_id, unit_id, sakin_id),
        )

        # Tur noktalari — simule okutmanin hedefi.
        for ad, uid in NOKTALAR:
            conn.execute(
                """
                INSERT INTO checkpoint (tenant_id, ad, nfc_tag_uid, aktif)
                VALUES (%s, %s, %s, true)
                ON CONFLICT (tenant_id, nfc_tag_uid) DO UPDATE SET ad = EXCLUDED.ad
                """,
                (tenant_id, ad, uid),
            )
        print(f"[demo] {len(NOKTALAR)} tur noktasi (UID'ler denetim notlarinda)")

        # Bir duyuru — ana ekran ve ceviri gostergesi bos kalmasin.
        conn.execute(
            """
            INSERT INTO announcement (tenant_id, baslik, govde, olusturan_user_id)
            SELECT %s, %s, %s, id FROM app_user
             WHERE tenant_id = %s AND role = 'yonetici'
            ON CONFLICT DO NOTHING
            """,
            (
                tenant_id,
                "Havuz bakımı",
                "Havuz 5 Ağustos Salı günü 09:00-12:00 arasında bakım nedeniyle kapalı olacaktır.",
                tenant_id,
            ),
        )

        # Bir aidat tahakkuku — "Aidatım" ekrani bos kalmasin.
        donem = datetime.now(tz=timezone.utc).strftime("%Y-%m")
        conn.execute(
            """
            INSERT INTO dues_assessment (tenant_id, unit_id, donem, tutar_kurus,
                                         son_odeme_tarihi, aciklama)
            VALUES (%s, %s, %s, 75000, %s, 'Aylık aidat')
            ON CONFLICT DO NOTHING
            """,
            (tenant_id, unit_id, donem, (datetime.now(tz=timezone.utc) + timedelta(days=10)).date()),
        )

        # (P150) KAPALI TEST VERISI — 17 testci 14 gun boyunca BAKACAK bir
        # sey bulmali. Google "yuklenip acilmamis" kullanimi test SAYMIYOR.
        _kapali_test_verisi(conn, tenant_id, unit_id)

    print("[demo] TAMAM — docs/app-store/review-notes.md ile birlikte kullanin.")
    return 0


def _rol(conn, tenant_id, rol):
    """Rolun kullanici id'si — cagiran kapsamda bir sozluk YOK, kaynaktan okunur."""
    r = conn.execute(
        "SELECT id FROM app_user WHERE tenant_id = %s AND role = %s LIMIT 1",
        (tenant_id, rol),
    ).fetchone()
    return r[0] if r else None


def _kapali_test_verisi(conn, tenant_id, unit_id):
    """Acik gorev + rezervasyon + kargo + gecikmis devriye alarmi.

    IDEMPOTENT: her satir dogal anahtariyla kontrol edilir.
    """
    yonetici = _rol(conn, tenant_id, "yonetici")
    gorevli = _rol(conn, tenant_id, "tesis_gorevlisi")
    guvenlik = _rol(conn, tenant_id, "security")
    sakin = _rol(conn, tenant_id, "resident")

    for baslik, oncelik in (("Asansör aylık bakımı", "orta"),
                            ("Otopark aydınlatma arızası", "yuksek"),
                            ("Çatı su sızıntısı kontrolü", "dusuk")):
        conn.execute(
            # SEMA VARSAYILMADI, OKUNDU: `task` sutunlari ad/aciklama/
            # atanan_user_id/oncelik/aktif — `baslik`/`durum`/`son_tarih` YOK.
            "INSERT INTO task (tenant_id, ad, aciklama, atanan_user_id, "
            "oncelik, aktif) SELECT %s, %s, %s, %s, %s, true "
            "WHERE NOT EXISTS (SELECT 1 FROM task WHERE tenant_id = %s AND ad = %s)",
            (tenant_id, baslik, baslik, gorevli, oncelik, tenant_id, baslik),
        )

    alan = conn.execute(
        "SELECT id FROM ortak_alan WHERE tenant_id = %s LIMIT 1", (tenant_id,)
    ).fetchone()
    if alan and sakin:
        conn.execute(
            "INSERT INTO rezervasyon (tenant_id, alan_id, unit_id, "
            "talep_eden_user_id, tarih, baslangic, bitis, durum) "
            "SELECT %s, %s, %s, %s, current_date + 1, '14:00', '16:00', "
            "'onaylandi' WHERE NOT EXISTS (SELECT 1 FROM rezervasyon "
            "WHERE tenant_id = %s AND alan_id = %s AND tarih = current_date + 1)",
            (tenant_id, alan[0], unit_id, sakin, tenant_id, alan[0]),
        )

    if unit_id and guvenlik:
        for firma in ("Yurtiçi Kargo", "Aras Kargo"):
            conn.execute(
                "INSERT INTO kargo (tenant_id, unit_id, firma, durum, kaydeden_user_id) "
                "SELECT %s, %s, %s, 'bekliyor', %s WHERE NOT EXISTS "
                "(SELECT 1 FROM kargo WHERE tenant_id = %s AND unit_id = %s AND firma = %s)",
                (tenant_id, unit_id, firma, guvenlik, tenant_id, unit_id, firma),
            )

    # `user_id` NULL: YONETIM alarmi (P147 kapsam ayrimi).
    conn.execute(
        "INSERT INTO notification (tenant_id, tip, mesaj, mesaj_kimlik) "
        "SELECT %s, 'kacirilan_tur', 'Gece turu kaçırıldı', 'kacirilan_tur' "
        "WHERE NOT EXISTS (SELECT 1 FROM notification WHERE tenant_id = %s "
        "AND tip = 'kacirilan_tur')",
        (tenant_id, tenant_id),
    )
    print("[demo] kapali test verisi: 3 acik gorev, 1 rezervasyon, 2 kargo, 1 alarm")


if __name__ == "__main__":
    raise SystemExit(main())
