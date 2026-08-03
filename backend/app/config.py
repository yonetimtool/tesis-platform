"""Uygulama ayarlari — env'den okunur (pydantic-settings).

Uygulama DB'ye DUSUK YETKILI `app_rw` rolu ile (async) baglanir; bu rol RLS'e
tabidir. Owner/superuser baglantisi sadece migration ve testlerde kullanilir
(uygulama kodu owner ile baglanmaz).
"""
from __future__ import annotations

from urllib.parse import urlsplit, urlunsplit

from pydantic_settings import BaseSettings, SettingsConfigDict


def _punycode_origin(origin: str) -> str | None:
    """`https://yönetiyor.com` -> `https://xn--ynetiyor-n4a.com`.

    Zaten ASCII olan ya da cozulemeyen girdide `None` doner (cagiran o
    zaman ham degeri kullanir). STDLIB `idna` codec'i yeterli: yeni bir
    bagimlilik eklemek, tek bir alan adi icin tedarik zinciri yuzeyini
    buyutmek olurdu.

    PORT KORUNUR: `netloc` yalniz KONAK kismindan cevrilir; `:8000` gibi
    bir son ek `idna` codec'ini hata verdirirdi.
    """
    try:
        parca = urlsplit(origin)
        konak = parca.hostname
        if not konak or konak.isascii():
            return None
        ace = konak.encode("idna").decode("ascii")
        netloc = f"{ace}:{parca.port}" if parca.port else ace
        return urlunsplit((parca.scheme, netloc, parca.path, "", ""))
    except (UnicodeError, ValueError):
        # Bozuk/desteklenmeyen girdi: cagiran ham degeri kullanmaya devam
        # eder. Burada patlamak, tek bir yazim hatasi yuzunden UYGULAMANIN
        # ACILMAMASI demek olurdu.
        return None


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Async SQLAlchemy URL (app_rw, asyncpg suruculu).
    # Ornek: postgresql+asyncpg://app_rw:***@db:5432/tesis
    database_url: str = "postgresql+asyncpg://app_rw:app_rw_secret_change_me@localhost:5432/tesis"

    # Redis (cache / Celery broker+backend).
    redis_url: str = "redis://localhost:6379/0"

    # JWT (token uretimi Prompt 2'de; burada sadece ayar iskeleti).
    jwt_secret: str = "change-me-please-use-32+chars-secret"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 30

    # SQLAlchemy engine echo (debug).
    sql_echo: bool = False

    # --- PORTAL TABAN ADRESI (P120) ---
    # Sakine GIDEN mesajlardaki `{odeme_linki}` etiketi bundan uretilir.
    #
    # NEDEN AYAR OLDU: burada `yonetio.app/ode` SABIT KODLUYDU ve
    # **yonetio.app BIZE AIT DEGIL** (NS'i Cloudflare; bizim alanlarimizin
    # hepsi Hostinger'da). Yani aidat hatirlatma SMS/e-postalarinda
    # sakinlere UCUNCU BIR TARAFIN alan adina baglanti gonderiyorduk —
    # o alani elinde tutan biri, BIZIM gonderdigimiz mesajdaki baglantiyla
    # sakinlerimizi kimlik avina dusurebilirdi.
    #
    # UNICODE bilerek: baglanti insanin okudugu bir mesaj metnine girer;
    # `xn--...` bicimi SMS'te kimlik avi gibi gorunur. Modern istemciler
    # unicode adresi kendileri punycode'a cevirir.
    #
    # NOT: `/ode` rotasi HENUZ YOK (panelin public rotalari: /gizlilik,
    # /kosullar, /login). Baglanti bugun 404 verir — ama BIZIM alanimizda
    # 404 verir; yabancinin alaninda calisan bir sayfadan iyidir.
    portal_base_url: str = "https://yönetiyor.com"

    # --- CORS (uretim) ---
    # Virgulle ayrilmis izinli tarayici kaynaklari (orn.
    # "https://panel.yonetio.site"). Bos (dev varsayilani) => CORS middleware
    # EKLENMEZ: panel BFF (Next sunucu tarafi) API'yi cagirir, tarayici API'ye
    # dogrudan gitmez; mobil ise native (CORS'suz). Prod'da panel origin'i verilir.
    cors_origins: str = ""

    @property
    def cors_origin_list(self) -> list[str]:
        """Izinli origin'ler — IDN alan adlari PUNYCODE'a normallestirilmis.

        NEDEN (P120): birincil musteri alani `yönetiyor.com` bir IDN'dir.
        Tarayici `Origin` basligini DAIMA punycode gonderir
        (`https://panel.xn--ynetiyor-n4a.com`); yapilandirmaya unicode
        yazilmissa `allow_origins` listesi TAM ESLESME yaptigi icin hicbir
        istek gecmez ve belirti "CORS bozuk" diye gorunur — alan adinin
        yazim bicimi kimsenin aklina gelmez.

        Iki bicim de listede TUTULUR: hangisinin yazildigi onemsizlesir.
        Cozulemeyen bir deger (IP, `localhost`, bozuk giris) OLDUGU GIBI
        birakilir — sessizce dusurmek, calisan bir origin'i yok ederdi.
        """
        cikti: list[str] = []
        for ham in self.cors_origins.split(","):
            o = ham.strip()
            if not o:
                continue
            if o not in cikti:
                cikti.append(o)
            ace = _punycode_origin(o)
            if ace and ace not in cikti:
                cikti.append(ace)
        return cikti

    # --- NTAG424 SDM/SUN dogrulamasi ---
    # Checkpoint-basina AES-128 etiket anahtarlarini sifrelemekte kullanilan
    # KEK (key encryption key). 32+ karakter; bos = SDM anahtar kaydi kapali
    # (PUT /checkpoints/{id}/sdm-key -> 500 config_error). jwt_secret deseni.
    sdm_kek: str = ""

    # --- Scheduler (Celery beat) ---
    # OWNER (superuser) libpq DSN — tenant enumerasyonu (RLS bootstrap) icin.
    owner_dsn: str = "postgresql://tesis_owner:owner_secret_change_me@localhost:5432/tesis"
    # app_rw libpq DSN (SYNC) — tenant-scoped pencere uretimi/tespiti icin.
    app_dsn: str = "postgresql://app_rw:app_rw_secret_change_me@localhost:5432/tesis"
    # Pencereler kac gun ileri uretilsin (bugun + ... => varsayilan bugun+yarin).
    scheduler_horizon_days: int = 2
    # Beat periyotlari (saniye).
    scheduler_generate_interval_seconds: int = 3600   # saat basi
    scheduler_detect_interval_seconds: int = 300      # 5 dk
    # (P34) Gecikme alarmi tespitten SIK kosar: pencere aciktir ve tur hala
    # kurtarilabilir; 5 dakikada bir bakan bir gorev, 10 dakikalik toleransi
    # 15. dakikada haber verirdi.
    scheduler_gecikme_interval_seconds: int = 120     # 2 dk

    # (P39) Veritabani havuzu — YUK ALTINDA OLCULDU. Varsayilan SQLAlchemy
    # havuzu (5 + 10) tek uvicorn isciyle bile yetiyordu; COKLU ISCIYE
    # gecince toplam baglanti = isci x (havuz + tasma) olur ve Postgres'in
    # `max_connections` (100) siniri ASILIRSA istekler "too many clients"
    # ile DUSER. Bu yuzden isci basina havuz KUCUK tutulur ve toplam,
    # scaling-runbook.md'deki formulle secilir.
    db_pool_size: int = 5
    db_max_overflow: int = 5
    #: Havuz doluyken bir istegin baglanti icin bekleyecegi sure. Sinirsiz
    #: bekleme, yuk altinda istegi sessizce ASILI birakirdi.
    db_pool_timeout: int = 10

    # --- MinIO (S3-uyumlu foto kanit deposu) ---
    # PUBLIC endpoint: presigned URL host'u (istemci buraya PUT'lar). dev: localhost.
    minio_endpoint: str = "http://localhost:9000"
    minio_access_key: str = "minioadmin"
    minio_secret_key: str = "minioadmin12345"  # compose varsayilani ile ayni (>=8)
    minio_bucket: str = "tesis-foto"
    minio_region: str = "us-east-1"
    minio_url_expire_seconds: int = 900

    # --- Odeme saglayici (kart) ---
    # manual | iyzico | paytr. GERCEK ANAHTAR YOK — placeholder'lar (sandbox sonra).
    payment_provider: str = "manual"

    # --- E-posta (P32) — SMTP YAPILANDIRILMAMISSA saglayici LOG'a duser.
    # Mimarinin kosulu buydu: gercek gonderim bir YAPILANDIRMA degisikligi
    # olmali, kod degisikligi degil.
    smtp_host: str | None = None
    smtp_port: int = 587
    smtp_user: str | None = None
    smtp_password: str | None = None
    smtp_from: str | None = None
    iyzico_api_key: str = ""
    iyzico_secret: str = ""
    iyzico_base_url: str = "https://sandbox-api.iyzipay.com"
    paytr_merchant_id: str = ""
    paytr_merchant_key: str = ""
    paytr_merchant_salt: str = ""
    paytr_base_url: str = "https://www.paytr.com"

    # --- Push saglayici (FCM) ---
    # noop | fcm. Kimlik yoksa FcmProvider unconfigured (no-op) — cokme yok.
    push_provider: str = "noop"
    fcm_project_id: str = ""  # bos birakilabilir: dosyadaki project_id kullanilir
    # Service account: ONCE dosya yolu (compose read-only mount, onerilen)...
    fcm_service_account_path: str = ""
    # ...yoksa inline JSON metni (test/gecici). Ikisi de bossa unconfigured.
    fcm_service_account_json: str = ""
    fcm_base_url: str = "https://fcm.googleapis.com"

    # Hava durumu proxy'si (WP-C) — anahtarsiz Open-Meteo; testte/ozel kurulumda
    # baska taban URL verilebilir.
    weather_base_url: str = "https://api.open-meteo.com"
    weather_cache_ttl: int = 1800  # saniye — tenant basina >=30dk'da 1 dis istek

    # --- Icerik cevirisi (duyuru / site kurali / etkinlik, 7 dil) ---
    # libretranslate (varsayilan, kendi barindirdigimiz servis) | echo
    # (deterministik sahte — dev/test) | noop (kapali).
    translate_provider: str = "libretranslate"
    # Compose ic ag adresi; kullanici girdisi DEGIL (bkz. translate.py SSRF notu).
    translate_url: str = "http://libretranslate:5000"
    translate_api_key: str = ""
    translate_timeout_seconds: float = 30.0
    # Kuyruga verme GECIKMESI (saniye). Ceviri isi istek yolundan, istegin
    # transaction'i HENUZ COMMIT EDILMEDEN kuyruklanir; worker hemen kosarsa
    # icerigi GOREMEZ ("icerik yok" -> ceviri hic uretilmez). Kucuk bir
    # gecikme commit'in onde olmasini saglar; task ayrica sinirli sayida
    # yeniden dener (bkz. app/tasks.py translate_entity).
    translate_enqueue_delay_seconds: float = 2.0

    # --- KVKK saklama & imha (retention) — AY cinsinden ---
    # Saklama sinirlama ilkesi (KVKK m.4/2-d + m.7): kisisel veri, isleme amaci
    # gectikten sonra tutulmaz. Varsayilanlar operatorce ENV ile DARALTILABILIR
    # (uzatilmasi onerilmez). Gerekce contracts/auth.md §7'de belgelenmistir.
    retention_visitors_months: int = 24        # ziyaretci LOG kaydi
    retention_kargo_months: int = 24           # kargo/paket kaydi (+foto)
    retention_reservations_months: int = 24    # TAMAMLANMIS/IPTAL rezervasyon
    retention_tickets_months: int = 36         # COZULMUS/REDDEDILMIS talep/sikayet
    retention_audit_months: int = 24           # audit_log purge
    # Tek DELETE/UPDATE partisi (bellek/kilit basincini sinirlar).
    retention_batch_size: int = 500


settings = Settings()
