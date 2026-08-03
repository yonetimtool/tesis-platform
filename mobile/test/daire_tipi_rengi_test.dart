/// (P122) TİP RENGİ — mobil ile panelin AYNI rengi üretmesi kilidi.
///
/// NEDEN KİLİT: aynı daire tipi iki yüzeyde **aynı** rengi almalıdır.
/// Yönetici panelde bakıp mobilde doğruluyor; renk ayrışırsa iki ekrandan
/// biri "yanlış" görünür ve güven kaybı teknik bir hatadan pahalıya patlar.
/// İki ayrı dilde yazılmış iki fonksiyonun aynı kalmasını ancak PAYLAŞILAN
/// bir beklenen-değer tablosu garanti eder: aşağıdaki tablonun AYNISI
/// `admin-web/tests/daire-tipi-rengi.test.ts` içinde de var. Biri
/// değiştirilirse o taraf düşer.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/building_map/presentation/daire_tipi_rengi.dart';

/// PAYLAŞILAN TABLO — panel testiyle BİREBİR aynı.
const _beklenen = <String, int>{
  '2+1': 0xFF3949AB,
  '3+1': 0xFF00897B,
  '1+1': 0xFF5D4037,
  '4+1': 0xFF8E24AA,
  'Dubleks': 0xFF8E24AA,
  'Dükkan': 0xFF00838F,
  'Villa': 0xFFC62828,
  'Stüdyo': 0xFF5D4037,
  'Bahçe Katı': 0xFF43A047,
  'Çatı Katı': 0xFF43A047,
};

void main() {
  group('daireTipiRengi', () {
    test('PAYLASILAN TABLOYU birebir uretir (panel ile ayni)', () {
      _beklenen.forEach((ad, deger) {
        expect(daireTipiRengi(ad).toARGB32(), deger, reason: 'tip: $ad');
      });
    });

    test('BOS/null -> varsayilan indigo', () {
      expect(daireTipiRengi(null), daireTipiPaleti.first);
      expect(daireTipiRengi(''), daireTipiPaleti.first);
      expect(daireTipiRengi('   '), daireTipiPaleti.first);
    });

    test('BUYUK/kucuk harf ve bosluk FARK ETMEZ', () {
      // Yonetici tipi " 2+1 " diye girse de ayni rengi gormeli.
      expect(daireTipiRengi(' 2+1 '), daireTipiRengi('2+1'));
      expect(daireTipiRengi('DUBLEKS'), daireTipiRengi('dubleks'));
    });

    test('KARARLI: ayni ad her cagride ayni rengi verir', () {
      final bir = daireTipiRengi('Bahçe Katı');
      for (var i = 0; i < 50; i++) {
        expect(daireTipiRengi('Bahçe Katı'), bir);
      }
    });

    test('palet DISINA cikmaz', () {
      for (final ad in ['a', 'bb', 'ccc', 'çç', '🏠 Daire', 'x' * 200]) {
        expect(daireTipiPaleti, contains(daireTipiRengi(ad)));
      }
    });
  });

  group('daireTipiKisa', () {
    test('KISA ad oldugu gibi kalir', () {
      expect(daireTipiKisa('2+1'), '2+1');
      expect(daireTipiKisa('Dubleks'), 'Dubleks');
    });

    test('UZUN ad kirpilir; SONUC sinir kadar uzun olur', () {
      // Sinir SONUCUN uzunlugudur (nokta dahil): 7'de "Dublek" + "…".
      expect(daireTipiKisa('Dubleks Bahçe Katı'), 'Dublek…');
      expect(daireTipiKisa('Dubleks Bahçe Katı').length, 7);
    });

    test('BOS ad bos doner', () {
      expect(daireTipiKisa(null), '');
      expect(daireTipiKisa('  '), '');
    });
  });
}
