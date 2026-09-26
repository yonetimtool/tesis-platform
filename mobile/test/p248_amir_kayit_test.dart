/// (P248 §1) GUVENLIK AMIRI MOBILDEN KAYDOLUR — TEL UZERINDEKI GOVDE.
///
/// Olculen kusur: kayit ekraninda amir secenegi YOKTU; yoneticinin
/// DOGRUDAN ekledigi amir "Guvenlik"i seciyordu ve sunucu (eski kural)
/// `rol_uyusmuyor` ile onu onay kuyruguna atiyordu. Artik:
///   * listede "Guvenlik amiri" var ve govdeye SUNUCU KIMLIGIYLE
///     (`guvenlik_amiri`) gider — parola ve SSO yolunda,
///   * sunucu `giris`/`hazir` donunce oturum acilir (onay beklenmez).
///
/// Taklit HTTP adapter'inda (P200 deseni, `akis-testi-dikis-yeri`): ekran ->
/// denetleyici -> depo -> api -> govde zincirinin tamami GERCEK.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/oauth_tarayici.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/auth/presentation/auth_controller.dart';
import 'package:mobile/src/features/auth/presentation/kayit_screen.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';

/// Tel uzerindeki istegi KAYDEDEN, yola gore yanit doner sahte adapter.
class _TelAdapteri implements HttpClientAdapter {
  _TelAdapteri(this.yanitlar);

  /// yol (path) -> govde. Eslesmeyen yol testi ACIKCA dusurur; sessiz
  /// bir 404, "uc hic cagrilmadi" kusurunu gizlerdi.
  final Map<String, Map<String, dynamic>> yanitlar;

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
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  /// Verilen uca giden TEK istegin govdesi.
  Map<String, dynamic> govde(String yol) {
    final eslesen = istekler.where((i) => i.yol == yol).toList();
    expect(eslesen, hasLength(1), reason: '$yol tam bir kez cagrilmali');
    return eslesen.single.govde;
  }

  List<String> get yollar => istekler.map((i) => i.yol).toList();
}

/// Tarayici donusunu taklit eder — gercek `flutter_web_auth_2` cagrilmaz.
class _SahteTarayici implements OauthTarayici {
  _SahteTarayici({this.sonucId = 'sonuc-1'});

  final String? sonucId;
  String? gidilenAdres;

  @override
  Future<String?> akisiCalistir(String adres) async {
    gidilenAdres = adres;
    return sonucId;
  }
}

const _jetonlar = {
  'access_token': 'erisim-jetonu',
  'refresh_token': 'yenileme-jetonu',
  'token_type': 'bearer',
};

/// SSO yolu icin taklit yanitlari. `rolTamamlaYaniti` degistirilerek
/// `giris` / `otp_gerekli` / `onay_bekliyor` dallari surulur.
Map<String, Map<String, dynamic>> _ssoYanitlari({
  Map<String, dynamic>? rolTamamla,
  Map<String, dynamic>? rolTamamlaDogrula,
}) =>
    {
      '/auth/oauth/saglayicilar': {
        'saglayicilar': ['google', 'microsoft', 'apple'],
      },
      '/auth/oauth/baslat/google': {'adres': 'https://oauth.test/git'},
      '/auth/oauth/sonuc': {
        'durum': 'baglama_gerekli',
        'saglayici': 'google',
        'baglama_jetonu': 'baglama-1',
        'ad': 'Ayse Sakin',
      },
      '/auth/oauth/rol-tamamla':
          rolTamamla ?? {'durum': 'giris', ..._jetonlar},
      '/auth/oauth/rol-tamamla-dogrula':
          rolTamamlaDogrula ?? {'durum': 'giris', ..._jetonlar},
    };

