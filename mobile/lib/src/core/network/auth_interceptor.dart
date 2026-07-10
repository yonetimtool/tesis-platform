import 'package:dio/dio.dart';

import '../../features/auth/data/token_storage.dart';
import '../../features/auth/domain/token_pair.dart';

/// Korunan isteklere access token ekleyen ve `401`'de otomatik refresh deneyen
/// Dio interceptor'i.
///
/// Akis (auth.md §3 — rotation):
///   1. `onRequest`: auth endpoint'leri (login/refresh) disindaki her istege
///      `Authorization: Bearer <access>` eklenir.
///   2. `onError` + `401`: `POST /auth/refresh` ile yeni `access + refresh` cifti
///      alinir (eski refresh iptal edilir — rotation), token'lar saklanir ve
///      orijinal istek yeni access ile **bir kez** yeniden denenir.
///   3. Refresh de gecersizse ([_doRefresh] null doner): token'lar silinir ve
///      [onSessionExpired] cagrilir → uygulama login'e doner.
///
/// Eszamanli `401`'lerde tek bir refresh calismasi icin [_refreshing] tek-ucus
/// (single-flight) kilidi kullanilir; bekleyen istekler ayni sonucu paylasir.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.storage,
    required this.rawDio,
    required this.onSessionExpired,
  });

  final TokenStorage storage;

  /// Interceptor'siz ham Dio. Refresh istegi ve orijinal istegin yeniden
  /// denenmesi bununla yapilir; boylece interceptor'a tekrar girilmez (sonsuz
  /// dongu engellenir).
  final Dio rawDio;

  /// Oturum kurtarilamadiginda (refresh olu) tetiklenir — auth state'i
  /// `unauthenticated` yapip login'e yonlendirmek icin.
  final Future<void> Function() onSessionExpired;

  /// Devam eden refresh calismasi (single-flight kilidi).
  Future<TokenPair?>? _refreshing;

  static const _retriedKey = '__auth_retried__';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isAuthEndpoint(options.path)) {
      final access = await storage.readAccessToken();
      if (access != null && access.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $access';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final req = err.requestOptions;
    final shouldRefresh = err.response?.statusCode == 401 &&
        !_isAuthEndpoint(req.path) &&
        req.extra[_retriedKey] != true;

    if (!shouldRefresh) {
      return handler.next(err);
    }

    final tokens = await _refresh();
    if (tokens == null) {
      // Refresh basarisiz → oturumu sonlandir, hatayi yukari ilet.
      await _expireSession();
      return handler.next(err);
    }

    try {
      req.extra[_retriedKey] = true;
      req.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      final response = await rawDio.fetch<dynamic>(req);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  /// Tek-ucus refresh: devam eden bir calisma varsa onu paylasir.
  Future<TokenPair?> _refresh() {
    return _refreshing ??=
        _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<TokenPair?> _doRefresh() async {
    final refreshToken = await storage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;
    try {
      final res = await rawDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final tokens = TokenPair.fromJson(res.data!);
      await storage.save(tokens);
      return tokens;
    } on DioException {
      // Gecersiz / suresi dolmus / iptal edilmis refresh token (401) vb.
      return null;
    }
  }

  Future<void> _expireSession() async {
    await storage.clear();
    await onSessionExpired();
  }

  /// `/auth/login`, `/auth/login-resident`, `/auth/set-password` ve
  /// `/auth/refresh` public'tir (header eklenmez, 401'de refresh denenmez).
  /// Path tam veya goreli olabilir.
  bool _isAuthEndpoint(String path) =>
      path.contains('/auth/login') ||
      path.contains('/auth/set-password') ||
      path.contains('/auth/refresh');
}
