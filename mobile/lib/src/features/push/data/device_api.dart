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
  Future<void> register({
    required String fcmToken,
    required String platform,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/devices',
        data: {'fcm_token': fcmToken, 'platform': platform},
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
