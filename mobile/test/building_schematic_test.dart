import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/building_map/data/building_map_api.dart';
import 'package:mobile/src/features/building_map/domain/building_map_models.dart';
import 'package:mobile/src/features/building_map/presentation/building_schematic_screen.dart';
import 'package:mobile/src/features/unit_complaints/data/unit_complaint_api.dart';
import 'package:mobile/src/features/unit_complaints/domain/unit_complaint_models.dart';

/// Aga cikmayan sahte building-map istemcisi — sabit sema doner.
class _FakeMapApi extends BuildingMapApi {
  _FakeMapApi(this._map) : super(Dio());
  final BuildingMap _map;

  @override
  Future<BuildingMap> fetchMap() async => _map;
}

/// Sahte sikayet istemcisi — liste sabit; file cagrilari kaydedilir.
class _FakeComplaintApi extends UnitComplaintApi {
  _FakeComplaintApi(this._items) : super(Dio());
  final List<UnitComplaint> _items;
  final List<UnitComplaintDraft> filed = [];

  @override
  Future<List<UnitComplaint>> fetchForUnit(String unitId,
          {bool acikOnly = true}) async =>
      _items;

  @override
  Future<UnitComplaint> file(UnitComplaintDraft draft) async {
    filed.add(draft);
    return _items.isEmpty
        ? UnitComplaint.fromJson(const {})
        : _items.first;
  }
}

BuildingMapUnit _u(String no, int count, DensityRenk color,
        {String? blok, int? kat, int? sira}) =>
    BuildingMapUnit(
      unitId: 'id-$no',
      unitNo: no,
      blok: blok,
      kat: kat,
      sira: sira,
      complaintCount: count,
      color: color,
    );

BuildingMap _sampleMap() => BuildingMap(
      bloklar: [
        BuildingMapBlok(
          blok: 'A',
          katlar: [
            BuildingMapKat(kat: 1, units: [
              _u('A-1', 0, DensityRenk.yesil, blok: 'A', kat: 1, sira: 1),
              _u('A-2', 6, DensityRenk.kirmizi, blok: 'A', kat: 1, sira: 2),
            ]),
          ],
        ),
      ],
      unplaced: [_u('C-9', 3, DensityRenk.sari)],
    );

Widget _app(
  UserRole role, {
  BuildingMap? map,
  List<UnitComplaint> complaints = const [],
  _FakeComplaintApi? complaintApi,
}) {
  return ProviderScope(
    overrides: [
      buildingMapApiProvider.overrideWithValue(_FakeMapApi(map ?? _sampleMap())),
      unitComplaintApiProvider
          .overrideWithValue(complaintApi ?? _FakeComplaintApi(complaints)),
      currentUserRoleProvider.overrideWith((ref) async => role),
    ],
    child: const MaterialApp(home: BuildingSchematicScreen()),
  );
}

UnitComplaint _c(UnitComplaintKategori k) => UnitComplaint(
      id: 'c-1',
      targetUnitId: 'id-A-2',
      kategori: k,
      durum: 'acik',
      createdAt: DateTime.utc(2026, 7, 12),
    );

void main() {
  group('Şikayet Haritası — render', () {
    testWidgets('building-map verisinden renkli hucreler + legend cizilir',
        (tester) async {
      await tester.pumpWidget(_app(UserRole.resident));
      await tester.pumpAndSettle();
      // Blok + kat baslegi
      expect(find.text('Blok A'), findsOneWidget);
      expect(find.text('Kat 1'), findsOneWidget);
      // Daire hucreleri (unit_no)
      expect(find.text('A-1'), findsOneWidget);
      expect(find.text('A-2'), findsOneWidget);
      // Legend esikleri (renk kaynagi: API — istemci esik hesaplamaz)
      expect(find.text('0–2'), findsOneWidget);
      expect(find.text('3–4'), findsOneWidget);
      expect(find.text('5+'), findsOneWidget);
      // Unplaced bolumu
      expect(find.text('Haritada yerleşimi girilmemiş'), findsOneWidget);
      expect(find.text('C-9'), findsOneWidget);
    });
  });

  group('Detay + rol gorunurlugu', () {
    testWidgets('hucreye dokun -> detay: sayim + anonim sikayet listesi',
        (tester) async {
      await tester.pumpWidget(
        _app(UserRole.resident, complaints: [_c(UnitComplaintKategori.gurultu)]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('A-2'));
      await tester.pumpAndSettle();
      expect(find.text('Daire A-2'), findsOneWidget);
      expect(find.textContaining('6 açık şikayet'), findsOneWidget);
      // Anonim sikayet listesi: kategori gorunur (complainant YOK)
      expect(find.text('Gürültü'), findsOneWidget);
    });

    testWidgets('SAKIN detayda "Bu daireyi şikayet et" gorur', (tester) async {
      await tester.pumpWidget(_app(UserRole.resident));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A-1'));
      await tester.pumpAndSettle();
      expect(find.text('Bu daireyi şikayet et'), findsOneWidget);
    });

    for (final role in [UserRole.security, UserRole.admin, UserRole.yonetici]) {
      testWidgets('${role.name}: "şikayet et" butonu YOK (yalniz sakin)',
          (tester) async {
        await tester.pumpWidget(_app(role));
        await tester.pumpAndSettle();
        await tester.tap(find.text('A-1'));
        await tester.pumpAndSettle();
        expect(find.text('Bu daireyi şikayet et'), findsNothing);
      });
    }

    testWidgets('sakin sikayet formu gonderir -> api.file cagrilir',
        (tester) async {
      final capi = _FakeComplaintApi(const []);
      await tester.pumpWidget(_app(UserRole.resident, complaintApi: capi));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A-2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bu daireyi şikayet et'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Şikayeti gönder'));
      await tester.pumpAndSettle();
      expect(capi.filed.length, 1);
      expect(capi.filed.first.targetUnitId, 'id-A-2');
    });
  });
}
