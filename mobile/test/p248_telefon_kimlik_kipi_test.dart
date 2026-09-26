/// (P248 §2) TELEFON ALANI HER YERDE AYNI — mobil, TEL ÜZERİNDEKİ gövde.
///
/// Taklit HTTP ADAPTER'INDA (P200 dersi): ekran -> denetleyici -> api ->
/// dio zincirinin tamamı gerçek; ölçülen, uca GİDEN JSON.
///
/// ÖLÇÜLENLER:
///  1. GİRİŞ (P205 tek alan) artık ortak `TelefonAlani`nın kimlik kipi:
///     rakamla başlayınca ülke kutusu belirir, numara biçimlenir, gövdede
///     E.164; e-posta yazılınca kutu YOK ve metin olduğu gibi gider.
///  2. YABANCI numara (`+49`, `+44`) girişte kendi ülke koduyla gider.
///  3. DÜKKÂN telefon kapısı yabancı numarayı REDDETMİYOR (eskiden sabit
///     "10 hane" kuralı 11 haneli Alman numarasını durduruyordu).
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/core/ui/telefon_alani.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/auth/presentation/login_screen.dart';
import 'package:mobile/src/features/dukkan/presentation/dukkan_telefon_screen.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';
import 'helpers/sosyal_kapali.dart';

class _Tel implements HttpClientAdapter {
  _Tel(this.yanitlar);

  final Map<String, (int, Map<String, dynamic>)> yanitlar;
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
    final (durum, govde) = yanitlar[options.path] ??
        (404, <String, dynamic>{
          'error': {'code': 'not_found', 'message': 'taklit yok'},
        });
    return ResponseBody.fromString(
      jsonEncode(govde),
      durum,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  List<Map<String, dynamic>> govdeler(String yol) =>
      istekler.where((i) => i.yol == yol).map((i) => i.govde).toList();
}

const _jetonlar = <String, dynamic>{
  'access_token': 'erisim',
  'refresh_token': 'yenileme',
  'token_type': 'bearer',
  'expires_in': 900,
};

Future<_Tel> _sur(WidgetTester tester, Widget ekran) async {
  final tel = _Tel({
    '/auth/login-phone': (200, {'password_setup_required': false, ..._jetonlar}),
    '/auth/login': (200, _jetonlar),
    '/dukkan/auth/telefon/kod': (200, {'gonderildi': true}),
  });
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = tel;
  final kap = ProviderContainer(
    overrides: [
      ...sosyalKapali,
      dioProvider.overrideWithValue(dio),
      tokenStorageProvider.overrideWithValue(TokenStorage(BellekDepo())),
    ],
  );
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: kap, child: l10nApp(ekran)),
  );
  await tester.pumpAndSettle();
  return tel;
}

