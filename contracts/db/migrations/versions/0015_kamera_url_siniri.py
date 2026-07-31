"""kamera_url_siniri (0015) — yayin adreslerine 2048 karakter UST SINIRI.

MASTER-PLAN P25(a). `camera.stream_url` ve `camera.restream_url` sinirsiz
`text` sutunlariydi: yapistirilan bir DVR yapilandirmasinin tamami (kilobayt
mertebesinde) kabul ediliyor, listeyi ve mobil kart cizimini sisiriyordu.
2048, HTTP yiginlarinin fiili URL siniridir — daha uzunu zaten agin oteki
ucunda kirilirdi.

NEDEN VERITABANINDA DA: uygulama katmani (schemas.dogrula_url_tur) sinirini
zaten olcuyor, ama tek savunma OLMAMALI — bu sutunlara ileride bir toplu ice
aktarma ya da bir bakim betigi de yazabilir. Kisit CHECK'tir (varchar(2048)
DEGIL): tur degisimi tabloyu yeniden yazardi, CHECK ise yalniz dogrular.

MEVCUT VERI: sinirdan uzun satir varsa gocu DUSURMEK yerine KESERIZ ve
kesilenleri NOTICE ile bildiririz — dagitilmis bir prod var (bkz.
docs/MIGRATION-POLITIKASI.md) ve bir kamera kaydi yuzunden gocun durmasi,
uzun URL'nin kendisinden daha kotu bir sonuctur. Kesilen adres zaten
oynamiyordu.

Revision ID: 0015_kamera_url_siniri
Revises: 0014_sikayet_okuma
"""
from __future__ import annotations

from alembic import op

revision = "0015_kamera_url_siniri"
down_revision = "0014_sikayet_okuma"
branch_labels = None
depends_on = None

SINIR = 2048


def upgrade() -> None:
    for sutun in ("stream_url", "restream_url"):
        op.execute(
            f"""
            DO $$
            DECLARE kesilen int;
            BEGIN
                UPDATE camera SET {sutun} = left({sutun}, {SINIR})
                 WHERE {sutun} IS NOT NULL AND length({sutun}) > {SINIR};
                GET DIAGNOSTICS kesilen = ROW_COUNT;
                IF kesilen > 0 THEN
                    RAISE NOTICE '0015: camera.{sutun} % satirda kesildi', kesilen;
                END IF;
            END $$;
            """
        )
    op.execute(
        f"ALTER TABLE camera ADD CONSTRAINT ck_camera_stream_url_uzunluk "
        f"CHECK (length(stream_url) <= {SINIR});"
    )
    op.execute(
        f"ALTER TABLE camera ADD CONSTRAINT ck_camera_restream_url_uzunluk "
        f"CHECK (restream_url IS NULL OR length(restream_url) <= {SINIR});"
    )


def downgrade() -> None:
    # Kesilen adresler GERI GELMEZ (bilgi kaybi tek yonludur); yalniz kisit
    # kalkar.
    op.execute("ALTER TABLE camera DROP CONSTRAINT IF EXISTS ck_camera_restream_url_uzunluk;")
    op.execute("ALTER TABLE camera DROP CONSTRAINT IF EXISTS ck_camera_stream_url_uzunluk;")
