import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/call_models.dart';

/// Rol-bazli arama HTTP istemcisi:
///
///   * `GET /call-target/{user_id}` → numara-gizlilik kapisi. 200 => aranabilir
///     (numara + tel: doner); 403 (yetkisiz yon) / 404 (rizasiz/numarasiz) =>
///     ApiException (statusCode ile ayirt edilir; numara ASLA gelmez).
class CallApi {
  CallApi(this._dio);

  final Dio _dio;

  Future<CallTarget> resolve(String userId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/call-target/$userId');
      return CallTarget.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final callApiProvider = Provider<CallApi>((ref) {
  return CallApi(ref.watch(dioProvider));
});
