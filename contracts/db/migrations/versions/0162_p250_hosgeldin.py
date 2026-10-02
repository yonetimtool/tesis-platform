"""(P250 §3) Hos geldiniz e-postasi — "bir kez" isareti.

`app_user.hosgeldin_at`: hos geldiniz e-postasinin GONDERILDIGI (ya da
gonderilmis sayildigi) an. Gonderim `UPDATE ... WHERE hosgeldin_at IS NULL
RETURNING` ile yapilir: ayni anda gelen iki tamamlama istegi (cift tik,
yeniden deneme) yalniz BIR e-posta uretir; tekrar kayit ve rol degisimi
isareti silmez, e-posta tekrar gitmez.

GERI DOLDURMA — MEVCUT HESAPLARA E-POSTA GITMESIN:
kaydini zaten tamamlamis (parolasi kurulmus YA DA sosyal kimligi bagli)
her hesap "karsilanmis" sayilir. Aksi halde bu hesaplardan biri parolasini
sifirladiginda ya da bir davet yeniden kullanildiginda aylardir kullanilan
bir hesaba "hos geldiniz" giderdi. Kaydini HENUZ tamamlamamis hesaplar
(davet bekleyen) NULL kalir ve tamamladiklarinda e-postayi alir.
"""
from alembic import op

revision = "0162_p250_hosgeldin"
down_revision = "0161_p250_gonderim_turu"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE app_user ADD COLUMN hosgeldin_at timestamptz NULL;")
    op.execute(
        """
        UPDATE app_user u
           SET hosgeldin_at = u.created_at
         WHERE u.password_set
            OR EXISTS (SELECT 1 FROM oauth_kimlik k WHERE k.user_id = u.id);
        """
    )


def downgrade() -> None:
    op.execute("ALTER TABLE app_user DROP COLUMN IF EXISTS hosgeldin_at;")
