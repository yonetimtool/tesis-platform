# İlk Mac derlemesi + TestFlight runbook (P118) — [KEREM]

> Ajanın payı **bu belge** ve `codemagic.yaml`dır; **koşum Kerem'in**
> (macOS ya da CI gerekir). Depodaki `ios/` ağacı P114'te denetime hazır
> hâle getirildi ama **hiç derlenmedi** — bu runbook'un ilk işi, elle
> yapılan yapılandırmayı **doğrulamaktır**.

## 0. Ön koşullar (bir kez)

| Ne | Nerede |
|---|---|
| Apple Developer Program üyeliği | developer.apple.com (yıllık) |
| App ID: **`site.yonetio.app`** | Certificates → Identifiers → **+** |
| App ID yeteneği: **NFC Tag Reading** | Aynı App ID → Capabilities |
| App Store Connect'te uygulama kaydı | appstoreconnect.apple.com → Apps → **+** |

**NFC yeteneği App ID'de açılmazsa** `ios/Runner/Runner.entitlements`
tek başına yetmez: imzalama başarısız olur ya da (daha kötüsü) uygulama
derlenir ama NFC **sessizce çalışmaz**.

> **Uyarı:** NFC tur okutma **iPhone 7 ve üstü** ister. NTAG424 SDM
> doğrulama yolu **gerçek cihazda** denenmelidir; simülatörde NFC yoktur.

## 1. Doğrulama — elle yapılan yapılandırma tuttu mu

Xcode'da `ios/Runner.xcworkspace` açıldıktan **hemen sonra**:

```bash
cd mobile
flutter clean && flutter pub get
flutter test test/ios_yapilandirma_test.dart   # 15 test: Mac'siz olculebilen her sey
open ios/Runner.xcworkspace
```

Xcode'da **gözle** doğrulanacaklar (pbxproj elle düzenlendi):

