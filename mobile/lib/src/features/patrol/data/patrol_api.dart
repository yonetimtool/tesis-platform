import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/patrol_models.dart';

/// `GET /patrol-windows` yaniti: sayfa ogeleri + filtrelenmis tum kume ozeti.
class PatrolWindowHistoryPage {
  const PatrolWindowHistoryPage({
    required this.items,
    required this.ozet,
    this.total = 0,
  });

  final List<PatrolWindowHistoryItem> items;
  final PatrolWindowOzet ozet;
  final int total;
}

/// Tur ekraninin HTTP istemcisi. Kullanilan uclar (tumune security rolu
/// erisebilir — bkz. contracts/auth.md §4):
///
///   * `GET /dashboard/live`                → aktif/bekleyen pencereler + sayilar
///   * `GET /patrol-plans/{id}/checkpoints` → planin sirali nokta listesi
///   * `GET /checkpoints`                   → nokta adi zenginlestirme (fallback)
///   * `GET /patrol-windows`                → pencere gecmisi + ozet
///
/// DioException'lar sozlesme hata zarfina gore [ApiException]'a cevrilir.
class PatrolApi {
  PatrolApi(this._dio);

  final Dio _dio;

  /// `GET /dashboard/live` — aktif/bekleyen patrol_window'lar. Yalnizca
  /// `aktif_turlar` kullanilir (alarmlar panel icindir).
  Future<List<ActivePatrolWindow>> fetchLiveWindows() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/dashboard/live',
        // Alarm listesi burada kullanilmiyor; en kucuk izinli deger istenir.
        queryParameters: {'alarm_limit': 1},
      );
      final raw = res.data?['aktif_turlar'];
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (item is Map)
            ActivePatrolWindow.fromJson(Map<String, dynamic>.from(item)),
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /patrol-plans/{id}/checkpoints` — sirali nokta listesi. Sozlesmede
  /// genisletilmis `checkpoint` alani OPSIYONEL; ad/UID gelmediyse
  /// `GET /checkpoints` ile bir kez zenginlestirilir (nokta adi ve yerel
  /// UID eslestirmesi icin gerekli).
  Future<List<PlanCheckpoint>> fetchPlanCheckpoints(String planId) async {
    List<PlanCheckpoint> checkpoints;
    try {
      final res = await _dio.get<List<dynamic>>(
        '/patrol-plans/$planId/checkpoints',
      );
      checkpoints = [
        for (final item in res.data ?? const [])
          if (item is Map)
            PlanCheckpoint.fromJson(Map<String, dynamic>.from(item)),
      ]..sort((a, b) => a.sira.compareTo(b.sira));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }

    final needsEnrich =
        checkpoints.any((c) => c.ad == null || c.nfcTagUid == null);
    if (!needsEnrich || checkpoints.isEmpty) return checkpoints;

    // Zenginlestirme basarisiz olsa da liste gosterilebilir (adsiz satirlar
    // "Nokta" + kisa id ile cizilir) — bu yuzden hata yutulmaz ama liste de
    // bos donulmez.
    try {
      final byId = await _fetchCheckpointsById();
      checkpoints = [
        for (final cp in checkpoints)
          byId.containsKey(cp.checkpointId)
              ? cp.copyWith(
                  ad: byId[cp.checkpointId]!.$1,
                  nfcTagUid: byId[cp.checkpointId]!.$2,
                )
              : cp,
      ];
    } on ApiException {
      // Ad zenginlestirmesi kritik degil; eldeki listeyle devam.
    }
    return checkpoints;
  }

  /// `GET /checkpoints` (tum sayfalar) → id → (ad, nfc_tag_uid) haritasi.
  Future<Map<String, (String?, String?)>> _fetchCheckpointsById() async {
    final map = <String, (String?, String?)>{};
    var offset = 0;
    const limit = 200; // sozlesme max
    try {
      while (true) {
        final res = await _dio.get<Map<String, dynamic>>(
          '/checkpoints',
          queryParameters: {'limit': limit, 'offset': offset},
        );
        final items = res.data?['items'];
        if (items is! List || items.isEmpty) break;
        for (final item in items) {
          if (item is Map && item['id'] is String) {
            map[item['id'] as String] =
                (item['ad'] as String?, item['nfc_tag_uid'] as String?);
          }
        }
        if (items.length < limit) break;
        offset += limit;
      }
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
    return map;
  }

  /// `GET /patrol-windows` — pencere gecmisi (pencere_baslangic DESC) + ozet.
  Future<PatrolWindowHistoryPage> fetchWindowHistory({
    int limit = 50,
    int offset = 0,
    PatrolWindowDurum? durum,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/patrol-windows',
        queryParameters: {
          'limit': limit,
          'offset': offset,
          if (durum != null && durum != PatrolWindowDurum.bilinmiyor)
            'durum': durum.name,
        },
      );
      final data = res.data ?? const <String, dynamic>{};
      final rawItems = data['items'];
      final meta = data['meta'];
      return PatrolWindowHistoryPage(
        items: [
          for (final item in rawItems is List ? rawItems : const [])
            if (item is Map)
              PatrolWindowHistoryItem.fromJson(
                Map<String, dynamic>.from(item),
              ),
        ],
        ozet: data['ozet'] is Map
            ? PatrolWindowOzet.fromJson(
                Map<String, dynamic>.from(data['ozet'] as Map),
              )
            : const PatrolWindowOzet(),
        total: meta is Map ? (meta['total'] as num?)?.toInt() ?? 0 : 0,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final patrolApiProvider = Provider<PatrolApi>((ref) {
  return PatrolApi(ref.watch(dioProvider));
});
