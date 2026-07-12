import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/dues/domain/dues_models.dart';

void main() {
  group('MyDuesUnit.fromJson (GET /me/dues UnitDuesStatus)', () {
    test('tam govde eslenir; toplamlar SUNUCU degerleri', () {
      final u = MyDuesUnit.fromJson(const {
        'unit_id': 'u-1',
        'no': 'A-12',
        'toplam_tahakkuk_kurus': 150000,
        'toplam_odenen_kurus': 75000,
        'bakiye_kurus': 75000,
        'assessments': [
          {
            'donem': '2026-06',
            'tutar_kurus': 75000,
            'son_odeme_tarihi': '2026-06-30',
            'aciklama': 'Haziran aidati',
          },
        ],
        'payments': [
          {
            'tutar_kurus': 75000,
            'odeme_zamani': '2026-06-15T10:00:00Z',
            'yontem': 'havale',
            'durum': 'basarili',
            'donem': '2026-06',
            'makbuz_no': 'MB-1',
          },
        ],
      });
      expect(u.no, 'A-12');
      expect(u.bakiyeKurus, 75000);
      expect(u.borcVar, isTrue);
      expect(u.assessments.single.donem, '2026-06');
      expect(u.assessments.single.sonOdemeTarihi, isNotNull);
      expect(u.payments.single.yontem, 'havale');
      expect(u.payments.single.makbuzNo, 'MB-1');
    });

    test('borc yoksa borcVar=false; eksik alanlar cokme yaratmaz', () {
      final u = MyDuesUnit.fromJson(const {'no': 'B-1', 'bakiye_kurus': 0});
      expect(u.borcVar, isFalse);
      expect(u.assessments, isEmpty);
      expect(u.payments, isEmpty);
    });
  });

  test('yontem/durum TR etiketleri (bilinmeyen deger oldugu gibi doner)', () {
    expect(yontemLabel('elden'), 'Elden');
    expect(yontemLabel('havale'), 'Havale/EFT');
    expect(durumLabel('basarili'), 'Başarılı');
    expect(durumLabel('iptal'), 'İptal');
    expect(durumLabel('acayip'), 'acayip');
  });
}
