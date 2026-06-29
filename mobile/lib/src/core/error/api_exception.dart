import 'package:dio/dio.dart';

/// API hatalarinin kaba siniflandirmasi (tiplenmis hata ele alimi icin).
///
///   * [network] — sunucuya ulasilamadi / timeout (hata zarfi yok).
///   * [auth]    — kimlik/yetki hatasi (401/403; orn. invalid_credentials,
///                 token_expired). UI login'e yonlendirebilir.
///   * [api]     — diger sozlesmeli hatalar (400/404/409/422/5xx).
enum ApiErrorKind { network, auth, api }

/// Sozlesmedeki hata zarfini (`{ "error": { "code", "message" } }`) temsil eden
/// uygulama-ici istisna. UI bu istisnanin [message] alanini kullaniciya gosterir.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  /// Makine-okunabilir hata kodu (orn. `invalid_credentials`, `validation_error`).
  final String code;

  /// Kullaniciya gosterilebilir aciklama.
  final String message;

  /// HTTP durum kodu (varsa).
  final int? statusCode;

  /// [DioException]'i sozlesme hata zarfina gore [ApiException]'a cevirir.
  /// Zarf yoksa (ag hatasi, timeout, beklenmeyen govde) makul bir mesaj uretir.
  factory ApiException.fromDio(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      return ApiException(
        code: (err['code'] as String?) ?? 'unknown_error',
        message: (err['message'] as String?) ?? _genericMessage,
        statusCode: status,
      );
    }

    // Hata zarfi yok → baglanti/timeout gibi durumlar icin anlamli mesaj.
    final message = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'Sunucuya baglanirken zaman asimi olustu.',
      DioExceptionType.connectionError =>
        'Sunucuya ulasilamadi. Ag baglantinizi ve sunucu adresini kontrol edin.',
      _ => _genericMessage,
    };
    return ApiException(
      code: 'network_error',
      message: message,
      statusCode: status,
    );
  }

  static const String _genericMessage =
      'Beklenmeyen bir hata olustu. Lutfen tekrar deneyin.';

  /// Hatanin kaba turu — UI'da ayrim icin (orn. ag hatasinda "tekrar dene",
  /// auth hatasinda login'e donus).
  ApiErrorKind get kind {
    if (code == 'network_error') return ApiErrorKind.network;
    if (statusCode == 401 ||
        statusCode == 403 ||
        const {
          'invalid_credentials',
          'unauthorized',
          'forbidden',
          'token_expired',
          'invalid_token',
        }.contains(code)) {
      return ApiErrorKind.auth;
    }
    return ApiErrorKind.api;
  }

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
