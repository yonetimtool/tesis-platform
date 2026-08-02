"""(P115) APP STORE DENETIM TESISI — tohumlama.

    docker compose exec api python -m scripts.demo_tenant

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

PAROLALAR: env ile verilir; varsayilanlar YALNIZ yerel deneme icindir.
App Store Connect'e girilecek gercek parola Kerem tarafindan
`DEMO_PAROLA` ile verilir ve `docs/app-store/review-notes.md`e yazilir.
"""
from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone

import psycopg

from app.security import hash_password

OWNER_DSN = os.getenv(
    "OWNER_DSN",
    "postgresql://tesis_owner:owner_secret_change_me@db:5432/tesis",
)

SLUG = os.getenv("DEMO_SLUG", "demo")
PAROLA = os.getenv("DEMO_PAROLA", "AppReview2026!")

#: Her rol icin BIR hesap. Denetci rolleri tek tek gormek isteyebilir;
#: tek hesap vermek "yonetici ekranlarini gosteremedik" demek olurdu.
HESAPLAR = [
    ("Demo Yönetici", "yonetici@demo.yonetio.site", "yonetici", "+905000000101"),
    ("Demo Güvenlik", "guvenlik@demo.yonetio.site", "security", "+905000000102"),
    ("Demo Görevli", "gorevli@demo.yonetio.site", "tesis_gorevlisi", "+905000000103"),
    ("Demo Sakin", "sakin@demo.yonetio.site", "resident", "+905000000104"),
]

#: Tur noktalari. UID'ler SABIT: denetim notlarindaki "simule okutma"
#: adimlari bu noktalara isaret eder.
NOKTALAR = [
    ("Ana Kapı", "DEMO-NFC-0001"),
    ("Otopark Girişi", "DEMO-NFC-0002"),
    ("Bahçe", "DEMO-NFC-0003"),
]


def main() -> int:
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

    print("[demo] TAMAM — docs/app-store/review-notes.md ile birlikte kullanin.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
