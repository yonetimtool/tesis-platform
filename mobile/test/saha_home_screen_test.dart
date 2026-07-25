import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/cameras/data/cameras_api.dart';
import 'package:mobile/src/features/cameras/domain/camera_models.dart';
import 'package:mobile/src/features/home/data/home_api.dart';
import 'package:mobile/src/features/home/domain/son_hareketler.dart';
import 'package:mobile/src/features/home/presentation/saha_home_screen.dart';
import 'package:mobile/src/features/home/presentation/widgets/home_states.dart';
import 'package:mobile/src/features/kargo/data/kargo_api.dart';
import 'package:mobile/src/features/kargo/domain/kargo_models.dart';
import 'package:mobile/src/features/notifications/data/notifications_controller.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/scan/data/scan_outbox.dart';
import 'package:mobile/src/features/scan/domain/outbox_entry.dart';
import 'package:mobile/src/features/shifts/data/shifts_api.dart';
import 'package:mobile/src/features/shifts/domain/shift_models.dart';
import 'package:mobile/src/features/tenant/data/tenant_api.dart';
import 'package:mobile/src/features/tenant/domain/tenant_models.dart';
import 'package:mobile/src/features/visitors/data/visitor_api.dart';
import 'package:mobile/src/features/visitors/domain/visitor_models.dart';
import 'package:mobile/src/features/weather/data/weather_api.dart';

/// Depoya dokunmayan sahte kuyruk (path_provider yok) — bekleyen sayisi
/// kadar 'bekliyor' kaydi tasir.
class _FakeOutbox extends ScanOutbox {
  _FakeOutbox(this._pending);
  final int _pending;

  @override
  ScanOutboxState build() => ScanOutboxState(
        loaded: true,
        entries: [
          for (var i = 0; i < _pending; i++)
            OutboxEntry(
              idempotencyKey: 'k$i',
              nfcTagUid: 'uid',
              okutmaZamani: DateTime(2026, 1, 1),
              enqueuedAt: DateTime(2026, 1, 1),
            ),
        ],
      );
}

