import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// (P253 Asama 2) Tanimlar genel defteri HTTP istemcisi.
///
/// Yol CAGIRANIN verdigi defter tanimindan gelir (`DefterTanimi.uc`,
/// literal); eylem taramasi yollari o tanimlardan acar. Muhasebe ayarlari
/// ve toplu sayac uretimi tek-amacli uclardir, burada literal yazilir.
class DefterApi {
  DefterApi(this._dio);

  final Dio _dio;

  Future<({List<Map<String, dynamic>> ogeler, int? toplam})> liste(
    String uc, {
    required int limit,
    required int offset,
  }) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        uc,
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final items = r.data?['items'];
      final meta = r.data?['meta'];
      return (
        ogeler: [
          if (items is List)
            for (final i in items)
              if (i is Map) Map<String, dynamic>.from(i),
        ],
        toplam: meta is Map ? (meta['total'] as num?)?.toInt() : null,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> olustur(String uc, Map<String, dynamic> govde) async {
    try {
      await _dio.post<Map<String, dynamic>>(uc, data: govde);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> guncelle(String uc, String id, Map<String, dynamic> govde) async {
    try {
      await _dio.patch<Map<String, dynamic>>('$uc/$id', data: govde);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> sil(String uc, String id) async {
    try {
      await _dio.delete<void>('$uc/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Bir ana sayac icin TUM aktif dairelere bolum sayaci acar.
  Future<({int olusturulan, int atlanan})> sayaclariUret(String anaSayacId) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/sayaclar/bolum/otomatik',
        data: {'ana_sayac_id': anaSayacId},
      );
      return (
        olusturulan: (r.data?['olusturulan'] as num?)?.toInt() ?? 0,
        atlanan: (r.data?['atlanan'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> muhasebeAyarlari() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/muhasebe-ayarlari');
      return r.data ?? const {};
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> muhasebeAyarlariniKaydet(Map<String, dynamic> govde) async {
    try {
      await _dio.patch<Map<String, dynamic>>('/muhasebe-ayarlari', data: govde);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final defterApiProvider = Provider<DefterApi>((ref) => DefterApi(ref.watch(dioProvider)));
