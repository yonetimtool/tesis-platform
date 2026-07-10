import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
// PresignTicket YENIDEN kullanilir (kopya yok) — presign yaniti gorev/duyuru/
// talep/kargo akisindakiyle ayni sozlesme semasidir (PresignResponse).
import '../../tasks/domain/task_models.dart' show PresignTicket;
import '../domain/site_kurali_models.dart';

/// Site kurallari modulunun HTTP istemcisi:
///
///   * `GET    /site-rules`        → liste (TUM roller; sira ASC; ?q= ile
///                                    sunucu tarafi baslik aramasi da var —
///                                    ekran ANLIK suzgec icin istemci tarafini
///                                    kullanir, tam liste zaten cekili)
///   * `POST   /site-rules`        → kural ekle (admin + yonetici)
///   * `PATCH  /site-rules/{id}`   → duzenle (acik foto_key=null gorseli kaldirir)
///   * `DELETE /site-rules/{id}`   → sil (HARD DELETE — salt icerik)
///   * `POST   /uploads/presign`   → opsiyonel gorsel icin PUT URL
///   * presigned URL'e HTTP PUT    → dosya dogrudan MinIO'ya
class SiteKuraliApi {
  SiteKuraliApi(this._dio, {Dio? uploadDio}) : _uploadDio = uploadDio ?? Dio();

  final Dio _dio;

  /// Presigned PUT icin TEMIZ istemci: Authorization header'i ve API
  /// base-url'u TASINMAZ (presigned imza baska header'la bozulur; URL mutlak
  /// gelir). Gorev/duyuru/talep/kargo foto akisiyla ayni desen.
  final Dio _uploadDio;

  Future<List<SiteKurali>> fetchAll({String? q}) async {
    final out = <SiteKurali>[];
    var offset = 0;
    const limit = 200;
    try {
      while (true) {
        final res = await _dio.get<Map<String, dynamic>>(
          '/site-rules',
          queryParameters: {
            'limit': limit,
            'offset': offset,
            if (q != null && q.isNotEmpty) 'q': q,
          },
        );
        final items = res.data?['items'];
        if (items is! List || items.isEmpty) break;
        for (final item in items) {
          if (item is Map) {
            out.add(SiteKurali.fromJson(Map<String, dynamic>.from(item)));
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

  Future<SiteKurali> create(SiteKuraliDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/site-rules',
        data: draft.toJson(),
      );
      return SiteKurali.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<SiteKurali> update(String id, SiteKuraliDraft draft) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/site-rules/$id',
        data: draft.toJson(),
      );
      return SiteKurali.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete<void>('/site-rules/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /uploads/presign` — kural gorseli icin obje anahtari + kisa
  /// omurlu PUT URL (mevcut akisla AYNI uc; yonetim yetkili).
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
  /// sonrasi [PresignTicket.fotoKey] kural kaydinda gonderilir.
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

final siteKuraliApiProvider = Provider<SiteKuraliApi>((ref) {
  return SiteKuraliApi(ref.watch(dioProvider));
});
