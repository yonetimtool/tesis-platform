import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/building_map_models.dart';

/// Bina semasi HTTP istemcisi (D-viz-1):
///   * `GET   /unit-complaints/building-map` → blok->kat->daire (+renk) +
///     'unplaced'; TUM roller okur (tenant-ici harita, tam anonim).
///   * `PATCH /units/{id}/layout`            → yerlesim girisi (blok/kat/sira);
///     YALNIZ admin+yonetici (backend RBAC 403 doner digerlerine).
class BuildingMapApi {
  BuildingMapApi(this._dio);

  final Dio _dio;

  Future<BuildingMap> fetchMap() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/unit-complaints/building-map',
      );
      return BuildingMap.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Bir dairenin yerlesimini (blok/kat/sira) gunceller. Guncel daire (tam
  /// yerlesimiyle) tekrar okunabilsin diye guncellenmis birim dondurulur.
  Future<BuildingMapUnit> updateLayout(String unitId, UnitLayoutDraft draft) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/units/$unitId/layout',
        data: draft.toJson(),
      );
      // /units yaniti UnitOut'tur (complaint_count/color YOK); harita alanlarini
      // koruyarak yerlesimi guncelle. Sayim/renk bir sonraki fetchMap ile tazelenir.
      final json = res.data ?? const {};
      return BuildingMapUnit(
        unitId: json['id'] as String? ?? unitId,
        unitNo: json['no'] as String? ?? '',
        blok: json['blok'] as String?,
        kat: (json['kat'] as num?)?.toInt(),
        sira: (json['sira'] as num?)?.toInt(),
        complaintCount: 0,
        color: DensityRenk.yesil,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final buildingMapApiProvider = Provider<BuildingMapApi>((ref) {
  return BuildingMapApi(ref.watch(dioProvider));
});
