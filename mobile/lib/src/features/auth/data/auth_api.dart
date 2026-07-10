import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/resident_login_result.dart';
import '../domain/token_pair.dart';

/// Auth endpoint'lerinin ince HTTP istemcisi. DioException'lari sozlesme hata
/// zarfina gore [ApiException]'a cevirir.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  /// `POST /auth/login` — LoginRequest semasina birebir uyar.
  Future<TokenPair> login({
    required String tenantSlug,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'tenant_slug': tenantSlug,
          'email': email,
          'password': password,
        },
      );
      return TokenPair.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /auth/login-resident` — sakin girisi: daire no + (kod|parola).
  Future<ResidentLoginResult> loginResident({
    required String tenantSlug,
    required String unitNo,
    required String password,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/login-resident',
        data: {
          'tenant_slug': tenantSlug,
          'unit_no': unitNo,
          'password': password,
        },
      );
      return ResidentLoginResult.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /auth/set-password` — ilk giristeki zorunlu parola belirleme.
  /// Basarida tam oturum (TokenPair) doner; gecici kod sunucuda silinir.
  Future<TokenPair> setPassword({
    required String setupToken,
    required String newPassword,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/set-password',
        data: {'setup_token': setupToken, 'new_password': newPassword},
      );
      return TokenPair.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /auth/refresh` — refresh token ile yeni cift al (rotation).
  Future<TokenPair> refresh(String refreshToken) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      return TokenPair.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioProvider));
});
