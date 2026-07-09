import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/complaints/data/complaint_api.dart';
import 'package:mobile/src/features/complaints/domain/complaint_models.dart';
import 'package:mobile/src/features/complaints/presentation/complaints_screen.dart';

/// Aga cikmayan sahte istemci — liste sabit doner (widget testi).
class _FakeComplaintApi extends ComplaintApi {
  _FakeComplaintApi(this._items) : super(Dio());

  final List<Complaint> _items;

  @override
  Future<List<Complaint>> fetchAll() async => _items;
}

Complaint _c({
  ComplaintDurum durum = ComplaintDurum.acik,
  String? yanit,
}) =>
    Complaint(
      id: 'c-1',
      baslik: 'Asansor arizali',
      mesaj: 'A blok asansoru durdu.',
      durum: durum,
      acanUserId: 'u-1',
      acanAd: 'Acme Sakin',
      yoneticiYaniti: yanit,
      yanitZamani: yanit == null ? null : DateTime.utc(2026, 7, 9, 11),
      createdAt: DateTime.utc(2026, 7, 9, 10),
      updatedAt: DateTime.utc(2026, 7, 9, 10),
    );

Widget _app(UserRole role, {List<Complaint> items = const []}) =>
    ProviderScope(
      overrides: [
        complaintApiProvider.overrideWithValue(_FakeComplaintApi(items)),
        currentUserRoleProvider.overrideWith((ref) async => role),
      ],
      child: const MaterialApp(home: ComplaintsScreen()),
    );

void main() {
  group('"Yeni talep" butonu rol gorunurlugu (auth.md §4 UX aynasi)', () {
    testWidgets('resident: FAB GORUNUR', (tester) async {
      await tester.pumpWidget(_app(UserRole.resident, items: [_c()]));
      await tester.pumpAndSettle();
      expect(find.text('Yeni talep'), findsOneWidget);
    });

    for (final role in [UserRole.admin, UserRole.yonetici]) {
      testWidgets('${role.name}: FAB YOK (talep acma sakine ait)',
          (tester) async {
        await tester.pumpWidget(_app(role, items: [_c()]));
        await tester.pumpAndSettle();
        expect(find.text('Yeni talep'), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
      });
    }
  });

  group('detay + yanit formu', () {
    testWidgets('yonetici karta dokununca durum secimi + yanit alani gorur',
        (tester) async {
      await tester.pumpWidget(_app(UserRole.yonetici, items: [_c()]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asansor arizali'));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<ComplaintDurum>), findsOneWidget);
      expect(find.text('Yonetim yaniti'), findsOneWidget);
      expect(find.text('Yaniti kaydet'), findsOneWidget);
    });

    testWidgets('resident detayda yanit formu GORMEZ; mevcut yaniti okur',
        (tester) async {
      await tester.pumpWidget(_app(
        UserRole.resident,
        items: [_c(durum: ComplaintDurum.cozuldu, yanit: 'Servis cagrildi.')],
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asansor arizali'));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<ComplaintDurum>), findsNothing);
      expect(find.text('Yaniti kaydet'), findsNothing);
      expect(find.textContaining('Servis cagrildi.'), findsWidgets);
    });

    testWidgets('resident yanitsiz talepte "yanit bekleniyor" gorur',
        (tester) async {
      await tester.pumpWidget(_app(UserRole.resident, items: [_c()]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asansor arizali'));
      await tester.pumpAndSettle();
      expect(find.text('Yonetim yaniti bekleniyor.'), findsOneWidget);
    });
  });

  testWidgets('resident formu acar: baslik/mesaj + opsiyonel gorsel alani',
      (tester) async {
    await tester.pumpWidget(_app(UserRole.resident));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeni talep'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni sikayet / oneri'), findsOneWidget);
    expect(find.text('Baslik'), findsOneWidget);
    expect(find.text('Mesajiniz'), findsOneWidget);
    expect(find.text('Gorsel (opsiyonel)'), findsOneWidget);
    // foto'suz da gonderilebilir — buton aktif
    expect(find.text('Gonder'), findsOneWidget);
  });

  testWidgets('durum rozeti dogru etiketle cizilir', (tester) async {
    await tester.pumpWidget(_app(
      UserRole.yonetici,
      items: [_c(durum: ComplaintDurum.inceleniyor)],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Inceleniyor'), findsOneWidget);
  });
}
