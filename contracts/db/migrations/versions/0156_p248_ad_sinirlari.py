"""(P248 gozden gecirme) GERCEK ADLAR SIGSIN — uc CHECK kisiti genisledi.

Kullanici: "sinir guvenlik icin gerekli ama kullaniciyi engelleyecek kadar
dar olmamali." Alan basina gercek bir ornek dusunuldu, sinir ondan genis:

  * `unit_grup.ad`, `unit_tip.ad`: 60 -> 100
    ("Dubleks Çatı Katı (Bahçe Katlı, Teraslı)" gibi tanim adlari).
  * `firma.ad`: 150 -> 200 — ticari unvan ("… Danışmanlık Temizlik
    Güvenlik Hizmetleri Sanayi ve Ticaret Anonim Şirketi" ~100).

Yalniz GEVSETME: mevcut hicbir satir yeni kisiti ihlal edemez. Sema
sinirlari (`backend/app/schemas.py`) ayni sayilarda; `test_p248_girdi_siniri`
DB CHECK ile semanin tutarliligini kilitler.

Goc `app.*` ithal ETMEZ (dondurulmus kopya kurali).
"""
from alembic import op

revision = "0156_p248_ad_sinirlari"
down_revision = "0155_p247_ek_saha"
branch_labels = None
depends_on = None


def _yenile(tablo: str, ad: str, tanim: str) -> None:
    op.execute(f"ALTER TABLE {tablo} DROP CONSTRAINT IF EXISTS {ad};")
    op.execute(f"ALTER TABLE {tablo} ADD CONSTRAINT {ad} CHECK ({tanim});")


def upgrade() -> None:
    _yenile("unit_grup", "ck_unit_grup_ad_uzunluk", "length(ad) <= 100")
    _yenile("unit_tip", "ck_unit_tip_ad_uzunluk", "length(ad) <= 100")
    _yenile("firma", "ck_firma_ad", "btrim(ad) <> '' AND length(ad) <= 200")


def downgrade() -> None:
    _yenile("unit_grup", "ck_unit_grup_ad_uzunluk", "length(ad) <= 60")
    _yenile("unit_tip", "ck_unit_tip_ad_uzunluk", "length(ad) <= 60")
    _yenile("firma", "ck_firma_ad", "btrim(ad) <> '' AND length(ad) <= 150")
