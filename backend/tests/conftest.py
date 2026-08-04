"""Test fixtures — RLS izolasyon testleri icin iki ayri DB baglantisi.

Baglanti bilgileri env'den okunur (libpq DSN; psycopg sync):
  * OWNER_DSN : owner/superuser (RLS BYPASS) — kurulum/temizlik icin.
  * APP_DSN   : app_rw (RLS'e TABI) — izolasyon davranisini dogrulamak icin.

Varsayilanlar compose ag ici hostname'i (`db`) ve .env.example sifrelerini
kullanir. Host'tan calistiriyorsaniz OWNER_DSN/APP_DSN env'lerini override edin
(orn. host=localhost).
"""
from __future__ import annotations

import os
import uuid

import psycopg
import pytest

OWNER_DSN = os.getenv(
    "OWNER_DSN",
    "postgresql://tesis_owner:owner_secret_change_me@db:5432/tesis",
)
APP_DSN = os.getenv(
    "APP_DSN",
    "postgresql://app_rw:app_rw_secret_change_me@db:5432/tesis",
)


def _connect(dsn: str, **kw):
    try:
        return psycopg.connect(dsn, connect_timeout=5, **kw)
    except Exception as exc:  # pragma: no cover - ortam yoksa anlamli atla
        pytest.skip(f"DB erisilemiyor ({dsn.split('@')[-1]}): {exc}")


# Fixture tenant'larinin slug ONEKLERI — hem uretim hem temizlik buradan.
# Yeni bir fixture tenant oneki eklenirse BURAYA da yazilmali.
FIXTURE_SLUG_ONEKLERI = (
    "ca-", "cb-",      # world (CRUD/RBAC)
    "rls-a-", "rls-b-",  # RLS izolasyonu
    "ta-", "tb-",      # auth testleri
    "cam-",            # kamera testleri
    "sched-",          # scheduler testleri
    # TUR 61: `POST /tenants` ADSIZ cagrildiginda backend tesise
    # "(Kurulum bekliyor)" yer tutucu adini verir ve slug ondan turer
    # (`kurulum-bekliyor-<6 hex>`). `test_tenants.py` bu ucu onlarca kez
    # cagiriyor ama YALNIZ silme testi kendi kaydini siliyor. Sonuc: her tam
    # kosum dev veritabaninda kalici tesisler biriktirdi — 2026-07-29'da
    # **100 tesis** vardi (seed tesisi dahil 101) ve panelin `/tenants`
    # sayfasi tamamen bu curufla doluydu. Bu yalniz kirlilik degil OLCUM
    # sorunu: her surus o sayfayi bu hâlde olcuyordu ve TR sizinti surusu
    # "Kurulum"/"bekliyor" kelimelerini VERI diye izin listesine almak
    # zorunda kaldi.
    "kurulum-bekliyor-",
)


#: (P75) Kosum kilidi anahtari — sabit ve keyfi; yalniz bu suit kullanir.
_KOSUM_KILIDI = 815_074_001


