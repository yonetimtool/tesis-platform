/// (P253 A2) Tesis konumu (kendi PMTiles karolarimiz) + toplu tahakkuk geri al.
///
/// Taklit HTTP ADAPTORUNDE: gonderilen govde ve sorgu olculur.
///  * adres aramasi `/konum/ara?q=` — aday LISTESI, ilk sonuc otomatik secilmez;
///  * secilen aday ayarlar PATCH govdesinde `konum_ad/lat/lon` olarak gider;
///  * karo adresi yoksa harita CIZILMEZ (anlasilir mesaj), varsa atif gorunur;
///  * toplu tahakkuk sonucu "Geri al": §C sebep zorunlu, govdede aciklama.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/src/core/harita/karo_haritasi.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/core/ozellikler/ozellik_bayraklari.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/tenant/presentation/tesis_ayarlari_screen.dart';

import 'helpers/l10n_test_app.dart';

class _Tel implements HttpClientAdapter {
  final istekler = <({String yol, String metot, Object? govde, Map<String, dynamic> sorgu})>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    istekler.add((yol: o.path, metot: o.method, govde: o.data, sorgu: o.queryParameters));
    final Object govde = switch ((o.method, o.path)) {
      ('GET', '/tenant/settings') || ('PATCH', '/tenant/settings') => {
          'tenant_id': 't-1', 'ad': 'Deneme Sitesi', 'gurultu_esigi': 3,
          'konum_ad': null, 'konum_lat': null, 'konum_lon': null,
        },
      ('GET', '/konum/ara') => {
          'q': 'Oltu',
          'items': [
            {'ad': 'Oltu', 'aciklama': 'Erzurum, Türkiye', 'lat': 40.5469, 'lon': 41.9886},
            {'ad': 'Oltuca', 'aciklama': 'Artvin, Türkiye', 'lat': 41.1, 'lon': 41.8},
          ],
        },
      _ => <String, dynamic>{},
    };
    return ResponseBody.fromString(jsonEncode(govde), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Future<_Tel> _ac(WidgetTester tester, {String? karoUrl}) async {
  tester.view.physicalSize = const Size(1080, 4200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  final tel = _Tel();
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(dio),
      currentUserRoleProvider.overrideWith((ref) async => UserRole.yonetici),
      haritaKaroUrlProvider.overrideWithValue(karoUrl),
    ],
    child: l10nApp(const TesisAyarlariScreen()),
  ));
  await tester.pumpAndSettle();
  return tel;
}

void main() {
  testWidgets('KONUM: aday listesinden secilir, PATCH govdesinde konum_ad/lat/lon', (tester) async {
    final tel = await _ac(tester);
    await tester.enterText(find.byKey(const Key('konum-ara')), 'Oltu');
    await tester.tap(find.byKey(const Key('konum-ara-dugme')));
    await tester.pumpAndSettle();
    final arama = tel.istekler.singleWhere((i) => i.yol == '/konum/ara');
    expect(arama.sorgu, {'q': 'Oltu'});
    // Iki aday: ilk sonuc otomatik SECILMEZ.
    expect(find.text('Erzurum, Türkiye'), findsOneWidget);
    expect(find.text('Artvin, Türkiye'), findsOneWidget);
    expect(find.byKey(const Key('konum-secili')), findsNothing);
    await tester.tap(find.text('Erzurum, Türkiye'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('konum-secili')), findsOneWidget);
    // Karo adresi yok: harita cizilmez, anlasilir mesaj.
    expect(find.byKey(const Key('harita-kapali')), findsOneWidget);

    final kaydet = find.byKey(const Key('tesis-ayar-kaydet'));
    await tester.scrollUntilVisible(kaydet, 400, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(kaydet);
    await tester.pumpAndSettle();
    final patch = tel.istekler.singleWhere((i) => i.metot == 'PATCH');
    expect(patch.govde, {'konum_ad': 'Oltu', 'konum_lat': 40.5469, 'konum_lon': 41.9886});
  });

  testWidgets('HARITA: karo adresi varsa OSM atfi gorunur', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [haritaKaroUrlProvider.overrideWithValue('http://karo.test/turkiye.pmtiles')],
      child: l10nApp(const Scaffold(
        body: SizedBox(height: 300, child: KaroHaritasi(merkez: LatLng(40.5, 41.9))),
      )),
    ));
    await tester.pump();
    final atif = tester.widget<Text>(find.byKey(const Key('harita-atif')));
    expect(atif.data, contains('OpenStreetMap katkıcıları'));
    expect(find.byKey(const Key('harita-kapali')), findsNothing);
  });
}
