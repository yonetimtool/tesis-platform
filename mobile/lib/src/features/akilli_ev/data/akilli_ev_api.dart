import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/akilli_ev_models.dart';

/// (P240 §3) Akilli ev ucu.
///
/// SAKIN SINIRI BURADA DEGIL SUNUCUDA: bu istemci hicbir daire suzgeci
/// GONDERMEZ. Sunucu `resident` icin sorguyu kendi dairelerine kisitlar
/// ve `/komut` ucunda kimligi ayrica denetler (403). Istemcide
/// filtrelemek "gonderilmis ama gizlenmis" veri demekti.
class AkilliEvApi {
  AkilliEvApi(this._dio);

  final Dio _dio;

  Future<List<AkilliEvCihaz>> cihazlar() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/akilli-ev/cihazlar',
        queryParameters: const {'limit': 200},
      );
      return ((res.data?['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => AkilliEvCihaz.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<AkilliEvBolum>> bolumler() async {
    try {
      final res = await _dio.get<List<dynamic>>('/akilli-ev/bolumler');
      return (res.data ?? const [])
          .whereType<Map>()
          .map((m) => AkilliEvBolum.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Komut — denetim kaydina HER ZAMAN yazilir (sunucu tarafi).
  Future<bool> komut(String cihazId, String eylem) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/akilli-ev/cihazlar/$cihazId/komut',
        data: {'eylem': eylem},
      );
      return res.data?['ok'] as bool? ?? false;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final akilliEvApiProvider =
    Provider<AkilliEvApi>((ref) => AkilliEvApi(ref.watch(dioProvider)));

final akilliEvCihazlarProvider =
    FutureProvider.autoDispose<List<AkilliEvCihaz>>(
  (ref) => ref.watch(akilliEvApiProvider).cihazlar(),
);

final akilliEvBolumlerProvider = FutureProvider.autoDispose<List<AkilliEvBolum>>(
  (ref) => ref.watch(akilliEvApiProvider).bolumler(),
);
