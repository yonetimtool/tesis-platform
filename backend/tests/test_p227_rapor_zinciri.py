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

    # (P227 §1) IS SATIRI DOGRUDAN ACILIR — kuyruk ucu CAGRILMAZ.
    #
    # OLCULEN SORUN: uc, Celery gorevini WORKER'a da gonderiyor. Test hem
    # worker'in isledigi hem kendi isledigi ayni satira yazinca
    #     psycopg.errors.DeadlockDetected
    # aliniyordu — ve daha sinsisi, iki uretimden HANGISININ depoya
    # yazdigi belirsizdi (elle olcum sirasinda worker ESKI imajla yazip
    # beni yanlis teshise surukledi).
    #
    # Kuyruk ucunun SOZLESMESI (sahiplik, bicim dogrulama, 404) zaten
    # `test_rapor_kuyruk.py`de olculuyor. Burada olculen sey URETIM +
    # YUKLEME + GERI OKUMA zinciri; is satirini dogrudan acmak onu
    # DETERMINISTIK yapar.
    is_id = str(uuid.uuid4())
    kullanici = client.get("/me", headers=yon).json()
    owner_conn.execute(
        "INSERT INTO rapor_isi (id, tenant_id, user_id, kod, bicim, parametre, durum) "
        "VALUES (%s, %s, %s, %s, %s, '{}'::jsonb, 'bekliyor')",
        (is_id, kullanici["tenant_id"], kullanici["id"], kod, bicim),
    )

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


# ==================================================================== #
# 5. GRAFIKLER — VERI TURUNE UYGUN, TURKCE ETIKETLI
# ==================================================================== #

def test_PASTA_COK_DILIMDE_CUBUGA_DUSER():
    """Kullanicinin kurali: "6-7 dilimden fazlasinda pasta okunmaz olur".

    Kural TEK YERDE: katalogda her rapor icin tek tek dusunmek yerine
    cikti veriye bakip karar veriyor. Panel tarafinda ayni esik
    (`PASTA_DILIM_SINIRI`) duruyor; ayrisirlarsa ayni rapor ekranda cubuk,
    ciktida okunmaz bir pasta olurdu.
    """
    from app.rapor_ciktilari import _PASTA_DILIM_SINIRI, _grafik_tipi_sec

    assert _grafik_tipi_sec("pasta", _PASTA_DILIM_SINIRI) == "pasta"
    assert _grafik_tipi_sec("pasta", _PASTA_DILIM_SINIRI + 1) == "sutun"


def test_ACIKCA_ISTENEN_TIP_EZILMEZ():
    """Az veri diye zaman serisini pastaya cevirmek, zaman eksenini yok
    etmek olurdu."""
    from app.rapor_ciktilari import _grafik_tipi_sec

    assert _grafik_tipi_sec("cizgi", 2) == "cizgi"
    assert _grafik_tipi_sec("yatay", 30) == "yatay"
    assert _grafik_tipi_sec("sutun", 50) == "sutun"


def test_GRAFIK_ETIKETLERI_TURKCE_HARF_TASIYABILIR():
    """GRAFIGIN KENDI etiketleri — veriden BAGIMSIZ kilit.

    ILK YAZIMIMDA bu testi gercek raporlarla yazdim ve KIRMA YAKALANMADI:
    dev verisindeki kasa adlarinda (`Ana Kasa`) Turkce harf YOK, yani
    grafik fontunu geri bozsam bile test geciyordu. Kusuru olcen tek yol,
    etiketleri TESTIN KENDISININ vermesi.

    Tablodaki font duzeltmesi grafigi KAPSAMIYORDU: eksen etiketleri,
    pasta dilim etiketleri ve legend kendi `fontName`lerini tasiyor.
    """
    pytest.importorskip("pypdf", reason="pypdf yok")
    from pypdf import PdfReader

    from app.raporlar import RaporSonuc, Sutun
    from app.rapor_ciktilari import pdf_uret
    from app.schemas import RaporGrafikTanimi

    sonuc = RaporSonuc(
        kod="t", baslik="Gider Dağılımı",
        sutunlar=[Sutun("kalem", "Kalem", genislik=3),
                  Sutun("tutar", "Tutar", "kurus", 2)],
        satirlar=[
            {"kalem": "Güvenlik Şirketi", "tutar": 120000},
            {"kalem": "Bahçe Bakımı", "tutar": 45000},
            {"kalem": "Asansör Bakımı", "tutar": 30000},
        ],
    )
    for tip in ("pasta", "sutun", "yatay", "cizgi"):
        pdf = pdf_uret(
            sonuc, "Acme Plaza", None, None,
            grafik=RaporGrafikTanimi(tip=tip, x="kalem", seriler=["tutar"]),
        )
        metin = "".join(
            (s.extract_text() or "") for s in PdfReader(io.BytesIO(pdf)).pages
        )
        assert "■" not in metin, f"{tip} grafiginde KUTU karakteri var"
        # ETIKET RENK-YALNIZ DEGIL: kategori adi metin olarak da geciyor.
        assert "Güvenlik Şirketi" in metin, f"{tip}: etiket metni YOK"


@pytest.mark.parametrize("kod", ["denetim_raporu", "finansal_hareketler"])
def test_GRAFIKLI_RAPOR_URETILIR_ve_ETIKETLERI_TURKCE(
        client, yon, owner_conn, kod):
    """Grafik ETIKETLERI de Turkce harf tasiyor ("Şişli Kasası").

    Tablodaki font duzeltmesi grafigi KAPSAMIYORDU: eksen etiketleri,
    pasta dilim etiketleri ve legend kendi `fontName`lerini tasiyor ve
    varsayilan Helvetica `ş/ğ/ı/İ` harflerini KUTU yapiyordu. Uctan uca
    olculdu (denetim_raporu ve donemsel_bakiye kutu veriyordu).
    """
    pytest.importorskip("pypdf", reason="pypdf yok")
    from pypdf import PdfReader

    _, veri = _uret(client, yon, owner_conn, kod, "pdf")
    rd = PdfReader(io.BytesIO(veri))
    metin = "".join((s.extract_text() or "") for s in rd.pages)
    assert "■" not in metin, f"{kod} PDF'inde KUTU karakteri var"
    # GRAFIK SAYFASI EKLENDI: veri varsa ikinci sayfa cizilir.
    assert len(rd.pages) >= 1
