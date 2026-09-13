"""(P227 §1) RAPOR URETIM ZINCIRI — UCTAN UCA, kuyruga atmakla kalmadan.

===========================================================================
OLCULEN KUSUR (PROD)
===========================================================================
Raporlar ekranindan istenen uc PDF de "Hata / SSLError" dondu.

KOK NEDEN: tek ayar IKI FARKLI ISE hizmet ediyordu. `MINIO_ENDPOINT`
hem presigned URL host'u (PUBLIC olmali) hem de SUNUCU-TARAFI yukleme
adresi olarak kullaniliyordu. Prod'da public adrese ayarli oldugu icin
`worker`, uretilen PDF'i yuklerken konteyner icinden KENDI GENEL
ADRESINE cikmaya calisti; pfSense NAT reflection bunu engelliyor ve TLS
el sikismasi koptu.

===========================================================================
TESTLER NEDEN GORMEDI
===========================================================================
`test_rapor_kuyruk.py` YALNIZ KUYRUGA ATMA ucunu olcuyordu: sahiplik,
bicim dogrulama, 404. Gorevin GOVDESI (`isi_uret`) — yani PDF uretimi ve
MinIO'ya yukleme — hicbir testte CALISTIRILMIYORDU. Kirilan adim test
yuzeyinin TAMAMEN DISINDAYDI.

Bu dosya o bosluğu kapatir: gorevi GERCEKTEN kosar, dosyanin depoya
yazildigini ve GERI OKUNABILDIGINI dogrular.
"""
from __future__ import annotations

import io
import uuid

import pytest


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def yon(client, world):
    return _h(client, world["slug_a"], world["yonetici_a"])


def _uret(client, yon, owner_conn, kod: str, bicim: str):
    """Kuyruga at + GOREVI CALISTIR + dosyayi GERI OKU."""
    from app import storage
    from app.config import settings
    from app.rapor_kuyruk import isi_uret
    from app.tasks import _async_calistir

    r = client.post(f"/raporlar/{kod}/kuyruk?bicim={bicim}", headers=yon, json={})
    assert r.status_code == 202, r.text
    is_id = r.json()["id"]

    # (P187) DUZ `asyncio.run` KULLANILMAZ ve bu OLCULDU: ikinci cagride
    #     RuntimeError: ... Future attached to a different loop
    # asyncpg baglantilari olusturuldugu loop'a BAGLIDIR; her `asyncio.run`
    # yeni bir loop acip kapatir ve havuzda olu loop'a bagli baglanti kalir.
    # Deponun kendi yardimcisi bitiste engine'i dispose eder — uretimdeki
    # Celery gorevleri de ayni yoldan geciyor, yani test URETIMLE AYNI
    # kosulda kosuyor.
    sonuc = _async_calistir(lambda: isi_uret(uuid.UUID(is_id)))
    satir = owner_conn.execute(
        "SELECT durum, dosya_key, hata FROM rapor_isi WHERE id = %s", (is_id,)
    ).fetchone()
    assert satir[0] == "hazir", f"is BASARISIZ: {satir[2]}"
    veri = storage._client(ic=True).get_object(
        Bucket=settings.minio_bucket, Key=satir[1]
    )["Body"].read()
    return sonuc, veri


# ==================================================================== #
# 1. ZINCIR — uretim + YUKLEME + GERI OKUMA
# ==================================================================== #

def test_PDF_URETILIR_DEPOYA_YAZILIR_ve_GERI_OKUNUR(client, yon, owner_conn):
    """Kirilan adim tam olarak buydu: uretim degil YUKLEME."""
    _, veri = _uret(client, yon, owner_conn, "borc_alacak", "pdf")
    assert veri[:5] == b"%PDF-", "gecerli PDF degil"
    assert len(veri) > 1000, f"PDF sasirtici kadar kucuk: {len(veri)}"


def test_EXCEL_de_ayni_zincirden_gecer(client, yon, owner_conn):
    _, veri = _uret(client, yon, owner_conn, "borc_alacak", "excel")
    assert veri[:2] == b"PK", "gecerli xlsx (zip) degil"


