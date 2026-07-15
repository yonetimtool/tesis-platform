import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/task_category_models.dart';

/// Gorev kategorisi HTTP istemcisi (A6):
///
///   * `GET    /task-categories`      → liste (gorev goren roller; varsayilan
///                                       yalniz aktifler, ad sirali)
///   * `POST   /task-categories`      → ekle (admin + yonetici; ayni ad 409)
///   * `DELETE /task-categories/{id}` → SOFT-DELETE (aktif=false)
class TaskCategoryApi {
  TaskCategoryApi(this._dio);

  final Dio _dio;

  Future<List<TaskCategory>> fetchAll() async {
    final out = <TaskCategory>[];
    var offset = 0;
    const limit = 200;
    try {
      while (true) {
        final res = await _dio.get<Map<String, dynamic>>(
          '/task-categories',
          queryParameters: {'limit': limit, 'offset': offset},
        );
        final items = res.data?['items'];
        if (items is! List || items.isEmpty) break;
        for (final item in items) {
          if (item is Map) {
            out.add(TaskCategory.fromJson(Map<String, dynamic>.from(item)));
          }
        }
        if (items.length < limit) break;
        offset += limit;
      }
      return out;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<TaskCategory> create(String ad) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/task-categories',
        data: {'ad': ad},
      );
      return TaskCategory.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete<void>('/task-categories/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final taskCategoryApiProvider = Provider<TaskCategoryApi>((ref) {
  return TaskCategoryApi(ref.watch(dioProvider));
});

/// Aktif gorev kategorileri (gorev tipi listesi) — filtre + kategori adi cozumu.
final taskCategoriesProvider = FutureProvider.autoDispose<List<TaskCategory>>(
  (ref) => ref.watch(taskCategoryApiProvider).fetchAll(),
);
