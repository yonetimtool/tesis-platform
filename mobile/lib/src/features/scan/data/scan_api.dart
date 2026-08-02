import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/scan.dart';

/// `/scans` endpoint'inin ince HTTP istemcisi. DioException'lari sozlesme hata
/// zarfina gore [ApiException]'a cevirir; 404 (eslesme yok) cagirana statusCode
/// ile ayirt ettirilir.
class ScanApi {
  ScanApi(this._dio);

  final Dio _dio;

  /// `POST /scans` — Idempotency-Key ZORUNLU. 201 → yeni kayit, 200 → mevcut
  /// kayit (idempotent tekrar). 404 → nfc_tag_uid hicbir checkpoint ile
  /// eslesmedi (ApiException.statusCode == 404).
  Future<ScanSubmitResult> submit(ScanDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/scans',
        data: draft.toJson(),
        options: Options(headers: {'Idempotency-Key': draft.idempotencyKey}),
      );
      return ScanSubmitResult(
        event: ScanEvent.fromJson(res.data!),
        wasDuplicate: res.statusCode == 200,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /scans/simule` — SIMULE OKUTMA (P115).
  ///
  /// YALNIZ demo modundaki tesiste calisir; baska bir tesiste sunucu
  /// **404** doner (uc "yok" gibi davranir). Istemci bu ucu ancak
  /// `TenantSettings.demoMod` acikken cagirir.
  ///
  /// Govdede `nfc_tag_uid` YOKTUR: etiketin kimligini istemciden almak,
  /// demo tesisinde bile "hangi etiket okutuldu"yu istemcinin
  /// uydurmasina birakmak olurdu — sunucu onu `checkpointId`den cozer.
  Future<ScanSubmitResult> submitSimule({
    required String checkpointId,
    required String idempotencyKey,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/scans/simule',
        data: {'checkpoint_id': checkpointId},
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return ScanSubmitResult(
        event: ScanEvent.fromJson(res.data!),
        wasDuplicate: res.statusCode == 200,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final scanApiProvider = Provider<ScanApi>((ref) {
  return ScanApi(ref.watch(dioProvider));
});
