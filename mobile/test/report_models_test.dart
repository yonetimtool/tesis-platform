import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/reports/domain/report_models.dart';
import 'package:mobile/src/core/i18n/l10n.dart';

void main() {
  group('ayAralik / donemStr', () {
    test('ay siniri yari-acik; aralik ayi tam kapsar', () {
      final r = ayAralik(2026, 7);
      expect(r.baslangic, DateTime(2026, 7, 1).toUtc());
      expect(r.bitis, DateTime(2026, 8, 1).toUtc());
    });

    test('aralik ayindan ocaga yil devri', () {
      final r = ayAralik(2026, 12);
      expect(r.bitis, DateTime(2027, 1, 1).toUtc());
    });

    test('donem anahtari YYYY-MM (tek haneli ay sifir dolgulu)', () {
      expect(donemStr(2026, 7), '2026-07');
      expect(donemStr(2026, 12), '2026-12');
    });

    // AY BASLIGI ve PARA BICIMI tur 10'da core/i18n'e tasindi (`ayAdi` +
    // `tlSonEkli`); iddialari dis_nfc_seffaflik / butce_demirbas_kargo
    // testlerinde yasiyor. Burada YALNIZ tarih/donem aritmetigi kalir.
    test('para bicimi core/i18n tek kaynagindan gelir', () {
      expect(tlSonEkli(75000, 'tr'), '750,00 TL');
      expect(tlSonEkli(123456789, 'tr'), '1.234.567,89 TL');
      expect(tlSonEkli(-75050, 'tr'), '-750,50 TL');
    });
  });

  group('aidatOzet — yalniz basarili odemeler sayilir', () {
    test('tahakkuk/tahsilat toplamlari + oran + bakiye', () {
      final ozet = aidatOzet(
        assessments: [
          {'tutar_kurus': 75000},
          {'tutar_kurus': 75000},
        ],
        payments: [
          {'tutar_kurus': 75000, 'durum': 'basarili'},
          {'tutar_kurus': 5000, 'durum': 'bekliyor'}, // sayilmaz
          {'tutar_kurus': 5000, 'durum': 'iptal'}, // sayilmaz
        ],
      );
      expect(ozet.tahakkukKurus, 150000);
      expect(ozet.tahakkukAdet, 2);
      expect(ozet.tahsilatKurus, 75000);
      expect(ozet.tahsilatAdet, 1);
      expect(ozet.bakiyeKurus, 75000);
      expect(ozet.tahsilatYuzde, 50);
    });

    test('tahakkuk yoksa oran null (bolme yok)', () {
      final ozet = aidatOzet(assessments: const [], payments: const []);
      expect(ozet.tahsilatYuzde, isNull);
      expect(ozet.bakiyeKurus, 0);
    });

    test('fazla tahsilat oran 100de kirpilir', () {
      final ozet = aidatOzet(
        assessments: [
          {'tutar_kurus': 1000},
        ],
        payments: [
          {'tutar_kurus': 5000, 'durum': 'basarili'},
        ],
      );
      expect(ozet.tahsilatYuzde, 100);
    });
  });

  group('GorevOzet / AylikRapor turetilmis alanlar', () {
    test('GorevOzet kategori bazli kalemleri esler (NULL -> Diğer)', () {
      final g = GorevOzet.fromJson(const {
        'toplam': 10,
        'kalemler': [
          {'kategori_ad': 'Temizlik', 'sayi': 6},
          {'kategori_ad': 'Diğer', 'sayi': 4},
        ],
      });
      expect(g.toplam, 10);
      expect(g.kalemler.length, 2);
      expect(g.kalemler.first.kategoriAd, 'Temizlik');
      expect(g.kalemler.first.sayi, 6);
    });

    test('devriyeYuzde: pencere yoksa null, varsa tam sayi oran', () {
      AylikRapor rapor(int toplam, int tamam) => AylikRapor(
            yil: 2026,
            ay: 7,
            devriyeToplam: toplam,
            devriyeTamamlandi: tamam,
            devriyeKacirildi: toplam - tamam,
            gorev: const GorevOzet(),
            sonTamamlamalar: const [],
            aidat: const AidatOzet(),
          );
      expect(rapor(0, 0).devriyeYuzde, isNull);
      expect(rapor(3, 2).devriyeYuzde, 66);
      expect(rapor(4, 4).devriyeYuzde, 100);
    });
  });
}