@pytest.fixture(scope="session", autouse=True)
def _artik_temizligi():
    """Onceki kosumdan KALAN fixture tenant'larini siler (tur 46).

    NEDEN: fixture tenant'lari `yield`den SONRA temizlenir; kosum ortadan
    kesilirse (timeout, Ctrl-C, konteyner yeniden baslatma) o adim hic
    calismaz ve satirlar kalir. Telefon GLOBAL benzersiz oldugu icin kalan
    TEK bir kullanici sonraki butun kosumlari `UniqueViolation` ile
    dusuruyordu — 700+ testlik suit tek bir artik satir yuzunden komple
    kirmiziya donuyordu.

    Temizlik yalniz FIXTURE oneklerine dokunur; seed tenant'i (`acme-plaza`)
    ve gercek veriler etkilenmez.
    """
    try:
        conn = psycopg.connect(OWNER_DSN, connect_timeout=5, autocommit=True)
    except Exception:  # pragma: no cover - DB yoksa testler zaten atlanir
        yield
        return
    try:
        with conn.cursor() as cur:
            # (P75) AYNI ANDA IKI KOSUM OLMAZ.
            #
            # Bu temizlik `slug LIKE 'ca-%'` ile TUM fixture tenant'larini
            # siler — BASKA BIR KOSUMUN CANLI tenant'lari dahil. Ikinci bir
            # pytest baslatmak, birincinin verisini ortasindan siliyordu ve
            # birinci kosum alfabetik olarak sonlardaki dosyalarda fixture
            # ERROR'u veriyordu. Olculdu: tam boyle bir "1 error" bulunmus
            # ve suit kusuru sanilmisti (P74) — oysa sebep ikinci kosumdu.
            #
            # Oneri lock, kosum boyunca ACIK KALAN bu baglantiya baglidir;
            # kosum nasil biterse bitsin (Ctrl-C, timeout) baglanti kapanir
            # ve kilit DUSER. Bekleme YOK, hemen hata: iki kosumun sirayla
            # beklemesi 22 dakikalik bir suitte sessiz bir takilma gibi
            # gorunurdu.
            cur.execute("SELECT pg_try_advisory_lock(%s)", (_KOSUM_KILIDI,))
            if not cur.fetchone()[0]:
                raise RuntimeError(
                    "Baska bir pytest kosumu bu veritabaninda ZATEN calisiyor. "
                    "Iki kosum ayni fixture tenant'larini paylasir ve bu "
                    "temizlik digerinin verisini siler. Once o kosumun "
                    "bitmesini bekleyin."
                )
            for onek in FIXTURE_SLUG_ONEKLERI:
                cur.execute("DELETE FROM tenant WHERE slug LIKE %s", (onek + "%",))
        yield
    finally:
        conn.close()


@pytest.fixture
def owner_conn():
    """Owner (superuser) baglantisi — autocommit; RLS'i bypass eder."""
    conn = _connect(OWNER_DSN, autocommit=True)
    try:
        yield conn
    finally:
        conn.close()


@pytest.fixture
def app_conn():
    """app_rw baglantisi — transaction-scoped (set_config LOCAL icin)."""
    conn = _connect(APP_DSN)
    try:
        yield conn
    finally:
        conn.rollback()
        conn.close()


@pytest.fixture
def two_tenants(owner_conn):
    """Owner ile 2 tenant + checkpoint'lar olusturur (A:2, B:3); sonra temizler."""
    tenant_a = uuid.uuid4()
    tenant_b = uuid.uuid4()

    # slug NOT NULL + benzersiz (bkz. /contracts/auth.md §1.1) — her kosumda essiz.
    slug_a = f"rls-a-{tenant_a.hex[:8]}"
    slug_b = f"rls-b-{tenant_b.hex[:8]}"
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO tenant (id, ad, slug, timezone) VALUES (%s, %s, %s, %s)",
            (tenant_a, "TENANT-A", slug_a, "Europe/Istanbul"),
        )
        cur.execute(
            "INSERT INTO tenant (id, ad, slug, timezone) VALUES (%s, %s, %s, %s)",
            (tenant_b, "TENANT-B", slug_b, "Europe/Istanbul"),
        )
        for i in range(2):
            cur.execute(
                "INSERT INTO checkpoint (tenant_id, ad, nfc_tag_uid) "
                "VALUES (%s, %s, %s)",
                (tenant_a, f"A-CP-{i}", f"A-{tenant_a}-{i}"),
            )
        for i in range(3):
            cur.execute(
                "INSERT INTO checkpoint (tenant_id, ad, nfc_tag_uid) "
                "VALUES (%s, %s, %s)",
                (tenant_b, f"B-CP-{i}", f"B-{tenant_b}-{i}"),
            )

    yield tenant_a, tenant_b

    # Temizlik: tenant silinince checkpoint'lar CASCADE ile gider.
    with owner_conn.cursor() as cur:
        cur.execute(
            "DELETE FROM tenant WHERE id IN (%s, %s)", (tenant_a, tenant_b)
        )


# --------------------------------------------------------------------------- #
# API uzerinden (token'li) testler icin paylasilan fixture'lar.
# (httpx/app importlari TEMBEL — app-free RLS testleri etkilenmesin.)
# --------------------------------------------------------------------------- #
API_URL = os.getenv("API_URL", "http://localhost:8000")

