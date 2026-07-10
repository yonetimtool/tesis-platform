import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/rezervasyon_models.dart';

/// Rezervasyon modulunun HTTP istemcisi:
///
///   * `GET   /common-areas`        → alanlar (yonetim pasifleri de gorur)
///   * `POST  /common-areas`        → alan olustur (admin + yonetici)
///   * `PATCH /common-areas/{id}`   → alan duzenle / aktiflik (soft-delete)
///   * `GET   /reservations`        → liste (yonetim TUMU; sakin KENDI dairesi)
///   * `POST  /reservations`        → talep (YALNIZ resident; onayli ile
///                                     cakisan aralik aninda 409)
///   * `PATCH /reservations/{id}`   → onay/red (yonetim; cakisan onay 409 —
///                                     DB EXCLUDE kisiti, yaris-guvenli)
class RezervasyonApi {
  RezervasyonApi(this._dio);

  final Dio _dio;

  Future<List<OrtakAlan>> fetchAreas() async {
    final out = <OrtakAlan>[];
    var offset = 0;
    const limit = 200;
    try {
      while (true) {
        final res = await _dio.get<Map<String, dynamic>>(
          '/common-areas',
          queryParameters: {'limit': limit, 'offset': offset},
        );
        final items = res.data?['items'];
        if (items is! List || items.isEmpty) break;
        for (final item in items) {
          if (item is Map) {
            out.add(OrtakAlan.fromJson(Map<String, dynamic>.from(item)));
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

  Future<OrtakAlan> createArea(OrtakAlanDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/common-areas',
        data: draft.toJson(),
      );
      return OrtakAlan.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<OrtakAlan> updateArea(String id, Map<String, dynamic> patch) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/common-areas/$id',
        data: patch,
      );
      return OrtakAlan.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<Rezervasyon>> fetchReservations() async {
    final out = <Rezervasyon>[];
    var offset = 0;
    const limit = 200;
    try {
      while (true) {
        final res = await _dio.get<Map<String, dynamic>>(
          '/reservations',
          queryParameters: {'limit': limit, 'offset': offset},
        );
        final items = res.data?['items'];
        if (items is! List || items.isEmpty) break;
        for (final item in items) {
          if (item is Map) {
            out.add(Rezervasyon.fromJson(Map<String, dynamic>.from(item)));
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

  Future<Rezervasyon> createReservation(RezervasyonDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/reservations',
        data: draft.toJson(),
      );
      return Rezervasyon.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Yonetici karari: onayla=true → onaylandi, false → reddedildi.
  Future<Rezervasyon> decide(String id, {required bool onayla}) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/reservations/$id',
        data: {'durum': onayla ? 'onaylandi' : 'reddedildi'},
      );
      return Rezervasyon.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final rezervasyonApiProvider = Provider<RezervasyonApi>((ref) {
  return RezervasyonApi(ref.watch(dioProvider));
});
