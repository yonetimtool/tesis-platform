import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../data/bina_duzenleme_api.dart';
import '../domain/bina_duzenleme_models.dart';
import '../../../core/error/akis_hatasi.dart';

/// "Bina Düzenleme" editor durumu — bloklar (BOS dahil) + tum daireler yuklenir;
/// yonetim gorsel olarak blok/kat/daire olusturur/duzenler/siler.
class BinaDuzenlemeState {
  const BinaDuzenlemeState({
    this.loading = false,
    this.errorMessage,
    this.hataKimligi,
    this.blocks = const [],
    this.units = const [],
  });

  final bool loading;

  /// Hata KANALI ikilidir: `errorMessage` SUNUCU metnini, `hataKimligi`
  /// yerellestirilebilir KIMLIGI tasir (bkz. core/error/akis_hatasi.dart).
  final String? errorMessage;
  final AkisHatasi? hataKimligi;
  final List<BuildingBlock> blocks;
  final List<EditorUnit> units;

  /// Hic yapi yok mu (blok da daire de yok)?
  bool get bos => blocks.isEmpty && units.isEmpty;

  /// Blok etiketleri — kayitli bloklar + daire.blok'ta gecen etiketler (birlesim,
  /// sirali). building-map'in aksine BOS blogu da icerir.
  List<String> get blockLabels {
    final labels = <String>{
      for (final b in blocks) b.ad,
      for (final u in units)
        if (u.blok != null && u.blok!.isNotEmpty) u.blok!,
    };
    final list = labels.toList()..sort();
    return list;
  }

  /// Etikete karsilik kayitli blok (yoksa null → yalniz daireden turemis etiket;
  /// duzenle/sil sunulmaz).
  BuildingBlock? blockByLabel(String label) {
    for (final b in blocks) {
      if (b.ad == label) return b;
    }
    return null;
  }

  /// Blok-suz daireler (blok=null) — implicit tek blok gorunumu.
  List<EditorUnit> get blocklessUnits =>
      units.where((u) => u.blok == null || u.blok!.isEmpty).toList();

  /// Bir bloktaki daireler (etikete gore).
  List<EditorUnit> unitsForBlock(String label) =>
      units.where((u) => u.blok == label).toList();

  BinaDuzenlemeState copyWith({
    bool? loading,
    Object? errorMessage = _sentinel,
    Object? hataKimligi = _sentinel,
    List<BuildingBlock>? blocks,
    List<EditorUnit>? units,
  }) {
    return BinaDuzenlemeState(
      loading: loading ?? this.loading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      hataKimligi: hataKimligi == _sentinel
          ? this.hataKimligi
          : hataKimligi as AkisHatasi?,
      blocks: blocks ?? this.blocks,
      units: units ?? this.units,
    );
  }

  static const Object _sentinel = Object();
}

class BinaDuzenlemeController extends Notifier<BinaDuzenlemeState> {
  bool _refreshing = false;

