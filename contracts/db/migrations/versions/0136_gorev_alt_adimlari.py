"""(P237 §2) GOREV ALT ADIMLARI — asamali ilerleme.

===========================================================================
OLCULEN DURUM
===========================================================================
`task` bir isi TEK PARCA olarak tasiyordu: ya acik ya tamamlanmis.
`task_completion` da gorev basina tek bir kapanis kaydiydi (foto + not).
"A, B, C bloklarini temizle" gibi bir is verildiginde yonetici, A bitip
B'ye gecildigini HICBIR YERDEN goremiyordu — yalnizca "henuz bitmedi".

Alt adim kavrami YOKTU; bu goc onu aciyor.

===========================================================================
NEDEN AYRI TABLO, NEDEN JSON DEGIL
===========================================================================
Adimlar `task` icinde bir JSON dizisi de olabilirdi. Olmadi, cunku her
adim KENDI tamamlayanini, zamanini ve FOTOGRAFINI tasiyor: bunlar
sorgulanacak (kim ne zaman bitirdi), yetkilendirilecek (RLS) ve
raporlanacak alanlar. JSON'da hepsi uygulama katmaninda cozulurdu ve
"kim bitirdi" sorusu bir FK ile degil bir metinle yanitlanirdi.

===========================================================================
TAMAMLAMA ALANLARI ADIMIN USTUNDE (ayri kayit tablosu DEGIL)
===========================================================================
Bir adim bir kez tamamlanir; ikinci bir tamamlama "geri al + yeniden"
demektir. Ayri bir `task_step_completion` tablosu bu basit gercegi
karmasiklastirirdi ve her okuma bir JOIN daha isterdi.

BEDELI ACIKCA YAZIYORUM: PERIYODIK gorevde periyot ilerleyince adimlar
sifirlanir ve onceki turun adim-duzeyi izi (kim/ne zaman/foto) TABLODA
KALMAZ. Kalici iz `audit_log`'a yazilir (foto anahtari dahil; fotograf
nesne deposunda durur) ve gorev-duzeyi `task_completion` kaydi zaten
korunur. Periyodik gorev + adim birlikteligi nadir; bu bedel bilincli.
"""
from alembic import op

revision = "0136_gorev_alt_adimlari"
down_revision = "0135_eposta_teslim_bildirimi"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE task_step (
            id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id  uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            task_id    uuid NOT NULL,
            -- SIRA: hem gosterim duzeni hem (task.adim_sirali ise) zorunlu
            -- akis. Esit sira degerleri serbest: yonetici uc adimi ayni
            -- anda tanimladiginda hepsi 0 olabilir.
            sira       integer NOT NULL DEFAULT 0,
            ad         text NOT NULL,
            -- ADIM BAZINDA FOTOGRAF: gorevin `foto_zorunlu` bayragi
            -- varsayilani belirler, adim onu SIKILASTIRABILIR. Gevsetme
            -- yok: gorev "fotografsiz kapanmasin" diyorsa bir adimin
            -- bundan muaf olmasi kurali delerdi.
            foto_zorunlu boolean NOT NULL DEFAULT false,
            -- TAMAMLAMA: `tamamlanma_zamani IS NOT NULL` = adim bitti.
            tamamlayan_user_id uuid,
            tamamlanma_zamani  timestamptz,
            foto_key   text,
            foto_url   text,
            notlar     text,
            created_at timestamptz NOT NULL DEFAULT now(),
            updated_at timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_task_step_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT fk_task_step_task
                FOREIGN KEY (task_id, tenant_id)
                REFERENCES task (id, tenant_id) ON DELETE CASCADE,
            -- KOLON-OZEL SET NULL: hesap silinse de adimin kendisi ve
            -- fotografi KALIR; yalnizca "kim" bilgisi dusar. Tum satiri
            -- silmek, yapilmis isi yok saymak olurdu.
            CONSTRAINT fk_task_step_user
                FOREIGN KEY (tamamlayan_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id)
                ON DELETE SET NULL (tamamlayan_user_id)
        );
        """
    )
    # Gorev detayinda adimlar HER ZAMAN gorev kimligiyle ve sirayla okunur.
    op.execute(
        "CREATE INDEX ix_task_step_task ON task_step (tenant_id, task_id, sira);"
    )
    op.execute("ALTER TABLE task_step ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE task_step FORCE ROW LEVEL SECURITY;")
    op.execute(
        """
        CREATE POLICY task_step_isolation ON task_step
            USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
            WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
        """
    )
    op.execute(f"GRANT SELECT, INSERT, UPDATE, DELETE ON task_step TO {APP_ROLE};")

    # SIRALI AKIS: varsayilan SERBEST. Sahada sira cogu zaman sabit
    # degildir (A blogunun kapisi kilitli olabilir); zorunlu sira, isi
    # bastan durdururdu. Gercekten sirali isler icin gorev duzeyinde bayrak.
    op.execute(
        "ALTER TABLE task ADD COLUMN adim_sirali boolean NOT NULL DEFAULT false;"
    )
    # BILDIRIM YORGUNLUGU KAPISI: her adimda push atmak, yirmi adimlik
    # gorevde yirmi bildirim demekti. Son bildirim ani burada tutulur;
    # arasindaki adimlar TOPLANIP tek bildirime dusuyor (bkz. tasks.py).
    op.execute("ALTER TABLE task ADD COLUMN son_adim_bildirim_at timestamptz;")

    # YENI BILDIRIM TIPI. `gorev_tamamlandi`ya BINDIRILMEDI: tamamlanma
    # gorevin SONUNU, ilerleme ORTASINI bildirir; tek tipe indirmek,
    # bildirim tercihinde "ilerlemeyi kapat, bitisi al" demeyi imkansiz
    # kilardi (0131'in `gorev_atandi` icin verdigi ayni gerekce).
    #
    # ADD VALUE IF NOT EXISTS: gocun tekrar kosulmasi (kurtarma) hata
    # vermemeli. Downgrade deger SILMEZ — PostgreSQL enum'dan deger
    # cikaramaz; tipi yeniden kurup tum kolonlari tasimak, bu satirin
    # tasidigindan cok daha buyuk bir risk (0131 ile ayni karar).
    op.execute(
        "ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS "
        "'gorev_adim_ilerleme';"
    )


def downgrade() -> None:
    op.execute("ALTER TABLE task DROP COLUMN IF EXISTS son_adim_bildirim_at;")
    op.execute("ALTER TABLE task DROP COLUMN IF EXISTS adim_sirali;")
    op.execute("DROP TABLE IF EXISTS task_step;")