# world kullanicilarinin kimlik bilgileri (admin A ve B AYNI email -> slug ayristirir)
SHARED_EMAIL = "admin@example.com"
YONETICI_EMAIL = "yonetici@example.com"
GUARD_EMAIL = "guard@example.com"
GOREVLI_EMAIL = "gorevli@example.com"
RESIDENT_EMAIL = "resident@example.com"
PW_ADMIN_A = "passwordA1"
PW_YONETICI_A = "yoneticipassA1"
PW_GUARD_A = "guardpassA1"
PW_GOREVLI_A = "gorevlipassA1"
PW_RESIDENT_A = "residentpassA1"
AMIR_EMAIL = "amir@example.com"
PW_AMIR_A = "amirpassA1"
# (P128) Denetci — SALT-OKUMA mali gozetim rolu. Fixture'a eklenmezse rol
# matrisi kilidinin YEDINCI sutunu hic surulmez ve yeni rolun yetkileri
# OLCULMEDEN gecerdi (P35'te alti sutun icin ayni not dusulmustu).
DENETCI_EMAIL = "denetci@example.com"
PW_DENETCI_A = "denetcipassA1"
PW_ADMIN_B = "passwordB1"
PW_YONETICI_B = "yoneticipassB1"


@pytest.fixture
def redis_client():
    """Calisan Redis'e sync baglanti (signup rate-limit testleri icin).

    Rate-limit sabit-pencere IP anahtarlarini (`signup:*`) deterministik
    yapmak icin testler bu fixture ile temizler."""
    import redis as _redis

    url = os.getenv("REDIS_URL", "redis://redis:6379/0")
    try:
        r = _redis.Redis.from_url(url, socket_connect_timeout=3)
        r.ping()
    except Exception as exc:  # pragma: no cover - ortam yoksa atla
        pytest.skip(f"Redis erisilemiyor ({url}): {exc}")
    try:
        yield r
    finally:
        r.close()


@pytest.fixture
def client():
    """Calisan API'ye httpx.Client; erisilemezse testi atla."""
    import httpx

    try:
        c = httpx.Client(base_url=API_URL, timeout=10)
        c.get("/health")
    except Exception as exc:  # pragma: no cover
        pytest.skip(f"API erisilemiyor ({API_URL}): {exc}")
    try:
        yield c
    finally:
        c.close()


def _telefonlar(tenant_id: uuid.UUID, adet: int = 8) -> list[str]:
    """Kosuma OZEL, cakismayan E.164 numaralari (tur 46).

    Bicim `+9054<7 hane><indeks>` = 13 karakter (TR cep formatiyla ayni
    uzunluk; `normalize_phone` E.164 dogrulamasindan gecer). `+9054` oneki
    seed'in kullandigi `+90532...` araligindan da ayridir.

    Ayni tenant icin her zaman ayni diziyi verir (test icinde tekrar
    cagrilabilir), farkli kosumlarda farklidir.
    """
    taban = tenant_id.int % 10_000_000  # 7 hane
    return [f"+9054{taban:07d}{i}" for i in range(adet)]


# bcrypt BILEREK yavastir (~50-100 ms). `world` her testte 7 kullanici
# aciyor; parolalar ise SABIT. Hash'i test basina yeniden uretmek suit
# genelinde bos yere dakikalar harciyordu — parola basina BIR KEZ uretilip
# saklanir (dogrulama ayni parolayi kabul eder).
_HASH_ONBELLEK: dict[str, str] = {}


def _hash(parola: str) -> str:
    from app.security import hash_password

    if parola not in _HASH_ONBELLEK:
        _HASH_ONBELLEK[parola] = hash_password(parola)
    return _HASH_ONBELLEK[parola]


