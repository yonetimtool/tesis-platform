import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/budget/data/budget_api.dart';
import 'package:mobile/src/features/budget/domain/budget_models.dart';
import 'package:mobile/src/features/budget/presentation/site_budget_screen.dart';

/// Sakin şeffaflık ekrani icin sahte istemci — yalniz OZET cagrilir.
class _FakeBudgetApi extends BudgetApi {
  _FakeBudgetApi() : super(Dio());

  var entriesCalled = false;

  @override
  Future<BudgetSummary> fetchSummary({String? donem}) async =>
      const BudgetSummary(
        toplamGelirKurus: 200000,
        toplamGiderKurus: 425000,
        bakiyeKurus: -225000,
        kategoriler: [
          BudgetCategorySummaryItem(
            kategoriId: 'k-1',
            ad: 'Elektrik',
            tip: BudgetTip.gider,
            toplamKurus: 245000,
          ),
        ],
      );

  @override
  Future<List<BudgetEntry>> fetchEntries({
    BudgetTip? tip,
    String? kategoriId,
    String? donem,
  }) async {
    entriesCalled = true; // sakin ekrani defter satiri ISTEMEMELI
    return const [];
  }
}

void main() {
  late _FakeBudgetApi api;

  setUp(() => api = _FakeBudgetApi());

  Widget app() => ProviderScope(
        overrides: [budgetApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: SiteBudgetScreen()),
      );

  testWidgets('agregat toplamlar TL olarak gorunur (negatif kasa dahil)',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Site Bütçesi'), findsOneWidget);
    expect(find.text('2.000,00 TL'), findsOneWidget); // gelir
    expect(find.text('4.250,00 TL'), findsOneWidget); // gider
    expect(find.text('-2.250,00 TL'), findsOneWidget); // kasa (negatif)
    expect(find.text('Elektrik'), findsOneWidget); // kategori kirilimi
  });

  testWidgets('SALT OKUMA: yonetim eylemleri yok, defter satiri istenmez',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Yeni hareket'), findsNothing);
    expect(find.text('Yeni kategori'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(api.entriesCalled, isFalse);
    // şeffaflık notu
    expect(find.textContaining('şeffaflık'), findsOneWidget);
  });
}
