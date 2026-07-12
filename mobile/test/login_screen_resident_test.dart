import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/auth_repository_impl.dart';
import 'package:mobile/src/features/auth/domain/auth_repository.dart';
import 'package:mobile/src/features/auth/domain/resident_login_result.dart';
import 'package:mobile/src/features/auth/domain/token_pair.dart';
import 'package:mobile/src/features/auth/presentation/login_screen.dart';

const _tokens = TokenPair(
  accessToken: 'acc',
  refreshToken: 'ref',
  tokenType: 'Bearer',
  expiresIn: 900,
);

/// login/loginResident cagrilarini kaydeden sahte auth deposu.
class _RecordingAuthRepository implements AuthRepository {
  final staffLogins = <({String email, bool rememberMe})>[];
  final residentLogins =
      <({String tenant, String unitNo, String password, bool rememberMe})>[];

  @override
  Future<bool> restoreSession() async => false;

  @override
  Future<void> login({
    required String tenantSlug,
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    staffLogins.add((email: email, rememberMe: rememberMe));
  }

  @override
  Future<ResidentLoginResult> loginResident({
    required String tenantSlug,
    required String unitNo,
    required String password,
    bool rememberMe = false,
  }) async {
    residentLogins.add((
      tenant: tenantSlug,
      unitNo: unitNo,
      password: password,
      rememberMe: rememberMe,
    ));
    return const ResidentLoginResult(
      passwordSetupRequired: false,
      tokens: _tokens,
    );
  }

  @override
  Future<void> setPassword({
    required String setupToken,
    required String newPassword,
    bool rememberMe = false,
  }) async {}

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

  testWidgets('varsayilan mod Personel: email alani gorunur, daire no yok',
      (tester) async {
    await pumpLogin(tester);

    expect(find.text('Personel'), findsOneWidget);
    expect(find.text('Sakin'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'E-posta'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Daire no'), findsNothing);
  });

  testWidgets('Sakin moduna gecis: daire no alani gelir, email gider',
      (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.text('Sakin'));
    await tester.pump();

    expect(find.widgetWithText(TextFormField, 'Daire no'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'E-posta'), findsNothing);
    // "Beni hatirla" sakin modunda da vardir.
    expect(find.byKey(const Key('remember_me_checkbox')), findsOneWidget);
  });

  testWidgets('sakin girisi loginResident\'a dogru alanlarla gider',
      (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.text('Sakin'));
    await tester.pump();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Tesis kodu (tenant)'), 'acme');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Daire no'), 'A-12');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Parola veya geçici kod'),
        'K7MR-2QWX');
    await tester.tap(find.byKey(const Key('remember_me_checkbox')));
    await tester.pump();

    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    expect(repo.staffLogins, isEmpty);
    final call = repo.residentLogins.single;
    expect(call.tenant, 'acme');
    expect(call.unitNo, 'A-12');
    expect(call.password, 'K7MR-2QWX');
    expect(call.rememberMe, isTrue);
  });

  testWidgets('Personel modunda mevcut email akisi bozulmaz', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Tesis kodu (tenant)'), 'acme');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'E-posta'), 'a@b.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Parola'), 'sifre-123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    expect(repo.residentLogins, isEmpty);
    expect(repo.staffLogins.single.email, 'a@b.com');
  });
}
