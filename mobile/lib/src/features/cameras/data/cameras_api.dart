import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/camera_models.dart';

/// GET/POST/PATCH/DELETE /cameras istemcisi (WP-F).
/// RBAC: GET admin/yonetici/security; yazma admin/yonetici (sunucu zorlar).
class CamerasApi {
  CamerasApi(this._dio);
  final Dio _dio;

  Future<List<Camera>> fetch({int limit = 100}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/cameras',
      queryParameters: {'limit': limit},
    );
    return [
      for (final item in (res.data?['items'] as List?) ?? const [])
        if (item is Map) Camera.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<void> create({required String ad, required String streamUrl}) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/cameras',
        data: {'ad': ad, 'stream_url': streamUrl},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> update(String id,
      {String? ad, String? streamUrl}) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/cameras/$id',
        data: {
          'ad': ?ad,
          'stream_url': ?streamUrl,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete<void>('/cameras/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final camerasApiProvider = Provider<CamerasApi>((ref) {
  return CamerasApi(ref.watch(dioProvider));
});

/// Kamera listesi — ana ekran seridi + yonetim ekrani. Hata → izleyen bolum
/// sessizce gizlenir (ana ekran rehin degil).
final camerasProvider = FutureProvider.autoDispose<List<Camera>>((ref) {
  return ref.watch(camerasApiProvider).fetch();
});
