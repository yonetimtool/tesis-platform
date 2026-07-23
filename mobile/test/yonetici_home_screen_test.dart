import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/budget/data/budget_api.dart';
import 'package:mobile/src/features/budget/domain/budget_models.dart';
import 'package:mobile/src/features/home/presentation/yonetici_home_screen.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';

Widget _app({Object? finansHata}) => ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) async => const Profile(
              ad: 'Kerem',
              role: 'yonetici',
              aranabilir: false,
            )),
        financialSummaryProvider.overrideWith((ref) async {
          if (finansHata != null) throw finansHata;
          return const FinancialSummary(
            toplamGelirKurus: 24875000,
            toplamGiderKurus: 10000000,
            bakiyeKurus: 14875000,
            enYuksekGiderler: [],
            tahsilat: TahsilatOzet(
              tahakkukKurus: 30000000,
              tahsilatKurus: 24875000,
              gecikenDaireSayisi: 4,
              tahsilatOraniYuzde: 86,
            ),
          );
        }),
      ],
      child: const MaterialApp(home: YoneticiHomeScreen()),
    );

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('YoneticiHomeScreen: profil adiyla karsilar + "Yönetici Paneli" '
      'alt-basligi + one cikan kart + FAB "Olay Bildir"', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Merhaba, Kerem'), findsOneWidget);
    expect(find.text('Yönetici Paneli'), findsOneWidget);
    expect(find.text('Görev Yönetimi'), findsOneWidget);
    expect(find.text('Olay Bildir'), findsOneWidget);
  });

  testWidgets('Hızlı Özet: finans verisi gelince tahsilat + oran gorunur',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Hızlı Özet'), findsOneWidget);
    expect(find.text('%86'), findsOneWidget);
    expect(find.text('₺248.750,00'), findsNWidgets(2));
  });

  testWidgets('finans HATASI ekrani dusurmez: Hızlı Özet sessizce gizli, '
      'kartlar durur', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(finansHata: Exception('500')));
    await tester.pumpAndSettle();

    expect(find.text('Hızlı Özet'), findsNothing);
    expect(find.text('Görev Yönetimi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
