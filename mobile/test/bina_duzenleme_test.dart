import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
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
    final b = BuildingBlock(id: 'b${_seq++}', ad: draft.ad);
    _blocks.add(b);
    return b;
  }

  @override
  Future<BuildingBlock> updateBlock(String blockId, BlockDraft draft) async {
    final i = _blocks.indexWhere((b) => b.id == blockId);
    final updated = BuildingBlock(id: blockId, ad: draft.ad);
    if (i >= 0) _blocks[i] = updated;
    return updated;
  }

  @override
  Future<void> deleteBlock(String blockId, {bool cascade = false}) async {
    if (deleteBlockError != null) throw deleteBlockError!;
    final idx = _blocks.indexWhere((b) => b.id == blockId);
    final ad = idx >= 0 ? _blocks[idx].ad : null;
    // Backend DB cascade aynasi: cascade=true ise blogun daireleri de gider.
    if (cascade && ad != null) _units.removeWhere((u) => u.blok == ad);
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

Widget _app(_FakeApi api, {UserRole role = UserRole.yonetici}) {
  return ProviderScope(
    overrides: [
      binaDuzenlemeApiProvider.overrideWithValue(api),
      currentUserRoleProvider.overrideWith((ref) async => role),
    ],
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
      '"Blok atanmamış" kova SALT-GORUNTULEME: mevcut bloksuz daire gorunur, '
      'ekleme kontrolleri (Kat ekle / Toplu / +) YOK',
      (tester) async {
    // Canli-site kurali: yeni daire bir bloga baglanir. Mevcut bloksuz
    // daireler yalniz goruntulenir/silinir; buradan YENI daire eklenemez.
    final api = _FakeApi(
      units: const [EditorUnit(id: 'u-0', no: '7', blok: null, kat: 1, sira: 1)],
    );
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    // Mod anahtari yok (Bloklu/Bloksuz segmenti hic yok).
    expect(find.widgetWithText(SegmentedButton<bool>, 'Bloklu'), findsNothing);

    // Mevcut bloksuz daire oldugundan "Blok atanmamış" kovasi gorunur → gir.
    await tester.tap(find.text('Blok atanmamış'));
    await tester.pumpAndSettle();

    // Mevcut daire goruntulenir...
    expect(find.text('7'), findsOneWidget);
    // ...ama HICBIR ekleme kontrolu yok (Kat ekle / Toplu daire ekle / "+").
    expect(find.text('Kat ekle'), findsNothing);
    expect(find.text('Toplu daire ekle'), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('bos site: "Blok atanmamış" kovasi gorunmez (yalniz + Blok ekle)',
      (tester) async {
    await tester.pumpWidget(_app(_FakeApi()));
    await tester.pumpAndSettle();
    expect(find.text('Blok atanmamış'), findsNothing);
    expect(find.text('Blok'), findsOneWidget); // yalniz "+ Blok ekle" kutucugu
  });

  testWidgets(
      'daire olan blogu sil → yazili onay dialogu; ad yazilinca cascade siler',
      (tester) async {
    final api = _FakeApi(
      blocks: const [BuildingBlock(id: 'b-A', ad: 'A', unitSayisi: 1)],
      units: const [EditorUnit(id: 'u-1', no: 'A-1', blok: 'A', kat: 1, sira: 1)],
    );
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    // Blok kutucuguna uzun bas → yonetim sayfasi (duzenle/sil).
    await tester.longPress(find.text('Blok A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bloğu sil'));
    await tester.pumpAndSettle();

    // Yazili onay dialogu; "Sil (1 daire)" once PASIF (ad yazilmadan).
    final silBtn = find.widgetWithText(FilledButton, 'Sil (1 daire)');
    expect(silBtn, findsOneWidget);
    expect(tester.widget<FilledButton>(silBtn).onPressed, isNull);

    // Blok adini AYNEN yaz → buton aktiflesir → sil (cascade).
    await tester.enterText(find.byType(TextField).last, 'A');
    await tester.pump();
    expect(tester.widget<FilledButton>(silBtn).onPressed, isNotNull);
    await tester.tap(silBtn);
    await tester.pumpAndSettle();

    // Blok (ve daireleri) silindi → listede yok.
    expect(find.text('Blok A'), findsNothing);
  });

  // ------------------------- SALT-OKUMA (saha rolleri) ---------------------- #
  for (final role in [UserRole.security, UserRole.tesisGorevlisi]) {
    testWidgets(
        '${role.name}: SALT-OKUMA — yapiyi gorur, TUM duzenleme eylemleri yok',
        (tester) async {
      final api = _FakeApi(
        blocks: const [BuildingBlock(id: 'b-A', ad: 'A', unitSayisi: 1)],
        units: const [EditorUnit(id: 'u-1', no: 'A-1', blok: 'A', kat: 1, sira: 1)],
      );
      await tester.pumpWidget(_app(api, role: role));
      await tester.pumpAndSettle();

      // Baslik salt-okuma modunda "Bina Yapisi" (AppBar buyuk harf).
      expect(find.text('BİNA YAPISI'), findsOneWidget);
      // Yapi gorunur (blok kutucugu), ama "+ Blok" ekleme kutusu YOK.
      expect(find.text('Blok A'), findsOneWidget);
      expect(find.text('Blok'), findsNothing); // ekleme kutucugu gizli

      // Blok kutucuguna uzun bas → yonetim menusu (duzenle/sil) ACILMAZ.
      // (Salt-okumada tile'in onLongPress'i yok; uzun bas onTap'i tetikler,
      // yani bloga GIRER — ayri bir tap'a gerek yok.)
      await tester.longPress(find.text('Blok A'));
      await tester.pumpAndSettle();
      expect(find.text('Bloğu sil'), findsNothing);

      // Artik blok icindeyiz: kat plani gorunur ama "Kat ekle" ve "+" daire
      // ekle hucresi YOK.
      expect(find.text('A-1'), findsOneWidget); // daire yapisi gorunur
      expect(find.text('Kat ekle'), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing); // "+" daire ekle hucresi yok

      // Daireye dokunmak duzenleme formu ACMAZ.
      await tester.tap(find.text('A-1'));
      await tester.pumpAndSettle();
      expect(find.text('Kaydet'), findsNothing);
      expect(find.text('Sil'), findsNothing);
    });
  }
}
