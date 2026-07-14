import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/auth/data/auth_api.dart';
import 'package:mobile/src/features/auth/data/auth_repository_impl.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/auth/domain/phone_login_result.dart';
import 'package:mobile/src/features/auth/domain/token_pair.dart';

/// Davranisi test basina ayarlanabilen sahte auth API'si (HTTP'ye inmez).
class _FakeAuthApi extends AuthApi {
  _FakeAuthApi() : super(Dio());

  TokenPair loginResult = const TokenPair(
    accessToken: 'login-access',
    refreshToken: 'login-refresh',
    tokenType: 'Bearer',
    expiresIn: 900,
  );

  /// null → refresh basarili (asagidaki cift doner); dolu → bu hata firlatilir.
  ApiException? refreshError;
  TokenPair refreshResult = const TokenPair(
    accessToken: 'rotated-access',
    refreshToken: 'rotated-refresh',
    tokenType: 'Bearer',
    expiresIn: 900,
  );
  final refreshedWith = <String>[];

  @override
  Future<PhoneLoginResult> loginPhone({
    required String phone,
    required String password,
  }) async {
    return PhoneLoginResult(passwordSetupRequired: false, tokens: loginResult);
  }

  @override
  Future<TokenPair> refresh(String refreshToken) async {
    refreshedWith.add(refreshToken);
    if (refreshError != null) throw refreshError!;
    return refreshResult;
  }
}

