/// (P211 §6) IOS PUSH ZINCIRI — Mac olmadan dogrulanabilen halkalar.
///
/// ===========================================================================
/// OLCULEN KUSUR
/// ===========================================================================
/// "iOS'ta bildirim gelmiyor" sikayetinin en somut sebebi bulundu:
/// `Runner.entitlements` dosyasinda **`aps-environment` YOKTU** ve
/// projede **Push Notifications yetenegi isaretli degildi**.
///
/// Zincir su sirayla kopuyordu:
///   `aps-environment` yok -> `registerForRemoteNotifications` APNs
///   jetonu ALMAZ -> FCM `getToken()` null/`apns-token-not-set` -> cihaz
///   sunucuya HIC kaydolmaz -> hicbir bildirim gelmez.
/// Android tarafi calisirken iOS'un sessiz kalmasinin dogal aciklamasi
/// budur ve hicbir kod hatasi gorunmez, cunku her katman sessizce
/// null'a duser.
///
/// BU DOSYANIN OLCEMEDIGI: APNs Auth Key'in (.p8) Firebase konsoluna
/// yuklenip yuklenmedigi ve App ID'de yetenegin acik olup olmadigi.
/// Ikisi de Apple/Firebase konsolundadir; adimlar
/// `docs/P211-kararlar.md` §6 listesinde.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _oku(String yol) => File(yol).readAsStringSync();

void main() {
  test('entitlements: aps-environment VAR', () {
    final e = _oku('ios/Runner/Runner.entitlements');
    expect(
      e.contains('<key>aps-environment</key>'),
      isTrue,
      reason: 'Bu anahtar olmadan cihaz APNs jetonu ALMAZ; iOS bildirimi '
          'HIC gelmez ve hicbir katman hata gostermez.',
    );
    // DEGER `development` OLMALI: Xcode dagitimda `production` ile
    // degistirir. Elle `production` yazmak, cihaza dogrudan kurulan
    // (development imzali) yapida jetonun alinmamasina yol acardi.
    expect(e, contains('<string>development</string>'));
  });

  test('pbxproj: Push Notifications yetenegi ISARETLI', () {
    expect(_oku('ios/Runner.xcodeproj/project.pbxproj'), contains('com.apple.Push'));
  });

  test('GoogleService-Info paket kimligi Runner ile AYNI', () {
    // Farkli olsaydi Firebase SDK'si baslar ama jeton BASKA bir uygulama
    // icin uretilirdi; gonderim sessizce hicbir cihaza ulasmazdi.
    final g = _oku('ios/Runner/GoogleService-Info.plist');
    expect(g, contains('site.yonetio.app'));
    expect(_oku('ios/Runner.xcodeproj/project.pbxproj'),
        contains('PRODUCT_BUNDLE_IDENTIFIER = site.yonetio.app;'));
  });

  test('OZEL SES dosyalari iOS PAKETINDE', () {
    // iOS'ta ozel ses UYGULAMA PAKETINDEDIR; sunucu yalniz adini gonderir
    // (`aps.sound = "yonetio_bildirim.caf"`). Dosya pakette yoksa iOS
    // SESSIZCE varsayilan sese duser.
    for (final ad in ['yonetio_bildirim', 'yonetio_vardiya', 'yonetio_gurultu']) {
      expect(File('ios/Runner/$ad.caf').existsSync(), isTrue, reason: ad);
    }
  });

  test('istemci: FCM jetonu APNs jetonundan SONRA istenir', () {
    // Sirayi bozmak, jetonun sessizce null donmesi demekti (olculen
    // sinif). Kaynak taramasi burada mesru: davranis gercek Firebase
    // ornegine bagli ve birim testinde surulemiyor — kilit, sıranın
    // koddan KAYBOLMAMASI.
    final k = _oku('lib/src/features/push/data/push_messaging.dart');
    expect(k, contains('getAPNSToken'));
    expect(k.indexOf('_apnsJetonunuBekle'), lessThan(k.indexOf('return await FirebaseMessaging.instance.getToken()')));
  });
}
