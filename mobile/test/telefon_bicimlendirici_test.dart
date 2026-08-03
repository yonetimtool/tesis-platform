/// (P123) TELEFON BİÇİMLENDİRİCİ — yazma, yapıştırma, silme, taşma, ön ek.
///
/// Bu dosya ÜRÜN DAVRANIŞINI ölçer, uygulamayı değil: biçimlendirici saf
/// bir dönüşümdür ve altı ekranın altısı da onu kullanır. Bir alan
/// migrasyondan geride kalırsa `telefon_alani_kapsam_test.dart` yakalar.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/ui/telefon_alani.dart';

/// Biçimlendiriciyi ardışık tuş vuruşlarıyla besler.
TextEditingValue _yaz(String tuslar) {
  const b = TelefonBicimlendirici();
  var v = TextEditingValue.empty;
  for (final t in tuslar.split('')) {
    final ham = v.text + t;
    v = b.formatEditUpdate(
      v,
      TextEditingValue(
        text: ham,
        selection: TextSelection.collapsed(offset: ham.length),
      ),
    );
  }
  return v;
}

/// Tek seferde yapıştırma.
TextEditingValue _yapistir(String metin) => const TelefonBicimlendirici()
    .formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: metin,
        selection: TextSelection.collapsed(offset: metin.length),
      ),
    );

void main() {
  group('telefonHaneleri', () {
    test('YEREL bicim', () => expect(telefonHaneleri('0543 199 29 04'), '5431992904'));
    test('E.164', () => expect(telefonHaneleri('+905431992904'), '5431992904'));
    test('00 ulke kodu', () => expect(telefonHaneleri('00905431992904'), '5431992904'));
    test('ulke kodsuz', () => expect(telefonHaneleri('5431992904'), '5431992904'));
    test('tire/parantez ATILIR',
        () => expect(telefonHaneleri('(0543) 199-29-04'), '5431992904'));

    test('`90` ile BASLAYAN GECERLI numara ulke kodu SANILMAZ', () {
      // `9053…` diye bir cep numarasi yok ama kural yine de dikkatli:
      // `90` YALNIZ fazladan hane varken soyulur. 10 haneli bir girdi
      // oldugu gibi kalir.
      expect(telefonHaneleri('9012345678'), '9012345678');
    });

    test('TASMA kirpilir', () {
      expect(telefonHaneleri('054319929041234'), '5431992904');
      expect(telefonHaneleri('5431992904').length, kTelefonHaneSayisi);
    });
  });

  group('telefonBicimle', () {
    test('TAM numara gruplanir',
        () => expect(telefonBicimle('5431992904'), '0543 199 29 04'));
    test('KISMI numara da gruplanir', () {
      expect(telefonBicimle('5'), '05');
      expect(telefonBicimle('543'), '0543');
      expect(telefonBicimle('5431'), '0543 1');
      expect(telefonBicimle('543199'), '0543 199');
      expect(telefonBicimle('54319929'), '0543 199 29');
    });
    test('BOS -> bos', () => expect(telefonBicimle(''), ''));
  });

  group('yazarken', () {
    test('rakamlar GRUPLANARAK cizilir', () {
      expect(_yaz('05431992904').text, '0543 199 29 04');
    });

    test('BASTA 0 YAZILMASA da bicim ayni', () {
      expect(_yaz('5431992904').text, '0543 199 29 04');
    });

    test('RAKAM DISI karakter YUTULUR', () {
      expect(_yaz('0a5b4c3d1e992904').text, '0543 199 29 04');
    });

    test('FAZLA HANE YAZILAMAZ (sert sinir)', () {
      // 10 hane dolduktan sonraki her tus metni DEGISTIRMEZ.
      final v = _yaz('054319929041111');
      expect(v.text, '0543 199 29 04');
      expect(telefonHaneleri(v.text).length, kTelefonHaneSayisi);
    });

    test('IMLEC metnin SONUNDA kalir (her tusta basa siframaz)', () {
      final v = _yaz('05431');
      expect(v.selection.baseOffset, v.text.length);
    });
  });

  group('yapistirma', () {
    for (final ham in [
      '+905431992904',
      '905431992904',
      '05431992904',
      '5431992904',
      '+90 543 199 29 04',
      '0543-199-29-04',
    ]) {
      test('`$ham` -> 0543 199 29 04', () {
        expect(_yapistir(ham).text, '0543 199 29 04');
      });
    }
  });

  group('geri silme', () {
    test('SON hane silinince bicim kisalir', () {
      const b = TelefonBicimlendirici();
      final tam = _yaz('05431992904');
      // Kullanici son karakteri siler.
      final kisa = tam.text.substring(0, tam.text.length - 1);
      final v = b.formatEditUpdate(
        tam,
        TextEditingValue(
          text: kisa,
          selection: TextSelection.collapsed(offset: kisa.length),
        ),
      );
      expect(v.text, '0543 199 29 0');
    });

    test('BOSLUK silinince hane KAYBOLMAZ', () {
      // "0543 199 29 04" icinde bosluk silmek bir HANE silmemeli; aksi
      // halde kullanici gorunmez bir veri kaybi yasar.
      const b = TelefonBicimlendirici();
      final tam = _yaz('05431992904');
      const bosluksuz = '0543199 29 04'; // ilk bosluk silindi
      final v = b.formatEditUpdate(
        tam,
        const TextEditingValue(
          text: bosluksuz,
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      expect(telefonHaneleri(v.text), '5431992904');
    });
  });

  group('telefonNormalle', () {
    test('E.164 uretir',
        () => expect(telefonNormalle('0543 199 29 04'), '+905431992904'));
    test('zaten E.164 olan DEGISMEZ',
        () => expect(telefonNormalle('+905431992904'), '+905431992904'));
    test('BOS -> bos (istege bagli alanlar temizlenebilsin)',
        () => expect(telefonNormalle(''), ''));
  });

  group('telefonHatasi', () {
    test('GECERLI numara -> null',
        () => expect(telefonHatasi('0543 199 29 04'), isNull));

    test('EKSIK hane', () {
      expect(telefonHatasi('0543 199'), TelefonHatasi.eksik);
    });

    test('SABIT HAT ON EKI reddedilir', () {
      // `0212…` bir cep numarasi degildir ve SMS gitmez; kullanici bunu
      // KAYDETMEDEN once ogrenmeli.
      expect(telefonHatasi('0212 555 44 33'), TelefonHatasi.gecersizOnEk);
      expect(telefonHatasi('0312 555 44 33'), TelefonHatasi.gecersizOnEk);
    });

    test('BOS: zorunluysa hata, degilse gecerli', () {
      expect(telefonHatasi(''), TelefonHatasi.bos);
      expect(telefonHatasi('', zorunlu: false), isNull);
    });

    test('BILINMEYEN ama 5 ile baslayan blok KABUL edilir', () {
      // BTK yeni blok tahsis edebilir; kural "kapali liste" DEGIL.
      expect(telefonHatasi('0599 123 45 67'), isNull);
    });
  });
}
