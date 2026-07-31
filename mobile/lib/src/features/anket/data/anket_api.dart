import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/anket_models.dart';

/// `/anketler` ince istemcisi (P38).
class AnketApi {
  AnketApi(this._dio);

  final Dio _dio;

  Future<List<Anket>> liste() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/anketler');
      return [
        for (final a in (r.data?['items'] as List? ?? const []))
          Anket.fromJson(a as Map<String, dynamic>),
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Oy ver. 409 = zaten oy verilmis VEYA anket kapali — oy
  /// DEGISTIRILEMEZ; istemci bunu hata degil DURUM olarak gosterir.
  Future<Anket> oyVer(String anketId, String secenekId) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/anketler/$anketId/oy',
        data: {'secenek_id': secenekId},
      );
      return Anket.fromJson(r.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final anketApiProvider =
    Provider<AnketApi>((ref) => AnketApi(ref.watch(dioProvider)));

final anketlerProvider =
    FutureProvider<List<Anket>>((ref) => ref.watch(anketApiProvider).liste());
