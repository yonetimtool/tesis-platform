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
  ComplaintKategori? kategori,
}) =>
    Complaint(
      id: 'c-1',
      baslik: 'Asansor arizali',
      mesaj: 'A blok asansoru durdu.',
      durum: durum,
      kategori: kategori,
      acanUserId: 'u-1',
      acanAd: 'Acme Sakin',
      yoneticiYaniti: yanit,
      yanitZamani: yanit == null ? null : DateTime.utc(2026, 7, 9, 11),
      createdAt: DateTime.utc(2026, 7, 9, 10),
      updatedAt: DateTime.utc(2026, 7, 9, 10),
    );

Widget _app(
  UserRole role, {
  List<Complaint> items = const [],
  String? initialComplaintId,
}) =>
    ProviderScope(
      overrides: [
        complaintApiProvider.overrideWithValue(_FakeComplaintApi(items)),
        currentUserRoleProvider.overrideWith((ref) async => role),
      ],
      child: MaterialApp(
        home: ComplaintsScreen(initialComplaintId: initialComplaintId),
      ),
    );

void main() {
  group('"Yeni talep" butonu rol gorunurlugu (auth.md §4 kesin kurali)', () {
    for (final role in [
      UserRole.security,
      UserRole.tesisGorevlisi,
      UserRole.resident,
    ]) {
      testWidgets('${role.name}: FAB GORUNUR (acan rol)', (tester) async {
        await tester.pumpWidget(_app(role, items: [_c()]));
        await tester.pumpAndSettle();
        expect(find.text('Yeni talep'), findsOneWidget);
      });
    }

    for (final role in [UserRole.admin, UserRole.yonetici]) {
      testWidgets('${role.name}: FAB YOK (yonetim acamaz, yalniz yanitlar)',
          (tester) async {
        await tester.pumpWidget(_app(role, items: [_c()]));
        await tester.pumpAndSettle();
        expect(find.text('Yeni talep'), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
      });
    }

    testWidgets('acan rol (security) detayda yanit formu GORMEZ',
        (tester) async {
      await tester.pumpWidget(_app(UserRole.security, items: [_c()]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asansor arizali'));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<ComplaintDurum>), findsNothing);
      expect(find.text('Yaniti kaydet'), findsNothing);
    });
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
      // Cozuldu kayit "Cozulenler" sekmesinde.
      await tester.tap(find.text('Cozulenler (1)'));
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

  group('push tiklamasi (initialComplaintId)', () {
    testWidgets('liste yuklenince ilgili talep detayi OTOMATIK acilir',
        (tester) async {
      await tester.pumpWidget(_app(
        UserRole.resident,
        items: [_c(yanit: 'Servis cagrildi.')],
        initialComplaintId: 'c-1',
      ));
      await tester.pumpAndSettle();
      // Detay sheet acildi: yanit metni TAM haliyle gorunur (kart onizlemesi
      // "Yonetim yaniti: ..." onekiyle tek satirdir — bu bulgu sheet'e ozgu).
      expect(find.text('Servis cagrildi.'), findsOneWidget);
      expect(find.textContaining('Yonetim yaniti ·'), findsOneWidget);
    });

    testWidgets('kayit listede yoksa sessizce listede kalinir (cokme yok)',
        (tester) async {
      await tester.pumpWidget(_app(
        UserRole.resident,
        items: [_c()],
        initialComplaintId: 'olmayan-id',
      ));
      await tester.pumpAndSettle();
      expect(find.text('Asansor arizali'), findsOneWidget); // liste ekrani
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('durum rozeti dogru etiketle cizilir (Inceleniyor sekmesinde)',
      (tester) async {
    await tester.pumpWidget(_app(
      UserRole.yonetici,
      items: [_c(durum: ComplaintDurum.inceleniyor)],
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inceleniyor (1)'));
    await tester.pumpAndSettle();
    // Rozet metni tam 'Inceleniyor' (sekme etiketi sayac tasir — karismaz).
    expect(find.text('Inceleniyor'), findsOneWidget);
  });

  group('Acik / Inceleniyor / Cozulenler sekmeleri', () {
    final items = [
      _c(),
      Complaint(
        id: 'c-2',
        baslik: 'Incelenen talep',
        mesaj: 'm',
        durum: ComplaintDurum.inceleniyor,
        acanUserId: 'u-1',
        createdAt: DateTime.utc(2026, 7, 8, 12),
        updatedAt: DateTime.utc(2026, 7, 8, 12),
      ),
      Complaint(
        id: 'c-3',
        baslik: 'Cozulen talep',
        mesaj: 'm',
        durum: ComplaintDurum.cozuldu,
        acanUserId: 'u-1',
        yoneticiYaniti: 'Tamam.',
        createdAt: DateTime.utc(2026, 7, 8),
        updatedAt: DateTime.utc(2026, 7, 9),
      ),
    ];

    testWidgets('her durum yalniz KENDI sekmesinde gorunur', (tester) async {
      await tester.pumpWidget(_app(UserRole.yonetici, items: items));
      await tester.pumpAndSettle();

      // Sekme sayaclari dogru
      expect(find.text('Acik (1)'), findsOneWidget);
      expect(find.text('Inceleniyor (1)'), findsOneWidget);
      expect(find.text('Cozulenler (1)'), findsOneWidget);
      // Varsayilan sekme Acik: yalniz acik kayit
      expect(find.text('Asansor arizali'), findsOneWidget);
      expect(find.text('Incelenen talep'), findsNothing);
      expect(find.text('Cozulen talep'), findsNothing);

      await tester.tap(find.text('Inceleniyor (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Incelenen talep'), findsOneWidget);
      expect(find.text('Asansor arizali'), findsNothing);

      await tester.tap(find.text('Cozulenler (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Cozulen talep'), findsOneWidget);
      expect(find.text('Incelenen talep'), findsNothing);
    });

    testWidgets('bos sekmeler anlamli mesaj gosterir', (tester) async {
      await tester.pumpWidget(_app(UserRole.yonetici, items: [_c()]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inceleniyor (0)'));
      await tester.pumpAndSettle();
      expect(find.text('Incelemede talep yok.'), findsOneWidget);
      await tester.tap(find.text('Cozulenler (0)'));
      await tester.pumpAndSettle();
      expect(find.text('Henuz cozulen talep yok.'), findsOneWidget);
    });
  });

  group('kategori (Wave 1 #3)', () {
    testWidgets('kategorili talep listede ve detayda etiketini gosterir',
        (tester) async {
      await tester.pumpWidget(_app(
        UserRole.resident,
        items: [_c(kategori: ComplaintKategori.gurultu)],
      ));
      await tester.pumpAndSettle();
      expect(find.text('Gurultu kirliligi'), findsOneWidget); // kart

      await tester.tap(find.text('Asansor arizali'));
      await tester.pumpAndSettle();
      expect(find.text('Gurultu kirliligi'), findsNWidgets(2)); // + detay
    });

    testWidgets('kategorisiz eski talep etiketsiz calisir', (tester) async {
      await tester.pumpWidget(_app(UserRole.resident, items: [_c()]));
      await tester.pumpAndSettle();
      expect(find.text('Gurultu kirliligi'), findsNothing);
      expect(find.text('Goruntu kirliligi'), findsNothing);
      expect(find.text('Asansor arizali'), findsOneWidget);
    });

    testWidgets('yeni talep formunda kategori secenekleri sunulur',
        (tester) async {
      await tester.pumpWidget(_app(UserRole.resident, items: [_c()]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yeni talep'));
      await tester.pumpAndSettle();

      expect(find.text('Kategori (opsiyonel)'), findsOneWidget);
      expect(find.text('Gurultu kirliligi'), findsOneWidget);
      expect(find.text('Goruntu kirliligi'), findsOneWidget);
      expect(find.text('Diger'), findsOneWidget);
      // foto butonu yeni adiyla
      expect(find.text('Kamera'), findsOneWidget);
    });
  });
}
