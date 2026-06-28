import 'package:dio/dio.dart';

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

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
