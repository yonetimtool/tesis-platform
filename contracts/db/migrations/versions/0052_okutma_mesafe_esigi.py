"""(P160) Okutma mesafe esigi — tesis ayari.

===========================================================================
NEDEN BIR AYAR, NEDEN SABIT DEGIL
===========================================================================
Panel haritasi bir okutmanin NFC noktasina uzakligini olcuyor. Bugune
kadar bu yalnizca bir SAYIYDI: "50 m" yazip orada duruyordu, cunku
sistemde bir esik YOKTU ve panelde uydurmak bir urun karari olurdu.

Esik artik URUN KARARI OLARAK ALINDI (Kerem): varsayilan 50 m, tesis
bazinda degistirilebilir. Sabit kodlamak yanlis olurdu — bir sitede
noktalar bahce icinde 10 m araliklarla dizilidir, digerinde bloklar
arasi 200 m vardir. Ayni sayi ikisinde de anlamli olamaz.

KOLON `tenant`DA cunku bu bir TESIS POLITIKASIDIR, kisisel tercih degil.
Istemci tarafinda (localStorage) tutmak, iki yoneticinin FARKLI "esik
disi" listesi gormesi demekti.

===========================================================================
SINIRLAR VE VARSAYILAN
===========================================================================
* `NOT NULL DEFAULT 50` — mevcut tesisler goc sonrasi calisir durumda
  kalir; hicbir satir NULL kontrolu gerektirmez.
* `CHECK (1..5000)` — 0 m bir esik degil (her okutma ihlal olurdu),
  5 km ise site olceginin cok disinda. Sinirlar sunucu semasinda cunku
  API dogrulamasi tek basina yeterli degil: veriye baska bir yoldan
  yazilan deger de gecerli olmali.

`gurultu_esigi` ile AYNI DESEN (0001'deki `Integer NOT NULL DEFAULT 5`):
yeni bir kavram uydurulmadi, var olan ayar kalibina eklendi.
"""
from alembic import op

revision = "0052_okutma_mesafe_esigi"
down_revision = "0051_davet_jetonu"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        ALTER TABLE public.tenant
        ADD COLUMN okutma_mesafe_esigi_m integer NOT NULL DEFAULT 50;
        """
    )
    op.execute(
        """
        ALTER TABLE public.tenant
        ADD CONSTRAINT tenant_okutma_mesafe_esigi_araligi
        CHECK (okutma_mesafe_esigi_m BETWEEN 1 AND 5000);
        """
    )


def downgrade() -> None:
    op.execute(
        """
        ALTER TABLE public.tenant
        DROP CONSTRAINT IF EXISTS tenant_okutma_mesafe_esigi_araligi;
        """
    )
    op.execute(
        "ALTER TABLE public.tenant DROP COLUMN IF EXISTS okutma_mesafe_esigi_m;"
    )
