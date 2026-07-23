import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/notifications/domain/notification_models.dart';

void main() {
  group('AppNotification.fromJson (GET /notifications sozlesmesi)', () {
    test('tam kayit: id/tip/mesaj/okundu/created_at + opsiyonel iliskiler',
        () {
      final n = AppNotification.fromJson({
        'id': 'n1',
        'tip': 'kacirilan_tur',
        'patrol_window_id': 'w1',
        'mesaj': 'Gece turu kaçırıldı',
        'okundu': false,
        'created_at': '2026-07-23T09:32:00+03:00',
      });
      expect(n.id, 'n1');
      expect(n.tip, 'kacirilan_tur');
      expect(n.mesaj, 'Gece turu kaçırıldı');
      expect(n.okundu, isFalse);
      expect(n.createdAt, DateTime.parse('2026-07-23T09:32:00+03:00'));
    });

    test('eksik/bos alanlar patlatmaz (savunmaci parse)', () {
      final n = AppNotification.fromJson(const {'id': 'n2'});
      expect(n.tip, '');
      expect(n.mesaj, '');
      expect(n.okundu, isTrue); // varsayilan: okunmus say — yanlis rozet yakma
      expect(n.createdAt, isNull);
    });
  });

  group('NotificationPage.fromJson (liste + meta.total)', () {
    test('items + total parse edilir', () {
      final page = NotificationPage.fromJson({
        'meta': {'limit': 50, 'offset': 0, 'total': 7},
        'items': [
          {'id': 'a', 'tip': 't', 'mesaj': 'm', 'okundu': false},
          {'id': 'b', 'tip': 't', 'mesaj': 'm2', 'okundu': true},
        ],
      });
      expect(page.total, 7);
      expect(page.items, hasLength(2));
      expect(page.items.first.id, 'a');
    });
  });
}
