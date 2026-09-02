# App Store denetim notları (P115)

> App Store Connect → **App Review Information → Notes** alanına bu
> belgenin **"Denetçiye not"** bölümü (İngilizce) yapıştırılır. Belgenin
> geri kalanı bizim çalışma notumuzdur.

## 1. Demo hesapları

Tohumlama (**tekrar çalıştırılabilir** — aynı komut ikinci kez koşulabilir):

**PROD:**

```bash
cd infra && docker compose -f docker-compose.prod.yml --env-file .env.prod \
  run --rm -e DEMO_PAROLA='<parola>' worker python -m scripts.demo_tenant
```

**DEV** (aynı biçim, yalnız compose dosyası farklı):

```bash
docker compose -f infra/docker-compose.yml \
  run --rm -e DEMO_PAROLA='<parola>' worker python -m scripts.demo_tenant
```

> **`worker`, `api` DEĞİL.** Betik RLS'i bypass etmek için OWNER
> (superuser) bağlantısı ister; prod'da `OWNER_DSN` **yalnız**
> `migrate`/`worker`/`beat` servislerinde tanımlıdır — `api`ye superuser
> DSN'i **bilinçli olarak** verilmez. `scripts/create_admin.py` ile aynı
> sınır ve aynı komut biçimi.
>
> `exec` değil **`run --rm`**: `worker` uzun ömürlü bir süreçtir ve
> tohumlama tek seferlik bir iştir; `run --rm` kendi kabını açıp kapatır.
>
> **`DEMO_PAROLA` zorunludur, varsayılanı yoktur** (en az 8 karakter).
> Sabit bir varsayılan, internete açık bir tenant'ta herkesin bildiği bir
> demo hesabı bırakırdı — hem de tam olarak denetçiye verilen hesaplarda.
> Parolayı App Store Connect'in parola alanına da **aynen** girin.

> **Demo hesapları için TELEFON kullanın.** (P205) Mobil giriş ekranında
> artık **tek bir alan** var: *"E-posta veya telefon numarası"* — hangisi
> yazılırsa onunla giriş yapılır. Aşağıdaki tabloda **her ikisi de**
> listelidir; denetçi ikisinden birini kullanabilir, ama **telefon
> sütunu** ölçülmüş ve doğrulanmış olandır.
>
> Bu satır İLK TestFlight yapımında YANLIŞTI: not "e-posta + tesis kodu"
> diyordu ama ekranda öyle bir alan yoktu (yalnız telefon + parola).
> Denetçi giriş yapamazdı → kesin ret. **Tesis kodu hâlâ SORULMAZ**;
> yalnız aynı kimlik birden çok tesiste kayıtlıysa giriş sonrası bir
> tesis seçim penceresi çıkar (demo hesapları tek tesistedir, çıkmaz).

| Rol | Telefon (giriş) | E-posta (giriş — P205) | Ne görür |
|---|---|---|---|
| Yönetici | `05000000101` | `yonetici@demo.yonetio.site` | Tam yönetim: aidat, talepler, duyurular, tur planları, tanımlar |
| Yönetici 2 | `05000000106` | `yonetici2@demo.yonetio.site` | (P193) İkinci yönetici — **hesap silme testinin 409'a takılmaması için**: son yönetici kendini silemez, bkz. §8 |
| Güvenlik | `05000000102` | `guvenlik@demo.yonetio.site` | Devriye turları, ziyaretçi, olay bildirimi |
| Tesis görevlisi | `05000000103` | `gorevli@demo.yonetio.site` | Görevler, iş emirleri |
| Sakin | `05000000104` | `sakin@demo.yonetio.site` | Aidatım, talep aç, duyurular, rezervasyon |
| Güvenlik amiri | `05000000105` | `amir@demo.yonetio.site` | Dış güvenlik şirketi amiri: tur/vardiya, ihlal ve araç geçişi okuma, ekip yönetimi |

**Parola:** hepsi aynı — App Store Connect'in parola alanına Kerem
girer (`DEMO_PAROLA`). (Eskiden "dördü de aynı" yazıyordu; hesap sayısı
arttıkça bayatlayan bir sayıydı.)

> **Tabloda `denetci` rolü YOK ve bu bilinçli.** `demo_tenant.py` altıncı
> bir hesap daha açıyor (`+905777777777` / `denetci@demo.yonetio.site`,
> kilitli kural 2 gereği) ama o
> rolün **mobil yüzeyi yoktur** (kilitli kural 5): mobilde yalnızca web
> paneline yönlendiren bir ekran görür. Denetçiye o hesabı vermek, ona
> "boş" görünen bir ekran açtırmak ve uygulamayı bozuk göstermek olurdu.
> Hesap **yönetim paneli** içindir.

**Tesis kodu (`demo`) mobilde SORULMAZ:** telefon numarası global
benzersizdir, sunucu tesisi ondan çözer. Tesis kodu yalnız yönetim
panelinde (e-posta girişi) gerekir.

Numara üç biçimde de yazılabilir — `05000000101`, `5000000101`,
`+90 500 000 01 01` — sunucu E.164'e normalleştirir (uçtan uca
doğrulandı). Hesaplar kalıcı parolayla açıldığı için **ilk giriş / kod
adımı yoktur**; doğrudan uygulamaya girilir.

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
bakım, ortak giderler. Tutarları **tesis yönetimi** belirler; Yönetiyor
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

