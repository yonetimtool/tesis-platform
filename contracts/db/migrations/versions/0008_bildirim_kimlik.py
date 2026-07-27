"""bildirim_kimlik (0008) — PUSH ve in-app bildirim metinleri KIMLIGE cevrildi.

Sorun: bildirim metinleri sunucuda TURKCE uretiliyordu
(`"Kargonuz geldi — Aras (A-12)"`, `notification.mesaj`). Push ASENKRONDUR:
istegin `Accept-Language` basligi yoktur, dolayisiyla tur 14'un cozumu
(istek aninda cevirme) burada CALISMAZ. Iki sey gerekir:

  1. **Cihazin dili** — push gonderim aninda okunacak sekilde SAKLANMALI.
     `user_device.dil`: kullanicinin degil CIHAZIN dili, cunku push bir
     token'a (cihaza) gider ve kullanici uygulamayi o cihazda hangi dilde
     kullaniyorsa bildirimi de o dilde bekler. Ayni kullanicinin iki cihazi
     farkli dilde olabilir; gonderim dile gore GRUPLANIR.

  2. **Metnin kimligi** — `notification` satiri artik cumle degil KIMLIK +
     PARAMETRE tasir (`mesaj_kimlik`, `mesaj_veri`). In-app bildirim listesi
     metni okuma aninda, istegin dilinde uretir. Boylece ayni kayit her
     kullaniciya kendi dilinde gorunur — cumle DONDURULMUS olmaz.

`notification.mesaj` DEPRECATED olarak kalir (NOT NULL — eski satirlar ve
guncellenmemis istemciler icin), ama artik yapisal veriden uretilir.
Tam ADDITIVE: mevcut satirlar/sorgular etkilenmez.
"""
from alembic import op

# revision identifiers, used by Alembic.
revision = "0008_bildirim_kimlik"
down_revision = "0007_icerik_ceviri"
branch_labels = None
depends_on = None

# Desteklenen diller — mobil UI + icerik cevirisi ile AYNI kume.
_DILLER = ("tr", "en", "ar", "ru", "de", "fr", "es")


def upgrade() -> None:
    dil_listesi = ", ".join(f"'{d}'" for d in _DILLER)

    # CIHAZIN dili. Varsayilan 'tr': kayit sirasinda dil gondermeyen eski
    # istemciler bugunku davranisi korur (regresyon yok).
    op.execute(
        "ALTER TABLE user_device "
        "ADD COLUMN dil text NOT NULL DEFAULT 'tr', "
        f"ADD CONSTRAINT ck_user_device_dil CHECK (dil IN ({dil_listesi}));"
    )

    # Bildirimin KIMLIGI + parametreleri. Eski satirlarda NULL'dur; okuma
    # yolu o zaman `mesaj` alanina duser (geri uyumluluk).
    op.execute(
        "ALTER TABLE notification "
        "ADD COLUMN mesaj_kimlik text, "
        "ADD COLUMN mesaj_veri jsonb;"
    )


def downgrade() -> None:
    op.execute(
        "ALTER TABLE notification "
        "DROP COLUMN IF EXISTS mesaj_veri, "
        "DROP COLUMN IF EXISTS mesaj_kimlik;"
    )
    op.execute(
        "ALTER TABLE user_device "
        "DROP CONSTRAINT IF EXISTS ck_user_device_dil, "
        "DROP COLUMN IF EXISTS dil;"
    )
