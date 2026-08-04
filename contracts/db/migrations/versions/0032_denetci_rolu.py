"""denetci rolu (0032) — MASTER-PLAN P128: tesisin SALT-OKUMA mali gozetimi.

NEDEN YENI BIR ROL: denetim kurulu / bagimsiz denetci bugune kadar ya
YONETICI hesabiyla giriyordu — yani denetledigi kayitlari DEGISTIREBILEN
biri olarak; denetimin bagimsizligi tam burada biter — ya da hic giremiyor
ve tesis kendi verisini disari dokum olarak tasiyordu. Mevcut rollerden
birine yamamak ("denetciyi de yonetici yapalim") ayni sorunu buyutur:
yonetici sakin verisini, tesis ayarlarini ve personel kayitlarini da yazar.

GOREV PENCERESI SEMADA, KODDA DEGIL: bir denetcinin yetkisi sureklidir
diye varsaymak yanlis — gorev suresi biten denetci ertesi gun tesisin
finansini okumaya devam ederdi. `gorev_baslangic`/`gorev_bitis` ikisi de
NULL olabilir (sinirsiz gorev; kucuk tesisler icin gercek durum) ve
uygulama HER istekte pencereyi olcer.

KOLONLAR ROLE OZEL ADLANDIRILMADI (`denetci_*` degil `gorev_*`): ayni
pencere yarin baska bir gecici rol icin de gecerli olabilir; kolon adina
rol gommek, o gun ya olu bir ad ya da ikinci bir kolon demekti.

ENUM'A DEGER EKLEME VE GERI ALMA: 0024'un (guvenlik_amiri) kararini
AYNEN izler — PostgreSQL bir enum degerini kaldiramaz; tek yol tipi
yeniden kurmaktir ve `user_role`a RLS politikalari baglidir. `downgrade`
bu yuzden ETIKETI BIRAKIR ve yalnizca onu KULLANAN her seyi geri alir.

DUSURULEN DENETCI SILINMEZ, PASIFLESTIRILIR: 0024 amiri `security`ye
dusurmustu (en yakin mevcut rol). Denetcinin "en yakin"i YOKTUR — her
mevcut rol ona bugun sahip olmadigi bir yazma yetkisi verirdi. Hesap
`resident` rolune dusurulur **ve** `is_active=false` yapilir: veri
kaybolmaz, yetki de sessizce genislemez.

Revision ID: 0032_denetci_rolu
Revises: 0031_kamera_snapshot
"""
from __future__ import annotations

from alembic import op

revision = "0032_denetci_rolu"
down_revision = "0031_kamera_snapshot"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'denetci';")
    op.execute(
        """
        ALTER TABLE app_user
            ADD COLUMN gorev_baslangic date NULL,
            ADD COLUMN gorev_bitis     date NULL;
        """
    )
    # Ters pencere (bitis < baslangic) bir VERI hatasidir; uygulamada
    # dogrulanir ama semada da kapatilir — API disindan (destek scripti,
    # elle SQL) girilen kayit da bu kisiti gecmek zorunda.
    op.execute(
        """
        ALTER TABLE app_user
            ADD CONSTRAINT ck_app_user_gorev_penceresi
            CHECK (
                gorev_baslangic IS NULL
                OR gorev_bitis IS NULL
                OR gorev_bitis >= gorev_baslangic
            );
        """
    )


def downgrade() -> None:
    # Denetci hesaplari KAYBOLMAZ; yetkisiz ve pasif hale gelir (bkz.
    # docstring — "en yakin rol" yok, o yuzden pasiflestirme).
    op.execute(
        "UPDATE app_user SET role = 'resident', is_active = false "
        "WHERE role = 'denetci';"
    )
    op.execute(
        "ALTER TABLE app_user DROP CONSTRAINT IF EXISTS ck_app_user_gorev_penceresi;"
    )
    op.execute("ALTER TABLE app_user DROP COLUMN IF EXISTS gorev_bitis;")
    op.execute("ALTER TABLE app_user DROP COLUMN IF EXISTS gorev_baslangic;")
    # `denetci` etiketi tipte KALIR (0024 ile ayni gerekce).
