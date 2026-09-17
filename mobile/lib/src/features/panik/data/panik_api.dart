import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/panik_models.dart';

/// (P240 §1) Panik ucu.
///
/// KONUM OPSIYONEL: izin yoksa/kapali alandaysa alarm YINE DE gitmeli.
/// Konumu zorunlu kilmak, konum alinamadigi icin alarmin HIC gitmemesi
/// demekti — acil durumda kabul edilemez.
class PanikApi {
  PanikApi(this._dio);

  final Dio _dio;

  Future<PanikAlarm> tetikle(
    PanikTip tip, {
    double? gpsLat,
    double? gpsLng,
    String? checkpointId,
    String? aciklama,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/panik', data: {
        'tip': tip.kimlik,
        // IKISI BIRLIKTE ya da HIC: tek basina enlem bir konum degildir
        // (sunucu da ayni kurali zorluyor).
        if (gpsLat != null && gpsLng != null) 'gps_lat': gpsLat,
        if (gpsLat != null && gpsLng != null) 'gps_lng': gpsLng,
        'checkpoint_id': ?checkpointId,
        if (aciklama != null && aciklama.isNotEmpty) 'aciklama': aciklama,
      });
      return PanikAlarm.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<PanikAlarm> iptal(String id) => _eylem(id, 'iptal');
  Future<PanikAlarm> gordum(String id) => _eylem(id, 'gordum');
  Future<PanikAlarm> mudahale(String id) => _eylem(id, 'mudahale');

  Future<PanikAlarm> kapat(String id, {String? not}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/panik/$id/kapat',
        data: {'kapanis_notu': not},
      );
      return PanikAlarm.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<PanikAlarm> _eylem(String id, String eylem) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/panik/$id/$eylem');
      return PanikAlarm.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// BANA gelen, kapanmamis ve HENUZ GORMEDIGIM alarmlar.
  Future<List<PanikAlarm>> aktifler() async {
    try {
      final res = await _dio.get<List<dynamic>>('/panik/aktif');
      return (res.data ?? const [])
          .whereType<Map>()
          .map((m) => PanikAlarm.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<PanikAlarm>> liste({int limit = 50}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/panik',
        queryParameters: {'limit': limit},
      );
      return ((res.data?['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => PanikAlarm.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final panikApiProvider = Provider<PanikApi>((ref) => PanikApi(ref.watch(dioProvider)));

/// Aktif alarmlar — tam ekran uyarinin kaynagi.
final panikAktifProvider = FutureProvider.autoDispose<List<PanikAlarm>>(
  (ref) => ref.watch(panikApiProvider).aktifler(),
);

final panikListeProvider = FutureProvider.autoDispose<List<PanikAlarm>>(
  (ref) => ref.watch(panikApiProvider).liste(),
);
