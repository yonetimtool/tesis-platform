import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/etkinlik_models.dart';

/// Etkinlik modulunun HTTP istemcisi:
///
///   * `GET    /events`           → liste (TUM roller; seffaf sayilar +
///                                   kullanicinin kendi beyani; tarih DESC)
///   * `POST   /events`           → olustur (admin + yonetici; sakinlere push)
///   * `PATCH  /events/{id}`      → duzenle (admin + yonetici)
///   * `DELETE /events/{id}`      → sil (admin + yonetici; RSVP'ler CASCADE)
///   * `PUT    /events/{id}/rsvp` → RSVP ver/degistir (YALNIZ resident;
///                                   kullanici basina TEK kayit — upsert)
class EtkinlikApi {
  EtkinlikApi(this._dio);

  final Dio _dio;

  Future<List<Etkinlik>> fetchAll() async {
    final out = <Etkinlik>[];
    var offset = 0;
    const limit = 200;
    try {
      while (true) {
        final res = await _dio.get<Map<String, dynamic>>(
          '/events',
          queryParameters: {'limit': limit, 'offset': offset},
        );
        final items = res.data?['items'];
        if (items is! List || items.isEmpty) break;
        for (final item in items) {
          if (item is Map) {
            out.add(Etkinlik.fromJson(Map<String, dynamic>.from(item)));
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

  Future<Etkinlik> create(EtkinlikDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/events',
        data: draft.toJson(),
      );
      return Etkinlik.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Etkinlik> update(String id, EtkinlikDraft draft) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/events/$id',
        data: draft.toJson(),
      );
      return Etkinlik.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete<void>('/events/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// RSVP beyani — yanit guncel SEFFAF sayilarla etkinligin kendisidir
  /// (UI sayaci aninda gunceller).
  Future<Etkinlik> rsvp(String id, KatilimDurum durum) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/events/$id/rsvp',
        data: {'durum': durum.wire},
      );
      return Etkinlik.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final etkinlikApiProvider = Provider<EtkinlikApi>((ref) {
  return EtkinlikApi(ref.watch(dioProvider));
});