Future<({ProviderContainer kap, _TelAdapteri tel, _SahteTarayici tarayici})>
    _sur(
  WidgetTester tester,
  Map<String, Map<String, dynamic>> yanitlar, {
  String? sonucId = 'sonuc-1',
}) async {
  final tel = _TelAdapteri(yanitlar);
  final tarayici = _SahteTarayici(sonucId: sonucId);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = tel;

  final kap = ProviderContainer(
    overrides: [
      // TEK TAKLIT NOKTASI: tasima katmani. Ustundeki her sey GERCEK.
      dioProvider.overrideWithValue(dio),
      tokenStorageProvider.overrideWithValue(TokenStorage(BellekDepo())),
      oauthTarayiciProvider.overrideWithValue(tarayici),
    ],
  );
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: kap,
      child: l10nApp(const KayitScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return (kap: kap, tel: tel, tarayici: tarayici);
}

/// Rol sec -> yontem sec -> (SSO ise) tesis kodu adimi.
Future<void> _rolVeSaglayici(
  WidgetTester tester, {
  required String rol,
  String saglayici = 'google',
}) async {
  await tester.tap(find.byKey(Key('kayit-rol-$rol')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('kayit-yontem-$saglayici')));
  await tester.pumpAndSettle();
}

Future<void> _tesisKodu(WidgetTester tester, String kod) async {
  await tester.enterText(find.byKey(const Key('kayit-tesis-kodu')), kod);
  await tester.tap(find.byKey(const Key('kayit-rol-ozel-gonder')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('listede GUVENLIK AMIRI var ve etiketi cevrili', (tester) async {
    await _sur(tester, _ssoYanitlari());
    expect(find.byKey(const Key('kayit-rol-guvenlik_amiri')), findsOneWidget);
    expect(find.text('Güvenlik Amiri'), findsOneWidget);
    expect(KayitRolu.values.map((r) => r.kimlik), contains('guvenlik_amiri'));
  });

  testWidgets('PAROLA YOLU: amir govdesi `guvenlik_amiri` -> onaysiz oturum',
      (tester) async {
    final s = await _sur(tester, {
      '/auth/oauth/saglayicilar': {'saglayicilar': <String>[]},
      '/auth/kayit/rol-eposta-basla': {'tesis_ad': 'Oltu Sitesi'},
      '/auth/kayit/rol-eposta-dogrula': {
        'durum': 'hazir',
        'setup_token': 'kurulum-jetonu',
      },
      '/auth/set-password': _jetonlar,
    });

    await tester.tap(find.byKey(const Key('kayit-rol-guvenlik_amiri')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kayit-yontem-parola')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('kayit-ad')), 'Kemal Amir');
    await tester.enterText(
        find.byKey(const Key('kayit-eposta')), 'amir@ornek.com');
    await tester.enterText(
        find.byKey(const Key('kayit-parola')), 'CokGizliParola1!');
    await tester.tap(find.byKey(const Key('kayit-bilgi-gonder')));
    await tester.pumpAndSettle();

    await _tesisKodu(tester, 'OLTU-260715');
    await tester.pumpAndSettle();

    final basla = s.tel.govde('/auth/kayit/rol-eposta-basla');
    expect(basla['rol'], 'guvenlik_amiri');
    expect(basla['tesis_kodu'], 'OLTU-260715');
    expect(basla['eposta'], 'amir@ornek.com');

    await tester.enterText(find.byType(TextFormField).first, '424242');
    await tester.tap(find.byKey(const Key('kayit-kod-gonder')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(s.tel.govde('/auth/kayit/rol-eposta-dogrula'), {
      'tesis_kodu': 'OLTU-260715',
      'eposta': 'amir@ornek.com',
      'kod': '424242',
    });
    expect(s.tel.govde('/auth/set-password')['setup_token'], 'kurulum-jetonu');
    expect(find.byKey(const Key('kayit-onay-bekliyor')), findsNothing);
    expect(s.kap.read(authControllerProvider).status, AuthStatus.authenticated);
  });

  testWidgets('SSO YOLU: rol-tamamla govdesi `guvenlik_amiri` -> oturum',
      (tester) async {
    final s = await _sur(tester, _ssoYanitlari());
    await _rolVeSaglayici(tester, rol: 'guvenlik_amiri');
    await _tesisKodu(tester, 'OLTU-260715');

    expect(s.tel.govde('/auth/oauth/rol-tamamla'), {
      'baglama_jetonu': 'baglama-1',
      'tesis_kodu': 'OLTU-260715',
      'rol': 'guvenlik_amiri',
    });
    expect(s.kap.read(authControllerProvider).status, AuthStatus.authenticated);
  });

  testWidgets('DAVET EDILMEMIS amir: sunucu onay_bekliyor -> kart, oturum YOK',
      (tester) async {
    final s = await _sur(
      tester,
      _ssoYanitlari(rolTamamla: {'durum': 'onay_bekliyor'}),
    );
    await _rolVeSaglayici(tester, rol: 'guvenlik_amiri');
    await _tesisKodu(tester, 'OLTU-260715');
    await tester.pumpAndSettle();

    expect(s.tel.govde('/auth/oauth/rol-tamamla')['rol'], 'guvenlik_amiri');
    expect(find.byKey(const Key('kayit-onay-bekliyor')), findsOneWidget);
    expect(s.kap.read(authControllerProvider).status,
        isNot(AuthStatus.authenticated));
  });
}
