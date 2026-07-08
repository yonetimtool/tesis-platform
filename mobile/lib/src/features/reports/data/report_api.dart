import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/report_models.dart';

/// Aylik rapor istemcisi — bir ayin verisini uc uctan derler
/// (hepsi yonetici'ye acik; auth.md §4):
///
///   * `GET /patrol-windows?baslangic&bitis&limit=1` → yalniz `ozet`
///     (filtrelenmis TUM kume uzerinden; sayfa verisi kullanilmaz)
///   * `GET /task-completions?baslangic&bitis&limit=10` → `ozet` + son 10
///   * `GET /dues/assessments|payments?donem` → tum sayfalar toplanir
class ReportApi {
  ReportApi(this._dio);

  final Dio _dio;

  Future<AylikRapor> fetchMonthly(int yil, int ay) async {
    final aralik = ayAralik(yil, ay);
    final donem = donemStr(yil, ay);
    try {
      final results = await Future.wait([
        _dio.get<Map<String, dynamic>>(
          '/patrol-windows',
          queryParameters: {
            'limit': 1,
            'offset': 0,
            'baslangic': aralik.baslangic.toIso8601String(),
            'bitis': aralik.bitis.toIso8601String(),
          },
        ),
        _dio.get<Map<String, dynamic>>(
          '/task-completions',
          queryParameters: {
            'limit': 10,
            'offset': 0,
            'baslangic': aralik.baslangic.toIso8601String(),
            'bitis': aralik.bitis.toIso8601String(),
          },
        ),
        _fetchAllPages('/dues/assessments', {'donem': donem}),
        _fetchAllPages('/dues/payments', {'donem': donem}),
      ]);

      final patrol =
          (results[0] as Response<Map<String, dynamic>>).data ?? const {};
      final patrolOzet = patrol['ozet'] is Map
          ? Map<String, dynamic>.from(patrol['ozet'] as Map)
          : const <String, dynamic>{};

      final tc = (results[1] as Response<Map<String, dynamic>>).data ?? const {};
      final gorevOzet = tc['ozet'] is Map
          ? GorevOzet.fromJson(Map<String, dynamic>.from(tc['ozet'] as Map))
          : const GorevOzet();
      final sonlar = [
        for (final item in tc['items'] is List ? tc['items'] as List : const [])
          if (item is Map)
            SonTamamlama.fromJson(Map<String, dynamic>.from(item)),
      ];

      return AylikRapor(
        yil: yil,
        ay: ay,
        devriyeToplam: (patrolOzet['toplam'] as num?)?.toInt() ?? 0,
        devriyeTamamlandi: (patrolOzet['tamamlandi'] as num?)?.toInt() ?? 0,
        devriyeKacirildi: (patrolOzet['kacirildi'] as num?)?.toInt() ?? 0,
        gorev: gorevOzet,
        sonTamamlamalar: sonlar,
        aidat: aidatOzet(
          assessments: results[2] as List<Map<String, dynamic>>,
          payments: results[3] as List<Map<String, dynamic>>,
        ),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Sayfali ucun TUM item'larini toplar (aylik hacim kucuk; limit 200).
  Future<List<Map<String, dynamic>>> _fetchAllPages(
    String path,
    Map<String, dynamic> query,
  ) async {
    final out = <Map<String, dynamic>>[];
    var offset = 0;
    const limit = 200;
    while (true) {
      final res = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: {...query, 'limit': limit, 'offset': offset},
      );
      final items = res.data?['items'];
      if (items is! List || items.isEmpty) break;
      for (final item in items) {
        if (item is Map) out.add(Map<String, dynamic>.from(item));
      }
      if (items.length < limit) break;
      offset += limit;
    }
    return out;
  }
}

final reportApiProvider = Provider<ReportApi>((ref) {
  return ReportApi(ref.watch(dioProvider));
});
