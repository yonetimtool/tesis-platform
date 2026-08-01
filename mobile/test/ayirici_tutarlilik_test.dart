// (P77) IKI AYRISTIRICI, TEK AYIRICI KURALI.
//
// `core/para.dart` (kurus tam sayisi) ve `core/sayi.dart` (ondalikli
// deger) AYRI donus tipleri uretir ama AYIRICI KURALI ayni olmak
// zorundadir: kullanici metrekare alaninda ve tutar alaninda ayni yazimi
// kullanabilmeli. Ikisi ayrisirsa, ayni sitede ayni metin iki farkli sayi
// girer — P49/P50'nin panel-mobil arasinda buldugu kusurun ayni evin
// icindeki hali.
//
// Bu test DEGERLERI degil, KABUL/RED kararini karsilastirir: para
// ayristiricisi iki basamak kisiti ve isaret POLITIKASI tasir (negatif
// reddedilir), sayi ayristiricisi tasimaz. Ortusen alanda ikisi AYNI
// karari vermelidir.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/para.dart';
import 'package:mobile/src/core/sayi.dart';

void main() {
  // Politika farki OLMAYAN girdiler: pozitif, en fazla iki ondalik hane.
  const kabulEdilmeli = [
    '1250', '1250,50', '1250.50', '1.250', '1.250,00', '0', '0,05',
  ];
  const reddedilmeli = [
    '', '  ', 'abc', '1250,', ',50', '1250.', '.50', '1 2 3',
    // `1,234` BURADA DEGIL: para onu reddeder (kurus iki hanedir) ama
    // sayi kabul eder (1,234). Bu bir AYIRICI farki degil, POLITIKA
    // farkidir ve asagida ayrica test edilir. Ortak listeye koymak,
    // dogru davranisi tutarsizlik gibi gostermek olurdu.
  ];

  group('ayirici kurali iki ayristiricida AYNI', () {
    for (final g in kabulEdilmeli) {
      test('KABUL: "$g"', () {
        expect(tlMetniniKurusaCevir(g), isNotNull, reason: 'para');
        expect(sayiCoz(g).tur, SayiTuru.sayi, reason: 'sayi');
      });
    }

    for (final g in reddedilmeli) {
      test('RED: "$g"', () {
        expect(tlMetniniKurusaCevir(g), isNull, reason: 'para');
        // Bos girdi `sayiCoz`ta AYRI bir durumdur (bos != gecersiz);
        // ortak olan sey "sayi URETMEZ"dir.
        expect(sayiCoz(g).tur, isNot(SayiTuru.sayi), reason: 'sayi');
      });
    }
  });

  group('politika farki BILINCLI', () {
    test('negatif: para REDDEDER, sayi kabul eder', () {
      // Isaret bir BICIM degil ALAN kuralidir: tutar negatif olamaz ama
      // bir olcu/fark negatif olabilir. Bu ayrim kasitlidir.
      expect(tlMetniniKurusaCevir('-5'), isNull);
      expect(sayiCoz('-5').deger, -5);
    });

    test('uc ondalik hane: para REDDEDER (kurus iki hanedir)', () {
      expect(tlMetniniKurusaCevir('1,234'), isNull);
    });

    test('bos girdi: sayi BOS der, para null', () {
      expect(sayiCoz('').tur, SayiTuru.bos);
      expect(tlMetniniKurusaCevir(''), isNull);
    });
  });
}
