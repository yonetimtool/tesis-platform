import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/auth_interceptor.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/auth/domain/token_pair.dart';

/// Path'e gore yanit ureten sahte Dio adapter'i.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final List<String> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.path}');
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> body, int status) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

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

  test('401 → refresh → orijinal istek yeni access ile yeniden denenir',
      () async {
    final storage = newStorage();
    await storage.save(const TokenPair(
      accessToken: 'old-access',
      refreshToken: 'good-refresh',
      tokenType: 'Bearer',
      expiresIn: 900,
    ));

    final rawAdapter = _FakeAdapter((options) {
      if (options.path == '/auth/refresh') {
        return _json({
          'access_token': 'new-access',
          'refresh_token': 'new-refresh',
          'token_type': 'Bearer',
          'expires_in': 900,
        }, 200);
      }
      // Yeniden denenen orijinal istek (raw dio ile).
      if (options.headers['Authorization'] == 'Bearer new-access') {
        return _json({'ok': true}, 200);
      }
      return _json({
        'error': {'code': 'token_expired', 'message': 'expired'}
      }, 401);
    });

    final rawDio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = rawAdapter;

    var expired = false;
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = _FakeAdapter((options) {
        // Ana dio'daki ilk istek: eski access → 401.
        return _json({
          'error': {'code': 'token_expired', 'message': 'expired'}
        }, 401);
      })
      ..interceptors.add(AuthInterceptor(
        storage: storage,
        rawDio: rawDio,
        onSessionExpired: () async => expired = true,
      ));

    final res = await dio.get<Map<String, dynamic>>('/protected');

    expect(res.statusCode, 200);
    expect(res.data!['ok'], true);
    expect(expired, isFalse);
    // Refresh sonrasi token'lar rotasyona ugradi.
    expect(await storage.readAccessToken(), 'new-access');
    expect(await storage.readRefreshToken(), 'new-refresh');
  });

  test('refresh de gecersizse oturum sonlandirilir (onSessionExpired)',
      () async {
    final storage = newStorage();
    await storage.save(const TokenPair(
      accessToken: 'old-access',
      refreshToken: 'dead-refresh',
      tokenType: 'Bearer',
      expiresIn: 900,
    ));

    final rawDio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = _FakeAdapter((options) {
        // refresh de 401 doner.
        return _json({
          'error': {'code': 'invalid_token', 'message': 'dead'}
        }, 401);
      });

    var expired = false;
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = _FakeAdapter((options) {
        return _json({
          'error': {'code': 'token_expired', 'message': 'expired'}
        }, 401);
      })
      ..interceptors.add(AuthInterceptor(
        storage: storage,
        rawDio: rawDio,
        onSessionExpired: () async => expired = true,
      ));

    await expectLater(
      dio.get<Map<String, dynamic>>('/protected'),
      throwsA(isA<DioException>()),
    );

    expect(expired, isTrue);
    // Token'lar temizlendi.
    expect(await storage.readAccessToken(), isNull);
    expect(await storage.readRefreshToken(), isNull);
  });

  test('login/refresh public — 401 refresh denenmez, header eklenmez',
      () async {
    final storage = newStorage();
    await storage.save(const TokenPair(
      accessToken: 'some-access',
      refreshToken: 'some-refresh',
      tokenType: 'Bearer',
      expiresIn: 900,
    ));

    String? seenAuthHeader = 'UNSET';
    final rawDio = Dio(BaseOptions(baseUrl: 'http://test'));
    var refreshAttempted = false;

    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = _FakeAdapter((options) {
        if (options.path == '/auth/refresh') refreshAttempted = true;
        seenAuthHeader = options.headers['Authorization'] as String?;
        return _json({
          'error': {'code': 'invalid_credentials', 'message': 'no'}
        }, 401);
      })
      ..interceptors.add(AuthInterceptor(
        storage: storage,
        rawDio: rawDio,
        onSessionExpired: () async {},
      ));

    await expectLater(
      dio.post<Map<String, dynamic>>('/auth/login', data: {}),
      throwsA(isA<DioException>()),
    );

    // Auth endpoint'ine Authorization eklenmedi ve refresh denenmedi.
    expect(seenAuthHeader, isNull);
    expect(refreshAttempted, isFalse);
  });
}
