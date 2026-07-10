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

    test('tip=ziyaretci -> ilgili ziyaretci (sakine kapida-ziyaretci push\'u)',
        () {
      expect(
        routeForPushData(const {'tip': 'ziyaretci', 'visitor_id': 'v-1'}),
        '/visitors?visitor_id=v-1',
      );
    });

    test('tip=ziyaretci_sonuc -> ilgili ziyaretci (guvenlige sonuc push\'u)',
        () {
      expect(
        routeForPushData(const {'tip': 'ziyaretci_sonuc', 'visitor_id': 'v-2'}),
        '/visitors?visitor_id=v-2',
      );
    });

    test('tip=kargo -> ilgili kargo (sakine kargonuz-geldi push\'u)', () {
      expect(
        routeForPushData(const {'tip': 'kargo', 'kargo_id': 'k-1'}),
        '/kargo?kargo_id=k-1',
      );
    });

    test('kargo_id yoksa/bossa kargo LISTESI acilir', () {
      expect(routeForPushData(const {'tip': 'kargo'}), '/kargo');
      expect(
        routeForPushData(const {'tip': 'kargo', 'kargo_id': ''}),
        '/kargo',
      );
    });

    test('visitor_id yoksa/bossa ziyaretci LISTESI acilir', () {
      expect(routeForPushData(const {'tip': 'ziyaretci'}), '/visitors');
      expect(
        routeForPushData(const {'tip': 'ziyaretci_sonuc', 'visitor_id': ''}),
        '/visitors',
      );
    });

    test('tip=rezervasyon / rezervasyon_karar -> ilgili rezervasyon', () {
      expect(
        routeForPushData(const {'tip': 'rezervasyon', 'rezervasyon_id': 'r-1'}),
        '/rezervasyon?rezervasyon_id=r-1',
      );
      expect(
        routeForPushData(
            const {'tip': 'rezervasyon_karar', 'rezervasyon_id': 'r-2'}),
        '/rezervasyon?rezervasyon_id=r-2',
      );
    });

    test('rezervasyon_id yoksa/bossa rezervasyon LISTESI acilir', () {
      expect(routeForPushData(const {'tip': 'rezervasyon'}), '/rezervasyon');
      expect(
        routeForPushData(const {'tip': 'rezervasyon_karar', 'rezervasyon_id': ''}),
        '/rezervasyon',
      );
    });

    test('bilinmeyen/eksik tip -> null (yonlendirme yok)', () {
      expect(routeForPushData(const {'tip': 'acil_durum'}), isNull);
      expect(routeForPushData(const {}), isNull);
    });
  });
}
