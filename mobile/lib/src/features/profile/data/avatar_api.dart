import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../tasks/domain/task_models.dart' show PresignTicket;

/// GET /me yanitindan avatar_url (SAF — test edilebilir).
String? avatarUrlFromMe(Map<String, dynamic> json) =>
    json['avatar_url'] as String?;

/// Profil fotografi istemcisi (WP-D) — presign PUT + PATCH /me/avatar.
/// Yalniz personel rollerinde cagrilir (resident'a sunucu 403 doner).
class AvatarApi {
  AvatarApi(this._dio, {Dio? uploadDio}) : _uploadDio = uploadDio ?? Dio();

  final Dio _dio;
  final Dio _uploadDio; // presigned PUT: auth header'siz temiz istemci

  Future<PresignTicket> presignUpload({required String contentType}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/uploads/presign',
        data: {'content_type': contentType, 'dosya_adi': 'avatar.jpg'},
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

  /// null -> fotografi kaldir. Basarida yeni avatar_url doner.
  Future<String?> setAvatar(String? fotoKey) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/me/avatar',
        data: {'avatar_key': fotoKey},
      );
      return avatarUrlFromMe(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<String?> fetchMyAvatarUrl() async {
    final res = await _dio.get<Map<String, dynamic>>('/me');
    return avatarUrlFromMe(res.data ?? const {});
  }
}

final avatarApiProvider = Provider<AvatarApi>((ref) {
  return AvatarApi(ref.watch(dioProvider));
});

/// App-bar avatari + profil ekrani onizlemesi. Hata -> null (bas harf/ikon
/// fallback'i cizilir; ekran dusmez).
final myAvatarUrlProvider = FutureProvider.autoDispose<String?>((ref) async {
  try {
    return await ref.watch(avatarApiProvider).fetchMyAvatarUrl();
  } catch (_) {
    return null;
  }
});
