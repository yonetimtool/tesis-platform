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

/// App-bar avatari + profil ekrani onizlemesi.
///
/// (P212 §2) HATA ARTIK YUTULMUYOR.
///
/// OLCULEN KUSUR: `catch (_) { return null; }` her hatayi "fotograf yok"a
/// ceviriyordu. Sonuc: `/me` cagrisi basarisiz olunca ekran fotografi
/// OLMAYAN bir kullanici gibi davraniyor, "Kaldir" dugmesini GIZLIYOR ve
/// kullaniciya HICBIR SEY soylemiyordu — "kaldiramiyorum" sikayetinin
/// ekranda hicbir izi olmamasinin sebebi buydu.
///
/// Artik hata YUKARI CIKAR: cagiran `AsyncValue.hasError` ile durumu
/// ayirt eder (profil kartinda mesaj + "tekrar dene", app-bar'da sessiz
/// bas-harf yedegi). "Fotograf yok" ile "okuyamadim" AYNI SEY DEGILDIR.
final myAvatarUrlProvider = FutureProvider.autoDispose<String?>((ref) async {
  return ref.watch(avatarApiProvider).fetchMyAvatarUrl();
});
