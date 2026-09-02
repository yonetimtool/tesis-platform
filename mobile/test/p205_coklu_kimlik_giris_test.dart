/// (P205 §1) COK YONLU GIRIS — TEK ALAN + TESIS SECIMI.
///
/// ===========================================================================
/// TAKLIT EN ALTTA (P200 DERSI)
/// ===========================================================================
/// Mevcut giris testleri (`login_screen_phone_test`, `login_remember_*`)
/// taklidi `AuthRepository` DUZEYINDE kuruyor; yani istegin GOVDESINI
/// kuran katman (`auth_api.dart` icindeki `data: {...}`) testte hic
/// calismiyor. Burada taklit HTTP adapter'ina konur: ekran -> denetleyici
/// -> api -> **tel uzerindeki govde** zincirinin tamami GERCEKTIR.
///
/// Olculen sey: hangi uca hangi JSON gitti ve 409 gelince ekranda ne cikti.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/auth_repository_impl.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/auth/presentation/login_screen.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';
import 'helpers/sosyal_kapali.dart';

/// Yola gore DURUM da donebilen sahte adapter. Tek bir durum degeri
/// yetmezdi: giris ucu 409 donerken uyelik ucu 200 donmeli.
class _TelAdapteri implements HttpClientAdapter {
  _TelAdapteri(this.yanitlar, {this.durumlar = const {}});

