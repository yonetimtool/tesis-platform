import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/emergency_models.dart';

/// Acil durum modulunun HTTP istemcisi (admin + security + cleaning erisir):
///
///   * `POST /emergency`       → panik alarmi (Idempotency-Key ZORUNLU;
///                               201 yeni / 200 idempotent tekrar)
///   * `GET /tenant/settings`  → yonetim numarasi (`acil_durum_telefon`)
class EmergencyApi {
  EmergencyApi(this._dio);

  final Dio _dio;

  Future<EmergencySubmitResult> submit(EmergencyDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/emergency',
        data: draft.toJson(),
        options: Options(headers: {'Idempotency-Key': draft.idempotencyKey}),
      );
      return EmergencySubmitResult(
        alert: EmergencyAlert.fromJson(res.data ?? const {}),
        wasDuplicate: res.statusCode == 200,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<TenantSettings> fetchSettings() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/tenant/settings');
      return TenantSettings.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final emergencyApiProvider = Provider<EmergencyApi>((ref) {
  return EmergencyApi(ref.watch(dioProvider));
});
