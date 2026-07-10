import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/kargo/domain/kargo_models.dart';

void main() {
  group('KargoDurum.fromWire', () {
    test('bilinen degerler eslesir', () {
      expect(KargoDurum.fromWire('bekliyor'), KargoDurum.bekliyor);
      expect(KargoDurum.fromWire('teslim_alindi'), KargoDurum.teslimAlindi);
    });

    test('null/bilinmeyen deger unknown (ileri surum COKMEZ)', () {
      expect(KargoDurum.fromWire(null), KargoDurum.unknown);
      expect(KargoDurum.fromWire('kayip'), KargoDurum.unknown);
    });
  });

  group('Kargo.fromJson', () {
    test('tam kayit (teslim alinmis + fotolu) parse edilir', () {
      final k = Kargo.fromJson(const {
        'id': 'k-1',
        'unit_id': 'u-1',
        'unit_no': 'A-12',
        'firma': 'Aras Kargo',
        'foto_key': 'tenant/uploads/paket.jpg',
        'foto_url': 'https://minio/paket.jpg?X-Amz-Signature=abc',
        'notlar': 'Orta boy koli',
        'durum': 'teslim_alindi',
        'kaydeden_user_id': 'g-1',
        'kaydeden_ad': 'Acme Guard',
        'teslim_alan_user_id': 'r-1',
        'teslim_alan_ad': 'Acme Sakin',
        'teslim_zamani': '2026-07-10T12:30:00Z',
        'created_at': '2026-07-10T12:00:00Z',
      });
      expect(k.id, 'k-1');
      expect(k.unitNo, 'A-12');
      expect(k.firma, 'Aras Kargo');
      expect(k.fotoKey, 'tenant/uploads/paket.jpg');
      expect(k.fotoUrl, contains('X-Amz-Signature'));
      expect(k.notlar, 'Orta boy koli');
      expect(k.durum, KargoDurum.teslimAlindi);
      expect(k.bekliyor, isFalse);
      expect(k.kaydedenAd, 'Acme Guard');
      expect(k.teslimAlanAd, 'Acme Sakin');
      expect(k.teslimZamani, DateTime.utc(2026, 7, 10, 12, 30));
      expect(k.createdAt, DateTime.utc(2026, 7, 10, 12));
    });

    test('bekleyen fotosuz kayit: opsiyonel alanlar null', () {
      final k = Kargo.fromJson(const {
        'id': 'k-2',
        'unit_id': 'u-1',
        'unit_no': 'A-12',
        'firma': 'MNG',
        'durum': 'bekliyor',
        'kaydeden_user_id': 'g-1',
        'created_at': '2026-07-10T12:00:00Z',
      });
      expect(k.bekliyor, isTrue);
      expect(k.fotoKey, isNull);
      expect(k.fotoUrl, isNull);
      expect(k.notlar, isNull);
      expect(k.teslimAlanUserId, isNull);
      expect(k.teslimAlanAd, isNull);
      expect(k.teslimZamani, isNull);
    });

    test('eksik/bozuk alanlarda COKMEZ (savunmaci parse)', () {
      final k = Kargo.fromJson(const {});
      expect(k.id, '');
      expect(k.firma, '');
      expect(k.durum, KargoDurum.unknown);
      expect(k.createdAt, DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
    });
  });

  group('KargoDraft.toJson', () {
    test('foto_key ve notlar dolu ise yazilir', () {
      expect(
        const KargoDraft(
          firma: 'Aras',
          unitNo: 'A-12',
          fotoKey: 't/uploads/p.jpg',
          notlar: 'Koli',
        ).toJson(),
        {
          'firma': 'Aras',
          'unit_no': 'A-12',
          'foto_key': 't/uploads/p.jpg',
          'notlar': 'Koli',
        },
      );
    });

    test('foto_key null / notlar bos ise JSON\'a HIC yazilmaz', () {
      expect(
        const KargoDraft(firma: 'Aras', unitNo: 'A-12').toJson(),
        {'firma': 'Aras', 'unit_no': 'A-12'},
      );
      expect(
        const KargoDraft(firma: 'Aras', unitNo: 'A-12', notlar: '').toJson(),
        {'firma': 'Aras', 'unit_no': 'A-12'},
      );
    });
  });
}
