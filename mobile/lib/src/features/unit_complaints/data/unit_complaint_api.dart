import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/unit_complaint_models.dart';

/// Daire sikayeti (D1) HTTP istemcisi — bina semasi detayini + sakin sikayet
/// akisini besler:
///   * `GET  /unit-complaints?target_unit_id=&durum=acik` → bir dairenin ANONIM
///     sikayet listesi (kategori + tarih; notlar yalniz yonetimde).
///   * `POST /unit-complaints` → daire sikayeti ac (YALNIZ resident; 409 spam).
///
/// TAM ANONIM: yanitlarda complainant YOKTUR (sunucu zorlar).
class UnitComplaintApi {
  UnitComplaintApi(this._dio);

  final Dio _dio;

  /// Bir dairenin sikayetleri. [acikOnly] true ise yalniz ACIK kayitlar
  /// (building-map sayimiyla tutarli); false ise tum gecmis.
  Future<List<UnitComplaint>> fetchForUnit(
    String unitId, {
    bool acikOnly = true,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/unit-complaints',
        queryParameters: {
          'target_unit_id': unitId,
          if (acikOnly) 'durum': 'acik',
          'limit': 200,
        },
      );
      final items = res.data?['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map((m) => UnitComplaint.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Sakinin KENDI actigi sikayetler (GET /unit-complaints/mine) — "gitti mi"
  /// geri bildirimi. Yalniz resident; unit_no + kategori + tarih + durum
  /// (yogunluk/renk/complainant YOK).
  Future<List<UnitComplaint>> fetchMine() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/unit-complaints/mine',
        queryParameters: {'limit': 200},
      );
      final items = res.data?['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map((m) => UnitComplaint.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Daire sikayeti ac (YALNIZ resident). Ayni daireye ayni KATEGORIDE 7 gunde
  /// 2. kez -> 409; kendi blogun disi -> 403.
  Future<UnitComplaint> file(UnitComplaintDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/unit-complaints',
        data: draft.toJson(),
      );
      return UnitComplaint.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final unitComplaintApiProvider = Provider<UnitComplaintApi>((ref) {
  return UnitComplaintApi(ref.watch(dioProvider));
});
