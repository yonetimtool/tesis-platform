import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/announcements/data/announcement_api.dart';
import 'package:mobile/src/features/announcements/domain/announcement_models.dart';
import 'package:mobile/src/features/dues/data/dues_api.dart';
import 'package:mobile/src/features/dues/domain/dues_models.dart';
import 'package:mobile/src/features/kargo/data/kargo_api.dart';
import 'package:mobile/src/features/kargo/domain/kargo_models.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/home/presentation/resident_home_screen.dart';
import 'package:mobile/src/features/visitors/data/visitor_api.dart';
import 'package:mobile/src/features/visitors/domain/visitor_models.dart';

Widget _app({
  List<MyDuesUnit> units = const [],
  List<Kargo> kargolar = const [],
  List<Visitor> ziyaretciler = const [],
  List<Announcement> duyurular = const [],
  bool hata = false,
}) =>
    ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) async => const Profile(
              ad: 'Çiğdem',
              role: 'resident',
              aranabilir: false,
            )),
        myDuesProvider.overrideWith(
            (ref) async => hata ? throw Exception('500') : units),
        kargoListProvider.overrideWith(
            (ref) async => hata ? throw Exception('500') : kargolar),
        visitorsListProvider.overrideWith(
            (ref) async => hata ? throw Exception('500') : ziyaretciler),
        sonDuyurularProvider.overrideWith(
            (ref) async => hata ? throw Exception('500') : duyurular),
      ],
      child: const MaterialApp(home: ResidentHomeScreen()),
    );

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 4200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

const _borcsuz = [
  MyDuesUnit(
      unitId: 'u1',
      no: '12',
      tahakkukKurus: 125000,
      odenenKurus: 125000,
      bakiyeKurus: 0),
];

const _borclu = [
  MyDuesUnit(
      unitId: 'u1',
      no: '12',
      tahakkukKurus: 250000,
      odenenKurus: 125000,
      bakiyeKurus: 125000),
];

Kargo _kargo(String id, {KargoDurum durum = KargoDurum.bekliyor}) => Kargo(
      id: id,
      unitId: 'u1',
      unitNo: '12',
      firma: 'Mng',
      durum: durum,
      kaydedenUserId: 'g1',
      createdAt: DateTime(2026, 7, 23, 9),
    );

void main() {
  testWidgets('ResidentHomeScreen: profil adiyla karsilar + sakin alt-basligi '
      '+ one cikan kart gorunur', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Merhaba, Çiğdem'), findsOneWidget);
    expect(find.text('Site Sakini'), findsOneWidget);
    expect(find.text('Ziyaretçiler'), findsOneWidget);
  });

  testWidgets('R1.1: borcsuz sakinde Aidat karti + Aidatım sayacinda '
      '"Borç Yok" (iki yerde)', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(units: _borcsuz));
    await tester.pumpAndSettle();

    expect(find.text('Ödeme ve Aidat Durumu'), findsOneWidget);
    expect(find.text('Borç Yok'), findsNWidgets(2)); // kart cipi + kart sayaci
  });

  testWidgets('R1.1: borclu sakinde kartta kirmizi toplam, Aidatım sayacinda '
      'kisa borc metni; kargo sayaci "2 Bekliyor" (listeden turetilir)',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(
      units: _borclu,
      kargolar: [_kargo('k1'), _kargo('k2')],
    ));
    await tester.pumpAndSettle();

    expect(find.text('₺1.250,00'), findsOneWidget); // aidat karti
    expect(find.text('₺1.250,00 borç'), findsOneWidget); // Aidatım sayaci
    expect(find.text('2 Bekliyor'), findsOneWidget); // Kargo sayaci
  });

  testWidgets('R1.2: Son Hareketler (kargo+ziyaretci) + Duyurular karti '
      'gorunur', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(
      kargolar: [_kargo('k1')],
      ziyaretciler: [
        Visitor(
          id: 'z1',
          unitId: 'u1',
          unitNo: '12',
          ziyaretciAd: 'Ahmet Yılmaz',
          kaydedenUserId: 'g1',
          targetResidentUserId: 'r1',
          createdAt: DateTime(2026, 7, 23, 10),
        ),
      ],
      duyurular: [
        Announcement(
          id: 'd1',
          baslik: 'Bahçe Düzenlemesi',
          govde: 'Peyzaj düzenlemesi yapılacaktır.',
          olusturanUserId: 'y1',
          createdAt: DateTime(2026, 7, 22),
          updatedAt: DateTime(2026, 7, 22),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Son Hareketler'), findsOneWidget);
    expect(find.text('Kargo Kaydedildi'), findsOneWidget);
    expect(find.text('Ziyaretçi Girişi'), findsOneWidget);
    // "Duyurular" iki yerde mesru: modul karti (Tüm Modüller) + bolum basligi.
    expect(find.text('Duyurular'), findsNWidgets(2));
    expect(find.text('Bahçe Düzenlemesi'), findsOneWidget);
  });

  testWidgets('R1.1/R1.2: veri HATALARI ekrani dusurmez — bolumler yok, '
      'izgara calisir', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(hata: true));
    await tester.pumpAndSettle();

    expect(find.text('Ödeme ve Aidat Durumu'), findsNothing);
    expect(find.text('Son Hareketler'), findsNothing);
    // Bolum yok; "Duyurular" yalniz modul karti olarak kalir.
    expect(find.text('Duyurular'), findsOneWidget);
    expect(find.text('Ziyaretçiler'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
