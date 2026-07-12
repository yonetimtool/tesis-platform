import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/budget/data/budget_api.dart';
import 'package:mobile/src/features/budget/domain/budget_models.dart';
import 'package:mobile/src/features/budget/presentation/budget_screen.dart';

/// Aga cikmayan sahte istemci; cagrilari kaydeder.
class _FakeBudgetApi extends BudgetApi {
  _FakeBudgetApi() : super(Dio());

  final categories = <BudgetCategory>[
    BudgetCategory(
      id: 'k-aidat',
      ad: 'Aidat',
      tip: BudgetTip.gelir,
      aktif: true,
    ),
    BudgetCategory(
      id: 'k-elektrik',
      ad: 'Elektrik',
      tip: BudgetTip.gider,
      aktif: true,
    ),
  ];
  final entries = <BudgetEntry>[
    BudgetEntry(
      id: 'e-1',
      kategoriId: 'k-elektrik',
      kategoriAd: 'Elektrik',
      tip: BudgetTip.gider,
      tutarKurus: 245000,
      tarih: DateTime.utc(2026, 6, 20),
      aciklama: 'Fatura',
      kaynak: 'manuel',
    ),
    BudgetEntry(
      id: 'e-2',
      kategoriId: 'k-aidat',
      kategoriAd: 'Aidat',
      tip: BudgetTip.gelir,
      tutarKurus: 75000,
      tarih: DateTime.utc(2026, 6, 25),
      kaynak: 'aidat_odeme',
      ilgiliPaymentId: 'p-1',
    ),
  ];
  var summary = BudgetSummary(
    toplamGelirKurus: 75000,
    toplamGiderKurus: 245000,
    bakiyeKurus: -170000,
    kategoriler: const [],
  );

  final createdCategories = <({String ad, BudgetTip tip})>[];
  final createdEntries = <({String kategoriId, int tutarKurus})>[];

  @override
  Future<List<BudgetCategory>> fetchCategories({BudgetTip? tip}) async =>
      tip == null ? categories : categories.where((c) => c.tip == tip).toList();

  @override
  Future<BudgetCategory> createCategory({
    required String ad,
    required BudgetTip tip,
  }) async {
    createdCategories.add((ad: ad, tip: tip));
    final cat = BudgetCategory(id: 'k-yeni', ad: ad, tip: tip, aktif: true);
    categories.add(cat);
    return cat;
  }

  @override
  Future<BudgetCategory> updateCategory(
    String id, {
    String? ad,
    bool? aktif,
  }) async {
    final old = categories.firstWhere((c) => c.id == id);
    return BudgetCategory(
      id: id,
      ad: ad ?? old.ad,
      tip: old.tip,
      aktif: aktif ?? old.aktif,
    );
  }

  @override
  Future<List<BudgetEntry>> fetchEntries({
    BudgetTip? tip,
    String? kategoriId,
    String? donem,
  }) async =>
      entries;

  @override
  Future<BudgetEntry> createEntry({
    required String kategoriId,
    required int tutarKurus,
    required DateTime tarih,
    String? aciklama,
  }) async {
    createdEntries.add((kategoriId: kategoriId, tutarKurus: tutarKurus));
    return BudgetEntry(
      id: 'e-yeni',
      kategoriId: kategoriId,
      tip: BudgetTip.gider,
      tutarKurus: tutarKurus,
      tarih: tarih,
      kaynak: 'manuel',
    );
  }

  @override
  Future<BudgetSummary> fetchSummary({String? donem}) async => summary;
}

void main() {
  late _FakeBudgetApi api;

  setUp(() => api = _FakeBudgetApi());

  Widget app() => ProviderScope(
        overrides: [budgetApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: BudgetScreen()),
      );

  testWidgets('Ozet sekmesi: gelir/gider/kasa TL olarak gorunur (negatif kasa)',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Gelir'), findsOneWidget);
    expect(find.text('Gider'), findsOneWidget);
    expect(find.text('Kasa'), findsOneWidget);
    expect(find.text('750,00 TL'), findsOneWidget);
    expect(find.text('2.450,00 TL'), findsOneWidget);
    expect(find.text('-1.700,00 TL'), findsOneWidget);
  });

  testWidgets('Hareketler sekmesi: kayitlar TL + kategori adiyla listelenir; '
      'otomatik aidat kaydi rozetli', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hareketler'));
    await tester.pumpAndSettle();

    expect(find.text('Elektrik'), findsOneWidget);
    expect(find.textContaining('2.450,00'), findsOneWidget);
    expect(find.textContaining('750,00'), findsWidgets);
    expect(find.text('Otomatik'), findsOneWidget); // aidat_odeme rozeti
  });

  testWidgets('Kategoriler sekmesi: liste + yeni kategori olusturma',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kategoriler'));
    await tester.pumpAndSettle();
    expect(find.text('Aidat'), findsOneWidget);
    expect(find.text('Elektrik'), findsOneWidget);

    await tester.tap(find.text('Yeni kategori'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Kategori adı'), 'Bahce');
    await tester.tap(find.text('Gider').last); // tip secimi
    await tester.pump();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(api.createdCategories.single.ad, 'Bahce');
    expect(api.createdCategories.single.tip, BudgetTip.gider);
  });

  testWidgets('Yeni hareket: kategori + TL tutar -> kurus olarak API\'ye gider',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hareketler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeni hareket'));
    await tester.pumpAndSettle();

    // kategori sec (dropdown)
    await tester.tap(find.byKey(const Key('entry_category_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elektrik (Gider)').last);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Tutar (TL)'), '1.234,56');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(api.createdEntries.single.kategoriId, 'k-elektrik');
    expect(api.createdEntries.single.tutarKurus, 123456); // integer kurus
  });

  testWidgets('gecersiz tutar kaydedilmez (validasyon)', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hareketler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeni hareket'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('entry_category_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elektrik (Gider)').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Tutar (TL)'), 'abc');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Geçerli bir tutar girin (örn. 1.250,50)'), findsOneWidget);
    expect(api.createdEntries, isEmpty);
  });
}
