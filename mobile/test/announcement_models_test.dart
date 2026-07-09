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
      // foto alanlari opsiyonel — eski govde foto'suz gelir (geriye uyumlu)
      expect(a.fotoKey, isNull);
      expect(a.fotoUrl, isNull);
    });

    test('foto_key + foto_url eslenir (gorselli duyuru)', () {
      final a = Announcement.fromJson(const {
        'id': 'a-4',
        'baslik': 'Gorselli',
        'govde': 'g',
        'olusturan_user_id': 'u-1',
        'foto_key': 't1/tasks/abc.jpg',
        'foto_url':
            'http://minio.local/bucket/t1/tasks/abc.jpg?X-Amz-Signature=s',
        'created_at': '2026-07-08T10:00:00Z',
        'updated_at': '2026-07-08T10:00:00Z',
      });
      expect(a.fotoKey, 't1/tasks/abc.jpg');
      expect(a.fotoUrl, contains('X-Amz-Signature'));
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

  test('AnnouncementDraft.toJson: fotoKey null ise foto_key HIC yazilmaz '
      '(PATCH mevcut gorsele dokunmaz)', () {
    const d = AnnouncementDraft(baslik: 'B', govde: 'G');
    expect(d.toJson(), {'baslik': 'B', 'govde': 'G'});
  });

  test('AnnouncementDraft.toJson: fotoKey doluysa foto_key tasinir', () {
    const d = AnnouncementDraft(baslik: 'B', govde: 'G', fotoKey: 't/x.jpg');
    expect(d.toJson(), {'baslik': 'B', 'govde': 'G', 'foto_key': 't/x.jpg'});
  });
}
