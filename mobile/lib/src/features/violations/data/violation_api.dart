import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/violation_models.dart';

/// Ihlal modulunun HTTP istemcisi:
///
///   * `GET   /violations`      → liste (created_at DESC), `?durum=` suzgeci
///   * `POST  /violations`      → kayit ac (durum='yeni')
///   * `PATCH /violations/{id}` → durum gecisi (KAPATMA yalniz admin;
///                                 kapali kayit 409; ayni duruma gecis 200)
class ViolationApi {
  ViolationApi(this._dio);

  final Dio _dio;

  Future<List<Ihlal>> fetchAll({IhlalDurum? durum}) async {
    final out = <Ihlal>[];
    var offset = 0;
    const limit = 200;
    try {
      while (true) {
        final res = await _dio.get<Map<String, dynamic>>(
          '/violations',
          queryParameters: {
            'limit': limit,
            'offset': offset,
            'durum': ?durum?.wire,
          },
        );
        final items = res.data?['items'];
        if (items is! List || items.isEmpty) break;
        for (final item in items) {
          if (item is Map) {
            out.add(Ihlal.fromJson(Map<String, dynamic>.from(item)));
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

  Future<Ihlal> create(IhlalDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/violations',
        data: draft.toJson(),
      );
      return Ihlal.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Ihlal> durumDegistir(String id, IhlalDurum durum) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/violations/$id',
        data: {'durum': durum.wire},
      );
      return Ihlal.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final violationApiProvider = Provider<ViolationApi>(
  (ref) => ViolationApi(ref.watch(dioProvider)),
);
