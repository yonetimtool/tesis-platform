import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/takvim_models.dart';

/// (P253 A1) Takvim + kisisel hatirlatmalar (admin + yonetici).
///
///   * `GET    /takvim?baslangic&bitis`   → alti kaynak tek listede (≤120 gun)
///   * `GET    /hatirlatmalar`            → kendi notlarim
///   * `POST   /hatirlatmalar`            → ekle (`user_id` jetondan)
///   * `PATCH  /hatirlatmalar/{id}`       → guncelle (yalniz kendi kaydi)
///   * `DELETE /hatirlatmalar/{id}`       → sil
class TakvimApi {
  TakvimApi(this._dio);

  final Dio _dio;

  Future<List<TakvimOgesi>> takvim(DateTime baslangic, DateTime bitis) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/takvim',
        queryParameters: {
          'baslangic': baslangic.toUtc().toIso8601String(),
          'bitis': bitis.toUtc().toIso8601String(),
        },
      );
      final items = res.data?['items'];
      return [
        if (items is List)
          for (final m in items.whereType<Map>())
            TakvimOgesi.fromJson(Map<String, dynamic>.from(m)),
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<Hatirlatma>> hatirlatmalar() async {
    try {
      final res = await _dio.get<List<dynamic>>('/hatirlatmalar');
      return [
        for (final m in (res.data ?? const []).whereType<Map>())
          Hatirlatma.fromJson(Map<String, dynamic>.from(m)),
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Hatirlatma> ekle(HatirlatmaTaslak t) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/hatirlatmalar', data: t.toJson());
      return Hatirlatma.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Hatirlatma> guncelle(String id, HatirlatmaTaslak t) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>('/hatirlatmalar/$id', data: t.toJson());
      return Hatirlatma.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> sil(String id) async {
    try {
      await _dio.delete<void>('/hatirlatmalar/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final takvimApiProvider = Provider<TakvimApi>((ref) => TakvimApi(ref.watch(dioProvider)));
