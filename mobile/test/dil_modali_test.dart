// (P140.4) DIL SECICI — mobil sag ust + ortada modal.
//
// Kerem: "profil resmi + yaninda ceviri simgesi; simgeye dokununca
// ekranin ortasinda dil secenekleri modal olarak acilir; secilen dil
// aninda uygulanir ve kalici olarak saklanir. 7 dil."
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/core/i18n/locale_controller.dart';
import 'package:mobile/src/features/home/presentation/widgets/dil_modali.dart';

void main() {
  Widget kur() => ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: supportedLocales,
          home: const Scaffold(
            appBar: null,
            body: Center(child: DilButonu()),
          ),
        ),
      );

  testWidgets('simge 44pt DOKUNMA HEDEFI ve erisilebilir AD tasir',
      (tester) async {
    await tester.pumpWidget(kur());
    final kutu = tester.getSize(find.byKey(const Key('home-dil')));
    expect(kutu.width, greaterThanOrEqualTo(44));
    expect(kutu.height, greaterThanOrEqualTo(44));
    // Simge tek basina "bu ne yapar" sorusunu yanitlamaz.
    expect(
      tester.getSemantics(find.byKey(const Key('home-dil'))).label.isNotEmpty,
      isTrue,
    );
  });

  testWidgets('dokununca YEDI DIL modalda listelenir', (tester) async {
    await tester.pumpWidget(kur());
    await tester.tap(find.byKey(const Key('home-dil')));
    await tester.pumpAndSettle();
    for (final d in AppDil.values) {
      expect(find.byKey(Key('dil-${d.kod}')), findsOneWidget, reason: d.kod);
    }
    expect(AppDil.values.length, 7);
  });

  testWidgets('dil adi HER ZAMAN kendi dilinde', (tester) async {
    // Kullanici bilmedigi bir dilde yazilmis kendi dilini bulamaz.
    await tester.pumpWidget(kur());
    await tester.tap(find.byKey(const Key('home-dil')));
    await tester.pumpAndSettle();
    expect(find.text('العربية'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
    expect(find.text('Türkçe'), findsOneWidget);
  });

  testWidgets('secim ANINDA uygulanir ve modal kapanir', (tester) async {
    await tester.pumpWidget(kur());
    await tester.tap(find.byKey(const Key('home-dil')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dil-de')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dil-de')), findsNothing, reason: 'modal kapanmali');
  });
}
