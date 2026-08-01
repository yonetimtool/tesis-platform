// (P49) Para ayristirma cekirdegi — AYIRICI KURALI ve POLITIKA AYRIMI.
//
// Bulunan kusur: `unit_tanimlari` ekrani kendi NAIF ayristiricisini
// kullaniyordu (`replaceAll(',', '.')` + `double.tryParse`) ve Turkce
// binlik ayiricisini ANLAMIYORDU. Yani uygulama BASKA YERDE `1.250,00`
// gosterip, ayni metni forma yazan kullaniciya "gecersiz tutar" diyordu.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/core/para.dart';
import 'package:mobile/src/features/budget/domain/budget_models.dart';

void main() {
  group('ayirici kurali (Turkce yazim)', () {
    test('VIRGUL ondalik, NOKTA binlik', () {
      expect(tlMetniniKurusaCevir('1.250,00'), 125000);
      expect(tlMetniniKurusaCevir('1.234.567,89'), 123456789);
      expect(tlMetniniKurusaCevir('1250,5'), 125050);
    });

    test('VIRGUL yoksa TEK nokta + en fazla 2 hane = ONDALIK', () {
      // Sayisal klavyeden gelen bicim.
      expect(tlMetniniKurusaCevir('1250.00'), 125000);
      expect(tlMetniniKurusaCevir('1250.5'), 125050);
    });

    test('VIRGUL yoksa ve nokta ONDALIK OLAMAZSA = BINLIK', () {
      // `1.250` uc haneli grup: binlik ayirici.
      expect(tlMetniniKurusaCevir('1.250'), 125000);
      expect(tlMetniniKurusaCevir('1.234.567'), 123456700);
    });

    test('para birimi isaretleri ve bosluklar YOK SAYILIR', () {
      expect(tlMetniniKurusaCevir('1.250,00 TL'), 125000);
      expect(tlMetniniKurusaCevir('₺1.250,00'), 125000);
      expect(tlMetniniKurusaCevir(' 1250 '), 125000);
    });

    test('gecersiz girdi null', () {
      expect(tlMetniniKurusaCevir(''), isNull);
      expect(tlMetniniKurusaCevir('abc'), isNull);
      expect(tlMetniniKurusaCevir('1,2,3'), isNull);
      expect(tlMetniniKurusaCevir('1,234'), isNull, reason: 'ondalik > 2 hane');
      expect(tlMetniniKurusaCevir('-5'), isNull, reason: 'isaret bicim degil');
    });

    test('(P50) YARIM giris ve ICERIDE bosluk REDDEDILIR', () {
      // `750,` ve `,50` yazmayi bitirmemis girislerdir; sessizce 750,00 /
      // 0,50 saymak kullanicinin adina karar vermek olurdu.
      expect(tlMetniniKurusaCevir('750,'), isNull);
      expect(tlMetniniKurusaCevir(',50'), isNull);
      expect(tlMetniniKurusaCevir('750.'), isNull);
      expect(tlMetniniKurusaCevir('.50'), isNull);
      // `1 000` Turkce yazimda bir sayi DEGILDIR; icerideki bosluklari
      // silmek `1 2 3`u de kabul etmek olurdu.
      expect(tlMetniniKurusaCevir('1 000'), isNull);
      expect(tlMetniniKurusaCevir('1 2 3'), isNull);
    });
  });

  group('POLITIKA cagirana ait', () {
    test('SIFIR cekirdekte GECERLI (bagimsiz bolumde "muaf")', () {
      expect(tlMetniniKurusaCevir('0'), 0);
      expect(tlMetniniKurusaCevir('0,00'), 0);
    });

    test('butce 0 TL KABUL ETMEZ (satir anlamsiz olurdu)', () {
      expect(parseTlToKurus('0'), isNull);
      expect(parseTlToKurus('0,00'), isNull);
      expect(parseTlToKurus('1.250,00'), 125000);
    });
  });

  group('GOSTERIM <-> GIRIS gidis-donusu', () {
    test('uygulamanin GOSTERDIGI bicim, formun KABUL ETTIGI bicimdir', () {
      // Kusurun ozu buydu: gosterim `1.250,00` uretiyor, ayristirici onu
      // reddediyordu.
      for (final kurus in [0, 99, 100, 125000, 123456789]) {
        expect(tlMetniniKurusaCevir(tlTutar(kurus)), kurus,
            reason: 'kurus=$kurus gosterimi geri okunamadi');
      }
    });
  });
}
