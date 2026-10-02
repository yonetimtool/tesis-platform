/// (P250 §5) GİRİŞ EKRANLARINDA E-POSTA SINIRI: 254 karakter.
///
/// Kusur: giriş ekranının tek kimlik alanı (P205/P248 kimlik kipi)
/// e-posta modunda SINIRSIZDI — biçimlendirici e-postaya dokunmuyordu.
/// Şifremi unuttum ekranının e-posta alanı 256'ya izin veriyordu.
///
/// ÖLÇÜLEN: alana 300 karakter yazılınca kutuda kalan metin. Kod ile
/// giriş aynı kimlik alanını kullanır (`_kodModu`), ayrı alan yok.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/auth/presentation/login_screen.dart';
import 'package:mobile/src/features/auth/presentation/sifremi_unuttum.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';
import 'helpers/sosyal_kapali.dart';

String _uzunEposta(int n) => '${'a' * (n - 9)}@ornek.co';

Future<void> _ciz(WidgetTester tester, Widget ekran) async {
  final kap = ProviderContainer(
    overrides: [
      ...sosyalKapali,
      tokenStorageProvider.overrideWithValue(TokenStorage(BellekDepo())),
    ],
  );
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: kap, child: l10nApp(ekran)),
  );
  await tester.pumpAndSettle();
}

String _metin(WidgetTester tester, Key anahtar) =>
    tester.widget<TextFormField>(find.byKey(anahtar)).controller!.text;

void main() {
  testWidgets('giris kimlik alani e-posta modunda 254te durur', (tester) async {
    await _ciz(tester, const LoginScreen());
    await tester.enterText(
        find.byKey(const Key('giris-kimlik')), _uzunEposta(300));
    await tester.pumpAndSettle();
    expect(_metin(tester, const Key('giris-kimlik')).length, 254);
  });

  testWidgets('254 karakterlik gecerli adres kirpilmaz', (tester) async {
    await _ciz(tester, const LoginScreen());
    final tam = _uzunEposta(254);
    await tester.enterText(find.byKey(const Key('giris-kimlik')), tam);
    await tester.pumpAndSettle();
    expect(_metin(tester, const Key('giris-kimlik')), tam);
  });

  testWidgets('telefon modu etkilenmez: numara bicimlenir', (tester) async {
    await _ciz(tester, const LoginScreen());
    await tester.enterText(find.byKey(const Key('giris-kimlik')), '05431992904');
    await tester.pumpAndSettle();
    expect(_metin(tester, const Key('giris-kimlik')), '543 199 29 04');
  });

  testWidgets('sifremi unuttum e-posta alani 254te durur', (tester) async {
    await _ciz(tester, const Scaffold(body: SifremiUnuttumFormu()));
    await tester.enterText(
        find.byKey(const Key('sifre-eposta')), _uzunEposta(300));
    await tester.pumpAndSettle();
    expect(_metin(tester, const Key('sifre-eposta')).length, 254);
  });
}
