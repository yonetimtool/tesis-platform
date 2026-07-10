import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/budget/data/budget_api.dart';
import 'package:mobile/src/features/budget/domain/budget_models.dart';
import 'package:mobile/src/features/budget/presentation/financial_summary_screen.dart';

class _FakeBudgetApi extends BudgetApi {
  _FakeBudgetApi() : super(Dio());

  String? lastDonem = 'UNSET';

  @override
  Future<FinancialSummary> fetchFinancialSummary({String? donem}) async {
    lastDonem = donem;
    return const FinancialSummary(
      donem: '2026-07',
      toplamGelirKurus: 30000,
      toplamGiderKurus: 100000,
      bakiyeKurus: -70000,
      enYuksekGiderler: [
        GiderKalemi(ad: 'Elektrik', toplamKurus: 90000),
        GiderKalemi(ad: 'Temizlik', toplamKurus: 10000),
      ],
      tahsilat: TahsilatOzet(
        tahakkukKurus: 120000,
        tahsilatKurus: 60000,
        tahsilatOraniYuzde: 50,
        gecikenDaireSayisi: 1,
      ),
    );
  }
}

void main() {
  late _FakeBudgetApi api;

  setUp(() => api = _FakeBudgetApi());

  Widget app() => ProviderScope(
        overrides: [budgetApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: FinancialSummaryScreen()),
      );

  testWidgets('yonetici ozeti: tahsilat orani + geciken daire + top giderler',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // tahsilat blogu
    expect(find.text('Tahsilat %50'), findsOneWidget);
    expect(find.textContaining('1 daire'), findsOneWidget); // geciken
    expect(find.text('1.200,00 TL'), findsOneWidget); // tahakkuk
    expect(find.text('600,00 TL'), findsOneWidget); // tahsilat
    // butce
    expect(find.text('-700,00 TL'), findsOneWidget); // negatif kasa
    // en yuksek giderler siralamayla
    expect(find.text('Elektrik'), findsOneWidget);
    expect(find.text('900,00 TL'), findsOneWidget);
    expect(find.text('Temizlik'), findsOneWidget);
  });

  testWidgets('donem secimi API cagrisina yansir', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    // ekran acilista mevcut ay ile yuklenir ('YYYY-MM')
    expect(api.lastDonem, isNotNull);
    expect(RegExp(r'^\d{4}-\d{2}$').hasMatch(api.lastDonem!), isTrue);

    // "Tum zamanlar" secilince donem'siz cagrilir
    await tester.tap(find.byKey(const Key('fs_donem_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tum zamanlar').last);
    await tester.pumpAndSettle();
    expect(api.lastDonem, isNull);
  });
}
