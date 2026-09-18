import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/bakim_models.dart';

/// (P241 §1) Bakim ucu.
class BakimApi {
  BakimApi(this._dio);

  final Dio _dio;

  Future<List<BakimEkipmani>> ekipmanlar({String? durum}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/bakim/ekipmanlar',
        queryParameters: {
          'limit': 200,
          if (durum != null && durum.isNotEmpty) 'durum': durum,
        },
      );
      return ((res.data?['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => BakimEkipmani.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<BakimKaydi>> kayitlar({String? ekipmanId}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/bakim/kayitlar',
        queryParameters: {
          'limit': 100,
          if (ekipmanId != null) 'ekipman_id': ekipmanId,
        },
      );
      return ((res.data?['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => BakimKaydi.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<BakimKaydi> kayitEkle(String ekipmanId, BakimKaydiTaslak t) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/bakim/ekipmanlar/$ekipmanId/kayitlar',
        data: t.toJson(),
      );
      return BakimKaydi.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final bakimApiProvider =
    Provider<BakimApi>((ref) => BakimApi(ref.watch(dioProvider)));

final bakimEkipmanlariProvider =
    FutureProvider.autoDispose<List<BakimEkipmani>>(
  (ref) => ref.watch(bakimApiProvider).ekipmanlar(),
);
