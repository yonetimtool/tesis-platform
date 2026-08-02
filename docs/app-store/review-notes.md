# App Store denetim notları (P115)

> App Store Connect → **App Review Information → Notes** alanına bu
> belgenin **"Denetçiye not"** bölümü (İngilizce) yapıştırılır. Belgenin
> geri kalanı bizim çalışma notumuzdur.

## 1. Demo hesapları

Tohumlama (prod'a benzer veriyle, **tekrar çalıştırılabilir**):

```bash
docker compose exec -e DEMO_PAROLA='<parola>' api python -m scripts.demo_tenant
```

| Rol | E-posta | Ne görür |
|---|---|---|
| Yönetici | `yonetici@demo.yonetio.site` | Tam yönetim: aidat, talepler, duyurular, tur planları, tanımlar |
| Güvenlik | `guvenlik@demo.yonetio.site` | Devriye turları, ziyaretçi, olay bildirimi |
| Tesis görevlisi | `gorevli@demo.yonetio.site` | Görevler, iş emirleri |
| Sakin | `sakin@demo.yonetio.site` | Aidatım, talep aç, duyurular, rezervasyon |

**Tesis kodu (tenant):** `demo` · **Parola:** App Store Connect'e Kerem
girer (`DEMO_PAROLA`).

Girişte **telefon** ya da **e-posta + tesis kodu** kullanılabilir; demo
hesapları e-posta ile girer.

## 2. NFC — donanımsız nasıl denenir

Uygulamanın omurgası **devriye turu**dur ve sahada NFC etiketi okutularak
çalışır. Denetçinin elinde bizim etiketimiz olamayacağı için **demo
tesisine özel** bir "simüle okutma" yolu açtık.

* Güvenlik hesabıyla girin → **Turlarım** → bir tur noktası seçin →
  **"Simüle okutma"**.
* Bu düğme **yalnız demo tesisinde** görünür; gerçek bir tesiste sunucu
  bu ucu **404** döndürür (`tenant.demo_mod`).
* Kayıt `imza_dogrulandi = false` olarak düşer; yani simüle okutma
  gerçeğinden **ayırt edilebilir** kalır.

**Fiziksel NFC:** iPhone 7 ve üstü gerekir. Gerçek etiketler NTAG424 SDM
imzası taşır ve sunucuda doğrulanır (tekrar-oynatma koruması dâhil).

## 3. İzinler nerede ve niçin isteniyor

| İzin | Ne zaman sorulur | Niçin |
|---|---|---|
| NFC | Tur noktası okutulurken | Etiketi okumak; turun gerçekten yürüdüğünün kanıtı |
| Kamera | Fotoğraf eklerken | Görev/talep/etkinlik/kargo/site kuralı fotoğrafı |
| Fotoğraf kitaplığı | Galeriden seçerken | Aynı akışlar için mevcut fotoğraf |
| Konum (kullanırken) | Tur okutması / acil bildirim | Olayın **nerede** olduğunu kaydetmek |

**Konum arka planda toplanmaz.** İzin reddedilse bile okutma kaydedilir;
kayıt "konum yok" nedenini taşır. Uygulama kullanıcıyı izlemez.

## 4. Ödeme modeli — 3.1.3(e), uygulama içi satın alma YOK

Uygulamada görünen **aidat** tutarları, uygulama **dışında** tüketilen
gerçek dünya hizmetlerinin bedelidir: bina yönetimi, temizlik, güvenlik,
bakım, ortak giderler. Tutarları **tesis yönetimi** belirler; Yönetio
bunları belirlemez, tahsil etmez ve bunlardan pay almaz — yalnız kaydını
tutar.

Bu nedenle **Guideline 3.1.3(e)** kapsamındayız ve uygulama içi satın
alma kullanılmaz. Uygulamada dijital içerik/özellik satışı **yoktur**.
Kartla ödeme özelliği şu an **etkin değildir**.

## 5. Uzaktan kod çalıştırma yok — 2.5.2

Uygulama Flutter ile derlenmiştir. **Uzaktan indirilen kod
çalıştırılmaz**: JavaScript motoru, dinamik kod yükleme, uzaktan
güncellenen betik ya da özellik bayrağıyla açılan gizli işlev yoktur.
Sunucudan gelen tek şey **veridir** (JSON) ve ekranlar uygulamanın
içindeki kodla çizilir.

## 6. Yapay zekâ ve otomatik çeviri

* **Üretken yapay zekâ kullanılmıyor.** Metin/görsel üreten hiçbir model
  yok; kullanıcıya "yapay zekâ ürettiği" bir içerik sunulmuyor.
* Tek otomatik işlem **makine çevirisidir** (duyuru, site kuralı,
  etkinlik metinleri) ve **kendi sunucumuzdaki LibreTranslate** ile
  yapılır — metin üçüncü bir şirkete gitmez.
* Otomatik çevrilen her içerik **"Bu içerik otomatik çevrilmiştir"**
  notunu ve **"Orijinali gör"** seçeneğini taşır. Bağlayıcı metin her
  zaman orijinaldir.

## 7. Sign in with Apple — 4.8 GEÇERSİZ (N/A)

Uygulama **üçüncü taraf sosyal giriş sunmuyor**: Google, Facebook, X ya
da benzeri bir giriş seçeneği yok. Hesaplar **tesis yönetimi tarafından**
açılır ve kullanıcı telefon/e-posta + parola ile girer. Guideline 4.8
yalnızca üçüncü taraf giriş **sunan** uygulamaları bağlar.

## 8. Hesap silme — 5.1.1(v)

**Ayarlar → Hesabımı sil.** Onay + parola doğrulaması ister; hesabı
uygulama içinde siler. Kişisel veriler silinir/anonimleştirilir; yasal
saklama yükümlülüğü olan aidat ve denetim kayıtları **kimlikle bağlantısı
kesilerek** kalır. Ayrıntı: `docs/hesap-silme-kvkk.md` ve `/gizlilik`.

## 9. Bağlantılar

* Gizlilik politikası: **https://yonetio.site/gizlilik**
* Kullanım koşulları: **https://yonetio.site/kosullar**
* Destek: **destek@yonetio.site**

## 10. Bilinen sınır — düz HTTP medya istisnası

`Info.plist` içinde `NSAllowsArbitraryLoadsForMedia` bulunur. Gerekçesi:
sahadaki IP kameraların yerel ağdaki restream geçidi (Frigate/go2rtc)
neredeyse her zaman düz HTTP'dir. İstisna **yalnızca AVFoundation medya
yüklemelerini** kapsar; API trafiği (URLSession) ATS korumasında kalır ve
HTTPS zorunludur. Genel `NSAllowsArbitraryLoads` **kullanılmamaktadır**.

---

# Denetçiye not (İngilizce — App Store Connect'e yapıştırılacak)

```
DEMO ACCOUNT
Site code (tenant): demo
Manager:  yonetici@demo.yonetio.site
Security: guvenlik@demo.yonetio.site
Staff:    gorevli@demo.yonetio.site
Resident: sakin@demo.yonetio.site
Password: <see App Store Connect password field>

Yönetio is a B2B property-management app for apartment buildings and
gated communities. Accounts are created by the site management; there is
no public sign-up.

NFC WITHOUT HARDWARE
The core feature is a security patrol that is normally performed by
scanning NFC tags on site. Because you cannot have our physical tags, the
demo site has a "simulated scan" path: sign in as Security -> My Patrols
-> pick a checkpoint -> "Simulated scan". This path is enabled ONLY for
the demo site (server-side tenant flag) and the resulting record is
marked as unsigned, so it is distinguishable from a real scan. Physical
NFC requires iPhone 7 or later.

PERMISSIONS
- NFC: reading checkpoint tags during a patrol.
- Camera / Photo Library: photos the user attaches to tasks, maintenance
  requests, events, parcels and site rules.
- Location (When In Use): recorded as evidence at the moment of a patrol
  scan or an emergency alert. Never collected in the background.

PAYMENTS - 3.1.3(e), NO IAP
Amounts shown in the app are dues for real-world services consumed
outside the app (building management, cleaning, security, maintenance,
shared costs), set and collected by the site management. Yönetio does not
set, collect or take a share of them; it only keeps the record. No
digital goods or features are sold in the app. Card payment is currently
disabled.

NO REMOTE CODE EXECUTION - 2.5.2
The app is compiled with Flutter. It does not download or execute remote
code: no JavaScript engine, no dynamic code loading, no remotely toggled
hidden functionality. The server returns data (JSON) only.

AI / AUTOMATIC TRANSLATION
No generative AI is used. The only automated processing is machine
translation of announcements, site rules and event texts, running on our
own server (self-hosted LibreTranslate); text is not sent to any third
party. Every translated item shows "This content has been translated
automatically" with a "View original" option.

SIGN IN WITH APPLE - 4.8 NOT APPLICABLE
The app offers no third-party social login (no Google/Facebook/X sign-in),
so Guideline 4.8 does not apply.

ACCOUNT DELETION - 5.1.1(v)
Settings -> Delete my account. Requires confirmation and re-entering the
password. Personal data is deleted or anonymised; dues and audit records
we are legally required to keep remain stored with the link to the
person's identity removed. Details: https://yonetio.site/gizlilik

Privacy policy: https://yonetio.site/gizlilik
Terms of use:   https://yonetio.site/kosullar
Support:        destek@yonetio.site
```
