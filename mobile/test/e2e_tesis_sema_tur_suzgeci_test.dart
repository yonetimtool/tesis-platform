/// (E2E 2026-09) TESIS-17 — sikayet haritasinda TUR SECICISI (mobil).
///
/// OLCULEN KUSUR: harita tum kategorileri tek sayida topluyordu; yonetici
/// "gurultu mu, goruntu kirliligi mi" sorusunu ancak daireye tek tek
/// girerek yanitlayabiliyordu. Web `/schematic` ile AYNI davranis:
/// secim sunucuya `?kategori=` olarak gider, bos = tum turler.
library;

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

import 'helpers/l10n_test_app.dart';

class _KayitliApi extends BuildingMapApi {
  _KayitliApi(this._map) : super(Dio());
  final BuildingMap _map;
  final List<String?> istenen = [];

  @override
  Future<BuildingMap> fetchMap({String? kategori}) async {
    istenen.add(kategori);
    return _map;
  }
}

BuildingMap _harita({required bool yogunluk}) => BuildingMap(
      showsDensity: yogunluk,
      bloklar: [
        BuildingMapBlok(blok: 'A', katlar: [
          BuildingMapKat(kat: 1, units: [
            BuildingMapUnit(
              unitId: 'u1',
              unitNo: 'A-1',
              blok: 'A',
              kat: 1,
              sira: 1,
              complaintCount: yogunluk ? 1 : null,
              color: yogunluk ? DensityRenk.sari : null,
            ),
          ]),
        ]),
      ],
      unplaced: const [],
    );

Widget _app(UserRole rol, _KayitliApi api) => ProviderScope(
      overrides: [
        buildingMapApiProvider.overrideWithValue(api),
        // Kuyruk rozeti (yonetim) istek atar; bu testin konusu degil.
        unitComplaintApiProvider.overrideWithValue(UnitComplaintApi(Dio())),
        currentUserRoleProvider.overrideWith((ref) async => rol),
      ],
      child: l10nApp(const BuildingSchematicScreen()),
    );

void main() {
  testWidgets('yonetim: tur secilince harita o turle yeniden istenir',
      (tester) async {
    final api = _KayitliApi(_harita(yogunluk: true));
    await tester.pumpWidget(_app(UserRole.yonetici, api));
    await tester.pumpAndSettle();
    expect(api.istenen, [null]);

    await tester.tap(find.byKey(const Key('sema-tur-suzgeci')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gürültü').last);
    await tester.pumpAndSettle();

    expect(api.istenen.last, 'gurultu');
  });

  testWidgets('yapi gorunumunde (sakin/saha) secici CIZILMEZ', (tester) async {
    final api = _KayitliApi(_harita(yogunluk: false));
    await tester.pumpWidget(_app(UserRole.security, api));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sema-tur-suzgeci')), findsNothing);
  });
}
