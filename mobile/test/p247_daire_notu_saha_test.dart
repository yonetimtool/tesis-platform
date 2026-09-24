/// (P247-bekleyen 1.2) DAIRE NOTLARI — "saha personeli gorebilir" isareti.
///
/// Taklit HTTP adapter'inda (tel uzerindeki govde olculur). Suzme
/// SUNUCUDA (backend/tests/test_p247_bekleyen.py); burada olculen:
///   * yonetim: kutu VARSAYILAN KAPALI, anlami yazili; govdeye false/true
///     gider; her notun durumu gorunur ve PATCH ile tersine cevrilir,
///   * saha: yazma alani/kutu YOK, yalniz sunucunun dondurdugu notlar.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/building_map/presentation/daire_notlari.dart';

import 'helpers/l10n_test_app.dart';

class _Tel implements HttpClientAdapter {
  _Tel(this.notlar);

  List<Map<String, dynamic>> notlar;
  final istekler = <(String, String, Object?)>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    istekler.add((o.method, o.path, o.data));
    final govde = o.method == 'GET' ? {'items': notlar} : {'id': 'yeni'};
    return ResponseBody.fromString(
      jsonEncode(govde),
      o.method == 'POST' ? 201 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _kutuEtiketi = 'Güvenlik ve tesis görevlileri bu notu görebilir';

Future<_Tel> _sur(WidgetTester tester, {required bool yonetim, List<Map<String, dynamic>> notlar = const []}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  final tel = _Tel(notlar);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dioProvider.overrideWithValue(dio)],
      child: l10nApp(Scaffold(
        body: SingleChildScrollView(
          child: DaireNotlari(unitId: 'u-1', yonetim: yonetim),
        ),
      )),
    ),
  );
  await tester.pumpAndSettle();
  return tel;
}

void main() {
  testWidgets('yonetim: kutu varsayilan KAPALI, anlami yazili; govdeye false/true', (tester) async {
    final tel = await _sur(tester, yonetim: true);
    final kutu = find.byKey(const Key('daire-notu-saha-kutusu'));
    expect(find.text(_kutuEtiketi), findsOneWidget);
    expect(find.textContaining('yalnızca yönetim tarafından görülür'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(kutu).value, isFalse);

    await tester.enterText(find.byKey(const Key('daire-notu-metin')), 'kapi kodu');
    await tester.tap(find.byKey(const Key('daire-notu-ekle')));
    await tester.pumpAndSettle();
    final ilk = tel.istekler.firstWhere((i) => i.$1 == 'POST');
    expect(ilk.$2, '/ekler');
    expect(ilk.$3, containsPair('saha_gorebilir', false));
    expect(ilk.$3, containsPair('varlik_tipi', 'unit'));

    await tester.enterText(find.byKey(const Key('daire-notu-metin')), 'ikinci');
    await tester.tap(kutu);
    await tester.pump();
    await tester.tap(find.byKey(const Key('daire-notu-ekle')));
    await tester.pumpAndSettle();
    final ikinci = tel.istekler.where((i) => i.$1 == 'POST').last;
    expect(ikinci.$3, containsPair('saha_gorebilir', true));
    // Gonderimden sonra kutu yine varsayilanda (kapali).
    expect(tester.widget<CheckboxListTile>(kutu).value, isFalse);
  });

  testWidgets('yonetim: not durumu yazili, dugme PATCH ile tersine cevirir', (tester) async {
    final tel = await _sur(tester, yonetim: true, notlar: [
      {'id': 'e1', 'tur': 'not', 'metin': 'borc anlasmazligi', 'saha_gorebilir': false},
    ]);
    expect(find.text('Yalnız yönetim'), findsOneWidget);
    await tester.tap(find.byKey(const Key('daire-notu-saha-e1')));
    await tester.pumpAndSettle();
    final p = tel.istekler.firstWhere((i) => i.$1 == 'PATCH');
    expect(p.$2, '/ekler/e1');
    expect(p.$3, {'saha_gorebilir': true});
  });

  testWidgets('saha: yazma alani ve kutu YOK, sunucunun dondurdugu notu okur', (tester) async {
    final tel = await _sur(tester, yonetim: false, notlar: [
      {'id': 'e2', 'tur': 'not', 'metin': 'kapi kodu 1234', 'saha_gorebilir': true},
    ]);
    expect(find.text('kapi kodu 1234'), findsOneWidget);
    expect(find.text(_kutuEtiketi), findsNothing);
    expect(find.byKey(const Key('daire-notu-metin')), findsNothing);
    expect(find.byKey(const Key('daire-notu-saha-e2')), findsNothing);
    expect(tel.istekler.every((i) => i.$1 == 'GET'), isTrue);
  });
}
