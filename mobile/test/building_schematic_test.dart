import 'dart:async';

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

/// Sahte building-map istemcisi — sabit sema doner (rol-farkinda: showsDensity).
class _FakeMapApi extends BuildingMapApi {
  _FakeMapApi(this._map) : super(Dio());
  final BuildingMap _map;

  @override
  Future<BuildingMap> fetchMap() async => _map;
}

class _FakeComplaintApi extends UnitComplaintApi {
  _FakeComplaintApi(List<UnitComplaint> items, {List<UnitComplaint>? mine})
      : _items = items,
        _mine = mine ?? items,
        super(Dio());
  final List<UnitComplaint> _items;
  final List<UnitComplaint> _mine;
  final List<UnitComplaintDraft> filed = [];

  /// Gecikmeli file() icin acilinca cozulen kapi (cift-dokunus testi).
  Completer<void>? gate;

  @override
  Future<List<UnitComplaint>> fetchForUnit(String unitId,
          {bool acikOnly = true}) async =>
      _items;

  @override
  Future<List<UnitComplaint>> fetchMine() async => _mine;

  @override
  Future<UnitComplaint> file(UnitComplaintDraft draft) async {
    filed.add(draft);
    if (gate != null) await gate!.future; // in-flight tut (cift-dokunus)
    return _items.isEmpty ? UnitComplaint.fromJson(const {}) : _items.first;
  }
}

BuildingMapUnit _u(
  String no, {
  int? count,
  DensityRenk? color,
  bool benimSikayetim = false,
  int? benimAcikSayisi,
}) =>
    BuildingMapUnit(
      unitId: 'id-$no',
      unitNo: no,
      blok: 'A',
      kat: 1,
      sira: no == 'A-1' ? 1 : 2,
      complaintCount: count,
      color: color,
      benimSikayetim: benimSikayetim,
      benimAcikSayisi: benimAcikSayisi,
    );

/// showsDensity=true (yonetim): renk + sayi dolu.
BuildingMap _mgmtMap() => BuildingMap(
      showsDensity: true,
      bloklar: [
        BuildingMapBlok(blok: 'A', katlar: [
          BuildingMapKat(kat: 1, units: [
            _u('A-1', count: 0, color: DensityRenk.yesil),
            _u('A-2', count: 6, color: DensityRenk.kirmizi),
          ]),
        ]),
      ],
      unplaced: const [],
    );

/// showsDensity=false (resident/saha): yapi; sayi/renk null.
BuildingMap _structureMap() => BuildingMap(
      showsDensity: false,
      bloklar: [
        BuildingMapBlok(blok: 'A', katlar: [
          BuildingMapKat(kat: 1, units: [_u('A-1'), _u('A-2')]),
        ]),
      ],
      unplaced: const [],
    );

Widget _app(
  UserRole role, {
  required BuildingMap map,
  List<UnitComplaint> complaints = const [],
  _FakeComplaintApi? complaintApi,
}) {
  return ProviderScope(
    overrides: [
      buildingMapApiProvider.overrideWithValue(_FakeMapApi(map)),
      unitComplaintApiProvider
          .overrideWithValue(complaintApi ?? _FakeComplaintApi(complaints)),
      currentUserRoleProvider.overrideWith((ref) async => role),
    ],
    child: const MaterialApp(home: BuildingSchematicScreen()),
  );
}

UnitComplaint _c() => UnitComplaint(
      id: 'c-1',
      targetUnitId: 'id-A-2',
      kategori: UnitComplaintKategori.zararVerme,
      durum: 'acik',
      complainantUserId: 'r-9',
      complainantAd: 'Ayşe Sakin',
      createdAt: DateTime.utc(2026, 7, 12),
    );