  @override
  BinaDuzenlemeState build() {
    Future.microtask(refresh);
    return const BinaDuzenlemeState(loading: true);
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    state = state.copyWith(
      loading: true,
      errorMessage: null,
      hataKimligi: null,
    );
    try {
      final api = ref.read(binaDuzenlemeApiProvider);
      final results = await Future.wait([api.listBlocks(), api.listUnits()]);
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        blocks: results[0] as List<BuildingBlock>,
        units: results[1] as List<EditorUnit>,
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: e.message,
        hataKimligi: e.agHatasi,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: null,
        hataKimligi: AkisHatasi.beklenmeyen,
      );
    } finally {
      _refreshing = false;
    }
  }

  /// Asagidaki mutasyonlar basari sonrasi listeleri tazeler; hata ApiException
  /// olarak firlar (ekran mesaji gosterir — orn. blok silmede 409).
  Future<void> createBlock(BlockDraft draft) async {
    await ref.read(binaDuzenlemeApiProvider).createBlock(draft);
    await refresh();
  }

  Future<void> updateBlock(String blockId, BlockDraft draft) async {
    await ref.read(binaDuzenlemeApiProvider).updateBlock(blockId, draft);
    await refresh();
  }

  Future<void> deleteBlock(String blockId, {bool cascade = false}) async {
    await ref
        .read(binaDuzenlemeApiProvider)
        .deleteBlock(blockId, cascade: cascade);
    await refresh();
  }

  Future<void> createUnit(EditorUnitDraft draft) async {
    await ref.read(binaDuzenlemeApiProvider).createUnit(draft);
    await refresh();
  }

  Future<void> updateUnit(String unitId, EditorUnitDraft draft) async {
    await ref.read(binaDuzenlemeApiProvider).updateUnit(unitId, draft);
    await refresh();
  }

  Future<void> deleteUnit(String unitId) async {
    await ref.read(binaDuzenlemeApiProvider).deleteUnit(unitId);
    await refresh();
  }

  /// Toplu daire ekle; sonuc (olusturulan/atlanan/bitis) cagirana doner.
  Future<BulkUnitResult> bulkCreateUnits({
    String? blok,
    required int katSayisi,
    required int katBasiDaire,
    required int baslangicNo,
    int? baslangicKat,
    String? unitTipId,
    String? unitGrupId,
  }) async {
    final res = await ref
        .read(binaDuzenlemeApiProvider)
        .bulkCreateUnits(
          blok: blok,
          katSayisi: katSayisi,
          katBasiDaire: katBasiDaire,
          baslangicNo: baslangicNo,
          baslangicKat: baslangicKat,
          unitTipId: unitTipId,
          unitGrupId: unitGrupId,
        );
    await refresh();
    return res;
  }

  // ====================================================================
  // (P164) WEB'DE OLUP MOBILDE OLMAYAN UC YETENEK
  //
  // `docs/web-mobil-esitlik.md` P163'te olcmustu: kat silme, daire tipi
  // toplu degistirme ve suruklemeli siralama webde vardi, mobilde YOKTU.
  // Uclarin hepsi ZATEN mevcuttu; eksik olan istemci tarafiydi.
  // ====================================================================

  /// Bir blogun BIR KATINI siler. Donen sayi silinen daire adedidir.
  Future<int> deleteFloor({
    required String blok,
    required int kat,
    bool cascade = true,
  }) async {
    final n = await ref
        .read(binaDuzenlemeApiProvider)
        .deleteFloor(blok: blok, kat: kat, cascade: cascade);
    await refresh();
    return n;
  }

  /// Secili dairelerin tipini/durumunu toplu degistirir.
  ///
  /// EN AZ BIR ALAN sarti CAGIRANDA degil BURADA: bos bir istek sunucudan
  /// 422 alirdi ve kullaniciya "yaptim" demis olurduk.
  Future<int> bulkUpdateUnits({
    required List<String> unitIds,
    String? unitTipId,
    bool? aktif,
  }) async {
    if (unitIds.isEmpty || (unitTipId == null && aktif == null)) return 0;
    final n = await ref
        .read(binaDuzenlemeApiProvider)
        .bulkUpdateUnits(unitIds: unitIds, unitTipId: unitTipId, aktif: aktif);
    await refresh();
    return n;
  }

  /// Kat/sira duzenini TEK ISTEKTE kaydeder (suruklemeli siralama).
  Future<void> reorderUnits(List<UnitSiraSatiri> satirlar) async {
    if (satirlar.isEmpty) return;
    await ref.read(binaDuzenlemeApiProvider).reorderUnits(satirlar);
    await refresh();
  }
}

final binaDuzenlemeControllerProvider =
    NotifierProvider<BinaDuzenlemeController, BinaDuzenlemeState>(
      BinaDuzenlemeController.new,
    );
