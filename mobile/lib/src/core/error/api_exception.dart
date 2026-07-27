import 'package:dio/dio.dart';
import 'akis_hatasi.dart';

/// API hatalarinin kaba siniflandirmasi (tiplenmis hata ele alimi icin).
///
///   * [network] — sunucuya ulasilamadi / timeout (hata zarfi yok).
///   * [auth]    — kimlik/yetki hatasi (401/403; orn. invalid_credentials,
///                 token_expired). UI login'e yonlendirebilir.
///   * [api]     — diger sozlesmeli hatalar (400/404/409/422/5xx).
enum ApiErrorKind { network, auth, api }

/// Sozlesmedeki hata zarfini (`{ "error": { "code", "message" } }`) temsil eden
/// uygulama-ici istisna.
///
/// IKI KANAL (tur 13):
///   * [message] — SUNUCUDAN gelen metin (422/409/503...). Istemci CEVIRMEZ,
///     aynen gosterir. TUR 14'ten beri sunucu bu metni `Accept-Language`e
///     gore 7 dilde uretir (`backend/app/hata_metinleri.py`); basligi
///     `core/network/dil_interceptor.dart` her istege ekler.
///   * [agHatasi] — sozlesme zarfi HIC gelmediginde (timeout / baglanti yok /
///     zarfsiz govde) ISTEMCININ urettigi KIMLIK. Bu durumda [message] BOS'tur
///     ve metni cizim katmani `apiHataMetni(l10n, e)` ile uretir.
///
/// Bu ayrim tur 13'te yapildi: oncesinde `core` katmani UC TR sabit cumle
/// tasiyordu ve uygulamanin tamamina Turkce sizdiriyordu.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.agHatasi,
  });

  /// Makine-okunabilir hata kodu (orn. `invalid_credentials`, `validation_error`).
  final String code;

  /// SUNUCUNUN dondurdugu, kullaniciya gosterilebilir aciklama. Ag
  /// hatalarinda BOS'tur — o durumda [agHatasi] doludur.
  final String message;

  /// HTTP durum kodu (varsa).
  final int? statusCode;

  /// Sozlesme zarfi gelmediginde ISTEMCI hata kimligi (bkz. [AkisHatasi]).
  /// Doluysa [message] bostur; metin cizimde `apiHataMetni` ile uretilir.
  final AkisHatasi? agHatasi;

  /// [DioException]'i sozlesme hata zarfina gore [ApiException]'a cevirir.
  /// Zarf yoksa (ag hatasi, timeout, beklenmeyen govde) makul bir mesaj uretir.
  factory ApiException.fromDio(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      final sunucuMetni = err['message'] as String?;
      return ApiException(
        code: (err['code'] as String?) ?? 'unknown_error',
        // Zarf var ama mesaj yoksa metni ISTEMCI uretir → kimlik tasi.
        message: sunucuMetni ?? '',
        statusCode: status,
        agHatasi: sunucuMetni == null ? AkisHatasi.beklenmeyen : null,
      );
    }

    // Hata zarfi yok → metin ISTEMCIDE uretilir, bu yuzden KIMLIK tasinir.
    final ag = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        AkisHatasi.zamanAsimi,
      DioExceptionType.connectionError => AkisHatasi.sunucuyaUlasilamadi,
      _ => AkisHatasi.beklenmeyen,
    };
    return ApiException(
      code: 'network_error',
      message: '',
      statusCode: status,
      agHatasi: ag,
    );
  }

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
