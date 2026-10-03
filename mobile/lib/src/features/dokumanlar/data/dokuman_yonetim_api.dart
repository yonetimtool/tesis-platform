import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/dokuman_models.dart';

/// (P253 A1) DOKUMAN ARSIVI — YONETIM istemcisi (admin + yonetici).
///
///   * `GET    /dokumanlar`               → tum arsiv (sayfali)
///   * `POST   /uploads/presign`          → depoya PUT bileti
///   * `POST   /dokumanlar`               → yuklenen dosyanin kaydi
///   * `PATCH  /dokumanlar/{id}`          → sakine ac / kapat (tek alan)
///   * `DELETE /dokumanlar/{id}`          → yumusak silme
///   * `GET    /dokumanlar/{id}/indir`    → kisa omurlu baglanti
///
/// Sakin istemcisi ([DokumanApi]) bu uclara BILEREK dokunmaz; ikisini ayri
/// sinifta tutmak "sakin ekrani yanlislikla tum arsivi cekti" sinifini
/// kapatir. Dosya UYGULAMA SUNUCUSUNDAN GECMEZ: yukleme ve indirme
/// dogrudan depoya (web ile ayni presign akisi).
class DokumanYonetimApi {
  DokumanYonetimApi(this._dio, {Dio? depoDio}) : _depoDio = depoDio ?? Dio();

  final Dio _dio;

  /// Depo (presign) istekleri — kimlik basligi TASIMAZ.
  final Dio _depoDio;

  Future<(List<YonetimDokumani>, int?)> liste({int offset = 0, int limit = 30}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/dokumanlar',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final items = res.data?['items'];
      final meta = res.data?['meta'];
      return (
        [
          if (items is List)
            for (final m in items.whereType<Map>())
              YonetimDokumani.fromJson(Map<String, dynamic>.from(m)),
        ],
        meta is Map ? (meta['total'] as num?)?.toInt() : null,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Uc adim: bilet -> depoya PUT -> kayit. Ara adim duserse kayit
  /// OLUSMAZ (depoda sahipsiz obje gecelik temizlikte gider).
  Future<YonetimDokumani> yukle({
    required YuklenecekDosya dosya,
    required String ad,
    String? aciklama,
    required bool sakineAcik,
  }) async {
    try {
      final bilet = await _dio.post<Map<String, dynamic>>(
        '/uploads/presign',
        data: {'content_type': dosya.icerikTipi, 'dosya_adi': dosya.dosyaAdi},
      );
      final anahtar = bilet.data?['foto_key'];
      final url = bilet.data?['upload_url'];
      if (anahtar is! String || url is! String) {
        throw const ApiException(
          code: 'invalid_response', message: '', agHatasi: AkisHatasi.beklenmeyen);
      }
      await _depoDio.put<void>(
        url,
        data: Stream.fromIterable([Uint8List.fromList(dosya.baytlar)]),
        options: Options(headers: {
          Headers.contentTypeHeader: dosya.icerikTipi,
          Headers.contentLengthHeader: dosya.baytlar.length,
        }),
      );
      final res = await _dio.post<Map<String, dynamic>>(
        '/dokumanlar',
        data: {
          'ad': ad,
          'obje_anahtari': anahtar,
          'icerik_tipi': dosya.icerikTipi,
          'boyut_bayt': dosya.baytlar.length,
          'aciklama': aciklama,
          'sakine_acik': sakineAcik,
        },
      );
      return YonetimDokumani.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<YonetimDokumani> gorunurluk(String id, {required bool sakineAcik}) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/dokumanlar/$id',
        data: {'sakine_acik': sakineAcik},
      );
      return YonetimDokumani.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> sil(String id) async {
    try {
      await _dio.delete<void>('/dokumanlar/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<DokumanBaglantisi> baglanti(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/dokumanlar/$id/indir');
      final url = res.data?['url'];
      if (url is! String || url.isEmpty) {
        throw const ApiException(
          code: 'invalid_response', message: '', agHatasi: AkisHatasi.beklenmeyen);
      }
      return DokumanBaglantisi(url: url, dosyaAdi: res.data?['dosya_adi'] as String?);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Baglantidaki dosyanin baytlari (paylasim icin). Depo istemcisiyle:
  /// presign imzasi kimlik basligi beklemez.
  Future<Uint8List> baytlar(String url) async {
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

final dokumanYonetimApiProvider = Provider<DokumanYonetimApi>((ref) {
  return DokumanYonetimApi(ref.watch(dioProvider));
});
