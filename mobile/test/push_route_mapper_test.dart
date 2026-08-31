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

    test('tip=ziyaretci -> ilgili ziyaretci (sakine bilgilendirme push\'u)',
        () {
      expect(
        routeForPushData(const {'tip': 'ziyaretci', 'visitor_id': 'v-1'}),
        '/visitors?visitor_id=v-1',
      );
    });

    test('tip=ziyaretci_sonuc KALDIRILDI -> null (artik onay/red push\'u yok)',
        () {
      expect(
        routeForPushData(const {'tip': 'ziyaretci_sonuc', 'visitor_id': 'v-2'}),
        isNull,
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
        routeForPushData(const {'tip': 'ziyaretci', 'visitor_id': ''}),
        '/visitors',
      );
    });

    test('tip=erisim_talebi (sakine) / erisim_sonuc (talep edene) -> '
        'goruntuleme izni ekrani', () {
      expect(
        routeForPushData(const {'tip': 'erisim_talebi', 'request_id': 'q-1'}),
        '/unit-access',
      );
      expect(
        routeForPushData(const {'tip': 'erisim_sonuc', 'request_id': 'q-1'}),
        '/unit-access',
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

    test('tip=etkinlik -> ilgili etkinlik (sakine yeni-etkinlik push\'u)', () {
      expect(
        routeForPushData(const {'tip': 'etkinlik', 'etkinlik_id': 'e-1'}),
        '/etkinlik?etkinlik_id=e-1',
      );
    });

    test('etkinlik_id yoksa/bossa etkinlik LISTESI acilir', () {
      expect(routeForPushData(const {'tip': 'etkinlik'}), '/etkinlik');
      expect(
        routeForPushData(const {'tip': 'etkinlik', 'etkinlik_id': ''}),
        '/etkinlik',
      );
    });

    test('(Böl.10.1) devriye alarmlari -> ilgili patrol ekrani', () {
      // Gecikmis/uzak okutma gorevliye kisi olarak → aktif tur ekrani.
      expect(
        routeForPushData(
            const {'tip': 'gecikmis_okutma', 'patrol_window_id': 'w-1'}),
        '/patrol',
      );
      expect(
        routeForPushData(
            const {'tip': 'uzak_okutma', 'checkpoint_id': 'c-1'}),
        '/patrol',
      );
      // Kacirilan tur yonetime → plan genel gorunumu.
      expect(
        routeForPushData(
            const {'tip': 'kacirilan_tur', 'patrol_window_id': 'w-2'}),
        '/patrol-plans',
      );
    });

    test('(Böl.10.2) vardiya ozeti -> vardiyalar ekrani', () {
      expect(
        routeForPushData(const {'tip': 'vardiya_ozeti', 'shift_id': 's-1'}),
        '/vardiyalar',
      );
    });

    test('(P191 §2) gorev atama -> Gorevlerim listesi', () {
      // `taskDetail` DEGIL: o rota Task nesnesini `extra` ile bekler ve
      // nesnesiz gelindiginde zaten listeye yonlendirir. Push'tan nesne
      // tasinamaz.
      expect(
        routeForPushData(const {'tip': 'gorev_atandi', 'task_id': 't-1'}),
        '/tasks',
      );
      expect(routeForPushData(const {'tip': 'gorev_atandi'}), '/tasks');
    });

    test('(P191 §2/§4) aidat borcu ve odeme -> Aidatim', () {
      expect(routeForPushData(const {'tip': 'aidat_borc'}), '/my-dues');
      expect(
        routeForPushData(const {'tip': 'aidat_odendi', 'receipt_id': 'r-1'}),
        '/my-dues',
      );
    });

    test('bilinmeyen/eksik tip -> null (yonlendirme yok)', () {
      expect(routeForPushData(const {'tip': 'bilinmeyen_tip'}), isNull);
      expect(routeForPushData(const {}), isNull);
    });
  });
}
