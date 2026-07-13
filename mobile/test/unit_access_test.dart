import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/unit_access/data/unit_access_api.dart';
import 'package:mobile/src/features/unit_access/domain/unit_access_models.dart';
import 'package:mobile/src/features/unit_access/presentation/unit_access_screen.dart';

/// Aga cikmayan sahte istemci — liste sabit doner; karar/talep kaydedilir.
class _FakeUnitAccessApi extends UnitAccessApi {
  _FakeUnitAccessApi(this._items) : super(Dio());

  final List<UnitAccessRequest> _items;
  final List<(String, bool)> decided = [];
  final List<String> requested = [];
  int bulkCalls = 0;
  BulkAccessRequestResult bulkResult =
      const BulkAccessRequestResult(created: 2, skipped: 0, items: []);
  List<GrantedUnit> granted = const [];

  @override
  Future<List<UnitAccessRequest>> fetchAll() async => _items;

  @override
  Future<UnitAccessRequest> decide(String id, {required bool onayla}) async {
    decided.add((id, onayla));
    return _items.first;
  }

  @override
  Future<UnitAccessRequest> createRequest(String unitNo) async {
    requested.add(unitNo);
    return _items.isEmpty ? _r() : _items.first;
  }

  @override
  Future<BulkAccessRequestResult> createBulkRequest() async {
    bulkCalls++;
    return bulkResult;
  }

  @override
  Future<List<GrantedUnit>> fetchGrantedUnits() async => granted;
}

UnitAccessRequest _r({
  String id = 'q-1',
  AccessRequestDurum durum = AccessRequestDurum.bekliyor,
  bool used = false,
}) =>
    UnitAccessRequest(
      id: id,
      unitId: 'u-1',
      unitNo: 'A-12',
      grantedToYoneticiUserId: 'y-1',
      yoneticiAd: 'Acme Yonetici',
      durum: durum,
      used: used,
      requestedAt: DateTime.utc(2026, 7, 12, 9),
    );

(_FakeUnitAccessApi, Widget) _app(
  UserRole role, {
  List<UnitAccessRequest> items = const [],
}) {
  final api = _FakeUnitAccessApi(items);
  return (
    api,
    ProviderScope(
      overrides: [
        unitAccessApiProvider.overrideWithValue(api),
        currentUserRoleProvider.overrideWith((ref) async => role),
      ],
      child: const MaterialApp(home: UnitAccessScreen()),
    ),
  );
}

void main() {
  group('UnitAccessRequest domain', () {
    test('fromJson + kullanilabilir (onaylandi & !used)', () {
      final r = UnitAccessRequest.fromJson(const {
        'id': 'q-1',
        'unit_id': 'u-1',
        'unit_no': 'A-12',
        'granted_to_yonetici_user_id': 'y-1',
        'yonetici_ad': 'Acme Yonetici',
        'durum': 'onaylandi',
        'used': false,
        'requested_at': '2026-07-12T09:00:00Z',
      });
      expect(r.unitNo, 'A-12');
      expect(r.durum, AccessRequestDurum.onaylandi);
      expect(r.kullanilabilir, isTrue); // onayli + kullanilmamis
    });

    test('kullanilmis onay artik kullanilabilir DEGIL (one-shot)', () {
      expect(_r(durum: AccessRequestDurum.onaylandi, used: true).kullanilabilir,
          isFalse);
      expect(_r(durum: AccessRequestDurum.bekliyor).kullanilabilir, isFalse);
    });

    test('bilinmeyen durum unknown (eski surum COKMEZ)', () {
      expect(AccessRequestDurum.fromWire('bok'), AccessRequestDurum.unknown);
    });
  });

  group('UnitAccessScreen rol-uyarlamali', () {
    testWidgets('admin/yonetici: "Yeni istek" FAB gorunur (talep acabilir)',
        (tester) async {
      final (_, app) = _app(UserRole.yonetici, items: [_r()]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Yeni istek'), findsOneWidget);
      // yonetim gelen talebi ONAYLAYAMAZ (karar sakinde) — buton yok
      expect(find.text('Onayla'), findsNothing);
    });

    testWidgets('resident: gelen bekleyen talepte Onayla/Reddet gorunur; '
        'Onayla api.decide cagirir', (tester) async {
      final (api, app) = _app(UserRole.resident, items: [_r()]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      // resident talep ACAMAZ (FAB yok)
      expect(find.text('Yeni istek'), findsNothing);
      expect(find.text('Onayla'), findsOneWidget);
      expect(find.text('Reddet'), findsOneWidget);
      await tester.tap(find.text('Onayla'));
      await tester.pumpAndSettle();
      expect(api.decided, [('q-1', true)]);
    });

    testWidgets('admin: onayli+kullanilmamis izinde "Ziyaretçiler"/"Kargolar" '
        'goruntuleme butonlari gorunur', (tester) async {
      final (_, app) = _app(
        UserRole.admin,
        items: [_r(durum: AccessRequestDurum.onaylandi)],
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Ziyaretçiler'), findsOneWidget);
      expect(find.text('Kargolar'), findsOneWidget);
    });

    testWidgets('admin: kullanilmis izinde "kullanıldı" durumu gosterilir '
        '(tek seferlik)', (tester) async {
      final (_, app) = _app(
        UserRole.admin,
        items: [_r(durum: AccessRequestDurum.onaylandi, used: true)],
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.textContaining('İzin kullanıldı'), findsOneWidget);
      expect(find.text('Ziyaretçiler'), findsNothing);
    });
  });

  group('Toplu izin (bulk) — CHANGE 2', () {
    testWidgets('yonetici: "Tüm dairelere izin iste" -> onay -> api.bulk cagirir',
        (tester) async {
      final (api, app) = _app(UserRole.yonetici, items: [_r()]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      // AppBar aksiyonu (tooltip ile bulunur)
      await tester.tap(find.byTooltip('Tüm dairelere izin iste'));
      await tester.pumpAndSettle();
      // Onay dialogu -> Gönder
      expect(find.text('Tüm dairelere izin iste'), findsWidgets);
      await tester.tap(find.text('Gönder'));
      await tester.pumpAndSettle();
      expect(api.bulkCalls, 1);
    });

    testWidgets('resident: bulk aksiyonu YOK (talep edemez)', (tester) async {
      final (_, app) = _app(UserRole.resident, items: [_r()]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Tüm dairelere izin iste'), findsNothing);
    });

    testWidgets('granted-units karti: gorunur daireler listelenir', (tester) async {
      final api = _FakeUnitAccessApi([_r()]);
      api.granted = const [
        GrantedUnit(requestId: 'q-9', unitId: 'u-9', unitNo: 'B-2'),
      ];
      final app = ProviderScope(
        overrides: [
          unitAccessApiProvider.overrideWithValue(api),
          currentUserRoleProvider.overrideWith((ref) async => UserRole.yonetici),
        ],
        child: const MaterialApp(home: UnitAccessScreen()),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.textContaining('Görüntülenebilir daireler'), findsOneWidget);
      expect(find.text('B-2'), findsOneWidget);
    });
  });
}
