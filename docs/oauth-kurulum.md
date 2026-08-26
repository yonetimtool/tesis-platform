# Sosyal Giriş — Konsol Kurulumu (P154 / Aşama 4 · P155r2 §5 güncellemesi)

> **(P155r2) ALAN ADLARI DÜZELTİLDİ.** Bu belge `api.test.yonetiyor.com`
> yazıyordu; test sunucusu Cloudflare Tunnel'a taşınınca adlar **tek
> seviyeye** indi (ücretsiz sertifika `*.test.*`'i kapsamıyor —
> `docs/test-sunucusu-kurulum.md` §son). Gerçek adlar aşağıdaki tabloda.

Bu belge **Kerem'in üç sağlayıcı konsolunda yapması gereken işleri** ve
karşılık gelen ortam değişkenlerini tam liste hâlinde verir. Kod tarafı
bitti; buradaki adımlar tamamlanana kadar sosyal giriş **kapalıdır** ve
bu bilinçlidir: yapılandırılmamış sağlayıcı ne mobilde ne web'de düğme
olarak görünür, telefon/parola girişi hiç etkilenmez.

---

## 0. ÖNCE BİLİNMESİ GEREKEN İKİ ŞEY

**1. Kaydedilecek geri dönüş adresi TEK TANEDİR.**
Mobil için ayrı adres, ayrı istemci gerekmez. Akış şöyle:

```
kullanıcı → sağlayıcı → https://api.<ortam>/auth/oauth/callback/<saglayici>
                              ↓ (arka uç sonucu Redis'e yazar)
       web:   https://panel.<ortam>/giris/oauth?oauth=<tek-kullanımlık-id>
       mobil: com.app.yonetiyor://oauth?oauth=<tek-kullanımlık-id>
```

Sağlayıcı **yalnız ortadaki https adresini** görür. Özel şemaya
yönlendirmeyi biz yaparız — bu yüzden Apple'ın "geri dönüş adresi https
olmalı" kuralı ihlal edilmez.

**2. Canlı istemciye test adresi EKLENMEYECEK.**
Sağlayıcılar adresi tam eşleşmeyle doğrular; canlı istemciye ikinci bir
adres eklemek, canlı istemcinin yapılandırmasını test için değiştirmek
olur. Her ortam için **ayrı istemci** açılır.

**3. İKİ ORTAMIN ALAN ADLARI (her adım bunlara bakar).**

| | **TEST/dev** | **CANLI (prod)** |
|---|---|---|
| API | `localhost:8000` | `api.yonetiyor.com` (+ eski `api.yonetio.site`) |
| Panel (platform) | `localhost:3000` | `panel.yonetiyor.com` |
| Uygulama (tesis) | `localhost:3000` | `app.yonetiyor.com` |
| Portal | `localhost:3000` | `yonetiyor.com` (IDN: `xn--ynetiyor-n4a.com`) |

> Canlı API **İKİ hostname'den** servis edilir: kanonik `api.yonetiyor.com`
> VE App Store/Play'de yayında olan sürümlerin gömülü adresi `api.yonetio.site`
> (yaşamaya devam eder — `infra/Caddyfile` dual-serve). Her sağlayıcıya İKİ
> redirect URI kaydedin (kanonik + eski). Google/Microsoft TEST için
> `http://localhost` kabul eder; Apple ETMEZ (aşağıda).

---

## 1. GOOGLE (Google Cloud Console)

1. <https://console.cloud.google.com> → proje seç/oluştur.
2. **APIs & Services → OAuth consent screen**
   - User type: **External**
   - Uygulama adı: `Yönetiyor`, destek e-postası, geliştirici e-postası
   - **Scopes:** `openid`, `.../auth/userinfo.email` — `profile` isteğe
     bağlı. Başka kapsam **istemeyin**: kullanmadığımız her kapsam
     doğrulama sürecini uzatır.
   - Yayına almadan önce **Test users** listesine testçileri ekleyin.
3. **APIs & Services → Credentials → Create credentials → OAuth client ID**
   - Application type: **Web application**
   - Name: `Yonetio TEST` (canlı için ayrı: `Yonetio PROD`)
   - **Authorized redirect URIs** — tam olarak (istemci başına BİR tane):
     - `Yonetio TEST` → `http://localhost:8000/auth/oauth/callback/google`
     - `Yonetio PROD` → `https://api.yonetiyor.com/auth/oauth/callback/google`
       **ve** `https://api.yonetio.site/auth/oauth/callback/google` (ikisi de)
   - "Authorized JavaScript origins" **gerekmez** (kod akışı kullanıyoruz,
     tarayıcıda jeton işlemiyoruz).
