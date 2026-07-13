import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/visitors/domain/visitor_models.dart';

void main() {
  group('Visitor.fromJson (LOG-ONLY — onay/red yok)', () {
    test('tam kayit parse edilir', () {
      final v = Visitor.fromJson(const {
        'id': 'v-1',
        'unit_id': 'u-1',
        'unit_no': 'A-12',
        'ziyaretci_ad': 'Kurye Mehmet',
        'notlar': 'Koli teslimati',
        'kaydeden_user_id': 'g-1',
        'kaydeden_ad': 'Acme Guard',
        'target_resident_user_id': 'r-1',
        'target_resident_ad': 'Acme Sakin',
        'created_at': '2026-07-10T09:00:00Z',
      });
      expect(v.id, 'v-1');
      expect(v.unitNo, 'A-12');
      expect(v.ziyaretciAd, 'Kurye Mehmet');
      expect(v.notlar, 'Koli teslimati');
      expect(v.kaydedenAd, 'Acme Guard');
      // Tek hedef modeli: hedef sakin alanlari parse edilir.
      expect(v.targetResidentUserId, 'r-1');
      expect(v.targetResidentAd, 'Acme Sakin');
      expect(v.createdAt, DateTime.utc(2026, 7, 10, 9));
    });

    test('eksik/bozuk alanlarda COKMEZ (savunmaci parse)', () {
      final v = Visitor.fromJson(const {});
      expect(v.id, '');
      expect(v.createdAt, DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
    });
  });

  group('VisitorDraft.toJson', () {
    test('hedef sakin (target_resident_user_id) + notlar dolu ise yazilir', () {
      expect(
        const VisitorDraft(
          ziyaretciAd: 'Kurye',
          unitNo: 'A-12',
          targetResidentUserId: 'r-1',
          notlar: 'Koli',
        ).toJson(),
        {
          'ziyaretci_ad': 'Kurye',
          'unit_no': 'A-12',
          'target_resident_user_id': 'r-1',
          'notlar': 'Koli',
        },
      );
    });

    test('notlar null/bos ise JSON\'a HIC yazilmaz; hedef sakin HEP yazilir',
        () {
      expect(
        const VisitorDraft(
          ziyaretciAd: 'Kurye',
          unitNo: 'A-12',
          targetResidentUserId: 'r-1',
        ).toJson(),
        {
          'ziyaretci_ad': 'Kurye',
          'unit_no': 'A-12',
          'target_resident_user_id': 'r-1',
        },
      );
      expect(
        const VisitorDraft(
          ziyaretciAd: 'Kurye',
          unitNo: 'A-12',
          targetResidentUserId: 'r-1',
          notlar: '',
        ).toJson(),
        {
          'ziyaretci_ad': 'Kurye',
          'unit_no': 'A-12',
          'target_resident_user_id': 'r-1',
        },
      );
    });

    test('UnitResidentBrief.fromJson (hedef sakin secicisi)', () {
      final b = UnitResidentBrief.fromJson(const {
        'user_id': 'r-9',
        'ad': 'Zeynep Kaya',
      });
      expect(b.userId, 'r-9');
      expect(b.ad, 'Zeynep Kaya');
    });
  });
}
