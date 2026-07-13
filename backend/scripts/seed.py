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
    "acil_durum_telefon": "+902120000000",
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
    },
]


def main() -> int:
    with psycopg.connect(OWNER_DSN, autocommit=True) as conn:
        # 1) tenant upsert (slug benzersiz).
        tenant_id = conn.execute(
            """
            INSERT INTO tenant (ad, slug, timezone, acil_durum_telefon)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (slug) DO UPDATE
                SET ad = EXCLUDED.ad, timezone = EXCLUDED.timezone,
                    acil_durum_telefon = EXCLUDED.acil_durum_telefon
            RETURNING id
            """,
            (TENANT["ad"], TENANT["slug"], TENANT["timezone"], TENANT["acil_durum_telefon"]),
        ).fetchone()[0]
        print(f"[seed] tenant '{TENANT['slug']}' -> {tenant_id}")

        # 2) kullanici upsert ((tenant_id, email) benzersiz). Parolasi belli
        #    hesaplarda password_set=true (gecici kod akisi disi).
        for u in USERS:
            conn.execute(
                """
                INSERT INTO app_user (tenant_id, ad, email, password_hash,
                                      password_set, temp_code_hash, role, is_active,
                                      telefon, aranabilir)
                VALUES (%s, %s, %s, %s, true, NULL, %s::user_role, true, %s, %s)
                ON CONFLICT (tenant_id, email) DO UPDATE
                    SET ad = EXCLUDED.ad,
                        password_hash = EXCLUDED.password_hash,
                        password_set = true,
                        temp_code_hash = NULL,
                        role = EXCLUDED.role,
                        is_active = true,
                        telefon = EXCLUDED.telefon,
                        aranabilir = EXCLUDED.aranabilir,
                        updated_at = now()
                """,
                (tenant_id, u["ad"], u["email"], hash_password(u["password"]), u["role"],
                 u.get("telefon"), u.get("aranabilir", False)),
            )
            print(f"[seed] user {u['email']:<18} role={u['role']}")

        # 2b) ikinci sakin: gecici kod BEKLEYEN hesap (ilk giris akisi testi).
        #     Ayni daireye (A-12) baglanir -> ayni dairede coklu sakin ornegi.
        conn.execute(
            """
            INSERT INTO app_user (tenant_id, ad, email, password_hash,
                                  password_set, temp_code_hash, role, is_active)
            VALUES (%s, %s, %s, NULL, false, %s, 'resident'::user_role, true)
            ON CONFLICT (tenant_id, email) DO UPDATE
                SET ad = EXCLUDED.ad,
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
                hash_password(RESIDENT2_TEMP_CODE),
            ),
        )
        print(
            "[seed] user resident2@acme.com  role=resident "
            f"(gecici kod bekliyor: {RESIDENT2_TEMP_CODE})"
        )

        # 3) aidat ornegi: daire A-12 + resident baglantisi + 2026-06 tahakkuk.
        unit_id = conn.execute(
            """
            INSERT INTO unit (tenant_id, no, blok)
            VALUES (%s, 'A-12', 'A')
            ON CONFLICT (tenant_id, no) DO UPDATE SET blok = EXCLUDED.blok
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
            VALUES (%s, %s, '2026-06', 75000, 'Haziran aidati')
            ON CONFLICT (tenant_id, unit_id, donem) DO NOTHING
            """,
            (tenant_id, unit_id),
        )
        print(f"[seed] unit A-12 -> {unit_id} (+ resident baglantisi + 2026-06 tahakkuk 750.00 TL)")

        # 3b) BUTCE (Wave 2A): kategoriler + ornek defter + otomatik aidat→gelir.
        #     Para INTEGER KURUS. 'Aidat' otomatik gelir kategorisidir (basarili
        #     odeme kaydi burada toplanir).
        kategoriler = [
            ("Aidat", "gelir"),      # otomatik aidat gelirlerinin varsayilan kategorisi
            ("Ek odeme", "gelir"),
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
            ("Elektrik", "gider", 245000, "2026-06-20", "Ortak alan elektrik faturasi (Haziran)"),
            ("Temizlik", "gider", 180000, "2026-07-01", "Temizlik hizmeti (Temmuz)"),
            ("Ek odeme", "gelir", 50000, "2026-07-05", "Otopark kira geliri"),
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
                    'Aidat odemesi 2026-06 (otomatik)', 'aidat_odeme'::budget_kaynak, %s, %s)
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
                "b": "Hos geldiniz",
                "g": "Tesis yonetim sistemi devrede. Duyurular bu ekranda yayinlanacak.",
            },
        )
        print("[seed] duyuru 'Hos geldiniz' (yonetici imzali, idempotent)")

        # 5) ornek sikayet + oneri (resident acmis). Dogal benzersiz anahtar
        #    yok -> ayni baslik varsa eklemeyerek idempotent kalinir.
        #    a) sikayet: yonetici yanitlamis, cozuldu.
        conn.execute(
            """
            INSERT INTO complaint (tenant_id, acan_user_id, baslik, mesaj, durum,
                                   yonetici_yaniti, yanitlayan_user_id, yanit_zamani)
            SELECT %(t)s, r.id, %(b)s, %(m)s, 'cozuldu', %(y)s, y.id, now()
            FROM app_user r, app_user y
            WHERE r.tenant_id = %(t)s AND r.email = 'resident@acme.com'
              AND y.tenant_id = %(t)s AND y.email = 'yonetici@acme.com'
              AND NOT EXISTS (
                  SELECT 1 FROM complaint
                  WHERE tenant_id = %(t)s AND baslik = %(b)s
              )
            """,
            {
                "t": tenant_id,
                "b": "Asansor ariziliydi",
                "m": "A blok asansoru iki gundur calismiyor, kontrol edilebilir mi?",
                "y": "Servis cagrildi, asansor onarildi. Bildiriminiz icin tesekkurler.",
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
                "b": "Oneri: bahceye bank",
                "m": "Cocuk parkinin yanina birkac bank konulmasini oneriyorum.",
            },
        )
        #    c) kategorili sikayet: gurultu kirliligi (acik, yanitsiz).
        #       Kategori alani opsiyonel — a/b kayitlari kategorisiz kalir
        #       (geriye uyumluluk ornegi).
        conn.execute(
            """
            INSERT INTO complaint (tenant_id, acan_user_id, baslik, mesaj, kategori)
            SELECT %(t)s, r.id, %(b)s, %(m)s, 'gurultu'::complaint_kategori
            FROM app_user r
            WHERE r.tenant_id = %(t)s AND r.email = 'resident@acme.com'
              AND NOT EXISTS (
                  SELECT 1 FROM complaint
                  WHERE tenant_id = %(t)s AND baslik = %(b)s
              )
            """,
            {
                "t": tenant_id,
                "b": "Gece gec saatte muzik",
                "m": "B blok 3. kattan gece yarisindan sonra yuksek sesli muzik geliyor.",
            },
        )
        print(
            "[seed] sikayet 'Asansor ariziliydi' (cozuldu+yanitli) + oneri 'Oneri: bahceye bank' (acik) "
            "+ sikayet 'Gece gec saatte muzik' (kategori=gurultu)"
        )

        # 6) ornek ziyaretci: A-12 icin (guvenlik acmis) — HEDEF sakin
        #    resident@acme.com. Bir BEKLEYEN (Onayla/Reddet karti) + bir
        #    ONAYLANMIS (sonuc gorunsun) kayit. Push/gorunurluk/karar YALNIZ
        #    hedef sakinde (tek hedef modeli, A). Ziyaretci adiyla idempotent.
        guard_id = conn.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND email='guard@acme.com'",
            (tenant_id,),
        ).fetchone()[0]
        target_id = conn.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND email='resident@acme.com'",
            (tenant_id,),
        ).fetchone()[0]
        for ad, notlar, durum in (
            ("Kurye - Ahmet Yilmaz", "Kargo teslimati (koli)", "bekliyor"),
            ("Misafir - Ayse Kaya", "Aksam yemegi misafiri", "onaylandi"),
        ):
            yanitlayan = target_id if durum == "onaylandi" else None
            conn.execute(
                """
                INSERT INTO visitor (tenant_id, unit_id, ziyaretci_ad, notlar,
                                     kaydeden_user_id, target_resident_user_id,
                                     durum, yanitlayan_user_id, yanit_zamani)
                SELECT %(t)s, %(u)s, %(ad)s, %(n)s, %(g)s, %(r)s,
                       %(d)s::visitor_durum, %(y)s,
                       CASE WHEN %(d)s = 'onaylandi' THEN now() END
                WHERE NOT EXISTS (
                    SELECT 1 FROM visitor
                    WHERE tenant_id = %(t)s AND ziyaretci_ad = %(ad)s
                )
                """,
                {
                    "t": tenant_id, "u": unit_id, "ad": ad, "n": notlar,
                    "g": guard_id, "r": target_id, "d": durum, "y": yanitlayan,
                },
            )
        print(
            "[seed] ziyaretci 'Kurye - Ahmet Yilmaz' (bekliyor) + "
            "'Misafir - Ayse Kaya' (onaylandi) A-12 -> hedef resident@acme.com"
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
                "n": "Orta boy koli — kapida teslim alindi",
            },
        )
        print("[seed] kargo 'Aras Kargo' A-12 (bekliyor, guvenlik kaydi)")

        # 7b) ornek DAIRE-SIKAYETI (D1 — ANONIM yogunluk): A-12 YESIL (2 acik),
        #     yeni daire B-2 SARI (3 acik). Sikayet edenler ASLA gorunmez; bu
        #     yalniz renk/harita verisi uretir. complainant_user_id ic alandir.
        conn.execute(
            """
            INSERT INTO unit (tenant_id, no, blok) VALUES (%s, 'B-2', 'B')
            ON CONFLICT (tenant_id, no) DO NOTHING
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
            (unit_id, "resident2@acme.com", "ayakkabi"),
            (b2_id, "resident@acme.com", "gurultu"),
            (b2_id, "resident2@acme.com", "gurultu"),
            (b2_id, "resident3@acme.com", "diger"),
        ]
        for tgt, email, kat in _uc:
            conn.execute(
                """
                INSERT INTO unit_complaint
                    (tenant_id, target_unit_id, complainant_user_id, kategori, notlar)
                VALUES (%s, %s, %s, %s::unit_complaint_kategori, %s)
                ON CONFLICT (tenant_id, target_unit_id, complainant_user_id)
                    WHERE durum = 'acik' DO NOTHING
                """,
                (tenant_id, tgt, _res_ids[email], kat, "Örnek daire şikayeti"),
            )
        print("[seed] daire-sikayeti (D1 anonim): A-12 yesil (2 acik), B-2 sari (3 acik)")

        # 8) ortak alanlar + ornek rezervasyon: Havuz'da A-12 icin ONAYLI slot
        #    (cakisma kisiti/ekranlar veriyle denensin). Alan upsert (tenant+ad
        #    benzersiz); rezervasyon (alan, tarih, baslangic) uzerinden idempotent.
        alan_ids: dict[str, str] = {}
        for ad, aciklama in [
            ("Havuz", "Acik yuzme havuzu (yaz sezonu)"),
            ("Toplanti Odasi", "12 kisilik toplanti odasi (projektorlu)"),
        ]:
            alan_ids[ad] = conn.execute(
                """
                INSERT INTO ortak_alan (tenant_id, ad, aciklama)
                VALUES (%s, %s, %s)
                ON CONFLICT ON CONSTRAINT uq_ortak_alan_tenant_ad
                    DO UPDATE SET aciklama = EXCLUDED.aciklama, aktif = true
                RETURNING id
                """,
                (tenant_id, ad, aciklama),
            ).fetchone()[0]
        print("[seed] ortak alanlar: Havuz, Toplanti Odasi")

        resident_id = conn.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND email=%s",
            (tenant_id, "resident@acme.com"),
        ).fetchone()[0]
        conn.execute(
            """
            INSERT INTO rezervasyon (tenant_id, alan_id, unit_id, talep_eden_user_id,
                                     tarih, baslangic, bitis, kisi_sayisi, notlar,
                                     durum, onaylayan_user_id, karar_zamani)
            SELECT %(t)s, %(alan)s, %(u)s, %(r)s, %(tarih)s, %(bas)s, %(bit)s,
                   4, 'Aile yuzme saati', 'onaylandi'::rezervasyon_durum, %(y)s, now()
            WHERE NOT EXISTS (
                SELECT 1 FROM rezervasyon
                WHERE tenant_id = %(t)s AND alan_id = %(alan)s
                  AND tarih = %(tarih)s AND baslangic = %(bas)s
            )
            """,
            {
                "t": tenant_id, "alan": alan_ids["Havuz"], "u": unit_id,
                "r": resident_id, "y": yonetici_id,
                "tarih": "2026-07-15", "bas": "10:00", "bit": "12:00",
            },
        )
        print("[seed] rezervasyon Havuz 2026-07-15 10:00-12:00 A-12 (onayli, 4 kisi)")

        # 9) etkinlikler + ornek RSVP'ler: yaklasan "Mac izleme" (2 katiliyor)
        #    + gecmis "Site genel kurulu" — sayac/ekranlar veriyle denensin.
        #    Etkinlik (tenant, baslik) ile idempotent; RSVP UNIQUE ile.
        etkinlikler = [
            ("Mac izleme aksami", "Buyuk ekranda milli mac — ikramlar yonetimden.",
             "2026-07-20T18:00:00Z", "Sosyal tesis salonu"),
            ("Site genel kurulu", "Yillik olagan genel kurul toplantisi.",
             "2026-06-15T17:00:00Z", "Toplanti Odasi"),
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
        print("[seed] etkinlikler: 'Mac izleme aksami' (yaklasan) + 'Site genel kurulu' (gecmis)")

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
                {"t": tenant_id, "e": etkinlik_ids["Mac izleme aksami"], "m": email},
            )
        print("[seed] RSVP: 2 sakin 'Mac izleme aksami' icin katiliyorum (seffaf sayi=2)")

        # 10) site kurallari: 3 ornek kural (sira ile) — liste + baslik
        #     aramasi veriyle denensin. (tenant, baslik) ile idempotent;
        #     fotosuz (foto gercek akista presign ile yuklenir).
        kurallar = [
            (1, "Otopark Kullanimi",
             "Her daireye bir otopark yeri ayrilmistir. Misafir araclari "
             "yalniz misafir otoparkini kullanabilir; yer degisimi yonetim "
             "onayina tabidir."),
            (2, "Havuz Saatleri",
             "Havuz 08:00-22:00 arasi acik; 12 yas alti cocuklar veli "
             "gozetiminde girebilir. Havuz alanina cam esya sokulmaz."),
            (3, "Gurultu Kurallari",
             "Hafta ici 22:00-08:00, hafta sonu 24:00-10:00 arasi gurultu "
             "yasaktir. Tadilat yalniz hafta ici 09:00-18:00 arasi yapilabilir."),
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
        print("[seed] site kurallari: Otopark Kullanimi (1), Havuz Saatleri (2), Gurultu Kurallari (3)")

    print("[seed] tamamlandi (idempotent).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