- [ ] Proje açılıyor, "damaged project file" uyarısı **yok**
- [ ] Runner → **Signing & Capabilities**: bundle `site.yonetio.app`,
      **Near Field Communication Tag Reading** yeteneği listede **ve
      üstünde uyarı üçgeni yok** (üçgen varsa profil yetkiyi taşımıyor →
      §0'daki App ID adımı eksik)
- [ ] Runner → **Build Settings** → `CODE_SIGN_ENTITLEMENTS` =
      `Runner/Runner.entitlements` (üç yapılandırmada da). Depoda hem
      pbxproj'ta hem `Flutter/Debug|Release.xcconfig`te tanımlı; Xcode
      yeniden yazsa bile xcconfig katmanı ayarı korur
- [ ] Runner → **Build Settings** → `TARGETED_DEVICE_FAMILY = iPhone`
- [ ] Runner → **Build Phases → Copy Bundle Resources** içinde
      **`PrivacyInfo.xcprivacy`** ve **`InfoPlist.strings`** var
- [ ] Project navigator'da `InfoPlist.strings` altında **en** ve **tr**
      alt öğeleri görünüyor
- [ ] `Assets.xcassets → AppIcon`: 1024'lük simge **marka**, yer tutucu
      "F" değil

Bir madde tutmazsa: Xcode'da elle düzelt (dosyayı hedefe sürükle) ve
**pbxproj değişikliğini commit'le** — o zaman `ios_yapilandirma_test.dart`
de gerçeği ölçmeye devam eder.

## 2. Yerel derleme (Mac'te)

```bash
cd mobile
flutter build ios --release \
  --dart-define=API_BASE_URL=https://api.yonetio.site \
  --dart-define=WEB_BASE_URL=https://yonetio.site
```

**`--dart-define`ler ZORUNLU.** Verilmezse `AppConfig` varsayılanları
devreye girer: API `http://10.0.2.2:8000` (Android emülatörü adresi) ve
gizlilik bağlantıları `https://yonetio.site` — yani **uygulama hiçbir
sunucuya bağlanamaz** ve denetçi "çalışmıyor" der.

İlk derlemede beklenen sorunlar ve karşılıkları:

| Belirti | Sebep | Çözüm |
|---|---|---|
| `CocoaPods not installed` | Pod aracı yok | `sudo gem install cocoapods` |
| `Signing for "Runner" requires a development team` | Takım seçilmedi | Xcode → Signing → Team |
| `Provisioning profile doesn't support NFC` | App ID'de yetenek kapalı | §0'daki NFC adımı |
| **`Missing required entitlement`** (cihazda, kurulumda ya da ilk açılışta) | **Provisioning profile NFC yetkisini taşımıyor.** Yetkilendirme dosyası uygulamada var ama profil onu tanımıyor — yani sorun depoda değil, **Apple Developer portalındaki App ID'de**. | §0: App ID → Capabilities → **NFC Tag Reading** → sonra Xcode'da profili **yenile** (Signing → takımı bir kapatıp aç ya da `xcode-project use-profiles`). Depodaki `CODE_SIGN_ENTITLEMENTS` ve `SystemCapabilities` zaten yerinde (`flutter test test/ios_yapilandirma_test.dart` doğrular). |
| `Invalid Info.plist key` | Elle düzenlemede yazım hatası | `plutil -lint ios/Runner/Info.plist` |

> **`Missing required entitlement` İKİ AYRI SEBEPTEN gelir — ayırt edin:**
>
> | Ne zaman | Sebep | Nerede düzeltilir |
> |---|---|---|
> | Kurulumda / uygulama **hiç açılmadan** | Provisioning profile NFC yetkisini taşımıyor | Apple Developer portalı → App ID → **NFC Tag Reading** |
> | Okutma sırasında, **sistem sayfası açıldıktan sonra** (etikete değince) | CoreNFC, ISO7816/DESFire etiketine **bağlanırken** `select-identifiers` beyanını arıyor | **Depoda düzeltildi** (Info.plist, 2026-08-02): `com.apple.developer.nfc.readersession.iso7816.select-identifiers` |
>
> İkincisinin işareti: `nfcd` günlüğünde alan algılama trafiği **var**,
> oturum/yetki satırı **yok** — çünkü ret `nfcd`ye ulaşmadan, CoreNFC
> katmanında **uygulama içinde** veriliyor.
>
> **`Missing required entitlement` neden derlemeyi düşürmez:** imzalama,
> uygulamanın istediği yetkiyi profilin **vermediği** durumda da
> tamamlanabilir; eksiklik **çalışma anında** ortaya çıkar. Bu yüzden
> "derleme başarılı" bu hatayı elemez.

## 2.5 Yapı numarası — iOS AYRI SAYAÇ TUTAR

`pubspec.yaml`'daki `version: <ad>+<numara>` **iki platformu birden**
besler: Android `versionCode`, iOS `CFBundleVersion`
(`Info.plist` ikisini de `$(FLUTTER_BUILD_NAME)`/`$(FLUTTER_BUILD_NUMBER)`
üzerinden okur). Ama iki mağaza aynı numarayı **aynı şekilde saymaz**:

* **App Store Connect** bir yapı numarasını **bir kez** kabul eder ve
  numara **uygulama kaydına** aittir — o numarayla daha önce bir yapım
  yüklendiyse (TestFlight'a düşmüş, hatta sonradan silinmiş olsa bile)
  aynı numara **bir daha kullanılamaz**. Sürüm adı (`1.0.0` → `1.1.0`)
  değişse de sayaç **sıfırlanmaz**.
* **Play Console** yalnız "artıyor mu" diye bakar; aradaki boşluklar
  sorun değildir.

**Ölçülen olay (2026-08-31):** `1.1.0+3` yüklemesi *"build number 3 has
already been used"* ile reddedildi — `1.0.0 (3)` 3 Ağustos'ta yüklenmişti;
`4` de kullanılmıştı. Sürüm **1.1.0+5**'e çıkarıldı.

**Kural:** yapı numarası **iOS'un ihtiyacına göre** ilerler ve
**asla geri gitmez**. Android bundan zarar görmez: `versionCode` 3 → 5
atlaması Play için geçerlidir (yalnız artması gerekir). İki platformu ayrı
numaralarda tutmak da mümkündür (`flutter build ipa --build-number=N`) ama
**yapılmıyor**: tek kaynak, "hangi ikili hangi numarayı taşıyor" sorusunu
tek yerden cevaplar; iki sayaç, birini yükseltip diğerini unutmanın
sessizce yanlış sürüm yüklemeye dönüştüğü bir tuzaktır.

**Yükleme öncesi kontrol:** App Store Connect → uygulama → TestFlight →
"Tüm Yapımlar" listesinde bu numara var mı? Varsa `pubspec.yaml`'daki
numarayı artırın; arşivi yeniden almak gerekir (numara ikiliye gömülüdür).

## 3. Arşiv + yükleme (Xcode)

1. Cihaz seçici → **Any iOS Device (arm64)**
2. **Product → Archive**
3. Organizer → **Distribute App** → **App Store Connect** → **Upload**
4. Yükleme sonrası App Store Connect → TestFlight → işlemenin bitmesini
   bekle (10–30 dk)

**"Missing Compliance" sorulmaz** (P194): `Info.plist` içinde
`ITSAppUsesNonExemptEncryption = false` var. Uygulama kendi şifrelemesini
yapmıyor — ağ trafiği yalnız HTTPS/TLS (işletim sistemi), yerel depo
Keychain, NFC etiket doğrulaması **sunucuda**. Bir gün kripto kitaplığı
eklenirse hem bu değer hem App Store Connect cevabı gözden geçirilmeli;
`ios_yapilandirma_test.dart` anahtarın kaybolmasını ve bilinen kripto
paketlerinin eklenmesini yakalar.

**Yükleme adımında reddedilirse** en olası üç sebep: **yapı numarası zaten
kullanılmış** (bkz. §2.5 — 2026-08-31'de yaşandı), eksik
`PrivacyInfo.xcprivacy` (P114'te eklendi — §1'deki Copy Bundle Resources
maddesini doğrulayın) ve **simgede alfa kanalı** (P114'te kaldırıldı).

## 4. TestFlight iç test

1. App Store Connect → TestFlight → **Internal Testing** → grup oluştur
2. Kendini (ve varsa test edecek kişileri) ekle
3. Yapımı gruba ata
4. iPhone'da TestFlight ile kur ve **`docs/app-store/screenshots.md`
   listesini** bu yapımla yürü — hem ekran görüntüleri hem de
   `docs/MASTER-PLAN.md` P11'deki cihaz-doğrulama maddeleri.

## 5. Denetime gönderme

- [ ] **App Privacy** anketi: `docs/app-store/app-privacy.md` tablosu
- [ ] **App Review Information → Notes**:
      `docs/app-store/review-notes.md` sonundaki İngilizce blok
- [ ] **Demo tenant prod'da tohumlandı** (`review-notes.md` §1'deki
      `run --rm … worker …` komutu; `api` değil)
- [ ] Demo hesap alanına: `sakin@demo.yonetio.site` + `DEMO_PAROLA`
      (denetçi rol değiştirmek isterse notlarda diğer hesaplar yazılı)
- [ ] Privacy Policy URL: `https://yonetio.site/gizlilik`
- [ ] Ekran görüntüleri: 6.7" seti (P117)

## 6. Codemagic (Mac'e alternatif)

`codemagic.yaml` depoda hazır. Codemagic'te yapılacaklar:

1. Depoyu bağla, `ios-release` iş akışını seç
2. **Environment variables** (grup: `yonetio`):
   `API_BASE_URL`, `WEB_BASE_URL`
3. **Code signing**: App Store Connect API anahtarını yükle (Integrations
   → Apple Developer Portal); Codemagic profili kendisi üretir
4. Çalıştır → çıktı otomatik TestFlight'a gider

Codemagic, Mac satın almadan ilk yapımı almanın en kısa yoludur; ama
**§1'deki Xcode gözle doğrulaması atlanamaz** — CI, pbxproj'daki bir
eksikliği "başarılı derleme" olarak da geçebilir (ör. kaynak hedefe
bağlanmamışsa dosya sessizce pakete girmez).
