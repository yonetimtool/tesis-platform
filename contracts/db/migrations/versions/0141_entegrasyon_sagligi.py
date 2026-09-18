"""(P240 §4) ENTEGRASYON SAGLIGI — durum, son iletisim, hata ve bildirim damgasi.

===========================================================================
OLCULEN KUSUR
===========================================================================
`integration` tablosu bir entegrasyonun TANIMINI tutuyordu ama DURUMUNU
hic tutmuyordu. Yonetici "diyafon bagli mi", "akilli ev kopmus mu"
sorusunu ancak ELLE "Test" dugmesine basarak yanitlayabiliyordu — yani
kopan bir baglanti, biri elle bakana kadar SESSIZ kaliyordu.

===========================================================================
SAGLIK KONTROLU TETIKLEME DEGILDIR — ve bu ayrim hayati
===========================================================================
"Duzenli saglik kontrolu" isteginin en kolay yorumu "her 15 dakikada bir
entegrasyonu tetikle"dir. BU YANLIS OLURDU: entegrasyonlarin kanallari
`megaphone` (siteye anons yapan hoparlor) ve `smarthome` (kapi acan,
vana kapatan cihaz). Onlari periyodik olarak TETIKLEMEK, gunde 96 kez
anons yapmak ya da kapi acmak demekti.

Bu yuzden saglik kontrolu HTTP ISTEGI GONDERMEZ: SSRF kapisindan gecirip
hedefe TCP baglantisi acar ve kapatir. Olculen sey "adres cozuluyor ve
kapi aciliyor mu" — yani "BAGLANTI VAR MI". Cihazin isini DOGRU yaptigi
bundan CIKARILAMAZ ve arayuzde de oyle sunulmuyor (docs §4).

===========================================================================
SON BASARILI ILETISIM: GERCEK TETIK DE YAZAR
===========================================================================
`son_basarili_at`i yalniz saglik kontrolu guncelleseydi, dakikalar once
GERCEKTEN calismis bir entegrasyon "uzun suredir iletisim yok" gorunurdu.
Gercek tetik (panik anonsu, kapi acma) en guclu kanittir ve o da bu
alani gunceller.

===========================================================================
BILDIRIM DAMGASI: KOPUSTA BIR KEZ
===========================================================================
`kopus_bildirildi_at` olmadan, 15 dakikada bir kosan gorev kopuk bir
entegrasyon icin GUNDE 96 BILDIRIM gonderirdi. Damga, bir kopus olayi
icin tek bildirim demektir; baglanti geri gelince damga TEMIZLENIR ve
bir sonraki kopus yeniden bildirilir.
"""
from alembic import op

revision = "0141_entegrasyon_sagligi"
down_revision = "0140_panik_alarm"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "CREATE TYPE entegrasyon_saglik AS ENUM ('bilinmiyor', 'bagli', 'hata');"
    )
    op.execute(
        "ALTER TABLE integration ADD COLUMN saglik entegrasyon_saglik "
        "NOT NULL DEFAULT 'bilinmiyor';"
    )
    op.execute("ALTER TABLE integration ADD COLUMN son_kontrol_at timestamptz;")
    op.execute("ALTER TABLE integration ADD COLUMN son_basarili_at timestamptz;")
    # HATA KIMLIGI, CUMLE DEGIL: metin kullanicinin dilinde uretilir
    # (`hata_metinleri`). Cumleyi kaydetmek, kaydi ilk yazan koşumun
    # dilini sonsuza kadar sabitlerdi — ve bu sutun bir ARAYUZ metnidir.
    op.execute("ALTER TABLE integration ADD COLUMN son_hata_kod text;")
    #: Operatore hitap eden HAM ayrinti (sunucu hata ozeti). Kullaniciya
    #: gosterilmez; teshis icin saklanir.
    op.execute("ALTER TABLE integration ADD COLUMN son_hata_ayrinti text;")
    op.execute("ALTER TABLE integration ADD COLUMN kopus_bildirildi_at timestamptz;")
    op.execute(
        "ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS 'entegrasyon_koptu';"
    )


def downgrade() -> None:
    # notification_tip degeri GERI ALINMAZ (goc 0131/0140 emsali).
    op.execute("ALTER TABLE integration DROP COLUMN IF EXISTS kopus_bildirildi_at;")
    op.execute("ALTER TABLE integration DROP COLUMN IF EXISTS son_hata_ayrinti;")
    op.execute("ALTER TABLE integration DROP COLUMN IF EXISTS son_hata_kod;")
    op.execute("ALTER TABLE integration DROP COLUMN IF EXISTS son_basarili_at;")
    op.execute("ALTER TABLE integration DROP COLUMN IF EXISTS son_kontrol_at;")
    op.execute("ALTER TABLE integration DROP COLUMN IF EXISTS saglik;")
    op.execute("DROP TYPE IF EXISTS entegrasyon_saglik;")
