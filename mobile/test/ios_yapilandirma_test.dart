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

/// Bir `XCBuildConfiguration` blogunun ozeti.
class _Konfig {
  const _Konfig(this.ad, this.bundle, this.yetkilendirme);
  final String ad;
  final String? bundle;
  final bool yetkilendirme;
}

/// pbxproj'taki yapilandirma bloklarini AYRISTIRIR.
///
/// Neden ayristirma: dosyada bir dizginin KAC KEZ gectigini saymak,
/// onun DOGRU hedefte olup olmadigini soylemez.
List<_Konfig> _yapilandirmalar(String proje) {
  final sonuc = <_Konfig>[];
  final satirlar = proje.split('\n');
  final bas = RegExp(r'^\t\t[0-9A-F]{24} /\* (\w+) \*/ = \{');
  for (var i = 0; i < satirlar.length; i++) {
    final m = bas.firstMatch(satirlar[i]);
    if (m == null) continue;
    final govde = <String>[];
    for (var j = i; j < satirlar.length; j++) {
      govde.add(satirlar[j]);
      if (satirlar[j] == '\t\t};') break;
    }
    final metin = govde.join('\n');
    if (!metin.contains('isa = XCBuildConfiguration')) continue;
    final b = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);').firstMatch(metin);
    sonuc.add(_Konfig(
      m.group(1)!,
      b?.group(1),
      metin.contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'),
    ));
  }
  return sonuc;
}

