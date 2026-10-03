import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/makbuz_models.dart';

/// (P253 A1) Sakinin KENDI makbuzlari (`GET /me/makbuzlar`, yalniz
/// resident; sunucu `user_id` ile suzer — dairenin eski sakininin
/// makbuzlari gorunmez). PDF depodan dogrudan iner (presign).
class MakbuzApi {
  MakbuzApi(this._dio, {Dio? depoDio}) : _depoDio = depoDio ?? Dio();

  final Dio _dio;
  final Dio _depoDio;

  Future<(List<Makbuz>, int?)> liste({int offset = 0, int limit = 30}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/me/makbuzlar',
        // Sunucu sayfa siniri 100.
        queryParameters: {'limit': limit > 100 ? 100 : limit, 'offset': offset},
      );
      final items = res.data?['items'];
      final meta = res.data?['meta'];
      return (
        [
          if (items is List)
            for (final m in items.whereType<Map>()) Makbuz.fromJson(Map<String, dynamic>.from(m)),
        ],
        meta is Map ? (meta['total'] as num?)?.toInt() : null,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Uint8List> pdf(String url) async {
    try {
      final res = await _depoDio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data ?? const []);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final makbuzApiProvider = Provider<MakbuzApi>((ref) => MakbuzApi(ref.watch(dioProvider)));
