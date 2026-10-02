/// (P250 §6) HIZLI İŞLEMLER — mobil kart + özelleştirme (web ile aynı uç).
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/hizli_islemler/presentation/hizli_islemler_karti.dart';
import 'package:mobile/src/features/hizli_islemler/presentation/hizli_islemler_ozellestir_screen.dart';

import 'helpers/l10n_test_app.dart';

class _Tel implements HttpClientAdapter {
  _Tel(this.veri);
  Map<String, dynamic> veri;
  final yazilan = <Object?>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? r, Future<void>? c) async {
    if (o.method == 'PUT') {
      final g = o.data as Map<String, dynamic>;
      yazilan.add(g['secili']);
      veri = {...veri, 'secili': g['secili'] ?? veri['varsayilan']};
    }
    return ResponseBody.fromString(jsonEncode(veri), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Future<_Tel> _sur(WidgetTester tester, Widget ekran, Map<String, dynamic> veri) async {
  final tel = _Tel(veri);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
  final kap = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: kap, child: l10nApp(ekran)));
  await tester.pumpAndSettle();
  return tel;
}

void main() {
  testWidgets('kart secimi SIRAYLA cizer', (tester) async {
    await _sur(tester, const Scaffold(body: HizliIslemlerKarti()), {
      'secenekler': ['aidat', 'talep', 'kurulum'],
      'secili': ['kurulum', 'aidat'],
      'varsayilan': ['aidat', 'talep'],
      'ozel': true,
    });
    final kurulum = tester.getTopLeft(find.byKey(const Key('hizli-kurulum')));
    final aidat = tester.getTopLeft(find.byKey(const Key('hizli-aidat')));
    expect(kurulum.dx < aidat.dx || kurulum.dy < aidat.dy, isTrue);
    expect(find.byKey(const Key('hizli-talep')), findsNothing);
  });

  testWidgets('secenekler ROLE gore; sec ve kaydet; varsayilana don', (tester) async {
    final tel = await _sur(tester, const HizliIslemlerOzellestirScreen(), {
      'secenekler': ['aidat', 'talep', 'ziyaretci'],
      'secili': ['aidat'],
      'varsayilan': ['aidat', 'talep'],
      'ozel': false,
    });
    // Rolun gormedigi islem (ornegin kurulum) listede yok.
    expect(find.byKey(const Key('hizli-secenek-kurulum')), findsNothing);
    await tester.tap(find.byKey(const Key('hizli-secenek-ziyaretci')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hizli-kaydet')));
    await tester.pumpAndSettle();
    expect(tel.yazilan.single, ['aidat', 'ziyaretci']);
  });

  testWidgets('varsayilana don = null gider', (tester) async {
    final tel = await _sur(tester, const HizliIslemlerOzellestirScreen(), {
      'secenekler': ['aidat', 'talep'],
      'secili': ['talep'],
      'varsayilan': ['aidat', 'talep'],
      'ozel': true,
    });
    await tester.tap(find.byKey(const Key('hizli-varsayilan')));
    await tester.pumpAndSettle();
    expect(tel.yazilan.single, isNull);
  });
}