void main() {
  group('Info.plist', () {
    final plist = _oku('ios/Runner/Info.plist');

    test('GORUNEN AD marka — Flutter sablonunun "Mobile"i DEGIL', () {
      expect(plist, contains('<string>Yönetiyor</string>'));
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

    test('(P194) IHRACAT UYUMLULUGU BEYANI Info.plist icinde', () {
      // Anahtar YOKSA App Store Connect her yuklemede "Missing
      // Compliance" sorar ve yapim ELLE cevaplanana kadar bekler —
      // otomatiklestirilebilir bir adimi her surumde tekrarlamak olurdu.
      //
      // Deger `false`: uygulama kendi sifrelemesini YAPMIYOR (yalniz
      // HTTPS + OS Keychain). Gerekcesi Info.plist icindeki yorumda.
      final plist = _oku('ios/Runner/Info.plist');
      expect(plist, contains('ITSAppUsesNonExemptEncryption'));
      expect(
        RegExp(r'<key>ITSAppUsesNonExemptEncryption</key>\s*<false/>')
            .hasMatch(plist),
        isTrue,
        reason: 'beyan true olmus — ihracat uyumlulugu yeniden degerlendirilmeli',
      );
    });

    test('(P194) UYGULAMADA KENDI SIFRELEMESI YOK (beyanla tutarli)', () {
      // "non-exempt sifreleme yok" iddiasi ancak bagimlilik listesi bunu
      // dogruluyorsa gecerlidir. Bir kripto kitapligi eklenirse bu test
      // duser ve beyanin gozden gecirilmesi gerektigini soyler.
      final pubspec = _oku('pubspec.yaml');
      for (final yasak in [
        'pointycastle',
        'encrypt',
        'cryptography',
        'webcrypto',
      ]) {
        expect(
          pubspec.contains('\n  $yasak:'),
          isFalse,
          reason: '$yasak eklenmis — ITSAppUsesNonExemptEncryption gozden gecirilmeli',
        );
      }
    });

    test('(P193) PUSH ACIKSA CIHAZ KIMLIGI BEYAN EDILMIS', () {
      // Push bildirimi acildiginda uygulama iki tanimlayici gonderir: FCM
      // kayit jetonu ve kurulum kimligi. Ikisi de Apple'in "Device ID"
      // kategorisine girer. Ozelligi acip beyani unutmak, denetimde en
      // sik yakalanan tutarsizliktir — bu yuzden BAGIMLILIKTAN olculur:
      // firebase_messaging pubspec'te varsa beyan da olmak ZORUNDA.
      final pubspec = _oku('pubspec.yaml');
      if (pubspec.contains('firebase_messaging:')) {
        expect(
          p,
          contains('NSPrivacyCollectedDataTypeDeviceID'),
          reason: 'push acik ama Device ID beyan edilmemis',
        );
      }
    });

    test('(P193) ANALITIK/REKLAM SDK YOK — beyanla tutarli', () {
      // "Tracking: No" ve "analitik SDK yok" iddiasi ancak bagimlilik
      // listesi bunu dogruluyorsa gecerlidir. Biri eklenirse bu test
      // duser ve beyanin gozden gecirilmesi gerektigini soyler.
      final pubspec = _oku('pubspec.yaml');
      for (final yasak in [
        'firebase_analytics',
        'firebase_crashlytics',
        'google_mobile_ads',
        'sentry_flutter',
        'appsflyer',
        'facebook_app_events',
      ]) {
        expect(
          pubspec.contains('$yasak:'),
          isFalse,
          reason: '$yasak eklenmis — App Privacy beyani guncellenmeli',
        );
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
    test('YALNIZ TAG bicimi — actigimiz TEK oturum turu', () {
      // Dizi, uygulamanin ACABILECEGI OTURUM TURLERINI beyan eder;
      // okuyabilecegi VERI turlerini degil.
      //   TAG  -> NFCTagReaderSession  (actigimiz tek oturum)
      //   NDEF -> NFCNDEFReaderSession (HIC acmiyoruz)
      // NDEF icerigini yine okuyoruz ama TAG oturumunun ICINDEN
      // (`NdefIos.from(tag)` -> tag.data.ndef), yani listeye NDEF
      // koymaya gerek yok.
      final e = _oku('ios/Runner/Runner.entitlements');
      expect(e, contains('com.apple.developer.nfc.readersession.formats'));
      expect(e, contains('<string>TAG</string>'),
          reason: 'TAG olmadan NFCTagReaderSession hic acilamaz');
      expect(
        e.contains('<string>NDEF</string>'),
        isFalse,
        reason: 'kullanmadigimiz oturum turu icin yetki istenmemeli '
            '(okadan/flutter-nfc-manager#91)',
      );
    });

    test('ISO7816 AID listesi BEYAN EDILMIS (DESFire baglantisi icin sart)',
        () {
      // CIHAZDA BULUNAN HATA. Etiketimiz NTAG424 DNA'dir ve iOS onu
      // MIFARE DESFire (ISO7816) olarak gorur. CoreNFC, bir ISO7816
      // etiketine `connect(to:)` yaparken uygulamanin SECEBILECEGI
      // uygulama kimliklerini ONCEDEN beyan etmis olmasini sart kosar;
      // liste yoksa baglanti "Missing required entitlement" ile
      // reddedilir — ret `nfcd`ye ULASMADAN, uygulama icinde olur.
      final plist = _oku('ios/Runner/Info.plist');
      expect(
        plist,
        contains(
          'com.apple.developer.nfc.readersession.iso7816.select-identifiers',
        ),
        reason: 'AID listesi yok — DESFire/NTAG424 etiketine BAGLANILAMAZ',
      );
      // NFC Forum Type 4 NDEF uygulamasi (v2 ve v1).
      expect(plist, contains('<string>D2760000850101</string>'));
      expect(plist, contains('<string>D2760000850100</string>'));
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

    test('YETKILENDIRME Runner hedefinin UC yapilandirmasina da BAGLI', () {
      // ESKI HALI SAYIYORDU, YERI OLCMUYORDU: "uc kez geciyor" demek,
      // ucunun de DOGRU hedefte oldugunu gostermez. Ayni uc satir
      // RunnerTests'e dusseydi eski test YINE GECERDI ve imzalanan
      // uygulama yetkilendirmesiz cikardi. Artik yapilandirma bloklari
      // AYRISTIRILIP hedefe gore denetleniyor.
      //
      // Cihaz belirtisi: "Missing required entitlement" — derleme
      // BASARILI gorunur, uygulama calismaz.
      final konfigler = _yapilandirmalar(proje);
      final runner = konfigler
          .where((k) => k.bundle == 'site.yonetio.app')
          .toList();
      expect(runner.length, 3,
          reason: 'Runner hedefinin Debug/Release/Profile yapilandirmasi');
      for (final k in runner) {
        expect(k.yetkilendirme, isTrue,
            reason:
                '${k.ad} yapilandirmasinda CODE_SIGN_ENTITLEMENTS yok — '
                'o yapimda NFC SESSIZCE calismaz (en sinsi hali: '
                'Debug\'da calisir, TestFlight yapiminda calismaz)');
      }
      // TEST PAKETINE SIZMAMALI: RunnerTests'in NFC yetenegi yoktur ve
      // yetkilendirme oraya dusse imzalama hatasi verirdi.
      for (final k in konfigler.where(
        (k) => k.bundle == 'site.yonetio.app.RunnerTests',
      )) {
        expect(k.yetkilendirme, isFalse, reason: 'RunnerTests: ${k.ad}');
      }
    });

    test('NFC YETENEGI proje ozniteliklerinde ACIK (Xcode ile ayni)', () {
      // Xcode'un "Signing & Capabilities" ekrani yetenegi eklerken
      // BUNU da yazar. Eksikse: (a) Xcode capability'yi "ekli
      // gormez" ve gelistirici elle ekleyince pbxproj DEGISIR —
      // her cekiste catisma; (b) otomatik imzalama akisi yetenegi
      // profile islemeyebilir.
      expect(
        proje,
        contains('com.apple.NearFieldCommunicationTagReading'),
        reason: 'TargetAttributes > SystemCapabilities girdisi yok',
      );
    });

    test('YEDEK KATMAN: yetkilendirme xcconfig\'lerde de tanimli', () {
      // pbxproj, Xcode ve Flutter'in "Upgrading project.pbxproj" gecisi
      // tarafindan YENIDEN YAZILABILIR; ayar dustugu anda uygulama
      // yetkilendirmesiz imzalanir. xcconfig Flutter tarafindan
      // URETILMEZ, dolayisiyla ayar orada kalir.
      for (final dosya in ['Debug', 'Release']) {
        expect(
          _oku('ios/Flutter/$dosya.xcconfig'),
          contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements'),
          reason: '$dosya.xcconfig yedegi kayboldu',
        );
      }
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
