"""Idempotent dev/test seed: ornek tenant + admin/yonetici/security/tesis_gorevlisi/resident kullanicilar.

Calistirma:
    docker compose exec api python -m scripts.seed
    # veya (api ayakta degilken) profilli servis:
    docker compose --profile seed run --rm seed

RLS uyumu: tenant tablosunda RLS FORCE etkin; YENI bir tenant olusturmak app_rw
ile mumkun degildir (WITH CHECK id = current_setting(...) yumurta-tavuk). Bu yuzden
seed OWNER (superuser) baglantisi ile calisir (migrate servisiyle ayni yetki) ve
RLS'i bypass ederek yazar. OWNER_DSN env'den okunur.

Idempotent: tenant `slug` ve kullanici `(tenant_id, email)` benzersiz kisitlari
uzerinden UPSERT (ON CONFLICT DO UPDATE) — ikinci kez calistirinca hata vermez,
hesaplari bilinen dev durumuna (parola dahil) gunceller.

Parolalar dev amaclidir; env ile override edilebilir.
"""
from __future__ import annotations

import os

import psycopg

from app.security import hash_password

# Ikinci sakinin (henuz parola belirlememis) tek seferlik gecici kodu.
# Dev/test icin sabittir; sakin girisinde "ilk giris" akisini denemek icin:
#   unit_no=A-12 + bu kod -> parola belirleme zorunlu.
RESIDENT2_TEMP_CODE = os.getenv("SEED_RESIDENT2_TEMP_CODE", "K7MR-2QWX")

OWNER_DSN = os.getenv(
    "OWNER_DSN",
    "postgresql://tesis_owner:owner_secret_change_me@db:5432/tesis",
)

TENANT = {
    "slug": "acme-plaza",
    "ad": "Acme Plaza",
    "timezone": "Europe/Istanbul",
    "yonetim_email": "yonetim@acme.com",
}

USERS = [
    {
        "ad": "Acme Admin",
        "email": "admin@acme.com",
        "role": "admin",
        "password": os.getenv("SEED_ADMIN_PASSWORD", "Admin123!"),
    },
    {
        "ad": "Acme Yonetici",
        "email": "yonetici@acme.com",
        "role": "yonetici",
        "password": os.getenv("SEED_YONETICI_PASSWORD", "Yonetici123!"),
        # Rol-bazli arama (C1a): security yoneticiyi arayabilir (rizali).
        "telefon": "+905321112201",
        "aranabilir": True,
        # Tesisi ilk giriste adlandiran yonetici (kapi YALNIZ buna acilir).
        "birincil": True,
    },
    {
        # Ikinci yonetici: "Yonetici Iletisim" sekmesindeki COKLU listeyi
        # gosterir. NOT: telefon GLOBAL benzersiz — 201-206 zaten dolu
        # (201 yonetici, 202 guard, 203 sakin, 204 cleaner, 205 sakin-3,
        # 206 sakin-es asagida ayri INSERT'te) -> 207.
        "ad": "Acme Yonetici 2",
        "email": "yonetici2@acme.com",
        "role": "yonetici",
        "password": os.getenv("SEED_YONETICI2_PASSWORD", "Yonetici123!"),
        "telefon": "+905321112207",
        "aranabilir": True,
        "birincil": False,
    },
    {
        "ad": "Acme Guard",
        "email": "guard@acme.com",
        "role": "security",
        "password": os.getenv("SEED_GUARD_PASSWORD", "Guard123!"),
        # resident guvenligi arayabilir (rizali).
        "telefon": "+905321112202",
        "aranabilir": True,
    },
    {
        "ad": "Acme Cleaner",
        "email": "cleaner@acme.com",
        "role": "tesis_gorevlisi",
        "password": os.getenv("SEED_CLEANER_PASSWORD", "Clean123!"),
        # Telefon = global benzersiz login anahtari (mobil giris).
        "telefon": "+905321112204",
    },
    {
        # Parolasi BELIRLENMIS sakin: daire girisi unit_no=A-12 + parola.
        # (email yalniz seed idempotency anahtari; sakin email ile girmez.)
        "ad": "Acme Sakin",
        "email": "resident@acme.com",
        "role": "resident",
        "password": os.getenv("SEED_RESIDENT_PASSWORD", "Resident123!"),
        # security sakini arayabilir (rizali; C1a).
        "telefon": "+905321112203",
        "aranabilir": True,
    },
    {
        # Ek sakin (D1 daire-sikayeti yogunlugu icin coklu sikayetci ornegi).
        "ad": "Acme Sakin 3",
        "email": "resident3@acme.com",
        "role": "resident",
        "password": os.getenv("SEED_RESIDENT3_PASSWORD", "Resident123!"),
        "telefon": "+905321112205",
    },
]


