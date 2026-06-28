"""Idempotent dev/test seed: ornek tenant + admin/security/cleaning kullanicilar.

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
        "ad": "Acme Guard",
        "email": "guard@acme.com",
        "role": "security",
        "password": os.getenv("SEED_GUARD_PASSWORD", "Guard123!"),
    },
    {
        "ad": "Acme Cleaner",
        "email": "cleaner@acme.com",
        "role": "cleaning",
        "password": os.getenv("SEED_CLEANER_PASSWORD", "Clean123!"),
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

        # 2) kullanici upsert ((tenant_id, email) benzersiz).
        for u in USERS:
            conn.execute(
                """
                INSERT INTO app_user (tenant_id, ad, email, password_hash, role, is_active)
                VALUES (%s, %s, %s, %s, %s::user_role, true)
                ON CONFLICT (tenant_id, email) DO UPDATE
                    SET ad = EXCLUDED.ad,
                        password_hash = EXCLUDED.password_hash,
                        role = EXCLUDED.role,
                        is_active = true,
                        updated_at = now()
                """,
                (tenant_id, u["ad"], u["email"], hash_password(u["password"]), u["role"]),
            )
            print(f"[seed] user {u['email']:<18} role={u['role']}")

    print("[seed] tamamlandi (idempotent).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
