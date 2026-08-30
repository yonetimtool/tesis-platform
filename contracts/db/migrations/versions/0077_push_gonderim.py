"""(P191 §2) push_gonderim — HER PUSH DENEMESİNİN İZİ

Ölçülen kusur: altyapı P181/P183'te yazıldı ama uçtan uca HİÇ ÇALIŞTIĞI
GÖRÜLMEDİ. Bildirim gelmediğinde bakılacak TEK BİR YER yoktu: sağlayıcı
noop mu, cihaz kaydı var mı, tercih kapalı mı, FCM ne dedi — hepsi ya
konteyner loglarında ya hiçbir yerdeydi.

Bu tablo zincirin ÇIKTI UCUNU kalıcı yapar: kime, ne zaman, hangi olay,
sonuç ne. Yönetici panelinde "Son push denemeleri" bu tablodan okunur.

TASARIM KARARLARI

* SATIR BAŞINA BİR CİHAZ. Toplu duyuruda 200 satır olur; alternatif
  (olay başına tek özet satır) "Ahmet'e gitti mi?" sorusunu
  cevaplayamazdı — teşhisin bütün değeri o soruda.
* HEDEFİ OLMAYAN DENEME DE YAZILIR (`durum='hedef_yok'`). Sessiz kalmak,
  "push hiç tetiklenmedi" ile "tetiklendi ama cihaz yok"u ayırt
  edilemez yapardı; ikisi TAMAMEN farklı iki arızadır.
* TOKEN SAKLANMAZ, MASKELENİR (son 6 karakter). Token bir kimlik
  bilgisidir; teşhis için "hangi cihaz" ayrımı bu kadarıyla yapılır.
* METİN SAKLANMAZ. Bildirim metni `notification` tablosunda zaten var ve
  orası KVKK saklama görevine bağlı. Burada yalnız `kimlik` (olay tipi).
* SAKLAMA: gecelik temizlik 30 günden eskisini siler (retention.py).

Revision ID: 0077_push_gonderim
Revises: 0076_ui_tema
Create Date: 2026-08-30
"""
from alembic import op

revision = "0077_push_gonderim"
down_revision = "0076_ui_tema"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"

#: Sonuç kümesi — zincirin NEREDE koptuğunu tek kelimeyle söyler.
#:   gonderildi        FCM isteği kabul etti
#:   gecersiz_token    FCM kalıcı reddetti (UNREGISTERED/INVALID_ARGUMENT) → budandı
#:   basarisiz         geçici hata / ağ / kota (token korunur)
#:   noop              PUSH_PROVIDER=noop — sağlayıcı hiç aranmadı
#:   yapilandirilmadi  sağlayıcı fcm ama service account/proje yok
#:   hedef_yok         olay tetiklendi ama gönderilecek AKTİF CİHAZ yok
_DURUMLAR = (
    "gonderildi",
    "gecersiz_token",
    "basarisiz",
    "noop",
    "yapilandirilmadi",
    "hedef_yok",
)


def upgrade() -> None:
    durum_listesi = ", ".join(f"'{d}'" for d in _DURUMLAR)
    op.execute(
        f"""
        CREATE TABLE push_gonderim (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            -- Olay tipi = push_metinleri kimliği = notification.tip.
            kimlik      text NOT NULL,
            -- Alıcı. `hedef_yok` satırında NULL olabilir (kimse yoktu).
            -- ON DELETE SET NULL: kullanıcı silinince iz KALIR ama kime
            -- ait olduğu düşer — KVKK silme hakkı ile teşhis arasındaki denge.
            user_id     uuid REFERENCES app_user (id) ON DELETE SET NULL,
            -- Cihaz jetonunun SON 6 KARAKTERİ (tam jeton saklanmaz).
            token_son6  text,
            platform    text,
            saglayici   text NOT NULL,
            durum       text NOT NULL,
            -- FCM'in hata kodu (UNREGISTERED, QUOTA_EXCEEDED, ...) ya da
            -- yerel neden. PII taşımaz.
            hata_kodu   text,
            created_at  timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT ck_push_gonderim_durum CHECK (durum IN ({durum_listesi}))
        );
        """
    )
    # Okuma deseni: "bu tesisin son denemeleri" (panel) ve "bu kişiye ne gitti".
    op.execute(
        "CREATE INDEX ix_push_gonderim_tenant_zaman "
        "ON push_gonderim (tenant_id, created_at DESC);"
    )
    op.execute(
        "CREATE INDEX ix_push_gonderim_user "
        "ON push_gonderim (tenant_id, user_id, created_at DESC);"
    )

    op.execute("ALTER TABLE push_gonderim ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE push_gonderim FORCE ROW LEVEL SECURITY;")
    op.execute(
        """
        CREATE POLICY push_gonderim_isolation ON push_gonderim
            USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
            WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
        """
    )
    # DELETE VAR: saklama süresi dolan satırları gecelik temizlik siler.
    # (Denetim kaydı DEĞİLDİR — bu bir işletim telemetrisidir.)
    op.execute(
        f"GRANT SELECT, INSERT, DELETE ON push_gonderim TO {APP_ROLE};"
    )


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS push_gonderim;")
