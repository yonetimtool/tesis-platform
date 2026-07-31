import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/unit_tanim_models.dart';

/// `/unit-tipleri` + `/unit-gruplari` istemcisi (P26).
///
/// RBAC (sunucu zorlar): YAZMA admin+yonetici; OKUMA saha rollerine de acik
/// (daire listeleri tip/grup adini gosterir); sakin ERISEMEZ.
class UnitTanimApi {
  UnitTanimApi(this._dio);
  final Dio _dio;

  Future<List<UnitTip>> fetchTipler({bool? aktif}) async =>
      _liste('/unit-tipleri', aktif, UnitTip.fromJson);

  Future<List<UnitGrup>> fetchGruplar({bool? aktif}) async =>
      _liste('/unit-gruplari', aktif, UnitGrup.fromJson);

  Future<List<T>> _liste<T>(
    String yol,
    bool? aktif,
    T Function(Map<String, dynamic>) coz,
  ) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        yol,
        queryParameters: {'limit': 200, 'aktif': ?aktif},
      );
      final items = res.data?['items'];
      if (items is! List) return const [];
      return [
        for (final m in items.whereType<Map>())
          coz(Map<String, dynamic>.from(m)),
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<UnitTip> createTip(UnitTanimDraft d) async =>
      UnitTip.fromJson(await _yaz('POST', '/unit-tipleri', d));

  Future<UnitTip> updateTip(String id, UnitTanimDraft d) async =>
      UnitTip.fromJson(await _yaz('PATCH', '/unit-tipleri/$id', d));

  Future<UnitGrup> createGrup(UnitTanimDraft d) async =>
      UnitGrup.fromJson(await _yaz('POST', '/unit-gruplari', d));

  Future<UnitGrup> updateGrup(String id, UnitTanimDraft d) async =>
      UnitGrup.fromJson(await _yaz('PATCH', '/unit-gruplari/$id', d));

  Future<Map<String, dynamic>> _yaz(
    String yontem,
    String yol,
    UnitTanimDraft d,
  ) async {
    try {
      final res = await _dio.request<Map<String, dynamic>>(
        yol,
        data: d.toJson(),
        options: Options(method: yontem),
      );
      return res.data ?? const {};
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Tanimi siler ve KAC daireyi etkiledigini doner.
  ///
  /// Silme 409 VERMEZ: daireler DURUR, yalniz siniflandirmalari bosalir.
  /// Donen sayi kullaniciya gosterilir — islem sessiz olmamali.
  Future<int> deleteTip(String id) => _sil('/unit-tipleri/$id');

  Future<int> deleteGrup(String id) => _sil('/unit-gruplari/$id');

  Future<int> _sil(String yol) async {
    try {
      final res = await _dio.delete<Map<String, dynamic>>(yol);
      return (res.data?['etkilenen_daire'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final unitTanimApiProvider = Provider<UnitTanimApi>((ref) {
  return UnitTanimApi(ref.watch(dioProvider));
});

/// Tip listesi — hem tanim ekrani hem daire duzenleme SECICISI kullanir
/// (tek istek).
final unitTipleriProvider = FutureProvider.autoDispose<List<UnitTip>>((ref) {
  return ref.watch(unitTanimApiProvider).fetchTipler();
});

final unitGruplariProvider = FutureProvider.autoDispose<List<UnitGrup>>((ref) {
  return ref.watch(unitTanimApiProvider).fetchGruplar();
});
