"""(E2E 2026-09) YONETIM ALARMLARINDA OKUNDU / SILINDI KISIYE AIT.

=========================================================================
OLCULEN KUSUR
=========================================================================
Tesise ait yonetim alarmlari (`notification.user_id IS NULL`: kacirilan
tur, vardiyaya baslamadi, bakim, gurultu eskalasyonu, entegrasyon koptu)
TEK SATIR olarak yaziliyor ve yonetim gozundeki HERKES ayni satiri
goruyor. Okundu/silindi de o satirin kendi kolonlarindaydi: bir guvenlik
gorevlisinin "okundu"su ya da silmesi, yoneticinin listesinden de
kayboluyordu. Olculdu: security2 bir `bakim_bugun` alarmini okundu yapti
-> yonetici ve amirin "Okunmus" sekmesine dustu; yonetici 4 alarmi sildi
-> amirin listesinden de gitti. Bir gorevli "vardiyaya baslamadi"
uyarisini silerek yoneticinin gormesini engelleyebiliyordu.

`sakin_bildirimi.py`nin kendi ilkesi zaten bu: "Tek satiri paylastirsaydik
bir kullanicinin okumasi digerininkini de okundu yapardi".

=========================================================================
NEDEN YAZICILARI DEGISTIRMEK YERINE AYRI TABLO
=========================================================================
Alarmi alici basina satir olarak yazmak bes ayri yaziciyi (beat dahil) ve
alici kumesinin YAZMA ANINDA sabitlenmesini gerektirirdi — sonradan ise
alinan bir guvenlik gorevlisi eski alarmlari hic gormezdi. Paylasilan
satir DURUR; yalniz kisiye ait DURUM ayri tutulur. Kendi satirlari
(`user_id = kisi`) eskisi gibi kendi kolonlarini kullanir.

=========================================================================
EK: CALISMA GECMISI HESAP SILMEDE KAYBOLMAZ (E2E 2026-09, YETKI-11)
=========================================================================
`vardiya_plani` ve `vardiya_izin` -> `app_user` FK'leri ON DELETE CASCADE
idi: personel kendi hesabini silince (`/me/hesap-sil`) vardiya ve izin
gecmisi SESSIZCE siliniyordu — mesai hesabi `vardiya_plani`den okundugu
icin o kisinin gecmis calisma kaydi da gidiyordu. `hesap_silme.py`
"gecmisi olan hesap FK hatasi verir -> anonimlestirilir" varsayimina
dayaniyor; CASCADE bu varsayimi deliyordu.

NO ACTION (RESTRICT degil): tesis silme `tenant` -> hem `app_user` hem
`vardiya_plani` CASCADE'ini AYNI ifadede yurutur; NO ACTION denetimi ifade
SONUNDA yapildigi icin tesis silme kirilmaz, tekil kullanici silme ise
FK hatasi verir ve anonimlestirmeye duser.
"""
from alembic import op

revision = "0149_bildirim_kisi_durumu"
down_revision = "0148_ilk_giris_turu"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE notification_kisi_durumu (
            tenant_id       uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            notification_id uuid NOT NULL REFERENCES notification (id) ON DELETE CASCADE,
            user_id         uuid NOT NULL,
            okundu_at       timestamptz,
            silindi_at      timestamptz,
            PRIMARY KEY (notification_id, user_id),
            CONSTRAINT fk_notification_kisi_durumu_user
                FOREIGN KEY (user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE CASCADE
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_notification_kisi_durumu_kisi "
        "ON notification_kisi_durumu (tenant_id, user_id);"
    )
    op.execute("ALTER TABLE notification_kisi_durumu ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE notification_kisi_durumu FORCE ROW LEVEL SECURITY;")
    op.execute(
        """
        CREATE POLICY notification_kisi_durumu_isolation ON notification_kisi_durumu
            USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
            WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
        """
    )
    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON notification_kisi_durumu TO {APP_ROLE};"
    )

    for tablo, ad in (("vardiya_plani", "fk_vardiya_plani_user"),
                      ("vardiya_izin", "fk_izin_user")):
        op.execute(f"ALTER TABLE {tablo} DROP CONSTRAINT {ad};")
        op.execute(
            f"ALTER TABLE {tablo} ADD CONSTRAINT {ad} "
            "FOREIGN KEY (user_id, tenant_id) "
            "REFERENCES app_user (id, tenant_id) ON DELETE NO ACTION;"
        )


def downgrade() -> None:
    for tablo, ad in (("vardiya_plani", "fk_vardiya_plani_user"),
                      ("vardiya_izin", "fk_izin_user")):
        op.execute(f"ALTER TABLE {tablo} DROP CONSTRAINT {ad};")
        op.execute(
            f"ALTER TABLE {tablo} ADD CONSTRAINT {ad} "
            "FOREIGN KEY (user_id, tenant_id) "
            "REFERENCES app_user (id, tenant_id) ON DELETE CASCADE;"
        )
    op.execute("DROP TABLE IF EXISTS notification_kisi_durumu;")
