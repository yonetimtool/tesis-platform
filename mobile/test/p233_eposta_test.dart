/// (P233 §4) E-POSTA KURALI — panel ikiziyle AYNI tablo
/// (`admin-web/tests/eposta.test.ts`).
///
/// İki yüzey ayrışırsa kullanıcı panelde kabul edilen bir adresi mobilde
/// reddedilmiş görür.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/ui/eposta.dart';

const _gecerli = [
  'ayse@ornek.com',
  'a.b+etiket@alt.ornek.co.uk',
  'AYSE@ORNEK.COM',
  '  bosluklu@ornek.com  ',
];

const _bozuk = [
  'ayse',
  'ayse@',
  '@ornek.com',
  'ayse@ornek',
  'ayse@@ornek.com',
  'ay se@ornek.com',
  'ayse@.com',
  'ayse@ornek.',
  '.ayse@ornek.com',
  'ayse..b@ornek.com',
];

void main() {
  test('GECERLI adresler -> null', () {
    for (final e in _gecerli) {
      expect(epostaHatasi(e), isNull, reason: e);
    }
  });

  test('BOZUK bicim -> bicim', () {
    for (final e in _bozuk) {
      expect(epostaHatasi(e), EpostaHatasi.bicim, reason: e);
    }
  });

  test('BOS: zorunluysa hata, degilse gecerli', () {
    expect(epostaHatasi(''), EpostaHatasi.bos);
    expect(epostaHatasi('   '), EpostaHatasi.bos);
    expect(epostaHatasi('', zorunlu: false), isNull);
  });

  test('YEREL KISIM 64u gecemez (RFC 5321)', () {
    expect(epostaHatasi('${'a' * kEpostaYerelSinir}@ornek.com'), isNull);
    expect(
      epostaHatasi('${'a' * (kEpostaYerelSinir + 1)}@ornek.com'),
      EpostaHatasi.yerelUzun,
    );
  });

  test('TOPLAM 254u gecemez', () {
    final uzun = '${'a' * 10}@${'b' * 240}.com';
    expect(uzun.length, greaterThan(kEpostaSinir));
    expect(epostaHatasi(uzun), EpostaHatasi.cokUzun);
  });

  test('UZUNLUK bicimden ONCE sorulur', () {
    // Cok uzun VE bozuk bir adreste kullanici asil engeli gormeliydi;
    // "bicim gecersiz" deyip uzunlugu gizlemek, adresi duzeltip yine
    // reddedilmesine yol acardi.
    expect(epostaHatasi('a' * 300), EpostaHatasi.cokUzun);
  });

  test('epostaNormalle kirpar ve KUCUK HARFE indirir', () {
    expect(epostaNormalle('  Ayse@Ornek.COM '), 'ayse@ornek.com');
  });
}
