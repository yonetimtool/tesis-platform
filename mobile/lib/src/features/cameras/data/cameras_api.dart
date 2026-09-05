import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/camera_models.dart';

/// (P190 §6) Canli yayin (`canli_yol`) icin OYNATICIYA verilecek HTTP
/// basliklari. Sunucu HLS ucu normal API yetkisi ister; parca istekleri
/// listeye goreli oldugundan ayni baslik hepsini kapsar.
///
/// BURADA (data katmani), oynatici ekranda DEGIL: `Authorization` bir
/// protokol sabitidir ve cizim katmanindaki sabit-metin taramasi
/// (sabit_metin_denetimi_test) hakli olarak orada dizge sabiti istemez.
Map<String, String> canliYayinBasliklari(String? token) =>
    {if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token'};

/// `/cameras` istemcisi.
///
/// RBAC (sunucu zorlar): OKUMA tum roller AMA liste ROL'E GORE SUZULUR —
/// admin/yonetici/security tumunu, resident/tesis_gorevlisi yalniz
/// `aktif && sakin_gorebilir` kameralari alir. Istemci suzgeci TEKRARLAMAZ:
/// ekranda gelen liste ne ise o cizilir (gizli kamera yaniti hic terk etmez).
/// YAZMA admin + yonetici.
class CamerasApi {
  CamerasApi(this._dio);
  final Dio _dio;

  /// (P213 §4) `anaEkranda: true` -> yalnizca ANA EKRANDA gosterilmek
  /// uzere isaretlenmis kameralar. Suzgec SUNUCUDA uygulanir; istemci
  /// tum listeyi cekip elemez — 20 kamerali bir sitede o, 20 kamera
  /// verisi indirip 4'unu gostermek olurdu.
  Future<List<Camera>> fetch({int limit = 100, bool? anaEkranda}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/cameras',
        queryParameters: {
          'limit': limit,
          'ana_ekranda': ?anaEkranda,
        },
      );
      return [
        for (final item in (res.data?['items'] as List?) ?? const [])
          if (item is Map) Camera.fromJson(Map<String, dynamic>.from(item)),
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// (P190 §6) `GET /cameras/{id}/kare` — RTSP kameradan SUNUCUNUN yakaladigi
  /// TEK JPEG kare.
  ///
  /// Yetkili Dio ile BAYT olarak cekilir; `Image.network` KULLANILAMAZ
  /// (Authorization basligi olmadan 401 yerdi). Hatalar: 502
  /// `kamera_baglanti_yok` (kamera erisilemez), 422 (RTSP degil), 404
  /// (role gorunmez) — hepsi [ApiException] olarak yukari cikar; karo
  /// "baglanti yok" durumunu cizer.
  Future<Uint8List> kare(String id) async {
    try {
      final res = await _dio.get<List<int>>(
        '/cameras/$id/kare',
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data ?? const []);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Camera> create(CameraDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/cameras',
        data: draft.toCreateJson(),
      );
      return Camera.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Camera> update(String id, CameraDraft draft) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/cameras/$id',
        data: draft.toUpdateJson(),
      );
      return Camera.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete<void>('/cameras/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final camerasApiProvider = Provider<CamerasApi>((ref) {
  return CamerasApi(ref.watch(dioProvider));
});

/// Kamera listesi — ana ekran seridi + kamera ekrani AYNI saglayiciyi
/// kullanir (tek istek, sunucu suzgeci). Hata → izleyen bolum sessizce
/// gizlenir (ana ekran rehin degil).
final camerasProvider = FutureProvider.autoDispose<List<Camera>>((ref) {
  return ref.watch(camerasApiProvider).fetch();
});

/// (P213 §4) ANA EKRAN BANDI — yalnizca isaretli kameralar.
///
/// Ayri saglayici: kameralar EKRANI tum kameralari gosterir (yonetim
/// ekranidir), ana ekran ise yoneticinin SECTIKLERINI. Tek saglayiciyi
/// paylasip istemcide elemek, iki ekranin ayni onbellegi farkli
/// anlamlarla kullanmasi olurdu.
final anaEkranKameralariProvider =
    FutureProvider.autoDispose<List<Camera>>((ref) {
  return ref.watch(camerasApiProvider).fetch(limit: 10, anaEkranda: true);
});
