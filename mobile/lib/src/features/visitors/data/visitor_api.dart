import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/visitor_models.dart';

/// Ziyaretci modulunun HTTP istemcisi:
///
///   * `GET   /visitors`        → LOG gecmisi (security TUMU; resident kendine
///                                 hedeflenen; admin/yonetici ?unit_id ile
///                                 tek-seferlik izinle — sunucu created_at DESC)
///   * `POST  /visitors`        → ziyaretci LOG kaydi (YALNIZ security; hedef
///                                 sakine bilgilendirme push'u — onay/red YOK)
///   * `GET   /units/by-no/{no}/residents` → hedef sakin secicisi
class VisitorApi {
  VisitorApi(this._dio);

  final Dio _dio;

  /// [unitId] verilirse yalniz o dairenin kayitlari cekilir — admin/yonetici
  /// tek-seferlik izin gorunumu (?unit_id). Izin YOKSA/tukendiyse sunucu 403
  /// doner (ApiException statusCode=403).
  Future<List<Visitor>> fetchAll({String? unitId}) async {
    final out = <Visitor>[];
    var offset = 0;
    const limit = 200;
    try {
      while (true) {
        final res = await _dio.get<Map<String, dynamic>>(
          '/visitors',
          queryParameters: {
            'limit': limit,
            'offset': offset,
            'unit_id': ?unitId,
          },
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

  /// Hedef sakin secicisi: dairenin AKTIF sakinleri (user_id + ad).
  /// `GET /units/by-no/{unit_no}/residents` — security+admin+yonetici okur.
  Future<List<UnitResidentBrief>> fetchUnitResidents(String unitNo) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/units/by-no/$unitNo/residents',
      );
      return (res.data ?? const [])
          .whereType<Map>()
          .map((m) => UnitResidentBrief.fromJson(Map<String, dynamic>.from(m)))
          .toList();
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

  /// `PATCH /visitors/{id}` — guvenlik kaydi duzenler (ad/daire/hedef/not).
  /// notlar bos ise ACIKCA null gonderilir (sunucuda temizlenir).
  Future<Visitor> update(
    String id, {
    required String ziyaretciAd,
    required String unitNo,
    required String targetResidentUserId,
    String? notlar,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/visitors/$id',
        data: {
          'ziyaretci_ad': ziyaretciAd,
          'unit_no': unitNo,
          'target_resident_user_id': targetResidentUserId,
          'notlar': (notlar != null && notlar.isNotEmpty) ? notlar : null,
        },
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

/// Ziyaretci listesi — sakin ana ekran Son Hareketler akisi. Sunucu rol
/// suzer (sakin yalniz kendine hedeflenenleri gorur). Hata → bolum gizli.
final visitorsListProvider =
    FutureProvider.autoDispose<List<Visitor>>((ref) {
  return ref.watch(visitorApiProvider).fetchAll();
});
