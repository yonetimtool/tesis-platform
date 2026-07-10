import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/budget/domain/budget_models.dart';

void main() {
  group('BudgetTip.fromWire', () {
    test('bilinen degerler + etiketler', () {
      expect(BudgetTip.fromWire('gelir'), BudgetTip.gelir);
      expect(BudgetTip.fromWire('gider'), BudgetTip.gider);
      expect(BudgetTip.gelir.label, 'Gelir');
      expect(BudgetTip.gider.label, 'Gider');
    });
  });

  group('BudgetCategory.fromJson', () {
    test('tam govde eslenir', () {
      final c = BudgetCategory.fromJson(const {
        'id': 'k-1',
        'ad': 'Elektrik',
        'tip': 'gider',
        'aktif': true,
        'created_at': '2026-07-10T10:00:00Z',
      });
      expect(c.id, 'k-1');
      expect(c.ad, 'Elektrik');
      expect(c.tip, BudgetTip.gider);
      expect(c.aktif, isTrue);
    });
  });

  group('BudgetEntry.fromJson', () {
    test('manuel kayit: para INTEGER kurus olarak korunur', () {
      final e = BudgetEntry.fromJson(const {
        'id': 'e-1',
        'kategori_id': 'k-1',
        'kategori_ad': 'Elektrik',
        'tip': 'gider',
        'tutar_kurus': 245000,
        'tarih': '2026-06-20',
        'aciklama': 'Fatura',
        'kaynak': 'manuel',
        'ilgili_payment_id': null,
        'created_by': 'u-1',
        'created_at': '2026-06-20T10:00:00Z',
      });
      expect(e.tutarKurus, 245000);
      expect(e.tutarKurus, isA<int>());
      expect(e.tip, BudgetTip.gider);
      expect(e.kategoriAd, 'Elektrik');
      expect(e.otomatik, isFalse);
    });

    test('aidat_odeme kaydi otomatik olarak isaretlenir', () {
      final e = BudgetEntry.fromJson(const {
        'id': 'e-2',
        'kategori_id': 'k-2',
        'tip': 'gelir',
        'tutar_kurus': 75000,
        'tarih': '2026-06-25',
        'kaynak': 'aidat_odeme',
        'ilgili_payment_id': 'p-1',
        'created_by': 'u-1',
        'created_at': '2026-06-25T10:00:00Z',
      });
      expect(e.otomatik, isTrue);
      expect(e.ilgiliPaymentId, 'p-1');
    });
  });

  group('BudgetSummary.fromJson', () {
    test('negatif kasa dahil dogru eslenir', () {
      final s = BudgetSummary.fromJson(const {
        'toplam_gelir_kurus': 100000,
        'toplam_gider_kurus': 150000,
        'bakiye_kurus': -50000,
        'kategoriler': [
          {'kategori_id': 'k-1', 'ad': 'Elektrik', 'tip': 'gider', 'toplam_kurus': 150000},
        ],
      });
      expect(s.toplamGelirKurus, 100000);
      expect(s.toplamGiderKurus, 150000);
      expect(s.bakiyeKurus, -50000);
      expect(s.kategoriler.single.toplamKurus, 150000);
    });
  });

  group('kurus <-> TL donusumu (para integer kurus)', () {
    test('parseTlToKurus: TR bicimleri', () {
      expect(parseTlToKurus('1.234,56'), 123456);
      expect(parseTlToKurus('1234,56'), 123456);
      expect(parseTlToKurus('1234,5'), 123450);
      expect(parseTlToKurus('1234'), 123400);
      expect(parseTlToKurus('1.234'), 123400); // binlik ayraci
      expect(parseTlToKurus(' 750 '), 75000);
    });

    test('parseTlToKurus: nokta ondalik da kabul (son 1-2 hane)', () {
      expect(parseTlToKurus('1234.56'), 123456);
      expect(parseTlToKurus('12.5'), 1250);
    });

    test('parseTlToKurus: gecersiz girdiler null', () {
      expect(parseTlToKurus(''), isNull);
      expect(parseTlToKurus('abc'), isNull);
      expect(parseTlToKurus('-10'), isNull);
      expect(parseTlToKurus('0'), isNull); // sifir tutar kabul edilmez
      expect(parseTlToKurus('12,345'), isNull); // 3 ondalik hane olmaz
    });

    test('formatKurusAsTl: TR gosterimi', () {
      expect(formatKurusAsTl(245000), '2.450,00');
      expect(formatKurusAsTl(123456), '1.234,56');
      expect(formatKurusAsTl(75000), '750,00');
      expect(formatKurusAsTl(-50000), '-500,00'); // negatif kasa
      expect(formatKurusAsTl(5), '0,05');
    });

    test('gidis-donus kayipsiz (integer kurus)', () {
      for (final kurus in [1, 99, 100, 123456, 99999999]) {
        expect(parseTlToKurus(formatKurusAsTl(kurus)), kurus);
      }
    });
  });
}
