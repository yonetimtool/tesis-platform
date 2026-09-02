/// (P203 §3) ZIYARETCI — DAIRE ARAMAYLA SECILIR.
///
/// ===========================================================================
/// OLCULEN KUSUR
/// ===========================================================================
/// Daire ELLE yaziliyordu. Kapidaki gorevli cogu zaman "Ayse Hanim'a
/// geldim" duyar, "A-12'ye geldim" duymaz. Numarayi tahmin etmek SESSIZ
/// bir kusur uretir: kayit olusur ve bildirim BASKA BIR SAKINE gider.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/visitors/presentation/visitors_screen.dart';

import 'helpers/l10n_test_app.dart';

class _Tel implements HttpClientAdapter {
  final istekler = <({String yol, Map<String, dynamic> sorgu, Object? govde})>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    istekler.add((
      yol: options.path,
      sorgu: Map<String, dynamic>.from(options.queryParameters),
      govde: options.data,
    ));
    final q = (options.queryParameters['q'] as String?) ?? '';
    final govde = switch (options.path) {
      // SORGUYA DUYARLI: gercek uc de oyle. Sabit liste dondurmek,
      // "arama metni degisince ne oluyor" sorusunu olculemez kilardi.
      '/units/ara' when q.toLowerCase().startsWith('mehmet') => [
          {
            'id': 'u-2',
            'no': 'B-3',
            'blok': 'B',
            'sakinler': [
              {'user_id': 'r-3', 'ad': 'Mehmet Demir'},
            ],
          },
        ],
      '/units/ara' => [
          {
            'id': 'u-1',
            'no': 'A-12',
            'blok': 'A',
            'sakinler': [
              {'user_id': 'r-1', 'ad': 'Ayse Yilmaz'},
            ],
          },
          {
            'id': 'u-2',
            'no': 'B-3',
            'blok': 'B',
            'sakinler': [
              {'user_id': 'r-2', 'ad': 'Ayse Demir'},
              {'user_id': 'r-3', 'ad': 'Mehmet Demir'},
            ],
          },
        ],
      _ => <String, dynamic>{'id': 'v-1'},
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

Future<_Tel> _sur(WidgetTester tester) async {
  final tel = _Tel();
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
  final kap = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: kap,
      child: l10nApp(const Scaffold(body: VisitorForm())),
    ),
  );
  await tester.pumpAndSettle();
  return tel;
}

Future<void> _yaz(WidgetTester tester, String metin) async {
  await tester.enterText(find.byKey(const Key('ziyaret-daire-ara')), metin);
  // Arama GECIKMELIDIR: her tusta istek atmak, dokuz harflik bir isim
  // icin dokuz istek demekti.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('SAKIN ADIYLA arama yapilir — ozelligin varlik sebebi',
      (tester) async {
    final tel = await _sur(tester);
    await _yaz(tester, 'Ayse');

    final aramalar = tel.istekler.where((i) => i.yol == '/units/ara');
    expect(aramalar, isNotEmpty);
    expect(aramalar.last.sorgu['q'], 'Ayse');
    // Iki daire de listelenir ve SAKIN ADLARI gorunur: gorevli dogru
    // daireyi ISIMDEN tanir.
    expect(find.text('A / A-12'), findsOneWidget);
    expect(find.text('B / B-3'), findsOneWidget);
    expect(find.text('Ayse Yilmaz'), findsOneWidget);
    expect(find.text('Ayse Demir, Mehmet Demir'), findsOneWidget);
  });

  testWidgets('IKI HARFTEN KISA sorgu istek ATMAZ', (tester) async {
    // Uc bir DOKUM ARACI degil; istemci de bosuna cagirmaz.
    final tel = await _sur(tester);
    await _yaz(tester, 'A');
    expect(tel.istekler.where((i) => i.yol == '/units/ara'), isEmpty);
  });

  testWidgets('DAIRE SECILINCE sakinler AYNI YANITTAN dolar (ikinci cagri YOK)',
      (tester) async {
    final tel = await _sur(tester);
    await _yaz(tester, 'Ayse');
    await tester.tap(find.byKey(const Key('ziyaret-daire-B-3')));
    await tester.pumpAndSettle();

    // Hedef sakin secicisi CIZILDI (iki sakin var -> acilir menu).
    // Menu ogeleri acilana kadar cizilmez; olculen sey seciciyi
    // dolduracak verinin GELMIS olmasi.
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    // ESKI AKIS OLSAYDI burada `/units/by-no/...` cagrilirdi.
    expect(
      tel.istekler.where((i) => i.yol.contains('by-no')),
      isEmpty,
      reason: 'sakinler arama yanitindan gelmeli, ikinci cagri olmamali',
    );
  });

  testWidgets('TEK SAKINLI dairede hedef OTOMATIK secilir', (tester) async {
    await _sur(tester);
    await _yaz(tester, 'Ayse');
    await tester.tap(find.byKey(const Key('ziyaret-daire-A-12')));
    await tester.pumpAndSettle();
    // Tek sakin: gorevliye anlamsiz bir secim yaptirmayiz — secili
    // deger acilir menude GORUNUR.
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('Ayse Yilmaz'), findsOneWidget);
  });

  testWidgets('ARAMA METNI DEGISINCE eski hedef DUSER', (tester) async {
    // Secim yapip sonra daireyi degistiren gorevlinin eski hedefi
    // sessizce durursa, bildirim YANLIS SAKINE gider.
    await _sur(tester);
    await _yaz(tester, 'Ayse');
    await tester.tap(find.byKey(const Key('ziyaret-daire-A-12')));
    await tester.pumpAndSettle();
    // Secili hedef ekranda duruyor.
    expect(find.text('Ayse Yilmaz'), findsOneWidget);
    await _yaz(tester, 'Mehmet');
    // ESKI HEDEF DUSTU: sessizce durursa bildirim YANLIS SAKINE gider.
    expect(find.text('Ayse Yilmaz'), findsNothing);
  });
}
