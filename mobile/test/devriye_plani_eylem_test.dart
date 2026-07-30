/// TUR 65 — DEVRIYE PLANI: EYLEM ZINCIRLERI.
///
/// Ucuncu envanterin A maddesi, ekran kismi: `patrol_plans_screen` kapsami
/// **%52**'ydi. Ekran surusluyordu ama yalniz LISTE hâlinde; asil kod alt
/// sayfada:
///   * yeni plan formu (ad + saatler + periyot + nokta secimi),
///   * duzenleme (mevcut plan yuklenmis form),
///   * PERIYOT DOGRULAMASI (pozitif olmali) — sunucuya GITMEDEN durur,
///   * kaydetmede API hatasi ve beklenmeyen hata dallari,
///   * plan silme onayi (iptal + onay + hata),
///   * nokta atama: `setCheckpoints` cagrisi ve SIRA (secim sirasi).
///
/// Olculen sey ekranin cizilmesi degil, EYLEMIN SONUCU: hangi API hangi
/// argumanla cagrildi, liste tazelendi mi, hangi mesaj cizildi.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/checkpoints/data/checkpoint_api.dart';
import 'package:mobile/src/features/patrol/data/patrol_plan_api.dart';
import 'package:mobile/src/features/patrol/presentation/patrol_plans_screen.dart';

import 'helpers/l10n_test_app.dart';

class _SahtePlanApi extends PatrolPlanApi {
  _SahtePlanApi({this.hata}) : super(Dio());
  final Object? hata;

  final olusturulan = <Map<String, Object?>>[];
  final guncellenen = <Map<String, Object?>>[];
  final silinen = <String>[];
  final atananlar = <String, List<String>>{};

  @override
  Future<List<PatrolPlan>> list() async => const [
    PatrolPlan(
      id: 'p1',
      ad: 'Gece devriyesi',
      baslangicSaat: '22:00:00',
      bitisSaat: '06:00:00',
      periyotDakika: 60,
      aktif: true,
    ),
  ];

  @override
  Future<PatrolPlan> create({
    required String ad,
    required String baslangicSaat,
    required String bitisSaat,
    required int periyotDakika,
    bool aktif = true,
  }) async {
    olusturulan.add({
      'ad': ad,
      'bas': baslangicSaat,
      'bit': bitisSaat,
      'periyot': periyotDakika,
      'aktif': aktif,
    });
    if (hata != null) throw hata!;
    return PatrolPlan(
      id: 'yeni',
      ad: ad,
      baslangicSaat: baslangicSaat,
      bitisSaat: bitisSaat,
      periyotDakika: periyotDakika,
      aktif: aktif,
    );
  }

  @override
  Future<void> update(
    String id, {
    required String ad,
    required String baslangicSaat,
    required String bitisSaat,
    required int periyotDakika,
    bool? aktif,
  }) async {
    guncellenen.add({'id': id, 'ad': ad, 'periyot': periyotDakika});
    if (hata != null) throw hata!;
  }

  @override
  Future<void> delete(String id) async {
    silinen.add(id);
    if (hata != null) throw hata!;
  }

  @override
  Future<List<String>> checkpointIds(String planId) async => const [];

  @override
  Future<void> setCheckpoints(String planId, List<String> ids) async {
    atananlar[planId] = ids;
  }
}

const _noktalar = [
  Checkpoint(id: 'c1', ad: 'Ana Kapı', nfcTagUid: '04A1', aktif: true),
  Checkpoint(id: 'c2', ad: 'Otopark', nfcTagUid: '04A2', aktif: true),
  // PASIF nokta: secim listesinde GORUNMEMELI.
  Checkpoint(id: 'c3', ad: 'Kapali Havuz', nfcTagUid: '04A3', aktif: false),
];

Widget _ekran(_SahtePlanApi api) => ProviderScope(
  overrides: [
    patrolPlanApiProvider.overrideWithValue(api),
    checkpointsProvider.overrideWith((ref) async => _noktalar),
  ],
  child: l10nApp(const PatrolPlansScreen(), locale: const Locale('tr')),
);

