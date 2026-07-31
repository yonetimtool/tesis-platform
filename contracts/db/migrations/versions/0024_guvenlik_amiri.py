"""guvenlik amiri (0024) — MASTER-PLAN P35: altinci rol + tenant guvenlik modu.

NEDEN YENI BIR ROL: bugune kadar guvenligi HER ZAMAN yonetici planliyordu.
Bu, guvenligi DIS BIR SIRKETIN yuruttugu tesislerde yanlis: orada vardiyayi
ve tur penceresini kuran kisi site yoneticisi DEGIL, guvenlik sirketinin
amiridir; yonetici izler ama karisamaz. Mevcut rollerden birine yamamak
("amiri de yonetici yapalim") yoneticiye finans, sakin verisi ve tesis
ayarlarini da acardi — DIS bir sirketin personeline.

MOD TENANT AYARIDIR, GLOBAL DEGIL:
  * `yonetim_ici` (VARSAYILAN, bugunku davranis) — yonetici planlar,
  * `dis_sirket`  — amir planlar, yonetici SALT-OKUR izler.
Mevcut tesislerin hicbiri etkilenmez: varsayilan bugunku davranistir.

ROL SAHIPLIGI SEMADA DEGIL KODDA: "kim planlayabilir" sorusu MODA baglidir
ve mod calisma aninda degisebilir. Bunu tabloya gomulu bir yetki matrisine
cevirmek, her mod degisiminde satir guncellemek demekti.

ENUM'A DEGER EKLEME VE GERI ALMA: PostgreSQL bir enum degerini KALDIRAMAZ;
tek yol tipi yeniden kurmaktir. Ama `user_role` tipine RLS POLITIKALARI
(`role = 'yonetici'::public.user_role`) ve `audit_log.actor_role` bagli —
tipi yeniden kurmak bu politikalari dusurup yeniden yazmayi gerektirirdi ve
bir GERI ALMA adiminin guvenlik politikalarini yeniden yazmasi kabul
edilemez risk. Bu yuzden `downgrade` **degeri birakir** ve yalnizca onu
KULLANAN her seyi geri alir: kolon, mod tipi ve `guvenlik_amiri`
kullanicilarin rolu (`security`ye dusurulur — kullanici SILMEK geri
alinamaz bir veri kaybi olurdu). Artik kullanilmayan bir enum etiketi
zararsizdir; `goc-tersinirlik` zinciri de base'e inerken tipi 0001 ile
zaten dusurur.

Revision ID: 0024_guvenlik_amiri
Revises: 0023_tur_butunlugu
"""
from __future__ import annotations

from alembic import op

revision = "0024_guvenlik_amiri"
down_revision = "0023_tur_butunlugu"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'guvenlik_amiri';")
    op.execute(
        "CREATE TYPE guvenlik_modu AS ENUM ('yonetim_ici', 'dis_sirket');"
    )
    op.execute(
        """
        ALTER TABLE tenant
            ADD COLUMN guvenlik_modu guvenlik_modu NOT NULL
                DEFAULT 'yonetim_ici';
        """
    )


def downgrade() -> None:
    # Amir rolundeki kullanicilar KAYBOLMAZ: uygulama bu rolu artik
    # bilmeyecegi icin en yakin mevcut role (`security`) dusurulurler.
    op.execute(
        "UPDATE app_user SET role = 'security' WHERE role = 'guvenlik_amiri';"
    )
    op.execute("ALTER TABLE tenant DROP COLUMN IF EXISTS guvenlik_modu;")
    op.execute("DROP TYPE IF EXISTS guvenlik_modu;")
    # `guvenlik_amiri` etiketi tipte KALIR (bkz. docstring): kaldirmak tipi
    # yeniden kurmayi, o da `user_role`a bagli RLS politikalarini yeniden
    # yazmayi gerektirirdi. Kullanilmayan etiket zararsizdir.
