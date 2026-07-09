import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
// PresignTicket YENIDEN kullanilir (kopya yok) — presign yaniti gorev
// akisindakiyle ayni sozlesme semasidir (PresignResponse).
import '../../tasks/domain/task_models.dart' show PresignTicket;
import '../domain/announcement_models.dart';

/// Duyuru modulunun HTTP istemcisi:
///
///   * `GET    /announcements`      → liste (created_at DESC; TUM roller)
///   * `POST   /announcements`      → olustur (admin + yonetici)
///   * `PATCH  /announcements/{id}` → duzenle (admin + yonetici)
///   * `DELETE /announcements/{id}` → sil (admin + yonetici)
///   * `POST   /uploads/presign`    → opsiyonel duyuru gorseli icin PUT URL
///   * presigned URL'e HTTP PUT     → dosya dogrudan MinIO'ya
class AnnouncementApi {
  AnnouncementApi(this._dio, {Dio? uploadDio}) : _uploadDio = uploadDio ?? Dio();

  final Dio _dio;

  /// Presigned PUT icin TEMIZ istemci: Authorization header'i ve API
  /// base-url'u TASINMAZ (presigned imza baska header'la bozulur; URL mutlak
  /// gelir). Gorev foto akisiyla ayni desen.
  final Dio _uploadDio;

  Future<List<Announcement>> fetchAll() async {
    final out = <Announcement>[];
    var offset = 0;
    const limit = 200;
    try {
      while (true) {
        final res = await _dio.get<Map<String, dynamic>>(
          '/announcements',
          queryParameters: {'limit': limit, 'offset': offset},
        );
        final items = res.data?['items'];
        if (items is! List || items.isEmpty) break;
        for (final item in items) {
          if (item is Map) {
            out.add(Announcement.fromJson(Map<String, dynamic>.from(item)));
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

  Future<Announcement> create(AnnouncementDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/announcements',
        data: draft.toJson(),
      );
      return Announcement.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Announcement> update(String id, AnnouncementDraft draft) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/announcements/$id',
        data: draft.toJson(),
      );
      return Announcement.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete<void>('/announcements/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /uploads/presign` — duyuru gorseli icin obje anahtari + kisa
  /// omurlu PUT URL (gorev foto akisiyla ayni uc; yonetici de yetkili).
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

  /// Presigned URL'e dosyayi PUT eder (dogru Content-Type ile — imza buna
  /// gore atilmis olabilir). Basari sonrasi [PresignTicket.fotoKey]
  /// duyuru olusturmada gonderilir.
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
}

final announcementApiProvider = Provider<AnnouncementApi>((ref) {
  return AnnouncementApi(ref.watch(dioProvider));
});