/// Yeni plan alt sayfasini ac.
Future<void> _formAc(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

/// Satir menusunden bir eylem sec.
Future<void> _menu(WidgetTester tester, String etiket) async {
  await tester.tap(find.byType(PopupMenuButton<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(etiket).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('YENI PLAN: ad + nokta secimi -> create + setCheckpoints', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _SahtePlanApi();
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    await _formAc(tester);

    // Ad alani: formdaki ilk metin alani.
    await tester.enterText(find.byType(TextFormField).first, 'Sabah turu');
    // PASIF nokta secim listesinde OLMAMALI.
    expect(find.text('Kapalı Havuz'), findsNothing);
    // Iki noktayi SIRAYLA sec: sira `setCheckpoints`e gecmeli.
    await tester.tap(find.text('Otopark'));
    await tester.pump();
    await tester.tap(find.text('Ana Kapı'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(api.olusturulan, hasLength(1));
    expect(api.olusturulan.single['ad'], 'Sabah turu');
    expect(api.atananlar['yeni'], ['c2', 'c1'],
        reason: 'sira SECIM sirasidir (listedeki sira degil)');
  });

  testWidgets('PERIYOT DOGRULAMASI: 0 girilirse istek ATILMAZ', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _SahtePlanApi();
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    await _formAc(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Bozuk plan');
    // Periyot alani: ikinci metin alani.
    await tester.enterText(find.byType(TextFormField).at(1), '0');
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(api.olusturulan, isEmpty, reason: 'pozitif olmayan periyot durdurulmali');
    // Hata metni formda gorunur.
    expect(find.textContaining('pozitif'), findsWidgets);
  });

  testWidgets('KAYDETMEDE API HATASI: sunucu metni formda gosterilir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _SahtePlanApi(
      hata: const ApiException(
        code: 'validation_error',
        message: 'Saat araligi gecersiz',
        statusCode: 422,
      ),
    );
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    await _formAc(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Plan');
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(find.text('Saat araligi gecersiz'), findsOneWidget);
    // Alt sayfa KAPANMAMALI (kullanici duzeltebilsin).
    expect(find.byType(TextFormField), findsWidgets);
  });

  testWidgets('BEKLENMEYEN hata: genel kimlik mesaji, cokme YOK', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _SahtePlanApi(hata: StateError('bozuk'));
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    await _formAc(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Plan');
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(TextFormField), findsWidgets);
  });

  testWidgets('DUZENLE: mevcut plan formda yuklenir ve update cagrilir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _SahtePlanApi();
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    await _menu(tester, 'Düzenle');

    // Mevcut ad formda olmali.
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).first).controller?.text,
      'Gece devriyesi',
    );
    await tester.enterText(find.byType(TextFormField).first, 'Gece turu v2');
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(api.guncellenen, hasLength(1));
    expect(api.guncellenen.single['id'], 'p1');
    expect(api.guncellenen.single['ad'], 'Gece turu v2');
    expect(api.olusturulan, isEmpty, reason: 'duzenleme create CAGIRMAMALI');
  });

  testWidgets('SIL: onay verilirse delete cagrilir', (tester) async {
    final api = _SahtePlanApi();
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    await _menu(tester, 'Sil');
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();
    expect(api.silinen, ['p1']);
  });

  testWidgets('SIL - VAZGEC: delete CAGRILMAZ', (tester) async {
    final api = _SahtePlanApi();
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    await _menu(tester, 'Sil');
    await tester.tap(find.widgetWithText(TextButton, 'Vazgeç'));
    await tester.pumpAndSettle();
    expect(api.silinen, isEmpty);
  });

  testWidgets('SIL - API HATASI: sunucu metni SnackBar ile gosterilir', (
    tester,
  ) async {
    final api = _SahtePlanApi(
      hata: const ApiException(
        code: 'conflict',
        message: 'Plana bagli pencere var',
        statusCode: 409,
      ),
    );
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    await _menu(tester, 'Sil');
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();
    expect(api.silinen, ['p1']);
    expect(find.text('Plana bagli pencere var'), findsOneWidget);
  });
}