Widget _app(
  UserRole role, {
  int pending = 0,
  int unread = 0,
  List<Shift> vardiyalar = const [
    Shift(
        id: 'v1',
        ad: 'Sabah Vardiyası',
        baslangicSaat: '06:00',
        bitisSaat: '14:00',
        gunTipi: 'hafta_ici'),
  ],
  String? tesisAd,
  List<Kargo> kargolar = const [],
  List<Visitor> ziyaretciler = const [],
  List<Hareket> hareketler = const [],
  Object? hareketHata,
}) =>
    ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) async =>
            Profile(ad: 'Mehmet', role: role.wire, aranabilir: false)),
        scanOutboxProvider.overrideWith(() => _FakeOutbox(pending)),
        unreadNotificationCountProvider.overrideWith((ref) async => unread),
        // Hava/tesis uclari testte aga cikmasin.
        weatherProvider.overrideWith((ref) async => throw Exception('offline')),
        tenantSettingsProvider.overrideWith((ref) async => tesisAd == null
            ? throw Exception('offline')
            : TenantSettings(tenantId: 't1', ad: tesisAd)),
        shiftsProvider.overrideWith((ref) async => vardiyalar),
        kargoListProvider.overrideWith((ref) async => kargolar),
        visitorsListProvider.overrideWith((ref) async => ziyaretciler),
        sahaHareketleriProvider.overrideWith((ref, guvenlik) =>
            hareketHata != null
                ? AsyncError(hareketHata, StackTrace.empty)
                : AsyncData(hareketler)),
        camerasProvider.overrideWith((ref) async => const [
              Camera(id: 'c1', ad: 'Ana Kapı', streamUrl: 'https://x/s.m3u8'),
            ]),
      ],
      child: MaterialApp(home: SahaHomeScreen(role: role)),
    );

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('SahaHomeScreen — gorevli.jpeg (guvenlik + tesis gorevlisi)', () {
    testWidgets('security: karsilama + tesis secici + serit + GERCEK vardiya '
        '+ Son Hareketler + Canlı Kamera', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(
        UserRole.security,
        tesisAd: 'Mavi Sitesi',
        hareketler: [
          Hareket(
            tip: HareketTip.ziyaretci,
            baslik: 'Ziyaretçi Girişi',
            altBaslik: 'Ahmet Yılmaz - Daire 12',
            zaman: DateTime(2026, 7, 23, 10),
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Merhaba, Mehmet'), findsOneWidget);
      // Tesis secici: gercek tenant adi + asagi ok.
      expect(find.text('Mavi Sitesi'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      // Hava ucu hatali → uydurma 24°C YOK.
      expect(find.text('24°C'), findsNothing);

      // Referans serit kartlari.
      expect(find.text('Vardiya Durum'), findsOneWidget);
      expect(find.text('Kargo'), findsOneWidget);
      expect(find.text('Ziyaretçi'), findsOneWidget);

      // Vardiya bolumu GERCEK /shifts verisinden.
      expect(find.text('Vardiya Durumu'), findsOneWidget);
      expect(find.text('Sabah Vardiyası'), findsOneWidget);
      expect(find.text('06:00 - 14:00'), findsOneWidget);

      // Son Hareketler GERCEK akistan + Canlı Kamera (gercek kamera).
      expect(find.text('Son Hareketler'), findsOneWidget);
      expect(find.text('Ziyaretçi Girişi'), findsOneWidget);
      expect(find.text('Canlı Kamera'), findsOneWidget);
      expect(find.text('Ana Kapı'), findsOneWidget);
      // Referans (uydurma) satirlar ARTIK YOK.
      expect(find.text('Kamera İhlal Tespiti'), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('tesis adi YOKKEN alt satir HIC cizilmez (uydurma tesis adi '
        'yok)', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.security));
      await tester.pumpAndSettle();
      expect(find.text('Mavi Residence'), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    });

    testWidgets('serit sayaclari GERCEK uctan: kargo bekleyen + bugunku '
        'ziyaretci; plaka/ihlal "Yakında"', (tester) async {
      _tall(tester);
      final now = DateTime.now();
      await tester.pumpWidget(_app(
        UserRole.security,
        tesisAd: 'Mavi Sitesi',
        kargolar: [
          Kargo(
            id: 'k1',
            unitId: 'u1',
            unitNo: '12',
            firma: 'Aras',
            durum: KargoDurum.bekliyor,
            kaydedenUserId: 'g1',
            createdAt: now,
          ),
        ],
        ziyaretciler: [
          Visitor(
            id: 'z1',
            unitId: 'u1',
            unitNo: '12',
            ziyaretciAd: 'Ahmet',
            kaydedenUserId: 'g1',
            targetResidentUserId: 'r1',
            createdAt: now,
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('1 Bekliyor'), findsOneWidget); // Kargo
      expect(find.text('1 Bugün'), findsOneWidget); // Ziyaretçi
      // Serit yatay kaydirilir; MISSING-BACKEND kartlar sonda.
      await tester.drag(find.text('Kargo'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Yakında'), findsWidgets);
    });

    testWidgets('tesisGorevlisi: KVKK — Kargo/Ziyaretçi/Araç Plaka kartlari '
        've Canlı Kamera YOK; vardiya + son hareketler VAR', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(
        UserRole.tesisGorevlisi,
        hareketler: [
          Hareket(
            tip: HareketTip.gorevTamamlama,
            baslik: 'Görev Tamamlandı',
            altBaslik: 'Merdiven - Temizlik',
            zaman: DateTime(2026, 7, 23, 10),
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Kargo'), findsNothing);
      expect(find.text('Ziyaretçi'), findsNothing);
      expect(find.text('Araç Plaka'), findsNothing);
      expect(find.text('Canlı Kamera'), findsNothing);

      expect(find.text('Vardiya Durum'), findsOneWidget); // serit karti
      expect(find.text('Vardiya Durumu'), findsOneWidget); // bolum basligi
      expect(find.text('Son Hareketler'), findsOneWidget);
      expect(find.text('Görev Tamamlandı'), findsOneWidget);
    });

    testWidgets('vardiya YOKKEN bolum HIC cizilmez (uydurma vardiya yok)',
        (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.security, vardiyalar: const []));
      await tester.pumpAndSettle();

      expect(find.text('Vardiya Durumu'), findsNothing); // bolum basligi yok
      expect(find.text('Öğle Vardiyası'), findsNothing);
      expect(find.text('Kerem Aşçı'), findsNothing); // mock yonetici karti yok
      expect(find.text('Vardiya Durum'), findsOneWidget); // serit karti durur
    });

    testWidgets('Son Hareketler HATASI: "Yüklenemedi" + yeniden dene',
        (tester) async {
      _tall(tester);
      await tester.pumpWidget(
          _app(UserRole.security, hareketHata: Exception('500')));
      await tester.pumpAndSettle();

      expect(find.byType(HomeBolumHatasi), findsOneWidget);
      expect(find.text('Yeniden dene'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('security: okunmamis bildirim rozeti zil + sekmede gorunur '
        '(RBAC izinli rol)', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.security, unread: 7));
      await tester.pumpAndSettle();
      expect(find.text('7'), findsNWidgets(2));
    });

    testWidgets('tesisGorevlisi: /notifications RBAC DISI — rozet HIC '
        'gorunmez (401 uretecek istek de atilmaz)', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.tesisGorevlisi, unread: 7));
      await tester.pumpAndSettle();
      expect(find.text('7'), findsNothing);
    });

    testWidgets('outbox bekleyen > 0: seride "Gönderim Kuyruğu" karti girer '
        '(cevrimdisi saha kaniti gorunur kalir)', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.tesisGorevlisi, pending: 3));
      await tester.pumpAndSettle();
      expect(find.text('Gönderim Kuyruğu'), findsOneWidget);
      expect(find.text('3 bekleyen'), findsOneWidget);
    });

    testWidgets('outbox bos: serit referans duzeninde kalir (ek kart YOK)',
        (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.tesisGorevlisi));
      await tester.pumpAndSettle();
      expect(find.text('Gönderim Kuyruğu'), findsNothing);
    });
  });
}
