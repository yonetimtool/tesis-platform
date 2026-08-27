# P183 — Mobil bildirimler (Flutter) — kararlar

Kesintisiz mod. Kararlar gerekçeleriyle. Bu, P181 §10.1'in cihaz gerektiren /
tamamlanmamış kısmının bitirilmesidir. Backend HAZIR ve prod'da (FCM gönderimi,
`bildirim_mobil` kanal kapısı [göç 0055], çok-rollü dedup, vardiya özeti [göç
0073], uzak_okutma 30 dk kısıtı, push `data` alanları). Eksik olan **yalnız
Flutter tarafıydı** — telefona bildirim düşmüyordu / ayarlanamıyordu.

**Dürüstlük notu:** Altyapının ÇOĞU P181 §10.1'de kurulmuştu (arka-plan handler,
token kayıt/yenileme, logout pasifleştirme, `routeForPushData` derin bağlantı).
P183 bunları **doğruladı + sertleştirdi** ve eksik iki parçayı ekledi: **cihaz
izni görünürlüğü/UX (§2)** ve **bildirim tercihleri ekranı (§5)**.

---

## §1 — Arka plan handler (3 durum) — VARDI, doğrulandı

`firebaseMessagingBackgroundHandler` (top-level, `@pragma('vm:entry-point')`)
+ `FirebaseMessaging.onBackgroundMessage(...)` kaydı `initialize()` içinde
(P181 §10.1). Üç durum:
- **Ön plan:** `onMessage` → `PushState.sonBildirim` → `main.dart` SnackBar
  ("Aç" aksiyonu derin bağlantıya gider).
- **Arka plan (tepside):** `onMessageOpenedApp` → `sonTiklanan` → yönlendirme.
- **Tamamen kapalı:** `getInitialMessage` (soğuk başlatmada bir kez okunur) +
  arka-plan izolasyonunda `onBackgroundMessage` handler'ı.

**Karar — handler EK bildirim GÖSTERMEZ:** backend `notification` bloğu (başlık+
gövde) gönderir; FCM/OS tepsi bildirimini KENDİSİ düşürür. Handler'da ikinci bir
bildirim göstermek ÇİFT olurdu. Handler yalnız Firebase'i izolasyonda başlatır +
loglar (ileride data-only mesaj işlenecek yer).

**Cihazda test (kullanıcı):** uygulama tamamen kapalıyken gerçek teslim (kabul
1) — izole ortamda push GÖNDERİLEMEZ; gerçek cihaz + prod FCM gerekir.

---

## §2 — İzin akışı: zamanlama + görünürlük + ret UX — YENİ

**Zamanlama kararı — İLK OTURUMDA (login sonrası), uygulama ilk açılışında/
splash'te DEĞİL.** Gerekçe: login öncesi kullanıcı/bağlam yoktur ve alınacak
bildirim yoktur; izin istemi kullanıcının hesabı ve bağlamı oluştuktan sonra,
uygulamanın değerini gördüğü noktada çıkar. `pushSetupProvider` yalnız
`AuthStatus.authenticated` geçişinde `registerCurrentToken()` çağırır → istem
orada gösterilir. (Ayrı "yumuşak ön-istem" ekranı eklenmedi — login zaten değer
kapısıdır; ekstra ekran sürtünme olurdu.)

**Görünürlük (kabul 3):** `requestPermission()` artık `PushIzinDurumu` döner
(verildi/reddedildi/belirsiz/kısmi/bilinmiyor — FCM `AuthorizationStatus`
karşılığı). Bu durum `PushState.izinDurumu`ya yazılır ve **Ayarlar → Bildirimler**
kartında görünür. Ayarlar açılışında `izinDurumunuTazele()` istem GÖSTERMEDEN
(`getNotificationSettings`) durumu tazeler (kullanıcı cihaz ayarlarından değiştirmiş
olabilir).

