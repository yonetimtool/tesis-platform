/// (P195) iOS IZIN AMAC METINLERI — KILIT.
///
/// ===========================================================================
/// NEDEN VAR: BU HATA YUKLEMEDE DEGIL BURADA CIKMALIYDI
/// ===========================================================================
/// App Store Connect yuklemeyi reddetti:
///
///     Missing purpose string in Info.plist ... should contain a
///     NSLocationAlwaysAndWhenInUseUsageDescription key with a
///     user-facing purpose string  (90683)
///
/// Anahtar EKSIKTI ve hicbir sey bunu soylemiyordu: eksiklik ancak Mac'te
/// derleyip Apple'a yukledikten SONRA, insan eliyle gorulebiliyordu. Bir
/// eksigi ogrenmenin en pahali yolu budur.
///
/// ===========================================================================
/// NE OLCULUYOR
/// ===========================================================================
///   1. ZORUNLU ANAHTARLAR Info.plist'te VAR ve metni BOS DEGIL.
///   2. YERELLESTIRME AYRISMIYOR: `en.lproj` ve `tr.lproj` AYNI anahtar
///      kumesini tasiyor. `InfoPlist.strings` Info.plist'i EZER; bir
///      anahtar yalniz birinde olursa o dildeki cihazda YANLIS (ya da
///      cevrilmemis) metin gorunur.
///   3. YENI ANAHTAR SESSIZCE EKLENMEZ: Info.plist'e bir amac metni
///      eklenip ceviriler unutulursa test duser.
///
/// ===========================================================================
/// NE OLCULMUYOR (bilincli)
/// ===========================================================================
/// Metnin Apple'in inceleme kurallarina UYGUNLUGU. "Yaniltici mi" sorusu
/// bir insan kararidir; test yalnizca VARLIGI ve YERELLESTIRME BUTUNLUGUNU
/// kilitler. Metnin dogrulugu icin `ios/Runner/Info.plist` icindeki
/// gerekce notlari okunmalidir (konumun tek kullanim yeri orada yazili).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Uygulamanin GERCEKTEN kullandigi izinler.
///
/// `NSLocationAlwaysAndWhenInUseUsageDescription` LISTEDE ve bu bilincli:
/// uygulama "always" iznini ISTEMEZ (geolocator, WhenInUse anahtari
/// varken o dala hic girmez) ama geolocator ikilisi ilgili API'ye
/// referans verdigi icin App Store Connect anahtari ZORUNLU tutar.
/// Anahtari silmek yuklemeyi yeniden kirar.
const _zorunluAnahtarlar = <String>{
  'NFCReaderUsageDescription',
  'NSCameraUsageDescription',
  'NSPhotoLibraryUsageDescription',
  'NSLocationWhenInUseUsageDescription',
  'NSLocationAlwaysAndWhenInUseUsageDescription',
};

/// Yerellestirilmis diller — `ios/Runner/<dil>.lproj/InfoPlist.strings`.
const _diller = <String>['en', 'tr'];

File _dosya(String yol) {
  final f = File(yol);
  if (!f.existsSync()) {
    // Testler depo kokunden de, `mobile/`den de kosabilir.
    final alt = File('mobile/$yol');
    if (alt.existsSync()) return alt;
  }
  return f;
}

/// Info.plist'teki `<key>X</key><string>Y</string>` ciftleri.
Map<String, String> _plistAmacMetinleri(String icerik) {
  final sonuc = <String, String>{};
  final desen = RegExp(
    r'<key>([A-Za-z]*UsageDescription)</key>\s*<string>(.*?)</string>',
    dotAll: true,
  );
  for (final e in desen.allMatches(icerik)) {
    sonuc[e.group(1)!] = e.group(2)!.trim();
  }
  return sonuc;
}

