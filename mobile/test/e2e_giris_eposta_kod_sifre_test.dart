/// (E2E 2026-09, YETKI-13) MOBIL GIRIS: e-posta koduyla giris + sifremi
/// unuttum — web'deki iki yolun ikizi.
///
/// TAKLIT HTTP ADAPTER'INDA (P200 dersi): ekran -> denetleyici -> api ->
/// TEL UZERINDEKI GOVDE zincirinin tamami gercek. Olculen: hangi uca hangi
/// JSON gitti, 409'da ne cikti, telefonla kod istenince ne soylendi.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/auth/presentation/auth_controller.dart';
import 'package:mobile/src/features/auth/presentation/login_screen.dart';
import 'package:mobile/src/features/auth/presentation/sifremi_unuttum.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';
import 'helpers/sosyal_kapali.dart';

/// Yanit SIRAYLA verilir: ayni uca ikinci cagri farkli durum alabilir
/// (409 -> slug ile 200).
class _Tel implements HttpClientAdapter {
  _Tel(this.yanitlar);

  /// yol -> sirali (durum, govde) listesi; son eleman tekrar eder.
  final Map<String, List<(int, Map<String, dynamic>)>> yanitlar;
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
    final sira = yanitlar[yol];
    final kac = istekler.where((i) => i.yol == yol).length - 1;
    final (durum, govde) = sira == null
        ? (404, <String, dynamic>{
            'error': {'code': 'not_found', 'message': 'taklit yok: $yol'},
          })
        : sira[kac < sira.length ? kac : sira.length - 1];
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

const _tamam = <String, dynamic>{'durum': 'onay_bekliyor'};

Future<(_Tel, ProviderContainer)> _sur(
  WidgetTester tester,
  Map<String, List<(int, Map<String, dynamic>)>> yanitlar,
) async {
  final tel = _Tel(yanitlar);
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
    UncontrolledProviderScope(
      container: kap,
      child: l10nApp(const LoginScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return (tel, kap);
}

Future<void> _dokun(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  group('E-POSTA KODUYLA GIRIS', () {
    testWidgets('kod istenir (tesis kodu GONDERILMEZ), kodla OTURUM acilir',
        (tester) async {
      final (tel, kap) = await _sur(tester, {
        '/auth/giris/eposta-kod-iste': [(200, _tamam)],
        '/auth/giris/eposta-kod-dogrula': [(200, _jetonlar)],
      });
      await tester.enterText(
          find.byKey(const Key('giris-kimlik')), 'kerem@ornek.com');
      await _dokun(tester, find.byKey(const Key('giris-kod-modu')));
      // Kod modunda parola alani YOK.
      expect(find.text('Parola veya geçici kod'), findsNothing);
      await _dokun(tester, find.text('Kod gönder'));

      expect(tel.govdeler('/auth/giris/eposta-kod-iste').single,
          {'eposta': 'kerem@ornek.com'});
      expect(find.byKey(const Key('giris-kod-gonderildi')), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('giris-eposta-kod')), '123456');
      await _dokun(tester, find.text('Giriş yap'));

      expect(tel.govdeler('/auth/giris/eposta-kod-dogrula').single,
          {'eposta': 'kerem@ornek.com', 'kod': '123456'});
      expect(kap.read(authControllerProvider).status,
          AuthStatus.authenticated);
    });

    testWidgets('TELEFONLA kod istenmez — istekten ONCE acikca soylenir',
        (tester) async {
      final (tel, _) = await _sur(tester, {});
      await tester.enterText(
          find.byKey(const Key('giris-kimlik')), '0532 111 22 03');
      await _dokun(tester, find.byKey(const Key('giris-kod-modu')));
      await _dokun(tester, find.text('Kod gönder'));
      expect(tel.istekler, isEmpty);
      expect(find.textContaining('Kod ile giriş e-posta adresiyle çalışır'),
          findsOneWidget);
    });

    testWidgets('409 tesis_secimi_gerekli -> tesis kodu sorulur, AYNI kodla '
        'slug ile yeniden denenir', (tester) async {
      final (tel, kap) = await _sur(tester, {
        '/auth/giris/eposta-kod-iste': [(200, _tamam)],
        '/auth/giris/eposta-kod-dogrula': [
          (409, {
            'error': {
              'code': 'tesis_secimi_gerekli',
              'message': 'Bu bilgiler birden çok tesiste geçerli.',
            },
          }),
          (200, _jetonlar),
        ],
      });
      await tester.enterText(
          find.byKey(const Key('giris-kimlik')), 'kerem@ornek.com');
      await _dokun(tester, find.byKey(const Key('giris-kod-modu')));
      await _dokun(tester, find.text('Kod gönder'));
      await tester.enterText(
          find.byKey(const Key('giris-eposta-kod')), '123456');
      await _dokun(tester, find.text('Giriş yap'));

      expect(find.byKey(const Key('giris-kod-tesis-sorusu')), findsOneWidget);
      // Bicim denetimi: buyuk harf/bosluk reddedilir, istek GITMEZ.
      await tester.enterText(
          find.byKey(const Key('giris-kod-tesis')), 'Oltu Sitesi');
      await _dokun(tester, find.byKey(const Key('giris-kod-tesis-gir')));
      expect(tel.govdeler('/auth/giris/eposta-kod-dogrula'), hasLength(1));

      await tester.enterText(
          find.byKey(const Key('giris-kod-tesis')), 'oltu-sitesi');
      await _dokun(tester, find.byKey(const Key('giris-kod-tesis-gir')));
      final govdeler = tel.govdeler('/auth/giris/eposta-kod-dogrula');
      expect(govdeler, hasLength(2));
      expect(govdeler.last, {
        'eposta': 'kerem@ornek.com',
        'kod': '123456',
        'tenant_slug': 'oltu-sitesi',
      });
      expect(kap.read(authControllerProvider).status,
          AuthStatus.authenticated);
    });

    testWidgets('parolayla girise donus mod durumunu SIFIRLAR',
        (tester) async {
      await _sur(tester, {
        '/auth/giris/eposta-kod-iste': [(200, _tamam)],
      });
      await tester.enterText(
          find.byKey(const Key('giris-kimlik')), 'kerem@ornek.com');
      await _dokun(tester, find.byKey(const Key('giris-kod-modu')));
      await _dokun(tester, find.text('Kod gönder'));
      await _dokun(tester, find.byKey(const Key('giris-kod-modu')));
      expect(find.text('Parola veya geçici kod'), findsOneWidget);
      expect(find.byKey(const Key('giris-eposta-kod')), findsNothing);
    });
  });

  group('SIFREMI UNUTTUM', () {
    testWidgets('uc adim: tesis+e-posta -> kod+yeni parola -> bitti; '
        'girise donunce e-posta on-dolar', (tester) async {
      final (tel, _) = await _sur(tester, {
        '/auth/sifre/kod-iste': [(200, _tamam)],
        '/auth/sifre/dogrula-ve-ayarla': [(200, _tamam)],
      });
      await _dokun(tester, find.byKey(const Key('giris-sifremi-unuttum')));
      expect(find.byKey(const Key('sifremi-unuttum')), findsOneWidget);

      // Bicim hatasi: istek GITMEZ.
      await tester.enterText(find.byKey(const Key('sifre-tesis')), 'Oltu!');
      await tester.enterText(
          find.byKey(const Key('sifre-eposta')), 'kerem@ornek.com');
      await _dokun(tester, find.byKey(const Key('sifre-kod-gonder')));
      expect(tel.istekler, isEmpty);

      await tester.enterText(
          find.byKey(const Key('sifre-tesis')), 'oltu-sitesi');
      await _dokun(tester, find.byKey(const Key('sifre-kod-gonder')));
      expect(tel.govdeler('/auth/sifre/kod-iste').single, {
        'tenant_slug': 'oltu-sitesi',
        'eposta': 'kerem@ornek.com',
      });
      expect(find.byKey(const Key('sifre-kod-gonderildi')), findsOneWidget);

      // Zayif parola istemcide reddedilir (sunucu kuraliyla ayni).
      await tester.enterText(find.byKey(const Key('sifre-kod')), '654321');
      await tester.enterText(find.byKey(const Key('sifre-yeni')), 'zayif');
      await tester.enterText(find.byKey(const Key('sifre-tekrar')), 'zayif');
      await _dokun(tester, find.byKey(const Key('sifre-kur')));
      expect(tel.govdeler('/auth/sifre/dogrula-ve-ayarla'), isEmpty);

      await tester.enterText(
          find.byKey(const Key('sifre-yeni')), 'YeniParola1!');
      await tester.enterText(
          find.byKey(const Key('sifre-tekrar')), 'YeniParola1!');
      await _dokun(tester, find.byKey(const Key('sifre-kur')));
      expect(tel.govdeler('/auth/sifre/dogrula-ve-ayarla').single, {
        'tenant_slug': 'oltu-sitesi',
        'eposta': 'kerem@ornek.com',
        'kod': '654321',
        'yeni_parola': 'YeniParola1!',
      });
      expect(find.byKey(const Key('sifre-bitti')), findsOneWidget);

      await _dokun(tester, find.byKey(const Key('sifre-girise-don')));
      expect(find.byKey(const Key('sifremi-unuttum')), findsNothing);
      final alan = tester.widget<TextFormField>(
          find.byKey(const Key('giris-kimlik')));
      expect(alan.controller!.text, 'kerem@ornek.com');
    });

    testWidgets('kod-iste SIZINTISIZ: 429 disindaki yanitta da 2. adima '
        'gecilir; 429 hata gosterir', (tester) async {
      await _sur(tester, {
        '/auth/sifre/kod-iste': [
          (429, {
            'error': {'code': 'rate_limited', 'message': 'Çok fazla deneme.'},
          }),
        ],
      });
      await _dokun(tester, find.byKey(const Key('giris-sifremi-unuttum')));
      await tester.enterText(
          find.byKey(const Key('sifre-tesis')), 'oltu-sitesi');
      await tester.enterText(
          find.byKey(const Key('sifre-eposta')), 'kerem@ornek.com');
      await _dokun(tester, find.byKey(const Key('sifre-kod-gonder')));
      expect(find.byKey(const Key('sifre-hata')), findsOneWidget);
      expect(find.byKey(const Key('sifre-kod-gonderildi')), findsNothing);
    });

    test('tesis kodu bicimi web SLUG_RE ile ayni', () {
      expect(tesisKoduGecerli('oltu-sitesi'), isTrue);
      expect(tesisKoduGecerli('site2'), isTrue);
      expect(tesisKoduGecerli('-oltu'), isFalse);
      expect(tesisKoduGecerli('Oltu'), isFalse);
      expect(tesisKoduGecerli('oltu sitesi'), isFalse);
    });
  });
}
