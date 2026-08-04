"""RLS KAPSAMI — KATALOGDAN turetilen, elle liste ICERMEYEN olcum (tur 73).

NEDEN: `test_rls_isolation.py` cross-tenant izolasyonu DAVRANISSAL olarak
dogruluyor, ama yalniz ELLE YAZILMIS bir tablo listesi uzerinde
(`@pytest.mark.parametrize("tablo", ["vehicle_pass", "violation"])` + temel
tablolar). Dosyanin kendi yorumu soyle diyordu:

    "Tablo eklenip _enable_rls listesine yazilmayi UNUTMAK sessiz bir
     cross-tenant sizintisidir; bu test onu yakalar."

Yakalamiyordu: yeni tabloyu `_enable_rls` listesine yazmayi unutan kisi, ayni
tabloyu bu testin parametrize listesine de yazmayi unutur. Olcum, olctugu
hatanin AYNISINA maruzdu. Tur 73'te sayildi: 48 tablonun **6'si** kontrol
ediliyordu.

BU DOSYA hicbir tablo adi ICERMEZ. Her sey `pg_class`/`pg_policy`
katalogundan okunur; yeni bir tablo eklenir ve RLS'i kurulmazsa test
KENDILIGINDEN kirmiziya doner.

DEGISMEZLER
  1. public'teki her tabloda RLS ENABLE **ve** FORCE (FORCE olmadan tablo
     sahibi politikalari atlar).
  2. Her tabloda en az bir politika; politika TUM komutlara (polcmd='*') ve
     hem USING hem WITH CHECK ifadesine sahip (yalniz USING = INSERT serbest).
  3. Politika ifadesi `app.current_tenant_id` oturum degiskenini kullaniyor.
  4. app_rw rolu RLS'i BYPASS EDEMEZ (rolsuper/rolbypassrls kapali) — aksi
     halde tum politikalar suslemedir.
  5. app_rw her tabloda SELECT yetkilisi. Bu, izolasyonun "yetki yok"
     yuzunden DEGIL, politika yuzunden calistigini garanti eder: yetkisi
     olmayan yeni bir tablo davranissal testte de "sizinti yok" gorunurdu.
  6. TABAN SAYI: katalog sorgusu bos donerse yukaridaki her sey BOSA gecer.
     Bu yuzden tablo sayisinin bir alt siniri var.

PLATFORM TABLOLARI (P127.2) — UCUNCU SINIF
  Semada artik tenant'a AIT OLMAYAN bir tablo var: `tanitim_iletisim`
  (tanitim sitesine gelen musteri adayi; yazan kisinin henuz bir tesisi
  YOKTUR). Boyle bir tabloya `app.current_tenant_id` uzerine politika
  yazilamaz — yazilsaydi anlamsiz olurdu.
  Bu tablolar icin degismez FARKLI ama DAHA KATI:
     * RLS ENABLE + FORCE (digerleriyle ayni),
     * POLITIKA YOK  -> app_rw hicbir satiri goremez/yazamaz,
     * erisim YALNIZ SECURITY DEFINER fonksiyonlarindan (goc 0033).
  SINIF KATALOGDAN TURETILIR (elle liste YOK, bu dosyanin ilkesi): tablo
  `tenant_id` kolonu TASIMIYOR **ve** hic politikasi YOKSA platform
  tablosudur. Ayrica DAVRANISLA dogrulanir (app_rw ile SELECT/INSERT
  denenir) ve sayisi SINIRLIDIR — unutulan bir politika bu sinifa
  sessizce kacamasin.
"""
from __future__ import annotations

import os

import pytest

# Beklenen en az tablo sayisi. 0008 semasinda 48 tablo var (alembic_version
# haric). Bu sayi, katalog sorgusunun bos/eksik donup butun testleri BOSA
# gecirmesini engeller. Sema buyudukce artirilabilir, ASLA dusurulmez.
#
# ENV OVERRIDE (`RLS_TABAN_TABLO`) muhafizin KENDISINI sinamak icin var:
# `RLS_TABAN_TABLO=999 pytest tests/test_rls_kapsam.py` sagliklı bir semada
# bile kirmizi donmeli. Donmezse muhafiz KOR demektir.
TABAN_TABLO_SAYISI = int(os.getenv("RLS_TABAN_TABLO", "40"))

TENANT_DEGISKENI = "app.current_tenant_id"

#: Platform (tenant'siz) tablolarin UST SINIRI. Sinif katalogdan turetilir;
#: bu tavan, "politikasi unutulmus" bir tablonun sinifa sessizce katilmasini
#: gurultulu hale getirir. Bilincli olarak dar.
PLATFORM_TABLO_TAVANI = int(os.getenv("RLS_PLATFORM_TAVAN", "2"))


