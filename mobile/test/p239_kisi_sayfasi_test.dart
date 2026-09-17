/// (P239 §5) KISI SAYFASI — vardiya kartindan acilan ekran.
///
/// Olculen istek: "karta dokununca o kisinin sayfasi acilsin, telefonu
/// dokunulabilir olsun". Burada uc sey kilitleniyor:
///   1. ad + rol + vardiya satiri ROTAYLA gelir, ikinci istek ATILMAZ,
///   2. arama dugmesi SUNUCU KARARINI cizer (numara ekranda YAZMAZ),
///   3. sunucu izin vermiyorsa (403/404) ekran cokmez, sessizce
///      "aranamıyor" der — kullaniciya anlamsiz bir hata gosterilmez.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/call/data/call_api.dart';
import 'package:mobile/src/features/call/data/call_launcher.dart';
import 'package:mobile/src/features/call/domain/call_models.dart';
import 'package:mobile/src/features/staff/presentation/kisi_sayfasi.dart';

import 'helpers/l10n_test_app.dart';

class _SahteCallApi extends CallApi {
  _SahteCallApi({this.target, this.hata}) : super(Dio());

  final CallTarget? target;
  final ApiException? hata;
  final List<String> istenen = [];

  @override
  Future<CallTarget> resolve(String userId) async {
    istenen.add(userId);
    if (hata != null) throw hata!;
    return target!;
  }
}

class _SahteLauncher implements CallLauncher {
  final List<String> cevrilen = [];

  @override
  Future<bool> dial(String telUri) async {
    cevrilen.add(telUri);
    return true;
  }
}

const _hedef = CallTarget(
  userId: 'u1',
  ad: 'Ali Veli',
  role: 'security',
  channel: 'phone',
  telefon: '+905551110000',
  telUri: 'tel:+905551110000',
);

const _args = KisiArgs(
  userId: 'u1',
  ad: 'Ali Veli',
  rol: 'security',
  altSatir: '06:00–14:00',
);

Widget _ekran(_SahteCallApi api, _SahteLauncher launcher,
        {KisiArgs args = _args}) =>
    ProviderScope(
      overrides: [
        callApiProvider.overrideWithValue(api),
        callLauncherProvider.overrideWithValue(launcher),
      ],
      child: l10nApp(KisiSayfasi(args: args)),
    );

void main() {
  testWidgets('AD + ROL + VARDIYA satiri ROTADAN cizilir', (tester) async {
    final api = _SahteCallApi(target: _hedef);
    await tester.pumpWidget(_ekran(api, _SahteLauncher()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kisi-ad')), findsOneWidget);
    expect(find.text('Ali Veli'), findsWidgets);
    // Rol KIMLIKTEN cozulur; ham 'security' EKRANDA YAZMAZ.
    expect(find.text('Güvenlik'), findsOneWidget);
    expect(find.text('security'), findsNothing);
    expect(find.text('06:00–14:00'), findsOneWidget);
    // Bas harfler: avatar yoksa bos daire "veri yok" gibi gorunurdu.
    expect(find.text('AV'), findsOneWidget);
  });

  testWidgets('TELEFON EKRANDA YAZMAZ; dokununca ceviriciye gider',
      (tester) async {
    final api = _SahteCallApi(target: _hedef);
    final launcher = _SahteLauncher();
    await tester.pumpWidget(_ekran(api, launcher));
    await tester.pumpAndSettle();

    // KVKK — amac-sinirli: numara gorunmez.
    expect(find.textContaining('905551110000'), findsNothing);

    await tester.tap(find.byKey(const Key('kisi-ara')));
    await tester.pumpAndSettle();
    expect(launcher.cevrilen, ['tel:+905551110000']);
  });

  testWidgets('SUNUCU IZIN VERMIYORSA (403) ekran cokmez, numara gelmez',
      (tester) async {
    // Yon kapisi sunucuda (CALL_DIRECTIONS). Istemci o karari TAKLIT
    // ETMEZ — yalniz sonucunu cizer.
    final api = _SahteCallApi(
      hata: ApiException(statusCode: 403, code: 'forbidden', message: 'x'),
    );
    final launcher = _SahteLauncher();
    await tester.pumpWidget(_ekran(api, launcher));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('kisi-ad')), findsOneWidget);
    expect(launcher.cevrilen, isEmpty);
  });

  testWidgets('ALT SATIR YOKSA o satir HIC cizilmez', (tester) async {
    final api = _SahteCallApi(target: _hedef);
    await tester.pumpWidget(_ekran(api, _SahteLauncher(),
        args: const KisiArgs(userId: 'u1', ad: 'Ali Veli', rol: 'security')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kisi-alt-satir')), findsNothing);
  });

  testWidgets('IKINCI ISTEK ATILMAZ: yalniz /call-target cozumu', (tester) async {
    final api = _SahteCallApi(target: _hedef);
    await tester.pumpWidget(_ekran(api, _SahteLauncher()));
    await tester.pumpAndSettle();

    expect(api.istenen, ['u1']);
  });
}
