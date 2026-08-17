import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/dokuman_models.dart';

/// (P167 ek) Sakin dokuman gorunumunun HTTP istemcisi:
///
///   * `GET /me/dokumanlar`              → sakine ACILMIS dokumanlar
///   * `GET /me/dokumanlar/{id}/indir`   → kisa omurlu indirme baglantisi
///
/// YONETIM UCLARI (`/dokumanlar`) BU SINIFTA YOK ve olmamali: onlar TUM
/// arsivi doner. Mobil sakin uygulamasinin o uca hic dokunmamasi,
/// "yanlislikla yonetim ucunu cagirdim" sinifini kapatir.
class DokumanApi {
  DokumanApi(this._dio);

  final Dio _dio;

  Future<List<SiteDokumani>> fetchAll() async {
    final out = <SiteDokumani>[];
    var offset = 0;
    const limit = 200;
    try {
      while (true) {
        final res = await _dio.get<Map<String, dynamic>>(
          '/me/dokumanlar',
          queryParameters: {'limit': limit, 'offset': offset},
        );
        final items = res.data?['items'];
        if (items is! List || items.isEmpty) break;
        for (final item in items) {
          if (item is Map) {
            out.add(SiteDokumani.fromJson(Map<String, dynamic>.from(item)));
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

  /// Indirme baglantisi — KISA OMURLU presigned URL.
  ///
  /// Dosya UYGULAMA SUNUCUSUNDAN GECMEZ: baglanti dogrudan depoya isaret
  /// eder. Proxylemek, bir yonetim planini uygulama surecinin bellegine
  /// sokmak olurdu.
  Future<String> indirmeBaglantisi(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/me/dokumanlar/$id/indir',
      );
      final url = res.data?['url'];
      if (url is! String || url.isEmpty) {
        // GOVDE BEKLENDIGI GIBI DEGIL: sessizce bos dizge dondurmek,
        // ekranda "acildi" gibi gorunup hicbir sey olmamasi demekti.
        throw const ApiException(
          code: 'invalid_response',
          message: '',
          agHatasi: AkisHatasi.beklenmeyen,
        );
      }
      return url;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final dokumanApiProvider = Provider<DokumanApi>((ref) {
  return DokumanApi(ref.watch(dioProvider));
});
