import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/camera_models.dart';

/// `/cameras` istemcisi.
///
/// RBAC (sunucu zorlar): OKUMA tum roller AMA liste ROL'E GORE SUZULUR —
/// admin/yonetici/security tumunu, resident/tesis_gorevlisi yalniz
/// `aktif && sakin_gorebilir` kameralari alir. Istemci suzgeci TEKRARLAMAZ:
/// ekranda gelen liste ne ise o cizilir (gizli kamera yaniti hic terk etmez).
/// YAZMA admin + yonetici.
class CamerasApi {
  CamerasApi(this._dio);
  final Dio _dio;

  Future<List<Camera>> fetch({int limit = 100}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/cameras',
        queryParameters: {'limit': limit},
      );
      return [
        for (final item in (res.data?['items'] as List?) ?? const [])
          if (item is Map) Camera.fromJson(Map<String, dynamic>.from(item)),
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Camera> create(CameraDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/cameras',
        data: draft.toCreateJson(),
      );
      return Camera.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Camera> update(String id, CameraDraft draft) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/cameras/$id',
        data: draft.toUpdateJson(),
      );
      return Camera.fromJson(res.data ?? const {});
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

/// Kamera listesi — ana ekran seridi + kamera ekrani AYNI saglayiciyi
/// kullanir (tek istek, sunucu suzgeci). Hata → izleyen bolum sessizce
/// gizlenir (ana ekran rehin degil).
final camerasProvider = FutureProvider.autoDispose<List<Camera>>((ref) {
  return ref.watch(camerasApiProvider).fetch();
});
