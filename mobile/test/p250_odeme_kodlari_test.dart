/// (P250 §2) ÖDEME KODLARI — mobil, web penceresiyle parite.
///
/// Taklit HTTP adapter'ında (P200 deseni): ölçülen, TEL ÜZERİNDEKİ gövde.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/odeme_kodlari/presentation/odeme_kodlari_screen.dart';

import 'helpers/l10n_test_app.dart';

const _liste = {
  'uretilen': 0,
  'items': [
    {'user_id': 'u-yeni', 'ad': 'Işıl ÖZTÜRK', 'daire_no': 'A-3',
     'odeme_kodu': 'TS-YENI22', 'email': 'isil@ornek.com'},
    {'user_id': 'u-2', 'ad': 'Ali VELİ', 'daire_no': 'A-1',
     'odeme_kodu': 'TS-ABC234', 'email': 'ali@ornek.com',
     'eposta_durumu': 'geri_dondu'},
    {'user_id': 'u-3', 'ad': 'Adressiz', 'daire_no': 'B-2',
     'odeme_kodu': 'TS-XYZ789', 'eposta_engeli': 'eposta_yok'},
  ],
};

class _Tel implements HttpClientAdapter {
  final istekler = <({String yol, Map<String, dynamic> govde})>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final ham = options.data;
    istekler.add((
      yol: options.path,
      govde: ham is Map<String, dynamic> ? Map.of(ham) : <String, dynamic>{},
    ));
    final Object govde = options.path.endsWith('/eposta')
        ? {'gonderilen': 1, 'kuyruga_alinan': 0, 'atlananlar': <Object>[]}
        : _liste;
    return ResponseBody.fromString(jsonEncode(govde), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Future<_Tel> _sur(WidgetTester tester) async {
  final tel = _Tel();
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = tel;
  final kap = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: kap, child: l10nApp(const OdemeKodlariScreen())));
  await tester.pumpAndSettle();
  return tel;
}

List<Map<String, dynamic>> _epostaGovdeleri(_Tel tel) => [
      for (final i in tel.istekler)
        if (i.yol == '/users/odeme-kodlari/eposta') i.govde,
    ];

void main() {
  testWidgets('sira sunucudaki gibi, durum ve engel gorunur', (tester) async {
    await _sur(tester);
    final yeni = tester.getTopLeft(find.text('TS-YENI22'));
    final eski = tester.getTopLeft(find.text('TS-ABC234'));
    expect(yeni.dy < eski.dy, isTrue);
    // (P251 §10) Sade durum + ne yapilacagi; ham saglayici kodu yok.
    expect(find.text('Ulaşmadı'), findsOneWidget);
    expect(find.text('E-posta adresi geçersiz olabilir.'), findsOneWidget);
    expect(find.text('E-posta adresi yok'), findsOneWidget);
    expect(find.byTooltip('Kodu kopyala'), findsNWidgets(3));
  });

  testWidgets('tumunu sec yalniz gonderilebilirleri secer; toplu govde',
      (tester) async {
    final tel = await _sur(tester);
    await tester.tap(find.byKey(const Key('odeme-kodu-tumunu-sec')));
    await tester.pumpAndSettle();
    expect(find.text('Seçilenlere e-posta gönder (2)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('odeme-kodu-toplu-gonder')));
    await tester.pumpAndSettle();
    expect(_epostaGovdeleri(tel).single['user_ids'], ['u-yeni', 'u-2']);
  });

  testWidgets('tek kisiye gonder; adressiz kisinin dugmesi kapali',
      (tester) async {
    final tel = await _sur(tester);
    final kapali = tester.widget<IconButton>(
        find.byKey(const Key('odeme-kodu-gonder-u-3')));
    expect(kapali.onPressed, isNull);
    await tester.tap(find.byKey(const Key('odeme-kodu-gonder-u-2')));
    await tester.pumpAndSettle();
    expect(_epostaGovdeleri(tel).single['user_ids'], ['u-2']);
  });
}
