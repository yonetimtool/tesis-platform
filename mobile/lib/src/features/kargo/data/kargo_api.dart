import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
// PresignTicket YENIDEN kullanilir (kopya yok) — presign yaniti gorev/duyuru/
// talep akisindakiyle ayni sozlesme semasidir (PresignResponse).
import '../../tasks/domain/task_models.dart' show PresignTicket;
import '../domain/kargo_models.dart';

/// Kargo modulunun HTTP istemcisi:
///
///   * `GET   /kargo`           → gecmis (yonetim+guvenlik TUMU; sakin KENDI
///                                 dairesi; sunucu created_at DESC siralar)
///   * `POST  /kargo`           → paket kaydi (YALNIZ security)
///   * `PATCH /kargo/{id}`      → teslim aldim (o dairenin aktif sakini;
///                                 ikinci isaret 409 — teslim alan degismez)
///   * `POST  /uploads/presign` → opsiyonel paket fotografi icin PUT URL
///   * presigned URL'e HTTP PUT → dosya dogrudan MinIO'ya
class KargoApi {
  KargoApi(this._dio, {Dio? uploadDio}) : _uploadDio = uploadDio ?? Dio();

  final Dio _dio;

  /// Presigned PUT icin TEMIZ istemci: Authorization header'i ve API
  /// base-url'u TASINMAZ (presigned imza baska header'la bozulur; URL mutlak
  /// gelir). Gorev/duyuru/talep foto akisiyla ayni desen.
  final Dio _uploadDio;

  Future<List<Kargo>> fetchAll() async {
    final out = <Kargo>[];
    var offset = 0;
    const limit = 200;
    try {
      while (true) {
        final res = await _dio.get<Map<String, dynamic>>(
          '/kargo',
          queryParameters: {'limit': limit, 'offset': offset},
        );
        final items = res.data?['items'];
        if (items is! List || items.isEmpty) break;
        for (final item in items) {
          if (item is Map) {
            out.add(Kargo.fromJson(Map<String, dynamic>.from(item)));
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

  Future<Kargo> create(KargoDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/kargo',
        data: draft.toJson(),
      );
      return Kargo.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Sakin teslim isareti: bekliyor -> teslim_alindi.
  Future<Kargo> markReceived(String id) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/kargo/$id',
        data: {'durum': 'teslim_alindi'},
      );
      return Kargo.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /uploads/presign` — paket fotografi icin obje anahtari + kisa
  /// omurlu PUT URL (gorev/duyuru/talep foto akisiyla AYNI uc; security yetkili).
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
  /// kargo kaydinda gonderilir.
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

final kargoApiProvider = Provider<KargoApi>((ref) {
  return KargoApi(ref.watch(dioProvider));
});
