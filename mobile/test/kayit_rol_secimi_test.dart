import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/auth_api.dart';
import 'package:mobile/src/features/auth/presentation/auth_controller.dart';
import 'package:mobile/src/features/auth/presentation/kayit_screen.dart';

import 'helpers/l10n_test_app.dart';

/// (P154 / Asama 3) ROL SECIMLI KAYIT — mobil ekran.
///
/// Olculen uc sey:
///   1. Brief'in DORT rolu listeleniyor (ve web'e ait `denetci` YOK),
///   2. Daire alani YALNIZ sakinde cikiyor (yoneticiden daire istenmez),
///   3. Kod dogrulanınca jeton denetleyiciye gecıyor — router'in parola
///      ekranina goturmesi buna bagli.

/// Cagrilari kaydeden sahte API. `AuthApi`yi Dio olmadan surmek icin
/// alt sinif: arayuzu genisletmek yerine yalniz iki metot ezildi.
class _SahteAuthApi extends AuthApi {
  _SahteAuthApi() : super(Dio());

  final baslaCagrilari = <Map<String, String?>>[];
  String? donenJeton;

  @override
  Future<({String tesisAd, String telefonMaskeli})> rolKayitBasla({
    required String rol,
    required String tesisKodu,
    required String telefon,
    String? daireNo,
    String? blok,
  }) async {
    baslaCagrilari.add({
      'rol': rol,
      'tesis_kodu': tesisKodu,
      'telefon': telefon,
      'daire_no': daireNo,
    });
    return (tesisAd: 'Oltu Sitesi', telefonMaskeli: '+9053***203');
  }

  @override
  Future<String> rolKayitDogrula({
    required String telefon,
    required String kod,
  }) async {
    return donenJeton ?? 'kurulum-jetonu';
  }
}

Future<ProviderContainer> _sur(WidgetTester tester, _SahteAuthApi api) async {
  final kap = ProviderContainer(
    overrides: [authApiProvider.overrideWithValue(api)],
  );
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: kap,
      child: l10nApp(const KayitScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return kap;
}

void main() {
  testWidgets('brief’in DORT rolu listeleniyor, denetci YOK', (tester) async {
    await _sur(tester, _SahteAuthApi());

    for (final kimlik in ['yonetici', 'resident', 'security', 'tesis_gorevlisi']) {
      expect(
        find.byKey(Key('kayit-rol-$kimlik')),
        findsOneWidget,
        reason: '$kimlik rolu listede yok',
      );
    }
    // `denetci` WEB rolu; mobilde gosterilmesi brief'e aykiri olurdu.
    expect(find.byKey(const Key('kayit-rol-denetci')), findsNothing);
    expect(KayitRolu.values.length, 4);
  });

  testWidgets('daire alani YALNIZ sakinde cikar', (tester) async {
    final api = _SahteAuthApi();
    await _sur(tester, api);

    // Yonetici: daire alani YOK.
    await tester.tap(find.byKey(const Key('kayit-rol-yonetici')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.meeting_room_outlined), findsNothing);

    // Geri don, sakini sec: daire alani VAR.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kayit-rol-resident')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.meeting_room_outlined), findsOneWidget);
  });

  testWidgets('kod dogrulaninca jeton DENETLEYICIYE gecer', (tester) async {
    final api = _SahteAuthApi()..donenJeton = 'jeton-42';
    final kap = await _sur(tester, api);

    await tester.tap(find.byKey(const Key('kayit-rol-yonetici')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'OLTU-260715',
    );
    await tester.enterText(find.byType(TextFormField).at(1), '5321112203');
    await tester.tap(find.byKey(const Key('kayit-kimlik-gonder')));
    await tester.pumpAndSettle();

    // Telefon E.164'e NORMALLESTIRILEREK gitti (giris ekraniyla ayni kural).
    expect(api.baslaCagrilari.single['telefon'], '+905321112203');
    expect(api.baslaCagrilari.single['rol'], 'yonetici');
    // Yoneticiden daire ISTENMEDI.
    expect(api.baslaCagrilari.single['daire_no'], isNull);

    await tester.enterText(find.byType(TextFormField).first, '424242');
    await tester.tap(find.byKey(const Key('kayit-kod-gonder')));
    // `pumpAndSettle` DEGIL: basarili yolda `_bekliyor` BILEREK `true`
    // kaliyor (router ekrani degistirene kadar cift gonderimi engeller) ve
    // spinner sonsuz animasyon oldugu icin agac hic "oturmaz". Gercek
    // uygulamada bu bir sorun degil — orada router ekrani kaldiriyor.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Ekran KENDI navigasyonunu yapmaz; jetonu denetleyiciye birakir ve
    // router `setupToken` dolunca parola ekranina goturur.
    expect(kap.read(authControllerProvider).setupToken, 'jeton-42');
  });
}
