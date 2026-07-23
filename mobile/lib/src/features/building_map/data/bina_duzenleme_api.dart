import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/bina_duzenleme_models.dart';

/// "Bina Düzenleme" (D-viz Rev-2) HTTP istemcisi — mevcut blok/daire CRUD
/// uclarini kullanir (yeni backend YOK):
///   * `GET/POST/PATCH/DELETE /blocks`  → blok yonetimi (BOS bloklar dahil).
///   * `GET /units` (limit=200)         → tum daireler (blok->kat->sira gruplama).
///   * `POST/PATCH/DELETE /units`       → daire olustur/duzenle/sil.
/// Hepsi admin+yonetici (backend RBAC 403 doner digerlerine). Blok silme, o
/// blogu kullanan daire varsa 409 doner (ekran mesaj gosterir).
class BinaDuzenlemeApi {
  BinaDuzenlemeApi(this._dio);

  final Dio _dio;

  /// Editor daire listesi tek sayfada cekilir; buyuk siteler icin ust sinir.
  static const int _unitLimit = 200;

  Future<List<BuildingBlock>> listBlocks() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/blocks');
      final items = (res.data?['items'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => BuildingBlock.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      return items;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<EditorUnit>> listUnits() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/units',
        queryParameters: {'limit': _unitLimit, 'offset': 0},
      );
      final items = (res.data?['items'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => EditorUnit.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      return items;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<BuildingBlock> createBlock(BlockDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/blocks',
        data: draft.toJson(),
      );
      return BuildingBlock.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<BuildingBlock> updateBlock(String blockId, BlockDraft draft) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/blocks/$blockId',
        data: draft.toJson(),
      );
      return BuildingBlock.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Blok siler. [cascade]=false ise o blogu kullanan daire varsa backend 409
  /// doner (ApiException statusCode=409). [cascade]=true ise blogun daireleri
  /// (ve bagli kayitlari) da silinir — cagiran ekran once yazili onay alir.
  Future<void> deleteBlock(String blockId, {bool cascade = false}) async {
    try {
      await _dio.delete<void>(
        '/blocks/$blockId',
        queryParameters: cascade ? const {'cascade': 'true'} : null,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<EditorUnit> createUnit(EditorUnitDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/units',
        data: draft.toJson(),
      );
      return EditorUnit.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<EditorUnit> updateUnit(String unitId, EditorUnitDraft draft) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/units/$unitId',
        data: draft.toJson(),
      );
      return EditorUnit.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> deleteUnit(String unitId) async {
    try {
      await _dio.delete<void>('/units/$unitId');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /units/bulk` — toplu daire olustur. Sunucu ardisik numaralandirir
  /// (kat kat); var olan no'lar atlanir.
  Future<BulkUnitResult> bulkCreateUnits({
    String? blok,
    required int katSayisi,
    required int katBasiDaire,
    required int baslangicNo,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/units/bulk',
        data: {
          if (blok != null && blok.isNotEmpty) 'blok': blok,
          'kat_sayisi': katSayisi,
          'kat_basi_daire': katBasiDaire,
          'baslangic_no': baslangicNo,
        },
      );
      final d = res.data ?? const {};
      return BulkUnitResult(
        olusturulanSayi: (d['olusturulan'] as List?)?.length ?? 0,
        atlanan: ((d['atlanan'] as List?) ?? const <dynamic>[]).cast<String>(),
        bitisNo: (d['bitis_no'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

/// `POST /units/bulk` sonucu — kac daire olustu, hangileri atlandi, bitis no.
class BulkUnitResult {
  const BulkUnitResult({
    required this.olusturulanSayi,
    required this.atlanan,
    required this.bitisNo,
  });

  final int olusturulanSayi;
  final List<String> atlanan;
  final int bitisNo;
}

final binaDuzenlemeApiProvider = Provider<BinaDuzenlemeApi>((ref) {
  return BinaDuzenlemeApi(ref.watch(dioProvider));
});
