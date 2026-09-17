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
    this.shiftId,
    this.gunler,
    this.ekTarihler,
  });

  final String id;
  final String ad;
  final String baslangicSaat; // "HH:MM:SS"
  final String bitisSaat;
  final int periyotDakika;
  final bool aktif;

  /// (P239 §3) PLANIN BAGLI OLDUGU VARDIYA — "kim yuruyecek"in bugunku
  /// yaniti. `patrol_plan`da atanan KISI kolonu YOK; plan bir vardiyaya
  /// baglanir ve o vardiyanin kadrosu yurur. Web formunda bu alan
  /// VARDI, mobilde YOKTU — yani mobilde acilan her plan kadrosuz
  /// kaliyordu.
  final String? shiftId;

  /// (P239 §4) Planin yurudugu ISO hafta gunleri (1=Pzt ... 7=Paz).
  /// null = HER GUN (goc 0139 oncesi kayitlar ve "gun secmedim" hali).
  final List<int>? gunler;

  /// (P239 §4) Bir kerelik ek gunler (bayram, ozel etkinlik).
  final List<DateTime>? ekTarihler;

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
        shiftId: json['shift_id'] as String?,
        gunler: (json['gunler'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList(),
        ekTarihler: (json['ek_tarihler'] as List?)
            ?.map((e) => DateTime.parse(e as String))
            .toList(),
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
    String? shiftId,
    List<int>? gunler,
    List<DateTime>? ekTarihler,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/patrol-plans', data: {
        'ad': ad,
        'baslangic_saat': baslangicSaat,
        'bitis_saat': bitisSaat,
        'periyot_dakika': periyotDakika,
        'aktif': aktif,
        'shift_id': shiftId,
        // BOS LISTE GONDERILMEZ: sunucu 422 verir ve dogru yapar —
        // "hicbir gun" plan aktif gorunurken hicbir pencere uretmeyen
        // sessiz bir kapali hal olurdu. Gun secilmediyse null = HER GUN.
        'gunler': (gunler == null || gunler.isEmpty) ? null : (gunler.toList()..sort()),
        'ek_tarihler': (ekTarihler == null || ekTarihler.isEmpty)
            ? null
            : [for (final g in ekTarihler) _gunMetni(g)],
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
    String? shiftId,
    List<int>? gunler,
    List<DateTime>? ekTarihler,
  }) async {
    try {
      await _dio.patch<Map<String, dynamic>>('/patrol-plans/$id', data: {
        'ad': ad,
        'baslangic_saat': baslangicSaat,
        'bitis_saat': bitisSaat,
        'periyot_dakika': periyotDakika,
        'aktif': aktif,
        // NULL DA GONDERILIR: vardiya bagini KALDIRMAK baska turlu
        // mumkun olmazdi (tam-govde PATCH kurali).
        'shift_id': shiftId,
        // null GONDERMEK "her gune don" demektir — ayni gerekce.
        'gunler': (gunler == null || gunler.isEmpty) ? null : (gunler.toList()..sort()),
        'ek_tarihler': (ekTarihler == null || ekTarihler.isEmpty)
            ? null
            : [for (final g in ekTarihler) _gunMetni(g)],
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

/// (P239 §4) `DateTime` -> `YYYY-MM-DD`. SAAT KIRPILIR: sunucu `date`
/// bekliyor ve ISO-8601 tam damgasi gondermek yerel saat/UTC farkiyla
/// gunu BIR KAYDIRABILIR (23:00'te secilen gun bir sonraki gun olurdu).
String _gunMetni(DateTime g) =>
    '${g.year.toString().padLeft(4, '0')}-'
    '${g.month.toString().padLeft(2, '0')}-'
    '${g.day.toString().padLeft(2, '0')}';
