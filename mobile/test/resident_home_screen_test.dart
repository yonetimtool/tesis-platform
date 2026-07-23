import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/dues/data/dues_api.dart';
import 'package:mobile/src/features/dues/domain/dues_models.dart';
import 'package:mobile/src/features/kargo/data/kargo_api.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/home/presentation/resident_home_screen.dart';

Widget _app({
  List<MyDuesUnit> units = const [],
  int kargoBekleyen = 0,
}) =>
    ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) async => const Profile(
              ad: 'Çiğdem',
              role: 'resident',
              aranabilir: false,
            )),
        myDuesProvider.overrideWith((ref) async => units),
        kargoBekleyenSayisiProvider.overrideWith((ref) async => kargoBekleyen),
      ],
      child: const MaterialApp(home: ResidentHomeScreen()),
    );

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 3600);
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
      'kisa borc metni; kargo sayaci "2 Bekliyor"', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(units: _borclu, kargoBekleyen: 2));
    await tester.pumpAndSettle();

    expect(find.text('₺1.250,00'), findsOneWidget); // aidat karti
    expect(find.text('₺1.250,00 borç'), findsOneWidget); // Aidatım sayaci
    expect(find.text('2 Bekliyor'), findsOneWidget); // Kargo sayaci
  });

  testWidgets('R1.1: aidat/kargo HATASI ekrani dusurmez — kart/sayac yok, '
      'izgara calisir', (tester) async {
    _tall(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) async => const Profile(
            ad: 'Çiğdem', role: 'resident', aranabilir: false)),
        myDuesProvider.overrideWith((ref) async => throw Exception('500')),
        kargoBekleyenSayisiProvider
            .overrideWith((ref) async => throw Exception('500')),
      ],
      child: const MaterialApp(home: ResidentHomeScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ödeme ve Aidat Durumu'), findsNothing);
    expect(find.text('Ziyaretçiler'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
