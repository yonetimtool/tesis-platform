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

    # (P190) API'nin PUBLIC tabani — e-postadaki List-Unsubscribe (RFC 8058)
    # tek-tik bagi buraya POST'lanir; backend ucu dogrudan cevaplamali (web
    # aracisiz). Kanonik `api.yonetiyor.com` (api.yonetio.site de yasar).
    api_public_url: str = "https://api.yonetiyor.com"

    # --- (P155r2 / §4 · P186) MAGAZA BAGLANTILARI — davet SMS'i + e-postasi ---
    #
    # Play paketi `com.app.yonetiyor`; App Store id'si (P186) TAHSIS EDILDI:
    # `id6797316863`. Ikisi de varsayilan olarak DOLU. Bos birakilan bir magaza
    # icin ( or. bir platformdan cekilirse) dugme CIZILMEZ — uydurma/kirik bir
    # baglanti hic baglanti gondermemekten kotudur; bu koruma korunur.
    #
    # `admin-web/lib/magaza.ts` ve `davet_eposta.py` ayni kurali uygular
    # (url yoksa dugme cizilmez); tum yuzeyler ayni davranisi gosterir.
    play_store_url: str = (
        "https://play.google.com/store/apps/details?id=com.app.yonetiyor"
    )
    app_store_url: str = "https://apps.apple.com/tr/app/id6797316863"

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
    #: (P187) Havuzdaki baglantiyi bu sure (sn) sonra GERI DONUSTUR. Sonsuz
    #: yasayan bir baglanti, agdaki sessiz bir kopmayi ya da sunucu-tarafi
    #: sonlandirmayi pool_pre_ping'e kadar fark etmez; periyodik tazeleme
    #: bayat baglantilarin havuzda birikmesini onler.
    db_pool_recycle: int = 1800
    #: (P187) BAGLANTI SIZINTISI SAVUNMASI (engine seviyesi; goc 0071 rol
    #: seviyesinde de koyar). Bir transaction bu kadar ms BOSTA (idle in
    #: transaction) kalirsa PG oturumu oldurur ve slotu geri verir. 60 sn:
    #: normal istek ms surer; en uzun mesru bosluk davetin senkron SMTP/SMS
    #: cagrisidir (~18 sn) ve bunun rahatca altinda kalir.
    db_idle_tx_timeout_ms: int = 60000

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
    # (P150) SMS GECIDI. Hicbiri verilmezse saglayici LOG'dur ve SMS
    # GERCEKTEN GITMEZ — bu, "yanlislikla gonderim" yerine "hic gonderim"
    # tarafinda hata yapmak icin bilincli bir varsayilan.
    # (P177 §6) SMS ANA SALTERI — SAGLAYICIDAN AYRI VE ONUN USTUNDE.
    #
    # NEDEN AYRI BIR BAYRAK: `sms_saglayici` bos birakmak "yapilandirma
    # eksik" demektir; bir gun biri gecidi baglar ve SMS ANINDA AKMAYA
    # BASLAR. Oysa bugun SMS gonderilmemesi bir EKSIKLIK DEGIL, bir
    # KARARDIR: Verimor/Netgsm baslik onayimiz yok ve onaysiz baslikla
    # gonderilen SMS operator tarafindan reddedilir ya da spam sayilir.
    # Telefon bu urunde yalniz ILETISIM BILGISIDIR, dogrulama araci
    # degildir (dogrulama e-posta koduyla yapilir).
    #
    # `false` iken `sms_saglayicisi()` saglayici ne olursa olsun
    # `KapaliSmsSaglayici` doner: gonderim DENENMEZ ve sonuc
    # `yapilandirilmadi` olur — yani cagiran "gonderildi" SANMAZ.
    #
    # Kod yolu ILERIDE ACILABILIR halde birakildi: tek satir `SMS_AKTIF=true`.
    sms_aktif: bool = False
    sms_saglayici: str | None = None        # "netgsm" | None
    sms_kullanici: str | None = None
    sms_parola: str | None = None
    sms_baslik: str | None = None           # onayli gonderici basligi
    sms_url: str = "https://api.netgsm.com.tr/sms/send/get"
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
    # (P167 §6.3) SILINMIS dokumanin bekleme suresi — GUN cinsinden.
    # AY degil GUN: bu bir kisisel-veri saklama siniri degil, "yanlislikla
    # sildim" penceresi. Aylarca beklemek, silinen dosyanin depoda
    # aylarca durmasi demekti; hemen silmek ise geri donusu yok ederdi.
    retention_dokuman_grace_days: int = 30
    # (P167 §5) URETILMIS RAPOR CIKTILARININ omru — GUN cinsinden.
    #
    # DOKUMANDAN DAHA KISA VE BILINCLI: dokuman tesisin ARSIVIDIR, rapor
    # ciktisi ise GECICI BIR TURETMEDIR — kaybolursa aynisi yeniden
    # uretilebilir. Saklamanin tek amaci "kullanici indirmeye firsat
    # bulsun".
    #
    # KVKK ACISINDAN DA DAR OLMALI: `borc_alacak` ciktisi daire daire ad
    # ve borc tasir. Yeniden uretilebilen bir dosyayi aylarca depoda
    # tutmak, amac sinirliligiyla bagdasmazdi.
    retention_rapor_isi_days: int = 7
    # Tek DELETE/UPDATE partisi (bellek/kilit basincini sinirlar).
    retention_batch_size: int = 500

    # --- (P154 / Asama 4) SOSYAL GIRIS — Google / Microsoft / Apple ---
    #
    # HEPSI BOS VARSAYILANLI: yapilandirilmamis saglayici KAPALIDIR ve
    # `/auth/oauth/saglayicilar` onu listelemez. Brief'in sarti bu —
    # "tikanirsa Asama 3 tek basina calissin": sosyal giris hic
    # yapilandirilmasa da telefon/parola akislari degismeden isler.
    #
    # `*_aud` NEDEN AYRI: ayni Google projesi web ve Android icin AYRI
    # istemci kimlikleri uretir ve `id_token.aud` hangisiyle giris
    # yapildiysa onu tasir. Virgulle ayrilmis liste; bos birakilirsa
    # `*_client_id` tek basina kullanilir (yalniz web).
    oauth_google_client_id: str = ""
    oauth_google_client_secret: str = ""
    oauth_google_aud: str = ""
    oauth_microsoft_client_id: str = ""
    oauth_microsoft_client_secret: str = ""
    oauth_microsoft_aud: str = ""
    # `common` = hem is/okul hem kisisel Microsoft hesaplari. Tek bir
    # kiraciya kilitlemek, sakinlerin kisisel hesaplarini disarida
    # birakirdi.
    oauth_microsoft_tenant: str = "common"
    # Apple'da `client_id` bir "Services ID"dir (web) ya da paket
    # kimligidir (mobil); ikisi de `oauth_apple_aud` listesine girer.
    oauth_apple_client_id: str = ""
    oauth_apple_aud: str = ""
    oauth_apple_team_id: str = ""
    oauth_apple_key_id: str = ""
    # .p8 dosyasinin ICERIGI. Env'de tek satira sigmasi icin `\n`
    # kacislari kabul edilir (`oauth._apple_istemci_sirri` cozer).
    oauth_apple_private_key: str = ""
    # Sosyal giris oturumunun (state) omru. Kisa: kullanici saglayiciya
    # gidip donene kadar yeter, calinan bir `state`in kullanim
    # penceresini dar tutar.
    # Saglayiciya bildirilen `redirect_uri`nin tabani. TERS VEKIL
    # ARKASINDA ZORUNLU: saglayicilar adresi TAM ESLESME ile dogrular ve
    # istekten turetilen adres (ic konak, http, farkli port) kayitli
    # adresle tutmazdi. Bos birakilirsa istegin taban adresi kullanilir.
    oauth_callback_taban: str = ""
    # Callback sonrasi tarayicinin gonderilecegi adresler. ISTEKTEN
    # ALINMAZ — istekten almak acik-yonlendirme acigi olurdu.
    # BOS = O YUZEY KAPALI. Varsayilan olarak bos: panelin mutlak adresi
    # sunucudan bilinemez ve gorece bir adres callback'te API konagina
    # cozulup 404 verirdi. Bos birakildiginda `basla` 503 doner — hata,
    # kullanici siteden AYRILMADAN gorunur.
    oauth_web_donus: str = ""
    # (P180) niyet=kayit donusu — yonetici kayit tamamlama sayfasi. BOS =
    # SSO KAYIT KAPALI (basla'da 503; sessiz yanlis-yapilandirma yok). Giris
    # akisi bundan ETKILENMEZ.
    oauth_kayit_donus: str = ""
    # Mobil, tarayici oturumunu bir OZEL SEMA ile kapatir; adres
    # saglayiciya HIC bildirilmez (saglayici yalniz callback'i gorur),
    # bu yuzden Apple'in "https zorunlu" kurali ihlal edilmez.
    oauth_mobil_donus: str = "com.app.yonetiyor://oauth"
    oauth_state_ttl_seconds: int = 600
    # Kimligi dogrulanmis ama HENUZ ESLESMEMIS kullanicinin elindeki
    # baglama jetonunun omru: tesis kodu + telefon + SMS kodu girecek
    # kadar sure.
    oauth_baglama_ttl_seconds: int = 900


    # ======================================================================
    # (P177) YENI KAYIT AKISI + TICARI ILETI KAPILARI
    # ======================================================================

    #: (P177 §0) YENI KAYIT AKISI — VARSAYILAN KAPALI.
    #:
    #: Kapaliyken bu turda eklenen uclarin HEPSI `503 kayit_akisi_kapali`
    #: doner ve mevcut kimlik sistemi BIREBIR bugunku gibi calisir:
    #: `/auth/kayit/tesis-olustur`, `/auth/kayit/rol-basla`,
    #: `/auth/login`, `/auth/login-phone`, sosyal giris — hicbiri bu
    #: bayragi OKUMAZ.
    #:
    #: NEDEN VARSAYILAN KAPALI: Play kapali testi MEVCUT sistemle
    #: yapilacak. Yeni bir kayit yolunu varsayilan acik birakmak, o testin
    #: ortasinda ikinci bir kapi acmak olurdu.
    #:
    #: KAPI TEK YERDE: tanitim sitesinde ikinci bir istemci bayragi YOK.
    #: Iki bayrak, ayrisabilecekleri bir durum uretirdi.
    yeni_kayit_akisi: bool = False

    #: (P177 §4) TICARI ELEKTRONIK ILETI GONDERIMI — VARSAYILAN KAPALI.
    #:
    #: Kayit formundaki ucuncu onay SAKLANIR (KVKK/6563: rizanin varligi
    #: ve zamani ispatlanabilir olmali) ama HICBIR ticari ileti
    #: GONDERILMEZ: sirket kaydi ve IYS (Ileti Yonetim Sistemi) kaydi
    #: yok. IYS'ye islenmemis bir rizayla ticari ileti gondermek idari
    #: para cezasi sebebidir.
    #:
    #: Yani bu bayrak "ozellik eksik" demiyor; "riza toplaniyor, gonderim
    #: kapali" diyor. Acilmasi icin once IYS kaydi gerekir.
    ticari_ileti_aktif: bool = False

    #: (P177 §4) Yonetici basvurusunun (e-posta dogrulanana kadar) omru.
    #: Kisa: dogrulanmamis bir basvuru, birinin e-posta adresini tutan
    #: bir kayittir ve suresiz durmamalidir.
    yonetici_basvuru_omru_saat: int = 24

    #: (P177 §5) Dogrulanmis basvurunun tesis acma jetonunun omru.
    #: Kullanici kodu girdikten sonra site adini yazacak kadar sure.
    kurulum_jetonu_omru_dk: int = 30


settings = Settings()
