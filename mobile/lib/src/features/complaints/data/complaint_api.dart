import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
// PresignTicket YENIDEN kullanilir (kopya yok) — presign yaniti gorev/duyuru
// akisindakiyle ayni sozlesme semasidir (PresignResponse).
import '../../tasks/domain/task_models.dart' show PresignTicket;
import '../domain/complaint_models.dart';

/// Sikayet/oneri modulunun HTTP istemcisi:
///
///   * `GET   /complaints`        → liste (acan roller KENDI; yonetim TUMU; DESC)
///   * `POST  /complaints`        → talep ac (security/tesis_gorevlisi/resident)
///   * `PATCH /complaints/{id}`   → durum/yanit (admin + yonetici)
///   * `POST  /uploads/presign`   → opsiyonel talep gorseli icin PUT URL
///   * presigned URL'e HTTP PUT   → dosya dogrudan MinIO'ya
class ComplaintApi {
  ComplaintApi(this._dio, {Dio? uploadDio}) : _uploadDio = uploadDio ?? Dio();

  final Dio _dio;

  /// Presigned PUT icin TEMIZ istemci: Authorization header'i ve API
  /// base-url'u TASINMAZ (presigned imza baska header'la bozulur; URL mutlak
  /// gelir). Gorev/duyuru foto akisiyla ayni desen.
  final Dio _uploadDio;

  Future<List<Complaint>> fetchAll() async {
    final out = <Complaint>[];
    var offset = 0;
    const limit = 200;
    try {
      while (true) {
        final res = await _dio.get<Map<String, dynamic>>(
          '/complaints',
          queryParameters: {'limit': limit, 'offset': offset},
        );
        final items = res.data?['items'];
        if (items is! List || items.isEmpty) break;
        for (final item in items) {
          if (item is Map) {
            out.add(Complaint.fromJson(Map<String, dynamic>.from(item)));
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

  Future<Complaint> create(ComplaintDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/complaints',
        data: draft.toJson(),
      );
      return Complaint.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Complaint> reply(String id, ComplaintReplyDraft draft) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/complaints/$id',
        data: draft.toJson(),
      );
      return Complaint.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /uploads/presign` — talep gorseli icin obje anahtari + kisa
  /// omurlu PUT URL (gorev/duyuru foto akisiyla ayni uc; acan roller yetkili).
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
  /// talep acmada gonderilir.
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

final complaintApiProvider = Provider<ComplaintApi>((ref) {
  return ComplaintApi(ref.watch(dioProvider));
});
