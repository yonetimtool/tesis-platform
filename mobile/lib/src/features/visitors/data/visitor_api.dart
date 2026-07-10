import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/visitor_models.dart';

/// Ziyaretci modulunun HTTP istemcisi:
///
///   * `GET   /visitors`        → gecmis (yonetim+guvenlik TUMU; sakin KENDI
///                                 dairesi; sunucu created_at DESC siralar)
///   * `POST  /visitors`        → ziyaretci kaydi (YALNIZ security)
///   * `PATCH /visitors/{id}`   → onay/red (o dairenin aktif sakini; ikinci
///                                 yanit 409 — ilk kazanir)
class VisitorApi {
  VisitorApi(this._dio);

  final Dio _dio;

  Future<List<Visitor>> fetchAll() async {
    final out = <Visitor>[];
    var offset = 0;
    const limit = 200;
    try {
      while (true) {
        final res = await _dio.get<Map<String, dynamic>>(
          '/visitors',
          queryParameters: {'limit': limit, 'offset': offset},
        );
        final items = res.data?['items'];
        if (items is! List || items.isEmpty) break;
        for (final item in items) {
          if (item is Map) {
            out.add(Visitor.fromJson(Map<String, dynamic>.from(item)));
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

  Future<Visitor> create(VisitorDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/visitors',
        data: draft.toJson(),
      );
      return Visitor.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Sakin yaniti: onayla=true → onaylandi, false → reddedildi.
  Future<Visitor> answer(String id, {required bool onayla}) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/visitors/$id',
        data: {'durum': onayla ? 'onaylandi' : 'reddedildi'},
      );
      return Visitor.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final visitorApiProvider = Provider<VisitorApi>((ref) {
  return VisitorApi(ref.watch(dioProvider));
});
