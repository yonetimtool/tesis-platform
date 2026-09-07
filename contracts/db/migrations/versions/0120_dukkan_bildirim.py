"""(DUKKAN F6) BILDIRIM + CIHAZ — ve Yonetiyor koprusu izleri.

===========================================================================
NEDEN AYRI BILDIRIM TABLOSU
===========================================================================
Yonetiyor'un `notification` tablosu `tenant_id` ZORUNLU tutuyor ve RLS
`app.current_tenant_id` uzerinden calisiyor. Dukkan cok-kiracili DEGIL;
bir Dukkan kullanicisinin tesisi olmayabilir (bagimsiz kullanici).

Ayrica `dukkan_app` rolunun `public` semasinda hicbir yetkisi yok — o
tabloya yazamaz bile (goc 0113). Ayri tablo bir tercih degil, ZORUNLULUK.

PUSH SAGLAYICISI ISE PAYLASILIYOR (`app.push.get_push_provider`): FCM
kimligi, HTTP katmani ve hata eslemesi iki urunde de ayni. Ayrisan sey
KIME gonderildigi, NASIL gonderildigi degil.

===========================================================================
CIHAZ JETONU NEDEN AYRI TABLODA
===========================================================================
Ayni fiziksel cihaz Yonetiyor'da `user_device`, Dukkan'da `dukkan_cihaz`
satirina sahip olur ve FCM jetonu AYNI olabilir. Bu bir tekrar degil:
jeton bir CIHAZI tanimlar, satir ise "bu cihaz SU kullaniciya ait"
iliskisini. Iki urunun kullanici kimligi farkli oldugu icin iliski de
ayri.

Yonetiyor hesabini silen bir kullanicinin Dukkan bildirimlerinin kesilmesi
GEREKMEZ — iki hesap bagimsiz yasar.

===========================================================================
`okundu_at` VE `gonderildi_at` AYRI
===========================================================================
"Gonderildi" saglayicinin KABUL ettigi an; "okundu" kullanicinin gordugu
an. Ikisini tek sutunda tutmak, teslim edilmemis bir bildirimi "okunmadi"
sanmak ya da tersini yapmak olurdu (P191'de push teshisinde ayni ayrim).

GERI ALINABILIR.
"""
from alembic import op

revision = "0120_dukkan_bildirim"
down_revision = "0119_dukkan_guven"
branch_labels = None
depends_on = None

SEMA = "dukkan"
ROL = "dukkan_app"


def upgrade() -> None:
    op.execute(
        f"""
        CREATE TABLE {SEMA}.dukkan_cihaz (
            id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            kullanici_id uuid NOT NULL
                REFERENCES {SEMA}.dukkan_kullanici(id) ON DELETE CASCADE,
            fcm_token    text NOT NULL,
            platform     text CHECK (platform IN ('android','ios','web')),
            dil          text NOT NULL DEFAULT 'tr',
            son_gorulme  timestamptz NOT NULL DEFAULT now(),
            created_at   timestamptz NOT NULL DEFAULT now(),
            -- AYNI JETON IKI KULLANICIYA BAGLANAMAZ: cihaz el degistirirse
            -- (ortak telefon, ikinci el) eski sahibin bildirimleri yeni
            -- kullaniciya DUSMEMELI.
            UNIQUE (fcm_token)
        );
        """
    )
    op.execute(
        f"CREATE INDEX ix_dukkan_cihaz_kullanici ON {SEMA}.dukkan_cihaz "
        "(kullanici_id);"
    )

    op.execute(
        f"""
        CREATE TABLE {SEMA}.bildirim (
            id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            kullanici_id  uuid NOT NULL
                REFERENCES {SEMA}.dukkan_kullanici(id) ON DELETE CASCADE,
            tip           text NOT NULL,
            -- METIN KAYDA DONDURULMAZ: satir `tip` + `veri` tutar, okuma
            -- yolu metni ISTEGIN dilinde uretir. Yonetiyor'un
            -- `sakin_bildirimi.py` dosyasinda ayni karar yazili — 7 dilli
            -- bir uygulamada kaydedilmis metin, dil degistiginde ESKI
            -- dilde kalirdi.
            veri          jsonb NOT NULL DEFAULT '{{}}'::jsonb,
            -- Tiklandiginda gidilecek yol (mobil + web ayni degeri okur).
            hedef_yol     text,
            gonderildi_at timestamptz,
            okundu_at     timestamptz,
            created_at    timestamptz NOT NULL DEFAULT now()
        );
        """
    )
    # Okunmamis rozeti icin sicak yol.
    op.execute(
        f"CREATE INDEX ix_bildirim_okunmamis ON {SEMA}.bildirim "
        "(kullanici_id, created_at DESC) WHERE okundu_at IS NULL;"
    )
    op.execute(
        f"CREATE INDEX ix_bildirim_kullanici ON {SEMA}.bildirim "
        "(kullanici_id, created_at DESC);"
    )

    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON "
        f"{SEMA}.dukkan_cihaz, {SEMA}.bildirim TO {ROL};"
    )


def downgrade() -> None:
    op.execute(f"DROP TABLE IF EXISTS {SEMA}.bildirim CASCADE;")
    op.execute(f"DROP TABLE IF EXISTS {SEMA}.dukkan_cihaz CASCADE;")
