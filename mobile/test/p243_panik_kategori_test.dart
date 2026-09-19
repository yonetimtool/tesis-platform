/// (P243 §5) SOS — sol menu konumu + KATEGORILI alarm.
///
/// OLCULEN: kategori secimi tetiklemeden ONCE geliyor, secilen kategori
/// gövdede gidiyor ve KAPSAM secim aninda yaziyor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/panik/data/panik_api.dart';
import 'package:mobile/src/features/panik/domain/panik_models.dart';
import 'package:mobile/src/features/panik/presentation/panik_sayfasi.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';

import 'helpers/l10n_test_app.dart';

class _SahteApi implements PanikApi {
  final cagrilar = <String>[];

  @override
  Future<PanikAlarm> tetikle(
    PanikTip tip, {
    PanikKategori? kategori,
    double? gpsLat,
    double? gpsLng,
    String? checkpointId,
    String? aciklama,
  }) async {
    cagrilar.add('${tip.kimlik}:${kategori?.kimlik ?? "-"}');
    return const PanikAlarm(
      id: 'a-1',
      tip: 'guvenlik',
      durum: 'beklemede',
      iptalPenceresiSn: 5,
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _ekran(_SahteApi api, UserRole rol) => ProviderScope(
      overrides: [
        panikApiProvider.overrideWithValue(api),
        currentUserRoleProvider.overrideWith((ref) async => rol),
      ],
      child: l10nApp(const PanikSayfasi()),
    );

void main() {
  testWidgets('KATEGORI SECIMI tetiklemeden ONCE cizilir', (tester) async {
    // Tersi olsaydi (once bas, sonra kategori sor) alarm ZATEN gitmis
    // olurdu ve kategori metni kimseye ulasmazdi.
    final api = _SahteApi();
    await tester.pumpWidget(_ekran(api, UserRole.yonetici));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('panik-kategori-baslik')), findsOneWidget);
    for (final k in PanikKategori.values) {
      expect(find.byKey(Key('panik-kategori-${k.kimlik}')), findsOneWidget);
    }
  });

  testWidgets('SECILEN KATEGORI GOVDEDE gider', (tester) async {
    final api = _SahteApi();
    await tester.pumpWidget(_ekran(api, UserRole.yonetici));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('panik-kategori-deprem')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('panik-tip-guvenlik')));
    await tester.pumpAndSettle();
    expect(api.cagrilar, ['guvenlik:deprem']);
  });

  testWidgets('KAPSAM SECIM ANINDA yazilir', (tester) async {
    // "Deprem" derken tum siteye seslendigini GONDERMEDEN ONCE bilmeli.
    final api = _SahteApi();
    await tester.pumpWidget(_ekran(api, UserRole.yonetici));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('panik-kategori-deprem')));
    await tester.pumpAndSettle();
    final kapsam = tester
        .widget<Text>(find.byKey(const Key('panik-kategori-kapsam')))
        .data;
    expect(kapsam, contains('Tüm siteye'));

    await tester.tap(find.byKey(const Key('panik-kategori-saglik')));
    await tester.pumpAndSettle();
    final ikinci = tester
        .widget<Text>(find.byKey(const Key('panik-kategori-kapsam')))
        .data;
    expect(ikinci, isNot(contains('Tüm siteye')));
  });

  testWidgets('KATEGORISIZ de gonderilebilir (zorunlu DEGIL)', (tester) async {
    // Acil durumda kategori secmeye USRASMAK zorunda birakmak, alarmi
    // geciktirmekti. Kategori bir KOLAYLIK; sunucu da onu opsiyonel
    // kabul ediyor.
    final api = _SahteApi();
    await tester.pumpWidget(_ekran(api, UserRole.yonetici));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('panik-tip-guvenlik')));
    await tester.pumpAndSettle();
    expect(api.cagrilar, ['guvenlik:-']);
  });

  test('(§5b) SOS GORUNURLUGU tetikleme yetkisinin AYNASI', () {
    // Ayri bir liste tutmak, birinin guncellenip otekinin eskimesi
    // demekti.
    expect(panikGorunur(UserRole.resident), isTrue);
    expect(panikGorunur(UserRole.yonetici), isTrue);
    expect(panikGorunur(UserRole.denetci), isFalse);
    expect(panikGorunur(UserRole.unknown), isFalse);
  });
}