Future<void> _dokun(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

final _kimlik = find.byKey(const Key('giris-kimlik'));
final _ulke = find.byKey(const Key('telefon-ulke'));
final _parola = find.widgetWithText(TextFormField, 'Parola veya geçici kod');

void main() {
  test('karar kurali panel ikiziyle ayni', () {
    expect(kimlikTelefonMu('0532'), isTrue);
    expect(kimlikTelefonMu('+49 151'), isTrue);
    expect(kimlikTelefonMu('(+90) 532'), isTrue);
    expect(kimlikTelefonMu('a@b.c'), isFalse);
    expect(kimlikTelefonMu('123ali@x.com'), isFalse);
    expect(kimlikTelefonMu(''), isFalse);
    expect(kimlikGonderimDegeri('0543 199 29 04'), '+905431992904');
    expect(kimlikGonderimDegeri('(+49) 151 23456789'), '+4915123456789');
    expect(kimlikGonderimDegeri(' kerem@ornek.com '), 'kerem@ornek.com');
    // Sabit hat (firma): TR `5` on eki aranmaz.
    expect(telefonHatasi('(+90) 212 555 44 33'), TelefonHatasi.gecersizOnEk);
    expect(telefonHatasi('(+90) 212 555 44 33', sabitHat: true), isNull);
  });

  group('GIRIS — kimlik kipi', () {
    testWidgets('e-posta yazilirken ulke kutusu YOK, govde oldugu gibi',
        (tester) async {
      final tel = await _sur(tester, const LoginScreen());
      expect(_ulke, findsNothing);
      await tester.enterText(_kimlik, '123ali@x.com');
      await tester.pumpAndSettle();
      expect(_ulke, findsNothing);
      await tester.enterText(_parola, 'CokGizli1!');
      await _dokun(tester, find.text('Giriş yap'));
      expect(tel.govdeler('/auth/login').single['kimlik'], '123ali@x.com');
      expect(tel.govdeler('/auth/login-phone'), isEmpty);
    });

    testWidgets('rakamla baslayinca ulke kutusu belirir, harfte e-postaya doner',
        (tester) async {
      await _sur(tester, const LoginScreen());
      await tester.enterText(_kimlik, '5');
      await tester.pumpAndSettle();
      expect(_ulke, findsOneWidget);
      expect(find.text('🇹🇷 +90'), findsOneWidget);
      await tester.enterText(_kimlik, '5a');
      await tester.pumpAndSettle();
      expect(_ulke, findsNothing);
      expect(find.text('5a'), findsOneWidget);
    });

    testWidgets('TR numarasi bicimlenir, gövdede E.164', (tester) async {
      final tel = await _sur(tester, const LoginScreen());
      await tester.enterText(_kimlik, '05321112203');
      await tester.pumpAndSettle();
      expect(find.text('532 111 22 03'), findsOneWidget);
      await tester.enterText(_parola, 'K7MR-2QWX');
      await _dokun(tester, find.text('Giriş yap'));
      expect(tel.govdeler('/auth/login-phone').single,
          {'phone': '+905321112203', 'password': 'K7MR-2QWX'});
    });

    testWidgets('YABANCI numara yapistirilinca kendi ulkesiyle gider',
        (tester) async {
      final tel = await _sur(tester, const LoginScreen());
      await tester.enterText(_kimlik, '+49 151 23456789');
      await tester.pumpAndSettle();
      expect(find.text('🇩🇪 +49'), findsOneWidget);
      await tester.enterText(_parola, 'CokGizli1!');
      await _dokun(tester, find.text('Giriş yap'));
      expect(tel.govdeler('/auth/login-phone').single['phone'],
          '+4915123456789');
    });

    testWidgets('`+49` sonra BOSLUK sonra numara: ulke KAYBOLMAZ',
        (tester) async {
      // Panelde Playwright ile olculen kusurun ikizi: `+49` ulke kutusuna
      // gecip numara kutusu bosalinca gelen bosluk alani e-postaya
      // dusuruyordu ve numara `+90...` olarak gidiyordu.
      final tel = await _sur(tester, const LoginScreen());
      await tester.enterText(_kimlik, '+');
      await tester.enterText(_kimlik, '+4');
      await tester.enterText(_kimlik, '+49');
      await tester.pumpAndSettle();
      await tester.enterText(_kimlik, ' ');
      await tester.pumpAndSettle();
      expect(find.text('🇩🇪 +49'), findsOneWidget);
      await tester.enterText(_kimlik, '15123456789');
      await tester.enterText(_parola, 'CokGizli1!');
      await _dokun(tester, find.text('Giriş yap'));
      expect(tel.govdeler('/auth/login-phone').single['phone'],
          '+4915123456789');
    });

    testWidgets('ulke kutusundan GB secilir, numara GB olarak gider',
        (tester) async {
      final tel = await _sur(tester, const LoginScreen());
      await tester.enterText(_kimlik, '7');
      await tester.pumpAndSettle();
      await _dokun(tester, _ulke);
      await _dokun(tester, find.byKey(const Key('telefon-ulke-GB')));
      await tester.enterText(_kimlik, '7911123456');
      await tester.pumpAndSettle();
      await tester.enterText(_parola, 'CokGizli1!');
      await _dokun(tester, find.text('Giriş yap'));
      expect(tel.govdeler('/auth/login-phone').single['phone'],
          '+447911123456');
    });
  });

  group('DUKKAN telefon kapisi', () {
    testWidgets('11 haneli Alman numarasi REDDEDILMEZ, E.164 gider',
        (tester) async {
      final tel = await _sur(tester, const DukkanTelefonScreen());
      await tester.enterText(
          find.byType(TextFormField).first, '+49 151 23456789');
      await tester.pumpAndSettle();
      await _dokun(tester, find.text('Kod gönder'));
      expect(tel.govdeler('/dukkan/auth/telefon/kod').single,
          {'telefon': '+4915123456789'});
    });
  });
}
