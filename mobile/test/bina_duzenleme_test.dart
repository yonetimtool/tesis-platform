import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/building_map/data/bina_duzenleme_api.dart';
import 'package:mobile/src/features/building_map/domain/bina_duzenleme_models.dart';
import 'package:mobile/src/features/building_map/presentation/bina_duzenleme_screen.dart';

/// Sahte editor istemcisi — bellek-ici blok/daire tutar; create/delete sonrasi
/// refresh guncel listeyi dondurur (gercek CRUD davranisini taklit eder).
class _FakeApi extends BinaDuzenlemeApi {
  _FakeApi({
    List<BuildingBlock>? blocks,
    List<EditorUnit>? units,
    this.deleteBlockError,
  })  : _blocks = [...?blocks],
        _units = [...?units],
        super(Dio());

  final List<BuildingBlock> _blocks;
  final List<EditorUnit> _units;
  final ApiException? deleteBlockError;
  int _seq = 0;

  @override
  Future<List<BuildingBlock>> listBlocks() async => List.of(_blocks);

  @override
  Future<List<EditorUnit>> listUnits() async => List.of(_units);

  @override
  Future<BuildingBlock> createBlock(BlockDraft draft) async {
    final b = BuildingBlock(id: 'b${_seq++}', ad: draft.ad, katSayisi: draft.katSayisi);
    _blocks.add(b);
    return b;
  }

  @override
  Future<BuildingBlock> updateBlock(String blockId, BlockDraft draft) async {
    final i = _blocks.indexWhere((b) => b.id == blockId);
    final updated = BuildingBlock(id: blockId, ad: draft.ad, katSayisi: draft.katSayisi);
    if (i >= 0) _blocks[i] = updated;
    return updated;
  }

  @override
  Future<void> deleteBlock(String blockId) async {
    if (deleteBlockError != null) throw deleteBlockError!;
    _blocks.removeWhere((b) => b.id == blockId);
  }

  @override
  Future<EditorUnit> createUnit(EditorUnitDraft draft) async {
    final u = EditorUnit(
      id: 'u${_seq++}',
      no: draft.no,
      blok: draft.blok,
      kat: draft.kat,
      sira: draft.sira,
    );
    _units.add(u);
    return u;
  }

  @override
  Future<EditorUnit> updateUnit(String unitId, EditorUnitDraft draft) async {
    final i = _units.indexWhere((u) => u.id == unitId);
    final updated = EditorUnit(
      id: unitId,
      no: draft.no,
      blok: draft.blok,
      kat: draft.kat,
      sira: draft.sira,
    );
    if (i >= 0) _units[i] = updated;
    return updated;
  }

  @override
  Future<void> deleteUnit(String unitId) async {
    _units.removeWhere((u) => u.id == unitId);
  }
}

Widget _app(_FakeApi api) {
  return ProviderScope(
    overrides: [binaDuzenlemeApiProvider.overrideWithValue(api)],
    child: const MaterialApp(home: BinaDuzenlemeScreen()),
  );
}

void main() {
  testWidgets('blok ekle → kutucuk onizlemede belirir (bloklu mod)',
      (tester) async {
    await tester.pumpWidget(_app(_FakeApi()));
    await tester.pumpAndSettle();

    // Bos: "+ Blok" ekleme kutucugu var, henuz "Blok A" yok.
    expect(find.text('Blok A'), findsNothing);

    await tester.tap(find.text('Blok')); // + Blok ekleme kutucugu
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'A'); // blok etiketi
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    // Blok kutucugu onizlemede belirir.
    expect(find.text('Blok A'), findsOneWidget);
  });

  testWidgets(
      'bloksuz kova: kat ekle → kattaki "+" ile daire ekle (blok=null); '
      'mod anahtari YOK, ayri "daire ekle" butonu YOK',
      (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    // Mod anahtari kaldirildi (Bloklu/Bloksuz segmenti yok).
    expect(find.widgetWithText(SegmentedButton<bool>, 'Bloklu'), findsNothing);

    // Bos site: "Bloksuz" kovasi kutucugu gorunur → icine gir.
    await tester.tap(find.text('Bloksuz'));
    await tester.pumpAndSettle();

    // Blok icinde ayri ust "Daire ekle" butonu YOK; yalniz "Kat ekle".
    expect(find.text('Daire ekle'), findsNothing);
    await tester.tap(find.text('Kat ekle'));
    await tester.pumpAndSettle();

    // Kattaki "+" hucresi daire formunu acar (son eklenen add ikonu).
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '12'); // daire no
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    // Daire hucresi belirir; blok=null olarak olusturuldu.
    expect(find.text('12'), findsOneWidget);
    expect(api._units.single.blok, isNull);
    expect(api._units.single.no, '12');
  });

  testWidgets(
      'daire olan blogu sil → 409 hata mesaji gosterilir (silinmez)',
      (tester) async {
    final api = _FakeApi(
      blocks: const [BuildingBlock(id: 'b-A', ad: 'A', unitSayisi: 1)],
      units: const [EditorUnit(id: 'u-1', no: 'A-1', blok: 'A', kat: 1, sira: 1)],
      deleteBlockError: const ApiException(
        code: 'conflict',
        message: 'Bu blogu kullanan 1 daire var; once daireleri tasiyin/silin.',
        statusCode: 409,
      ),
    );
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    // Blok kutucuguna uzun bas → yonetim sayfasi (duzenle/sil).
    await tester.longPress(find.text('Blok A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bloğu sil'));
    await tester.pumpAndSettle();

    // 409 mesaji SnackBar'da net gosterilir; blok hala listede.
    expect(find.textContaining('daire var'), findsOneWidget);
    expect(find.text('Blok A'), findsOneWidget);
  });
}
