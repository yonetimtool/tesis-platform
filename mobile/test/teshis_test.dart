/// (P119) CİHAZ TEŞHİSİ — maskeleme + kanalın iki ucunun aynı olması.
///
/// NEDEN: teşhis günlüğü ekran görüntüsüyle paylaşılır ve hata kaydına
/// yapıştırılır. Saha kameralarının adresleri gerçek dünyada
/// `rtsp://kullanici:parola@10.0.0.5/...` biçimindedir — maskeleme
/// bozulursa, teşhis uğruna kalıcı bir parola sızıntısı açılır.
///
/// İkinci ölçüm daha sıradan ama iki tur kaybettiren sınıftandır: Dart
/// tarafındaki kanal adı ile `AppDelegate.swift`teki ad **ayrışırsa**
/// teşhis hiç çalışmaz ve — en kötüsü — sessizce çalışmaz.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/teshis/teshis.dart';

const _appDelegate = 'ios/Runner/AppDelegate.swift';
const _plist = 'ios/Runner/Info.plist';

void main() {
  group('adresMaskele', () {
    test('KIMLIK BILGISI atilir, konak ve yol KALIR', () {
      final m = adresMaskele('rtsp://admin:S3cret!@10.0.0.5:554/live/ch1');
      expect(m, isNot(contains('S3cret')));
      expect(m, isNot(contains('admin')));
      // Teshisi yapan sey konak + yol + port: bunlar korunmali.
      expect(m, contains('10.0.0.5'));
      expect(m, contains('554'));
      expect(m, contains('/live/ch1'));
      expect(m, contains('***@'), reason: 'kimlik VARDI, bu bilgi kaybolmamali');
    });

    test('SORGU atilir ama VARLIGI bildirilir', () {
      // Imzali jeton (`?token=...`) tam olarak sizdirilmemesi gereken sey;
      // ama "adres sorgu tasiyor mu" bazen tek ayirt edici bilgidir.
      final m = adresMaskele('https://gecit.ornek/hls/1.m3u8?token=abc123def');
      expect(m, isNot(contains('abc123def')));
      expect(m, contains('+sorgu('));
      expect(m, contains('/hls/1.m3u8'));
    });

    test('KIMLIK YOKKEN "***@" EKLENMEZ', () {
      final m = adresMaskele('https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8');
      expect(m, isNot(contains('***')));
      expect(m, 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8');
    });

    test('BOZUK adres icerigi YAZILMAZ, uzunlugu yazilir', () {
      // Yapistirma artigi tasiyan adres teshisin en sik konusu; ama
      // icerigini gunluge dokmek yine sizinti olurdu.
      final m = adresMaskele('https://ornek /gizli-yol?token=xyz');
      expect(m, isNot(contains('gizli-yol')));
      expect(m, isNot(contains('xyz')));
      expect(m, contains('karakter'));
    });

    test('BOS adres ayirt edilir', () {
      expect(adresMaskele('   '), '(bos)');
    });
  });

  group('kanalin IKI UCU ayni', () {
    test('Dart kanal adi = AppDelegate.swift kanal adi', () {
      final swift = File(_appDelegate).readAsStringSync();
      expect(swift, contains('"${teshisKanali.name}"'),
          reason: 'kanal adlari ayrisirsa teshis SESSIZCE calismaz');
    });

    test('AppDelegate BEKLENEN anahtarlarin hepsini dondurur', () {
      // Dart tarafi bu adlarla okuyor; biri dusunce ekranda "YOK" yazar
      // ve YANLIS teshise goturur ("ATS anahtari pakete girmemis" gibi).
      final swift = File(_appDelegate).readAsStringSync();
      for (final anahtar in [
        'paket', 'surum', 'yapim',
        'atsVar', 'atsMedya', 'atsKeyfi',
        'nfcAciklama', 'nfcAid', 'nfcFelica',
      ]) {
        expect(swift, contains('koy("$anahtar"'), reason: anahtar);
      }
    });

    test('teshis kanali GERCEKTEN kayit ediliyor', () {
      // Yalniz fonksiyonun VAR olmasi yetmez; cagrilmiyorsa kanal yok.
      final swift = File(_appDelegate).readAsStringSync();
      expect(swift, contains('kurTeshisKanali(engineBridge.pluginRegistry)'));
    });
  });

  group('teshisin OLCTUGU Info.plist gercekleri', () {
    test('ATS medya istisnasi KAYNAKTA var', () {
      // Cihazda "pakete girdi mi" sorusunu teshis kanali yanitlar; bu
      // test yalniz KAYNAGIN dogru oldugunu sabitler — ikisi birlikte
      // "kaynak dogru + pakete girdi" zincirini kapatir.
      final plist = File(_plist).readAsStringSync();
      expect(plist, contains('NSAppTransportSecurity'));
      expect(plist, contains('NSAllowsArbitraryLoadsForMedia'));
    });

    test('KEYFI yukleme ACILMAMIS (dar istisna korunuyor)', () {
      // `NSAllowsArbitraryLoads` tum URLSession trafigini de acardi —
      // API cagrilari dahil. Kamera yayini icin gereken sey bu DEGIL.
      final plist = File(_plist).readAsStringSync();
      expect(plist.contains('NSAllowsArbitraryLoads<'), isFalse);
      expect(plist.contains('<key>NSAllowsArbitraryLoads</key>'), isFalse);
    });
  });
}
