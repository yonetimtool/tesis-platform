/// (P207 §2) SESLI UYARI ANAHTARI — ayarlar ekrani.
///
/// Olculen sey: anahtarin GONDERDIGI govde ve KAPALIYKEN cikan uyari.
/// Taklit HTTP adapter'inda (P200 dersi): `bildirim_sesi` alanini
/// govdeye koyan katman da testin icinden geciyor.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/push/presentation/push_registrar.dart';
import 'package:mobile/src/features/settings/presentation/settings_screen.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';
import 'helpers/sahte_jwt.dart';
import 'helpers/push_test_fakes.dart';

class _Tel implements HttpClientAdapter {
  _Tel({this.sesli = true});

  bool sesli;
  final istekler = <({String yol, String metot, Map<String, dynamic> govde})>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final ham = options.data;
    final govde = ham is Map<String, dynamic> ? Map.of(ham) : <String, dynamic>{};
    istekler.add((yol: options.path, metot: options.method, govde: govde));
    if (options.path == '/me/bildirim-tercihleri' && options.method == 'PATCH') {
      sesli = (govde['bildirim_sesi'] as bool?) ?? sesli;
    }
    final yanit = switch (options.path) {
      '/me/bildirim-tercihleri' => {
          'bildirim_eposta': true,
          'bildirim_sms': true,
          'bildirim_mobil': true,
          'bildirim_sesi': sesli,
        },
      _ => <String, dynamic>{},
    };
    return ResponseBody.fromString(
      jsonEncode(yanit),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<_Tel> _sur(WidgetTester tester, {bool sesli = true}) async {
  final tel = _Tel(sesli: sesli);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
  final depo = BellekDepo({
    'auth.access_token': sahteJwt({'role': 'security', 'tenant_id': 't-1'}),
  });
  final kap = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(dio),
    secureStorageProvider.overrideWithValue(depo),
    pushMessagingProvider.overrideWithValue(SahtePushMessaging()),
  ]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: kap, child: l10nApp(const SettingsScreen())),
  );
  await tester.pumpAndSettle();
  return tel;
}

void main() {
  testWidgets('SES ANAHTARI govdede `bildirim_sesi` gonderir', (tester) async {
    final tel = await _sur(tester);
    final anahtar = find.byKey(const Key('ayar-bildirim-sesi'));
    // AYARLAR EKRANI UZUN: anahtar goruntu disinda kalabiliyor ve
    // gorunmeyene dokunmak sessizce hicbir sey yapmiyordu (ilk kosumda
    // "hitTest warning" + bos istek listesi).
    await tester.scrollUntilVisible(anahtar, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(anahtar);
    await tester.pumpAndSettle();
    await tester.tap(anahtar);
    await tester.pumpAndSettle();

    final patch = tel.istekler.lastWhere((i) => i.metot == 'PATCH');
    expect(patch.yol, '/me/bildirim-tercihleri');
    expect(patch.govde['bildirim_sesi'], isFalse);
    // KISMI GUNCELLEME: oteki kanallar GOVDEDE YOK — iki ekran acikken
    // birinin otekini sessizce geri almasini onler.
    expect(patch.govde.containsKey('bildirim_mobil'), isFalse);
  });

  testWidgets('SES KAPALIYKEN kritik bildirim UYARISI cikar', (tester) async {
    // Kullanici vardiya hatirlatmasini duymayabilir ve bunu ancak
    // vardiyayi kacirdiginda ogrenir.
    await _sur(tester, sesli: false);
    final uyari = find.byKey(const Key('ayar-bildirim-sesi-uyari'));
    await tester.scrollUntilVisible(uyari, 300,
        scrollable: find.byType(Scrollable).first);
    expect(uyari, findsOneWidget);
  });

  testWidgets('SES ACIKKEN uyari CIKMAZ', (tester) async {
    // Surekli gorunen bir uyari okunmaz olurdu.
    await _sur(tester, sesli: true);
    expect(find.byKey(const Key('ayar-bildirim-sesi-uyari')), findsNothing);
  });
}
