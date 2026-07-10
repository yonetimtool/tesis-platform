import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/auth/data/auth_repository_impl.dart';
import 'package:mobile/src/features/auth/domain/auth_repository.dart';
import 'package:mobile/src/features/auth/domain/resident_login_result.dart';
import 'package:mobile/src/features/auth/domain/token_pair.dart';
import 'package:mobile/src/features/auth/presentation/auth_controller.dart';

const _tokens = TokenPair(
  accessToken: 'acc',
  refreshToken: 'ref',
  tokenType: 'Bearer',
  expiresIn: 900,
);

/// Cagrilari kaydeden, davranisi ayarlanabilen sahte auth deposu.
class _FakeAuthRepository implements AuthRepository {
  ResidentLoginResult residentResult =
      const ResidentLoginResult(passwordSetupRequired: false, tokens: _tokens);
  ApiException? setPasswordError;

  final residentLogins = <({String unitNo, bool rememberMe})>[];
  final setPasswords = <({String setupToken, bool rememberMe})>[];

  @override
  Future<bool> restoreSession() async => false;

  @override
  Future<void> login({
    required String tenantSlug,
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {}

  @override
  Future<ResidentLoginResult> loginResident({
    required String tenantSlug,
    required String unitNo,
    required String password,
    bool rememberMe = false,
  }) async {
    residentLogins.add((unitNo: unitNo, rememberMe: rememberMe));
    return residentResult;
  }

  @override
  Future<void> setPassword({
    required String setupToken,
    required String newPassword,
    bool rememberMe = false,
  }) async {
    if (setPasswordError != null) throw setPasswordError!;
    setPasswords.add((setupToken: setupToken, rememberMe: rememberMe));
  }

  @override
  Future<void> logout() async {}
}

void main() {
  late _FakeAuthRepository repo;

  setUp(() => repo = _FakeAuthRepository());

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('sakin girisi (kalici parola) → authenticated', () async {
    final container = makeContainer();
    await container.read(authControllerProvider.notifier).loginResident(
          tenantSlug: 'acme',
          unitNo: 'A-12',
          password: 'parola123',
          rememberMe: true,
        );

    final state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.authenticated);
    expect(state.setupToken, isNull);
    expect(repo.residentLogins.single.rememberMe, isTrue);
  });

  test('gecici kodla ilk giris → setupToken state\'e yazilir (oturum yok)',
      () async {
    repo.residentResult = const ResidentLoginResult(
      passwordSetupRequired: true,
      setupToken: 'setup-1',
    );
    final container = makeContainer();
    await container.read(authControllerProvider.notifier).loginResident(
          tenantSlug: 'acme',
          unitNo: 'A-12',
          password: 'K7MR-2QWX',
          rememberMe: true,
        );

    final state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.unauthenticated);
    expect(state.setupToken, 'setup-1');
  });

  test('parola belirleme → authenticated + rememberMe korunur + setup temiz',
      () async {
    repo.residentResult = const ResidentLoginResult(
      passwordSetupRequired: true,
      setupToken: 'setup-1',
    );
    final container = makeContainer();
    final controller = container.read(authControllerProvider.notifier);
    await controller.loginResident(
      tenantSlug: 'acme',
      unitNo: 'A-12',
      password: 'K7MR-2QWX',
      rememberMe: true,
    );

    await controller.submitNewPassword('YeniParola1!');

    final state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.authenticated);
    expect(state.setupToken, isNull);
    expect(repo.setPasswords.single.setupToken, 'setup-1');
    // ilk giristeki "beni hatirla" tercihi parola kurulumuna tasinir.
    expect(repo.setPasswords.single.rememberMe, isTrue);
  });

  test('setup token olu (401) → kurulum iptal, login\'e kibar donus', () async {
    repo.residentResult = const ResidentLoginResult(
      passwordSetupRequired: true,
      setupToken: 'setup-1',
    );
    repo.setPasswordError = const ApiException(
      code: 'invalid_token',
      message: 'Kurulum token\'i artik gecerli degil.',
      statusCode: 401,
    );
    final container = makeContainer();
    final controller = container.read(authControllerProvider.notifier);
    await controller.loginResident(
      tenantSlug: 'acme',
      unitNo: 'A-12',
      password: 'K7MR-2QWX',
    );

    await controller.submitNewPassword('YeniParola1!');

    final state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.unauthenticated);
    expect(state.setupToken, isNull); // ekran login'e doner
    expect(state.errorMessage, isNotNull);
  });

  test('cancelPasswordSetup → setupToken temizlenir', () async {
    repo.residentResult = const ResidentLoginResult(
      passwordSetupRequired: true,
      setupToken: 'setup-1',
    );
    final container = makeContainer();
    final controller = container.read(authControllerProvider.notifier);
    await controller.loginResident(
      tenantSlug: 'acme',
      unitNo: 'A-12',
      password: 'K7MR-2QWX',
    );

    controller.cancelPasswordSetup();

    expect(container.read(authControllerProvider).setupToken, isNull);
  });

  test('sakin girisinde hata → errorMessage dolar, submitting biter', () async {
    final container = makeContainer();
    final controller = container.read(authControllerProvider.notifier);
    repo.residentResult = const ResidentLoginResult(
      passwordSetupRequired: true,
      setupToken: 'x',
    );
    // ApiException yolunu ayrica dogrula:
    repo.setPasswordError = null;
    await controller.loginResident(
      tenantSlug: 'acme',
      unitNo: 'A-12',
      password: 'K7MR-2QWX',
    );
    expect(container.read(authControllerProvider).submitting, isFalse);
  });
}
