import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// (E2E 2026-09, MOBIL-10) GURULTU UYARILARI — web `/gurultu-uyarilari`
/// sayfasinin mobil ikizi. Esitlik belgesi "uc hazir, ekran yok" diyordu.
///
///   * `GET  /unit-uyarilari`             -> uyari kayitlari (yeni ustte)
///   * `POST /unit-uyarilari/{id}/yapildi` -> manuel anonsu isaretle
///
/// RBAC sunucuda: admin + yonetici (komsu davranisi verisi, P24 gerekcesi).
class GurultuUyarisi {
  const GurultuUyarisi({
    required this.id,
    required this.esik,
    required this.sayac,
    required this.kanal,
    required this.durum,
    required this.createdAt,
    this.unitNo,
  });

  final String id;
  final String? unitNo;
  final int esik;
  final int sayac;
  final String kanal;

  /// `gonderildi` | `basarisiz` | `manuel_bekliyor` | `manuel_yapildi`.
  final String durum;
  final DateTime createdAt;

  /// "Anons yapildi" dugmesi YALNIZ bekleyende (web ile ayni): kapanmis bir
  /// uyariya "yapildi" demek, olmayan bir eylemi sunmak olurdu. SUNUCU
  /// bunu kendiliginden varsayamaz — anonsu yalniz insan bilir (P37).
  bool get isaretlenebilir => durum == 'manuel_bekliyor';

  factory GurultuUyarisi.fromJson(Map<String, dynamic> j) => GurultuUyarisi(
    id: j['id'] as String? ?? '',
    unitNo: j['unit_no'] as String?,
    esik: (j['esik'] as num?)?.toInt() ?? 0,
    sayac: (j['sayac'] as num?)?.toInt() ?? 0,
    kanal: j['kanal'] as String? ?? '',
    durum: j['durum'] as String? ?? '',
    createdAt:
        DateTime.tryParse(j['created_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}

class GurultuApi {
  GurultuApi(this._dio);

  final Dio _dio;

  Future<List<GurultuUyarisi>> liste() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/unit-uyarilari',
        queryParameters: {'limit': 200},
      );
      final ham = (res.data?['items'] as List?) ?? const [];
      return ham
          .whereType<Map>()
          .map((m) => GurultuUyarisi.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> yapildi(String id) async {
    try {
      await _dio.post<Map<String, dynamic>>('/unit-uyarilari/$id/yapildi');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final gurultuApiProvider = Provider<GurultuApi>(
  (ref) => GurultuApi(ref.watch(dioProvider)),
);

final gurultuUyarilariProvider =
    FutureProvider.autoDispose<List<GurultuUyarisi>>(
      (ref) => ref.watch(gurultuApiProvider).liste(),
    );
