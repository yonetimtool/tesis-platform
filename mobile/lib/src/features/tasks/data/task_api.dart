import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/task_models.dart';

/// Gorev modulunun HTTP istemcisi. Kullanilan uclar (cleaning + security +
/// admin erisir — bkz. contracts/auth.md):
///
///   * `GET  /tasks`                   → gorev listesi (tip/aktif filtreli)
///   * `POST /tasks/{id}/completions`  → tamamlama (Idempotency-Key ZORUNLU)
///   * `POST /uploads/presign`         → foto icin presigned PUT URL
///   * presigned URL'e HTTP PUT        → dosya dogrudan MinIO'ya
///
/// DioException'lar sozlesme hata zarfina gore [ApiException]'a cevrilir.
class TaskApi {
  TaskApi(this._dio, {Dio? uploadDio}) : _uploadDio = uploadDio ?? Dio();

  final Dio _dio;

  /// Presigned PUT icin TEMIZ istemci: Authorization header'i ve API
  /// base-url'u TASINMAZ (presigned imza baska header'la bozulur; URL mutlak
  /// gelir). Content-Type istek basina verilir.
  final Dio _uploadDio;

  /// `GET /tasks` — aktif gorevler, gerekirse tip filtreli. Sayfalari
  /// dolasarak TUM kumeyi dondurur (limit 200 = sozlesme max; gorev sayisi
  /// kucuk bir kumedir).
  Future<List<Task>> fetchTasks({TaskTip? tip, bool aktif = true}) async {
    final tasks = <Task>[];
    var offset = 0;
    const limit = 200;
    try {
      while (true) {
        final res = await _dio.get<Map<String, dynamic>>(
          '/tasks',
          queryParameters: {
            'limit': limit,
            'offset': offset,
            'aktif': aktif,
            if (tip != null && tip != TaskTip.bilinmiyor) 'tip': tip.name,
          },
        );
        final items = res.data?['items'];
        if (items is! List || items.isEmpty) break;
        for (final item in items) {
          if (item is Map) {
            tasks.add(Task.fromJson(Map<String, dynamic>.from(item)));
          }
        }
        if (items.length < limit) break;
        offset += limit;
      }
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
    return tasks;
  }

  /// `POST /tasks/{id}/completions` — gorevi kanitla tamamlar.
  /// 201 → yeni kayit, 200 → ayni Idempotency-Key ile idempotent tekrar
  /// ([TaskCompletionResult.wasDuplicate]). NFC etiketi gorevin
  /// checkpoint'iyle eslesmezse backend 422 `invalid_reference` doner —
  /// mesaji kullaniciya oldugu gibi gosterilebilir.
  Future<TaskCompletionResult> submitCompletion(
    TaskCompletionDraft draft,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/tasks/${draft.taskId}/completions',
        data: draft.toJson(),
        options: Options(headers: {'Idempotency-Key': draft.idempotencyKey}),
      );
      return TaskCompletionResult(
        completion: TaskCompletion.fromJson(res.data ?? const {}),
        wasDuplicate: res.statusCode == 200,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /uploads/presign` — foto icin obje anahtari + kisa omurlu PUT URL.
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
  /// completion'da gonderilir.
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

final taskApiProvider = Provider<TaskApi>((ref) {
  return TaskApi(ref.watch(dioProvider));
});
