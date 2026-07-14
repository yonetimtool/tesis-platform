import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/auth_repository_impl.dart';
import 'package:mobile/src/features/auth/domain/auth_repository.dart';
import 'package:mobile/src/features/auth/domain/phone_login_result.dart';
import 'package:mobile/src/features/auth/presentation/login_screen.dart';

/// loginPhone cagrilarini kaydeden sahte auth deposu (HTTP/storage'a inmez).
class _RecordingAuthRepository implements AuthRepository {
  final logins = <({String phone, bool rememberMe})>[];

  @override
  Future<PhoneLoginResult> loginPhone({
    required String phone,
    required String password,
    bool rememberMe = false,
  }) async {
    logins.add((phone: phone, rememberMe: rememberMe));
    return const PhoneLoginResult(passwordSetupRequired: false);
  }

  @override
  Future<void> signup({
    required String tenantAd,
    required String yoneticiAd,
    required String phone,
    required String password,
    bool rememberMe = false,
  }) async {}

  @override
  Future<void> setPassword({
    required String setupToken,
    required String newPassword,
    bool rememberMe = false,
  }) async {}

  @override
  Future<bool> restoreSession() async => false;

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

  Future<void> fillForm(WidgetTester tester) async {
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Cep telefonu'), '05321112203');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Parola veya geçici kod'),
        'sifre-123');
  }

  testWidgets('"Beni hatirla" kutusu vardir ve varsayilan ISARETSIZDIR',
      (tester) async {
    await pumpLogin(tester);

    final checkbox = find.byKey(const Key('remember_me_checkbox'));
    expect(checkbox, findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(checkbox).value,
      isFalse,
    );
  });

  testWidgets('isaretsiz giris → rememberMe=false iletilir', (tester) async {
    await pumpLogin(tester);
    await fillForm(tester);

    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    expect(repo.logins.single.rememberMe, isFalse);
  });

  testWidgets('isaretli giris → rememberMe=true iletilir', (tester) async {
    await pumpLogin(tester);
    await fillForm(tester);

    await tester.tap(find.byKey(const Key('remember_me_checkbox')));
    await tester.pump();
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    expect(repo.logins.single.rememberMe, isTrue);
  });
}
