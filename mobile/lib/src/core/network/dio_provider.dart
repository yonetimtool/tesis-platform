import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/token_storage.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../config/app_config.dart';
import 'auth_interceptor.dart';

BaseOptions _baseOptions() => BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      // 4xx/5xx'i exception olarak ele almak istiyoruz (varsayilan davranis).
    );

/// Interceptor'siz **ham** Dio.
///
/// Sadece [AuthInterceptor] tarafindan kullanilir: refresh istegi ve `401`
/// sonrasi orijinal istegin yeniden denenmesi bununla yapilir; boylece
/// interceptor'a tekrar girilmez (sonsuz refresh dongusu engellenir).
final rawDioProvider = Provider<Dio>((ref) {
  return Dio(_baseOptions());
});

/// Uygulama genelinde paylasilan [Dio] ornegi.
///
/// [AuthInterceptor] ile: her korunan istege access token eklenir, `401`'de
/// otomatik `POST /auth/refresh` denenir, refresh de olduyse oturum sonlandirilir
/// (login'e donus). Login/refresh public oldugu icin onlara header eklenmez.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(_baseOptions());
  dio.interceptors.add(
    AuthInterceptor(
      storage: ref.watch(tokenStorageProvider),
      rawDio: ref.watch(rawDioProvider),
      // ref.read geç (cagri aninda) calisir → provider init dongusu olusmaz.
      onSessionExpired: () async {
        ref.read(authControllerProvider.notifier).onSessionExpired();
      },
    ),
  );
  return dio;
});
