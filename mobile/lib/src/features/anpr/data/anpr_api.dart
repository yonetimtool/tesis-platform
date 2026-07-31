import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/anpr_models.dart';

/// ANPR olay defteri + onay kuyrugu istemcisi.
///
/// NOT: olay YAZMA ucu (`POST /integrations/anpr/events`) bu istemcide YOKTUR
/// — onu KAMERA KUTUSU `X-ANPR-Key` ile cagirir, telefon degil.
class AnprApi {
  AnprApi(this._dio);

  final Dio _dio;

  Future<List<AnprOlay>> fetchAll({AnprDurum? durum, String? plaka}) async {
    final out = <AnprOlay>[];
    var offset = 0;
    const limit = 200;
    try {
      while (true) {
        final res = await _dio.get<Map<String, dynamic>>(
          '/integrations/anpr/events',
          queryParameters: {
            'limit': limit,
            'offset': offset,
            'durum': ?durum?.wire,
            'plaka': ?((plaka != null && plaka.trim().isNotEmpty)
                ? plaka.trim()
                : null),
          },
        );
        final items = res.data?['items'];
        if (items is! List || items.isEmpty) break;
        for (final item in items) {
          if (item is Map) {
            out.add(AnprOlay.fromJson(Map<String, dynamic>.from(item)));
          }
        }
        if (items.length < limit) break;
        offset += limit;
      }
      return out;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Dusuk guvenli okumanin insan karari. [plaka] verilirse OCR duzeltilir.
  Future<AnprOlay> onayla(
    String id, {
    required bool onay,
    String? plaka,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/integrations/anpr/events/$id/onay',
        data: {
          'onay': onay,
          if (plaka != null && plaka.trim().isNotEmpty) 'plaka': plaka.trim(),
        },
      );
      return AnprOlay.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final anprApiProvider = Provider<AnprApi>(
  (ref) => AnprApi(ref.watch(dioProvider)),
);
