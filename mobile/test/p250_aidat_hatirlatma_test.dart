/// (P250 §7) OTOMATİK HATIRLATMA — mobil ayar + geçmiş (web ile aynı kayıt).
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/otomasyon/presentation/otomatik_hatirlatma_screen.dart';

import 'helpers/l10n_test_app.dart';

class _Tel implements HttpClientAdapter {
  final yazilan = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? r, Future<void>? c) async {
    Object govde;
    if (o.path == '/finans/hatirlatma-epostalari') {
      govde = {'meta': {'total': 1}, 'items': [
        {'id': 'm1', 'ad': 'Ali VELİ', 'gonderim_zamani': '2026-10-01T10:00:00Z', 'durum': 'iletildi'},
      ]};
    } else {
      if (o.method == 'PATCH') yazilan.add(Map.of(o.data as Map<String, dynamic>));
      govde = {
        'aktif': true, 'vade_oncesi_gun': 0, 'kademeler': [3, 10, 30], 'metin': null,
        'eposta': true, 'ilk_gun': 3, 'tekrar_sayisi': 3, 'aralik_gun': 7,
      };
    }
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
      container: kap, child: l10nApp(const OtomatikHatirlatmaScreen())));
  await tester.pumpAndSettle();
  return tel;
}

void main() {
  testWidgets('duz cumle gercek kademelerle; e-posta gecmisi', (tester) async {
    await _sur(tester);
    final cumle = tester.widget<Text>(find.byKey(const Key('hatirlatma-cumlesi'))).data!;
    expect(cumle, contains('3, 10, 30'));
    expect(cumle, contains('e-posta'));
    await tester.scrollUntilVisible(find.text('Ali VELİ'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('İletildi'), findsOneWidget);
  });

  testWidgets('plan UCU BIRLIKTE; e-posta anahtari ayri', (tester) async {
    final tel = await _sur(tester);
    await tester.enterText(find.byKey(const Key('hatirlatma-ilk')), '5');
    await tester.tap(find.byKey(const Key('hatirlatma-plan-kaydet')));
    await tester.pumpAndSettle();
    expect(tel.yazilan.first, {'ilk_gun': 5, 'tekrar_sayisi': 3, 'aralik_gun': 7});
    await tester.tap(find.byKey(const Key('hatirlatma-eposta')));
    await tester.pumpAndSettle();
    expect(tel.yazilan.last, {'eposta': false});
  });
}