4. Çıkan **Client ID** ve **Client secret** değerlerini alın.

```env
OAUTH_GOOGLE_CLIENT_ID=<...>.apps.googleusercontent.com
OAUTH_GOOGLE_CLIENT_SECRET=<...>
# OAUTH_GOOGLE_AUD boş bırakılabilir — o zaman CLIENT_ID kullanılır.
```

---

## 2. MICROSOFT (Azure Portal)

1. <https://portal.azure.com> → **Microsoft Entra ID → App registrations
   → New registration**
   - Name: `Yonetio TEST`
   - **Supported account types: "Accounts in any organizational
     directory and personal Microsoft accounts"** — bu şart. Tek kiracıya
     kilitlemek, sakinlerin kişisel Microsoft hesaplarını dışarıda
     bırakırdı.
   - Redirect URI: platform **Web**, adres:
     - TEST kaydı → `http://localhost:8000/auth/oauth/callback/microsoft`
     - PROD kaydı → `https://api.yonetiyor.com/auth/oauth/callback/microsoft`
       **ve** `https://api.yonetio.site/auth/oauth/callback/microsoft`
2. **Certificates & secrets → New client secret** → değeri **hemen**
   kopyalayın (bir daha gösterilmez).
3. **API permissions**: `openid`, `email`, `profile` (Microsoft Graph →
   Delegated). Varsayılan `User.Read` gereksiz, kaldırılabilir.
4. **Overview** ekranından **Application (client) ID**'yi alın.

```env
OAUTH_MICROSOFT_CLIENT_ID=<uygulama-kimliği>
OAUTH_MICROSOFT_CLIENT_SECRET=<gizli-anahtar-DEĞERİ>
OAUTH_MICROSOFT_TENANT=common
```

> `common` kiracısında `iss` her kiracı için farklıdır
> (`https://login.microsoftonline.com/{kiracı}/v2.0`). Arka uç bunu önek +
> `/v2.0` sonu ile doğrular; sabit bir dize beklemek kişisel hesap
> dışında herkesi reddederdi.

---

## 3. APPLE (Apple Developer)

Apple üç ayrı nesne ister; sırası önemli.

1. **App ID** — Certificates, Identifiers & Profiles → Identifiers → **App IDs**
   - Bundle ID: `com.app.yonetiyor` (mevcut, **değiştirmeyin**)
   - Capabilities: **Sign in with Apple** işaretli.
