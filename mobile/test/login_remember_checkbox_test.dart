import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/auth_repository_impl.dart';
import 'package:mobile/src/features/auth/domain/auth_repository.dart';
import 'package:mobile/src/features/auth/domain/resident_login_result.dart';
import 'package:mobile/src/features/auth/presentation/login_screen.dart';

/// login cagrilarini kaydeden sahte auth deposu (HTTP/storage'a inmez).
class _RecordingAuthRepository implements AuthRepository {
  final logins = <({String tenant, String email, bool rememberMe})>[];

  @override
  Future<void> login({
    required String tenantSlug,
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    logins.add((tenant: tenantSlug, email: email, rememberMe: rememberMe));
  }

  @override
  Future<ResidentLoginResult> loginResident({
    required String tenantSlug,
    required String unitNo,
    required String password,
    bool rememberMe = false,
  }) async {
    return const ResidentLoginResult(passwordSetupRequired: false);
  }

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
        find.widgetWithText(TextFormField, 'Tesis kodu (tenant)'), 'acme');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'E-posta'), 'a@b.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Parola'), 'sifre-123');
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

    await tester.tap(find.text('Giris yap'));
    await tester.pumpAndSettle();

    expect(repo.logins.single.rememberMe, isFalse);
  });

  testWidgets('isaretli giris → rememberMe=true iletilir', (tester) async {
    await pumpLogin(tester);
    await fillForm(tester);

    await tester.tap(find.byKey(const Key('remember_me_checkbox')));
    await tester.pump();
    await tester.tap(find.text('Giris yap'));
    await tester.pumpAndSettle();

    expect(repo.logins.single.rememberMe, isTrue);
  });
}