const _tokens = TokenPair(
  accessToken: 'acc',
  refreshToken: 'ref',
  tokenType: 'Bearer',
  expiresIn: 900,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // flutter_secure_storage'i in-memory map ile taklit et.
  final store = <String, String>{};
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    store.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
      switch (call.method) {
        case 'write':
          store[args['key'] as String] = args['value'] as String;
          return null;
        case 'read':
          return store[args['key'] as String];
        case 'delete':
          store.remove(args['key'] as String);
          return null;
        case 'readAll':
          return store;
        case 'deleteAll':
          store.clear();
          return null;
        case 'containsKey':
          return store.containsKey(args['key'] as String);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  TokenStorage newStorage() => TokenStorage(const FlutterSecureStorage());

  group('TokenStorage — beni hatirla bayragi', () {
    test('varsayilan: bayrak yok → false', () async {
      expect(await newStorage().readRememberMe(), isFalse);
    });

    test('saveRememberMe(true) → true; saveRememberMe(false) → false',
        () async {
      final storage = newStorage();
      await storage.saveRememberMe(true);
      expect(await storage.readRememberMe(), isTrue);
      await storage.saveRememberMe(false);
      expect(await storage.readRememberMe(), isFalse);
    });

    test('clear() bayragi da temizler', () async {
      final storage = newStorage();
      await storage.saveRememberMe(true);
      await storage.clear();
      expect(await storage.readRememberMe(), isFalse);
    });
  });

  group('AuthRepositoryImpl — login + beni hatirla', () {
    test('rememberMe: true → bayrak kalici olarak saklanir', () async {
      final storage = newStorage();
      final repo = AuthRepositoryImpl(api: _FakeAuthApi(), storage: storage);

      await repo.loginPhone(
        phone: '+905321112203',
        password: 'p',
        rememberMe: true,
      );

      expect(await storage.readRememberMe(), isTrue);
      expect(await storage.readRefreshToken(), 'login-refresh');
    });

    test('rememberMe: false → bayrak saklanmaz (mevcut davranis)', () async {
      final storage = newStorage();
      final repo = AuthRepositoryImpl(api: _FakeAuthApi(), storage: storage);

      await repo.loginPhone(
        phone: '+905321112203',
        password: 'p',
        rememberMe: false,
      );

      expect(await storage.readRememberMe(), isFalse);
      // Token'lar bu oturum icin yine saklanir (API cagrilari icin gerekli).
      expect(await storage.readRefreshToken(), 'login-refresh');
    });
  });

  group('AuthRepositoryImpl.restoreSession — acilis akisi', () {
    test('bayrak yok → false; onceki oturumdan kalan token temizlenir',
        () async {
      final storage = newStorage();
      await storage.save(_tokens); // "hatirlama"siz onceki oturumun kalintisi
      final api = _FakeAuthApi();
      final repo = AuthRepositoryImpl(api: api, storage: storage);

      expect(await repo.restoreSession(), isFalse);
      expect(api.refreshedWith, isEmpty); // refresh hic denenmez
      expect(await storage.readRefreshToken(), isNull);
      expect(await storage.readAccessToken(), isNull);
    });

    test('bayrak var + refresh token yok → false', () async {
      final storage = newStorage();
      await storage.saveRememberMe(true);
      final repo = AuthRepositoryImpl(api: _FakeAuthApi(), storage: storage);

      expect(await repo.restoreSession(), isFalse);
    });

    test('bayrak var + refresh basarili → true, token cifti rotasyona ugrar',
        () async {
      final storage = newStorage();
      await storage.save(_tokens);
      await storage.saveRememberMe(true);
      final api = _FakeAuthApi();
      final repo = AuthRepositoryImpl(api: api, storage: storage);

      expect(await repo.restoreSession(), isTrue);
      expect(api.refreshedWith, ['ref']);
      expect(await storage.readAccessToken(), 'rotated-access');
      expect(await storage.readRefreshToken(), 'rotated-refresh');
      expect(await storage.readRememberMe(), isTrue); // bayrak korunur
    });

    test('refresh token olu (401) → false, oturum + bayrak temizlenir',
        () async {
      final storage = newStorage();
      await storage.save(_tokens);
      await storage.saveRememberMe(true);
      final api = _FakeAuthApi()
        ..refreshError = const ApiException(
          code: 'invalid_token',
          message: 'dead',
          statusCode: 401,
        );
      final repo = AuthRepositoryImpl(api: api, storage: storage);

      expect(await repo.restoreSession(), isFalse);
      expect(await storage.readRefreshToken(), isNull);
      expect(await storage.readRememberMe(), isFalse);
    });

    test('gecici ag hatasi → false ama oturum korunur (sonraki acilis dener)',
        () async {
      final storage = newStorage();
      await storage.save(_tokens);
      await storage.saveRememberMe(true);
      final api = _FakeAuthApi()
        ..refreshError = const ApiException(
          code: 'network_error',
          message: 'sunucuya ulasilamadi',
        );
      final repo = AuthRepositoryImpl(api: api, storage: storage);

      expect(await repo.restoreSession(), isFalse);
      expect(await storage.readRefreshToken(), 'ref');
      expect(await storage.readRememberMe(), isTrue);
    });

    test('beklenmeyen hata patlatilmaz → false (kibar dusus)', () async {
      final storage = newStorage();
      await storage.save(_tokens);
      await storage.saveRememberMe(true);
      final repo = AuthRepositoryImpl(
        api: _ThrowingAuthApi(),
        storage: storage,
      );

      expect(await repo.restoreSession(), isFalse);
    });
  });

  group('AuthRepositoryImpl.logout', () {
    test('token\'lar VE hatirla bayragi temizlenir', () async {
      final storage = newStorage();
      final repo = AuthRepositoryImpl(api: _FakeAuthApi(), storage: storage);
      await repo.loginPhone(
        phone: '+905321112203',
        password: 'p',
        rememberMe: true,
      );

      await repo.logout();

      expect(await storage.readAccessToken(), isNull);
      expect(await storage.readRefreshToken(), isNull);
      expect(await storage.readRememberMe(), isFalse);
    });
  });
}

/// refresh'te sozlesme disi (ApiException olmayan) hata firlatan sahte API.
class _ThrowingAuthApi extends AuthApi {
  _ThrowingAuthApi() : super(Dio());

  @override
  Future<TokenPair> refresh(String refreshToken) async {
    throw StateError('beklenmeyen');
  }
}
