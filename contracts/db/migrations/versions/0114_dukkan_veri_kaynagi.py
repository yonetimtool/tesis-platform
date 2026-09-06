"""(DUKKAN F1) `dukkan.veri_kaynagi` — dis veri kaynagi IZI.

===========================================================================
NEDEN BIR TABLO, NEDEN BELGEDE BIR CUMLE DEGIL
===========================================================================
Lokasyon agaci (81 il / ~970 ilce / ~45.000 mahalle) DISARIDAN geliyor.
Kullanicinin sarti acikti: "Lisansi net olsun, kaynagi ve indirme tarihini
belgele, guncelleme yolu tanimli olsun."

Bunu bir markdown dosyasina yazmak yetmez: iki yil sonra "bu mahalle
listesi nereden geldi, ne zaman, hangi surumden?" diye soran kisi kodu
degil VERITABANINI sorgular. Kaynak izini verinin YANINDA tutmak, o
soruyu tek bir SELECT ile yanitlanabilir yapiyor.

Ayrica `sha256` alani, ayni dosyanin yeniden yuklenip yuklenmedigini
kesin olarak soyler — dosya adi ya da tarih yanilticidir, ozet degildir.

===========================================================================
`onarim_notu` NE ISE YARAR
===========================================================================
Yuklenen veri HAM HALIYLE KULLANILAMAZDI ve bu OLCULDU:
  * 74.402 Turkce mahalle adinda 'ı' harfi SIFIR kez geciyordu
    (istatistiksel olarak imkansiz),
  * adlarin %83,6'si U+0307 birlesen noktayla bozuktu ("Mahallesi̇"),
  * il adlari bile bozuktu ("Balikesi̇r", "Di̇yarbakir").
Kaynak, Turkce olmayan bir yerel ayarla kucultulmus ve bozulma
DETERMINISTIK oldugu icin geri dondurulebildi (81/81 il ve 39/39
Istanbul ilcesi dogru adla eslesti).

Bu onarimin YAPILDIGI kayit altina alinmali: veri "oldugu gibi" degil,
"islenmis" haliyle duruyor ve bunu bilmeyen biri ileride ham kaynakla
karsilastirdiginda farki kusur sanabilir.
"""
from alembic import op

revision = "0114_dukkan_veri_kaynagi"
down_revision = "0113_dukkan_sema_ve_rol"
branch_labels = None
depends_on = None

SEMA = "dukkan"


def upgrade() -> None:
    op.execute(
        f"""
        CREATE TABLE {SEMA}.veri_kaynagi (
            id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tur            text NOT NULL,          -- 'lokasyon' | 'kategori'
            kaynak_url     text NOT NULL,
            lisans         text NOT NULL,          -- orn 'MIT'
            surum          text,                   -- commit/etiket, biliniyorsa
            sha256         text NOT NULL,
            indirme_tarihi date NOT NULL,
            kayit_sayisi   jsonb NOT NULL DEFAULT '{{}}'::jsonb,
            onarim_notu    text,
            not_metni      text,
            created_at     timestamptz NOT NULL DEFAULT now()
        );
        """
    )
    # Ayni ozetin ayni tur icin iki kez yazilmasi anlamsiz (ayni dosya).
    op.execute(
        f"CREATE UNIQUE INDEX uq_veri_kaynagi_tur_sha ON {SEMA}.veri_kaynagi "
        "(tur, sha256);"
    )
    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON {SEMA}.veri_kaynagi "
        "TO dukkan_app;"
    )


def downgrade() -> None:
    op.execute(f"DROP TABLE IF EXISTS {SEMA}.veri_kaynagi;")
