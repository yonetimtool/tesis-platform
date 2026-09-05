"""(P213 §6b) KAMERA ADRESINDEKI PAROLAYI ADRESTEN AYIR ve SIFRELE.

===========================================================================
DUZELTILEN KUSUR
===========================================================================
`camera.stream_url` `rtsp://kullanici:parola@10.0.0.5:554/s` biciminde
DUZ METIN saklaniyordu:

  * DB dokumu (yedek, destek kopyasi, hata ayiklama) parolayi aciyordu,
  * `GET /cameras` adresi OLDUGU GIBI donduruyordu — parola yetkili her
    istemciye gidiyordu,
  * adres gunluge yazildiginda parola da yaziliyordu.

Gecmis kayit ozelligi NVR'in YONETIM hesabini gerektirdigi icin bu sorun
buyuyecekti; once bu kapatildi.

===========================================================================
GOC NE YAPAR
===========================================================================
1. `stream_kullanici` + `stream_parola_sifreli` sutunlarini ekler.
2. MEVCUT KAYITLARI TASIR: her satirdaki adresten kimligi ayirir,
   parolayi AES-GCM ile sifreler (app/crypto.py — entegrasyon sirlariyla
   ayni KEK), `stream_url`i KIMLIKSIZ hâline yazar.

Ayni islem `restream_url` ve `snapshot_url` icin YAPILMAZ: ikisi de
GECIDIN adresidir (Frigate/go2rtc/MediaMTX), kameranin degil; kimlik
tasiyorlarsa bile o kimlik bizim kendi gecidimizindir ve ayri bir
karardir. Kapsami dar tutmak, geri alinabilirligi de dar tutuyor.

===========================================================================
GERI ALINABILIR
===========================================================================
`downgrade` parolayi COZUP adrese GERI TAKAR, sonra sutunlari dusurur.
Yani goc cift yonlu ve veri kaybi yok. KEK erisilemezse cozulemeyen satir
adresini kimliksiz birakir (kamera calismaz ama KAYIT SILINMEZ) —
sessizce yanlis bir parola yazmaktansa gorunur bir kimlik hatasi.
"""
from alembic import op
import sqlalchemy as sa

revision = "0107_kamera_kimlik_ayrimi"
down_revision = "0106_kamera_ana_ekran"
branch_labels = None
depends_on = None


def _tasi(yon: str) -> None:
    """Satir satir tasi. Ham SQL YETMEZ: sifreleme uygulama kodunda."""
    from app.kamera_kimlik import (
        kimligi_ayir,
        kimligi_uygula,
        parola_coz,
        parola_sakla,
    )

    baglanti = op.get_bind()
    satirlar = baglanti.execute(
        sa.text(
            "SELECT id, stream_url, stream_kullanici, stream_parola_sifreli "
            "FROM camera"
        )
    ).fetchall()
    for kid, url, kul, blob in satirlar:
        if yon == "ileri":
            temiz, k, p = kimligi_ayir(url or "")
            if k is None and p is None:
                continue
            baglanti.execute(
                sa.text(
                    "UPDATE camera SET stream_url=:u, stream_kullanici=:k, "
                    "stream_parola_sifreli=:p WHERE id=:i"
                ),
                {"u": temiz, "k": k, "p": parola_sakla(p), "i": kid},
            )
        else:
            if not kul and not blob:
                continue
            baglanti.execute(
                sa.text("UPDATE camera SET stream_url=:u WHERE id=:i"),
                {"u": kimligi_uygula(url or "", kul, parola_coz(blob)), "i": kid},
            )


def upgrade() -> None:
    op.add_column("camera", sa.Column("stream_kullanici", sa.Text(), nullable=True))
    op.add_column(
        "camera", sa.Column("stream_parola_sifreli", sa.Text(), nullable=True)
    )
    _tasi("ileri")


def downgrade() -> None:
    _tasi("geri")
    op.execute("ALTER TABLE camera DROP COLUMN IF EXISTS stream_parola_sifreli;")
    op.execute("ALTER TABLE camera DROP COLUMN IF EXISTS stream_kullanici;")
