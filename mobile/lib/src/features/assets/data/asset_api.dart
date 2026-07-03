import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/asset_models.dart';

/// Demirbas zimmet modulunun HTTP istemcisi (admin + security + cleaning):
///
///   * `GET  /assets`               → liste (UID indeksi + uzerimdekiler)
///   * `GET  /assets/{id}`          → guncel durum (okutma sonrasi tazeleme)
///   * `GET  /assets/{id}/history`  → zimmet gecmisi (alma_zamani ASC —
///                                    acik kayit/son hareketler SON sayfada)
///   * `POST /assets/{id}/checkout` → zimmete al (Idempotency-Key zorunlu)
///   * `POST /assets/{id}/checkin`  → birak (Idempotency-Key zorunlu)
class AssetApi {
  AssetApi(this._dio);

  final Dio _dio;

  /// `GET /assets` — tum sayfalari dolasip listeyi dondurur (limit 200 =
  /// sozlesme max; demirbas envanteri kucuk bir kumedir).
  Future<List<Asset>> fetchAssets({AssetDurum? durum, bool aktif = true}) async {
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
            'aktif': aktif,
            if (durum != null && durum != AssetDurum.bilinmiyor)
              'durum': durum.name,
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

  /// `GET /assets/{id}` — guncel durum (okutma karti her zaman taze durumla
  /// cizilir; liste onbellegi bayat olabilir).
  Future<Asset> fetchAsset(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/assets/$id');
      return Asset.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Zimmet gecmisinin SON [lastN] kaydini (en yeni en sonda) dondurur.
  /// Backend `alma_zamani` ASC siraladigi icin once toplami ogrenir, sonra
  /// son sayfayi ceker (README §13'te DESC onerisi flag'li).
  Future<List<AssetCheckout>> fetchHistoryTail(
    String assetId, {
    int lastN = 20,
  }) async {
    try {
      final head = await _dio.get<Map<String, dynamic>>(
        '/assets/$assetId/history',
        queryParameters: {'limit': 1, 'offset': 0},
      );
      final meta = head.data?['meta'];
      final total = meta is Map ? (meta['total'] as num?)?.toInt() ?? 0 : 0;
      if (total == 0) return const [];

      final offset = total > lastN ? total - lastN : 0;
      final res = await _dio.get<Map<String, dynamic>>(
        '/assets/$assetId/history',
        queryParameters: {'limit': lastN, 'offset': offset},
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

  /// `POST /assets/{id}/checkin` — backend kapatma ve idempotent tekrari
  /// ayni kodla (200) doner; 409 "Acik zimmet yok (demirbas zaten musait)."
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
