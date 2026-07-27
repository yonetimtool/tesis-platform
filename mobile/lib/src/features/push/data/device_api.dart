import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// `/devices` endpoint'lerinin ince HTTP istemcisi (sozlesme: DeviceRegister).
/// Backend idempotent upsert yapar — ayni token'i her acilista gondermek
/// guvenlidir.
class DeviceApi {
  DeviceApi(this._dio);

  final Dio _dio;

  /// `POST /devices` — kendi cihazinin FCM token'ini kaydeder (201; ayni
  /// token tekrar gonderilirse gunceller + aktiflestirir).
  /// [dil] CIHAZIN UI dilidir: push metni sunucuda GONDERIM aninda bu dilde
  /// uretilir (tur 16). Push asenkron oldugu icin `Accept-Language` basligi
  /// o anda YOKTUR — dil cihaz kaydinda saklanmak zorundadir.
  Future<void> register({
    required String fcmToken,
    required String platform,
    required String dil,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/devices',
        data: {'fcm_token': fcmToken, 'platform': platform, 'dil': dil},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `DELETE /devices/{fcm_token}` — token'i pasiflestirir (logout).
  /// 404 (zaten yok/pasif) basari sayilir — hedef duruma zaten ulasilmis.
  Future<void> unregister(String fcmToken) async {
    try {
      await _dio.delete<void>('/devices/${Uri.encodeComponent(fcmToken)}');
    } on DioException catch (e) {
      final apiError = ApiException.fromDio(e);
      if (apiError.statusCode == 404) return;
      throw apiError;
    }
  }
}

final deviceApiProvider = Provider<DeviceApi>((ref) {
  return DeviceApi(ref.watch(dioProvider));
});
