/// (P211 §4) MOBIL TAHSILAT — DAIREDE BIRDEN COK SAKIN VARSA "ODEYEN" SORULUR.
///
/// ===========================================================================
/// KARAR
/// ===========================================================================
/// Odeyen her zaman borclunun kendisi degildir: kiraci adina ev sahibi
/// oder, aile bireyi kapiya gelir. Mobil ekranda borclu satirini secmek
/// KISIYI zaten belirliyordu (satir = daire + borclu); eksik olan, ayni
/// dairedeki BASKA birine makbuz kesebilmekti.
///
/// TEK sakinde secici CIZILMEZ — bu ekranin kurucu ilkesi "olmayan
/// karari sorma". Liste alinamazsa da cizilmez ve tahsilat borclunun
/// adina kaydedilir: bir kolaylik ugruna asil isi kaybetmeyiz.
///
/// Taklit HTTP ADAPTER'INDA (P200 dersi): govdeyi kuran katman testin
/// icinden geciyor.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/finans/presentation/tahsilat_screen.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';
import 'helpers/sahte_jwt.dart';

const _YASLANDIRMA = {
  'kovalar': [
    {
      'kova': '0-30',
      'daire': 2,
      'kalan_kurus': 175000,
      'daireler': [
        {
          'unit_id': 'u-1',
          'unit_no': 'A-3',
          'kalan_kurus': 125000,
          'en_eski_gun': 12,
          'borclu_ad': 'Ahmet Borclu',
          'borclu_user_id': 'k-1',
        },
        {
          'unit_id': 'u-2',
          'unit_no': 'A-4',
          'kalan_kurus': 50000,
          'en_eski_gun': 5,
          'borclu_ad': 'Ayse Borclu',
          'borclu_user_id': 'k-2',
        },
      ],
    },
  ],
  'toplam_kalan_kurus': 175000,
  'toplam_daire': 2,
};

class _Tel implements HttpClientAdapter {
  _Tel({this.sakinler = const {}, this.sakinDurumu = 200});

  /// daire no -> sakin listesi
  final Map<String, List<Map<String, dynamic>>> sakinler;
  final int sakinDurumu;

  final istekler = <({String yol, String metot, Map<String, dynamic> govde})>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final ham = options.data;
    istekler.add((
      yol: options.path,
      metot: options.method,
      govde: ham is Map<String, dynamic> ? Map.of(ham) : <String, dynamic>{},
    ));
    final sakin = RegExp(r'^/units/by-no/([^/]+)/residents$').firstMatch(options.path);
    if (sakin != null) {
      if (sakinDurumu != 200) {
        return ResponseBody.fromString('{}', sakinDurumu, headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
      }
      return ResponseBody.fromString(
        jsonEncode(sakinler[sakin.group(1)] ?? const []),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    final govde = switch (options.path) {
      '/finans/yaslandirma' => _YASLANDIRMA,
      '/kasalar' => {
          'items': [
            {'id': 'kasa-1', 'ad': 'Merkez Kasa', 'banka_mi': false},
          ],
          'meta': {'total': 1},
        },
      _ => <String, dynamic>{},
    };
    return ResponseBody.fromString(
      jsonEncode(govde),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<_Tel> _sur(
  WidgetTester tester, {
  Map<String, List<Map<String, dynamic>>> sakinler = const {},
  int sakinDurumu = 200,
}) async {
  final tel = _Tel(sakinler: sakinler, sakinDurumu: sakinDurumu);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
  final depo = BellekDepo({
    'auth.access_token': sahteJwt({'role': 'yonetici', 'tenant_id': 't-1'}),
  });
  final kap = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(dio),
    secureStorageProvider.overrideWithValue(depo),
  ]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: kap, child: l10nApp(const TahsilatScreen())),
  );
  await tester.pumpAndSettle();
  return tel;
}

const _IKI_SAKIN = {
  'A-3': [
    {'user_id': 'k-1', 'ad': 'Ahmet Borclu'},
    {'user_id': 'k-7', 'ad': 'Zeynep Malik'},
  ],
};

void main() {
  testWidgets('TEK sakinli dairede ODEYEN secicisi CIZILMEZ', (tester) async {
    final tel = await _sur(tester, sakinler: {
      'A-3': [
        {'user_id': 'k-1', 'ad': 'Ahmet Borclu'},
      ],
    });
    await tester.tap(find.byKey(const Key('tahsilat-borclu-u-1')));
    await tester.pumpAndSettle();
    // Sakinler yine de SORULUR (kac kisi oldugunu bilmeden karar verilemez).
    expect(tel.istekler.any((i) => i.yol == '/units/by-no/A-3/residents'), isTrue);
    expect(find.byKey(const Key('tahsilat-odeyen')), findsNothing);
  });

  testWidgets('IKI sakinli dairede ODEYEN secilebilir ve GOVDEYE gider',
      (tester) async {
    final tel = await _sur(tester, sakinler: _IKI_SAKIN);
    await tester.tap(find.byKey(const Key('tahsilat-borclu-u-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tahsilat-odeyen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tahsilat-odeyen')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zeynep Malik').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tahsilat-kaydet')));
    await tester.pumpAndSettle();

    final post = tel.istekler.firstWhere((i) => i.yol == '/finans/tahsilat');
    expect(post.govde['user_id'], 'k-7');
    // DAIRE DEGISMEZ: makbuz yine o daireye kesilir.
    expect(post.govde['unit_id'], 'u-1');
  });

  testWidgets('ODEYEN secilmezse VARSAYILAN borclunun kendisi', (tester) async {
    final tel = await _sur(tester, sakinler: _IKI_SAKIN);
    await tester.tap(find.byKey(const Key('tahsilat-borclu-u-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tahsilat-kaydet')));
    await tester.pumpAndSettle();
    final post = tel.istekler.firstWhere((i) => i.yol == '/finans/tahsilat');
    expect(post.govde['user_id'], 'k-1');
  });

  testWidgets('SAKIN LISTESI HATA verirse ekran CALISMAYA devam eder',
      (tester) async {
    // Kolaylik ugruna asil isi kaybetmeyiz: secici cizilmez, tahsilat
    // borclunun adina kaydedilir.
    final tel = await _sur(tester, sakinDurumu: 500);
    await tester.tap(find.byKey(const Key('tahsilat-borclu-u-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tahsilat-odeyen')), findsNothing);
    await tester.tap(find.byKey(const Key('tahsilat-kaydet')));
    await tester.pumpAndSettle();
    final post = tel.istekler.firstWhere((i) => i.yol == '/finans/tahsilat');
    expect(post.govde['user_id'], 'k-1');
  });

  testWidgets('BASKA DAIREYE gecince onceki odeyen TASINMAZ', (tester) async {
    final tel = await _sur(tester, sakinler: _IKI_SAKIN);
    await tester.tap(find.byKey(const Key('tahsilat-borclu-u-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tahsilat-odeyen')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zeynep Malik').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tahsilat-borclu-u-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tahsilat-kaydet')));
    await tester.pumpAndSettle();

    final post = tel.istekler.firstWhere((i) => i.yol == '/finans/tahsilat');
    expect(post.govde['user_id'], 'k-2');
    expect(post.govde['unit_id'], 'u-2');
  });
}
