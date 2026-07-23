import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/dues_models.dart';

/// "Aidatim" HTTP istemcisi:
///
///   * `GET /me/dues` → sakinin KENDI dairelerinin borc durumu
///     (yalniz resident; auth.md §4). Sayfalama yok — sakin basina
///     daire sayisi kucuktur, sunucu tumunu tek yanitla doner.
class DuesApi {
  DuesApi(this._dio);

  final Dio _dio;

  Future<List<MyDuesUnit>> fetchMyDues() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/me/dues');
      final items = res.data?['items'];
      if (items is! List) return const [];
      return [
        for (final item in items)
          if (item is Map) MyDuesUnit.fromJson(Map<String, dynamic>.from(item)),
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final duesApiProvider = Provider<DuesApi>((ref) {
  return DuesApi(ref.watch(dioProvider));
});

/// Sakinin kendi dairelerinin borc durumu — ana ekran "Ödeme ve Aidat
/// Durumu" karti + Aidatım kart sayaci. Hata → izleyen ekran kart/sayaci
/// sessizce gizler (ana ekran rehin degil).
final myDuesProvider =
    FutureProvider.autoDispose<List<MyDuesUnit>>((ref) {
  return ref.watch(duesApiProvider).fetchMyDues();
});
