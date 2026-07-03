import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/asset_models.dart';

/// Demirbas zimmet modulunun HTTP istemcisi (admin + security + cleaning).
/// §13 bulgulari kapandiktan sonraki SADE veri yolu:
///
///   * `GET  /assets?nfc_tag_uid=...`     → UID→asset TEK istekte (0/1 sonuc;
///                                          yanit `acik_zimmet` ozetini tasir)
///   * `GET  /assets?checked_out_by=me`   → uzerimdekiler TEK istekte
///   * `GET  /assets/{id}`                → taze durum (aksiyon sonrasi)
///   * `GET  /assets/{id}/history`        → varsayilan DESC → son N dogrudan
///   * `POST /assets/{id}/checkout|checkin` → Idempotency-Key zorunlu;
///     checkin artik SAHIPLIK kontrollu (baskasininkini kapatma → 403)
class AssetApi {
  AssetApi(this._dio);

  final Dio _dio;

  /// Okutulan UID'yi tek istekle asset'e cozer (tenant icinde unique →
  /// 0/1 sonuc). Eslesme yoksa null (etiket kayitsiz).
  Future<Asset?> findByUid(String uid) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/assets',
        queryParameters: {'nfc_tag_uid': uid.trim(), 'limit': 1},
      );
      final items = res.data?['items'];
      if (items is! List || items.isEmpty) return null;
      final first = items.first;
      return first is Map
          ? Asset.fromJson(Map<String, dynamic>.from(first))
          : null;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /assets?checked_out_by=me` — acik zimmeti bende olanlar (tek
  /// istek; sayfalar dolasilir ama pratikte 1 sayfadir).
  Future<List<Asset>> fetchMyAssets() async {
    final assets = <Asset>[];
    var offset = 0;
    const limit = 200;
    try {
      while (true) {
        final res = await _dio.get<Map<String, dynamic>>(
          '/assets',
          queryParameters: {
            'limit': limit,
            'offset': offset,
            'checked_out_by': 'me',
          },
        );
        final items = res.data?['items'];
        if (items is! List || items.isEmpty) break;
        for (final item in items) {
          if (item is Map) {
            assets.add(Asset.fromJson(Map<String, dynamic>.from(item)));
          }
        }
        if (items.length < limit) break;
        offset += limit;
      }
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
    return assets;
  }

  /// `GET /assets/{id}` — guncel durum + acik_zimmet (aksiyon sonrasi kart
  /// her zaman taze sunucu gercegiyle cizilir).
  Future<Asset> fetchAsset(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/assets/$id');
      return Asset.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Son [lastN] hareket — varsayilan siralama DESC (en yeni once)
  /// oldugundan dogrudan ilk sayfa yeter.
  Future<List<AssetCheckout>> fetchRecentHistory(
    String assetId, {
    int lastN = 20,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/assets/$assetId/history',
        queryParameters: {'limit': lastN, 'offset': 0},
      );
      final items = res.data?['items'];
      return [
        for (final item in items is List ? items : const [])
          if (item is Map)
            AssetCheckout.fromJson(Map<String, dynamic>.from(item)),
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /assets/{id}/checkout` — 201 yeni / 200 idempotent tekrar;
  /// 409 "Demirbas zaten zimmetli." (yaris: sen okurken baskasi aldi).
  Future<AssetActionResult> checkout(AssetActionDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/assets/${draft.assetId}/checkout',
        data: draft.toJson(),
        options: Options(headers: {'Idempotency-Key': draft.idempotencyKey}),
      );
      return AssetActionResult(
        checkout: AssetCheckout.fromJson(res.data ?? const {}),
        wasDuplicate: res.statusCode == 200,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /assets/{id}/checkin` — 200 (kapatma / idempotent tekrar);
  /// 409 "Acik zimmet yok"; 403 sahiplik (yalniz sahibi veya admin).
  Future<AssetActionResult> checkin(AssetActionDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/assets/${draft.assetId}/checkin',
        data: draft.toJson(),
        options: Options(headers: {'Idempotency-Key': draft.idempotencyKey}),
      );
      return AssetActionResult(
        checkout: AssetCheckout.fromJson(res.data ?? const {}),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final assetApiProvider = Provider<AssetApi>((ref) {
  return AssetApi(ref.watch(dioProvider));
});
