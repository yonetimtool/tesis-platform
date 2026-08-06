/// Saha ana ekrani — 4'LU IZGARA duzeni (yatay serit KALKTI) + rol basina
/// kart seti. Sayaclar sahte uclarla beslenir; ag'a cikilmaz.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/announcements/data/announcement_api.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/cameras/data/cameras_api.dart';
import 'package:mobile/src/features/complaints/data/complaint_api.dart';
import 'package:mobile/src/features/home/data/activity_api.dart';
import 'package:mobile/src/features/home/data/home_api.dart';
import 'package:mobile/src/features/home/presentation/saha_home_screen.dart';
import 'package:mobile/src/features/home/presentation/widgets/hizli_erisim.dart';
import 'package:mobile/src/features/kargo/data/kargo_api.dart';
import 'package:mobile/src/features/notifications/data/notifications_controller.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/scan/data/scan_outbox.dart';
import 'package:mobile/src/features/shifts/data/shifts_api.dart';
import 'package:mobile/src/features/tenant/data/tenant_api.dart';
import 'package:mobile/src/features/weather/data/weather_api.dart';
import 'package:mobile/src/features/yonetici_iletisim/data/yonetici_iletisim_api.dart';
import 'helpers/l10n_test_app.dart';
import 'package:mobile/src/core/i18n/locale_controller.dart';

class _FakeOutbox extends ScanOutbox {
  @override
  ScanOutboxState build() => const ScanOutboxState(loaded: true);
}

Widget _app(UserRole role) => ProviderScope(
      overrides: [
        profileProvider.overrideWith(
            (ref) async => Profile(ad: 'Mehmet', role: role.wire, aranabilir: false)),
        scanOutboxProvider.overrideWith(_FakeOutbox.new),
        unreadNotificationCountProvider.overrideWith((ref) async => 0),
        weatherProvider.overrideWith((ref) async => throw Exception('offline')),
        tenantSettingsProvider
            .overrideWith((ref) async => throw Exception('offline')),
        yoneticiIletisimProvider
            .overrideWith((ref) async => throw Exception('offline')),
        shiftsProvider.overrideWith((ref) async => const []),
        camerasProvider.overrideWith((ref) async => const []),
        kargoListProvider.overrideWith((ref) async => const []),
        sonHareketlerProvider.overrideWith((ref) async => const []),
        sonDuyurularProvider.overrideWith((ref) async => const []),
        icerdekiZiyaretciSayisiProvider.overrideWith((ref) async => 1),
        bugunkuAracGirisSayisiProvider.overrideWith((ref) async => 4),
        yeniIhlalSayisiProvider.overrideWith((ref) async => 2),
        aktifGorevSayisiProvider.overrideWith((ref) async => 6),
        uzerimdekiZimmetSayisiProvider.overrideWith((ref) async => 3),
        acikSikayetSayisiProvider.overrideWith((ref) async => 5),
        yaklasanEtkinlikSayisiProvider.overrideWith((ref) async => 2),
      ],
      child: MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: supportedLocales,
      localizationsDelegates: testLocalizationsDelegates,
      home: SahaHomeScreen(role: role)),
    );

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('security: YATAY SERIT YOK — 4\'lu izgara + 8 kart sayacli',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(UserRole.security));
    await tester.pumpAndSettle();

    // Duzen: izgara VAR, serit YOK.
    expect(find.byType(HizliErisimIzgarasi), findsOneWidget);
    expect(find.byType(HizliErisimSeridi), findsNothing);

    // 8 kart basligi.
    for (final baslik in [
      'Vardiyalar', // (P144) kanonik ad = /vardiyalar ekraninin basligi
      'Kargo',
      'Ziyaretçiler', // (P144) kanonik ad = /visitors ekraninin basligi
      'Araç Plaka',
      'İhlaller',
      'Görevlerim',
      'Demirbaş',
      'Turlarım',
    ]) {
      expect(find.text(baslik), findsWidgets, reason: baslik);
    }

    // YENI sayaclar gercek uctan.
    expect(find.text('6 Bekliyor'), findsOneWidget); // Görevlerim
    expect(find.text('3 Zimmetli'), findsOneWidget); // Demirbaş
    expect(find.text('1 İçeride'), findsOneWidget);
    expect(find.text('4 Giriş'), findsOneWidget);
    expect(find.text('2 Yeni'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tesis gorevlisi: KENDI izgarasi — KVKK kartlari YOK, is '
      'kartlari sayacli', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(UserRole.tesisGorevlisi));
    await tester.pumpAndSettle();

    expect(find.byType(HizliErisimIzgarasi), findsOneWidget);
    // Rolun cagirabildigi uclar → kartlar + sayaclar.
    expect(find.text('Görevlerim'), findsWidgets);
    expect(find.text('6 Bekliyor'), findsOneWidget);
    expect(find.text('3 Zimmetli'), findsOneWidget);
    expect(find.text('5 Açık'), findsOneWidget); // Talep / Arıza
    expect(find.text('2 Yaklaşan'), findsOneWidget); // Etkinlikler
    expect(find.text('Site Kuralları'), findsOneWidget);

    // KVKK: bu rolun 403 aldigi uclarin kartlari HIC yok.
    for (final yasak in ['Kargo', 'Ziyaretçi', 'Araç Plaka', 'İhlaller']) {
      expect(find.text(yasak), findsNothing, reason: yasak);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('izgara 4 sutundur (telefon genisliginde)', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(UserRole.security));
    await tester.pumpAndSettle();

    final grid = tester.widget<GridView>(
      find.descendant(
        of: find.byType(HizliErisimIzgarasi),
        matching: find.byType(GridView),
      ),
    );
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 4);
  });
}
