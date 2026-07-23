import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/auth_repository_impl.dart';
import 'package:mobile/src/features/auth/domain/auth_repository.dart';
import 'package:mobile/src/features/auth/domain/phone_login_result.dart';
import 'package:mobile/src/features/auth/domain/token_pair.dart';
import 'package:mobile/src/features/auth/presentation/login_screen.dart';

const _tokens = TokenPair(
  accessToken: 'acc',
  refreshToken: 'ref',
  tokenType: 'Bearer',
  expiresIn: 900,
);

/// loginPhone cagrilarini kaydeden sahte auth deposu.
class _RecordingAuthRepository implements AuthRepository {
  final phoneLogins =
      <({String phone, String password, bool rememberMe})>[];

  @override
  Future<bool> restoreSession() async => false;

  @override
  Future<PhoneLoginResult> loginPhone({
    required String phone,
    required String password,
    bool rememberMe = false,
  }) async {
    phoneLogins.add((phone: phone, password: password, rememberMe: rememberMe));
    return const PhoneLoginResult(passwordSetupRequired: false, tokens: _tokens);
  }

  @override
  Future<void> setPassword({
    required String setupToken,
    required String newPassword,
    bool rememberMe = false,
    String? phone,
  }) async {}

  @override
  Future<({String phone, String password})?> readSavedCredentials() async =>
      null;

  @override
  Future<void> logout() async {}
}

void main() {
  late _RecordingAuthRepository repo;

  setUp(() => repo = _RecordingAuthRepository());

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('telefon + parola alanlari var; tenant/e-posta/mod yok',
      (tester) async {
    await pumpLogin(tester);

    expect(find.widgetWithText(TextFormField, 'Cep telefonu'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Parola veya geçici kod'),
      findsOneWidget,
    );
    // Eski iki-modlu akisin izleri kalmadi.
    expect(find.text('Personel'), findsNothing);
    expect(find.text('Sakin'), findsNothing);
    expect(
      find.widgetWithText(TextFormField, 'Tesis kodu (tenant)'),
      findsNothing,
    );
    expect(find.widgetWithText(TextFormField, 'E-posta'), findsNothing);
  });

  testWidgets('giris loginPhone\'a telefon + rememberMe ile gider',
      (tester) async {
    await pumpLogin(tester);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Cep telefonu'), '05321112203');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Parola veya geçici kod'),
        'K7MR-2QWX');
    await tester.tap(find.byKey(const Key('remember_me_checkbox')));
    await tester.pump();

    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    final call = repo.phoneLogins.single;
    expect(call.phone, '05321112203');
    expect(call.password, 'K7MR-2QWX');
    expect(call.rememberMe, isTrue);
  });

  testWidgets('bos alanlarla giris → dogrulama, cagri yapilmaz',
      (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    expect(repo.phoneLogins, isEmpty);
    expect(find.text('Telefon zorunludur'), findsOneWidget);
  });
}