2. **Services ID** — Identifiers → **Services IDs** → yeni
   - Identifier: `com.app.yonetiyor.web` (web tarafının `client_id`'si)
   - **Configure → Sign in with Apple**
     - Primary App ID: yukarıdaki App ID
     - **Domains and Subdomains:**
       - PROD Services ID → `api.yonetiyor.com` **ve** `api.yonetio.site`
       - (Apple `localhost` KABUL ETMEZ → TEST için gerçek bir alan adı
         gerekir; pratikte Apple'ı yalnız PROD'da doğrulayın.)
     - **Return URLs:**
       - PROD → `https://api.yonetiyor.com/auth/oauth/callback/apple`
         **ve** `https://api.yonetio.site/auth/oauth/callback/apple`
   - PROD için `com.app.yonetiyor.web` Services ID yeterlidir. (Apple TEST
     ayrı bir GERÇEK alan adı gerektirir — `localhost` desteklemez; ihtiyaç
     olursa ayrı bir test Services ID açılır.)
3. **Key** — Keys → yeni anahtar
   - **Sign in with Apple** işaretle, Primary App ID'yi seç
   - `.p8` dosyasını indirin — **BİR KEZ indirilir**, kaybolursa yeni
     anahtar üretmek gerekir.
   - **Key ID** (10 karakter) ve **Team ID** (hesap sağ üstünde) not edin.

```env
# `client_id`: web için Services ID, mobilde de aynı akış kullanıldığı
# için ek bir değer gerekmez.
OAUTH_APPLE_CLIENT_ID=com.app.yonetiyor.web
OAUTH_APPLE_TEAM_ID=<10-karakter>
OAUTH_APPLE_KEY_ID=<10-karakter>
# .p8 İÇERİĞİ tek satırda; satır sonları \n olarak yazılır.
OAUTH_APPLE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\nMIGT...\n-----END PRIVATE KEY-----
```

> Apple'ın `client_secret`i **sabit bir sır değil**, `.p8` ile ES256
> imzalanmış kısa ömürlü bir JWT'dir. Arka uç bunu her takasta yeniden
> üretir; uzun ömürlü bir sır saklamak, süresi dolduğunda girişin
> sessizce durması demekti (Apple azami 6 ay verir).

---

## 4. ORTAK AYARLAR (her ortam için)

**TEST/dev** (`infra/.env`):

```env
# Sağlayıcıya bildirilen redirect_uri'nin tabanı. TERS VEKİL ARKASINDA
# ZORUNLU: istekten türetilen adres (iç konak, http, farklı port) kayıtlı
# adresle tutmaz ve giriş "redirect_uri mismatch" ile patlar.
OAUTH_CALLBACK_TABAN=http://localhost:8000
# Callback sonrası tarayıcının gönderileceği yerler. BOŞ = O YÜZEY KAPALI.
OAUTH_WEB_DONUS=http://localhost:3000/giris/oauth
OAUTH_MOBIL_DONUS=com.app.yonetiyor://oauth
```

**CANLI** (`infra/.env.prod`):

```env
OAUTH_CALLBACK_TABAN=https://api.yonetio.site
OAUTH_WEB_DONUS=https://app.yonetio.site/giris/oauth
OAUTH_MOBIL_DONUS=com.app.yonetiyor://oauth
```

> `OAUTH_WEB_DONUS` neden `app.` (panel değil): kayıt ve sosyal giriş
> **tesis yüzeyindedir**; `panel.` yalnız platform admin'e açıktır
> (bkz. hafıza notu "app.* vs panel.*"). Yöneticiyi panel'e döndürmek
> onu göremeyeceği bir yüzeye düşürürdü.

`OAUTH_WEB_DONUS` boş bırakılırsa `POST /auth/oauth/baslat/{saglayici}`
**503** döner — hata kullanıcı siteden ayrılmadan görünür. Bu bilinçli:
yanlış yapılandırma, kullanıcı sağlayıcıdan döndükten sonra 404 olarak
karşısına çıkmamalı.

---

## 4b. DEĞİŞKENLERİ YAZMAK TEK BAŞINA YETMEZ — compose'a da geçmeli

> **(P155r2) ÖLÇÜLEN KUSUR.** Konsollar yapılandırıldı, değerler
> `.env.prod`a yazıldı ve `/auth/oauth/saglayicilar` yine **boş liste**
> döndü. Sebep: compose'da `env_file` **yok**; `environment:` blokları
> **açık beyaz listedir** ve adı orada geçmeyen değişken konteynere
> **ulaşmaz**. Hata sessizdi — hiçbir yerde uyarı çıkmıyor, sadece düğme
> çizilmiyor.
>
> **Düzeltildi:** tüm `OAUTH_*` değişkenleri hem `docker-compose.yml`
> hem `docker-compose.prod.yml` içindeki `api` servisine eklendi (hepsi
> `:-` ile opsiyonel). Bir daha sessizce kaymaması için kilit test:
> `backend/tests/test_compose_oauth.py` — `Settings`teki her `oauth_*`
> alanını kodun kendisinden okuyup iki compose dosyasında da arıyor.

**Değiştirdikten sonra konteyneri YENİDEN OLUŞTURUN.** Sadece `restart`
yetmez; `environment` yalnız kapsayıcı yaratılırken okunur:

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  up -d --force-recreate api
```

**worker/beat'e gerek YOK:** OAuth yalnız istek yolunda kullanılıyor
(`routers/oauth.py`); hiçbir Celery görevi ona dokunmuyor. Değişkenleri
oraya da geçirmek, sırları gereksiz bir sürece taşımak olurdu.

**admin-web'e de gerek YOK:** panel sağlayıcı listesini **kendi sunucu
tarafından** okuyor (`/api/auth/oauth/saglayicilar` → BFF → backend);
tarayıcı API'ye doğrudan gitmiyor ve admin-web'de hiçbir OAuth ortam
değişkeni yok. Yani yapılandırma **tek yerde**: api servisi.

---

## 5. DOĞRULAMA (yapılandırma sonrası)

```bash
# 1) Sağlayıcı açık mı?
curl -s http://localhost:8000/auth/oauth/saglayicilar
# {"saglayicilar":["google","microsoft","apple"]}

# 2) Yetkilendirme adresi üretiliyor mu?
curl -s -X POST http://localhost:8000/auth/oauth/baslat/google \
     -H 'Content-Type: application/json' -d '{"yuzey":"web"}'
# {"adres":"https://accounts.google.com/o/oauth2/v2/auth?...","state":"..."}
```

Adres dönüyorsa panelde ve mobilde düğmeler kendiliğinden belirir; ayrı
bir dağıtım gerekmez (liste her istekte okunur).

**`saglayicilar` boş dönüyorsa** sırayla bakın:

```bash
# 1) Değişken KONTEYNERE ulaşmış mı? (en sık kaçırılan adım)
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  exec api printenv | grep OAUTH_
# Boş çıktı => compose'un `environment` bloğunda eksik ya da konteyner
#              eski (`up -d --force-recreate api` koşun).

# 2) Değer var ama liste boş => `izinli_aud` boş demektir.
#    `hazir` özelliği hem CLIENT_ID hem aud listesi ister; aud boşken
#    CLIENT_ID'ye düşer, yani CLIENT_ID de boşsa sağlayıcı kapalıdır.
```

---

## 6. İLK GİRİŞTE NE OLUR

> **(P155r2) YÖNETİCİ İÇİN İSTİSNA:** yönetici *yeni bir tesis açıyorsa*
> aşağıdaki SMS adımı **yoktur** — `POST /auth/kayit/tesis-olustur`
> sağlayıcı kimliğiyle doğrudan tesis + hesap açar. Sebep: orada
> sahiplenilecek mevcut bir hesap yok, hesap o anda yaratılıyor ve numara
> boş olmak zorunda. Kanıtlanacak bir sahiplik yok. Aşağıdaki akış
> **var olan bir hesabı sahiplenme** durumu içindir.
>
> Sağlayıcıdan gelen **ad soyad** kayıt formuna otomatik dolar
> (Google/Microsoft `name` iddiası; **Apple vermez**, alan boş gelir).
> **Telefon hiçbir sağlayıcıdan gelmez** — kullanıcı doldurur.

Sosyal hesap **kimlik doğrulama yöntemidir, eşleşme anahtarı değil.**
Google "bu hesabın sahibisin" der; hangi tesiste kim olduğunuzu söylemez.
Bu yüzden ilk girişte:

1. Sağlayıcı doğrulanır,
2. Kullanıcıdan **tesis ID + telefon** istenir,
3. Telefona **SMS kodu** gider,
4. Kod doğrulanınca sosyal hesap **mevcut** kullanıcıya bağlanır ve
   oturum açılır.

SMS adımı atlanamaz: tesis kodu kamuya açıktır ve telefon numarası sır
değildir — ikisi birlikte bir kimlik kanıtı değildir. SMS olmasaydı,
birinin tesis kodunu ve numarasını bilen herkes kendi Google hesabını o
kişinin hesabına bağlayıp içeri girerdi.

Sonraki girişlerde tek tık yeter. Kullanıcı yöntemlerini **Profil →
Giriş yöntemlerim**'den ekleyip kaldırabilir; **son giriş yolu
kaldırılamaz** (parola, başka bir sosyal hesap ya da telefon kalmalı).

---

## 7. NELER SAKLANMIYOR

`oauth_kimlik` tablosunda **sağlayıcı jetonu yoktur** —
`access_token`/`refresh_token` ne dönülür ne yazılır. Kimliğe yalnız
giriş anında ihtiyaç var; sonrasını kendi JWT çiftimiz yürütür ve hiçbir
sağlayıcı API'si çağrılmıyor. Saklamak, sızması hâlinde kullanıcının
**Google hesabına** erişim veren, hiçbir işi olmayan bir sorumluluk
olurdu (KVKK "veri en az" ilkesi).

Sağlayıcının e-postası **yalnız görüntüleme** için tutulur; eşleşmede
kullanılmaz ve `app_user.email`i ezmez. Apple "e-postamı gizle" dediğinde
gelen `...@privaterelay.appleid.com` adresi kalıcı değildir; orayı
kullanıcının gerçek e-postasının üzerine yazmak veriyi yok ederdi.
