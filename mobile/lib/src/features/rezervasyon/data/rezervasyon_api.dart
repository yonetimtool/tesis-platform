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
///   * `POST  /reservations`        → rezerve et (YALNIZ resident; ONAY YOK —
///                                     aninda onaylandi; cakisma/24s/kota 409-422)
///   * `POST  /reservations/{id}/cancel` → iptal (rezerve eden sakin + yonetim)
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

  /// `GET /common-areas/{id}/slots?date=` — o gunun slot izgarasi (dolu/bos).
  /// GIZLILIK: kim rezerve etmis DONMEZ. Pasif alan sakine 404 → bos liste.
  Future<List<Slot>> fetchSlots(String alanId, String date) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/common-areas/$alanId/slots',
        queryParameters: {'date': date},
      );
      final items = res.data?['items'];
      if (items is! List) return const [];
      return [
        for (final it in items)
          if (it is Map) Slot.fromJson(Map<String, dynamic>.from(it)),
      ];
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

  /// Rezervasyonu iptal et (rezerve eden sakin KENDI, yonetim herhangi biri).
  /// durum=iptal; slot bosalir. Zaten iptal ise 409.
  Future<Rezervasyon> cancel(String id) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/reservations/$id/cancel',
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
