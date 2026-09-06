#!/usr/bin/env python3
"""`dukkan_app` rolunu Dukkan modulu icin hazirlar (migrate adiminda, owner ile).

Goc `0113_dukkan_sema_ve_rol` rolu NOLOGIN olusturur ve `dukkan` semasindaki
GRANT'leri verir. Bu betik EK olarak:
  * dukkan_app'e LOGIN + parola verir (Dukkan engine'i bu rolle baglanir),
  * `dukkan` semasindaki DML GRANT'lerini (idempotent) garanti eder,
  * gelecek tablolar icin DEFAULT PRIVILEGES tanimlar,
  * ve EN ONEMLISI: `public` semasindaki yetkisizligi YENIDEN DOGRULAR.

===========================================================================
NEDEN REVOKE'LAR BURADA DA TEKRARLANIYOR
===========================================================================
`setup_app_role.py`'de ogrenilmis bir ders var ve yorumu orada yazili:
audit_log'un append-only kilidi YALNIZ gocte yapilsaydi, ilk `migrate`
kosumundaki blanket GRANT kilidi SESSIZCE acardi.

Ayni sinif risk burada da var: bir gun biri `setup_app_role.py`'deki
"GRANT ... ON ALL TABLES IN SCHEMA public" satirini kopyalayip dukkan_app
icin uyarlarsa, Dukkan'in Yonetiyor verisine erisimi sessizce ACILIR.
Sinirin her `migrate` kosumunda YENIDEN dayatilmasi, o sessiz acilmayi
gurultulu bir hataya cevirir.

`test_dukkan_sinir.py` ayni seyi disaridan olcer. Ikisi birlikte: biri
sinirI kurar, oteki kurulduğunu KANITLAR.

===========================================================================
`public` SEMASI USAGE'I GERI ALINAMAZ — VE GEREKMEZ
===========================================================================
PostgreSQL'de `public` semasindaki USAGE varsayilan olarak `PUBLIC`
sozde-rolune verilidir ve her rol PUBLIC uyesidir; tek bir rolden geri
alinamaz. Yani dukkan_app semayi GOREBILIR.

Asil engel TABLO duzeyindedir: tablolarin PUBLIC'e GRANT'i yoktur ve
dukkan_app hicbir tablo GRANT'i almaz. Sonuc:
    SELECT * FROM public.app_user  ->  permission denied for table app_user

Env:
  OWNER_DSN            owner libpq DSN
  DUKKAN_DB_USER       varsayilan: dukkan_app
  DUKKAN_DB_PASSWORD   zorunlu
"""
from __future__ import annotations

import os
import sys

import psycopg
from psycopg import sql

SEMA = "dukkan"


def main() -> int:
    owner_dsn = os.environ["OWNER_DSN"]
    app_user = os.environ.get("DUKKAN_DB_USER", "dukkan_app")
    app_password = os.environ["DUKKAN_DB_PASSWORD"]

    role = sql.Identifier(app_user)
    pw = sql.Literal(app_password)
    sema = sql.Identifier(SEMA)

    with psycopg.connect(owner_dsn, autocommit=True) as conn:
        # Sema henuz yoksa goc uygulanmamis demektir. Sessizce gecmek,
        # "kuruldu" yanilgisi uretirdi — acikca hata veriyoruz.
        var = conn.execute(
            "SELECT 1 FROM information_schema.schemata WHERE schema_name = %s",
            (SEMA,),
        ).fetchone()
        if var is None:
            print(
                f"[setup_dukkan_role] HATA: '{SEMA}' semasi yok. "
                "Goc 0113 uygulanmamis.",
                file=sys.stderr,
            )
            return 1

        exists = conn.execute(
            "SELECT 1 FROM pg_roles WHERE rolname = %s", (app_user,)
        ).fetchone() is not None

        if not exists:
            conn.execute(
                sql.SQL("CREATE ROLE {role} LOGIN PASSWORD {pw} NOBYPASSRLS").format(
                    role=role, pw=pw
                )
            )

        conn.execute(
            sql.SQL("ALTER ROLE {role} WITH LOGIN PASSWORD {pw} NOBYPASSRLS").format(
                role=role, pw=pw
            )
        )

        # --- Dukkan semasi: tam DML --- #
        conn.execute(
            sql.SQL("GRANT USAGE ON SCHEMA {sema} TO {role}").format(
                sema=sema, role=role
            )
        )
        conn.execute(
            sql.SQL(
                "GRANT SELECT, INSERT, UPDATE, DELETE "
                "ON ALL TABLES IN SCHEMA {sema} TO {role}"
            ).format(sema=sema, role=role)
        )
        conn.execute(
            sql.SQL(
                "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA {sema} TO {role}"
            ).format(sema=sema, role=role)
        )
        conn.execute(
            sql.SQL(
                "ALTER DEFAULT PRIVILEGES IN SCHEMA {sema} "
                "GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO {role}"
            ).format(sema=sema, role=role)
        )

        # --- SINIR: `public` semasinda hicbir sey --- #
        # Idempotent ve her kosumda yeniden dayatiliyor (yukaridaki gerekce).
        for ifade in (
            "REVOKE ALL ON ALL TABLES IN SCHEMA public FROM {role}",
            "REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM {role}",
            "REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM {role}",
            "REVOKE CREATE ON SCHEMA public FROM {role}",
        ):
            conn.execute(sql.SQL(ifade).format(role=role))

        # Owner'in ILERIDE public'te acacagi tablolar da dukkan_app'e
        # gitmesin: varsayilan ayricaliklardan da cikariyoruz. Bu satir
        # olmazsa, owner yeni bir Yonetiyor tablosu actiginda dukkan_app
        # ona erisebilir hale GELEBILIRDI (owner'in default privileges
        # ayari degistirilmisse).
        conn.execute(
            sql.SQL(
                "ALTER DEFAULT PRIVILEGES IN SCHEMA public "
                "REVOKE ALL ON TABLES FROM {role}"
            ).format(role=role)
        )

        # --- KANIT: sinir gercekten duruyor mu? --- #
        # Kurulum betigi kendi isini DOGRULUYOR. "Kaydedildi" deyip hicbir
        # sey yapmamak, bu depoda P217'de olculmus bir kusur sinifi.
        kalan = conn.execute(
            """
            SELECT count(*) FROM information_schema.table_privileges
            WHERE grantee = %s AND table_schema = 'public'
            """,
            (app_user,),
        ).fetchone()[0]
        if kalan:
            print(
                f"[setup_dukkan_role] HATA: '{app_user}' rolunun public "
                f"semasinda hala {kalan} tablo yetkisi var.",
                file=sys.stderr,
            )
            return 1

    print(
        f"[setup_dukkan_role] '{app_user}' hazir: "
        f"'{SEMA}' semasinda DML, 'public' semasinda SIFIR yetki (dogrulandi)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