**Menü yolu:** Ana ekran → alt sekme **Ayarlar** → **Hesap** bölümü →
**Hesabımı sil** → onay ekranı → parola **veya** e-posta kodu → *Hesabımı
kalıcı olarak sil*.

**TUZAK — inceleme hesabı seçimi.** `POST /me/hesap-sil`, tesisin **son
yöneticisini** 409 ile reddeder ("önce devret"): tesisi sahipsiz
bırakmamak için doğru bir kural, ama incelemeci silmeyi o hesapla
denerse **çalışan bir özellik yüzünden ret** alırız. İki önlem:

1. Demo tesise **ikinci bir yönetici** eklendi (`05000000106`) — artık
   hangi hesapla denenirse denensin silme tamamlanır.
2. Aşağıdaki İngilizce notta incelemeciye **sakin hesabıyla** denemesi
   söyleniyor (yan etkisi en küçük olan).

**Silme sonrası demo veriyi geri getirmek:** `demo_tenant.py` yeniden
çalıştırılır (idempotent) — bkz. §1.

### App Store Connect → App Review Information → Notes (İNGİLİZCE)

Aşağıdaki metin doğrudan forma yapıştırılabilir:

```text
ACCOUNT DELETION (Guideline 5.1.1(v))

Account deletion is available inside the app, in three taps:

  1. Open the app and sign in (please use the RESIDENT demo account:
     phone 05000000104).
  2. Bottom navigation bar -> "Settings" (last tab).
  3. Scroll to the "Account" section -> tap "Delete my account".
  4. A confirmation sheet explains exactly what is deleted and what is
     kept. Confirm your identity:
       - if the account has a password: re-enter the password;
       - if it does not (residents can sign in without one): tap
         "No password - confirm with a code". We e-mail a six-digit,
         single-use code to the address on the account; enter it.
  5. Tap "Permanently delete my account". The session ends immediately
     and the credentials no longer work.

Re-authentication is required by design: an unlocked, borrowed phone
must not be enough to delete somebody's account with one tap.

WHAT IS DELETED
  Name, e-mail address, phone number, profile photo, password and
  one-time-code hashes, and all push/device records are deleted. Active
  unit-resident links are closed and the account is deactivated. The
  person can no longer sign in by any method.

WHAT IS KEPT, AND WHY
  If the account has financial or audit history, the underlying rows
  (dues assessments, payments, ledger entries, audit log) are NOT
  deleted - Turkish law (TTK art. 82 and tax legislation) requires the
  building's books to be retained, and deleting a payment would silently
  change the shared cash balance that OTHER residents rely on. Those
  rows are ANONYMISED instead: the identity fields are cleared and the
  record no longer points to a named person.

  If the account has no such history, the row is deleted outright. The
  app does not guess which case applies: it attempts a full delete first
  and falls back to anonymisation only when a foreign-key constraint
  proves history exists. The confirmation screen tells the user which of
  the two happened.

NOTE FOR THE REVIEWER
  A facility must always have at least one manager, so the LAST manager
  of a facility is asked to transfer management before deleting their own
  account (the app shows this message). This does not block deletion:
  the demo facility contains two manager accounts, and the resident
  account suggested above deletes without any precondition.

  Deleting the demo account is safe - we can restore the demo data at any
  time.

Details of the deletion/anonymisation rule are also published in our
privacy policy: https://app.yonetiyor.com/gizlilik
```

## 9. Bağlantılar

Formlara **doğrudan 200 dönen** adresler yazılır. Eski adresler çalışmaya
devam ediyor ama **iki 301 üzerinden** gidiyor
(`yonetio.site/gizlilik` → `yonetiyor.com/gizlilik` → `app.yonetiyor.com/gizlilik`);
bir doğrulayıcı yönlendirme zincirini izlemezse gereksiz yere "erişilemiyor"
der. Ölçüldü (2026-08-31):

| Adres | Yanıt |
|---|---|
| `https://app.yonetiyor.com/gizlilik` | **200** ← forma bunu yazın |
| `https://yonetiyor.com/gizlilik` | 301 |
| `https://yonetio.site/gizlilik` | 301 |

* Gizlilik politikası: **https://app.yonetiyor.com/gizlilik**
* Kullanım koşulları: **https://app.yonetiyor.com/kosullar**
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
DEMO ACCOUNTS - SIGN IN WITH PHONE NUMBER (not e-mail)
The app's sign-in screen asks for a phone number and a password. The site
code is NOT required on mobile: phone numbers are globally unique and the
server resolves the site from them.

Manager:  0500 000 01 01
Security: 0500 000 01 02
Staff:    0500 000 01 03
Resident: 0500 000 01 04
Password: <see App Store Connect password field> (same for all four)

Any of these formats is accepted: 05000000101 / 5000000101 /
+90 500 000 01 01. There is no first-time-code step; these accounts sign
in directly.

Yönetiyor is a B2B property-management app for apartment buildings and
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
shared costs), set and collected by the site management. Yönetiyor does not
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
Settings (last tab) -> "Account" -> "Delete my account". Confirm with the
account password, or - for accounts without one - with a single-use code
we e-mail to the address on file. Personal data (name, e-mail, phone,
photo, credentials, device/push records) is deleted; dues and audit
records we are legally required to keep remain stored with the link to
the person's identity removed. Please test with the RESIDENT demo account
(05000000104). Full text in the App Review Notes above.

Privacy policy: https://app.yonetiyor.com/gizlilik
Terms of use:   https://app.yonetiyor.com/kosullar
Support:        destek@yonetio.site
```
