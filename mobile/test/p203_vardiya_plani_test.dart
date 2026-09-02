/// (P203 §4) VARDIYA PLANI — mobil goruntuleme.
///
/// ===========================================================================
/// MOBILDE NEDEN OLCULUYOR
/// ===========================================================================
/// Saha rolleri WEB'DE HICBIR SAYFA GORMEZ (P129) — plani gorebilecekleri
/// TEK yer mobil. "Bu hafta ne zaman calisiyorum" ve "siradaki vardiyada
/// kim var" sorularinin yaniti burada.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/shifts/presentation/vardiya_plani_screen.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';
import 'helpers/sahte_jwt.dart';

class _Tel implements HttpClientAdapter {
  final istekler = <({String yol, Map<String, dynamic> sorgu, String metot})>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    istekler.add((
      yol: options.path,
      sorgu: Map<String, dynamic>.from(options.queryParameters),
      metot: options.method,
    ));
    const gunduz = {
      'shift_id': 's-1',
      'shift_ad': 'Gunduz',
      'baslangic_saat': '08:00:00',
      'bitis_saat': '16:00:00',
      'kisiler': [
        {'plan_id': 'p-1', 'user_id': 'u-1', 'ad': 'Ali Guvenlik', 'rol': 'security'},
      ],
      'bos': false,
    };
    const geceBos = {
      'shift_id': 's-2',
      'shift_ad': 'Gece',
      'baslangic_saat': '20:00:00',
      'bitis_saat': '08:00:00',
      'kisiler': <Map<String, dynamic>>[],
      'bos': true,
    };
    final govde = switch (options.path) {
      '/vardiya-plani' => {
          'gunler': [
            {'tarih': '2026-09-02', 'slotlar': [gunduz, geceBos]},
          ],
        },
      '/vardiya-plani/simdi' => {
          'zaman': '2026-09-02T10:00:00',
          'gorevdeki_vardiya': gunduz,
          'gorevdekiler': gunduz['kisiler'],
          'sonraki_vardiya': geceBos,
          'sonrakiler': [
            {'plan_id': 'p-9', 'user_id': 'u-9', 'ad': 'Veli Gece', 'rol': 'security'},
          ],
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

Future<_Tel> _sur(WidgetTester tester, {String rol = 'security'}) async {
  final tel = _Tel();
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
  final depo = BellekDepo({
    'auth.access_token': sahteJwt({'role': rol, 'tenant_id': 't-1'}),
  });
  final kap = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(dio),
    secureStorageProvider.overrideWithValue(depo),
  ]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: kap,
      child: l10nApp(const VardiyaPlaniScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return tel;
}

void main() {
  testWidgets('HAFTALIK PLAN gunluk LISTE olarak cizilir', (tester) async {
    // Yedi gun x vardiya IZGARASI telefona sigmaz; yatay kaydirma en
    // cok ihtiyac duyulan bilgiyi (BUGUN) gorunmez yapardi.
    await _sur(tester);
    expect(find.byKey(const Key('vardiya-gun-2026-09-02')), findsOneWidget);
    expect(find.byKey(const Key('vardiya-slot-2026-09-02-s-1')), findsOneWidget);
    expect(find.text('Ali Guvenlik'), findsWidgets);
  });

  testWidgets('BOS VARDIYA acikca isaretli', (tester) async {
    await _sur(tester);
    final slot = find.byKey(const Key('vardiya-slot-2026-09-02-s-2'));
    expect(slot, findsOneWidget);
    expect(
      find.descendant(of: slot, matching: find.text('Boş')),
      findsOneWidget,
    );
  });

  testWidgets('ANLIK DURUM: su an gorevde + siradaki', (tester) async {
    await _sur(tester);
    final kart = find.byKey(const Key('vardiya-simdi'));
    expect(kart, findsOneWidget);
    expect(find.descendant(of: kart, matching: find.textContaining('Ali Guvenlik')),
        findsOneWidget);
    expect(find.descendant(of: kart, matching: find.textContaining('Veli Gece')),
        findsOneWidget);
  });

  testWidgets('SAHA ROLU CIKARMA dugmesini GORMEZ', (tester) async {
    // Yazma sunucuda admin+yonetici ile sinirli; dugmeyi gostermek
    // gorevliye 403 yedirmek olurdu.
    await _sur(tester, rol: 'security');
    expect(find.byKey(const Key('vardiya-cikar-s-1')), findsNothing);
  });

  testWidgets('YONETICI cikarabilir ve SEBEP sorulur', (tester) async {
    // Gun ici degisiklik denetime yaziliyor; "neden" bos kalirsa kayit
    // sonradan hicbir soruyu yanitlayamaz.
    final tel = await _sur(tester, rol: 'yonetici');
    await tester.tap(find.byKey(const Key('vardiya-cikar-s-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vardiya-cikar-sebep')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('vardiya-cikar-sebep')), 'grip');
    await tester.tap(find.byKey(const Key('vardiya-cikar-onayla')));
    await tester.pumpAndSettle();

    final silme = tel.istekler.where((i) => i.metot == 'DELETE');
    expect(silme, hasLength(1));
    expect(silme.single.yol, '/vardiya-plani/p-1');
    // SEBEP SORGUDA tasinir: DELETE govdesi bazi yiginlarda sessizce
    // duser ve denetim kaydi "neden" sorusunu yanitlayamazdi.
    expect(silme.single.sorgu['not_metni'], 'grip');
  });
}
