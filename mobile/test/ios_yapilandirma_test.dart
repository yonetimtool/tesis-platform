/// P114 — iOS YAPILANDIRMA KİLİDİ (Mac olmadan doğrulanabilen her şey).
///
/// `ios/` ağacı elle düzenlendi çünkü macOS yok. Bu dosya, ilk Mac
/// derlemesine kadar geçen sürede yapılandırmanın **sessizce geri
/// gitmemesini** sağlar: `flutter create`, bir eklenti kurulumu ya da
/// `flutter_launcher_icons` gibi bir araç bu dosyalara dokunabiliyor
/// (nitekim ikon aracı bu turda iki yapı ayarını bozdu).
///
/// Ölçülenlerin hepsi App Store denetiminde **ret sebebi** olan şeyler:
/// eksik gizlilik bildirimi (yükleme adımında reddedilir), yer tutucu
/// simge, uygulamanın gerçek kullanımını anlatmayan izin metni, NFC
/// yetkilendirmesinin unutulması (özellik sessizce çalışmaz).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

String _oku(String yol) => File(yol).readAsStringSync();

void main() {
  group('Info.plist', () {
    final plist = _oku('ios/Runner/Info.plist');

    test('GORUNEN AD marka — Flutter sablonunun "Mobile"i DEGIL', () {
      expect(plist, contains('<string>Yönetio</string>'));
      expect(plist.contains('<string>Mobile</string>'), isFalse);
    });

    test('IZIN METINLERI uygulamanin GERCEK kullanimini anlatiyor', () {
      // Apple, amac metninin gercek kullanimi anlatmasini ister. Eski
      // metinler DARDI: kamera "gorev tamamlama" diyordu ama talep,
      // etkinlik, kargo ve site kurali da ayni izni kullaniyor; konum
      // "acil durum" diyordu ama ASIL kullanim tur okutmasi (P34).
      for (final anahtar in [
        'NFCReaderUsageDescription',
        'NSCameraUsageDescription',
        'NSPhotoLibraryUsageDescription',
        'NSLocationWhenInUseUsageDescription',
      ]) {
        expect(plist, contains('<key>$anahtar</key>'),
            reason: '$anahtar eksik — izin istendiginde uygulama COKER');
      }
      // Konum metni ARKA PLAN IZLEME OLMADIGINI soylemeli: soylemeyen bir
      // metin, denetcinin "neden konum istiyor" sorusunu acik birakir.
      expect(plist, contains('never tracks your location in the background'));
      // Kamera metni tek bir akisa DARALTILMAMIS olmali.
      expect(plist, contains('maintenance requests'));
    });

    test('YEDI DIL beyan edilmis (magaza tek-dilli gostermesin)', () {
      for (final dil in ['en', 'tr', 'ar', 'ru', 'de', 'fr', 'es']) {
        expect(plist, contains('<string>$dil</string>'));
      }
    });

    test('IPAD yon anahtari YOK (ilk surum yalniz iPhone)', () {
      expect(plist.contains('UISupportedInterfaceOrientations~ipad'), isFalse);
    });

    test('ATS istisnasi YALNIZ MEDYA ile sinirli', () {
      // `NSAllowsArbitraryLoads` (genel istisna) API trafigini de acardi ve
      // denetimde gerekce ister. Bizimki YALNIZ AVFoundation medya
      // yuklemelerini kapsar (saha kameralarinin duz-http restream'i).
      expect(plist, contains('NSAllowsArbitraryLoadsForMedia'));
      expect(plist.contains('<key>NSAllowsArbitraryLoads</key>'), isFalse);
    });
  });

  group('Gizlilik bildirimi (PrivacyInfo.xcprivacy)', () {
    final p = _oku('ios/Runner/PrivacyInfo.xcprivacy');

    test('IZLEME YOK olarak beyan edilmis', () {
      // Bu satir, App Privacy anketindeki "Tracking: No" ile AYNI seyi
      // soylemek zorunda; ikisinin ayrismasi tutarsizlik olarak okunur.
      expect(p, contains('<key>NSPrivacyTracking</key>'));
      expect(
        RegExp(r'<key>NSPrivacyTracking</key>\s*<false/>').hasMatch(p),
        isTrue,
        reason: 'NSPrivacyTracking true olmus — IDFA/izleme beyani degisti',
      );
      expect(p, contains('<key>NSPrivacyTrackingDomains</key>'));
    });

    test('GEREKCE ZORUNLU API kategorileri beyan edilmis', () {
      for (final kategori in [
        'NSPrivacyAccessedAPICategoryUserDefaults',
        'NSPrivacyAccessedAPICategoryFileTimestamp',
        'NSPrivacyAccessedAPICategoryDiskSpace',
        'NSPrivacyAccessedAPICategorySystemBootTime',
      ]) {
        expect(p, contains(kategori), reason: '$kategori beyan edilmemis');
      }
    });

    test('TOPLANAN VERI tipleri kullandigimiz izinlerle TUTARLI', () {
      // Kamera/galeri izni istiyorsak fotograf toplandigini, konum izni
      // istiyorsak konum toplandigini beyan etmeliyiz. Izin isteyip
      // beyan etmemek, denetimde en sik yakalanan tutarsizliktir.
      final plist = _oku('ios/Runner/Info.plist');
      if (plist.contains('NSCameraUsageDescription')) {
        expect(p, contains('NSPrivacyCollectedDataTypePhotosorVideos'));
      }
      if (plist.contains('NSLocationWhenInUseUsageDescription')) {
        expect(p, contains('NSPrivacyCollectedDataTypePreciseLocation'));
      }
    });
  });

  group('Core NFC yetkilendirmesi', () {
    test('NDEF ve TAG bicimlerinin IKISI de acik', () {
      final e = _oku('ios/Runner/Runner.entitlements');
      expect(e, contains('com.apple.developer.nfc.readersession.formats'));
      expect(e, contains('<string>NDEF</string>'));
      // TAG olmadan NTAG424 SDM dogrulamasi (ISO7816) yapilamaz —
      // yalniz NDEF birakmak o yolu SESSIZCE kapatirdi.
      expect(e, contains('<string>TAG</string>'));
    });
  });

  group('Xcode projesi', () {
    final proje = _oku('ios/Runner.xcodeproj/project.pbxproj');

    test('BUNDLE KIMLIGI marka alanindan (ters DNS)', () {
      expect(proje, contains('PRODUCT_BUNDLE_IDENTIFIER = site.yonetio.app;'));
      expect(proje.contains('com.tesisguvenlik.mobile'), isFalse);
    });

    test('YALNIZ IPHONE hedefleniyor', () {
      expect(proje.contains('TARGETED_DEVICE_FAMILY = "1,2"'), isFalse);
      expect(proje, contains('TARGETED_DEVICE_FAMILY = 1;'));
    });

    test('YETKILENDIRME Runner hedefinin UC yapilandirmasinda da bagli', () {
      // Debug/Release/Profile. Birini atlamak, o yapilandirmada NFC'nin
      // SESSIZCE calismamasi demekti (en sinsi hali: Debug'da calisir,
      // TestFlight yapiminda calismaz).
      expect(
        'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'
            .allMatches(proje)
            .length,
        3,
      );
    });

    test('YENI KAYNAKLAR hedefe bagli (yoksa pakete GIRMEZ)', () {
      // Dosyayi diske koymak yetmez: Copy Bundle Resources fazinda
      // olmayan bir gizlilik bildirimi pakete girmez ve yukleme
      // reddedilir — hem de "dosya var" diye bakip gormeden.
      expect(proje, contains('PrivacyInfo.xcprivacy in Resources'));
      expect(proje, contains('InfoPlist.strings in Resources'));
      expect(proje, contains('isa = PBXVariantGroup'));
    });
  });

  group('Uygulama simgesi', () {
    test('YER TUTUCU DEGIL: markadan uretilmis ve SAYDAMLIK YOK', () {
      final ikon = File(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/'
        'Icon-App-1024x1024@1x.png',
      ).readAsBytesSync();
      expect(ikon.length, greaterThan(10000),
          reason: 'Flutter yer tutucu simgesi kucuktur');
      // PNG IHDR: 16..24 boyut, 25 renk tipi. 6 = RGBA (ALFA VAR) ->
      // App Store yuklemede REDDEDER.
      final renkTipi = ikon[25];
      expect(renkTipi, isNot(6),
          reason: 'App Store simgede alfa kanali KABUL ETMEZ');
      final genislik =
          ByteData.sublistView(ikon, 16, 20).getUint32(0, Endian.big);
      expect(genislik, 1024);
    });
  });

  group('Yerellestirilmis izin metinleri', () {
    test('tr ve en dosyalari VAR ve AYNI anahtarlari tasiyor', () {
      final anahtar = RegExp(r'^"([A-Za-z]+)"\s*=', multiLine: true);
      final en = anahtar
          .allMatches(_oku('ios/Runner/en.lproj/InfoPlist.strings'))
          .map((m) => m.group(1))
          .toSet();
      final tr = anahtar
          .allMatches(_oku('ios/Runner/tr.lproj/InfoPlist.strings'))
          .map((m) => m.group(1))
          .toSet();
      expect(en, isNotEmpty);
      // Eksik anahtar, o dilde TEMEL DILE dusme demektir: Turkce cihazda
      // Ingilizce izin metni gorunurdu.
      expect(tr, en, reason: 'tr ve en anahtar kumeleri ayrismis');
    });
  });
}
