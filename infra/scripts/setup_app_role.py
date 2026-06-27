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

    with psycopg.connect(owner_dsn, autocommit=True) as conn:
        # Migration rolu zaten olusturmus olmali; emniyet icin yoksa olustur.
        conn.execute(
            sql.SQL(
                "DO $$ BEGIN "
                "IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = %s) THEN "
                "CREATE ROLE {role} NOLOGIN; END IF; END $$;"
            ).format(role=role),
            (app_user,),
        )
        # LOGIN + parola.
        conn.execute(
            sql.SQL("ALTER ROLE {role} WITH LOGIN PASSWORD {pw}").format(
                role=role, pw=sql.Literal(app_password)
            )
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

    print(f"[setup_app_role] '{app_user}' rolu hazir (LOGIN + GRANT).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
