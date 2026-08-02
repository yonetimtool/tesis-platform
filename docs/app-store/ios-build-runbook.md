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
      **Near Field Communication Tag Reading** yeteneği listede
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
| `Invalid Info.plist key` | Elle düzenlemede yazım hatası | `plutil -lint ios/Runner/Info.plist` |

## 3. Arşiv + yükleme (Xcode)

1. Cihaz seçici → **Any iOS Device (arm64)**
2. **Product → Archive**
3. Organizer → **Distribute App** → **App Store Connect** → **Upload**
4. Yükleme sonrası App Store Connect → TestFlight → işlemenin bitmesini
   bekle (10–30 dk)

**Yükleme adımında reddedilirse** en olası iki sebep: eksik
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