# ==================================================================== #
# 2. IKI ADRES, IKI IS
# ==================================================================== #

def test_SUNUCU_TARAFI_IC_ADRESI_PRESIGN_PUBLIC_ADRESI_KULLANIR(monkeypatch):
    """Kok nedenin kilidi.

    Ayni ayar ikisine birden hizmet ederse prod'da `SSLError` geri gelir.
    """
    from app import storage
    from app.config import settings

    monkeypatch.setattr(settings, "minio_endpoint", "https://storage.ornek.com")
    monkeypatch.setattr(settings, "minio_internal_endpoint", "http://minio:9000")

    assert storage._client(ic=True).meta.endpoint_url == "http://minio:9000"
    assert storage._client().meta.endpoint_url == "https://storage.ornek.com"


def test_IC_ADRES_BOSSA_ESKI_DAVRANIS_SURER(monkeypatch):
    """Tek-adresli kurulumlar (dev) BOZULMAZ."""
    from app import storage
    from app.config import settings

    monkeypatch.setattr(settings, "minio_endpoint", "http://localhost:9000")
    monkeypatch.setattr(settings, "minio_internal_endpoint", "")
    assert storage._client(ic=True).meta.endpoint_url == "http://localhost:9000"


# ==================================================================== #
# 3. HATA MESAJI TESHIS EDILEBILIR
# ==================================================================== #

def test_SSLError_ANLASILIR_METNE_CEVRILIR():
    """"SSLError" yoneticiye hicbir sey anlatmiyordu: kamerasi mi bozuk,
    sertifikasi mi, interneti mi? Metin NE OLDUGUNU ve KIMIN duzeltecegini
    soylemeli."""
    from ssl import SSLError

    from app.rapor_kuyruk import _hata_metni

    metin = _hata_metni(SSLError("handshake"))
    assert "SUNUCU YAPILANDIRMA" in metin
    # TEKNIK AD KALIR: yonetici destege iletebilmeli.
    assert "SSLError" in metin


def test_BILINMEYEN_HATADA_SINIF_ADI_YINE_VERILIR():
    """"Bilinmeyen hata" demek, destege iletilebilecek TEK ipucunu da
    silmek olurdu."""
    from app.rapor_kuyruk import _hata_metni

    class GaripBirHata(Exception):
        pass

    metin = _hata_metni(GaripBirHata())
    assert "GaripBirHata" in metin


# ==================================================================== #
# 4. PDF KALITESI — TURKCE HARFLER
# ==================================================================== #

def test_PDF_TURKCE_HARFLERI_DOGRU_CIZER(client, yon, owner_conn):
    """OLCULDU: Helvetica `ç/ö/ü` ciziyor ama `ş/ğ/ı/İ` KUTU yapiyordu
    ("Olu■turma", "Kad■köy", "■stanbul"). WinAnsi (cp1252) o harfleri
    ICERMEZ. "Muhasebeciye verilebilecek kalite" iddiasini dogrudan
    curutuyordu."""
    pytest.importorskip("pypdf", reason="pypdf yok — PDF metni okunamaz")
    from pypdf import PdfReader

    _, veri = _uret(client, yon, owner_conn, "borc_alacak", "pdf")
    metin = "".join((s.extract_text() or "") for s in PdfReader(io.BytesIO(veri)).pages)

    assert "Oluşturma" in metin, f"Turkce harf BOZUK: {metin[:120]!r}"
    assert "■" not in metin, "PDF'te KUTU karakteri var"


def test_PDF_KURUMSAL_BASLIK_TASIR(client, yon, owner_conn):
    """Muhasebeciye/denetime verilecek cikti: tesis adi, rapor adi, donem,
    zaman damgasi ve SAYFA NUMARASI."""
    pytest.importorskip("pypdf", reason="pypdf yok")
    from pypdf import PdfReader

    _, veri = _uret(client, yon, owner_conn, "borc_alacak", "pdf")
    metin = "".join((s.extract_text() or "") for s in PdfReader(io.BytesIO(veri)).pages)
    for beklenen in ("Dönem:", "Oluşturma:", "Sayfa"):
        assert beklenen in metin, f"{beklenen!r} ciktida YOK"
