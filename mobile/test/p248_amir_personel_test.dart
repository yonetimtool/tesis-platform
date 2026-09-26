/// (P248 §1) YONETICI MOBILDE GUVENLIK AMIRINI DOGRUDAN YONETIR.
///
/// Olculen eksik: mobil personel ekraninda rol secimi yalniz guvenlik +
/// tesis gorevlisiydi ve liste amirleri SUZUYORDU — yonetici amiri ancak
/// web'den ekleyebiliyor, mobilde hic goremiyordu (duzenle / guvenlige
/// dusur imkansiz). Sunucu yoneticiye amir acmayi P213 §6'dan beri
/// izin veriyor (`roller.YONETILEBILIR_ROLLER`).
///
/// Taklit HTTP adapter'inda (P200 deseni): olculen sey TEL UZERINDEKI govde.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/staff/presentation/staff_screen.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';
import 'helpers/sahte_jwt.dart';

const _personel = [
  {'id': 'g1', 'ad': 'Ali Guvenlik', 'role': 'security', 'is_active': true},
  {'id': 'a1', 'ad': 'Mehmet Amir', 'role': 'guvenlik_amiri', 'is_active': true},
  {'id': 't1', 'ad': 'Hasan Gorevli', 'role': 'tesis_gorevlisi', 'is_active': true},
];

class _Tel implements HttpClientAdapter {
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
    final Object govde = switch ((options.method, options.path)) {
      ('GET', '/users') => {
          'items': _personel,
          'meta': {'total': _personel.length},
        },
      ('POST', '/users') => {'id': 'yeni-1'},
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

Future<_Tel> _sur(WidgetTester tester, String rol) async {
  final tel = _Tel();
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
  final kap = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(dio),
    secureStorageProvider.overrideWithValue(BellekDepo({
      'auth.access_token': sahteJwt({'role': rol, 'tenant_id': 't-1'}),
    })),
  ]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: kap, child: l10nApp(const StaffScreen())),
  );
  await tester.pumpAndSettle();
  return tel;
}

void main() {
  testWidgets('YONETICI: liste amiri GOSTERIR, ekleme govdesi guvenlik_amiri',
      (tester) async {
    final tel = await _sur(tester, 'yonetici');
    expect(find.text('Mehmet Amir'), findsOneWidget);
    expect(find.text('Ali Guvenlik'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Güvenlik Amiri').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Kemal Amir');
    await tester.enterText(
        find.byKey(const Key('personel-eposta')), 'amir@ornek.com');
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    final post = tel.istekler
        .singleWhere((i) => i.yol == '/users' && i.metot == 'POST');
    expect(post.govde['role'], 'guvenlik_amiri');
    expect(post.govde['email'], 'amir@ornek.com');
  });

  testWidgets('YONETICI: guvenligi AMIR yapar (PATCH govdesi)', (tester) async {
    final tel = await _sur(tester, 'yonetici');
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Düzenle').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Güvenlik Amiri').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    final patch = tel.istekler
        .singleWhere((i) => i.yol == '/users/g1' && i.metot == 'PATCH');
    expect(patch.govde['role'], 'guvenlik_amiri');
  });

  testWidgets('YONETICI: amiri GUVENLIGE dusurur (PATCH govdesi)', (tester) async {
    final tel = await _sur(tester, 'yonetici');
    await tester.tap(find.byType(PopupMenuButton<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Düzenle').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Güvenlik').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    final patch = tel.istekler
        .singleWhere((i) => i.yol == '/users/a1' && i.metot == 'PATCH');
    expect(patch.govde['role'], 'security');
  });

  testWidgets('AMIR: amir SECENEGI YOK, liste ikinci amiri GOSTERMEZ',
      (tester) async {
    await _sur(tester, 'guvenlik_amiri');
    expect(find.text('Mehmet Amir'), findsNothing);
    expect(find.text('Ali Guvenlik'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Güvenlik Amiri'), findsNothing);
  });
}
