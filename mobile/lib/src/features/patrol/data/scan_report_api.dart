import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// Gun-gun tarama raporu satiri (Parca D): kim (guardAd), hangi nokta
/// (checkpointAd), ne zaman (okutmaZamani). `GET /scans?tarih=...`.
class ScanReportItem {
  const ScanReportItem({
    required this.id,
    required this.checkpointId,
    required this.checkpointAd,
    required this.guardId,
    required this.guardAd,
    required this.okutmaZamani,
    required this.imzaDogrulandi,
  });

  final String id;
  final String checkpointId;
  final String checkpointAd;
  final String guardId;
  final String guardAd;
  final DateTime okutmaZamani;
  final bool imzaDogrulandi;

  factory ScanReportItem.fromJson(Map<String, dynamic> json) => ScanReportItem(
        id: json['id'] as String,
        checkpointId: json['checkpoint_id'] as String,
        checkpointAd: json['checkpoint_ad'] as String? ?? '',
        guardId: json['guard_id'] as String,
        guardAd: json['guard_ad'] as String? ?? '',
        okutmaZamani: DateTime.parse(json['okutma_zamani'] as String).toUtc(),
        imzaDogrulandi: (json['imza_dogrulandi'] as bool?) ?? false,
      );
}

/// `GET /scans?tarih=YYYY-MM-DD` — bir gunun (tenant tz) taramalari, okutma
/// zamanina gore sirali. RBAC admin + yonetici.
class ScanReportApi {
  ScanReportApi(this._dio);

  final Dio _dio;

  Future<List<ScanReportItem>> fetch(DateTime day) async {
    final tarih = '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/scans',
        queryParameters: {'tarih': tarih},
      );
      final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
      return items.map(ScanReportItem.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final scanReportApiProvider =
    Provider<ScanReportApi>((ref) => ScanReportApi(ref.watch(dioProvider)));

/// Secili gunun tarama raporu (autoDispose; gun degisince yeniden cekilir).
final scanReportProvider =
    FutureProvider.autoDispose.family<List<ScanReportItem>, DateTime>(
  (ref, day) => ref.watch(scanReportApiProvider).fetch(day),
);
