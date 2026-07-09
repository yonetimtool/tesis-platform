import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/routing/app_router.dart';

void main() {
  group('routeForPushData (push tiklama yonlendirmesi)', () {
    test('tip=talep -> ilgili talep (complaint_id ile)', () {
      expect(
        routeForPushData(const {'tip': 'talep', 'complaint_id': 'c-1'}),
        '/complaints?complaint_id=c-1',
      );
    });

    test('tip=talep_yanit -> ilgili talep (sakine yanit push\'u)', () {
      expect(
        routeForPushData(const {'tip': 'talep_yanit', 'complaint_id': 'c-2'}),
        '/complaints?complaint_id=c-2',
      );
    });

    test('complaint_id yoksa/bossa talep LISTESI acilir', () {
      expect(routeForPushData(const {'tip': 'talep'}), '/complaints');
      expect(
        routeForPushData(const {'tip': 'talep_yanit', 'complaint_id': ''}),
        '/complaints',
      );
    });

    test('tip=duyuru -> duyurular', () {
      expect(routeForPushData(const {'tip': 'duyuru'}), '/announcements');
    });

    test('bilinmeyen/eksik tip -> null (yonlendirme yok)', () {
      expect(routeForPushData(const {'tip': 'acil_durum'}), isNull);
      expect(routeForPushData(const {}), isNull);
    });
  });
}
