// (P140.4 · P233 §2) DIL SECICI MODALI.
//
// Kerem (P140.4): "simgeye dokununca ekranin ortasinda dil secenekleri
// modal olarak acilir; secilen dil aninda uygulanir ve kalici olarak
// saklanir. 7 dil."
//
// (P233 §2) UST BARDAKI DIL SIMGESI KALDIRILDI (yerine ARAMA geldi; dil
// zaten Ayarlar'dan degistirilebiliyor). Modalin KENDISI duruyor ve bu
// dosya onu olcmeye devam ediyor — testteki `DilButonu` yerine yerel bir
// acici dugme kullaniliyor. Modali de silmek, ileride baska bir yerden
// acmak isteyeni sifirdan yazmaya zorlardi.
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
          home: Scaffold(
            appBar: null,
            body: Center(
              child: Builder(
                builder: (ctx) => IconButton(
                  key: const Key('home-dil'),
                  tooltip: ctx.l10n.dilSeciciBaslik,
                  icon: const Icon(Icons.translate),
                  onPressed: () => dilModaliniAc(ctx),
                ),
              ),
            ),
          ),
        ),
      );

  // (P233 §2) "SIMGE 44pt DOKUNMA HEDEFI" TESTI BURADAN KALKTI.
  //
  // O test `DilButonu`yu olcuyordu; buton kaldirilinca geriye yalnizca bu
  // dosyanin KENDI actigi yerel dugme kalirdi — yani test kendi kurdugu
  // widget'i olcerdi ve hicbir sey kanitlamazdi. Ust bardaki dugmenin
  // dokunma hedefi kilidi `p233_ust_bar_arama_test.dart` icinde, ARAMA
  // dugmesi uzerinde duruyor.

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
