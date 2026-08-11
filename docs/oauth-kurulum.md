# Sosyal Giriş — Konsol Kurulumu (P154 / Aşama 4)

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

---

## 1. GOOGLE (Google Cloud Console)

1. <https://console.cloud.google.com> → proje seç/oluştur.
2. **APIs & Services → OAuth consent screen**
   - User type: **External**
   - Uygulama adı: `Yönetio`, destek e-postası, geliştirici e-postası
   - **Scopes:** `openid`, `.../auth/userinfo.email` — `profile` isteğe
     bağlı. Başka kapsam **istemeyin**: kullanmadığımız her kapsam
     doğrulama sürecini uzatır.
   - Yayına almadan önce **Test users** listesine testçileri ekleyin.
3. **APIs & Services → Credentials → Create credentials → OAuth client ID**
   - Application type: **Web application**
   - Name: `Yonetio TEST` (canlı için ayrı: `Yonetio PROD`)
   - **Authorized redirect URIs** — tam olarak:
     - test: `https://api.test.yonetiyor.com/auth/oauth/callback/google`
     - canlı: `https://api.yonetiyor.com/auth/oauth/callback/google`
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
     `https://api.test.yonetiyor.com/auth/oauth/callback/microsoft`
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
     - **Domains and Subdomains:** `api.test.yonetiyor.com`
     - **Return URLs:** `https://api.test.yonetiyor.com/auth/oauth/callback/apple`
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

```env
# Sağlayıcıya bildirilen redirect_uri'nin tabanı. TERS VEKİL ARKASINDA
# ZORUNLU: istekten türetilen adres (iç konak, http, farklı port) kayıtlı
# adresle tutmaz ve giriş "redirect_uri mismatch" ile patlar.
OAUTH_CALLBACK_TABAN=https://api.test.yonetiyor.com

# Callback sonrası tarayıcının gönderileceği yerler. BOŞ = O YÜZEY KAPALI.
OAUTH_WEB_DONUS=https://panel.test.yonetiyor.com/giris/oauth
OAUTH_MOBIL_DONUS=com.app.yonetiyor://oauth
```

`OAUTH_WEB_DONUS` boş bırakılırsa `POST /auth/oauth/baslat/{saglayici}`
**503** döner — hata kullanıcı siteden ayrılmadan görünür. Bu bilinçli:
yanlış yapılandırma, kullanıcı sağlayıcıdan döndükten sonra 404 olarak
karşısına çıkmamalı.

---

## 5. DOĞRULAMA (yapılandırma sonrası)

```bash
# 1) Sağlayıcı açık mı?
curl -s https://api.test.yonetiyor.com/auth/oauth/saglayicilar
# {"saglayicilar":["google","microsoft","apple"]}

# 2) Yetkilendirme adresi üretiliyor mu?
curl -s -X POST https://api.test.yonetiyor.com/auth/oauth/baslat/google \
     -H 'Content-Type: application/json' -d '{"yuzey":"web"}'
# {"adres":"https://accounts.google.com/o/oauth2/v2/auth?...","state":"..."}
```

Adres dönüyorsa panelde ve mobilde düğmeler kendiliğinden belirir; ayrı
bir dağıtım gerekmez (liste her istekte okunur).

---

## 6. İLK GİRİŞTE NE OLUR

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