/// `InfoPlist.strings` icindeki `"X" = "Y";` ciftleri (yorumlar atlanir).
Map<String, String> _stringsAmacMetinleri(String icerik) {
  final sonuc = <String, String>{};
  final yorumsuz = icerik.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  final desen = RegExp(r'"([A-Za-z]*UsageDescription)"\s*=\s*"(.*?)"\s*;',
      dotAll: true);
  for (final e in desen.allMatches(yorumsuz)) {
    sonuc[e.group(1)!] = e.group(2)!.trim();
  }
  return sonuc;
}

void main() {
  final plist = _plistAmacMetinleri(
      _dosya('ios/Runner/Info.plist').readAsStringSync());

  test('ZORUNLU izin metinleri Info.plist icinde VAR ve BOS DEGIL', () {
    final eksik = _zorunluAnahtarlar.difference(plist.keys.toSet());
    expect(eksik, isEmpty,
        reason: 'Info.plist bu amac metinlerini TASIMIYOR — Apple yuklemeyi '
            '90683 ile reddeder: ${eksik.join(", ")}');
    for (final anahtar in _zorunluAnahtarlar) {
      expect(plist[anahtar], isNotEmpty,
          reason: '$anahtar BOS: Apple bos amac metnini de reddeder');
    }
  });

  test('AMAC METINLERI yeterince ACIKLAYICI (yer tutucu degil)', () {
    for (final giris in plist.entries) {
      // Apple "TODO"/"test" gibi yer tutuculari reddeder; ayrica tek
      // kelimelik bir metin kullaniciya NEDEN sorusunu yanitlamaz.
      expect(giris.value.length, greaterThan(30),
          reason: '${giris.key} cok kisa — kullaniciya amaci anlatmiyor');
      expect(giris.value.toLowerCase(), isNot(contains('todo')),
          reason: '${giris.key} yer tutucu metin tasiyor');
    }
  });

  for (final dil in _diller) {
    test('$dil.lproj/InfoPlist.strings anahtar kumesi Info.plist ile AYNI',
        () {
      final yerel = _stringsAmacMetinleri(
          _dosya('ios/Runner/$dil.lproj/InfoPlist.strings').readAsStringSync());

      // `InfoPlist.strings` Info.plist'i EZER: eksik bir anahtar, o dildeki
      // cihazda TEMEL DILDEKI metni gosterir (ya da hic gostermez).
      final eksik = plist.keys.toSet().difference(yerel.keys.toSet());
      expect(eksik, isEmpty,
          reason: '$dil cevirisi EKSIK: ${eksik.join(", ")}');

      // Ters yon de onemli: silinmis bir anahtarin cevirisi kalirsa,
      // hangi metnin gecerli oldugu belirsizlesir.
      final fazla = yerel.keys.toSet().difference(plist.keys.toSet());
      expect(fazla, isEmpty,
          reason: '$dil cevirisinde Info.plist\'te OLMAYAN anahtar var: '
              '${fazla.join(", ")}');

      for (final anahtar in yerel.keys) {
        expect(yerel[anahtar], isNotEmpty, reason: '$dil/$anahtar BOS');
      }
    });
  }

  test('KONUM metinleri arka plan takibi IMA ETMIYOR', () {
    // Uygulama konumu YALNIZ okutma aninda alir (tek atis
    // `getCurrentPosition`; akis ve `UIBackgroundModes` YOK). Arka plan
    // takibi ima eden bir metin YANILTICI olurdu ve Apple bunu reddeder.
    for (final dil in _diller) {
      final yerel = _stringsAmacMetinleri(
          _dosya('ios/Runner/$dil.lproj/InfoPlist.strings').readAsStringSync());
      final always = yerel['NSLocationAlwaysAndWhenInUseUsageDescription']!;
      final iddia = always.toLowerCase();
      expect(
        iddia.contains('arka planda konumunuzu izlemez') ||
            iddia.contains('does not track your location in the background'),
        isTrue,
        reason: '$dil: "always" metni arka planda IZLEMEDIGIMIZI acikca '
            'soylemeli — uygulama o izni hic istemiyor',
      );
    }
  });
}