@pytest.fixture
def world(owner_conn, request):
    """A ve B tenant'lari + admin/security kullanicilar (CRUD/RBAC testleri icin)."""
    a = uuid.uuid4()
    b = uuid.uuid4()
    slug_a = f"ca-{a.hex[:8]}"
    slug_b = f"cb-{b.hex[:8]}"
    # TEMIZLIK ONCE KAYDEDILIR: kurulum yarida hata verirse (ornegin bir
    # kisit ihlali) `yield` sonrasi kod HIC calismaz ve tenant satiri
    # kalirdi (tur 46).
    def _sil() -> None:
        with owner_conn.cursor() as cur:
            cur.execute("DELETE FROM tenant WHERE id IN (%s,%s)", (a, b))

    request.addfinalizer(_sil)
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO tenant (id, ad, slug) VALUES (%s,%s,%s),(%s,%s,%s)",
            (a, "A", slug_a, b, "B", slug_b),
        )
        # telefon = GLOBAL benzersiz login anahtari; password_set=true (kalici
        # parola belli). email-login (/auth/login) VE telefon-login (/auth/
        # login-phone) ikisi de bu hesaplarla calisir. Numaralar seed'inkiyle
        # (+9053211122xx) cakismaz.
        # TELEFON = GLOBAL BENZERSIZ login anahtari. Sabit numaralar
        # (+90500000000x) kosumlar arasi CATISIYORDU: kesilmis bir kosumun
        # birakti tek satir, sonraki kosumun TUM testlerini dusuruyordu.
        # Numara artik tenant uuid'sinden turetilir — catisma imkansiz.
        tel = _telefonlar(a, adet=9)
        users = [
            (a, "Admin A", SHARED_EMAIL, PW_ADMIN_A, "admin", tel[0]),
            (a, "Yonetici A", YONETICI_EMAIL, PW_YONETICI_A, "yonetici", tel[1]),
            (a, "Guard A", GUARD_EMAIL, PW_GUARD_A, "security", tel[2]),
            (a, "Gorevli A", GOREVLI_EMAIL, PW_GOREVLI_A, "tesis_gorevlisi", tel[3]),
            (a, "Resident A", RESIDENT_EMAIL, PW_RESIDENT_A, "resident", tel[4]),
            (b, "Admin B", SHARED_EMAIL, PW_ADMIN_B, "admin", tel[5]),
            (b, "Yonetici B", YONETICI_EMAIL, PW_YONETICI_B, "yonetici", tel[6]),
            # (P35) Guvenlik amiri — rol matrisi kilidi ALTINCI sutunu bundan
            # surer; fixture'a eklenmezse yeni rol hic olculmezdi.
            (a, "Amir A", AMIR_EMAIL, PW_AMIR_A, "guvenlik_amiri", tel[7]),
            # (P128) Gorev penceresi YOK (suresiz) — pencere davranisi kendi
            # testinde acikca kurulur; buradaki hesap "normal" denetcidir.
            (a, "Denetci A", DENETCI_EMAIL, PW_DENETCI_A, "denetci", tel[8]),
        ]
        # Dongu degiskeni `tel` OLAMAZ: listeyi golgeler ve `yield` sozlugu
        # numaralar yerine SON numaranin KARAKTERLERINI dagitirdi.
        for tid, ad, email, pw, role, telefon in users:
            cur.execute(
                "INSERT INTO app_user "
                "(tenant_id, ad, email, telefon, password_hash, password_set, role) "
                "VALUES (%s,%s,%s,%s,%s,true,%s::user_role)",
                (tid, ad, email, telefon, _hash(pw), role),
            )

    yield {
        "a": a,
        "b": b,
        "slug_a": slug_a,
        "slug_b": slug_b,
        "admin_a": {"email": SHARED_EMAIL, "password": PW_ADMIN_A, "phone": tel[0]},
        "yonetici_a": {"email": YONETICI_EMAIL, "password": PW_YONETICI_A, "phone": tel[1]},
        "guard_a": {"email": GUARD_EMAIL, "password": PW_GUARD_A, "phone": tel[2]},
        "gorevli_a": {"email": GOREVLI_EMAIL, "password": PW_GOREVLI_A, "phone": tel[3]},
        "resident_a": {"email": RESIDENT_EMAIL, "password": PW_RESIDENT_A, "phone": tel[4]},
        "admin_b": {"email": SHARED_EMAIL, "password": PW_ADMIN_B, "phone": tel[5]},
        "yonetici_b": {"email": YONETICI_EMAIL, "password": PW_YONETICI_B, "phone": tel[6]},
        # Testlerin KENDI olusturdugu numaralar da kosuma ozel olmali
        # (kesilmis kosum artik satiri birakirsa global benzersizlik
        # sonraki kosumu dusuruyordu).
        "amir_a": {"email": AMIR_EMAIL, "password": PW_AMIR_A, "phone": tel[7]},
        "denetci_a": {
            "email": DENETCI_EMAIL, "password": PW_DENETCI_A, "phone": tel[8],
        },
        "bos_telefonlar": _telefonlar(b, adet=4),
    }