void main() {
  group('YONETIM gorunumu (shows_density=true)', () {
    testWidgets('legend + hucre sayilari gorunur', (tester) async {
      await tester.pumpWidget(_app(UserRole.yonetici, map: _mgmtMap()));
      await tester.pumpAndSettle();
      expect(find.text('0–2'), findsOneWidget); // legend
      expect(find.text('5+'), findsOneWidget);
      expect(find.text('A-1'), findsOneWidget);
      expect(find.text('A-2'), findsOneWidget);
      // sayi hucrede gorunur (yonetim)
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('detay: sayim + sikayet listesi (sikayet eden KIMLIGI GIZLI)',
        (tester) async {
      await tester.pumpWidget(
        _app(UserRole.admin, map: _mgmtMap(), complaints: [_c()]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('A-2'));
      await tester.pumpAndSettle();
      expect(find.textContaining('6 açık şikayet'), findsOneWidget);
      expect(find.text('Zarar verme'), findsOneWidget); // yeni kategori
      // F4 gizlilik: sikayet eden kimligi yonetime bile GORUNMEZ
      expect(find.textContaining('Ayşe Sakin'), findsNothing);
      // yonetim sikayet ETMEZ -> buton yok
      expect(find.text('Bu daireyi şikayet et'), findsNothing);
    });
  });

  group('YAPI gorunumu (shows_density=false)', () {
    testWidgets('resident: sayi/renk YOK; yapi notu; hucreler var', (tester) async {
      await tester.pumpWidget(_app(UserRole.resident, map: _structureMap()));
      await tester.pumpAndSettle();
      // Legend yok (yogunluk gizli); yapi notu var
      expect(find.text('0–2'), findsNothing);
      expect(find.textContaining('yalnızca yönetime'), findsWidgets);
      expect(find.text('A-1'), findsOneWidget);
      // sayi hucrede YOK (resident yogunlugu bilemez)
      expect(find.text('6'), findsNothing);
    });

    testWidgets('resident detayda "Bu daireyi şikayet et" gorur; liste YOK',
        (tester) async {
      await tester.pumpWidget(_app(UserRole.resident, map: _structureMap()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A-1'));
      await tester.pumpAndSettle();
      expect(find.text('Bu daireyi şikayet et'), findsOneWidget);
      // yogunluk/sikayet listesi gosterilmez
      expect(find.textContaining('açık şikayet'), findsNothing);
    });

    for (final role in [UserRole.security, UserRole.tesisGorevlisi]) {
      testWidgets('${role.name}: "şikayet et" YOK + liste YOK (salt yapi)',
          (tester) async {
        await tester.pumpWidget(_app(role, map: _structureMap()));
        await tester.pumpAndSettle();
        await tester.tap(find.text('A-1'));
        await tester.pumpAndSettle();
        expect(find.text('Bu daireyi şikayet et'), findsNothing);
      });
    }

    testWidgets('sakin sikayet formu gonderir -> api.file (yeni kategori secilebilir)',
        (tester) async {
      final capi = _FakeComplaintApi(const []);
      await tester.pumpWidget(
        _app(UserRole.resident, map: _structureMap(), complaintApi: capi),
      );
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

    testWidgets('cift-dokunus KORUMASI: hizli iki dokunus -> file YALNIZ 1 kez '
        '(1 dosya = 1 kayit)', (tester) async {
      final capi = _FakeComplaintApi(const [])..gate = Completer<void>();
      await tester.pumpWidget(
        _app(UserRole.resident, map: _structureMap(), complaintApi: capi),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('A-2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bu daireyi şikayet et'));
      await tester.pumpAndSettle();
      // Ilk dokunus _submit'i baslatir (busy=true, file() kapida bekler); ikinci
      // dokunus REBUILD'DEN ONCE gelir -> _submit ust-guard'i onu reddetmeli.
      await tester.tap(find.text('Şikayeti gönder'));
      await tester.tap(find.text('Şikayeti gönder'));
      capi.gate!.complete();
      await tester.pumpAndSettle();
      expect(capi.filed.length, 1); // cift kayit YOK
    });
  });

  group('RESIDENT KENDI sikayet isareti (harita uzerinde)', () {
    // resident: A-2'ye KENDI sikayeti var (isaretli); A-1 noturr.
    BuildingMap ownMap() => BuildingMap(
          showsDensity: false,
          bloklar: [
            BuildingMapBlok(blok: 'A', katlar: [
              BuildingMapKat(kat: 1, units: [
                _u('A-1'),
                _u('A-2', benimSikayetim: true, benimAcikSayisi: 1),
              ]),
            ]),
          ],
          unplaced: const [],
        );

    UnitComplaint ownComplaint() => UnitComplaint(
          id: 'c-own',
          targetUnitId: 'id-A-2',
          kategori: UnitComplaintKategori.gurultu,
          durum: 'acik',
          createdAt: DateTime.utc(2026, 7, 12),
        );

    testWidgets('KENDI sikayet ettigi daire vurgulu (iletildi isareti); genel '
        'yogunluk YOK', (tester) async {
      await tester.pumpWidget(_app(UserRole.resident, map: ownMap()));
      await tester.pumpAndSettle();
      // Yapi gorunumu: genel sayi/renk yok.
      expect(find.text('0–2'), findsNothing);
      // KENDI sikayeti olan dairede "iletildi" isareti (check_circle).
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('KENDI isaretli daireye dokun -> kendi sikayet(ler)i (kategori + '
        'durum "Yönetime iletildi") + sikayet et butonu', (tester) async {
      await tester.pumpWidget(
        _app(UserRole.resident, map: ownMap(), complaints: [ownComplaint()]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('A-2'));
      await tester.pumpAndSettle();
      expect(find.text('Bu daire için şikayetleriniz'), findsOneWidget);
      expect(find.text('Gürültü'), findsOneWidget);
      expect(find.textContaining('Yönetime iletildi'), findsOneWidget);
      // Yine sikayet edebilir; yonetim yogunluk listesi YOK.
      expect(find.text('Bu daireyi şikayet et'), findsOneWidget);
      expect(find.textContaining('açık şikayet'), findsNothing);
    });

    testWidgets('sikayet ETMEDIGI daireye dokun -> kendi listesi YOK, yalniz '
        'sikayet et', (tester) async {
      await tester.pumpWidget(_app(UserRole.resident, map: ownMap()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A-1'));
      await tester.pumpAndSettle();
      expect(find.text('Bu daire için şikayetleriniz'), findsNothing);
      expect(find.text('Bu daireyi şikayet et'), findsOneWidget);
    });
  });
}
