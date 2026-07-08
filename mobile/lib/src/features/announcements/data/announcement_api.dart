import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/announcement_models.dart';

/// Duyuru modulunun HTTP istemcisi:
///
///   * `GET    /announcements`      → liste (created_at DESC; TUM roller)
///   * `POST   /announcements`      → olustur (admin + yonetici)
///   * `PATCH  /announcements/{id}` → duzenle (admin + yonetici)
///   * `DELETE /announcements/{id}` → sil (admin + yonetici)
class AnnouncementApi {
  AnnouncementApi(this._dio);

  final Dio _dio;

  Future<List<Announcement>> fetchAll() async {
    final out = <Announcement>[];
    var offset = 0;
    const limit = 200;
    try {
      while (true) {
        final res = await _dio.get<Map<String, dynamic>>(
          '/announcements',
          queryParameters: {'limit': limit, 'offset': offset},
        );
        final items = res.data?['items'];
        if (items is! List || items.isEmpty) break;
        for (final item in items) {
          if (item is Map) {
            out.add(Announcement.fromJson(Map<String, dynamic>.from(item)));
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

  Future<Announcement> create(AnnouncementDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/announcements',
        data: draft.toJson(),
      );
      return Announcement.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Announcement> update(String id, AnnouncementDraft draft) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/announcements/$id',
        data: draft.toJson(),
      );
      return Announcement.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete<void>('/announcements/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final announcementApiProvider = Provider<AnnouncementApi>((ref) {
  return AnnouncementApi(ref.watch(dioProvider));
});
