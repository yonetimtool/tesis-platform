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
    // (P164) BASLANGIC KATI EKSIKTI: alan gonderilmeyince sunucu 1
    // varsayiyor ve bodrumlu bir binada kat numaralari bir kaydirmayla
    // yaziliyordu. Bodrum ve zemin GERCEK katlardir (-2, -1, 0).
    int? baslangicKat,
    String? unitTipId,
    String? unitGrupId,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/units/bulk',
        data: {
          if (blok != null && blok.isNotEmpty) 'blok': blok,
          'kat_sayisi': katSayisi,
          'kat_basi_daire': katBasiDaire,
          'baslangic_no': baslangicNo,
          'baslangic_kat': ?baslangicKat,
          // (P26) Verilirse PARTININ TAMAMINA uygulanir.
          'unit_tip_id': ?unitTipId,
          'unit_grup_id': ?unitGrupId,
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

  /// (P165) `GET /units/kat-onizleme` — kat silinirse NE KAYBEDILECEK.
  ///
  /// SAYAR, SILMEZ. Ayri uc cunku ozet KARAR ANINDA gerekiyor: `kat-sil`
  /// `cascade=false` iken zaten 409 doner, ama o yanit ancak kullanici
  /// SILMEYE BASTIKTAN sonra gorunur — hata yolunu bilgi yolu olarak
  /// kullanmak, kullaniciyi once denemeye zorlamakti.
  Future<KatOnizleme> fetchKatOnizleme({
    required String blok,
    required int kat,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/units/kat-onizleme',
        queryParameters: {'blok': blok, 'kat': kat},
      );
      return KatOnizleme.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /units/kat-sil` — bir blogun BIR KATINI siler.
  ///
  /// `cascade` ZORUNLU OLARAK true gonderilmez; cagiran karar verir.
  /// Sunucu cascade=false iken dolu kat icin 409 doner ve ekran bunu
  /// kullaniciya gosterir — "sildim" deyip silmemek en kotu sonuctur.
  Future<int> deleteFloor({
    required String blok,
    required int kat,
    bool cascade = true,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/units/kat-sil',
        data: {'blok': blok, 'kat': kat, 'cascade': cascade},
      );
      return (res.data?['silinen'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `PATCH /units/toplu` — secili dairelerin tipini/durumunu degistirir.
  ///
  /// EN AZ BIR ALAN gonderilmeli; ikisi de null ise sunucu 422 doner.
  /// Cagiran bunu ONCEDEN engeller (bos istek "yaptim" deyip hicbir sey
  /// yapmamakti).
  Future<int> bulkUpdateUnits({
    required List<String> unitIds,
    String? unitTipId,
    bool? aktif,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/units/toplu',
        data: {'unit_ids': unitIds, 'unit_tip_id': ?unitTipId, 'aktif': ?aktif},
      );
      return (res.data?['etkilenen'] as num?)?.toInt() ?? unitIds.length;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `PATCH /units/siralama` — TEK ISTEKTE kat/sira gunceller.
  ///
  /// Daire basina ayri `PATCH` atmak, yirmi dairelik bir katta yirmi
  /// istek ve ARADA KESILME riski demekti: yarim uygulanmis bir siralama,
  /// kullanicinin gordugu duzen ile veritabanindakini ayirirdi.
  Future<void> reorderUnits(List<UnitSiraSatiri> satirlar) async {
    if (satirlar.isEmpty) return;
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/units/siralama',
        data: {
          'satirlar': [
            for (final s in satirlar)
              {'id': s.id, 'kat': s.kat, 'sira': s.sira},
          ],
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

/// `PATCH /units/siralama` govdesindeki tek satir.
class UnitSiraSatiri {
  const UnitSiraSatiri({
    required this.id,
    required this.kat,
    required this.sira,
  });

  final String id;
  final int kat;
  final int sira;
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
