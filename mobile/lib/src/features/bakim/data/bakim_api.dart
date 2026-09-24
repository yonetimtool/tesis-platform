import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../tasks/domain/task_models.dart' show PresignTicket;
import '../domain/bakim_models.dart';

/// (P241 §1) Bakim ucu.
class BakimApi {
  BakimApi(this._dio, {Dio? uploadDio}) : _uploadDio = uploadDio ?? Dio();

  final Dio _dio;

  /// Imzali PUT icin AYRI istemci: ana `Dio` yetki basligi ekler ve
  /// depo imzasi yabanci bir basligi reddeder (gider fisindeki karar).
  final Dio _uploadDio;

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

  /// (E2E 2026-09) Bakim kaydinin ekleri (TESIS-05). Sunucu
  /// `varlik_tipi=bakim_kaydi` ekini P241'den beri kabul ediyordu ama
  /// hicbir ekran onu cizmiyordu.
  Future<List<BakimEki>> ekler(String kayitId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/ekler',
        queryParameters: {'varlik_tipi': 'bakim_kaydi', 'varlik_id': kayitId},
      );
      return ((res.data?['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => BakimEki.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Fotografi yukler ve kayda baglar: presign (`amac=belge`, ek
  /// baglami) -> imzali PUT -> `/ekler`.
  Future<void> fotoEkle({
    required String kayitId,
    required Uint8List baytlar,
    String contentType = 'image/jpeg',
    String dosyaAdi = 'bakim.jpg',
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/uploads/presign',
        data: {
          'content_type': contentType,
          'dosya_adi': dosyaAdi,
          'amac': 'belge',
          'boyut': baytlar.length,
        },
      );
      final bilet = PresignTicket.fromJson(res.data ?? const {});
      await _uploadDio.put<void>(
        bilet.uploadUrl,
        data: Stream.value(baytlar),
        options: Options(headers: {
          Headers.contentTypeHeader: contentType,
          Headers.contentLengthHeader: baytlar.length,
        }),
      );
      await _dio.post<Map<String, dynamic>>(
        '/ekler',
        data: {
          'varlik_tipi': 'bakim_kaydi',
          'varlik_id': kayitId,
          'tur': 'dosya',
          'dosya_key': bilet.fotoKey,
          'dosya_adi': dosyaAdi,
        },
      );
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

/// (E2E 2026-09) Bir ekipmanin gecmis bakim kayitlari (en yeni ustte).
final bakimKayitlariProvider = FutureProvider.autoDispose
    .family<List<BakimKaydi>, String>(
  (ref, ekipmanId) => ref.watch(bakimApiProvider).kayitlar(ekipmanId: ekipmanId),
);

final bakimEkleriProvider =
    FutureProvider.autoDispose.family<List<BakimEki>, String>(
  (ref, kayitId) => ref.watch(bakimApiProvider).ekler(kayitId),
);
