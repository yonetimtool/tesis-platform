import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../tasks/domain/task_models.dart' show PresignTicket;
import '../domain/support_models.dart';

/// POST/GET /support — yonetici destek kanali (WP1). Admin yaniti panelden.
/// WP-G: opsiyonel talep gorseli (announcements presign PUT deseni).
class SupportApi {
  SupportApi(this._dio, {Dio? uploadDio}) : _uploadDio = uploadDio ?? Dio();

  final Dio _dio;
  final Dio _uploadDio; // presigned PUT: auth header'siz temiz istemci

  Future<List<SupportTicket>> fetchMine({int limit = 50}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/support',
      queryParameters: {'limit': limit},
    );
    return [
      for (final item in (res.data?['items'] as List?) ?? const [])
        if (item is Map)
          SupportTicket.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<SupportTicket> create({
    required String konu,
    required String aciklama,
    String? fotoKey,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/support',
      data: {'konu': konu, 'aciklama': aciklama, 'foto_key': ?fotoKey},
    );
    return SupportTicket.fromJson(res.data ?? const {});
  }

  Future<PresignTicket> presignUpload({required String contentType}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/uploads/presign',
        data: {'content_type': contentType, 'dosya_adi': 'destek.jpg'},
      );
      return PresignTicket.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> uploadPhoto({
    required PresignTicket ticket,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await _uploadDio.put<void>(
      ticket.uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(headers: {
        Headers.contentTypeHeader: contentType,
        Headers.contentLengthHeader: bytes.length,
      }),
    );
  }
}

final supportApiProvider = Provider<SupportApi>((ref) {
  return SupportApi(ref.watch(dioProvider));
});

/// Yoneticinin kendi biletleri (en-yeni-ustte sunucu sirasi).
final myTicketsProvider =
    FutureProvider.autoDispose<List<SupportTicket>>((ref) {
  return ref.watch(supportApiProvider).fetchMine();
});
