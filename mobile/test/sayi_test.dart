// (P57) Para OLMAYAN sayilarin ayristirilmasi.
//
// Kusur: NFC noktasi ekraninda koordinat `double.tryParse` ile
// okunuyordu ve TURKCE KLAVYEDE ONDALIK TUSU VIRGULDUR. `41,0082`
// yazan kullanicida `double.tryParse` null doner, null da `gpsLat`
// alanina gidip "alani temizle" anlamina gelirdi: koordinat SESSIZCE
// siliniyordu. Panelde ayni sinif alti yerde bulunmustu (P56).
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/sayi.dart';

void main() {
  group('sayiCoz', () {
    test('BOS ile GECERSIZ ayrilir — asil kusur buydu', () {
      expect(sayiCoz('').tur, SayiTuru.bos);
      expect(sayiCoz('   ').tur, SayiTuru.bos);
      expect(sayiCoz('kuzey').tur, SayiTuru.gecersiz);
    });

    test('Turkce yazim (virgullu ondalik) kabul edilir', () {
      expect(sayiCoz('41,0082').deger, closeTo(41.0082, 1e-9));
      expect(sayiCoz('-29,0123').deger, closeTo(-29.0123, 1e-9));
    });

    test('ingilizce klavyeden gelen NOKTA ondaligi da kabul edilir', () {
      // Kullaniciya klavyesini degistirtmek bir cozum degildir.
      expect(sayiCoz('41.00').deger, closeTo(41.0, 1e-9));
    });

    test('binlik ayirici para ile AYNI kurala baglidir', () {
      expect(sayiCoz('1.250').deger, 1250);
      expect(sayiCoz('1.250,75').deger, closeTo(1250.75, 1e-9));
    });

    test('YARIM giris ve icerideki bosluk reddedilir', () {
      for (final g in ['41,', ',5', '41.', '.5', '1 2 3']) {
        expect(sayiCoz(g).tur, SayiTuru.gecersiz, reason: g);
      }
    });
  });
}
