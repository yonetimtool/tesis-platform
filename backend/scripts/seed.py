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
from datetime import datetime, timedelta, timezone

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

# Seed gorselleri MinIO'ya EN-IYI-CABA yuklenir. api/seed konteynerindeki
# MINIO_ENDPOINT presign icin PUBLIC adrestir (tarayici/cihaz erisir); yukleme
# ise IC agdan yapilir -> ayri degisken. Erisilemezse seed DURMAZ: foto_key
# yine yazilir (API sekli/akisi denenebilir), yalniz gorsel gorunmez.
MINIO_SEED_ENDPOINT = os.getenv("MINIO_SEED_ENDPOINT", "http://minio:9000")
MINIO_BUCKET = os.getenv("MINIO_BUCKET", "tesis-foto")
MINIO_KEY = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET = os.getenv("MINIO_SECRET_KEY", "minioadmin12345")


def _solid_png(width: int, height: int, rgb: tuple[int, int, int]) -> bytes:
    """Bagimliliksiz (PIL yok) tek-renk PNG — seed gorselleri icin yeterli."""
    import struct
    import zlib

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    satir = b"\x00" + bytes(rgb) * width  # filter byte + RGB pikseller
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(satir * height, 6))
        + chunk(b"IEND", b"")
    )


def _gorsel_yukle(tenant_id: str, ad: str, rgb: tuple[int, int, int]) -> str:
    """Seed gorselini MinIO'ya yazar ve foto_key doner (idempotent: ayni ad ->
    ayni anahtar, PUT ustune yazar). Yukleme basarisiz olursa UYARI basar ve
    anahtari yine doner — DB kaydi tutarli kalir, yalniz obje eksik olur.

    Anahtar tenant ile namespace'lidir (`{tenant_id}/seed/...`): API'nin
    IDOR kontrolu (foto_key tenant onekiyle baslamali) saglanir.
    """
    key = f"{tenant_id}/seed/{ad}.png"
    try:
        import boto3
        from botocore.client import Config

        boto3.client(
            "s3",
            endpoint_url=MINIO_SEED_ENDPOINT,
            aws_access_key_id=MINIO_KEY,
            aws_secret_access_key=MINIO_SECRET,
            config=Config(signature_version="s3v4",
                          s3={"addressing_style": "path"}),
        ).put_object(
            Bucket=MINIO_BUCKET,
            Key=key,
            Body=_solid_png(800, 480, rgb),
            ContentType="image/png",
        )
    except Exception as exc:  # pragma: no cover - dev araci; depo yoksa atla
        print(f"[seed] UYARI gorsel yuklenemedi ({key}): {exc}")
    return key

TENANT = {
    "slug": "acme-plaza",
    "ad": "Acme Plaza",
    "timezone": "Europe/Istanbul",
    "yonetim_email": "yonetim@acme.com",
    # G4: otopark kapasitesi -> GET /parking/occupancy gercek oran doner
    # (kapasite tanimsiz olsaydi kapasite+oran null gelirdi).
    "otopark_kapasite": 120,
}

