"""(DUKKAN) BILDIRIM TERCIHI — Dukkan'in KENDI anahtari.

===========================================================================
NEDEN YONETIYOR'UN `bildirim_mobil` ALANI KULLANILMIYOR
===========================================================================
Iki sebep, ikisi de belirleyici:

1. **Dukkan kullanicisinin Yonetiyor hesabi OLMAYABILIR.** Bagimsiz
   kullanici (telefonla kaydolmus, hicbir tesise bagli degil) `app_user`
   satirina sahip degildir. Onun tercihini `app_user.bildirim_mobil`de
   tutmak imkansiz — ve `dukkan_app` rolu o tabloya erisemiyor zaten
   (goc 0113).

2. **Iki urunun bildirimleri FARKLI seyler.** "Binanizda gurultu
   sikayeti var" ile "teklifiniz geldi" ayni kapiyla yonetilirse,
   pazar yeri bildirimlerinden bunalan kullanici SITESININ bildirimlerini
   de kapatir. Tersi de dogru: is bekleyen bir usta, tesis duyurularini
   susturmak isteyebilir ama tekliflerini KACIRMAK istemez.

Ayri anahtar, iki urunun birbirini SUSTURMASINI onluyor.

===========================================================================
VARSAYILAN ACIK — VE BU BILINCLI
===========================================================================
Bildirim bir TERCIHTIR, riza degil (pazarlama rizasindan farki bu;
Yonetiyor'da `bildirim_mobil` icin ayni ayrim yazili). Talep/teklif
akisinin KALBI bildirim: kapali baslasaydi, ilk teklifini goremeyen
kullanici pazar yerinin calismadigini dusunurdu.

`bildirim_sesli` AYRI bir soru: "bildirim gelsin mi" degil, "SESLI mi
gelsin". Ikisini tek anahtara baglamak, "gece caliyor" diyen kullaniciya
bildirimin TAMAMINI kapattirirdi (P207'de birebir bu karar verildi).

GERI ALINABILIR.
"""
from alembic import op

revision = "0121_dukkan_bildirim_tercihi"
down_revision = "0120_dukkan_bildirim"
branch_labels = None
depends_on = None

SEMA = "dukkan"


def upgrade() -> None:
    op.execute(
        f"""
        ALTER TABLE {SEMA}.dukkan_kullanici
          ADD COLUMN bildirim_acik  boolean NOT NULL DEFAULT true,
          ADD COLUMN bildirim_sesli boolean NOT NULL DEFAULT true;
        """
    )


def downgrade() -> None:
    op.execute(
        f"ALTER TABLE {SEMA}.dukkan_kullanici "
        "DROP COLUMN IF EXISTS bildirim_acik, "
        "DROP COLUMN IF EXISTS bildirim_sesli;"
    )
