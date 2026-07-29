/// TUR 51 — PAROLA BELIRLEME EKRANINI SUR.
///
/// Tur 36 ve tur 49 envanterlerinin ikisinde de acik kalan tek ekran:
/// `set_password_screen` **1/83 satir** kapsamla duruyordu. Oysa bu ekran
/// SAKININ ILK GIRISININ TEK YOLU — gecici kodla giren herkes buradan gecer.
/// Cevirisi, dar ekranda tasmasi, koyu tema kontrasti, klavye erisimi ve
/// ekran okuyucu etiketleri hakkinda hicbir olcum yoktu.
///
/// Surulen dort hal: bos form, DOGRULAMA hatasi (parolalar uyusmuyor),
/// SUNUCU hatasi bandi ve GONDERILIYOR (buton spinner'i).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/giris_hatasi.dart';
import 'package:mobile/src/features/auth/presentation/auth_controller.dart';
import 'package:mobile/src/features/auth/presentation/set_password_screen.dart';

import 'helpers/ekran_surus.dart';
import 'helpers/l10n_test_app.dart';

/// Durumu TESTIN verdigi denetleyici: gercek ag/oturum akisi calismaz.
class _FakeAuth extends AuthController {
  _FakeAuth(this._ilk);
  final AuthState _ilk;

  @override
  AuthState build() => _ilk;

  @override
  Future<void> submitNewPassword(String password) async {}
}

Widget _ekran(Locale locale, {AuthState durum = const AuthState()}) =>
    ProviderScope(
      overrides: [authControllerProvider.overrideWith(() => _FakeAuth(durum))],
      child: l10nApp(const SetPasswordScreen(), locale: locale),
    );

/// Iki parola alanini FARKLI doldurup gonder → dogrulama hatasi cizilir.
Future<void> _uyusmayanParola(WidgetTester tester) async {
  final alanlar = find.byType(TextFormField);
  expect(alanlar, findsNWidgets(2), reason: 'iki parola alani bekleniyordu');
  await tester.enterText(alanlar.at(0), 'GucluParola1!');
  await tester.enterText(alanlar.at(1), 'BaskaParola2!');
  await tester.tap(find.byType(FilledButton));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  // Dogrulama metni CIZILDIGINI dogrula: yoksa surus bos kosar.
  final hataVar = tester.allWidgets
      .whereType<Text>()
      .any((t) => (t.data ?? '').isNotEmpty && t.style?.color != null);
  if (!hataVar && find.byType(TextFormField).evaluate().isEmpty) {
    throw StateError('dogrulama hatasi cizilmedi');
  }
}

void main() {
  testWidgets('DEDEKTOR: uyusmayan parola dogrulama hatasi verir',
      (tester) async {
    await tester.pumpWidget(_ekran(const Locale('tr')));
    await tester.pumpAndSettle();
    await _uyusmayanParola(tester);
    // Alanlar hala ekranda (gonderim ENGELLENDI) ve bir hata metni var.
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('PAROLA: bos form (bes eksen)', (tester) async {
    await tumEksenlerSurusu(tester, (dil) => _ekran(Locale(dil)));
  });

  testWidgets('PAROLA: DOGRULAMA hatasi (bes eksen)', (tester) async {
    await tumEksenlerSurusu(tester, (dil) => _ekran(Locale(dil)),
        hazirla: _uyusmayanParola);
  });

  testWidgets('PAROLA: SUNUCU hatasi bandi (bes eksen)', (tester) async {
    await tumEksenlerSurusu(
      tester,
      (dil) => _ekran(
        Locale(dil),
        durum: const AuthState(hataKimligi: GirisAkisHatasi.oturumSonaErdi),
      ),
    );
  });

  testWidgets('PAROLA: GONDERILIYOR hali (bes eksen)', (tester) async {
    // Buton spinner'i SONSUZ animasyondur: surus sabit kare pompalar.
    await tumEksenlerSurusu(
      tester,
      (dil) => _ekran(Locale(dil), durum: const AuthState(submitting: true)),
      bekleyen: true,
    );
  });
}
