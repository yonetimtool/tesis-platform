"""Ilk PLATFORM ADMIN kurulumu (prod — seed YOK).

Idempotent CLI: bir "bootstrap" tenant + tek bir platform admin (role='admin')
olusturur. DEMO tenant/kullanici/veri URETMEZ. Admin bu hesapla panele girer ve
gercek tesisleri (tenant'lari) panelden acar.

Neden tenant gerekir? Login `(tenant_slug, email, parola)` ile calisir ve her
app_user bir tenant'a baglidir; bu yuzden admin'i barindiran minimal bir tenant
sart. Bu tenant'in slug'i panel giris ekranindaki "Tesis (slug)" alanina yazilir.

Calistirma — `worker` servisinden (app modullerini VE OWNER_DSN'i tasir):
    docker compose -f docker-compose.prod.yml --env-file .env.prod \
        run --rm worker python -m scripts.create_admin --email you@firma.com

    DIKKAT: `api` DEGIL. Prod'da api servisine superuser (OWNER) DSN'i BILINCLI
    olarak verilmez — internete (Caddy uzerinden) bakan surec yalniz RLS'e tabi
    app_rw kimligini tasir. `worker`/`beat` ayni imajdir ve OWNER_DSN'i tasir.
    (Tur 72'ye kadar bu dosya ve runbook `api` diyordu; prod'da OWNER_DSN
    tanimsiz oldugu icin komut "password authentication failed" ile duserdi.)

    # parola bayragi verilmezse guvenli sekilde sorulur (ekranda gorunmez):
    #   ... python -m scripts.create_admin --email you@firma.com
    # tum bayraklarla:
    #   ... --email you@firma.com --password 'Guclu1!' --name 'Ad Soyad' \
    #       --tenant-slug yonetio --tenant-name 'Yönetio Platform'

RLS: tenant tablosunda RLS FORCE etkin — YENI tenant app_rw ile acilamaz. Bu
yuzden (seed gibi) OWNER (superuser) baglantisi kullanilir; OWNER_DSN env'den okunur.

Idempotent: tekrar calistirmak hata vermez; parola verildiyse gunceller,
verilmediyse mevcut parolayi KORUR (ayni admin'in parolasini istemeden ezmemek icin).
"""
from __future__ import annotations

import argparse
import getpass
import os
import re
import sys

import psycopg

from app.security import hash_password

# OWNER_DSN'in SABIT KODLU bir yedegi YOK. Onceden dev parolasini
# ("owner_secret_change_me") iceren bir yedek vardi; dev'de kaza eseri dogru
# oldugu icin calisiyor, prod'da ise sessizce YANLIS parolayla baglanmayi
# deneyip anlasilmaz bir kimlik hatasi veriyordu. Eksikse ERKEN ve NET patlar.
OWNER_DSN = os.getenv("OWNER_DSN", "")

# schemas.validate_password_strength ile ayni kurallar (panel/mobil ile tutarli).
_PW_UPPER = re.compile(r"[A-ZĞÜŞİÖÇ]")
_PW_DIGIT = re.compile(r"\d")
_PW_SYMBOL = re.compile(r"[^A-Za-z0-9ĞÜŞİÖÇğüşıöç]")


def _validate_password(v: str) -> str:
    if len(v) < 8:
        raise ValueError("Parola en az 8 karakter olmali.")
    if not _PW_UPPER.search(v):
        raise ValueError("Parola en az bir buyuk harf icermeli.")
    if not _PW_DIGIT.search(v):
        raise ValueError("Parola en az bir rakam icermeli.")
    if not _PW_SYMBOL.search(v):
        raise ValueError("Parola en az bir sembol icermeli (orn. ! ? @ # . -).")
    return v


def _prompt_password() -> str:
    """Parolayi iki kez (dogrulamali), ekranda gostermeden sorar."""
    for _ in range(3):
        p1 = getpass.getpass("Yeni admin parolasi: ")
        p2 = getpass.getpass("Parola (tekrar): ")
        if p1 != p2:
            print("  Parolalar eslesmedi, tekrar deneyin.", file=sys.stderr)
            continue
        try:
            return _validate_password(p1)
        except ValueError as e:
            print(f"  {e}", file=sys.stderr)
    print("Parola belirlenemedi.", file=sys.stderr)
    sys.exit(2)


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Ilk platform admin'i olustur (idempotent; demo veri yok).",
    )
    ap.add_argument("--email", help="Admin e-postasi (login anahtari).")
    ap.add_argument("--password", help="Admin parolasi (verilmezse guvenli sorulur).")
    ap.add_argument("--name", default="Platform Admin", help="Admin gorunen adi.")
    ap.add_argument(
        "--tenant-slug",
        default="yonetio",
        help="Bootstrap tenant slug'i (panel giris ekranindaki 'Tesis' alani).",
    )
    ap.add_argument(
        "--tenant-name", default="Yönetio Platform", help="Bootstrap tenant adi."
    )
    args = ap.parse_args()

    if not OWNER_DSN:
        print(
            "OWNER_DSN tanimsiz. Bu betik RLS'i bypass etmek icin OWNER "
            "(superuser) baglantisi ister.\n"
            "  Prod: `run --rm worker python -m scripts.create_admin ...` "
            "(api DEGIL — api'de superuser DSN'i bilincli olarak yoktur).\n"
            "  Elle: OWNER_DSN=postgresql://<owner>:<parola>@db:5432/<db>",
            file=sys.stderr,
        )
        return 2

    email = (args.email or input("Admin e-postasi: ")).strip().lower()
    if "@" not in email:
        print("Gecerli bir e-posta gerekli.", file=sys.stderr)
        return 2

    # Parola: bayrak > guvenli prompt. Bayrakla gelirse yine de dogrula.
    if args.password is not None:
        try:
            password = _validate_password(args.password)
        except ValueError as e:
            print(str(e), file=sys.stderr)
            return 2
    else:
        password = _prompt_password()

    with psycopg.connect(OWNER_DSN, autocommit=True) as conn:
        # 1) bootstrap tenant upsert (slug benzersiz). kurulum_tamamlandi tablo
        #    varsayilani (true) — platform tenant'i onboarding akisina girmez.
        tenant_id = conn.execute(
            """
            INSERT INTO tenant (ad, slug, timezone)
            VALUES (%s, %s, 'Europe/Istanbul')
            ON CONFLICT (slug) DO UPDATE SET ad = EXCLUDED.ad
            RETURNING id
            """,
            (args.tenant_name, args.tenant_slug),
        ).fetchone()[0]

        # 2) admin upsert ((tenant_id, email) benzersiz). Parola HER ZAMAN verilir
        #    (bayrak ya da prompt) => password_hash guncellenir. Bu, unutulan
        #    admin parolasini sifirlamanin da yoludur (ayni komut).
        conn.execute(
            """
            INSERT INTO app_user (tenant_id, ad, email, password_hash,
                                  password_set, temp_code_hash, role, is_active)
            VALUES (%s, %s, %s, %s, true, NULL, 'admin'::user_role, true)
            ON CONFLICT (tenant_id, email) DO UPDATE
                SET ad = EXCLUDED.ad,
                    password_hash = EXCLUDED.password_hash,
                    password_set = true,
                    role = 'admin'::user_role,
                    is_active = true
            """,
            (tenant_id, args.name, email, hash_password(password)),
        )

    print("\n✓ Platform admin hazir.")
    print(f"  Tenant (slug) : {args.tenant_slug}")
    print(f"  E-posta       : {email}")
    print("  Panele giris  : Tesis(slug) + e-posta + parola ile.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