**Ret UX (kabul 3):** İzin reddedilse de **akış durmaz** — token yine kaydedilir
(kullanıcı sonra izin verirse hazır olsun; ayrıca backend `bildirim_mobil` kapısı
push'u zaten ayrıca denetler) ve uygulama ÇALIŞMAYA DEVAM eder. Kart:
- **belirsiz** (henüz sorulmadı): uyarı + "İzin iste" düğmesi → sistem istemini
  gösterir; verilirse token da kaydedilir.
- **reddedildi:** uyarı + "cihaz ayarlarından açın" metni (iOS'ta yeniden istem
  ÇIKMAZ; tek yol cihaz ayarlarıdır).

**Karar — yeni native bağımlılık YOK:** `permission_handler`/`app_settings`
eklenmedi (native yapılandırma + 7.6 GB RAM'de derleme maliyeti + KGP/AGP riski).
Reddedilen durumda kullanıcı metinle cihaz ayarlarına yönlendirilir; istem
mümkün olan (belirsiz) durumda "İzin iste" doğrudan çalışır. Bu, native yüzey
eklemeden kabul kriterini karşılar.

**Cihazda test (kullanıcı):** iOS sistem istemi görünümü + reddettikten sonra
cihaz ayarları yolu.

---

## §3 — Derin bağlantı — VARDI, sertleştirildi

`routeForPushData(data)` `data['tip']` + `data.*` id'lerine göre `AppRoutes`
üretir (talep/ziyaretçi/kargo/erişim/rezervasyon/etkinlik/duyuru + devriye/
vardiya). Soğuk başlatma `getInitialMessage` ile çalışır (P181 §10.1).

**Sertleştirme (kabul 2):** `main.dart`'ta tıklanan bildirim yönlendirmesi artık
`try/catch` içinde: `router.push` bozuk/eksik id ile nadiren fırlatırsa **çökme
yerine ana ekrana düşülür** (`router.go(home)`). Bilinmeyen `tip` → `null` →
uygulama olduğu yerde kalır (soğuk başlatmada bu zaten ana ekrandır → pratikte
"ana ekrana düş").

**Cihazda test (kullanıcı):** kilitli ekrandan/kapalıdan dokunup doğru ekranın
açılması (kabul 2) — gerçek FCM teslimi gerekir.

---

## §4 — Jeton yönetimi — VARDI, doğrulandı

- **Kayıt:** login sonrası `POST /devices` (idempotent upsert), cihaz dili ile
  (tur 16 — push metni sunucuda gönderim anında o dilde üretilir).
- **Yenileme (kabul 4):** `onTokenRefresh` → eski token pasifleştirilir
  (`DELETE /devices/{eski}`) + yeni kaydedilir.
- **Çıkış (kabul 5):** `AuthController.logout` → `PushRegistrar.onLogout()`
  (auth token hâlâ geçerliyken) → `DELETE /devices/{token}` + yerel işaret
  temizlenir. Böylece **aynı cihaza başka kullanıcı girince eskisinin push'ları
  gitmez.** (Kanca `auth_controller.dart`'ta zaten bağlıydı — doğrulandı + test.)

Testler: `push_registrar_test.dart` (kayıt/yenileme/logout + yeni izin testleri).

---

## §5 — Bildirim tercihleri ekranı — YENİ (asıl eksik parça)

Backend `GET/PATCH /me/bildirim-tercihleri` (göç 0055: `bildirim_eposta/sms/mobil`)
VARDI; mobilde HİÇ arayüz yoktu. Eklendi:

- **Yeni:** `settings/domain/bildirim_tercihleri.dart` (model),
  `settings/data/bildirim_tercih_api.dart` (Dio istemci + provider),
  `settings_screen.dart` → `_BildirimKarti` (3 kanal `SwitchListTile`).
- **Konum:** Ayarlar → "Bildirimler" bölümü (Görünüm'den sonra). **KVKK pazarlama
  kartından AYRI** (`_IzinlerKarti`): biri RIZA (varsayılan kapalı), öteki
  KULLANIM TERCİHİ (varsayılan açık). İkisi tek kartta olsaydı kullanıcı "hepsini
  kapattım" sanıp aidat bildirimini de kaybederdi (web profil sayfasındaki aynı
  ayrımın mobil karşılığı).
- **PATCH KISMİ (kabul 6):** yalnız değişen kanal gönderilir; öteki kanallar
  sunucuda AYNEN kalır (iki oturum açıkken birinin ötekini sessizce geri almasını
  önler — backend `BildirimTercihUpdate`). Test bunu kilitler
  (`bildirim_tercih_test.dart`: `guncelle(mobil:false)` → gövde `{bildirim_mobil:
  false}`).
- **Kanal vs liste ayrımı (kabul 6):** `bildirim_mobil=false` yalnız **PUSH'u**
  durdurur (backend kapısı); **uygulama içi bildirim LİSTESİ etkilenmez** (o
  ayrı uç, `notifications`). Bu bilinçli — kullanıcı push almak istemese de
  geçmişi uygulamada görebilmeli.
- **İzin entegrasyonu:** Mobil kanal AÇIK ama cihaz OS izni KAPALIYSA kartta
  uyarı çıkar (§2) — yoksa "açık ama gelmiyor" sessiz başarısızlığı olurdu.

i18n: 11 yeni anahtar × 7 dil (ratchet `sozluk_denetimi_test` yeşil; Türkçe harf
sızıntısı yok). `flutter gen-l10n` ile `lib/l10n/gen/` yeniden üretildi (repoya
girer).

---

## Bilinen tuzaklar — sonuç

- **KGP/AGP:** `flutter analyze` TEMİZ, `flutter build apk --debug` denendi (bkz.
  dağıtım). `flutter_web_auth_2`/`nfc_manager` KGP uyarısı mevcut Flutter 3.47.1
  ile derleniyor — kırılmadı, ek karar gerekmedi.
- **google-services.json:** dev makinede yerel kopya var → debug build plugin'i
  uygular. Repoya girmez; release'i kullanıcı `bash mobile/yayin-yap.sh apk` ile
  üretir (dart-define + release google-services).
- **Analyze temizliği:** P183 kodu 0 sorun. Ek olarak 3 ÖNCEDEN VAR olan uyarı
  (ilgisiz test dosyalarında ölü import/parametre) temizlendi ki `flutter analyze`
  gerçekten "temiz" olsun (kabul 7).

---

## CİHAZDA TEST EDİLEMEYENLER (kullanıcı doğrulayacak)

İzole/başsız ortamda gerçek push GÖNDERİLEMEZ. Aşağıdakiler yalnız gerçek cihaz +
prod FCM ile doğrulanır:

1. **Kabul 1** — uygulama tamamen kapalıyken bildirimin cihaza ulaşması.
2. **Kabul 2** — bildirime dokununca doğru ekranın açılması + soğuk başlatma.
3. **Kabul 3 (iOS istemi)** — sistem izin isteminin görünümü + reddedince davranış.
4. **Kabul 4** — FCM jetonu gerçek yenilendiğinde backend'e gitmesi.
5. **Kabul 5** — çıkışta jetonun sunucuda pasifleşmesi (başka kullanıcı push
   almaması).

**Kod tarafında doğrulanan (test + analyze):** izin durumunun state'e yansıması,
akışın ret sonrası durmaması, logout kancası, kısmi PATCH gövdesi, 7-dil sözlük
bütünlüğü, `routeForPushData` eşlemesi, çökmesiz ana-ekran düşüşü.