def main() -> int:
    with psycopg.connect(OWNER_DSN, autocommit=True) as conn:
        # 1) tenant upsert (slug benzersiz).
        tenant_id = conn.execute(
            """
            INSERT INTO tenant (ad, slug, timezone, yonetim_email)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (slug) DO UPDATE
                SET ad = EXCLUDED.ad, timezone = EXCLUDED.timezone,
                    yonetim_email = EXCLUDED.yonetim_email
            RETURNING id
            """,
            (TENANT["ad"], TENANT["slug"], TENANT["timezone"], TENANT["yonetim_email"]),
        ).fetchone()[0]
        print(f"[seed] tenant '{TENANT['slug']}' -> {tenant_id}")

        # 2) kullanici upsert ((tenant_id, email) benzersiz). Parolasi belli
        #    hesaplarda password_set=true (gecici kod akisi disi).
        for u in USERS:
            conn.execute(
                """
                INSERT INTO app_user (tenant_id, ad, email, password_hash,
                                      password_set, temp_code_hash, role, is_active,
                                      telefon, aranabilir, birincil)
                VALUES (%s, %s, %s, %s, true, NULL, %s::user_role, true, %s, %s, %s)
                ON CONFLICT (tenant_id, email) DO UPDATE
                    SET ad = EXCLUDED.ad,
                        password_hash = EXCLUDED.password_hash,
                        password_set = true,
                        temp_code_hash = NULL,
                        role = EXCLUDED.role,
                        is_active = true,
                        telefon = EXCLUDED.telefon,
                        aranabilir = EXCLUDED.aranabilir,
                        birincil = EXCLUDED.birincil,
                        updated_at = now()
                """,
                (tenant_id, u["ad"], u["email"], hash_password(u["password"]), u["role"],
                 u.get("telefon"), u.get("aranabilir", False), u.get("birincil", False)),
            )
            print(f"[seed] user {u['email']:<18} role={u['role']}")

        # 2b) ikinci sakin: gecici kod BEKLEYEN hesap (ilk giris akisi testi).
        #     Ayni daireye (A-12) baglanir -> ayni dairede coklu sakin ornegi.
        conn.execute(
            """
            INSERT INTO app_user (tenant_id, ad, email, telefon, password_hash,
                                  password_set, temp_code_hash, role, is_active)
            VALUES (%s, %s, %s, %s, NULL, false, %s, 'resident'::user_role, true)
            ON CONFLICT (tenant_id, email) DO UPDATE
                SET ad = EXCLUDED.ad,
                    telefon = EXCLUDED.telefon,
                    password_hash = NULL,
                    password_set = false,
                    temp_code_hash = EXCLUDED.temp_code_hash,
                    role = 'resident'::user_role,
                    is_active = true,
                    updated_at = now()
            """,
            (
                tenant_id,
                "Acme Sakin Es",
                "resident2@acme.com",
                "+905321112206",
                hash_password(RESIDENT2_TEMP_CODE),
            ),
        )
        print(
            "[seed] user resident2@acme.com  role=resident "
            f"(gecici kod bekliyor: {RESIDENT2_TEMP_CODE})"
        )

        # 3) aidat ornegi: daire A-12 + resident baglantisi + 2026-06 tahakkuk.
        # Yerlesim (D-viz-1): A-12 -> blok A, kat 1, sira 2 (bina semasi verisi).
        unit_id = conn.execute(
            """
            INSERT INTO unit (tenant_id, no, blok, kat, sira)
            VALUES (%s, 'A-12', 'A', 1, 2)
            ON CONFLICT (tenant_id, no) DO UPDATE
                SET blok = EXCLUDED.blok, kat = EXCLUDED.kat, sira = EXCLUDED.sira
            RETURNING id
            """,
            (tenant_id,),
        ).fetchone()[0]
        # Iki sakin de A-12'ye baglanir (ayni dairede coklu sakin — her biri
        # kendi parolasi/koduyla girer).
        for email, rol_tipi in [
            ("resident@acme.com", "malik"),
            ("resident2@acme.com", "malik"),
        ]:
            resident_id = conn.execute(
                "SELECT id FROM app_user WHERE tenant_id=%s AND email=%s",
                (tenant_id, email),
            ).fetchone()[0]
            conn.execute(
                """
                INSERT INTO unit_resident (tenant_id, unit_id, user_id, rol_tipi)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (unit_id, user_id) WHERE bitis IS NULL DO NOTHING
                """,
                (tenant_id, unit_id, resident_id, rol_tipi),
            )
        conn.execute(
            """
            INSERT INTO dues_assessment (tenant_id, unit_id, donem, tutar_kurus, aciklama)
            VALUES (%s, %s, '2026-06', 75000, 'Haziran aidatı')
            ON CONFLICT (tenant_id, unit_id, donem) DO NOTHING
            """,
            (tenant_id, unit_id),
        )
        print(
            f"[seed] unit A-12 -> {unit_id} (blok A/kat 1/sira 2 + resident "
            "baglantisi + 2026-06 tahakkuk 750.00 TL)"
        )

        # Yerlesim ornekleri (D-viz-1): sikayetsiz (yesil) birkac daire ki
        # sonraki tur cizecegi harita dolu gorunsun. blok A: kat 1 (sira 1) +
        # kat 2 (sira 1); blok B: kat 1 (sira 1).
        for _no, _blok, _kat, _sira in [
            ("A-5", "A", 1, 1),
            ("A-9", "A", 2, 1),
            ("B-7", "B", 1, 1),
        ]:
            conn.execute(
                """
                INSERT INTO unit (tenant_id, no, blok, kat, sira)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (tenant_id, no) DO UPDATE
                    SET blok = EXCLUDED.blok, kat = EXCLUDED.kat, sira = EXCLUDED.sira
                """,
                (tenant_id, _no, _blok, _kat, _sira),
            )
        print("[seed] yerlesim ornek daireleri: A-5, A-9 (blok A), B-7 (blok B) — yesil")

        # Bina bloklari (D-viz Rev-1): yonetici/admin blok tanimlar (Rev-2
        # editor iskeleti). A: 3 kat, B: 2 kat. Etiket unit.blok ile eslesir.
        for _ad, _kat in (("A", 3), ("B", 2)):
            conn.execute(
                """
                INSERT INTO building_block (tenant_id, ad, kat_sayisi)
                VALUES (%s, %s, %s)
                ON CONFLICT (tenant_id, ad) DO UPDATE SET kat_sayisi = EXCLUDED.kat_sayisi
                """,
                (tenant_id, _ad, _kat),
            )
        print("[seed] bina bloklari: A (3 kat), B (2 kat)")

        # 3b) BUTCE (Wave 2A): kategoriler + ornek defter + otomatik aidat→gelir.
        #     Para INTEGER KURUS. 'Aidat' otomatik gelir kategorisidir (basarili
        #     odeme kaydi burada toplanir).
        kategoriler = [
            ("Aidat", "gelir"),      # otomatik aidat gelirlerinin varsayilan kategorisi
            ("Ek ödeme", "gelir"),
            ("Elektrik", "gider"),
            ("Temizlik", "gider"),
        ]
        kat_ids: dict[tuple[str, str], str] = {}
        for ad, tip in kategoriler:
            kat_ids[(ad, tip)] = conn.execute(
                """
                INSERT INTO budget_category (tenant_id, ad, tip)
                VALUES (%s, %s, %s::budget_tip)
                ON CONFLICT ON CONSTRAINT uq_budgetcat_tenant_tip_ad
                    DO UPDATE SET aktif = true, updated_at = now()
                RETURNING id
                """,
                (tenant_id, ad, tip),
            ).fetchone()[0]
        print(f"[seed] butce kategorileri: {', '.join(f'{a}/{t}' for a, t in kategoriler)}")

        yonetici_id = conn.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND email=%s",
            (tenant_id, "yonetici@acme.com"),
        ).fetchone()[0]

        # Ornek MANUEL defter kayitlari (aciklama dogal anahtar — idempotent).
        ornek_kayitlar = [
            ("Elektrik", "gider", 245000, "2026-06-20", "Ortak alan elektrik faturası (Haziran)"),
            ("Temizlik", "gider", 180000, "2026-07-01", "Temizlik hizmeti (Temmuz)"),
            ("Ek ödeme", "gelir", 50000, "2026-07-05", "Otopark kira geliri"),
        ]
        for ad, tip, kurus, tarih, aciklama in ornek_kayitlar:
            conn.execute(
                """
                INSERT INTO budget_entry (tenant_id, kategori_id, tip, tutar_kurus,
                                          tarih, aciklama, kaynak, created_by)
                SELECT %(t)s, %(k)s, %(tip)s::budget_tip, %(kurus)s, %(tarih)s,
                       %(a)s, 'manuel'::budget_kaynak, %(u)s
                WHERE NOT EXISTS (
                    SELECT 1 FROM budget_entry
                    WHERE tenant_id = %(t)s AND aciklama = %(a)s
                )
                """,
                {
                    "t": tenant_id, "k": kat_ids[(ad, tip)], "tip": tip,
                    "kurus": kurus, "tarih": tarih, "a": aciklama, "u": yonetici_id,
                },
            )
        print("[seed] ornek defter: Elektrik 2450.00 TL gider, Temizlik 1800.00 TL gider, Ek odeme 500.00 TL gelir")

        # Ornek AIDAT ODEMESI + otomatik gelir kaydi (API'nin urettigiyle ayni
        # sekil: kaynak=aidat_odeme + ilgili_payment_id; UNIQUE ile idempotent).
        payment_id = conn.execute(
            """
            INSERT INTO dues_payment (tenant_id, unit_id, tutar_kurus, donem,
                                      yontem, durum, kaydeden_user_id, idempotency_key,
                                      odeme_zamani)
            VALUES (%s, %s, 75000, '2026-06', 'elden'::dues_yontem,
                    'basarili'::dues_durum, %s, 'seed-a12-2026-06', '2026-06-25T10:00:00Z')
            ON CONFLICT (tenant_id, idempotency_key) DO UPDATE SET donem = EXCLUDED.donem
            RETURNING id
            """,
            (tenant_id, unit_id, yonetici_id),
        ).fetchone()[0]
        conn.execute(
            """
            INSERT INTO budget_entry (tenant_id, kategori_id, tip, tutar_kurus, tarih,
                                      aciklama, kaynak, ilgili_payment_id, created_by)
            VALUES (%s, %s, 'gelir'::budget_tip, 75000, '2026-06-25',
                    'Aidat ödemesi 2026-06 (otomatik)', 'aidat_odeme'::budget_kaynak, %s, %s)
            ON CONFLICT ON CONSTRAINT uq_budget_entry_payment DO NOTHING
            """,
            (tenant_id, kat_ids[("Aidat", "gelir")], payment_id, yonetici_id),
        )
        # Dogrulama: odemenin TEK otomatik gelir kaydi var mi?
        auto_count = conn.execute(
            "SELECT count(*) FROM budget_entry WHERE ilgili_payment_id = %s",
            (payment_id,),
        ).fetchone()[0]
        assert auto_count == 1, f"aidat->gelir kaydi bekleniyordu, bulunan: {auto_count}"
        print("[seed] aidat odemesi A-12 750.00 TL (2026-06) -> otomatik 'Aidat' gelir kaydi OK (tek, idempotent)")

        # 4) ornek duyuru (yonetici imzali). Dogal benzersiz anahtar yok ->
        #    ayni baslik varsa eklemeyerek idempotent kalinir.
        conn.execute(
            """
            INSERT INTO announcement (tenant_id, baslik, govde, olusturan_user_id)
            SELECT %(t)s, %(b)s, %(g)s, u.id
            FROM app_user u
            WHERE u.tenant_id = %(t)s AND u.email = 'yonetici@acme.com'
              AND NOT EXISTS (
                  SELECT 1 FROM announcement
                  WHERE tenant_id = %(t)s AND baslik = %(b)s
              )
            """,
            {
                "t": tenant_id,
                "b": "Hoş geldiniz",
                "g": "Tesis yönetim sistemi devrede. Duyurular bu ekranda yayınlanacak.",
            },
        )
        print("[seed] duyuru 'Hoş geldiniz' (yonetici imzali, idempotent)")

        # 5) ornek sikayet + oneri (resident acmis). Dogal benzersiz anahtar
        #    yok -> ayni baslik varsa eklemeyerek idempotent kalinir.
        #    a) sikayet: cozuldu.
        #    NOT (ticketing reshape, Task 1): complaint.yonetici_yaniti/
        #    yanitlayan_user_id/yanit_zamani kolonlari kaldirildi (yanit artik
        #    complaint_status_history.sebep uzerinden). Demo ticket/history
        #    verisi Task 9'da eklenecek — burada yalnizca eski kolonlara
        #    referans birakmamak icin minimal duzeltme yapildi.
        conn.execute(
            """
            INSERT INTO complaint (tenant_id, acan_user_id, baslik, mesaj, durum)
            SELECT %(t)s, r.id, %(b)s, %(m)s, 'cozuldu'
            FROM app_user r
            WHERE r.tenant_id = %(t)s AND r.email = 'resident@acme.com'
              AND NOT EXISTS (
                  SELECT 1 FROM complaint
                  WHERE tenant_id = %(t)s AND baslik = %(b)s
              )
            """,
            {
                "t": tenant_id,
                "b": "Asansör arızalıydı",
                "m": "A blok asansörü iki gündür çalışmıyor, kontrol edilebilir mi?",
            },
        )
        #    b) oneri: acik, yanitsiz.
        conn.execute(
            """
            INSERT INTO complaint (tenant_id, acan_user_id, baslik, mesaj)
            SELECT %(t)s, r.id, %(b)s, %(m)s
            FROM app_user r
            WHERE r.tenant_id = %(t)s AND r.email = 'resident@acme.com'
              AND NOT EXISTS (
                  SELECT 1 FROM complaint
                  WHERE tenant_id = %(t)s AND baslik = %(b)s
              )
            """,
            {
                "t": tenant_id,
                "b": "Öneri: bahçeye bank",
                "m": "Çocuk parkının yanına birkaç bank konulmasını öneriyorum.",
            },
        )
        #    c) ucuncu sikayet (acik, yanitsiz). kategori_id dinamik
        #       task_category FK'idir (Task 9'da demo kategori/ticket verisi
        #       eklenecek); burada kategorisiz (NULL = "Diğer") birakilir.
        conn.execute(
            """
            INSERT INTO complaint (tenant_id, acan_user_id, baslik, mesaj)
            SELECT %(t)s, r.id, %(b)s, %(m)s
            FROM app_user r
            WHERE r.tenant_id = %(t)s AND r.email = 'resident@acme.com'
              AND NOT EXISTS (
                  SELECT 1 FROM complaint
                  WHERE tenant_id = %(t)s AND baslik = %(b)s
              )
            """,
            {
                "t": tenant_id,
                "b": "Gece geç saatte müzik",
                "m": "B blok 3. kattan gece yarısından sonra yüksek sesli müzik geliyor.",
            },
        )
        print(
            "[seed] sikayet 'Asansör arızalıydı' (cozuldu) + oneri 'Öneri: bahçeye bank' (acik) "
            "+ sikayet 'Gece geç saatte müzik' (acik)"
        )

        # 6) ornek ziyaretci: A-12 icin (guvenlik kaydetmis) — HEDEF sakin
        #    resident@acme.com. Ziyaretci artik LOG-ONLY: onay/red YOK, yalniz
        #    kayit + bilgilendirme. Iki gunluk (log) kaydi. Gorunurluk/bildirim
        #    YALNIZ hedef sakinde (tek hedef modeli, A). Ad ile idempotent.
        guard_id = conn.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND email='guard@acme.com'",
            (tenant_id,),
        ).fetchone()[0]
        target_id = conn.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND email='resident@acme.com'",
            (tenant_id,),
        ).fetchone()[0]
        for ad, notlar in (
            ("Kurye - Ahmet Yılmaz", "Kargo teslimatı (koli)"),
            ("Misafir - Ayşe Kaya", "Akşam yemeği misafiri"),
        ):
            conn.execute(
                """
                INSERT INTO visitor (tenant_id, unit_id, ziyaretci_ad, notlar,
                                     kaydeden_user_id, target_resident_user_id)
                SELECT %(t)s, %(u)s, %(ad)s, %(n)s, %(g)s, %(r)s
                WHERE NOT EXISTS (
                    SELECT 1 FROM visitor
                    WHERE tenant_id = %(t)s AND ziyaretci_ad = %(ad)s
                )
                """,
                {
                    "t": tenant_id, "u": unit_id, "ad": ad, "n": notlar,
                    "g": guard_id, "r": target_id,
                },
            )
        print(
            "[seed] ziyaretci (LOG) 'Kurye - Ahmet Yılmaz' + 'Misafir - Ayşe Kaya' "
            "A-12 -> hedef resident@acme.com (onay/red yok)"
        )

        # 7) ornek kargo: A-12 icin BEKLEYEN paket (guvenlik kaydi, fotosuz —
        #    foto gercek akista presign ile yuklenir; seed depoya obje
        #    yazmaz). Ayni firma+not varsa eklemeyerek idempotent.
        conn.execute(
            """
            INSERT INTO kargo (tenant_id, unit_id, firma, notlar, kaydeden_user_id)
            SELECT %(t)s, %(u)s, %(f)s, %(n)s, g.id
            FROM app_user g
            WHERE g.tenant_id = %(t)s AND g.email = 'guard@acme.com'
              AND NOT EXISTS (
                  SELECT 1 FROM kargo
                  WHERE tenant_id = %(t)s AND firma = %(f)s AND notlar = %(n)s
              )
            """,
            {
                "t": tenant_id,
                "u": unit_id,
                "f": "Aras Kargo",
                "n": "Orta boy koli — kapıda teslim alındı",
            },
        )
        print("[seed] kargo 'Aras Kargo' A-12 (bekliyor, guvenlik kaydi)")

        # 7b) ornek DAIRE-SIKAYETI (D1 — ANONIM yogunluk): A-12 YESIL (2 acik),
        #     yeni daire B-2 SARI (3 acik). Sikayet edenler ASLA gorunmez; bu
        #     yalniz renk/harita verisi uretir. complainant_user_id ic alandir.
        # Yerlesim (D-viz-1): B-2 -> blok B, kat 0 (zemin), sira 2.
        conn.execute(
            """
            INSERT INTO unit (tenant_id, no, blok, kat, sira)
            VALUES (%s, 'B-2', 'B', 0, 2)
            ON CONFLICT (tenant_id, no) DO UPDATE
                SET blok = EXCLUDED.blok, kat = EXCLUDED.kat, sira = EXCLUDED.sira
            """,
            (tenant_id,),
        )
        b2_id = conn.execute(
            "SELECT id FROM unit WHERE tenant_id=%s AND no='B-2'", (tenant_id,)
        ).fetchone()[0]
        _res_ids = {
            e: conn.execute(
                "SELECT id FROM app_user WHERE tenant_id=%s AND email=%s", (tenant_id, e)
            ).fetchone()[0]
            for e in ("resident@acme.com", "resident2@acme.com", "resident3@acme.com")
        }
        # (hedef_unit, sikayetci_email, kategori) — A-12 x2 (yesil), B-2 x3 (sari)
        _uc = [
            (unit_id, "resident@acme.com", "gurultu"),
            (unit_id, "resident2@acme.com", "kapi_onu_ayakkabi"),
            (b2_id, "resident@acme.com", "gurultu"),
            (b2_id, "resident2@acme.com", "gurultu"),
            (b2_id, "resident3@acme.com", "diger"),
        ]
        # Rev-1.1: spam kurali artik haftalik+kategori-bazli (partial-unique index
        # kaldirildi). Idempotentlik icin ayni (daire,sikayetci,kategori) kaydi
        # zaten varsa ekleme (WHERE NOT EXISTS).
        for tgt, email, kat in _uc:
            conn.execute(
                """
                INSERT INTO unit_complaint
                    (tenant_id, target_unit_id, complainant_user_id, kategori, notlar)
                SELECT %(t)s, %(u)s, %(c)s, %(k)s::unit_complaint_kategori, %(n)s
                WHERE NOT EXISTS (
                    SELECT 1 FROM unit_complaint
                    WHERE tenant_id = %(t)s AND target_unit_id = %(u)s
                      AND complainant_user_id = %(c)s AND kategori = %(k)s::unit_complaint_kategori
                )
                """,
                {"t": tenant_id, "u": tgt, "c": _res_ids[email], "k": kat,
                 "n": "Örnek daire şikayeti"},
            )
        print(
            "[seed] daire-sikayeti (D1 anonim): A-12 yesil (2 acik, blok A/kat 1), "
            "B-2 sari (3 acik, blok B/kat 0)"
        )

        # 8) ortak alanlar + ornek rezervasyon: Havuz'da A-12 icin ONAYLI slot
        #    (cakisma kisiti/ekranlar veriyle denensin). Alan upsert (tenant+ad
        #    benzersiz); rezervasyon (alan, tarih, baslangic) uzerinden idempotent.
        alan_ids: dict[str, str] = {}
        # (ad, aciklama, acilis, kapanis, slot_dakika) — musaitlik: her gun
        # [acilis, kapanis) araligi, slot_dakika slot uzunlugu.
        for ad, aciklama, acilis, kapanis, slot in [
            ("Havuz", "Açık yüzme havuzu (yaz sezonu)", "08:00", "22:00", 60),
            ("Toplantı Odası", "12 kişilik toplantı odası (projektörlü)",
             "09:00", "18:00", 60),
        ]:
            alan_ids[ad] = conn.execute(
                """
                INSERT INTO ortak_alan
                    (tenant_id, ad, aciklama, acilis, kapanis, slot_dakika)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT ON CONSTRAINT uq_ortak_alan_tenant_ad
                    DO UPDATE SET aciklama = EXCLUDED.aciklama, aktif = true,
                                  acilis = EXCLUDED.acilis,
                                  kapanis = EXCLUDED.kapanis,
                                  slot_dakika = EXCLUDED.slot_dakika
                RETURNING id
                """,
                (tenant_id, ad, aciklama, acilis, kapanis, slot),
            ).fetchone()[0]
        print("[seed] ortak alanlar: Havuz (08-22), Toplantı Odası (09-18)")

        resident_id = conn.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND email=%s",
            (tenant_id, "resident@acme.com"),
        ).fetchone()[0]
        # ONAY AKISI YOK: rezervasyon dogrudan onaylandi (iptal_eden NULL).
        conn.execute(
            """
            INSERT INTO rezervasyon (tenant_id, alan_id, unit_id, talep_eden_user_id,
                                     tarih, baslangic, bitis, kisi_sayisi, notlar,
                                     durum)
            SELECT %(t)s, %(alan)s, %(u)s, %(r)s, %(tarih)s, %(bas)s, %(bit)s,
                   4, 'Aile yüzme saati', 'onaylandi'::rezervasyon_durum
            WHERE NOT EXISTS (
                SELECT 1 FROM rezervasyon
                WHERE tenant_id = %(t)s AND alan_id = %(alan)s
                  AND tarih = %(tarih)s AND baslangic = %(bas)s
            )
            """,
            {
                "t": tenant_id, "alan": alan_ids["Havuz"], "u": unit_id,
                "r": resident_id,
                "tarih": "2026-07-15", "bas": "10:00", "bit": "12:00",
            },
        )
        print("[seed] rezervasyon Havuz 2026-07-15 10:00-12:00 A-12 (onaylı, 4 kişi)")

        # IPTAL ornegi (Toplanti Odasi): iptal rozeti/gecmisi veriyle denensin
        # (iptal_eden = sakinin kendisi).
        conn.execute(
            """
            INSERT INTO rezervasyon (tenant_id, alan_id, unit_id, talep_eden_user_id,
                                     tarih, baslangic, bitis, kisi_sayisi, notlar,
                                     durum, iptal_eden_user_id, iptal_zamani)
            SELECT %(t)s, %(alan)s, %(u)s, %(r)s, %(tarih)s, %(bas)s, %(bit)s,
                   6, 'Aidat toplantısı', 'iptal'::rezervasyon_durum, %(r)s, now()
            WHERE NOT EXISTS (
                SELECT 1 FROM rezervasyon
                WHERE tenant_id = %(t)s AND alan_id = %(alan)s
                  AND tarih = %(tarih)s AND baslangic = %(bas)s
            )
            """,
            {
                "t": tenant_id, "alan": alan_ids["Toplantı Odası"], "u": unit_id,
                "r": resident_id,
                "tarih": "2026-07-20", "bas": "14:00", "bit": "15:00",
            },
        )
        print("[seed] rezervasyon Toplantı Odası 2026-07-20 14:00-15:00 A-12 (iptal)")

        # 9) etkinlikler + ornek RSVP'ler: yaklasan "Mac izleme" (2 katiliyor)
        #    + gecmis "Site genel kurulu" — sayac/ekranlar veriyle denensin.
        #    Etkinlik (tenant, baslik) ile idempotent; RSVP UNIQUE ile.
        etkinlikler = [
            ("Maç izleme akşamı", "Büyük ekranda milli maç — ikramlar yönetimden.",
             "2026-07-20T18:00:00Z", "Sosyal tesis salonu"),
            ("Site genel kurulu", "Yıllık olağan genel kurul toplantısı.",
             "2026-06-15T17:00:00Z", "Toplantı Odası"),
        ]
        etkinlik_ids: dict[str, str] = {}
        for baslik, aciklama, tarih, konum in etkinlikler:
            etkinlik_ids[baslik] = conn.execute(
                """
                WITH yeni AS (
                    INSERT INTO etkinlik (tenant_id, baslik, aciklama, tarih,
                                          konum, olusturan_user_id)
                    SELECT %(t)s, %(b)s, %(a)s, %(tarih)s, %(k)s, %(y)s
                    WHERE NOT EXISTS (
                        SELECT 1 FROM etkinlik
                        WHERE tenant_id = %(t)s AND baslik = %(b)s
                    )
                    RETURNING id
                )
                SELECT id FROM yeni
                UNION ALL
                SELECT id FROM etkinlik WHERE tenant_id = %(t)s AND baslik = %(b)s
                LIMIT 1
                """,
                {"t": tenant_id, "b": baslik, "a": aciklama,
                 "tarih": tarih, "k": konum, "y": yonetici_id},
            ).fetchone()[0]
        print("[seed] etkinlikler: 'Maç izleme akşamı' (yaklasan) + 'Site genel kurulu' (gecmis)")

        # RSVP'ler: iki sakin de mac izlemeye katiliyor (sayi=2 gorunsun).
        for email in ("resident@acme.com", "resident2@acme.com"):
            conn.execute(
                """
                INSERT INTO etkinlik_katilim (tenant_id, etkinlik_id, user_id, durum)
                SELECT %(t)s, %(e)s, u.id, 'katiliyorum'::katilim_durum
                FROM app_user u
                WHERE u.tenant_id = %(t)s AND u.email = %(m)s
                ON CONFLICT ON CONSTRAINT uq_katilim_tenant_etkinlik_user
                    DO NOTHING
                """,
                {"t": tenant_id, "e": etkinlik_ids["Maç izleme akşamı"], "m": email},
            )
        print("[seed] RSVP: 2 sakin 'Maç izleme akşamı' icin katiliyorum (seffaf sayi=2)")

        # 10) site kurallari: 3 ornek kural (sira ile) — liste + baslik
        #     aramasi veriyle denensin. (tenant, baslik) ile idempotent;
        #     fotosuz (foto gercek akista presign ile yuklenir).
        kurallar = [
            (1, "Otopark Kullanımı",
             "Her daireye bir otopark yeri ayrılmıştır. Misafir araçları "
             "yalnız misafir otoparkını kullanabilir; yer değişimi yönetim "
             "onayına tabidir."),
            (2, "Havuz Saatleri",
             "Havuz 08:00-22:00 arası açık; 12 yaş altı çocuklar veli "
             "gözetiminde girebilir. Havuz alanına cam eşya sokulmaz."),
            (3, "Gürültü Kuralları",
             "Hafta içi 22:00-08:00, hafta sonu 24:00-10:00 arası gürültü "
             "yasaktır. Tadilat yalnız hafta içi 09:00-18:00 arası yapılabilir."),
        ]
        for sira, baslik, icerik in kurallar:
            conn.execute(
                """
                INSERT INTO site_kurali (tenant_id, baslik, icerik, sira,
                                         olusturan_user_id)
                SELECT %(t)s, %(b)s, %(i)s, %(s)s, %(y)s
                WHERE NOT EXISTS (
                    SELECT 1 FROM site_kurali
                    WHERE tenant_id = %(t)s AND baslik = %(b)s
                )
                """,
                {"t": tenant_id, "b": baslik, "i": icerik, "s": sira,
                 "y": yonetici_id},
            )
        print("[seed] site kurallari: Otopark Kullanımı (1), Havuz Saatleri (2), Gürültü Kuralları (3)")

    print("[seed] tamamlandi (idempotent).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
