#!/usr/bin/env python3
"""app_rw rolunu uygulama icin hazirlar (migrate adiminda, owner ile calisir).

/contracts/db migration'i `app_rw` rolunu NOLOGIN olarak olusturur ve tablo
GRANT'lerini verir. Bu betik EK olarak:
  * app_rw'ye LOGIN + parola verir (uygulama bu rolle baglanir),
  * USAGE/DML GRANT'lerini (idempotent) garanti eder,
  * gelecekte eklenecek tablolar icin DEFAULT PRIVILEGES tanimlar.

app_rw, owner DEGILDIR ve BYPASSRLS YOKTUR => FORCE RLS ona uygulanir.

Env:
  OWNER_DSN        owner/superuser libpq DSN (orn postgresql://owner:***@db:5432/tesis)
  APP_DB_USER      varsayilan: app_rw
  APP_DB_PASSWORD  app_rw parolasi (zorunlu)
"""
from __future__ import annotations

import os
import sys

import psycopg
from psycopg import sql


def main() -> int:
    owner_dsn = os.environ["OWNER_DSN"]
    app_user = os.environ.get("APP_DB_USER", "app_rw")
    app_password = os.environ["APP_DB_PASSWORD"]

    role = sql.Identifier(app_user)
    pw = sql.Literal(app_password)

    with psycopg.connect(owner_dsn, autocommit=True) as conn:
        # Rol var mi? Normal (parametreli) sorgu — DO blogu/placeholder YOK,
        # boylece "could not determine data type of parameter" hatasi olusmaz.
        exists = (
            conn.execute(
                "SELECT 1 FROM pg_roles WHERE rolname = %s", (app_user,)
            ).fetchone()
            is not None
        )

        # Migration rolu zaten olusturmus olmali; emniyet icin yoksa olustur.
        # Rol adi sabit identifier, parola sql.Literal ile guvenli kacislanir
        # (CREATE/ALTER ROLE DDL'i placeholder kabul etmedigi icin Literal sart).
        if not exists:
            conn.execute(
                sql.SQL(
                    "CREATE ROLE {role} LOGIN PASSWORD {pw} NOBYPASSRLS"
                ).format(role=role, pw=pw)
            )

        # Idempotent: LOGIN + parola + NOBYPASSRLS'i her calistirmada garanti et.
        # (Migration rolu NOLOGIN olusturmus olabilir; burada LOGIN'e ceviriyoruz.)
        # NOBYPASSRLS => app_rw RLS'e TABI kalir (FORCE RLS uygulanir).
        conn.execute(
            sql.SQL(
                "ALTER ROLE {role} WITH LOGIN PASSWORD {pw} NOBYPASSRLS"
            ).format(role=role, pw=pw)
        )
        # Sema kullanimi + DML (idempotent).
        conn.execute(sql.SQL("GRANT USAGE ON SCHEMA public TO {role}").format(role=role))
        conn.execute(
            sql.SQL(
                "GRANT SELECT, INSERT, UPDATE, DELETE "
                "ON ALL TABLES IN SCHEMA public TO {role}"
            ).format(role=role)
        )
        # Gelecek tablolar icin varsayilan ayricaliklar.
        conn.execute(
            sql.SQL(
                "ALTER DEFAULT PRIVILEGES IN SCHEMA public "
                "GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO {role}"
            ).format(role=role)
        )

        # --- audit_log: APPEND-ONLY (KVKK, migration 0002) ---
        # Blanket GRANT (yukarida) app_rw'ye audit_log'da da UPDATE/DELETE verir;
        # burada GERI ALIYORUZ => app_rw yalniz INSERT + SELECT yapar, denetim
        # satirini DEGISTIREMEZ/SILEMEZ. Purge YALNIZ owner (retention task) ile.
        # audit_log henuz yoksa (0002 uygulanmamis) sessizce atla.
        if conn.execute(
            "SELECT to_regclass('public.audit_log')"
        ).fetchone()[0] is not None:
            conn.execute(
                sql.SQL("REVOKE UPDATE, DELETE ON audit_log FROM {role}").format(
                    role=role
                )
            )
            print("[setup_app_role] audit_log append-only (UPDATE/DELETE revoked).")

    print(f"[setup_app_role] '{app_user}' rolu hazir (LOGIN + GRANT).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