USERS = [
    {
        "ad": "Acme Admin",
        "email": "admin@acme.com",
        "role": "admin",
        "password": os.getenv("SEED_ADMIN_PASSWORD", "Admin123!"),
        # MOBIL GIRIS telefonla yapilir (POST /auth/login-phone); e-posta+tesis
        # kodu YALNIZ panelde (POST /auth/login) kullanilir. Telefonu olmayan
        # admin mobilde HIC giris yapamiyordu — dev'de admin duzenini mobilde
        # denemek icin numara verildi (blogun basi: 200).
        "telefon": "+905321112200",
        # Platform operatoru: rol-bazli aramaya (C1a) ACIK DEGIL.
        "aranabilir": False,
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
        # gosterir. NOT: telefon GLOBAL benzersiz — 200-206 zaten dolu
        # (200 admin, 201 yonetici, 202 guard, 203 sakin, 204 cleaner,
        # 205 sakin-3, 206 sakin-es asagida ayri INSERT'te) -> 207.
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
            INSERT INTO tenant (ad, slug, timezone, yonetim_email, otopark_kapasite)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (slug) DO UPDATE
                SET ad = EXCLUDED.ad, timezone = EXCLUDED.timezone,
                    yonetim_email = EXCLUDED.yonetim_email,
                    otopark_kapasite = EXCLUDED.otopark_kapasite
            RETURNING id
            """,
            (
                TENANT["ad"], TENANT["slug"], TENANT["timezone"],
                TENANT["yonetim_email"], TENANT["otopark_kapasite"],
            ),
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
            -- P28 REGRESYONU: `(tenant_id, unit_id, donem)` KISITI ARTIK
            -- YOK — benzersizlik `COALESCE(gelir_gider_tanim_id, ...)`
            -- iceren bir INDEKSE cevrildi. Hedefli `ON CONFLICT` hicbir
            -- kisitla eslesmiyor ve seed'i DUSURUYORDU. Hedefsiz bicim
            -- hangi kisit ihlal olursa olsun calisir.
            ON CONFLICT DO NOTHING
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

        # Vardiya tanimlari — mobil saha ana ekrani "Vardiya Durumu" bolumu
        # (GET /shifts; RBAC admin+security+tesis_gorevlisi). Gece vardiyasi
        # bilerek gece-sarkmali (22:00-06:00): istemcinin aktifMi hesabinin
        # sarkma dalini dev veride de gorunur kilar. shift'te benzersiz kisit
        # yok -> (tenant_id, ad) uzerinden NOT EXISTS ile idempotent.
        for _ad, _bas, _bit, _gun in [
            ("Sabah Vardiyası", "06:00", "14:00", "hafta_ici"),
            ("Öğle Vardiyası", "14:00", "22:00", "her_gun"),
            ("Gece Vardiyası", "22:00", "06:00", "her_gun"),
        ]:
            conn.execute(
                """
                INSERT INTO shift (tenant_id, ad, baslangic_saat, bitis_saat, gun_tipi)
                SELECT %s, %s, %s::time, %s::time, %s::gun_tipi
                WHERE NOT EXISTS (
                    SELECT 1 FROM shift WHERE tenant_id = %s AND ad = %s
                )
                """,
                (tenant_id, _ad, _bas, _bit, _gun, tenant_id, _ad),
            )
        print("[seed] vardiyalar: Sabah 06-14 (hafta_ici), Öğle 14-22, Gece 22-06")

        # Vardiya personel atamasi (0005/WP-E) — saha personelini (security +
        # tesis_gorevlisi) TUM vardiyalara ata; yonetici dashboard'undaki
        # "Vardiya Durumu" kartlari referanstaki gibi personelli (foto +
        # "N Görevli") gorunsun. Foto'yu yonetici StaffScreen'den yukler; atama
        # olmadan yuklenen foto vardiya kartinda gorunmezdi (eksik halka).
        # UNIQUE(tenant_id, shift_id, user_id) -> ON CONFLICT ile idempotent.
        conn.execute(
            """
            INSERT INTO shift_assignment (tenant_id, shift_id, user_id)
            SELECT s.tenant_id, s.id, u.id
            FROM shift s
            JOIN app_user u
              ON u.tenant_id = s.tenant_id
             AND u.role IN ('security', 'tesis_gorevlisi')
            WHERE s.tenant_id = %s
            ON CONFLICT (tenant_id, shift_id, user_id) DO NOTHING
            """,
            (tenant_id,),
        )
        print("[seed] vardiya atamalari: saha personeli -> tum vardiyalar")


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

        # 3b) Seffaflik Panosu: 2026-06'yi YAYINLA (demo — sakin ekraninda gorunur).
        #     Tablo yoksa (0003 uygulanmamis — prod-upgrade sim) sessizce atla.
        if conn.execute(
            "SELECT to_regclass('public.transparency_publication')"
        ).fetchone()[0] is not None:
            conn.execute(
                """
                INSERT INTO transparency_publication (tenant_id, ay, yayin)
                VALUES (%s, '2026-06', true)
                ON CONFLICT (tenant_id, ay) DO UPDATE SET yayin = true
                """,
                (tenant_id,),
            )
            print("[seed] seffaflik: 2026-06 yayinlandi (demo)")

        # 4) ornek duyuru (yonetici imzali). Dogal benzersiz anahtar yok ->
        #    ayni baslik varsa eklemeyerek idempotent kalinir.
        conn.execute(
            """
            INSERT INTO announcement
                (tenant_id, baslik, govde, olusturan_user_id, foto_key)
            SELECT %(t)s, %(b)s, %(g)s, u.id, %(f)s
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
                "f": _gorsel_yukle(tenant_id, "duyuru-hosgeldiniz", (14, 149, 148)),
            },
        )
        # Duyuru zaten varsa insert atlanir; gorseli ayrica yaz.
        conn.execute(
            """
            UPDATE announcement SET foto_key = %(f)s
             WHERE tenant_id = %(t)s AND baslik = 'Hoş geldiniz'
               AND foto_key IS NULL
            """,
            {"t": tenant_id,
             "f": _gorsel_yukle(tenant_id, "duyuru-hosgeldiniz", (14, 149, 148))},
        )
        print("[seed] duyuru 'Hoş geldiniz' (yonetici imzali, GORSELLI, idempotent)")

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

        # 5b) talep timeline'lari (Task 9 — ticketing reshape): yukaridaki 3
        #     eski-sekil sikayetin GECMISI yoktu (bkz. 5. yorum); yeni modelde
        #     her talep en az [acik] satiri tasimalidir, aksi taktirde
        #     timeline bos gorunur (celiskili/eksik veri). Burada tamamlanir.
        def _add_hist(baslik: str, durum: str, actor_role: str, sebep: str | None) -> None:
            """complaint_status_history satiri — (complaint,durum) ciftine
            gore idempotent (WHERE NOT EXISTS)."""
            conn.execute(
                """
                INSERT INTO complaint_status_history
                    (tenant_id, complaint_id, durum, actor_role, sebep)
                SELECT %(t)s, c.id, %(d)s::complaint_durum, %(r)s::user_role, %(s)s
                FROM complaint c
                WHERE c.tenant_id = %(t)s AND c.baslik = %(b)s
                  AND NOT EXISTS (
                      SELECT 1 FROM complaint_status_history
                      WHERE tenant_id = %(t)s AND complaint_id = c.id
                        AND durum = %(d)s::complaint_durum
                  )
                """,
                {"t": tenant_id, "b": baslik, "d": durum, "r": actor_role, "s": sebep},
            )

        _add_hist("Asansör arızalıydı", "acik", "resident", None)
        _add_hist(
            "Asansör arızalıydı", "cozuldu", "yonetici", "Asansör bakım firması onardı."
        )
        _add_hist("Öneri: bahçeye bank", "acik", "resident", None)
        _add_hist("Gece geç saatte müzik", "acik", "resident", None)
        print(
            "[seed] talep gecmisi (timeline) tamamlandi: Asansör [acik,cozuldu], "
            "Öneri [acik], Gece geç saatte müzik [acik]"
        )

        # 5c) demo talep kategorisi (task_category, A6) — talep/is-emri
        #     ornekleri icin. Ad benzersiz (tenant_id, ad) -> ON CONFLICT upsert.
        tesisat_kat_id = conn.execute(
            """
            INSERT INTO task_category (tenant_id, ad)
            VALUES (%s, 'Tesisat')
            ON CONFLICT ON CONSTRAINT uq_task_category_tenant_ad
                DO UPDATE SET aktif = true, updated_at = now()
            RETURNING id
            """,
            (tenant_id,),
        ).fetchone()[0]
        print(f"[seed] talep kategorisi 'Tesisat' -> {tesisat_kat_id}")

        # 5d) 4 demo talep (Task 9 — durum makinesinin TUM asamalarini kapsar,
        #     frontend/kabul testleri icin): acik (fotosuz), acik (fotolu),
        #     is_emri (bagli gorev), cozuldu (tamamlama kanitiyla oto-coz).
        #     Atanan saha personeli: guard@acme.com (security) + cleaner@acme.com
        #     (tesis_gorevlisi) — is-emri atamasinin iki saha rolunu de gostersin.
        guard_id = conn.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND email='guard@acme.com'",
            (tenant_id,),
        ).fetchone()[0]
        cleaner_id = conn.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND email='cleaner@acme.com'",
            (tenant_id,),
        ).fetchone()[0]

        def _upsert_complaint(
            baslik: str, mesaj: str, kategori_id: str | None
        ) -> str:
            """INSERT ... WHERE NOT EXISTS + var olani SELECT (etkinlik ile
            ayni CTE deseni) — her zaman complaint.id doner, idempotent."""
            return conn.execute(
                """
                WITH yeni AS (
                    INSERT INTO complaint
                        (tenant_id, acan_user_id, baslik, mesaj, kategori_id)
                    SELECT %(t)s, r.id, %(b)s, %(m)s, %(k)s
                    FROM app_user r
                    WHERE r.tenant_id = %(t)s AND r.email = 'resident@acme.com'
                      AND NOT EXISTS (
                          SELECT 1 FROM complaint WHERE tenant_id = %(t)s AND baslik = %(b)s
                      )
                    RETURNING id
                )
                SELECT id FROM yeni
                UNION ALL
                SELECT id FROM complaint WHERE tenant_id = %(t)s AND baslik = %(b)s
                LIMIT 1
                """,
                {"t": tenant_id, "b": baslik, "m": mesaj, "k": kategori_id},
            ).fetchone()[0]

        def _add_photo(complaint_id: str, foto_key: str, sira: int) -> None:
            conn.execute(
                """
                INSERT INTO complaint_photo (tenant_id, complaint_id, foto_key, sira)
                SELECT %(t)s, %(c)s, %(k)s, %(s)s
                WHERE NOT EXISTS (
                    SELECT 1 FROM complaint_photo
                    WHERE tenant_id = %(t)s AND complaint_id = %(c)s AND foto_key = %(k)s
                )
                """,
                {"t": tenant_id, "c": complaint_id, "k": foto_key, "s": sira},
            )

        # -- Demo 1: acik, fotosuz, kategorisiz ("Diğer").
        demo1_id = _upsert_complaint(
            "Demo talep 1: Bahçe musluğu damlatıyor",
            "Bahçe musluğu sürekli damlatıyor, contası değişebilir mi?",
            None,
        )
        conn.execute(
            "INSERT INTO complaint_status_history "
            "(tenant_id, complaint_id, durum, actor_role, sebep) "
            "SELECT %(t)s, %(c)s, 'acik', 'resident'::user_role, NULL "
            "WHERE NOT EXISTS (SELECT 1 FROM complaint_status_history "
            "WHERE tenant_id=%(t)s AND complaint_id=%(c)s AND durum='acik')",
            {"t": tenant_id, "c": demo1_id},
        )

        # -- Demo 2: acik, 2 foto (tenant-onekli MinIO anahtari), kategorili.
        demo2_id = _upsert_complaint(
            "Demo talep 2: Otopark bariyeri kırık (fotoğraflı)",
            "Otopark girişindeki bariyer kırıldı, araçlar giriş yapamıyor.",
            tesisat_kat_id,
        )
        # Anahtarlar `_gorsel_yukle` ile URETILIR: eskiden sabit
        # `{tenant}/tasks/seed-foto-1.jpg` yaziliyordu ama o obje MinIO'ya HIC
        # yuklenmiyordu — presigned URL gecerli, obje YOK (NoSuchKey) ve panel
        # de mobil de KIRIK GORSEL gosteriyordu (tur 35'te olculdu).
        conn.execute(
            "DELETE FROM complaint_photo WHERE tenant_id = %(t)s "
            "AND foto_key LIKE %(k)s",
            {"t": tenant_id, "k": f"{tenant_id}/tasks/seed-foto-%"},
        )
        _add_photo(demo2_id, _gorsel_yukle(tenant_id, "talep-bariyer-1", (220, 38, 38)), 0)
        _add_photo(demo2_id, _gorsel_yukle(tenant_id, "talep-bariyer-2", (37, 99, 235)), 1)
        conn.execute(
            "INSERT INTO complaint_status_history "
            "(tenant_id, complaint_id, durum, actor_role, sebep) "
            "SELECT %(t)s, %(c)s, 'acik', 'resident'::user_role, NULL "
            "WHERE NOT EXISTS (SELECT 1 FROM complaint_status_history "
            "WHERE tenant_id=%(t)s AND complaint_id=%(c)s AND durum='acik')",
            {"t": tenant_id, "c": demo2_id},
        )

        # -- Demo 3: is_emri — donusturuldu (convert_complaint ile ayni sekil:
        #    bagli task, oncelik=orta, atanan=security).
        demo3_id = _upsert_complaint(
            "Demo talep 3: Kombi arızası (iş emri)",
            "B blok kazan dairesindeki kombi ısıtma yapmıyor.",
            tesisat_kat_id,
        )
        conn.execute(
            """
            INSERT INTO task (tenant_id, ad, aciklama, atanan_user_id, kategori_id,
                              oncelik, ticket_id, foto_zorunlu)
            SELECT %(t)s, c.baslik, c.mesaj, %(a)s, %(k)s, 'orta'::task_oncelik,
                   c.id, false
            FROM complaint c
            WHERE c.id = %(c)s
              AND NOT EXISTS (SELECT 1 FROM task WHERE tenant_id = %(t)s AND ticket_id = %(c)s)
            """,
            {"t": tenant_id, "c": demo3_id, "a": guard_id, "k": tesisat_kat_id},
        )
        conn.execute(
            "UPDATE complaint SET durum='is_emri', updated_at=now() "
            "WHERE tenant_id=%(t)s AND id=%(c)s AND durum <> 'is_emri'",
            {"t": tenant_id, "c": demo3_id},
        )
        for durum, role, sebep in (
            ("acik", "resident", None),
            ("is_emri", "yonetici", "Kombi ustasına iş emri açıldı."),
        ):
            conn.execute(
                "INSERT INTO complaint_status_history "
                "(tenant_id, complaint_id, durum, actor_role, sebep) "
                "SELECT %(t)s, %(c)s, %(d)s::complaint_durum, %(r)s::user_role, %(s)s "
                "WHERE NOT EXISTS (SELECT 1 FROM complaint_status_history "
                "WHERE tenant_id=%(t)s AND complaint_id=%(c)s AND durum=%(d)s::complaint_durum)",
                {"t": tenant_id, "c": demo3_id, "d": durum, "r": role, "s": sebep},
            )

        # -- Demo 4: is_emri -> cozuldu (task_completion kaniti ile OTO-COZ —
        #    tasks router'daki /completions ile ayni sekil: foto_key kaniti,
        #    complaint.durum=cozuldu, actor_role=tamamlayanin rolu).
        demo4_id = _upsert_complaint(
            "Demo talep 4: Su sızıntısı onarıldı (tamamlanmış, kanıtlı)",
            "A blok zemin kat tavanından su sızıyor, acil kontrol gerekiyor.",
            tesisat_kat_id,
        )
        demo4_task_id = conn.execute(
            """
            WITH yeni AS (
                INSERT INTO task (tenant_id, ad, aciklama, atanan_user_id, kategori_id,
                                  oncelik, ticket_id, foto_zorunlu)
                SELECT %(t)s, c.baslik, c.mesaj, %(a)s, %(k)s, 'orta'::task_oncelik,
                       c.id, false
                FROM complaint c
                WHERE c.id = %(c)s
                  AND NOT EXISTS (SELECT 1 FROM task WHERE tenant_id = %(t)s AND ticket_id = %(c)s)
                RETURNING id
            )
            SELECT id FROM yeni
            UNION ALL
            SELECT id FROM task WHERE tenant_id = %(t)s AND ticket_id = %(c)s
            LIMIT 1
            """,
            {"t": tenant_id, "c": demo4_id, "a": cleaner_id, "k": tesisat_kat_id},
        ).fetchone()[0]
        conn.execute(
            """
            INSERT INTO task_completion
                (tenant_id, task_id, tamamlayan_user_id, tamamlanma_zamani,
                 foto_key, notlar, idempotency_key)
            VALUES (%s, %s, %s, now(), %s, %s, %s)
            -- (P131) DO NOTHING DEGIL DO UPDATE: `foto_key` eski tohumda
            -- YUKLENMEYEN bir anahtara (seed-completion-1.jpg) isaret
            -- ediyordu ve DO NOTHING yuzunden yeniden tohumlama onu ASLA
            -- duzeltmiyordu. Sonuc: gelistirme veritabaninda kirik bir
            -- gorsel — ve "web'de gorseller cikmiyor" teshisini zorlastiran
            -- ikinci bir belirti. Idempotency anahtari ayni kaldigi icin
            -- tekrar tohumlama hâlâ tek kayit uretir.
            ON CONFLICT ON CONSTRAINT uq_completion_tenant_idempotency
            DO UPDATE SET foto_key = EXCLUDED.foto_key
            """,
            (
                tenant_id, demo4_task_id, cleaner_id,
                # Ayni sebep: sabit anahtar yerine GERCEKTEN yuklenen obje.
                _gorsel_yukle(tenant_id, "tamamlama-kaniti-1", (22, 163, 74)),
                "Sızıntı contası değiştirildi, kanıt fotoğrafı eklendi.",
                "seed-demo-talep-4-completion",
            ),
        )
        conn.execute(
            "UPDATE complaint SET durum='cozuldu', updated_at=now() "
            "WHERE tenant_id=%(t)s AND id=%(c)s AND durum <> 'cozuldu'",
            {"t": tenant_id, "c": demo4_id},
        )
        for durum, role, sebep in (
            ("acik", "resident", None),
            ("is_emri", "yonetici", "Tesis görevlisine iş emri açıldı."),
            ("cozuldu", "tesis_gorevlisi", "Sızıntı contası değiştirildi (kanıt fotoğraflı)."),
        ):
            conn.execute(
                "INSERT INTO complaint_status_history "
                "(tenant_id, complaint_id, durum, actor_role, sebep) "
                "SELECT %(t)s, %(c)s, %(d)s::complaint_durum, %(r)s::user_role, %(s)s "
                "WHERE NOT EXISTS (SELECT 1 FROM complaint_status_history "
                "WHERE tenant_id=%(t)s AND complaint_id=%(c)s AND durum=%(d)s::complaint_durum)",
                {"t": tenant_id, "c": demo4_id, "d": durum, "r": role, "s": sebep},
            )

        print(
            "[seed] 4 demo talep: 'Demo talep 1' (acik, fotosuz) + "
            "'Demo talep 2' (acik, 2 foto) + 'Demo talep 3' (is_emri, "
            "atanan=guard) + 'Demo talep 4' (cozuldu, tamamlama-kanitli, "
            "atanan=cleaner) — hepsi tam timeline ile"
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
        # 6b) G3: kuryenin CIKISI damgalanir -> "icerde" sayaci gercek deger
        #     uretir (Kurye cikti, Misafir hala iceride). WHERE cikis_zamani
        #     IS NULL sayesinde ikinci kosumda damga DEGISMEZ (idempotent).
        conn.execute(
            """
            UPDATE visitor SET cikis_zamani = now() - interval '30 minutes'
            WHERE tenant_id = %s AND ziyaretci_ad = 'Kurye - Ahmet Yılmaz'
              AND cikis_zamani IS NULL
            """,
            (tenant_id,),
        )
        print(
            "[seed] ziyaretci (LOG) 'Kurye - Ahmet Yılmaz' (CIKTI) + "
            "'Misafir - Ayşe Kaya' (ICERIDE) A-12 -> hedef resident@acme.com"
        )

        # 6c) G1+G4: arac gecisleri — 3 ACIK (otopark dolu=3) + 1 kapanmis.
        #     plaka NORMALIZE (bosluksuz + BUYUK) saklanir; ayni plakadan tek
        #     acik gecis olabildigi icin plaka ile idempotent.
        for plaka, tanim, ziyaretci_mi, daireli, kapali in (
            ("34ABC123", "BMW Siyah", False, True, False),
            ("06XYZ789", "Renault Clio Beyaz", True, False, False),
            ("35DEF456", "Ford Transit (Kargo)", True, False, False),
            ("34GHI321", "Toyota Corolla Gri", False, True, True),
        ):
            conn.execute(
                """
                INSERT INTO vehicle_pass (tenant_id, plaka, arac_tanim, unit_id,
                                          ziyaretci_mi, kaydeden_user_id,
                                          giris_zamani, cikis_zamani)
                SELECT %(t)s, %(p)s, %(a)s, %(u)s, %(z)s, %(g)s,
                       now() - interval '3 hours',
                       CASE WHEN %(k)s THEN now() - interval '1 hour' END
                WHERE NOT EXISTS (
                    SELECT 1 FROM vehicle_pass
                    WHERE tenant_id = %(t)s AND plaka = %(p)s
                )
                """,
                {
                    "t": tenant_id, "p": plaka, "a": tanim,
                    "u": unit_id if daireli else None,
                    "z": ziyaretci_mi, "g": guard_id, "k": kapali,
                },
            )
        print(
            "[seed] arac gecisi: 3 ACIK (34ABC123, 06XYZ789, 35DEF456) + "
            "1 kapanmis (34GHI321) -> /parking/occupancy dolu=3/120 (%3)"
        )

        # 6d) G2: ihlal kayitlari — 2 'yeni' (ana ekran sayaci), 1 inceleniyor,
        #     1 kapatildi. Baslik ile idempotent.
        for baslik, aciklama, kaynak, konum, durum in (
            ("Otopark girişinde hatalı park", "Yangın yolu üzerine park edilmiş araç.",
             "kamera", "Otopark Girişi - Kamera 3", "yeni"),
            ("Gece 23:00 sonrası gürültü", "B blok bahçesinde yüksek sesli müzik.",
             "manuel", "B Blok Bahçe", "yeni"),
            ("Çöp konteyneri dışına atık", "Ayrıştırılmamış atık poşetleri.",
             "devriye", "Çöp Toplama Alanı", "inceleniyor"),
            ("Ziyaretçi aracı yaya yolunda", "Uyarı yapıldı, araç kaldırıldı.",
             "kamera", "Ana Kapı - Kamera 1", "kapatildi"),
        ):
            conn.execute(
                """
                INSERT INTO violation (tenant_id, baslik, aciklama, kaynak,
                                       konum, durum, olusturan_user_id)
                SELECT %(t)s, %(b)s, %(a)s, %(k)s::violation_kaynak, %(ko)s,
                       %(d)s::violation_durum, %(g)s
                WHERE NOT EXISTS (
                    SELECT 1 FROM violation
                    WHERE tenant_id = %(t)s AND baslik = %(b)s
                )
                """,
                {
                    "t": tenant_id, "b": baslik, "a": aciklama, "k": kaynak,
                    "ko": konum, "d": durum, "g": guard_id,
                },
            )
        print(
            "[seed] ihlal: 2 'yeni' + 1 'inceleniyor' + 1 'kapatildi' "
            "(?durum=yeni sayaci = 2)"
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
        print("[seed] etkinlikler: 'Maç izleme akşamı' + 'Site genel kurulu' (ikisi de gecmis tarihli)")

        # 9b) YAKLASAN 2 etkinlik + GORSEL: sakin ana ekraninin "yaklasan
        #     etkinlikler" bolumu (?aktif=true) her zaman veriyle gorunsun.
        #     Tarihler GORELIDIR (now() + interval) — seed ne zaman kosarsa
        #     kossun etkinlikler yaklasan kalir. bitis_zamani dolu: etkinlik
        #     BITENE kadar listede durur (COALESCE(bitis, tarih) >= now()).
        yaklasan = [
            ("Bahar şenliği", "Bahçede müzik, ikram ve çocuklar için oyun alanı.",
             "3 days", "5 hours", "Site bahçesi", "etkinlik-bahar-senligi",
             (37, 99, 235)),
            ("Aidat bilgilendirme toplantısı",
             "2026 bütçesi ve aidat kalemleri sunumu; soru-cevap.",
             "10 days", "2 hours", "Toplantı Odası", "etkinlik-aidat-toplantisi",
             (13, 148, 136)),
        ]
        for baslik, aciklama, sonra, sure, konum, dosya, renk in yaklasan:
            foto_key = _gorsel_yukle(tenant_id, dosya, renk)
            conn.execute(
                f"""
                INSERT INTO etkinlik (tenant_id, baslik, aciklama, tarih,
                                      bitis_zamani, konum, foto_key,
                                      olusturan_user_id)
                SELECT %(t)s, %(b)s, %(a)s,
                       now() + interval '{sonra}',
                       now() + interval '{sonra}' + interval '{sure}',
                       %(k)s, %(f)s, %(y)s
                WHERE NOT EXISTS (
                    SELECT 1 FROM etkinlik
                    WHERE tenant_id = %(t)s AND baslik = %(b)s
                )
                """,
                {"t": tenant_id, "b": baslik, "a": aciklama, "k": konum,
                 "f": foto_key, "y": yonetici_id},
            )
            # BAYATLAMA ONLEMI (tur 55): kayit zaten varsa INSERT atlanir ve
            # tarih ILK kosumdan kalirdi — zamanla gecmise duser, "yaklasan
            # etkinlikler" bolumu bosalir. Tarih her kosumda tazelenir.
            conn.execute(
                f"""
                UPDATE etkinlik
                   SET tarih = now() + interval '{sonra}',
                       bitis_zamani = now() + interval '{sonra}'
                                      + interval '{sure}'
                 WHERE tenant_id = %(t)s AND baslik = %(b)s
                """,
                {"t": tenant_id, "b": baslik},
            )
        print("[seed] YAKLASAN etkinlikler (gorselli): 'Bahar şenliği' (+3g, 5s) + "
              "'Aidat bilgilendirme toplantısı' (+10g, 2s) -> ?aktif=true = 2")

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
        # Bir kurala GORSEL: sakin ana ekraninda gorselli kural bolumu
        # denenebilsin (gorsel akisi duyuru/etkinlik ile AYNI mekanizma).
        conn.execute(
            """
            UPDATE site_kurali SET foto_key = %(f)s
            WHERE tenant_id = %(t)s AND baslik = 'Otopark Kullanımı'
              AND foto_key IS DISTINCT FROM %(f)s
            """,
            {"t": tenant_id,
             "f": _gorsel_yukle(tenant_id, "kural-otopark", (234, 88, 12))},
        )
        print("[seed] site kurallari: Otopark Kullanımı (1, GORSELLI), "
              "Havuz Saatleri (2), Gürültü Kuralları (3)")

        # 10b) KAMERALAR (WP-H): tur karisimi + gorunurluk bayragi.
        #      URL'ler PUBLIC test yayinlaridir -> oynatma gercekten denenir.
        #      sakin/tesis gorevlisi YALNIZ aktif+sakin_gorebilir olanlari
        #      gorur: burada tam 2 kamera ('Ana Kapı', 'Otopark').
        kameralar = [
            ("Ana Kapı", "Ana Kapı - Giriş", "hls", True, True,
             "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"),
            ("Otopark", "Kapalı otopark -1", "hls", True, True,
             "https://devstreaming-cdn.apple.com/videos/streaming/examples/"
             "img_bipbop_adv_example_fmp4/master.m3u8"),
            # Havuz KVKK: kisiler goruntulenir -> sakine KAPALI (yonetim gorur).
            ("Havuz", "Havuz cevresi", "mp4", True, False,
             # NOT: eski ornek (commondatastorage.googleapis.com/gtv-videos-
             # bucket/...) artik 403 doner — public degil. Bu adres 206 +
             # video/mp4 ile dogrulandi.
             "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/"
             "Big_Buck_Bunny_360_10s_1MB.mp4"),
            # RTSP: kayit TUTULUR ama istemci oynatamaz -> oynatilabilir=false.
            ("Arka Bahçe NVR", "NVR kanal 4", "rtsp", True, False,
             "rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mp4"),
            # PASIF + sakine acik: aktif=false oldugu icin sakin GORMEZ
            # (iki kosul birlikte aranir).
            ("Servis Girişi (bakımda)", "Servis kapısı", "hls", False, True,
             "https://test-streams.mux.dev/pts_shift/master.m3u8"),
        ]
        for ad, konum, tur, aktif, sakin_gorebilir, url in kameralar:
            conn.execute(
                """
                INSERT INTO camera (tenant_id, ad, konum, stream_url, tur,
                                    aktif, sakin_gorebilir)
                SELECT %(t)s, %(ad)s, %(k)s, %(u)s, %(tur)s::camera_tur,
                       %(a)s, %(sg)s
                WHERE NOT EXISTS (
                    SELECT 1 FROM camera WHERE tenant_id = %(t)s AND ad = %(ad)s
                )
                """,
                {"t": tenant_id, "ad": ad, "k": konum, "u": url, "tur": tur,
                 "a": aktif, "sg": sakin_gorebilir},
            )
        print("[seed] kameralar: 5 kayit (3 hls + 1 mp4 + 1 rtsp) — sakin/gorevli "
              "YALNIZ 'Ana Kapı' + 'Otopark' gorur (aktif+sakin_gorebilir)")


        # ------------------------------------------------------------------
        # MUHASEBE "TANIMLAR" KATMANI (P27) — gercekci bir site kurulumu.
        # Hepsi IDEMPOTENT: `WHERE NOT EXISTS` ile ad/kod uzerinden.
        # ------------------------------------------------------------------
        kasalar = [
            ("KASA01", "Merkez Kasa", False, None, None, 250000),
            ("BNK01", "Ziraat Bankası - Site Hesabı", True,
             "TR330006100519786457841326", "Ziraat Bankası", 12500000),
        ]
        for kod, ad, banka, iban, banka_adi, acilis in kasalar:
            conn.execute(
                """
                INSERT INTO kasa (tenant_id, kod, ad, banka_mi, iban, banka_adi,
                                  acilis_bakiye_kurus, acilis_tarihi)
                SELECT %(t)s, %(kod)s, %(ad)s, %(b)s, %(iban)s, %(ba)s,
                       %(ac)s, DATE '2026-01-01'
                WHERE NOT EXISTS (
                    SELECT 1 FROM kasa WHERE tenant_id = %(t)s AND kod = %(kod)s
                )
                """,
                {"t": tenant_id, "kod": kod, "ad": ad, "b": banka,
                 "iban": iban, "ba": banka_adi, "ac": acilis},
            )

        for grup in ("Sabit Giderler", "Bakım-Onarım", "Personel", "Gelirler"):
            conn.execute(
                """
                INSERT INTO gelir_gider_grup (tenant_id, ad)
                SELECT %(t)s, %(ad)s
                WHERE NOT EXISTS (
                    SELECT 1 FROM gelir_gider_grup
                     WHERE tenant_id = %(t)s AND ad = %(ad)s
                )
                """,
                {"t": tenant_id, "ad": grup},
            )

        def _grup_id(ad: str):
            return conn.execute(
                "SELECT id FROM gelir_gider_grup WHERE tenant_id = %s AND ad = %s",
                (tenant_id, ad),
            ).fetchone()[0]

        # GELIR kalemlerinde dagitim sekli YOKTUR (tahsil edilir, dagitilmaz).
        gg_tanimlari = [
            ("Aidat", "gelir", "Gelirler", None),
            ("Kira Geliri (dükkan)", "gelir", "Gelirler", None),
            ("Elektrik", "gider", "Sabit Giderler", "bagimsiz_bolumlere_esit"),
            ("Su", "gider", "Sabit Giderler", "bagimsiz_bolumlere_esit"),
            ("Doğalgaz", "gider", "Sabit Giderler", "tipe_gore"),
            ("Asansör Bakımı", "gider", "Bakım-Onarım", "bagimsiz_bolumlere_esit"),
            ("Personel Maaşı", "gider", "Personel", "bagimsiz_bolumlere_esit"),
            ("Demirbaş Alımı", "her_ikisi", "Bakım-Onarım", "tipe_gore"),
        ]
        for ad, tip, grup, dagitim in gg_tanimlari:
            conn.execute(
                """
                INSERT INTO gelir_gider_tanim (tenant_id, ad, tip, grup_id,
                                               dagitim_sekli)
                SELECT %(t)s, %(ad)s, %(tip)s::gelir_gider_tip, %(g)s,
                       %(d)s::gelir_gider_dagitim
                WHERE NOT EXISTS (
                    SELECT 1 FROM gelir_gider_tanim
                     WHERE tenant_id = %(t)s AND ad = %(ad)s
                )
                """,
                {"t": tenant_id, "ad": ad, "tip": tip, "g": _grup_id(grup),
                 "d": dagitim},
            )

        firmalar = [
            ("Kone Asansör A.Ş.", "1234567890", "Kadıköy", "+902161112233",
             "Mehmet Yıldız", 0, "borc"),
            ("Yeşil Peyzaj Ltd.", "9876543210", "Ataşehir", "+902164445566",
             "Ayşe Demir", 750000, "borc"),
            ("Temiz Su Arıtma", "5555544444", "Ümraniye", "+902167778899",
             "Can Kara", 120000, "alacak"),
        ]
        for ad, vno, vd, tel, yetkili, acilis, yon in firmalar:
            conn.execute(
                """
                INSERT INTO firma (tenant_id, ad, vergi_no, vergi_dairesi,
                                   telefon, yetkili_ad, acilis_bakiye_kurus,
                                   acilis_bakiye_yon)
                SELECT %(t)s, %(ad)s, %(v)s, %(vd)s, %(tel)s, %(y)s, %(ac)s,
                       %(yon)s::bakiye_yon
                WHERE NOT EXISTS (
                    SELECT 1 FROM firma WHERE tenant_id = %(t)s AND ad = %(ad)s
                )
                """,
                {"t": tenant_id, "ad": ad, "v": vno, "vd": vd, "tel": tel,
                 "y": yetkili, "ac": acilis, "yon": yon},
            )

        # Personel: BIRI uygulama hesabina bagli (guvenlik), digerleri degil —
        # "her personelin hesabi yoktur" kurali seed'de de gorunsun.
        guard_uid = conn.execute(
            "SELECT id FROM app_user WHERE tenant_id = %s AND email = %s",
            (tenant_id, "guard@acme.com"),
        ).fetchone()
        personeller = [
            ("Hasan Güvenlik", "Güvenlik Görevlisi", 4200000,
             guard_uid[0] if guard_uid else None),
            ("Fatma Temizlik", "Temizlik Personeli", 3500000, None),
            ("Ali Bahçıvan", "Bahçıvan", 3300000, None),
        ]
        for ad, gorev, maas, uid in personeller:
            conn.execute(
                """
                INSERT INTO personel_kayit (tenant_id, ad, gorev, maas_kurus,
                                            app_user_id, giris_tarihi)
                SELECT %(t)s, %(ad)s, %(g)s, %(m)s, %(u)s, DATE '2025-09-01'
                WHERE NOT EXISTS (
                    SELECT 1 FROM personel_kayit
                     WHERE tenant_id = %(t)s AND ad = %(ad)s
                )
                """,
                {"t": tenant_id, "ad": ad, "g": gorev, "m": maas, "u": uid},
            )

        # Araclar: plaka NORMALIZE (bosluksuz + BUYUK) — vehicle_pass ile ayni.
        araclar = [
            ("34ABC123", "Fiat", "Egea", "Beyaz"),
            ("06XYZ789", "Renault", "Clio", "Gri"),
            ("35DEF456", "Toyota", "Corolla", "Siyah"),
        ]
        for plaka, marka, model, renk in araclar:
            conn.execute(
                """
                INSERT INTO arac_kayit (tenant_id, plaka, marka, model, renk)
                SELECT %(t)s, %(p)s, %(ma)s, %(mo)s, %(r)s
                WHERE NOT EXISTS (
                    SELECT 1 FROM arac_kayit
                     WHERE tenant_id = %(t)s AND plaka = %(p)s
                )
                """,
                {"t": tenant_id, "p": plaka, "ma": marka, "mo": model, "r": renk},
            )

        for ad, tip, yuzde in [("Ana Su Sayacı", "su", 10.00),
                               ("Ana Elektrik Sayacı", "elektrik", 15.00)]:
            conn.execute(
                """
                INSERT INTO sayac_ana (tenant_id, ad, tip, ortak_alan_dagitim,
                                       ortak_alan_yuzde)
                SELECT %(t)s, %(ad)s, %(tip)s::sayac_tip,
                       'bagimsiz_bolumlere_esit'::gelir_gider_dagitim, %(y)s
                WHERE NOT EXISTS (
                    SELECT 1 FROM sayac_ana WHERE tenant_id = %(t)s AND ad = %(ad)s
                )
                """,
                {"t": tenant_id, "ad": ad, "tip": tip, "y": yuzde},
            )

        # Daire sayaclari: ana su sayacina bagli TUM aktif daireler
        # (uretim ucuyla AYNI kural — zaten olanlar atlanir).
        ana_su = conn.execute(
            "SELECT id FROM sayac_ana WHERE tenant_id = %s AND ad = %s",
            (tenant_id, "Ana Su Sayacı"),
        ).fetchone()[0]
        conn.execute(
            """
            INSERT INTO sayac_bolum (tenant_id, unit_id, ana_sayac_id)
            SELECT %(t)s, u.id, %(a)s
              FROM unit u
             WHERE u.tenant_id = %(t)s AND u.aktif
               AND NOT EXISTS (
                   SELECT 1 FROM sayac_bolum sb
                    WHERE sb.tenant_id = %(t)s AND sb.unit_id = u.id
                      AND sb.ana_sayac_id = %(a)s
               )
            """,
            {"t": tenant_id, "a": ana_su},
        )
        print("[seed] muhasebe tanimlari: 2 kasa, 4 gelir/gider grubu, "
              "8 kalem, 3 firma, 3 personel, 3 arac, 2 ana sayac + daire "
              "sayaclari (idempotent).")


        # ------------------------------------------------------------------
        # MESAJ SABLONLARI (P32) — varsayilan set. HEPSI OPERASYONEL:
        # finansal bildirim ve toplanti cagrisi KMK yukumluluguyle
        # gonderilir; PAZARLAMA sablonu VARSAYILAN OLARAK YOKTUR (riza
        # gerektirir, bkz. P36).
        # ------------------------------------------------------------------
        from app.mesajlasma import VARSAYILAN_SABLONLAR

        for kanal, ad, konu, govde, amac in VARSAYILAN_SABLONLAR:
            conn.execute(
                """
                INSERT INTO mesaj_sablonu (tenant_id, kanal, ad, konu, govde, amac)
                SELECT %(t)s, %(k)s::mesaj_kanal, %(ad)s, %(konu)s, %(g)s,
                       %(a)s::mesaj_amac
                WHERE NOT EXISTS (
                    SELECT 1 FROM mesaj_sablonu
                     WHERE tenant_id = %(t)s AND kanal = %(k)s::mesaj_kanal
                       AND ad = %(ad)s
                )
                """,
                {"t": tenant_id, "k": kanal, "ad": ad, "konu": konu,
                 "g": govde, "a": amac},
            )
        print(f"[seed] mesaj sablonlari: {len(VARSAYILAN_SABLONLAR)} kayit "
              "(hepsi OPERASYONEL — pazarlama rizasi P36).")


        # ------------------------------------------------------------------
        # KVKK AYDINLATMA METNI (P36) — ORNEK surum 1.
        #
        # NEDEN SEED'DE: metin olmadan onay kapisi HIC KURULMAZ ve akis
        # gelistirme/demo ortaminda uctan uca denenemezdi. Metin TENANT
        # ICERIGIDIR — buradaki ORNEKTIR ve gercek tesis kendi hukuk
        # danismaninin metnini yayinlar (yeni SURUM olarak; yerinde
        # duzenleme yok).
        # ------------------------------------------------------------------
        conn.execute(
            """
            INSERT INTO kvkk_metin (tenant_id, surum, baslik, govde)
            SELECT %(t)s, 1, %(b)s, %(g)s
            WHERE NOT EXISTS (
                SELECT 1 FROM kvkk_metin WHERE tenant_id = %(t)s
            )
            """,
            {
                "t": tenant_id,
                "b": "Kişisel Verilerin Korunması Hakkında Aydınlatma Metni",
                "g": (
                    "Bu metin ÖRNEKTİR; tesis yönetimi kendi hukuk "
                    "danışmanının hazırladığı metni yeni sürüm olarak "
                    "yayınlamalıdır.\n\n"
                    "1) VERİ SORUMLUSU\nSite/tesis yönetimi, 6698 sayılı "
                    "Kanun kapsamında veri sorumlusudur.\n\n"
                    "2) İŞLENEN VERİLER\nAd-soyad, telefon, e-posta, "
                    "bağımsız bölüm bilgisi; personel için tur okutma "
                    "kayıtları ve okutma anındaki konum (sürekli takip "
                    "YAPILMAZ).\n\n"
                    "3) AMAÇ VE HUKUKİ SEBEP\nSite yönetim hizmetinin "
                    "ifası, KMK'dan doğan yükümlülükler ve güvenliğin "
                    "sağlanmasındaki meşru menfaat.\n\n"
                    "4) AKTARIM\nVeriler yalnızca hizmetin ifası için "
                    "zorunlu olduğu ölçüde ve mevzuatın izin verdiği "
                    "hallerde aktarılır.\n\n"
                    "5) HAKLARINIZ\nKanun'un 11. maddesindeki haklarınızı "
                    "yönetime başvurarak kullanabilirsiniz.\n\n"
                    "6) PAZARLAMA İZNİ\nKampanya/teklif iletileri AYRI ve "
                    "İSTEĞE BAĞLI bir izne tabidir; bu metni onaylamanız "
                    "pazarlama izni vermek anlamına GELMEZ ve izni "
                    "istediğiniz zaman geri alabilirsiniz."
                ),
            },
        )
        print("[seed] kvkk aydinlatma metni: surum 1 (ORNEK — gercek metin "
              "tesisin kendi hukuk metnidir).")


        # ------------------------------------------------------------------
        # DEVRIYE ALANI (tur 41) — checkpoint + plan + pencereler + okutmalar.
        #
        # Seed'de bu alan HIC YOKTU: /dashboard tum sayaclari 0, /checkpoints
        # ve /patrol-plans bos, /reports/patrols bos, bildirim tablosu bos.
        # Yani panelin ANA EKRANI ve devriye modulu her suruste BOS DURUMDA
        # olculuyordu (tur 36 envanteri).
        # ------------------------------------------------------------------
        gece_shift_id = conn.execute(
            "SELECT id FROM shift WHERE tenant_id=%s AND ad='Gece Vardiyası'",
            (tenant_id,),
        ).fetchone()[0]

        cp_ids = []
        for cp_ad, uid in [
            ("Ana Kapı", "04A1B2C3D4E5F6"),
            ("Otopark", "04B2C3D4E5F6A1"),
            ("Havuz", "04C3D4E5F6A1B2"),
        ]:
            cp_ids.append(conn.execute(
                """
                WITH yeni AS (
                    INSERT INTO checkpoint (tenant_id, ad, nfc_tag_uid, aktif)
                    SELECT %(t)s, %(a)s, %(u)s, true
                    WHERE NOT EXISTS (
                        SELECT 1 FROM checkpoint
                        WHERE tenant_id = %(t)s AND nfc_tag_uid = %(u)s
                    )
                    RETURNING id
                )
                SELECT id FROM yeni
                UNION ALL
                SELECT id FROM checkpoint
                 WHERE tenant_id = %(t)s AND nfc_tag_uid = %(u)s
                LIMIT 1
                """,
                {"t": tenant_id, "a": cp_ad, "u": uid},
            ).fetchone()[0])

        plan_id = conn.execute(
            """
            WITH yeni AS (
                INSERT INTO patrol_plan
                    (tenant_id, ad, shift_id, baslangic_saat, bitis_saat,
                     periyot_dakika, aktif)
                SELECT %(t)s, 'Gece devriyesi', %(s)s, '22:00', '06:00', 120, true
                WHERE NOT EXISTS (
                    SELECT 1 FROM patrol_plan
                    WHERE tenant_id = %(t)s AND ad = 'Gece devriyesi'
                )
                RETURNING id
            )
            SELECT id FROM yeni
            UNION ALL
            SELECT id FROM patrol_plan
             WHERE tenant_id = %(t)s AND ad = 'Gece devriyesi'
            LIMIT 1
            """,
            {"t": tenant_id, "s": gece_shift_id},
        ).fetchone()[0]

        for sira, cp in enumerate(cp_ids, start=1):
            conn.execute(
                """
                INSERT INTO patrol_plan_checkpoint
                    (tenant_id, patrol_plan_id, checkpoint_id, sira)
                VALUES (%(t)s, %(p)s, %(c)s, %(s)s)
                ON CONFLICT DO NOTHING
                """,
                {"t": tenant_id, "p": plan_id, "c": cp, "s": sira},
            )

        # Pencereler: BUGUN aktif (bekliyor) + dun tamamlandi + onceki gun
        # kacirildi. Panelin "Bugunku Turlar" tablosu ve rapor sayfalari
        # ancak bu satirlarla cizilir.
        #
        # IKI SORUN VARDI (tur 55):
        #   * IDEMPOTENT DEGILDI: anahtar `pencere_baslangic` idi ve deger
        #     `now()`dan turedigi icin HER KOSUM ucer yeni pencere ekliyordu
        #     (22 pencere birikmisti).
        #   * BAYATLIYORDU: eski kosumun "bugun" penceresi gecmise dusuyor,
        #     scheduler onu `kacirildi` yapiyor; panelin AKTIF TUR hali
        #     ölçülemez hale geliyordu.
        # Cozum: zaman SAAT BASINA hizalanir (ayni saat icinde tekrar kosum
        # ayni satiri bulur) ve bu planin ONCEKI seed pencereleri silinir.
        conn.execute(
            "DELETE FROM patrol_window WHERE tenant_id = %(t)s "
            "AND patrol_plan_id = %(p)s",
            {"t": tenant_id, "p": plan_id},
        )
        saat_basi = datetime.now(timezone.utc).replace(
            minute=0, second=0, microsecond=0
        )
        pencereler = []
        for gun, saat, durum in [
            (0, 1, "bekliyor"),      # bugun, +1 saat sonra biter
            (1, -2, "tamamlandi"),
            (2, -2, "kacirildi"),
        ]:
            pencereler.append(conn.execute(
                """
                WITH yeni AS (
                    INSERT INTO patrol_window
                        (tenant_id, patrol_plan_id, pencere_baslangic,
                         pencere_bitis, durum)
                    SELECT %(t)s, %(p)s, %(b)s, %(e)s, %(d)s::patrol_window_durum
                    WHERE NOT EXISTS (
                        SELECT 1 FROM patrol_window
                        WHERE tenant_id = %(t)s AND patrol_plan_id = %(p)s
                          AND pencere_baslangic = %(b)s
                    )
                    RETURNING id
                )
                SELECT id FROM yeni
                UNION ALL
                SELECT id FROM patrol_window
                 WHERE tenant_id = %(t)s AND patrol_plan_id = %(p)s
                   AND pencere_baslangic = %(b)s
                LIMIT 1
                """,
                {
                    "t": tenant_id, "p": plan_id, "d": durum,
                    "b": saat_basi - timedelta(days=gun, hours=-saat + 2),
                    "e": saat_basi - timedelta(days=gun, hours=-saat),
                },
            ).fetchone()[0])

        # Okutmalar: tamamlanan pencerede UC nokta, aktif pencerede BIR nokta
        # (ilerleme "1/3" gorunsun; rapor sayfasi da dolsun).
        for pw, kapsam in [(pencereler[1], cp_ids), (pencereler[0], cp_ids[:1])]:
            for i, cp in enumerate(kapsam):
                conn.execute(
                    """
                    INSERT INTO scan_event
                        (tenant_id, guard_id, checkpoint_id, patrol_window_id,
                         nfc_tag_uid, okutma_zamani, imza_dogrulandi,
                         idempotency_key)
                    SELECT %(t)s, %(g)s, %(c)s, %(w)s, cp.nfc_tag_uid,
                           now() - (%(i)s || ' minutes')::interval, false, %(k)s
                    FROM checkpoint cp
                    WHERE cp.id = %(c)s AND cp.tenant_id = %(t)s
                    ON CONFLICT DO NOTHING
                    """,
                    {"t": tenant_id, "g": guard_id, "c": cp, "w": pw,
                     "i": (i + 1) * 7, "k": f"seed-scan-{pw}-{cp}"},
                )
        print("[seed] devriye: 3 nokta + 'Gece devriyesi' plani + 3 pencere "
              "(bugun/tamamlandi/kacirildi) + okutmalar")

        # Bildirimler (tur 41) — panelde /notifications hep BOSTU. Metin
        # KIMLIKTEN uretilir (tur 16): `mesaj` alani geri uyumluluk icin
        # doldurulur ama okuma yolu `mesaj_kimlik`i kullanir.
        for tip, kimlik, veri, okundu, dedup in [
            ("kacirilan_tur", "kacirilan_tur",
             '{"plan": "Gece devriyesi", "eksik": "2"}', False, "seed-bildirim-1"),
            ("talep_cozuldu", "talep_cozuldu",
             '{"baslik": "Demo talep 4: Su sızıntısı onarıldı"}', False,
             "seed-bildirim-2"),
            ("is_emri_atandi", "is_emri_atandi",
             '{"baslik": "Demo talep 3: Gece geç saatte müzik"}', True,
             "seed-bildirim-3"),
        ]:
            conn.execute(
                """
                INSERT INTO notification
                    (tenant_id, tip, mesaj, mesaj_kimlik, mesaj_veri, okundu,
                     dedup_key)
                SELECT %(t)s, %(tip)s::notification_tip, '', %(k)s, %(v)s::jsonb,
                       %(o)s, %(d)s
                WHERE NOT EXISTS (
                    SELECT 1 FROM notification
                    WHERE tenant_id = %(t)s AND dedup_key = %(d)s
                )
                """,
                {"t": tenant_id, "tip": tip, "k": kimlik, "v": veri,
                 "o": okundu, "d": dedup},
            )
        print("[seed] bildirim: 3 kayit (2 okunmamis + 1 okunmus)")

        # Platform destek kanali (WP1): 1 demo bilet — panel/mobil listeler
        # bos gorunmesin. (tenant_id, konu) NOT EXISTS ile idempotent.
        conn.execute(
            """
            INSERT INTO platform_support_ticket
                (tenant_id, acan_user_id, konu, aciklama, foto_key)
            SELECT %(t)s, %(u)s,
                   'Panel bildirim gecikmesi',
                   'Duyuru yayınladıktan sonra mobil bildirimler geç geliyor.',
                   %(f)s
            WHERE NOT EXISTS (
                SELECT 1 FROM platform_support_ticket
                WHERE tenant_id = %(t)s AND konu = 'Panel bildirim gecikmesi'
            )
            """,
            {"t": tenant_id, "u": yonetici_id,
             # Destek biletinin GORSELI: panelin detay bolmesindeki fotograf
             # yolu seed'de hic uretilmiyordu, dolayisiyla surulemiyordu.
             "f": _gorsel_yukle(tenant_id, "destek-bildirim", (139, 92, 246))},
        )
        # Bilet ZATEN VARSA insert atlanir; fotografi ayrica yaz (eski
        # seed'lerde fotosuz olusmustu).
        conn.execute(
            """
            UPDATE platform_support_ticket
               SET foto_key = %(f)s
             WHERE tenant_id = %(t)s AND konu = 'Panel bildirim gecikmesi'
               AND foto_key IS NULL
            """,
            {"t": tenant_id,
             "f": _gorsel_yukle(tenant_id, "destek-bildirim", (139, 92, 246))},
        )
        # Ikinci bilet COZULDU + admin cevap gorseli: panelin destek
        # detayindaki "cevap gorseli" dali ve `cozuldu` rozeti hic
        # cizilmemisti (tur 41).
        conn.execute(
            """
            INSERT INTO platform_support_ticket
                (tenant_id, acan_user_id, konu, aciklama, durum,
                 admin_cevap, admin_cevap_foto_key)
            SELECT %(t)s, %(u)s,
                   'Rapor ekrani yavas',
                   'Aidat tahsilat raporu 10 saniyede geliyor.',
                   'cozuldu', 'Sorgu indeksi eklendi, rapor artik hizli.',
                   %(f)s
            WHERE NOT EXISTS (
                SELECT 1 FROM platform_support_ticket
                WHERE tenant_id = %(t)s AND konu = 'Rapor ekrani yavas'
            )
            """,
            {"t": tenant_id, "u": yonetici_id,
             "f": _gorsel_yukle(tenant_id, "destek-cevap", (37, 99, 235))},
        )
        print("[seed] destek bileti: 'Panel bildirim gecikmesi' (acik, "
              "fotografli) + 'Rapor ekrani yavas' (cozuldu, cevap gorselli)")

        # ------------------------------------------------------------------
        # EKSIK VERI DURUMLARI (tur 58) — envanterin F tablosu.
        #
        # Bir DURUM seed'de yoksa o ekran hali HIC SURULEMEZ. Su uc durum
        # tur 36'dan beri bostu:
        #   * complaint 'reddedildi'      (dort durumdan biri)
        #   * kargo 'teslim_alindi'
        #   * unit_access_permission      (tablo TAMAMEN bos)
        # ------------------------------------------------------------------
        red_id = _upsert_complaint(
            "Demo talep 5: Balkona kamera talebi (reddedildi)",
            "Balkonuma guvenlik kamerasi takilmasini istiyorum.",
            None,
        )
        # Ret SEBEBI complaint tablosunda DEGIL, durum gecmisindedir
        # (`complaint_status_history.sebep`) — sema boyle.
        conn.execute(
            "UPDATE complaint SET durum = 'reddedildi' "
            "WHERE id = %(c)s AND tenant_id = %(t)s AND durum <> 'reddedildi'",
            {"t": tenant_id, "c": red_id},
        )
        conn.execute(
            "INSERT INTO complaint_status_history "
            "(tenant_id, complaint_id, durum, actor_role, sebep) "
            "SELECT %(t)s, %(c)s, 'reddedildi', 'yonetici'::user_role, "
            "       'Ortak alan disina kamera kurulamaz (KVKK).' "
            "WHERE NOT EXISTS (SELECT 1 FROM complaint_status_history "
            "WHERE tenant_id=%(t)s AND complaint_id=%(c)s "
            "AND durum='reddedildi')",
            {"t": tenant_id, "c": red_id},
        )

        # TESLIM ALINMIS kargo (ikinci kayit; bekleyen kargo korunur).
        conn.execute(
            """
            INSERT INTO kargo (tenant_id, unit_id, firma, durum,
                               kaydeden_user_id, teslim_alan_user_id,
                               teslim_zamani, notlar)
            SELECT %(t)s, %(u)s, 'Yurtiçi Kargo', 'teslim_alindi',
                   %(g)s, %(r)s, now() - interval '2 hours',
                   'Kapida teslim edildi.'
            WHERE NOT EXISTS (
                SELECT 1 FROM kargo
                WHERE tenant_id = %(t)s AND durum = 'teslim_alindi'
            )
            """,
            {"t": tenant_id, "u": unit_id, "g": guard_id, "r": resident_id},
        )

        # DAIRE ERISIM IZNI — uc durum: bekliyor / onaylandi / reddedildi.
        # `durum` + `unit_id` cifti idempotency anahtari.
        for _durum, _kullanildi in [
            ("bekliyor", False),
            ("onaylandi", True),
            ("reddedildi", False),
        ]:
            conn.execute(
                """
                INSERT INTO unit_access_permission
                    (tenant_id, unit_id, granted_to_yonetici_user_id,
                     granted_by_resident_user_id, durum, used,
                     requested_at, decided_at)
                SELECT %(t)s, %(u)s, %(y)s,
                       CASE WHEN %(d)s = 'bekliyor' THEN NULL ELSE %(r)s END,
                       %(d)s::access_request_durum, %(k)s,
                       now() - interval '3 hours',
                       CASE WHEN %(d)s = 'bekliyor' THEN NULL
                            ELSE now() - interval '2 hours' END
                WHERE NOT EXISTS (
                    SELECT 1 FROM unit_access_permission
                    WHERE tenant_id = %(t)s AND unit_id = %(u)s
                      AND durum = %(d)s::access_request_durum
                )
                """,
                {"t": tenant_id, "u": unit_id, "y": yonetici_id,
                 "r": resident_id, "d": _durum, "k": _kullanildi},
            )
        print("[seed] eksik durumlar: talep 'reddedildi' + kargo "
              "'teslim_alindi' + daire erisim izni (bekliyor/onaylandi/"
              "reddedildi)")

        # ------------------------------------------------------------------
        # TAZELIK DENETIMI (tur 55) — "bugun"/"yaklasan" veri GERCEKTEN oyle mi?
        #
        # Goreli tarihli seed verisi zamanla BAYATLAR ve bayatlama SESSIZDIR:
        # panel/mobil o durumu bos olcer, kimse fark etmez. Tur 49 envanterinde
        # tam bu gorulmustu (aktif tur penceresi kacirildiya donmus). Seed artik
        # kendi ciktisini denetler.
        #
        # NOT: bu blok `with psycopg.connect(...)` GOVDESININ ICINDE olmali —
        # disarida `conn` kapali ve execute "connection is closed" verir
        # (tur 41'de ayni tuzaga dusuldu).
        # ------------------------------------------------------------------
        # ------------------------------------------------------------------
        # TUR 62 — DEMIRBAS / DIS HIZMET / ENTEGRASYON verisi.
        #
        # Ucuncu envanterin B maddesi: bu uc tablo dev veritabaninda TAMAMEN
        # BOSTU. Panelin `/assets` sayfasi YEDI surus listesinde var ve
        # yedisi de "Demirbas yok · Toplam 0" halini olcuyordu; satir, durum
        # rozeti ve zimmet eylemlerinin koduna hic ugranmiyordu. `/integrations`
        # ve mobil dis hizmet ekrani icin de ayni durum.
        #
        # Idempotent: ad bazli `ON CONFLICT DO NOTHING` yerine "yoksa ekle"
        # (tabloda ad uzerinde kisit yok). NFC etiketi olan demirbas, `uq_asset_
        # tenant_nfc` yuzunden tekrar eklenemez — bu da idempotensi saglar.
        # ------------------------------------------------------------------
        if conn.execute(
            "SELECT count(*) FROM asset WHERE tenant_id=%s", (tenant_id,)
        ).fetchone()[0] == 0:
            # Enum'un UC durumu birden temsil edilir: musait / zimmetli /
            # bakimda. Bir durum yoksa o ekran hali HIC surulemez (tur 58).
            _demirbaslar = [
                ("Dewalt matkap", "alet", "04AA11BB22", "musait",
                 "Sarj adaptoru dahil."),
                ("Telsiz seti (4'lu)", "ekipman", "04CC33DD44", "zimmetli",
                 "Guvenlik ekibi kullaniyor."),
                ("Elektrikli supurge", "ekipman", None, "bakimda",
                 "Motor arizasi — servise gonderildi."),
                ("Servis araci", "arac", None, "musait", "Plaka: 34 ABC 123"),
            ]
            _asset_ids = {}
            for _ad, _kat, _uid, _durum, _acik in _demirbaslar:
                _asset_ids[_ad] = conn.execute(
                    "INSERT INTO asset (tenant_id, ad, kategori, nfc_tag_uid, "
                    "durum, aciklama) VALUES (%s,%s,%s,%s,%s,%s) RETURNING id",
                    (tenant_id, _ad, _kat, _uid, _durum, _acik),
                ).fetchone()[0]

            # ZIMMET GECMISI: biri ACIK (birakma_zamani NULL -> "islem
            # suruyor" kartini besler), biri KAPALI (gecmis karti).
            _guard = conn.execute(
                "SELECT id FROM app_user WHERE tenant_id=%s AND email=%s",
                (tenant_id, "guard@acme.com"),
            ).fetchone()[0]
            conn.execute(
                "INSERT INTO asset_checkout (tenant_id, asset_id, alan_user_id, "
                "alma_zamani, alma_nfc_tag_uid, notlar, idempotency_key) "
                "VALUES (%s,%s,%s, now() - interval '3 hours', %s,%s,%s)",
                (tenant_id, _asset_ids["Telsiz seti (4'lu)"], _guard,
                 "04CC33DD44", "Gece vardiyasi icin alindi.",
                 "seed-zimmet-acik"),
            )
            conn.execute(
                "INSERT INTO asset_checkout (tenant_id, asset_id, alan_user_id, "
                "birakan_user_id, alma_zamani, birakma_zamani, notlar, "
                "idempotency_key, birakma_idempotency_key) "
                "VALUES (%s,%s,%s,%s, now() - interval '2 days', "
                "now() - interval '2 days' + interval '6 hours', %s,%s,%s)",
                (tenant_id, _asset_ids["Dewalt matkap"], _guard, _guard,
                 "Kat koridoru tamiri.", "seed-zimmet-kapali-al",
                 "seed-zimmet-kapali-birak"),
            )

        if conn.execute(
            "SELECT count(*) FROM dis_hizmet WHERE tenant_id=%s", (tenant_id,)
        ).fetchone()[0] == 0:
            for _tur, _ad, _soyad, _tel, _acik in [
                ("tesisatci", "Hasan", "Kaya", "+905321110001",
                 "Hafta ici 09:00-18:00"),
                ("elektrikci", "Ayse", "Demir", "+905321110002",
                 "Acil cagri 7/24"),
                ("asansor", "Mert", "Yildiz", "+905321110003",
                 "Aylik bakim sozlesmesi"),
            ]:
                conn.execute(
                    "INSERT INTO dis_hizmet (tenant_id, tur, ad, soyad, "
                    "telefon, aciklama) VALUES (%s,%s,%s,%s,%s,%s)",
                    (tenant_id, _tur, _ad, _soyad, _tel, _acik),
                )

        if conn.execute(
            "SELECT count(*) FROM integration WHERE tenant_id=%s", (tenant_id,)
        ).fetchone()[0] == 0:
            # SSRF korumasi gercek isteklerde devrede; seed yalniz KAYIT
            # olusturur (tetikleme yok). Biri PASIF: aktif/pasif rozeti de
            # boylece surulur.
            for _ad, _kanal, _url, _aktif in [
                ("Megafon (anons)", "megaphone",
                 "https://ornek.invalid/anons", True),
                ("Akilli ev kopru", "smarthome",
                 "https://ornek.invalid/smart", True),
                ("Genel webhook", "webhook",
                 "https://ornek.invalid/hook", False),
            ]:
                conn.execute(
                    "INSERT INTO integration (tenant_id, ad, channel_type, "
                    "endpoint_url, payload_template, aktif) "
                    "VALUES (%s,%s,%s,%s,%s,%s)",
                    (tenant_id, _ad, _kanal, _url,
                     '{"mesaj": "{{mesaj}}"}', _aktif),
                )

        for _ad, _sorgu in [
            ("aktif devriye penceresi",
             "SELECT count(*) FROM patrol_window WHERE tenant_id = %(t)s "
             "AND pencere_baslangic <= now() AND pencere_bitis > now()"),
            ("yaklasan etkinlik",
             "SELECT count(*) FROM etkinlik WHERE tenant_id = %(t)s "
             "AND COALESCE(bitis_zamani, tarih) >= now()"),
            ("okunmamis bildirim",
             "SELECT count(*) FROM notification WHERE tenant_id = %(t)s "
             "AND okundu = false"),
            ("fotografli talep",
             "SELECT count(*) FROM complaint_photo WHERE tenant_id = %(t)s"),
            # DURUM KAPSAMASI (tur 58): bir durum seed'de yoksa o ekran hali
            # HIC SURULEMEZ. Enum'un TAMAMI temsil edilmeli.
            ("talep durumu (4/4)",
             "SELECT count(DISTINCT durum) FILTER (WHERE durum IN "
             "('acik','is_emri','cozuldu','reddedildi')) = 4 "
             "FROM complaint WHERE tenant_id = %(t)s"),
            ("kargo durumu (2/2)",
             "SELECT count(DISTINCT durum) = 2 FROM kargo "
             "WHERE tenant_id = %(t)s"),
            ("erisim izni durumu (3/3)",
             "SELECT count(DISTINCT durum) = 3 FROM unit_access_permission "
             "WHERE tenant_id = %(t)s"),
            ("devriye pencere durumu (3/3)",
             "SELECT count(DISTINCT durum) = 3 FROM patrol_window "
             "WHERE tenant_id = %(t)s"),
            # TUR 62: bu uc tablo tamamen bostu; sayfalar BOS olculuyordu.
            ("demirbas durumu (3/3)",
             "SELECT count(DISTINCT durum) = 3 FROM asset "
             "WHERE tenant_id = %(t)s"),
            ("acik zimmet",
             "SELECT count(*) FROM asset_checkout WHERE tenant_id = %(t)s "
             "AND birakma_zamani IS NULL"),
            ("kapali zimmet (gecmis)",
             "SELECT count(*) FROM asset_checkout WHERE tenant_id = %(t)s "
             "AND birakma_zamani IS NOT NULL"),
            ("dis hizmet",
             "SELECT count(*) FROM dis_hizmet WHERE tenant_id = %(t)s"),
            ("entegrasyon (aktif+pasif)",
             "SELECT count(DISTINCT aktif) = 2 FROM integration "
             "WHERE tenant_id = %(t)s"),
        ]:
            _sayi = conn.execute(_sorgu, {"t": tenant_id}).fetchone()[0]
            _isaret = "OK" if _sayi else "BAYAT/BOS"
            print(f"[seed] tazelik: {_ad} = {_sayi} ({_isaret})")

        # --- Demo denetim kayitlari (audit_log, WP1) — dogal aksiyon ornekleri
        # Idempotent: tenant'ta zaten audit yoksa birkac ornek satir ekle.
        # meta'da kisisel veri DEGERI yok (yalniz id/alan-adi). audit_log yoksa
        # (0002 henuz uygulanmamis — prod-upgrade simulasyonu) sessizce atla.
        # NOT: bu blok `with psycopg.connect(...)` govdesinin ICINDE olmalidir;
        # yanlis girintiyle disari tasmisti ve kapali baglantida execute
        # "the connection is closed" ile patliyordu.
        _has_audit = conn.execute(
            "SELECT to_regclass('public.audit_log')"
        ).fetchone()[0] is not None
        if _has_audit and conn.execute(
            "SELECT count(*) FROM audit_log WHERE tenant_id=%s", (tenant_id,)
        ).fetchone()[0] == 0:

            def _uid(email: str):
                return conn.execute(
                    "SELECT id FROM app_user WHERE tenant_id=%s AND email=%s",
                    (tenant_id, email),
                ).fetchone()[0]

            a_id, g_id, r_id = _uid("admin@acme.com"), _uid("guard@acme.com"), _uid("resident@acme.com")
            demo_audit = [
                ("login_ok", a_id, "admin", "app_user", str(a_id), "{}"),
                ("resident_create", a_id, "admin", "app_user", str(r_id), "{}"),
                ("phone_reveal", g_id, "security", "app_user", str(r_id), '{"channel": "phone"}'),
                ("call_initiate", g_id, "security", "app_user", str(r_id), '{"channel": "phone"}'),
            ]
            for action, actor, rol, rtype, rid, meta in demo_audit:
                conn.execute(
                    "INSERT INTO audit_log (tenant_id, actor_user_id, actor_rol, "
                    "action, resource_type, resource_id, meta) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s::jsonb)",
                    (tenant_id, actor, rol, action, rtype, rid, meta),
                )
            print("[seed] demo audit_log kayitlari eklendi (4).")

    _ceviri_uret(tenant_id)

    print("[seed] tamamlandi (idempotent).")
    return 0


def _ceviri_uret(tenant_id) -> None:
    """Ornek yayin icerigini GERCEK ceviri hattindan gecirir (7 dil).

    Elle INSERT edilmis ceviri YOKTUR: worker'in cagirdigi ayni fonksiyon
    (`app.ceviri_service.entity_cevir`) burada dogrudan cagrilir — yani
    saglayici -> durum -> `alanlar` yolu ucu uca ayni koddur. Kuyruk (Celery)
    gerekmez; seed sonucu beklemek ister.

    Varsayilan saglayici seed servisi icin `libretranslate`tir (compose).
    Saglayici erisilemezse [entity_cevir] ilgili dilleri `durum='hata'` yapar
    ve BURASI PATLAMAZ — seed'in geri kalani gecerli kalir (orijinal metin
    her zaman servis edilir).
    """
    from app import ceviri
    from app.ceviri_service import entity_cevir
    from app.config import settings
    from app.translate import get_translation_provider

    hedefler = [
        ("duyuru", "announcement", "Hoş geldiniz"),
        ("site_kurali", "site_kurali", "Otopark Kullanımı"),
        ("etkinlik", "etkinlik", "Bahar şenliği"),
    ]
    saglayici = type(get_translation_provider()).__name__
    print(
        f"[seed] icerik cevirisi basliyor (saglayici={saglayici}, "
        f"{len(ceviri.DESTEKLENEN_DILLER)} dil) — biraz surebilir..."
    )
    with psycopg.connect(settings.owner_dsn, autocommit=True) as conn:
        for tip_ad, tablo, baslik in hedefler:
            satir = conn.execute(
                f"SELECT id FROM {tablo} WHERE tenant_id = %s AND baslik = %s",
                (tenant_id, baslik),
            ).fetchone()
            if satir is None:
                print(f"[seed]   ! {tip_ad}/{baslik!r} bulunamadi, atlandi")
                continue
            ozet = entity_cevir(tip_ad, satir[0], tenant_id)
            print(
                f"[seed]   {tip_ad} {baslik!r}: cevrilen={ozet['cevrilen']} "
                f"hata={ozet['hata']} korunan={ozet['korunan']}"
            )


if __name__ == "__main__":
    raise SystemExit(main())
