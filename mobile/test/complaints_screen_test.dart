import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/complaints/data/complaint_api.dart';
import 'package:mobile/src/features/complaints/domain/complaint_models.dart';
import 'package:mobile/src/features/complaints/presentation/complaints_screen.dart';
import 'package:mobile/src/features/tasks/data/task_category_api.dart';
import 'package:mobile/src/features/tasks/domain/task_category_models.dart';

/// Aga cikmayan sahte istemci — liste sabit doner, kategori bos (widget
/// testleri ag beklemez). ComplaintApi Task 10'da ikinci pozisyonel
/// bagimlilik (TaskCategoryApi) kazandi; super cagrisi buna uyar.
class _FakeComplaintApi extends ComplaintApi {
  _FakeComplaintApi(this._items) : super(Dio(), TaskCategoryApi(Dio()));

  final List<Complaint> _items;

  @override
  Future<List<Complaint>> fetchAll({TalepDurum? durum}) async => _items;

  @override
  Future<List<TaskCategory>> listTaskCategories() async => const [];
}

Complaint _c({
  String id = 'c-1',
  String baslik = 'Asansor arizali',
  String mesaj = 'A blok asansoru durdu.',
  TalepDurum durum = TalepDurum.acik,
  String? kategoriAd,
  List<ComplaintHistory> gecmis = const [],
}) =>
    Complaint(
      id: id,
      acanUserId: 'u-1',
      acanAd: 'Acme Sakin',
      baslik: baslik,
      mesaj: mesaj,
      kategoriAd: kategoriAd,
      durum: durum,
      fotograflar: const [],
      gecmis: gecmis,
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
  group('"Yeni talep" FAB rol gorunurlugu (auth.md §4 kesin kurali)', () {
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
      testWidgets('${role.name}: FAB YOK (yonetim talep acamaz)',
          (tester) async {
        await tester.pumpWidget(_app(role, items: [_c()]));
        await tester.pumpAndSettle();
        expect(find.text('Yeni talep'), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
      });
    }
  });

  group('durum sekmeleri (Açık / İş Emri / Çözülen / Reddedilen)', () {
    final items = [
      _c(),
      _c(id: 'c-2', baslik: 'Is emri talebi', durum: TalepDurum.isEmri),
      _c(id: 'c-3', baslik: 'Cozulen talep', durum: TalepDurum.cozuldu),
      _c(id: 'c-4', baslik: 'Reddedilen talep', durum: TalepDurum.reddedildi),
    ];

    testWidgets('sayaclar dogru; her kayit yalniz KENDI sekmesinde',
        (tester) async {
      await tester.pumpWidget(_app(UserRole.yonetici, items: items));
      await tester.pumpAndSettle();

      expect(find.text('Açık (1)'), findsOneWidget);
      expect(find.text('İş Emri (1)'), findsOneWidget);
      expect(find.text('Çözülen (1)'), findsOneWidget);
      expect(find.text('Reddedilen (1)'), findsOneWidget);

      // Varsayilan sekme Acik.
      expect(find.text('Asansor arizali'), findsOneWidget);
      expect(find.text('Is emri talebi'), findsNothing);

      await tester.tap(find.text('İş Emri (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Is emri talebi'), findsOneWidget);
      expect(find.text('Asansor arizali'), findsNothing);

      await tester.tap(find.text('Reddedilen (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Reddedilen talep'), findsOneWidget);
    });

    testWidgets('bos sekme anlamli mesaj gosterir', (tester) async {
      await tester.pumpWidget(_app(UserRole.yonetici, items: [_c()]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İş Emri (0)'));
      await tester.pumpAndSettle();
      expect(find.text('İş emrine dönüşen talep yok.'), findsOneWidget);
    });
  });

  group('detay + yonetici eylem cubugu (Task 13)', () {
    testWidgets('yonetici + acik talep: uc eylem GORUNUR', (tester) async {
      await tester.pumpWidget(_app(UserRole.yonetici, items: [_c()]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asansor arizali'));
      await tester.pumpAndSettle();

      expect(find.text('İş Emrine Dönüştür'), findsOneWidget);
      expect(find.text('Çöz'), findsOneWidget);
      expect(find.text('Reddet'), findsOneWidget);
    });

    testWidgets('acan rol (security) detayda eylem cubugu GORMEZ',
        (tester) async {
      await tester.pumpWidget(_app(UserRole.security, items: [_c()]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asansor arizali'));
      await tester.pumpAndSettle();

      expect(find.text('İş Emrine Dönüştür'), findsNothing);
      expect(find.text('Çöz'), findsNothing);
      expect(find.text('Reddet'), findsNothing);
    });

    testWidgets('yonetici + NON-acik (cozuldu) talep: eylem cubugu GIZLI',
        (tester) async {
      await tester.pumpWidget(_app(
        UserRole.yonetici,
        items: [_c(durum: TalepDurum.cozuldu)],
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Çözülen (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asansor arizali'));
      await tester.pumpAndSettle();

      expect(find.text('İş Emrine Dönüştür'), findsNothing);
      expect(find.text('Reddet'), findsNothing);
    });

    testWidgets('reddet sheet acilir; sebep bosken buton PASIF, dolunca AKTIF',
        (tester) async {
      await tester.pumpWidget(_app(UserRole.yonetici, items: [_c()]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asansor arizali'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reddet'));
      await tester.pumpAndSettle();

      expect(find.text('Talebi reddet'), findsOneWidget);
      // Sheet acikken submit butonu (ikinci "Reddet") sebep bosken pasif.
      final submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Reddet'),
      );
      expect(submit.onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Mükerrer talep.');
      await tester.pumpAndSettle();
      final submit2 = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Reddet'),
      );
      expect(submit2.onPressed, isNotNull);
    });

    testWidgets('coz sheet acilir; cozum notu opsiyonel (buton aktif)',
        (tester) async {
      await tester.pumpWidget(_app(UserRole.yonetici, items: [_c()]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asansor arizali'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Çöz'));
      await tester.pumpAndSettle();

      expect(find.text('Talebi çöz'), findsOneWidget);
      // Notsuz bile "Çöz" submit butonu aktif.
      final submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Çöz'),
      );
      expect(submit.onPressed, isNotNull);
    });
  });

  group('detay icerigi + push tiklamasi', () {
    testWidgets('kategorili talep listede ve detayda etiketini gosterir',
        (tester) async {
      await tester.pumpWidget(_app(
        UserRole.resident,
        items: [_c(kategoriAd: 'Arıza')],
      ));
      await tester.pumpAndSettle();
      expect(find.text('Arıza'), findsOneWidget); // kart

      await tester.tap(find.text('Asansor arizali'));
      await tester.pumpAndSettle();
      expect(find.text('Arıza'), findsNWidgets(2)); // + detay
    });

    testWidgets('durum gecmisi (timeline) detayda gorunur', (tester) async {
      await tester.pumpWidget(_app(
        UserRole.yonetici,
        items: [
          _c(gecmis: [
            ComplaintHistory(
              durum: TalepDurum.acik,
              actorRole: 'resident',
              createdAt: DateTime.utc(2026, 7, 9, 10),
            ),
          ]),
        ],
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asansor arizali'));
      await tester.pumpAndSettle();
      expect(find.text('DURUM GEÇMİŞİ'), findsOneWidget);
    });

    testWidgets('initialComplaintId ile ilgili talep detayi OTOMATIK acilir',
        (tester) async {
      await tester.pumpWidget(_app(
        UserRole.resident,
        items: [_c(mesaj: 'A blok asansoru durdu.')],
        initialComplaintId: 'c-1',
      ));
      await tester.pumpAndSettle();
      // Detay sheet acildi: tam mesaj gorunur (kart onizlemesi de ayni metni
      // tasir; sheet + kart = 2 bulgu).
      expect(find.text('A blok asansoru durdu.'), findsNWidgets(2));
    });

    testWidgets('kayit listede yoksa sessizce listede kalinir (cokme yok)',
        (tester) async {
      await tester.pumpWidget(_app(
        UserRole.resident,
        items: [_c()],
        initialComplaintId: 'olmayan-id',
      ));
      await tester.pumpAndSettle();
      expect(find.text('Asansor arizali'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
