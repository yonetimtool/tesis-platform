import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
// PresignTicket YENIDEN kullanilir (kopya yok) — gorev foto kaniti akisiyla
// AYNI presign sozlesmesi (ayni uc, ayni tur/boyut limitleri).
import '../../tasks/domain/task_models.dart' show PresignTicket;
import '../domain/etkinlik_models.dart';

/// Etkinlik modulunun HTTP istemcisi:
///
///   * `GET    /events`           → liste (TUM roller; seffaf sayilar +
///                                   kullanicinin kendi beyani; tarih DESC)
///   * `POST   /events`           → olustur (admin + yonetici; sakinlere push)
///   * `PATCH  /events/{id}`      → duzenle (admin + yonetici)
///   * `DELETE /events/{id}`      → sil (admin + yonetici; RSVP'ler CASCADE)
///   * `PUT    /events/{id}/rsvp` → RSVP ver/degistir (YALNIZ resident;
///                                   kullanici basina TEK kayit — upsert)
class EtkinlikApi {
  EtkinlikApi(this._dio, {Dio? uploadDio}) : _uploadDio = uploadDio ?? Dio();

  final Dio _dio;

  /// Presigned PUT icin AYRI istemci: MinIO'ya Authorization header'i
  /// GITMEMELI (imza gecersiz olur) — site kurali/duyuru ile ayni desen.
  final Dio _uploadDio;

  Future<List<Etkinlik>> fetchAll() async {
    final out = <Etkinlik>[];
    var offset = 0;
    const limit = 200;
    try {
      while (true) {
        final res = await _dio.get<Map<String, dynamic>>(
          '/events',
          queryParameters: {'limit': limit, 'offset': offset},
        );
        final items = res.data?['items'];
        if (items is! List || items.isEmpty) break;
        for (final item in items) {
          if (item is Map) {
            out.add(Etkinlik.fromJson(Map<String, dynamic>.from(item)));
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

  /// `GET /events?aktif=true` — YAKLASAN/SUREN etkinlikler (bitisi gecmemis;
  /// suzgec ve siralama SUNUCUDA: en yakin once). Ana ekran bolumu bunu
  /// `limit` ile kullanir.
  Future<List<Etkinlik>> fetchYaklasan({int limit = 20}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/events',
        queryParameters: {'aktif': true, 'limit': limit, 'offset': 0},
      );
      final items = res.data?['items'];
      if (items is! List) return const [];
      return [
        for (final item in items)
          if (item is Map) Etkinlik.fromJson(Map<String, dynamic>.from(item)),
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /uploads/presign` — etkinlik gorseli icin obje anahtari + kisa
  /// omurlu PUT URL (gorev/duyuru/kural akisiyla AYNI uc).
  Future<PresignTicket> presignUpload({
    required String contentType,
    String? dosyaAdi,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/uploads/presign',
        data: {
          'content_type': contentType,
          'dosya_adi': ?dosyaAdi,
        },
      );
      return PresignTicket.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Presigned URL'e dosyayi PUT eder (dogru Content-Type ile). Basari
  /// sonrasi [PresignTicket.fotoKey] etkinlik kaydinda gonderilir.
  Future<void> uploadPhoto({
    required PresignTicket ticket,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      await _uploadDio.put<void>(
        ticket.uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            Headers.contentTypeHeader: contentType,
            Headers.contentLengthHeader: bytes.length,
          },
        ),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Etkinlik> create(EtkinlikDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/events',
        data: draft.toJson(),
      );
      return Etkinlik.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Etkinlik> update(String id, EtkinlikDraft draft) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/events/$id',
        data: draft.toJson(),
      );
      return Etkinlik.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete<void>('/events/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// RSVP beyani — yanit guncel SEFFAF sayilarla etkinligin kendisidir
  /// (UI sayaci aninda gunceller).
  Future<Etkinlik> rsvp(String id, KatilimDurum durum) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/events/$id/rsvp',
        data: {'durum': durum.wire},
      );
      return Etkinlik.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final etkinlikApiProvider = Provider<EtkinlikApi>((ref) {
  return EtkinlikApi(ref.watch(dioProvider));
});

/// Sakin ana ekraninin "Etkinlikler" bolumu — YAKLASAN etkinlikler (sunucu
/// suzer: `?aktif=true`, en yakin once). Bolum 3 kayit gosterir; "Tümünü Gör"
/// tam listeye gider. Hata → bolum sessizce gizlenir (ana ekran rehin degil).
final yaklasanEtkinliklerProvider =
    FutureProvider.autoDispose<List<Etkinlik>>((ref) {
  return ref.watch(etkinlikApiProvider).fetchYaklasan(limit: 3);
});
