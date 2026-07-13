import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/integration_models.dart';

/// Entegrasyon HTTP istemcisi (C1b):
///   * `GET/POST/PATCH/DELETE /integrations` → konfig CRUD (admin+yonetici)
///   * `GET /integrations/presets` → preset sablonlari
///   * `POST /integrations/{id}/trigger` → SSRF-korumali tetik; {ok,status,error}
class IntegrationApi {
  IntegrationApi(this._dio);

  final Dio _dio;

  Future<List<Integration>> fetchAll() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/integrations',
        queryParameters: {'limit': 200},
      );
      final items = res.data?['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map((m) => Integration.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<IntegrationPreset>> fetchPresets() async {
    try {
      final res = await _dio.get<List<dynamic>>('/integrations/presets');
      return (res.data ?? const [])
          .whereType<Map>()
          .map((m) => IntegrationPreset.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Integration> create(IntegrationDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/integrations',
        data: draft.toJson(),
      );
      return Integration.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Integration> update(String id, IntegrationDraft draft) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/integrations/$id',
        data: draft.toJson(),
      );
      return Integration.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete<void>('/integrations/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<TriggerResult> trigger(
    String id, {
    String message = '',
    String title = '',
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/integrations/$id/trigger',
        data: {'message': message, 'title': title},
      );
      return TriggerResult.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final integrationApiProvider = Provider<IntegrationApi>((ref) {
  return IntegrationApi(ref.watch(dioProvider));
});
