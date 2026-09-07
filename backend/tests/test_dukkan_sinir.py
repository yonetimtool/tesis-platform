"""(DUKKAN F1) SINIR: Dukkan, Yonetiyor'un veritabanina DOKUNAMAZ.

===========================================================================
BU DOSYA NEDEN VAR
===========================================================================
Kisit soyle konuldu: "Yonetiyor'un veritabanina DOGRUDAN YAZMA. Okuma da
API uzerinden." Tasarimda bu kisit ayri bir SEMA ile degil ayri bir ROL
ile karsilandi — cunku ayri sema tek basina hicbir seyi ZORLAMAZ,
yalnizca isimleri ayirir.

Ve bir kisit, ancak kirildiginda kirmizi yanan bir sey varsa kisittir.
Aksi halde iyi niyetli bir yorum satiridir. Bu dosya o kirmizi isik.

===========================================================================
NE OLCULUYOR
===========================================================================
1. `dukkan_app` rolu `public` semasindaki tablolari OKUYAMAZ.
2. YAZAMAZ.
3. `public` semasinda HICBIR tablo yetkisi kayitli degil (katalogdan).
4. Kendi semasinda (`dukkan`) tam DML YAPABILIR — sinir Dukkan'i
   felc etmemeli; yalnizca komsuya gecisi kesmeli.
5. Simetrik: `app_rw` de Dukkan semasina giremez.

===========================================================================
SINIR TAM OLARAK NEREDE (durust anlatim)
===========================================================================
`public` semasi uzerindeki USAGE, PostgreSQL'de `PUBLIC` sozde-rolune
verilidir ve her rol PUBLIC uyesidir; tek bir rolden geri alinamaz. Yani
dukkan_app semayi GOREBILIR ve testin bekledigi hata "schema" degil
TABLO hatasidir:

    permission denied for table app_user

Bu ayrimi acikca yaziyorum cunku testi bir gun okuyan kisi "sema
gorunuyorsa sinir yok mu?" diye dusunebilir. Hayir: tablolarin PUBLIC'e
GRANT'i yoktur ve dukkan_app hicbir tablo GRANT'i almaz.
"""
from __future__ import annotations

import psycopg
import pytest

# Yonetiyor'un en hassas tablolari. Hepsi ayni sebeple secildi: Dukkan
# bunlardan birine erisebilseydi kisit fiilen yok olurdu.
YONETIYOR_TABLOLARI = [
    "app_user",        # kimlik + telefon + e-posta
    "tenant",          # tesis
    "unit",            # daire — KVKK acisindan en hassasi
    "unit_resident",   # kim nerede oturuyor
    "audit_log",       # denetim izi
    "finansal_hareket",  # defter
    "dis_hizmet",      # yoneticinin ozel esnaf defteri
]


@pytest.mark.parametrize("tablo", YONETIYOR_TABLOLARI)
def test_dukkan_YONETIYOR_TABLOSUNU_OKUYAMAZ(dukkan_conn, tablo):
    with pytest.raises(psycopg.errors.InsufficientPrivilege) as hata:
        dukkan_conn.execute(f"SELECT 1 FROM public.{tablo} LIMIT 1")
    # Hatanin TABLO hatasi oldugunu dogruluyoruz: "schema" hatasi baska
    # bir sey anlatirdi (sema hic yok gibi) ve sinirin nerede durdugunu
    # yanlis belgelerdi.
    assert "permission denied" in str(hata.value)
    assert tablo in str(hata.value)


@pytest.mark.parametrize("tablo", ["app_user", "tenant", "unit"])
def test_dukkan_YONETIYOR_TABLOSUNA_YAZAMAZ(dukkan_conn, tablo):
    """Kisitin ASIL cumlesi buydu: 'DOGRUDAN YAZMA'."""
    with pytest.raises(psycopg.errors.InsufficientPrivilege):
        dukkan_conn.execute(f"UPDATE public.{tablo} SET id = id")


def test_dukkan_rolunun_public_semasinda_HICBIR_YETKISI_YOK(owner_conn):
    """Katalog uzerinden BUTUNCUL kontrol.

    Yukaridaki testler tablo tablo bakiyor ve yeni bir Yonetiyor tablosu
    eklendiginde onu KAPSAMAZ. Bu test kataloga sorup "sifir" bekliyor;
    boylece gelecekte eklenecek tablolar da otomatik kapsam altinda.
    """
    satir = owner_conn.execute(
        """
        SELECT count(*) FROM information_schema.table_privileges
        WHERE grantee = 'dukkan_app' AND table_schema = 'public'
        """
    ).fetchone()
    assert satir[0] == 0, (
        f"dukkan_app'e public semasinda {satir[0]} tablo yetkisi verilmis. "
        "Kisit DELINMIS: Dukkan artik Yonetiyor verisine erisebiliyor."
    )


