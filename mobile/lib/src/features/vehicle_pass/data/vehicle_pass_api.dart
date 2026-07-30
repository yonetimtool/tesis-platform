import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../home/domain/parking_occupancy.dart';
import '../domain/vehicle_pass_models.dart';

/// Arac gecisi modulunun HTTP istemcisi:
///
///   * `GET  /vehicle-passes`            → liste (giris_zamani DESC)
///   * `POST /vehicle-passes`            → arac GIRISI (409 = zaten iceride)
///   * `POST /vehicle-passes/{id}/checkout` → CIKIS damgasi (409 = zaten kapali)
///   * `GET  /parking/occupancy`         → agregat doluluk (tum roller)
///
/// Doluluk AYRI bir sayac degildir: acik gecislerin sayimidir. Bu yuzden
/// cikis damgalandigi anda doluluk duser ve iki sayi ASLA ayrisamaz.
class VehiclePassApi {
  VehiclePassApi(this._dio);

  final Dio _dio;

  /// Sayfali listeyi TAMAMEN ceker (ziyaretci/kargo modullerindeki desen).
  /// [suzgec] `?acik=`, [plaka] ONEK aramasi (sunucu normalize eder — istemci
  /// "34 abc" yazabilir).
  Future<List<VehiclePass>> fetchAll({
    GecisSuzgeci suzgec = GecisSuzgeci.tumu,
    String? plaka,
  }) async {
    final out = <VehiclePass>[];
    var offset = 0;
    const limit = 200;
    try {
      while (true) {
        final res = await _dio.get<Map<String, dynamic>>(
          '/vehicle-passes',
          queryParameters: {
            'limit': limit,
            'offset': offset,
            'acik': ?suzgec.acik,
            'plaka': ?((plaka != null && plaka.trim().isNotEmpty)
                ? plaka.trim()
                : null),
          },
        );
        final items = res.data?['items'];
        if (items is! List || items.isEmpty) break;
        for (final item in items) {
          if (item is Map) {
            out.add(VehiclePass.fromJson(Map<String, dynamic>.from(item)));
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

  Future<VehiclePass> create(VehiclePassDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/vehicle-passes',
        data: draft.toJson(),
      );
      return VehiclePass.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// CIKIS damgasi. Govde YOKTUR; sunucu kendi saatiyle damgalar. Gecis zaten
  /// kapaliysa 409 doner ve ILK cikis zamani DEGISMEZ.
  Future<VehiclePass> checkout(String id) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/vehicle-passes/$id/checkout',
      );
      return VehiclePass.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ParkingOccupancy> occupancy() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/parking/occupancy');
      return ParkingOccupancy.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final vehiclePassApiProvider = Provider<VehiclePassApi>(
  (ref) => VehiclePassApi(ref.watch(dioProvider)),
);