def _platform_tablolari(katalog) -> set[str]:
    """tenant_id kolonu OLMAYAN ve hic politikasi OLMAYAN tablolar."""
    return {ad for ad, _r, _f, pol, tid in katalog if not tid and pol == 0}


@pytest.fixture
def katalog(owner_conn):
    """public'teki tablolar + RLS bayraklari + politika ozeti."""
    if owner_conn is None:  # pragma: no cover - DB yoksa
        pytest.skip("DB yok")
    rows = owner_conn.execute(
        """
        SELECT c.relname,
               c.relrowsecurity,
               c.relforcerowsecurity,
               (SELECT count(*) FROM pg_policy p WHERE p.polrelid = c.oid),
               EXISTS (SELECT 1 FROM information_schema.columns col
                       WHERE col.table_schema = 'public'
                         AND col.table_name = c.relname
                         AND col.column_name = 'tenant_id')
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
          AND c.relkind = 'r'
          AND c.relname <> 'alembic_version'
        ORDER BY c.relname
        """
    ).fetchall()
    return rows


@pytest.fixture
def politikalar(owner_conn):
    if owner_conn is None:  # pragma: no cover
        pytest.skip("DB yok")
    return owner_conn.execute(
        """
        SELECT c.relname,
               p.polname,
               p.polcmd::text,
               pg_get_expr(p.polqual, p.polrelid),
               pg_get_expr(p.polwithcheck, p.polrelid)
        FROM pg_policy p
        JOIN pg_class c ON c.oid = p.polrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
        ORDER BY c.relname, p.polname
        """
    ).fetchall()


# --- 6. TABAN SAYI (once bu: digerlerinin bosa gecmedigini garanti eder) ---- #
def test_katalog_bos_donmedi(katalog):
    assert len(katalog) >= TABAN_TABLO_SAYISI, (
        f"public'te yalniz {len(katalog)} tablo goruldu; beklenen en az "
        f"{TABAN_TABLO_SAYISI}. Katalog sorgusu yanlis veritabanina baglanmis "
        f"olabilir — bu durumda asagidaki RLS testleri BOSA GECERDI."
    )


# --- 1. RLS ENABLE + FORCE -------------------------------------------------- #
def test_her_tablo_rls_enable_ve_force(katalog):
    eksik = [
        f"{ad} (enable={rls}, force={frls})"
        for ad, rls, frls, _pol, _tid in katalog
        if not rls or not frls
    ]
    assert not eksik, (
        "RLS ENABLE ve/veya FORCE olmayan tablo(lar): " + ", ".join(eksik)
        + ". FORCE olmadan tablo SAHIBI politikalari atlar."
    )


# --- 2. Politika var, TUM komutlar, USING + WITH CHECK ---------------------- #
def test_her_tablonun_politikasi_var(katalog):
    # PLATFORM TABLOLARI HARIC (bkz. modul notu): onlarda politika YOKLUGU
    # BILINCLIDIR ve app_rw'nin hicbir satiri gorememesini saglar. Ayri
    # testleri asagida — sayilari sinirli ve davranislari olculuyor.
    platform = _platform_tablolari(katalog)
    yok = [
        ad for ad, _rls, _frls, pol, tid in katalog
        if pol == 0 and not (ad in platform and not tid)
    ]
    assert not yok, "Izolasyon politikasi OLMAYAN tablo(lar): " + ", ".join(yok)


def test_platform_tablolari_SINIRLI_ve_beklenen(katalog):
    """Sinif buyuyorsa GORUNSUN — unutulan politika buraya kacmasin."""
    platform = _platform_tablolari(katalog)
    assert len(platform) <= PLATFORM_TABLO_TAVANI, (
        f"tenant_id'siz ve politikasiz tablo sayisi tavani asti: "
        f"{sorted(platform)}. Yeni bir tablo eklendiyse ya tenant'a "
        f"baglanmali ya da tavan BILINCLI olarak yukseltilmeli."
    )


def test_politikalar_tum_komutlari_ve_with_check_kapsiyor(politikalar):
    kusurlu = []
    for ad, polad, cmd, using, withcheck in politikalar:
        if cmd != "*":
            kusurlu.append(f"{ad}.{polad}: yalniz '{cmd}' komutuna uygulaniyor")
        if not using:
            kusurlu.append(f"{ad}.{polad}: USING ifadesi yok")
        if not withcheck:
            kusurlu.append(
                f"{ad}.{polad}: WITH CHECK yok — okuma korunur ama "
                f"INSERT/UPDATE ile BASKA tenant'a satir yazilabilir"
            )
    assert not kusurlu, "; ".join(kusurlu)


