import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/announcements/domain/announcement_models.dart';

void main() {
  group('Announcement.fromJson', () {
    test('tam govde eslenir; duzenlendi=false (created==updated)', () {
      final a = Announcement.fromJson(const {
        'id': 'a-1',
        'baslik': 'Su kesintisi',
        'govde': 'Yarin 10:00-12:00.',
        'olusturan_user_id': 'u-1',
        'olusturan_ad': 'Acme Yonetici',
        'created_at': '2026-07-08T10:00:00Z',
        'updated_at': '2026-07-08T10:00:00Z',
      });
      expect(a.id, 'a-1');
      expect(a.baslik, 'Su kesintisi');
      expect(a.olusturanAd, 'Acme Yonetici');
      expect(a.duzenlendi, isFalse);
    });

    test('updated_at > created_at ise duzenlendi=true', () {
      final a = Announcement.fromJson(const {
        'id': 'a-2',
        'baslik': 'x',
        'govde': 'y',
        'olusturan_user_id': 'u-1',
        'created_at': '2026-07-08T10:00:00Z',
        'updated_at': '2026-07-08T11:30:00Z',
      });
      expect(a.duzenlendi, isTrue);
    });

    test('eksik/bozuk alanlar cokme yaratmaz (savunmaci varsayilanlar)', () {
      final a = Announcement.fromJson(const {'id': 'a-3'});
      expect(a.baslik, '');
      expect(a.olusturanAd, isNull);
      expect(a.duzenlendi, isFalse);
    });
  });

  test('AnnouncementDraft.toJson yalnizca baslik+govde tasir', () {
    const d = AnnouncementDraft(baslik: 'B', govde: 'G');
    expect(d.toJson(), {'baslik': 'B', 'govde': 'G'});
  });
}
