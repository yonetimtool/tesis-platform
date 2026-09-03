# P211 — Yönetici girişi, panel yönlendirme, tahsilat, mesai ücreti, iOS bildirim, ikon

> **Numara notu.** Bu turu sen "P210" diye adlandırdın, ama `docs/P210-kararlar.md`
> zaten **ses dosyaları turunun** kararlarını tutuyor (üçüncü kanal + `_v2` geçişi).
> Var olan belgeyi ezmemek için bu tur **P211** numarasıyla yazıldı; koddaki
> yorum etiketleri de `(P211 §n)` biçiminde. Aynı işin iki adı olmasın diye
> not düşüyorum.

---

## §1 — Yönetici girişi: SSO düğmeleri ve "Tesis ID" sorusu

### ÖLÇÜM 1 — SSO düğmeleri mobilde neden görünmüyor?

**Kod kusuru değil, yapılandırma.** Ölçüm:

```
$ curl -s api:8000/auth/oauth/saglayicilar
{"saglayicilar":[]}
```

`app/oauth.py::Saglayici.hazir` bir sağlayıcıyı ancak `istemci_id` **ve**
`izinli_aud` doluysa "hazır" sayar; uç yalnızca hazır olanları listeler.
Bu geliştirme makinesinde `infra/.env` içinde **hiçbir** OAuth değişkeni
yok (`.env.example`'da hepsi yorum satırı). Mobil `SosyalGirisDugmeleri`
liste boşsa **hiç çizilmez** — tasarım gereği: yapılandırılmamış bir
düğmeye basmak kullanıcıyı sağlayıcının hata sayfasına atardı.

**Sonuç:** düğmelerin görünmesi için sunucuda şu değişkenler dolu olmalı
(prod `.env`'ini ben göremiyorum, ölçemediğim kısım bu):

| Değişken | Ne | Zorunlu mu |
|---|---|---|
| `OAUTH_GOOGLE_CLIENT_ID` | Google **Web** client id | Google için evet |
| `OAUTH_GOOGLE_CLIENT_SECRET` | aynı client'ın sırrı | evet |
| `OAUTH_GOOGLE_AUD` | virgüllü ek `aud` listesi (mobil client id'leri) | Google mobilde de kullanılacaksa |
| `OAUTH_APPLE_CLIENT_ID` | Services ID (`com.app.yonetiyor.web`) | Apple için evet |
| `OAUTH_APPLE_TEAM_ID` / `OAUTH_APPLE_KEY_ID` / `OAUTH_APPLE_PRIVATE_KEY` | client_secret JWT'si için | evet |
| `OAUTH_APPLE_AUD` | web Services ID + iOS bundle id | iOS'ta Apple ile giriş için |
| `OAUTH_MICROSOFT_CLIENT_ID` / `_SECRET` | Microsoft | isteğe bağlı |
| `OAUTH_CALLBACK_TABAN` | `https://api.yonetiyor.com` | evet |

Testle kilitlenen kısım: sağlayıcı listesi **doluyken** düğmelerin
gerçekten çizildiği (`p211_sso_tesis_secimi_test.dart`, 1. test) — yani
"liste dolduğunda arayüz tarafında bir kusur kalmadı" ölçülmüş oldu.

### ÖLÇÜM 2 — "Tesis ID" neden soruluyordu?

Kırılma noktası **backend**'de, `oauth.py::_eslesme`: doğrulanmış e-posta
ile eşleşen yönetici satırı **birden fazlaysa** akış "tekil değil" sayılıp
`baglama_gerekli` dönüyordu; hem web hem mobil bu duruma **Tesis ID formu**
çiziyordu. Yani kodu hiç ezberlemeyen, en çok tesisi olan kişiden
ezberlemesini istiyorduk. Tek tesisli yöneticide akış zaten doğruydu
(`mevcut_hesap`/`giris`).

### KARAR K1 — Çok tesiste `tesis_secimi`, Tesis ID **sorulmaz**

`/auth/oauth/sonuc` artık `durum="tesis_secimi"` + `secim_jetonu` +
tesis **adları** döner. Yeni uç: `POST /auth/oauth/tesis-sec`.

**Gerekçe ve güvenlik sınırı:** `secim_jetonu` yetki **vermez**, yalnız
"şu doğrulanmış adres şu tesislerde yöneticidir" bilgisini taşır ve
`getdel` ile **tek kullanımlıktır**. İstekteki `tenant_id` jetondaki aday
listesinde olmak **zorundadır**; olmazsa 403 `tesis_uyeligi_yok` — aksi
hâlde uç "istediğim tesisin jetonunu al" ucuna dönüşürdü. Ret mesajı
"böyle tesis yok" ile "üye değilsin" arasını **ayırt ettirmez** (P203 §2
`tesis-degistir` ile aynı kural).

Seçimden sonra kimlik o tesise **bağlanır** (`_kimligi_bagla`), böylece
bir sonraki girişte seçim sorulmaz.

### Kapsam
- Backend: `oauth.py` (+7 test), şema, openapi, rol-matrisi.
- Mobil: seçim ekranı — `sso-tesis-secimi` (+4 test).
- Web: `/giris/oauth` `tesis_secimi` dalı + BFF `/api/auth/oauth/tesis-sec`
  (+4 test). Jetonlar gövdede geçmez, httpOnly çereze yazılır.

### Ölçemediğim
Gerçek Google/Apple ile uçtan uca giriş: dev'de sağlayıcı yapılandırması
yok (yukarıdaki tablo). Taklit HTTP katmanına konuldu (P200 dersi);
sağlayıcıdan dönen `sonuc_id` sonrası **tüm** akış gerçek kodla sürüldü.

---

## §2 — `panel.yonetiyor.com`a düşen yönetici: mesaj değil, köprü

### ÖLÇÜM
Kırılma noktası **giriş ucunda**, `admin-web/lib/oturum-kapisi.ts` (ve o
sırada kuralı **kopyalayan** iki rota): `panel.*` yüzeyinde tesis rolü
`403` + "panel platform içindir" mesajı alıyordu. Kapı doğruydu —
**eksik olan çıkış yoluydu**: kullanıcıya gideceği adres söylenmiyordu.

Doğrudan gezinme tarafı (oturumu olan yöneticinin `panel.*`ta bir sayfa
açması) **zaten** P190 §1'de 307 ile `app.*`a taşınıyor ve P191 §1'de
portsuzluğu kilitlenmiş; `tests/middleware.test.ts` bunu ölçüyor. Yani §2'de
kalan tek boşluk giriş anıydı.

### KARAR K2 — Oturum açılır ve `yonlendir` adresi verilir

`oturumAc` artık: rol `app.*`a girebiliyorsa **oturumu açar** (çerezler
`COOKIE_DOMAIN=.yonetiyor.com` ile üst alan adına yazılır) ve gövdede
`yonlendir` ile **mutlak** `app.*` adresini döner; form `window.location`
ile oraya gider (`router.replace` konak-ötesi gidemez).

**Neden 403 + mesaj değil:** kullanıcı doğru paroladır, doğru kişidir,
yalnızca yanlış kapıdadır. Onu geri çevirmek yerine taşımak, ikinci bir
giriş de gerektirmiyor.

**Neden `router.replace` değil, tam adres:** hedef başka konaktır. Adres
**sunucuda** üretilir (`NEXT_PUBLIC_APP_ADRESI` → iletilmiş başlıklar),
böylece Next'in iç dinleme portu (`:3000`) adrese sızmaz — P201'de ölçülen
kusurun aynısı.

**Neden çerez alan adı şartı:** `COOKIE_DOMAIN` boşsa çerez konak-özel
kalır; köprü kurulsaydı kullanıcı `app.*`a varır varmaz `/login`e düşerdi —
mesajda kalmaktan **daha kötü**. O durumda eski 403 davranışı aynen kalır
(dev/yerel de böyle).

**Yan düzeltme:** kapı iki giriş rotasında kopyalanmıştı (P129'da bu sınıf
zaten bir kez ölçülmüştü). Tek yere alındı; kilit testleri de "rotada metin
ara" yerine "kapıyı çağırıyor mu" ölçer.

### Ölçemediğim
Gerçek `panel.yonetiyor.com` üzerinden uçtan uca akış: prod'a erişimim yok.
Ölçülen kısım, gerçek `NextRequest`lerle giriş ucunun döndürdüğü yanıt
(7 test: adres, portsuzluk, çerez alan adı şartı, admin/gerileme durumları).

---

## §3 — `POST /dues/payments` 500'leri: kök neden ve "500 değil 422"

### ÖLÇÜM (uçtan uca gerçek istekler; taklit YOK)
Uca 20+ gövde varyantı gönderildi. **İki gerçek 500 üretildi** ve api
günlüğünden kök nedenleri okundu:

| Girdi | Sonuç (önce) | Kök neden |
|---|---|---|
| `tutar_kurus = 10^19` | **500** | `bigint` (int64) taştı — asyncpg `DataError: value out of int64 range`. Doğrulama katmanı üst sınır tanımıyordu; hata **sürücüde** patlıyordu. |
| `odeme_zamani = 9999-12-31` | **500** | `belge_no_uret` → `ck_belge_sayaci_yil` (2000-2200, göç 0058) `CheckViolationError`. |

Ayrıca **iki mesaj yanlış şeyi anlatıyordu** (500 değil ama aynı sınıf hata):

| Girdi | Sonuç (önce) | Sorun |
|---|---|---|
| var olmayan `kasa_id` | 409 "İlişkili kayıt nedeniyle işlem yapılamıyor" | FK ihlali genel çeviriye düşüyordu. |
| aynı `makbuz_no` ikinci kez | 409 "Aynı Idempotency-Key farklı gövde ile gönderildi" | İhlal `uq_hareket_belge_no`ydu; kullanıcı anahtarı değiştirse de aynı cümleyi alırdı. |

### KARARLAR

**K3.1 — Para alanlarına üst sınır: `KURUS_UST_SINIR = 10^15` kuruş
(10 trilyon TL).** Şemada, yani veritabanına inmeden. int64'ün çok
altında **bilinçli**: gerçek bir aidat/gider bu sayıya yaklaşmaz,
yaklaşan bir değer kullanıcı hatasıdır. Sınır `dues_payment`a özel
değil — `_kurus` biten **tüm** para giriş alanlarına uygulandı (14 alan),
çünkü taşma tipin özelliği, ucun değil.

**K3.2 — Yıl aralığı denetimi `belge_no_uret` içinde, TEK YERDE.**
Uç bazında yazsaydık tahsilat düzelir, gider/virman/iade/karar defteri
aynı 500'ü vermeye devam ederdi; hepsi aynı seriden numara alıyor.
Mesaj hangi yılı ve hangi aralığı reddettiğini **söyler**.

**K3.3 — `kasa_id` varlığı önceden doğrulanır** → 422 `invalid_reference`
("Kasa bulunamadı"), FK ihlaline bırakılmaz.

**K3.4 — Unique ihlalinde KISIT ADINA bakılır** (`kisit_adi` yardımcısı).
`uq_hareket_belge_no` → 409 "Bu belge numarası (X) zaten kullanılmış".
Idempotency dalı kendi mesajını korur (gerileme testiyle kilitli).

### Kilit
7 test (`test_p211_tahsilat_500.py`), hepsi canlı uca gider. Dördü de
**kırma denemesiyle** doğrulandı: dört koruma tek tek devre dışı
bırakıldığında tam olarak beklenen 5 test düştü, geri alınca 7'si geçti.

### Ölçemediğim / açık madde
Senin gördüğün 500'ün **bu ikisinden hangisi** olduğunu bilmiyorum: elimde
o isteğin gövdesi ya da prod günlüğü yok. İkisi de kapandı; hâlâ 500
alıyorsan bana isteğin gövdesini ya da o ana ait api günlüğünü ver.
Bir gözlem daha: `donem` alanı **serbest metin** kabul ediyor ("Ağustos
2026", 500 karakter) — 500 üretmiyor ama rapor kırılımını sessizce bozar;
bu turda kapsam dışı bıraktım, ayrı bir madde olarak duruyor.

---

## §4 — Tahsilatta daire → kişi

### ÖLÇÜM
- **Web** (`finans/tahsilatlar`): P206 §2 **ters yönü** kurmuştu (borçlu
  seçilince daire dolar). Daireden kişiye giden yön **yoktu**; yönetici
  daireyi seçtikten sonra doğru kişiyi yüzlerce ad arasından kendisi
  buluyordu.
- **Mobil** (`tahsilat_screen`): seçim zaten satır bazlıydı — bir satır
  = **daire + borçlu**, yani kişi daireyle birlikte geliyordu. Eksik olan
  şey **aynı dairedeki başka birine** makbuz kesebilmekti.
- Backend'de **yeni uç gerekmedi**: `GET /units/{id}/residents` (adıyla)
  ve `GET /units/by-no/{no}/residents` (kısa) zaten var.

### KARAR K4 — Otomatik gelir, ama KİLİT DEĞİL

| Durum | Davranış |
|---|---|
| Dairede **tek** sakin | Kişi **kendiliğinden** seçilir (mobilde zaten öyleydi; seçici hiç çizilmez) |
| Dairede **çok** sakin | Web'de kişi seçici **o daireye süzülür**, otomatik seçim yapılmaz; mobilde "Ödeyen kişi" listesi çıkar (varsayılan borçlunun kendisi) |
| Dairede **sakin yok** | Web'de bilgilendirme metni yazılır, süzgeç uygulanmaz; mobilde seçici çizilmez |

**"Kullanıcı yine de başka birini seçebilmeli mi?" → EVET.** Ödeyen her
zaman sakin değildir: kiracı adına ev sahibi öder, aile bireyi kapıya
gelir, muhasebeci getirir. Süzgeci kilit yapmak, bu tamamen normal işlemi
imkânsız kılardı. Ama süzgeci kaldırmak **açık bir seçimdir** ("Bu
bağımsız bölüm dışından biri ödüyor" kutusu) — kazara olmaz.

**Neden çok sakinde sistem seçmiyor:** iki kişiden birini seçmek, yanlış
kişiye makbuz kesme riskini "kolaylık" adına bedavaya eklemek olurdu.
Tek sakinde belirsizlik yok, orada sormak gereksiz dokunuş.

**Yan düzeltme:** `useDaireSakinleri` gelen veri dizi değilse (uç hata
zarfı döndüğünde) boş sayar. Önceki hâlinde `.filter` patlıyor ve
**tahsilat penceresi hiç çizilmiyordu** — bir liste hatası yüzünden formu
kaybetmek kabul edilemez. Mobilde aynı ilke: sakin listesi hata verirse
seçici çizilmez, tahsilat borçlunun adına kaydedilir.

### Kilit
Web 5 DOM testi (taklit HTTP katmanında), mobil 5 widget testi (taklit
HTTP adapter'ında). İkisi de gönderilen **gövdeyi** ölçer.

---

## §5 — Fazla mesai ücreti: ne vardı, ne eksikti

### ÖLÇÜM — P203 §5'ten geriye kalan tek boşluk
Beklediğimden çoğu **zaten yapılmıştı** (P203 §5, göç 0094):

| İstenen | Durum |
|---|---|
| Personel başına **saatlik/aylık** ücret | **VAR** — `personel_kayit.maas_kurus` + `saatlik_ucret_kurus`; saatlik boşsa `maas/225` (30 gün × 7,5 saat) |
| Mesai çarpanı, varsayılan 1,5 | **VAR** — `tenant.mesai_katsayisi`, varsayılan `1.50` (4857/41) |
| "değiştirilebilir" | **YOKTU** — sütun vardı, onu yazan **hiçbir uç yoktu**. P203'ün kendi testi bile katsayıyı `UPDATE tenant …` ile değiştiriyordu. Söz ancak SQL ile tutuluyordu. |
| Ücret hassas: yalnız yönetici, **sunucuda** zorlanmış | **VAR** — `personel-kayitlari` uçları `require_role("admin","yonetici")`; denetçi ücret yazamaz |
| Mesai gideri **onay bekleyen** olarak `finansal_hareket`e, ayrı tablo yok | **VAR** — `/mesai/gidere-yaz`, `tip='gider'`, `durum='onay_bekliyor'` |

### KARAR K5.1 — `GET/PATCH /mesai/ayar`
Katsayı uçtan değiştirilebilir; **yazma** admin + yönetici, **okuma**
denetçiye de açık. Sınır **1,0 – 5,0**: yasal taban 1,50, toplu iş
sözleşmesi yükseltebilir; üst sınır ise yazım hatasını keser — yanlışlıkla
girilen "150" bir maaşı 150 katına çıkarır ve o sayı **onay bekleyen bir
gidere** dönüşürdü. **Geçmişe dokunmaz**: yalnız henüz yazılmamış hesapta
kullanılır (`gecikme_aylik_yuzde` ile aynı ilke).

### KARAR K5.2 — Hafta sonu/tatil çarpanı: **BU TURDA YOK**, gerekçesiyle
Değerlendirdim; eklemedim. Üç sebep:

1. **Hukuken ayrı bir "saatlik çarpan" değil.** 4857 md. 41 fazla çalışmayı
   **haftalık 45 saat** eşiğine bağlar — günün hangi gün olduğuna değil.
   Ulusal bayram/genel tatil çalışması (md. 47) ise **günlük** bir kuraldır
   (o günün ücreti + çalışılan gün için bir yevmiye daha), saatlik bir
   katsayı değil. Onu "1,5 yerine 2,0" diye modellemek yanlış olurdu.
2. **Tatil takvimi yok.** Resmî tatiller yıllara göre değişir (dinî
   bayramlar kayar) ve sistemde bir tatil takvimi tablosu **yok**. Hangi
   günün tatil olduğunu bilmeden "tatil çarpanı" uygulamak, çarpanı
   rastgele günlere uygulamak demek.
3. **Çarpan bir TAHMİNİ çarpardı** (aşağıdaki kısıt).

Yapılacaksa doğru sıra: (a) resmî tatil takvimi tablosu (yıl bazlı,
elle düzenlenebilir), (b) md. 47 kuralının **günlük** modellenmesi,
(c) ancak ondan sonra hesaba katılması. Bu, kendi başına bir tur.

### P203 KISITI — hâlâ geçerli, tekrar yazıyorum
**Sistemde gerçek mesai kaydı YOK.** Hesap **planlanan** vardiya saatleri
üzerinden yapılır; yanıt bunu `kaynak: "plan"` ile açıkça söyler ve ekran
da yazar. Yönetici gidere yazarken saati **düzeltebilir**.

**Çözüm görüşüm (bu turda uygulanmadı):** doğru kaynak, personelin
**vardiya başlangıcında ve bitişinde** kimlik doğrulamalı bir kayıt
bırakmasıdır. Sırasıyla, maliyetten faydaya:

1. **Mobilden "vardiyaya başla / bitir"** (en ucuz, bugünkü altyapı yeter):
   görevli zaten uygulamada; iki dokunuş + sunucu saati. Zayıflığı: kişi
   evden de basabilir.
2. **Konum/QR ile doğrulanmış giriş-çıkış**: devriye noktası okutma
   altyapısı (`scan_event`) **zaten var**; vardiya başı/sonu için özel bir
   nokta okutulur. Zayıflığı: telefon el değiştirebilir.
3. **Turnike/PDKS entegrasyonu**: en güvenilir, en pahalı; ancak sitede
   böyle bir cihaz varsa anlamlı.

Öneri: **(1) + (2)** birlikte — "başla/bitir" kaydı, mümkünse noktaya
okutmayla doğrulanır; doğrulanmamış kayıtlar özet ekranında **işaretlenir**.
Böylece plan ile gerçekleşen **yan yana** görünür ve fark ödemeden önce
göze çarpar. Devriye okutmalarından mesai **çıkarımı yapmak** ise yanlış
olurdu: gelmiş birini eksik, gelmemiş birini tam gösterebilirdi ve o sayı
doğrudan **paraya** dönüşüyor.

### Kilit
Backend 5 test (yönetici yazar, özet yeni katsayıyı kullanır, denetçi
yazamaz, sınır dışı 422, tesis izolasyonu) + web 4 DOM testi (PATCH gövdesi,
virgüllü giriş, kapsam notu, iptalde istek gitmez). openapi + rol matrisi
güncel. Ayrıca §1'in kaçırdığı bir kilit kaydı da burada kapatıldı:
`/auth/oauth/tesis-sec` "rol kapısı olmayan mutasyon uçları" kümesine
gerekçesiyle eklendi.

---

## §6 — iOS'ta bildirim gelmiyor: zincirin nerede koptuğu

### ÖLÇÜM — zinciri baştan sona, halka halka

| Halka | Durum | Not |
|---|---|---|
| Backend FCM v1 gönderimi | ✅ | `app/push.py`, tek token/istek, hata kodlarına göre budama |
| iOS `aps.sound` gövdede | ✅ | `.caf` **uzantısıyla** gönderiliyor (`ses_adi`) — doğru |
| `.caf` dosyaları pakette | ✅ | üçü de `ios/Runner/` altında (Xcode target'a eklemeyi sen yapacaksın) |
| `GoogleService-Info.plist` | ✅ | `site.yonetio.app` — Runner'ın paket kimliğiyle aynı |
| İzin isteme + jeton kaydı (Dart) | ✅ | `push_registrar` ilk oturumda ister, `platform: "ios"` gönderir |
| **`aps-environment` entitlement** | ❌ **YOKTU** | **Birincil sebep** |
| **Push Notifications capability** | ❌ **YOKTU** | pbxproj'da `com.apple.Push` işaretli değildi |
| iOS'ta `getToken()` sırası | ⚠️ **kırılgandı** | APNs jetonu gelmeden çağrılıyordu |
| APNs Auth Key (.p8) Firebase'de | **ÖLÇEMEDİM** | Firebase konsolunda; erişimim yok |
| App ID'de Push yeteneği | **ÖLÇEMEDİM** | Apple Developer portalı |

**Kırılma zinciri:** `aps-environment` yok → `registerForRemoteNotifications`
**APNs jetonu almaz** → FCM `getToken()` ya `null` döner ya
`apns-token-not-set` atar → bizim `catch` bunu **sessizce null**'a çevirir →
cihaz sunucuya **hiç kaydolmaz** → hiçbir bildirim gelmez. Hiçbir katman
hata göstermez; Android çalışırken iOS'un sessiz kalmasının doğal
açıklaması budur.

### Bu turda yapılanlar (kod tarafı)
1. `Runner.entitlements` → `aps-environment` = `development`. **Değer
   bilinçli `development`**: Xcode, App Store/TestFlight dağıtımında
   imzalarken `production` ile değiştirir; elle `production` yazmak
   cihaza doğrudan kurulan geliştirme yapısında jetonu engellerdi.
2. `project.pbxproj` → `SystemCapabilities` içine `com.apple.Push`
   (NFC için zaten kullanılan aynı kalıp).
3. `push_messaging.dart` → iOS'ta önce `getAPNSToken()` beklenir (10 ×
   500 ms), gelmezse FCM jetonu **istenmez** ve sebep günlüğe yazılır —
   sessiz null yerine söylenmiş bir başarısızlık.
4. 5 kilit testi (`p211_ios_push_zinciri_test.dart`).

### SENİN YAPACAKLARIN — Xcode ve Apple/Firebase konsolu
Erişimim yok; sırayla:

**A. Apple Developer portalı** (developer.apple.com → Certificates,
Identifiers & Profiles)
1. **Identifiers → `site.yonetio.app`** → Capabilities listesinde
   **Push Notifications**'ı işaretle → Save. (Aynı ekranda
   **Associated Domains** ve **NFC Tag Reading** de işaretli olmalı.)
2. **Keys → +** → adı `Yonetio APNs` → **Apple Push Notifications
   service (APNs)** kutusunu işaretle → Continue → Register →
   **`AuthKey_XXXXXXXXXX.p8` dosyasını indir** (bir kez indirilebilir!).
   Not al: **Key ID** (10 karakter) ve **Team ID** (Membership sayfasında).
3. Profilleri **yeniden üret**: yetenek eklendiği için mevcut provisioning
   profilleri geçersizleşir. Xcode otomatik imzalama kullanıyorsan
   Xcode kendisi yeniler; manuel imzalıyorsan profili yeniden indir.

**B. Firebase konsolu** (console.firebase.google.com → `tesis-platform`)
4. **Project settings → Cloud Messaging → Apple app configuration**
   (`site.yonetio.app`) → **APNs Authentication Key → Upload**:
   `.p8` dosyası + **Key ID** + **Team ID**. (Sertifika değil, **key**
   yükle: key her iki ortamda da — sandbox ve production — çalışır ve
   süresi dolmaz.)

**C. Xcode** (Runner.xcworkspace)
5. **Runner target → Signing & Capabilities → + Capability → Push
   Notifications**. (Bu adımdan sonra `aps-environment`'ı Xcode kendi
   yönetir; dosyaya koyduğum değer zaten uyumlu.)
6. Aynı ekranda **Background Modes**'u eklemek **isteğe bağlı**: yalnız
   *sessiz/veri* bildirimi işlemek gerekirse **Remote notifications**
   kutusu şart. Bugünkü gönderimlerimiz `notification` taşıdığı için
   alarm bildirimleri onsuz da gelir — bu yüzden `Info.plist`e
   `UIBackgroundModes` **eklemedim**; App Store denetimi gerekçesiz
   arka plan modunu sorgular.
7. **`yonetio_bildirim.caf`, `yonetio_vardiya.caf`, `yonetio_gurultu.caf`**
   dosyalarını **Runner target'ına ekle** (Build Phases → Copy Bundle
   Resources). Dosyalar depoda var ama target üyeliğini Xcode tutuyor;
   eksikse iOS sessizce **varsayılan sese** düşer.
8. Archive → TestFlight.

**D. Cihazda doğrulama sırası** (hangi halkanın koptuğunu ayırt eder)
9. Uygulamayı aç, bildirim iznini **ver**.
10. Ayarlar ekranındaki push tanılama bölümünde **jetonun kaydedildiğini**
    gör. Jeton **yoksa** sorun A/C adımlarındadır (APNs jetonu gelmiyor).
11. Jeton varsa panelden bir test bildirimi gönder. Jeton var ama bildirim
    gelmiyorsa sorun **B**'dedir (APNs key yüklü değil / yanlış Team ID) —
    bu durumda `push_gonderim` kaydında hata kodu görünür.

> **Simülatörde push çalışmaz** (APNs jetonu üretilmez). Test **gerçek
> cihazda** yapılmalı.

---

## §7 — Uygulama ikonu: yeni logoyu nasıl vereceksin

### ÖLÇÜM
`scripts/ikon-uret.py` çalışıyor ve doğrulaması sağlam (alfa kuralı + %66
güvenli bölge). Ama **yeni bir logoyu kabul edemiyordu**: kırpma kutusu
(`KUTU`) eski kaynağa göre sabit ve betik, kaynağın boyutu ya da alfa
sınır kutusu değişirse **açıkça duruyor** ("elle gözden geçirin"). Bu
durma bilinçliydi (kırpma sessizce kaymasın) ama yeni logo geldiğinde
elle piksel saymak gerekiyordu.

**Yeni logo dosyası bu depoda YOK** — bu yüzden yeni ikonları
**üretemedim**. Ölçemediğim şey bu; aşağıdaki dosyayı koyduğunda tek
komutla üretilecek.

### SANA GEREKEN — logo dosyasının yeri, biçimi, çözünürlüğü

| | |
|---|---|
| **Yol** | `assets/marka/yonetiyor-logo.png` (aynı dosyanın üzerine yaz) |
| **Biçim** | **PNG, RGBA** — alfa kanalı **şart** (arka plan **saydam**) |
| **Çözünürlük** | **en az 1024×1024**; ideal **2048×2048**. Kare olması gerekmez; işaret dikey/yatay olabilir, betik ölçer |
| **İçerik** | Yalnız **işaret** (+ istersen kısa gövde). **Yazı/slogan koyma**: 48 px launcher'da okunmaz |
| **Kenar boşluğu** | Bırakma — betik oranı kendisi verir (mağaza %72, adaptif %66) |
| **Renk** | Lacivert işaret; koyu zemin varyantı için beyaz siluete **betik çevirir** (`beyaza_boya`) |
| **Vermemesi gerekenler** | JPEG (alfa yok), SVG (araç PNG okur), düz beyaz zeminli PNG (siluet çıkarılamaz) |

> Elinde yalnız SVG varsa: 2048×2048 saydam PNG olarak dışa aktar.

### KARAR K7 — betik yeni kaynağı kabul eder, ama kırpma **karar olarak** kalır
Yeni kip: `--olc` kaynağı ölçer, alfa sınır kutusunu ve **yapıştırmaya
hazır** sabitleri basar; `--kutu sol,ust,sag,alt --kaynak-onay` ise
sabitleri değiştirmeden deneme koşumu yapar. Betik **kendi başına** yeni
kutuya geçmez: kırpma bir karardır, her koşumda yeniden ölçülürse marka
sessizce kayar.

Bugünkü kaynakta ölçüm:
`1072×992`, alfa sınırı `(303,182)-(768,810)` → `466×629` (dikey).

### Senin adımların (logo geldiğinde)
```
1) assets/marka/yonetiyor-logo.png  <- yeni dosya
2) python3 scripts/ikon-uret.py --olc                 # ölçüm + öneri
3) python3 scripts/ikon-uret.py --kutu <öneri> --kaynak-onay --onizle
   # ASCII önizlemede işaret tanınıyor mu? Değilse kutuyu daralt/genişlet
4) Beğendiğin kutuyu betikteki BEKLENEN_BOYUT / BEKLENEN_SINIR / KUTU
   sabitlerine yaz (—olc çıktısı hazır satırları veriyor)
5) python3 scripts/ikon-uret.py                        # iki varyant + doğrulama
6) python3 scripts/test_ikon_uret.py                   # kilit
7) cd mobile && dart run flutter_launcher_icons        # mipmap'leri tazele
   (P184 dersi: bu adım atlanınca gömülü ikonlar BAYAT kalır)
8) Mağaza görselleri: assets/marka/ikon/ios-appstore-1024.png ve
   play-store-512.png — mağaza simgesiyle tutarlılık buradan gelir,
   ikisi de AYNI zemin+siluetten üretiliyor
```

### Kilit
`scripts/test_ikon_uret.py` (yeni): `--olc` kipi çalışıyor mu, mağaza
ikonları alfasız mı, adaptif ön katman %66'yı aşıyor mu. Kırma denemesiyle
doğrulandı: oran 0,80'e çıkarılınca kilit `819x806 > 675` diyerek düştü,
geri alınca geçti. Bugünkü ölçüm: **675×664 ≤ 675** ve mağaza ikonlarının
hepsi alfasız.
