/// (P123 · P233 §3) TELEFON BİÇİMLENDİRİCİ — yazma, yapıştırma, silme,
/// taşma, ön ek, ÜLKE KODU.
///
/// Bu dosya ÜRÜN DAVRANIŞINI ölçer, uygulamayı değil: biçimlendirici saf
/// bir dönüşümdür ve telefon girilen yedi alanın yedisi de ona bağlı
/// `TelefonAlani`yı kullanır. Bir alan migrasyondan geride kalırsa
/// `telefon_alani_kapsam_test.dart` yakalar.
///
/// P233 §3 ile KUTUDA ÜLKE KODU YOK (ayrı seçicide), bu yüzden
/// biçimlendirici yalnız ULUSAL kısmı çizer: `541 922 23 88`.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/ui/telefon_alani.dart';

/// Biçimlendiriciyi ardışık tuş vuruşlarıyla besler.
TextEditingValue _yaz(String tuslar, [Ulke? ulke]) {
  final b = TelefonBicimlendirici(ulke ?? ulkeBul('TR'));
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
TextEditingValue _yapistir(String metin) =>
    TelefonBicimlendirici(ulkeBul('TR')).formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: metin,
        selection: TextSelection.collapsed(offset: metin.length),
      ),
    );

void main() {
  group('telefonHaneleri', () {
    test('YEREL bicim (ESKI kayitlar hala gelir)',
        () => expect(telefonHaneleri('0(543) 199 29 04'), '5431992904'));
    test('YENI bicim', () => expect(telefonHaneleri('(+90) 543 199 29 04'), '5431992904'));
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

    // (P227 §3) KIRPMA SESSIZ DEGIL — panel ikiziyle AYNI kural.
    //
    // Kirpma davranisi kaldi ama artik SORULABILIYOR. Once 11. rakam
    // yazildiginda ekranda hicbir sey degismiyordu; kullanici numarayi
    // dogru sandigi halde son hanesi DUSMUS oluyordu.
    test('TASMA sorulabiliyor', () {
      // 11 ULUSAL hane = tasma. `05431992904` TASMA DEGILDIR (bastaki
      // `0` ulusal haneye dahil degil).
      expect(telefonTasti('054319929041'), isTrue);
      expect(telefonTasti('54319929041'), isTrue);
      expect(telefonTasti('0543 199 29 04'), isFalse);
      expect(telefonTasti('05431992904'), isFalse);
    });

    test('ULKE KODU EKLERI tasma SAYILMAZ', () {
      for (final ham in ['+905431992904', '00905431992904', '905431992904']) {
        // `905431992904`: `+` YOK ama 90+10 hane TAM tutuyor -> TR.
        expect(telefonTasti(ham), isFalse, reason: ham);
      }
    });

    test('TASMA hata olarak doner ve ONCE gelir', () {
      expect(telefonHatasi('(+90) 543 199 29 041'), TelefonHatasi.tasma);
    });
  });

  group('telefonBicimle', () {
    final tr = ulkeBul('TR')!;
    test('TAM numara gruplanir',
        () => expect(telefonBicimle('5419222388', tr), '(+90) 541 922 23 88'));
    test('KISMI numara da gruplanir', () {
      expect(telefonBicimle('5', tr), '(+90) 5');
      expect(telefonBicimle('541', tr), '(+90) 541');
      expect(telefonBicimle('5419', tr), '(+90) 541 9');
      expect(telefonBicimle('541922', tr), '(+90) 541 922');
      expect(telefonBicimle('54192223', tr), '(+90) 541 922 23');
    });
    test('ULKE SECILI ama numara BOS -> yalniz kod',
        () => expect(telefonBicimle('', tr), '(+90) '));
    test('ULKE YOK -> kod YAZILMAZ (uydurulmaz)',
        () => expect(telefonBicimle('5419222388', null), '541 922 23 88'));
  });

  // (P233 §3) ULKE KODU — TR sabiti kalkti.
  group('ulke kodu', () {
    test('E.164 degerden ULKE cozulur', () {
      expect(telefonParcala('+491711234567').ulke?.kod, 'DE');
      expect(telefonParcala('+905431992904').ulke?.kod, 'TR');
      expect(telefonParcala('+9647912345678').ulke?.kod, 'IQ'); // 10 hane

      // 11 hane: SIKI cozum (`ulkeyiCoz`) ULKE VERMEZ — hane sayisi
      // araliga girmiyor. Ama `telefonParcala` ulkeyi YINE DE tanir ve
      // TASMA der: kullanici YAZARKEN her tusta "ulke secilmedi" demek,
      // fazla hane yazdigini gizlerdi.
      expect(ulkeyiCoz('96479123456789'), isNull);
      expect(telefonParcala('+96479123456789').ulke?.kod, 'IQ');
      expect(telefonHatasi('+96479123456789'), TelefonHatasi.tasma);
    });

    test('EN UZUN KOD ONCE denenir (+90 ile +964 ayni 9 ile baslar)', () {
      final p = telefonParcala('+9647912345678');
      expect(p.ulke?.arama, '964');
      expect(p.haneler, '7912345678');
    });

    test('ULKE SECILMEDEN numara GECERLI DEGIL', () {
      expect(telefonHatasi('5431992904'), TelefonHatasi.ulkeYok);
      // ...ve SESSIZCE +90 eklenmez.
      expect(telefonNormalle('5431992904'), '');
    });

    test('ESKI TR bicimi (bastaki 0) hala TR sayilir', () {
      expect(telefonParcala('05431992904').ulke?.kod, 'TR');
      expect(telefonNormalle('05431992904'), '+905431992904');
    });

    test('UZUNLUK SINIRI ULKEYE GORE', () {
      // Almanya 12 haneye kadar; ayni numara TR'de TASMA olurdu.
      expect(telefonHatasi('(+49) 171 1234 5678'), isNull);
      expect(telefonTasti('(+49) 171 1234 5678'), isFalse);
      expect(telefonTasti('(+49) 171 1234 567890'), isTrue); // 13 hane
      // Katar 8 hane: 9. hane TASMA.
      expect(telefonTasti('(+974) 3312 3456'), isFalse);
      expect(telefonTasti('(+974) 3312 345678'), isTrue); // 10 hane
    });

    test('ON EK KURALI YALNIZ TR (uydurulmus kural gercek numarayi reddeder)',
        () {
      expect(telefonHatasi('(+90) 212 555 44 33'), TelefonHatasi.gecersizOnEk);
      // Alman sabit hatti REDDEDILMEZ — bloklarini bilmiyoruz.
      expect(telefonHatasi('(+49) 30 12345678'), isNull);
    });

    test('ULKE DEGISINCE haneler KORUNUR, sinir asilirsa KIRPILIR', () {
      // DE'nin kendi gruplamasi yok -> ucerli (3-3-4).
      expect(telefonUlkeyiDegistir('(+90) 541 922 23 88', 'DE'),
          '(+49) 541 922 2388');
      // Katar 8 hane: 10 haneli numara kirpilir.
      expect(telefonUlkeyiDegistir('(+90) 541 922 23 88', 'QA'),
          '(+974) 541 922 23');
    });

    test('AYNI ARAMA KODU: listedeki ILK ulke doner (saklama AYNI)', () {
      expect(telefonParcala('+15551234567').ulke?.kod, 'US');
      expect(telefonNormalle('(+1) 555 123 4567'), '+15551234567');
    });
  });

  group('yazarken', () {
    test('rakamlar GRUPLANARAK cizilir', () {
      expect(_yaz('5419222388').text, '541 922 23 88');
    });

    test('RAKAM DISI karakter YUTULUR', () {
      expect(_yaz('5a4b1c9d2e22388').text, '541 922 23 88');
    });

    test('FAZLA HANE YAZILAMAZ (sert sinir, ULKEYE GORE)', () {
      // TR'de 10 hane dolduktan sonraki her tus metni DEGISTIRMEZ.
      final v = _yaz('54192223881111');
      expect(v.text, '541 922 23 88');
      // Ayni tuslar ALMANYA'da 12 haneye kadar girer.
      final d = _yaz('54192223881111', ulkeBul('DE'));
      expect(d.text.replaceAll(' ', '').length, 12);
    });

    test('IMLEC metnin SONUNDA kalir (her tusta basa siframaz)', () {
      final v = _yaz('54192');
      expect(v.selection.baseOffset, v.text.length);
    });
  });

  group('yapistirma', () {
    // ULKE KODSUZ yapistirma: bicimlendirici gruplar.
    for (final ham in ['5431992904', '543-199-29-04', '543 199 29 04']) {
      test('`\$ham` -> 543 199 29 04', () {
        expect(_yapistir(ham).text, '543 199 29 04');
      });
    }

    // (P233 §3) ULKE KODLU yapistirma bicimlendiriciye BIRAKILMAZ.
    //
    // Rehberden kopyalanan numara `+49 171...` diye gelir ve o metin ULKE
    // BILGISI tasir; bicimlendirici yalniz ULUSAL kutuyu ciziyor ve ulke
    // secicisini degistiremez. Bu yuzden `+` goren bicimlendirici metne
    // DOKUNMAZ, cozumu `TelefonAlani.onChanged` yapar — orada hem kutu hem
    // secici guncellenir.
    test('`+` iceren yapistirma bicimlendiriciden GECER', () {
      expect(_yapistir('+90 543 199 29 04').text, '+90 543 199 29 04');
    });

    test('...ve cozumu telefonParcala yapar', () {
      final p = telefonParcala('+90 543 199 29 04');
      expect(p.ulke?.kod, 'TR');
      expect(p.haneler, '5431992904');
    });
  });

  group('geri silme', () {
    test('SON hane silinince bicim kisalir', () {
      final b = TelefonBicimlendirici(ulkeBul('TR'));
      final tam = _yaz('5419222388');
      // Kullanici son karakteri siler.
      final kisa = tam.text.substring(0, tam.text.length - 1);
      final v = b.formatEditUpdate(
        tam,
        TextEditingValue(
          text: kisa,
          selection: TextSelection.collapsed(offset: kisa.length),
        ),
      );
      expect(v.text, '541 922 23 8');
    });

    test('BOSLUK silinince hane KAYBOLMAZ', () {
      // "0543 199 29 04" icinde bosluk silmek bir HANE silmemeli; aksi
      // halde kullanici gorunmez bir veri kaybi yasar.
      final b = TelefonBicimlendirici(ulkeBul('TR'));
      final tam = _yaz('5419222388');
      const bosluksuz = '541922 23 88'; // ilk bosluk silindi
      final v = b.formatEditUpdate(
        tam,
        const TextEditingValue(
          text: bosluksuz,
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      expect(v.text.replaceAll(' ', ''), '5419222388');
    });
  });

  group('telefonNormalle', () {
    test('E.164 uretir',
        () => expect(telefonNormalle('(+90) 543 199 29 04'), '+905431992904'));
    test('ESKI bicim de E.164 uretir (saklama DEGISMEDI)',
        () => expect(telefonNormalle('0(543) 199 29 04'), '+905431992904'));
    test('zaten E.164 olan DEGISMEZ',
        () => expect(telefonNormalle('+905431992904'), '+905431992904'));
    test('BOS -> bos (istege bagli alanlar temizlenebilsin)',
        () => expect(telefonNormalle(''), ''));
  });

  group('telefonHatasi', () {
    test('GECERLI numara -> null',
        () => expect(telefonHatasi('(+90) 543 199 29 04'), isNull));

    test('EKSIK hane', () {
      expect(telefonHatasi('(+90) 543 199'), TelefonHatasi.eksik);
    });

    test('SABIT HAT ON EKI reddedilir', () {
      // `0212…` bir cep numarasi degildir ve SMS gitmez; kullanici bunu
      // KAYDETMEDEN once ogrenmeli.
      expect(telefonHatasi('(+90) 212 555 44 33'), TelefonHatasi.gecersizOnEk);
      expect(telefonHatasi('(+90) 312 555 44 33'), TelefonHatasi.gecersizOnEk);
    });

    test('BOS: zorunluysa hata, degilse gecerli', () {
      expect(telefonHatasi(''), TelefonHatasi.bos);
      expect(telefonHatasi('', zorunlu: false), isNull);
    });

    test('BILINMEYEN ama 5 ile baslayan blok KABUL edilir', () {
      // BTK yeni blok tahsis edebilir; kural "kapali liste" DEGIL.
      expect(telefonHatasi('(+90) 599 123 45 67'), isNull);
    });
  });
}