def test_dukkan_KENDI_SEMASINDA_calisabiliyor(dukkan_conn):
    """Sinir Dukkan'i FELC ETMEMELI.

    Bu testin varlik sebebi: yukaridaki dort test, dukkan_app'in parolasi
    yanlis olsa ya da rol hic yetkisiz olsa da GECERDI. Bu test onlarin
    bos yere yesil yanmadigini kanitliyor.
    """
    dukkan_conn.execute(
        "INSERT INTO dukkan.ulke (kod, ad) VALUES ('XX', 'Sinir testi') "
        "ON CONFLICT (kod) DO NOTHING"
    )
    try:
        satir = dukkan_conn.execute(
            "SELECT ad FROM dukkan.ulke WHERE kod = 'XX'"
        ).fetchone()
        assert satir is not None, "dukkan_app kendi semasina yazamiyor"
    finally:
        dukkan_conn.execute("DELETE FROM dukkan.ulke WHERE kod = 'XX'")


def test_app_rw_DUKKAN_SEMASINA_giremez(app_conn):
    """Simetrik koruma.

    Kisit tek yonlu istenmisti (Dukkan -> Yonetiyor). Iki yonlu kurmak
    bedavaydi ve "hangi kod hangi veriye bakiyor" sorusunu kesin
    yanitliyor: Yonetiyor tarafi Dukkan verisini gormek isterse
    Dukkan'in KENDI ucundan alir, tabloya uzanmaz.
    """
    with pytest.raises(psycopg.Error) as hata:
        app_conn.execute("SELECT 1 FROM dukkan.ulke LIMIT 1")
    assert "permission denied" in str(hata.value)


# ===================================================================== #
# (F2) DENETIM APPEND-ONLY
# ===================================================================== #

def test_DENETIM_yazilabilir_ama_DEGISTIRILEMEZ(dukkan_conn):
    """Bir moderasyon karari sonradan "hic verilmemis" hale getirilemez.

    Itiraz sureci buna dayaniyor: karar verildiginde `denetim`e kim, ne
    zaman, hangi gerekceyle yazildigi kalir. UPDATE/DELETE acik olsaydi
    bir moderator kendi kararini silebilir ve itiraz eden kisi
    degerlendirilecek bir sey bulamazdi. Yonetiyor'un `audit_log`u da
    ayni sekilde korunuyor (goc 0002) — ayni ilke, ayri sema.

    ==================================================================
    BU TEST NEDEN GOCE EK OLARAK GEREKLI
    ==================================================================
    `setup_dukkan_role.py` her `migrate` kosumunda TUM tablolara blanket
    GRANT veriyor ve gocteki REVOKE'u SESSIZCE geri alirdi. Bu yuzden
    revoke betikte de tekrarlaniyor; bu test ikisinin birlikte
    calistigini DISARIDAN olcuyor. `setup_app_role.py`de birebir ayni
    ders `audit_log` icin yazili.
    """
    import uuid as _uuid

    import psycopg

    iz = "test_append_only_" + _uuid.uuid4().hex[:8]
    dukkan_conn.execute("INSERT INTO dukkan.denetim (eylem) VALUES (%s)", (iz,))
    var = dukkan_conn.execute(
        "SELECT count(*) FROM dukkan.denetim WHERE eylem = %s", (iz,)
    ).fetchone()[0]
    assert var == 1, "denetim satiri yazilamadi"

    with pytest.raises(psycopg.errors.InsufficientPrivilege):
        dukkan_conn.execute(
            "UPDATE dukkan.denetim SET eylem = 'x' WHERE eylem = %s", (iz,)
        )
    with pytest.raises(psycopg.errors.InsufficientPrivilege):
        dukkan_conn.execute("DELETE FROM dukkan.denetim WHERE eylem = %s", (iz,))


def test_DENETIM_katalogda_UPDATE_DELETE_yetkisi_YOK(owner_conn):
    """Katalog uzerinden butuncul kontrol."""
    n = owner_conn.execute(
        """
        SELECT count(*) FROM information_schema.table_privileges
        WHERE grantee = 'dukkan_app' AND table_schema = 'dukkan'
          AND table_name = 'denetim'
          AND privilege_type IN ('UPDATE', 'DELETE')
        """
    ).fetchone()[0]
    assert n == 0, (
        f"denetim tablosunda {n} yazma yetkisi var — append-only DELINMIS. "
        "En olasi sebep: setup_dukkan_role.py'deki REVOKE atlanmis."
    )
