import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/unit_access_models.dart';

/// Tek-seferlik daire erisim izni HTTP istemcisi:
///
///   * `POST  /unit-access-request`        → talep ac (admin/yonetici)
///   * `GET   /unit-access-request`        → talepler (yonetici kendi;
///                                            resident kendi dairesine gelen)
///   * `PATCH /unit-access-request/{id}`   → onayla/reddet (dairenin sakini)
class UnitAccessApi {
  UnitAccessApi(this._dio);

  final Dio _dio;

  Future<List<UnitAccessRequest>> fetchAll() async {
    final out = <UnitAccessRequest>[];
    var offset = 0;
    const limit = 200;
    try {
      while (true) {
        final res = await _dio.get<Map<String, dynamic>>(
          '/unit-access-request',
          queryParameters: {'limit': limit, 'offset': offset},
        );
        final items = res.data?['items'];
        if (items is! List || items.isEmpty) break;
        for (final item in items) {
          if (item is Map) {
            out.add(
              UnitAccessRequest.fromJson(Map<String, dynamic>.from(item)),
            );
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

  /// Talep ac — daire NUMARASIYLA (guvenlik/yonetim unit_id yetkisi yok).
  Future<UnitAccessRequest> createRequest(String unitNo) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/unit-access-request',
        data: {'unit_no': unitNo},
      );
      return UnitAccessRequest.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Sakin karari: onayla=true → onaylandi, false → reddedildi (ikinci 409).
  Future<UnitAccessRequest> decide(String id, {required bool onayla}) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/unit-access-request/$id',
        data: {'durum': onayla ? 'onaylandi' : 'reddedildi'},
      );
      return UnitAccessRequest.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final unitAccessApiProvider = Provider<UnitAccessApi>((ref) {
  return UnitAccessApi(ref.watch(dioProvider));
});