  final Map<String, Map<String, dynamic>> yanitlar;
  final Map<String, int> durumlar;
  final istekler = <({String yol, Map<String, dynamic> govde})>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final yol = options.path;
    final ham = options.data;
    istekler.add((
      yol: yol,
      govde: ham is Map<String, dynamic> ? Map.of(ham) : <String, dynamic>{},
    ));
    final govde = yanitlar[yol];
    if (govde == null) {
      return ResponseBody.fromString(
        jsonEncode({
          'error': {'code': 'not_found', 'message': 'taklit yok: $yol'}
        }),
        404,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(govde),
      durumlar[yol] ?? 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  List<Map<String, dynamic>> govdeler(String yol) =>
      istekler.where((i) => i.yol == yol).map((i) => i.govde).toList();

  Map<String, dynamic> govde(String yol) {
    final e = govdeler(yol);
    expect(e, hasLength(1), reason: '$yol tam bir kez cagrilmali');
    return e.single;
  }

  List<String> get yollar => istekler.map((i) => i.yol).toList();
}

const _JETONLAR = {
  'access_token': 'erisim',
  'refresh_token': 'yenileme',
  'token_type': 'bearer',
  'expires_in': 900,
};

const _IKI_TESIS = {
  'tesisler': [
    {'tenant_id': 't-1', 'slug': 'oltu-sitesi', 'ad': 'Oltu Sitesi', 'rol': 'yonetici'},
    {'tenant_id': 't-2', 'slug': 'city-ambiance', 'ad': 'City Ambiance', 'rol': 'resident'},
  ],
};

Future<_TelAdapteri> _sur(
  WidgetTester tester, {
  Map<String, Map<String, dynamic>>? yanitlar,
  Map<String, int> durumlar = const {},
}) async {
  final tel = _TelAdapteri(
    yanitlar ??
        {
          '/auth/login': Map<String, dynamic>.from(_JETONLAR),
          '/auth/login-phone': Map<String, dynamic>.from(_JETONLAR),
          '/auth/tesislerim': Map<String, dynamic>.from(_IKI_TESIS),
        },
    durumlar: durumlar,
  );
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = tel;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...sosyalKapali,
        // TEK TAKLIT NOKTASI: tasima katmani.
        dioProvider.overrideWithValue(dio),
        tokenStorageProvider.overrideWithValue(TokenStorage(BellekDepo())),
      ],
      child: l10nApp(const LoginScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return tel;
}

Future<void> _giris(
  WidgetTester tester, {
  required String kimlik,
  String parola = 'CokGizliParola1!',
}) async {
  await tester.enterText(find.byKey(const Key('giris-kimlik')), kimlik);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Parola veya geçici kod'), parola);
  await tester.tap(find.text('Giriş yap'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('EKRANDA TEK ALAN: e-posta/telefon; ayri telefon alani YOK',
      (tester) async {
    await _sur(tester);
    expect(find.text('E-posta veya telefon numarası'), findsOneWidget);
    // Kullaniciya HANGI kimlikle girebilecegi SOYLENIR — tek alanin
    // ne kabul ettigi ekrandan anlasilmazsa kullanici tahmin eder.
    expect(
      find.text('E-posta veya telefon numaranız ile giriş yapın'),
      findsOneWidget,
    );
    // Eski telefon-yalniz ekranin izi kalmadi.
    expect(find.widgetWithText(TextFormField, 'Cep telefonu'), findsNothing);
  });

  testWidgets('E-POSTA yazilirsa /auth/login govdesine KIMLIK olarak gider',
      (tester) async {
    final tel = await _sur(tester);
    await _giris(tester, kimlik: 'kerem@ornek.com');
    expect(tel.govde('/auth/login'), {
      'kimlik': 'kerem@ornek.com',
      'password': 'CokGizliParola1!',
    });
    // TELEFON UCU CAGRILMADI: ayrimi istemci dogru yapti.
    expect(tel.yollar, isNot(contains('/auth/login-phone')));
  });

  testWidgets('TELEFON yazilirsa NORMALLESTIRILIP telefon ucuna gider',
      (tester) async {
    final tel = await _sur(tester);
    await _giris(tester, kimlik: '0532 111 22 03');
    // Ayni numaranin iki farkli yazimla gitmesi, telefon GLOBAL
    // BENZERSIZ oldugu icin ileride cakisma hatasina donusurdu.
    expect(tel.govde('/auth/login-phone')['phone'], '+905321112203');
    expect(tel.yollar, isNot(contains('/auth/login')));
  });

  testWidgets('409 -> TESIS SECIMI cizilir, ROLLERIYLE', (tester) async {
    final tel = await _sur(tester, durumlar: {'/auth/login': 409});
    await _giris(tester, kimlik: 'kerem@ornek.com');

    expect(find.byKey(const Key('giris-tesis-secimi')), findsOneWidget);
    expect(find.text('Oltu Sitesi'), findsOneWidget);
    expect(find.text('City Ambiance'), findsOneWidget);
    // Ayni kisi birinde yonetici, otekinde sakin: hangi yetkiyle
    // girecegini SECMEDEN ONCE gormeli.
    expect(find.text('Site Yöneticisi'), findsOneWidget);
    // Liste AYRI ucla ve PAROLAYLA alindi (parolasiz sorulabilseydi uc,
    // "bu kimlik hangi sitelerde oturuyor" sorgusuna donerdi).
    expect(tel.govde('/auth/tesislerim'), {
      'kimlik': 'kerem@ornek.com',
      'password': 'CokGizliParola1!',
    });
  });

  testWidgets('SECILEN tesisin SLUGI ikinci giris govdesine gider',
      (tester) async {
    final tel = await _sur(tester, durumlar: {'/auth/login': 409});
    await _giris(tester, kimlik: 'kerem@ornek.com');

    await tester.tap(find.byKey(const Key('giris-tesis-city-ambiance')));
    await tester.pumpAndSettle();

    final govdeler = tel.govdeler('/auth/login');
    expect(govdeler, hasLength(2));
    expect(govdeler.last['tenant_slug'], 'city-ambiance');
  });

  testWidgets('TEK tesiste SECIM CIKMAZ ve UYELIK UCU CAGRILMAZ',
      (tester) async {
    // Sunucu 200 doner (tek uyelik) — istemcinin liste sormasina gerek
    // YOK; fazladan cagri her girise bir gidis-donus eklerdi.
    final tel = await _sur(tester);
    await _giris(tester, kimlik: 'kerem@ornek.com');
    expect(find.byKey(const Key('giris-tesis-secimi')), findsNothing);
    expect(tel.yollar, isNot(contains('/auth/tesislerim')));
  });

  testWidgets('BOS kimlikle giris: cagri YOK, alan hatasi VAR',
      (tester) async {
    final tel = await _sur(tester);
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();
    expect(tel.istekler, isEmpty);
    expect(find.text('E-posta veya telefon numaranızı yazın'), findsOneWidget);
  });
}
