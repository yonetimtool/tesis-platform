import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/diyafon_models.dart';

/// (P240 §2) Diyafon ucu.
class DiyafonApi {
  DiyafonApi(this._dio);

  final Dio _dio;

  Future<List<Diyafon>> liste() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/diyafon');
      return ((res.data?['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Diyafon.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Diyafon> olustur(DiyafonTaslak taslak) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/diyafon',
        data: taslak.toJson(),
      );
      return Diyafon.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// BAGLANTI TESTI — cihazi CALISTIRMAZ (SIP OPTIONS / TCP).
  Future<({bool ok, String? kod})> saglik(String id) => _eylem(id, 'saglik');

  Future<({bool ok, String? kod})> zil(String id) => _eylem(id, 'zil');

  Future<({bool ok, String? kod})> kapiAc(String id) => _eylem(id, 'kapi-ac');

  Future<({bool ok, String? kod})> _eylem(String id, String yol) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/diyafon/$id/$yol');
      final d = res.data ?? const {};
      return (ok: d['ok'] as bool? ?? false, kod: d['kod'] as String?);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final diyafonApiProvider =
    Provider<DiyafonApi>((ref) => DiyafonApi(ref.watch(dioProvider)));

final diyafonListeProvider = FutureProvider.autoDispose<List<Diyafon>>(
  (ref) => ref.watch(diyafonApiProvider).liste(),
);
