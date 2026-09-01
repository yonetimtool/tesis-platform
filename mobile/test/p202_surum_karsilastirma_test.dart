/// (P202) SURUM KARSILASTIRMASI — sinir durumlari (Dart tarafi).
///
/// Sunucudaki `tests/test_p202_surum_karsilastirma.py` ile AYNI vakalar:
/// iki taraf ayni kurali uyguladigini KANITLAMALI, iddia etmemeli.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/surum/domain/surum_karsilastir.dart';

void main() {
  group('karsilastirma', () {
    final vakalar = <List<Object>>[
      // ISTEKTE ACIKCA SORULAN SINIRLAR
      ['1.9.0', '1.10.0', -1],
      ['1.10.0', '1.9.0', 1],
      ['1.1.1', '1.1.10', -1],
      ['1.1.10', '1.1.1', 1],
      ['1.1.1', '1.1.1', 0],
      // Genel
      ['2.0.0', '1.99.99', 1],
      ['0.9.9', '1.0.0', -1],
      // Eksik parca SIFIR
      ['1.2', '1.2.0', 0],
      ['1', '1.0.0', 0],
      ['1.2', '1.2.1', -1],
      // Yapim numarasi karsilastirmaya GIRMEZ
      ['1.1.1+6', '1.1.1', 0],
      ['1.1.1+9', '1.1.2', -1],
      ['1.1.1-beta', '1.1.1', 0],
    ];
    for (final v in vakalar) {
      test('${v[0]} vs ${v[1]} = ${v[2]}', () {
        expect(surumKarsilastir(v[0] as String, v[1] as String), v[2]);
      });
    }

    test('METIN karsilastirmasi bu vakada TERS sonuc verirdi', () {
      // Kusurun kendisi kayit altina alinir: birisi bir gun
      // `compareTo`ya donerse bu test onu yakalar.
      expect('1.10.0'.compareTo('1.9.0') < 0, isTrue,
          reason: 'metin karsilastirmasi 1.10.0u ESKI sayar');
      expect(surumKarsilastir('1.10.0', '1.9.0'), 1);
    });
  });

  group('gecersiz bicim', () {
    for (final g in ['', 'surum-3', '1.2.3.4', 'a.b.c', '1.2.x', ' ', 'v1.2.3']) {
      test('"$g" -> null', () => expect(surumAyristir(g), isNull));
    }
    test('null -> null', () => expect(surumAyristir(null), isNull));

    test('BELIRSIZLIKTE ENGELLEME YOK', () {
      expect(surumEskiMi('1.0.0', 'surum-3'), isFalse);
      expect(surumEskiMi('bozuk', '9.9.9'), isFalse);
      expect(surumEskiMi(null, '9.9.9'), isFalse);
      expect(surumEskiMi('1.0.0', null), isFalse);
    });
  });

  test('ESIGIN KENDISI kabul edilir', () {
    expect(surumEskiMi('1.2.0', '1.2.0'), isFalse);
    expect(surumEskiMi('1.1.9', '1.2.0'), isTrue);
  });
}
