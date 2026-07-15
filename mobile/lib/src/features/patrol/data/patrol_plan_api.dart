import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// Devriye plani (patrol_plan) — yonetici tanimlar: ad + saatler + tur sikligi
/// + kontrol noktalari. Saatler "HH:MM:SS" string olarak gelir.
class PatrolPlan {
  const PatrolPlan({
    required this.id,
    required this.ad,
    required this.baslangicSaat,
    required this.bitisSaat,
    required this.periyotDakika,
    required this.aktif,
  });

  final String id;
  final String ad;
  final String baslangicSaat; // "HH:MM:SS"
  final String bitisSaat;
  final int periyotDakika;
  final bool aktif;

  /// "HH:MM" (saniyeyi kirp) — gosterim icin.
  String get baslangicHHMM => _hhmm(baslangicSaat);
  String get bitisHHMM => _hhmm(bitisSaat);
  static String _hhmm(String s) =>
      s.length >= 5 ? s.substring(0, 5) : s;

  factory PatrolPlan.fromJson(Map<String, dynamic> json) => PatrolPlan(
        id: json['id'] as String,
        ad: json['ad'] as String? ?? '',
        baslangicSaat: json['baslangic_saat'] as String? ?? '00:00:00',
        bitisSaat: json['bitis_saat'] as String? ?? '00:00:00',
        periyotDakika: (json['periyot_dakika'] as num?)?.toInt() ?? 60,
        aktif: (json['aktif'] as bool?) ?? true,
      );
}

/// `/patrol-plans` ince istemcisi (yazma admin+yonetici; okuma yonetim+saha).
class PatrolPlanApi {
  PatrolPlanApi(this._dio);

  final Dio _dio;

  Future<List<PatrolPlan>> list() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/patrol-plans',
        queryParameters: {'limit': 200},
      );
      final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
      return items.map(PatrolPlan.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<PatrolPlan> create({
    required String ad,
    required String baslangicSaat,
    required String bitisSaat,
    required int periyotDakika,
    bool aktif = true,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/patrol-plans', data: {
        'ad': ad,
        'baslangic_saat': baslangicSaat,
        'bitis_saat': bitisSaat,
        'periyot_dakika': periyotDakika,
        'aktif': aktif,
      });
      return PatrolPlan.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> update(
    String id, {
    required String ad,
    required String baslangicSaat,
    required String bitisSaat,
    required int periyotDakika,
    required bool aktif,
  }) async {
    try {
      await _dio.patch<Map<String, dynamic>>('/patrol-plans/$id', data: {
        'ad': ad,
        'baslangic_saat': baslangicSaat,
        'bitis_saat': bitisSaat,
        'periyot_dakika': periyotDakika,
        'aktif': aktif,
      });
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete<void>('/patrol-plans/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Plana atanmis checkpoint id'leri (sira ile).
  Future<List<String>> checkpointIds(String planId) async {
    try {
      final res = await _dio
          .get<List<dynamic>>('/patrol-plans/$planId/checkpoints');
      return (res.data ?? const [])
          .cast<Map<String, dynamic>>()
          .map((c) => c['checkpoint_id'] as String)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Atamayi TAMAMEN degistir (replace); sira = dizi index'i.
  Future<void> setCheckpoints(String planId, List<String> ids) async {
    try {
      await _dio.put<List<dynamic>>(
        '/patrol-plans/$planId/checkpoints',
        data: {
          'items': [
            for (final id in ids) {'checkpoint_id': id},
          ],
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final patrolPlanApiProvider =
    Provider<PatrolPlanApi>((ref) => PatrolPlanApi(ref.watch(dioProvider)));

final patrolPlansProvider = FutureProvider.autoDispose<List<PatrolPlan>>(
  (ref) => ref.watch(patrolPlanApiProvider).list(),
);
