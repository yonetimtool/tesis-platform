/// (P251 §1) ACIL DURUM TAKIBI — mobil: sayilar sunucudan, durum yazili,
/// durum suzgeci enum'dan, tatbikat suzgeci (web ile ayni).
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/panik/presentation/panik_takip_screen.dart';

import 'helpers/l10n_test_app.dart';

Map<String, dynamic> _alarm(String id, String durum, {bool tatbikat = false}) => {
      'id': id, 'tip': 'guvenlik', 'durum': durum, 'olusturan_ad': 'Acme Guard',
      'created_at': '2026-10-02T05:17:00Z', 'alicilar': [], 'baslik': 'ACİL DURUM',
      'toplu': false, 'tatbikat': tatbikat, 'iptal_penceresi_sn': 5,
    };

class _Tel implements HttpClientAdapter {
  final sorgular = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? r, Future<void>? c) async {
    sorgular.add(Map.of(o.queryParameters));
    final tatbikat = o.queryParameters['tatbikat'] == true;
    final govde = {
      'meta': {'limit': 50, 'offset': 0, 'total': 2},
      'items': tatbikat
          ? [_alarm('t1', 'acik', tatbikat: true)]
          : [_alarm('a1', 'yanlis_alarm'), _alarm('a2', 'kapandi')],
      'durumlar': ['beklemede', 'acik', 'mudahale', 'kapandi', 'iptal', 'yanlis_alarm'],
      'ozet': {'acik': 0, 'bugun': 2, 'kapanan': 2, 'yanlis_alarm': 1, 'iptal': 0, 'tatbikat': 1},
    };
    return ResponseBody.fromString(jsonEncode(govde), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Future<_Tel> _sur(WidgetTester tester) async {
  final tel = _Tel();
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
  final kap = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: kap, child: l10nApp(const PanikTakipScreen())));
  await tester.pumpAndSettle();
  return tel;
}

void main() {
  testWidgets('sayilar sunucudan; yanlis alarm acik sayilmaz; durum yazili', (tester) async {
    final tel = await _sur(tester);
    expect(tel.sorgular.first['tatbikat'], false, reason: 'varsayilan gercek alarmlar');
    final acik = find.byKey(const Key('panik-ozet-acik'));
    expect(find.descendant(of: acik, matching: find.text('0')), findsOneWidget);
    expect(find.text('1 yanlış alarm · 0 iptal'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('panik-durum-a1'))).data, 'Yanlış alarm');
    expect(tester.widget<Text>(find.byKey(const Key('panik-durum-a2'))).data, 'Kapandı');
    // Kapanmis/yanlis alarmda "Kapat" dugmesi yok.
    expect(find.byKey(const Key('panik-kapat-a1')), findsNothing);
  });

  testWidgets('durum suzgeci enum\'dan; tatbikat suzgeci', (tester) async {
    final tel = await _sur(tester);
    await tester.tap(find.byKey(const Key('panik-durum-suzgec')));
    await tester.pumpAndSettle();
    expect(find.text('Yanlış alarm').last, findsOneWidget);
    await tester.tap(find.text('Yanlış alarm').last);
    await tester.pumpAndSettle();
    expect(tel.sorgular.last['durum'], 'yanlis_alarm');

    await tester.tap(find.byKey(const Key('panik-kaynak')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tatbikatlar').last);
    await tester.pumpAndSettle();
    expect(tel.sorgular.last['tatbikat'], true);
    expect(find.byKey(const Key('panik-tatbikat-t1')), findsOneWidget);
  });

  testWidgets('buyuk yazi (2x) ve dar ekranda tasma yok', (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final tel = _Tel();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
    final kap = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
    addTearDown(kap.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: kap,
      child: l10nApp(const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2), size: Size(360, 800)),
        child: PanikTakipScreen(),
      )),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