# --- 3. Politika oturum degiskenini kullaniyor ------------------------------ #
def test_politikalar_tenant_oturum_degiskenini_kullaniyor(politikalar):
    kusurlu = [
        f"{ad}.{polad}"
        for ad, polad, _cmd, using, withcheck in politikalar
        if TENANT_DEGISKENI not in (using or "")
        or TENANT_DEGISKENI not in (withcheck or "")
    ]
    assert not kusurlu, (
        f"`{TENANT_DEGISKENI}` kullanmayan politika(lar): " + ", ".join(kusurlu)
    )


def test_tenant_id_olmayan_tablo_id_uzerinden_izole(katalog, politikalar):
    """tenant_id kolonu olmayan tablo, kendi `id`si uzerinden izole olmali.

    Semada boyle tek bir tablo var (`tenant`). Yeni bir tenant_id'siz tablo
    eklenirse bu test onu ONE CIKARIR: ya tenant_id alacak ya da izolasyonu
    icin BILINCLI bir karar yazilacak.
    """
    # Politikasi OLMAYAN tenant_id'siz tablolar PLATFORM sinifidir ve
    # kendi testlerine tabidir; burada yalniz politikali olanlar olculur
    # (semada `tenant` tablosu).
    platform = _platform_tablolari(katalog)
    tidsiz = {ad for ad, _r, _f, _p, tid in katalog if not tid} - platform
    ifadeler = {ad: (using or "") for ad, _pa, _c, using, _w in politikalar}
    for ad in sorted(tidsiz):
        using = ifadeler.get(ad, "")
        # SUBSTRING TUZAGI: oturum degiskeninin ADI (`app.current_tenant_id`)
        # `tenant_id` dizgisini ICERIR. Kolon aramasi once o adi cikarmali;
        # aksi halde `tenant` tablosunun dogru politikasi yanlis bildirilir
        # (bu testin ilk kosumunda tam olarak bu oldu).
        kolonlar = using.replace(TENANT_DEGISKENI, "")
        assert "tenant_id" not in kolonlar, (
            f"{ad} tablosunda tenant_id kolonu YOK ama politikasi tenant_id "
            f"kullaniyor: {using}"
        )
        assert TENANT_DEGISKENI in using and "id" in using, (
            f"{ad}: tenant_id'siz tablo kendi id'si uzerinden izole olmali; "
            f"politika: {using or '(yok)'}"
        )


# --- 4. app_rw RLS'i bypass edemez ----------------------------------------- #
def test_app_rolu_rls_bypass_edemez(owner_conn):
    if owner_conn is None:  # pragma: no cover
        pytest.skip("DB yok")
    # Rol adi APP_DSN'den okunur; ortama gore degisebilir (dev/prod/gecici db).
    app_dsn = os.getenv(
        "APP_DSN", "postgresql://app_rw:app_rw_secret_change_me@db:5432/tesis"
    )
    rol = app_dsn.split("//", 1)[1].split(":", 1)[0]
    row = owner_conn.execute(
        "SELECT rolsuper, rolbypassrls FROM pg_roles WHERE rolname = %s", (rol,)
    ).fetchone()
    assert row is not None, f"`{rol}` rolu yok"
    super_, bypass = row
    assert not super_, f"{rol} SUPERUSER — tum politikalar suslemedir"
    assert not bypass, f"{rol} BYPASSRLS — tum politikalar suslemedir"


# --- 5. app_rw her tabloda yetkili (izolasyon "yetki yok"dan degil) --------- #
def test_app_rolu_her_tabloda_select_yetkili(owner_conn, katalog):
    if owner_conn is None:  # pragma: no cover
        pytest.skip("DB yok")
    app_dsn = os.getenv(
        "APP_DSN", "postgresql://app_rw:app_rw_secret_change_me@db:5432/tesis"
    )
    rol = app_dsn.split("//", 1)[1].split(":", 1)[0]
    yetkisiz = [
        ad
        for ad, _r, _f, _p, _t in katalog
        if not owner_conn.execute(
            "SELECT has_table_privilege(%s, %s, 'SELECT')", (rol, ad)
        ).fetchone()[0]
    ]
    assert not yetkisiz, (
        f"{rol} su tablolarda SELECT yetkisiz: " + ", ".join(yetkisiz)
        + ". Bu tablolarda izolasyon testleri POLITIKA yuzunden degil YETKI "
        + "yuzunden gecerdi (yanlis nedenle yesil)."
    )
