import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/auth/data/auth_repository_impl.dart';
import 'package:mobile/src/features/auth/domain/auth_repository.dart';
import 'package:mobile/src/features/auth/domain/phone_login_result.dart';
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
  PhoneLoginResult phoneResult =
      const PhoneLoginResult(passwordSetupRequired: false, tokens: _tokens);
  ApiException? setPasswordError;

  final phoneLogins = <({String phone, bool rememberMe})>[];
  final setPasswords = <({String setupToken, bool rememberMe})>[];

  @override
  Future<bool> restoreSession() async => false;

  @override
  Future<PhoneLoginResult> loginPhone({
    required String phone,
    required String password,
    bool rememberMe = false,
  }) async {
    phoneLogins.add((phone: phone, rememberMe: rememberMe));
    return phoneResult;
  }

  @override
  Future<void> setPassword({
    required String setupToken,
    required String newPassword,
    bool rememberMe = false,
    String? phone,
  }) async {
    if (setPasswordError != null) throw setPasswordError!;
    setPasswords.add((setupToken: setupToken, rememberMe: rememberMe));
  }

  @override
  Future<({String phone, String password})?> readSavedCredentials() async =>
      null;

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

  test('telefon girisi (kalici parola) → authenticated', () async {
    final container = makeContainer();
    await container.read(authControllerProvider.notifier).loginPhone(
          phone: '+905321112203',
          password: 'parola123',
          rememberMe: true,
        );

    final state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.authenticated);
    expect(state.setupToken, isNull);
    expect(repo.phoneLogins.single.rememberMe, isTrue);
  });

  test('gecici kodla ilk giris → setupToken state\'e yazilir (oturum yok)',
      () async {
    repo.phoneResult = const PhoneLoginResult(
      passwordSetupRequired: true,
      setupToken: 'setup-1',
    );
    final container = makeContainer();
    await container.read(authControllerProvider.notifier).loginPhone(
          phone: '+905321112203',
          password: 'K7MR-2QWX',
          rememberMe: true,
        );

    final state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.unauthenticated);
    expect(state.setupToken, 'setup-1');
  });

  test('parola belirleme → authenticated + rememberMe korunur + setup temiz',
      () async {
    repo.phoneResult = const PhoneLoginResult(
      passwordSetupRequired: true,
      setupToken: 'setup-1',
    );
    final container = makeContainer();
    final controller = container.read(authControllerProvider.notifier);
    await controller.loginPhone(
      phone: '+905321112203',
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
    repo.phoneResult = const PhoneLoginResult(
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
    await controller.loginPhone(
      phone: '+905321112203',
      password: 'K7MR-2QWX',
    );

    await controller.submitNewPassword('YeniParola1!');

    final state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.unauthenticated);
    expect(state.setupToken, isNull); // ekran login'e doner
    expect(state.errorMessage, isNotNull);
  });

  test('cancelPasswordSetup → setupToken temizlenir', () async {
    repo.phoneResult = const PhoneLoginResult(
      passwordSetupRequired: true,
      setupToken: 'setup-1',
    );
    final container = makeContainer();
    final controller = container.read(authControllerProvider.notifier);
    await controller.loginPhone(
      phone: '+905321112203',
      password: 'K7MR-2QWX',
    );

    controller.cancelPasswordSetup();

    expect(container.read(authControllerProvider).setupToken, isNull);
  });

  test('giriste hata sonrasi submitting biter', () async {
    final container = makeContainer();
    final controller = container.read(authControllerProvider.notifier);
    repo.phoneResult = const PhoneLoginResult(
      passwordSetupRequired: true,
      setupToken: 'x',
    );
    await controller.loginPhone(
      phone: '+905321112203',
      password: 'K7MR-2QWX',
    );
    expect(container.read(authControllerProvider).submitting, isFalse);
  });
}
