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
import base64
import hashlib
import os
from urllib.parse import quote, unquote, urlsplit, urlunsplit

from alembic import op
import sqlalchemy as sa

revision = "0107_kamera_kimlik_ayrimi"
down_revision = "0106_kamera_ana_ekran"
branch_labels = None
depends_on = None


# =========================================================================== #
# GOMULU KOPYA — ve NEDEN `app.*` ITHAL EDILMIYOR
# =========================================================================== #
# Ilk yazimda bu goc `from app.kamera_kimlik import ...` yapiyordu ve
# `test_goc_bagimsizligi` bunu (hakli olarak) reddetti. Kural soyut
# degil, BU TURDA YASANDI: `contracts/` canli mount, `backend/app/` ise
# imaja gomulu. Imaj yenilenmeden goc kosunca
#   ModuleNotFoundError: No module named 'app.kamera_kimlik'
# ile TUM goc zinciri dustu ve api/worker/admin-web hic baslamadi.
#
# Daha derin gerekce: goc GECMISTIR. Bugun `kimligi_ayir` ne yapiyorsa,
# bu goc onu yapmali — yarin fonksiyon degisirse (ornegin baska bir
# sifreleme semasina gecilirse) BU GOC'un davranisi DEGISMEMELI, yoksa
# ayni goc iki kurulumda iki farkli sonuc uretir.
#
# Bu yuzden gereken mantik BURAYA KOPYALANDI. Kopya oldugu ACIKCA
# yaziliyor ki biri `app/kamera_kimlik.py`yi degistirince "burayi da
# guncelleyeyim mi" diye sormasin: HAYIR, bu kopya DONDURULMUSTUR.
#
# Sifreleme: `app/nfc_sdm.py` deseni (AES-GCM, KEK = SHA-256(SDM_KEK)),
# base64(nonce || ct+tag) — uygulama ile AYNI bicim, yoksa yazilan blob
# okunamazdi.


def _kek_aes():
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM

    kek = os.environ.get("SDM_KEK", "")
    if not kek or len(kek) < 32:
        # ACIK HATA, sessiz atlama DEGIL: anahtarsiz devam etmek
        # parolalari duz metin birakir ve kimse fark etmezdi.
        raise RuntimeError(
            "SDM_KEK yok/kisa — goc 0107 kamera parolasini sifreler. "
            "migrate servisine SDM_KEK gecirin (infra/docker-compose*.yml)."
        )
    return AESGCM(hashlib.sha256(kek.encode("utf-8")).digest())


def _sifrele(duz):
    if not duz:
        return None
    nonce = os.urandom(12)
    return base64.b64encode(
        nonce + _kek_aes().encrypt(nonce, duz.encode("utf-8"), None)
    ).decode("ascii")


def _coz(blob):
    if not blob:
        return None
    try:
        ham = base64.b64decode(blob)
        return _kek_aes().decrypt(ham[:12], ham[12:], None).decode("utf-8")
    except Exception:
        # Geri almada cozulemeyen satirin adresi KIMLIKSIZ kalir (kamera
        # calismaz ama KAYIT SILINMEZ). Yanlis bir parola yazmaktansa
        # gorunur bir kimlik hatasi.
        return None


def _ayir(url):
    """`url` -> (kimliksiz_url, kullanici, parola); kimlik yoksa (url, None, None)."""
    try:
        p = urlsplit(url)
    except ValueError:
        return url, None, None
    if not p.hostname or (p.username is None and p.password is None):
        return url, None, None
    konak = p.hostname
    if ":" in konak:                      # IPv6
        konak = f"[{konak}]"
    if p.port:
        konak = f"{konak}:{p.port}"
    return (
        urlunsplit((p.scheme, konak, p.path, p.query, p.fragment)),
        unquote(p.username) if p.username else None,
        unquote(p.password) if p.password else None,
    )


def _uygula(url, kullanici, parola):
    """Kimliksiz `url`e kimligi geri takar (geri alma yolu)."""
    if not kullanici and not parola:
        return url
    try:
        p = urlsplit(url)
    except ValueError:
        return url
    if p.username is not None or p.password is not None or not p.hostname:
        return url
    konak = p.hostname
    if ":" in konak:
        konak = f"[{konak}]"
    if p.port:
        konak = f"{konak}:{p.port}"
    kimlik = quote(kullanici or "", safe="")
    if parola:
        kimlik = f"{kimlik}:{quote(parola, safe='')}"
    return urlunsplit((p.scheme, f"{kimlik}@{konak}", p.path, p.query, p.fragment))


def _tasi(yon: str) -> None:
    """Satir satir tasi. Ham SQL YETMEZ: sifreleme hesaplanmali."""
    baglanti = op.get_bind()
    satirlar = baglanti.execute(
        sa.text(
            "SELECT id, stream_url, stream_kullanici, stream_parola_sifreli "
            "FROM camera"
        )
    ).fetchall()
    for kid, url, kul, blob in satirlar:
        if yon == "ileri":
            temiz, k, p = _ayir(url or "")
            if k is None and p is None:
                continue
            baglanti.execute(
                sa.text(
                    "UPDATE camera SET stream_url=:u, stream_kullanici=:k, "
                    "stream_parola_sifreli=:p WHERE id=:i"
                ),
                {"u": temiz, "k": k, "p": _sifrele(p), "i": kid},
            )
        else:
            if not kul and not blob:
                continue
            baglanti.execute(
                sa.text("UPDATE camera SET stream_url=:u WHERE id=:i"),
                {"u": _uygula(url or "", kul, _coz(blob)), "i": kid},
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
