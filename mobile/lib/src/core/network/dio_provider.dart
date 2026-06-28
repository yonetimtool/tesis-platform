import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

/// Uygulama genelinde paylasilan [Dio] ornegi.
///
/// Auth token enjeksiyonu sonraki promptlarda (kaynak endpoint'leri eklendikce)
/// bir interceptor ile buraya baglanacak. Su an login/refresh public oldugu icin
/// header gerekmez.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      // 4xx/5xx'i exception olarak ele almak istiyoruz (varsayilan davranis).
    ),
  );
  return dio;
});
