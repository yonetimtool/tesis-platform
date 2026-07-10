import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/budget/domain/budget_models.dart';

void main() {
  group('FinancialSummary.fromJson', () {
    test('yonetici yaniti: tahsilat blogu dolu', () {
      final s = FinancialSummary.fromJson(const {
        'donem': '2026-07',
        'toplam_gelir_kurus': 30000,
        'toplam_gider_kurus': 100000,
        'bakiye_kurus': -70000,
        'en_yuksek_giderler': [
          {'ad': 'Elektrik', 'toplam_kurus': 90000},
          {'ad': 'Temizlik', 'toplam_kurus': 10000},
        ],
        'tahsilat': {
          'tahakkuk_kurus': 100000,
          'tahsilat_kurus': 60000,
          'tahsilat_orani_yuzde': 60,
          'geciken_daire_sayisi': 1,
        },
      });

      expect(s.donem, '2026-07');
      expect(s.bakiyeKurus, -70000);
      expect(s.enYuksekGiderler.first.ad, 'Elektrik');
      expect(s.enYuksekGiderler.first.toplamKurus, 90000);
      expect(s.tahsilat, isNotNull);
      expect(s.tahsilat!.tahsilatOraniYuzde, 60);
      expect(s.tahsilat!.gecikenDaireSayisi, 1);
    });

    test('sakin yaniti: tahsilat null (agregat seffaflik)', () {
      final s = FinancialSummary.fromJson(const {
        'donem': null,
        'toplam_gelir_kurus': 200000,
        'toplam_gider_kurus': 425000,
        'bakiye_kurus': -225000,
        'en_yuksek_giderler': [],
        'tahsilat': null,
      });

      expect(s.donem, isNull);
      expect(s.tahsilat, isNull);
      expect(s.toplamGelirKurus, 200000);
      expect(s.bakiyeKurus, isA<int>());
    });

    test('tahsilat orani tahakkuk 0 iken null olabilir', () {
      final s = FinancialSummary.fromJson(const {
        'toplam_gelir_kurus': 0,
        'toplam_gider_kurus': 0,
        'bakiye_kurus': 0,
        'en_yuksek_giderler': [],
        'tahsilat': {
          'tahakkuk_kurus': 0,
          'tahsilat_kurus': 0,
          'tahsilat_orani_yuzde': null,
          'geciken_daire_sayisi': 0,
        },
      });
      expect(s.tahsilat!.tahsilatOraniYuzde, isNull);
    });
  });
}
