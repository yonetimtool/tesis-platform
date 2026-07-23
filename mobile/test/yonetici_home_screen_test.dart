import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/budget/data/budget_api.dart';
import 'package:mobile/src/features/budget/domain/budget_models.dart';
import 'package:mobile/src/features/complaints/data/complaint_api.dart';
import 'package:mobile/src/features/home/presentation/yonetici_home_screen.dart';
import 'package:mobile/src/features/notifications/data/notifications_controller.dart';
import 'package:mobile/src/features/notifications/domain/notification_models.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/shifts/data/shifts_api.dart';
import 'package:mobile/src/features/shifts/domain/shift_models.dart';

/// API'ye dokunmayan sahte bildirim listesi (Son Hareketler beslemesi).
class _FakeNotifications extends NotificationsController {
  _FakeNotifications(this._items);
  final List<AppNotification> _items;

  @override
  Future<List<AppNotification>> build() async => _items;
}

Widget _app({
  Object? finansHata,
  int unread = 0,
  int acikSikayet = 0,
  List<Shift> vardiyalar = const [],
  List<AppNotification> bildirimler = const [],
}) =>
    ProviderScope(
      overrides: [
        unreadNotificationCountProvider.overrideWith((ref) async => unread),
        acikSikayetSayisiProvider.overrideWith((ref) async => acikSikayet),
        shiftsProvider.overrideWith((ref) async => vardiyalar),
        notificationsProvider
            .overrideWith(() => _FakeNotifications(bildirimler)),
        profileProvider.overrideWith((ref) async => const Profile(
              ad: 'Kerem',
              role: 'yonetici',
              aranabilir: false,
            )),
        financialSummaryProvider.overrideWith((ref) async {
          if (finansHata != null) throw finansHata;
          return const FinancialSummary(
            toplamGelirKurus: 24875000,
            toplamGiderKurus: 10000000,
            bakiyeKurus: 14875000,
            enYuksekGiderler: [],
            tahsilat: TahsilatOzet(
              tahakkukKurus: 30000000,
              tahsilatKurus: 24875000,
              gecikenDaireSayisi: 4,
              tahsilatOraniYuzde: 86,
            ),
          );
        }),
      ],
      child: const MaterialApp(home: YoneticiHomeScreen()),
    );

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('YoneticiHomeScreen: profil adiyla karsilar + "Yönetici Paneli" '
      'alt-basligi + one cikan kart + FAB "Olay Bildir"', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Merhaba, Kerem'), findsOneWidget);
    expect(find.text('Yönetici Paneli'), findsOneWidget);
    expect(find.text('Görev Yönetimi'), findsOneWidget);
    expect(find.text('Olay Bildir'), findsOneWidget);
  });

  testWidgets('Hızlı Özet: finans verisi gelince tahsilat + oran gorunur',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Hızlı Özet'), findsOneWidget);
    expect(find.text('%86'), findsOneWidget);
    expect(find.text('₺248.750,00'), findsNWidgets(2));
  });

  testWidgets('R2.2: Vardiya Durumu bolumu — RBAC genislemesiyle yonetici de '
      'gercek /shifts verisini gorur', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(vardiyalar: const [
      Shift(
          id: 'v1',
          ad: 'Sabah Vardiyası',
          baslangicSaat: '06:00',
          bitisSaat: '14:00',
          gunTipi: 'hafta_ici'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Vardiya Durumu'), findsOneWidget);
    expect(find.text('Sabah Vardiyası'), findsOneWidget);
    expect(find.text('06:00 - 14:00'), findsOneWidget);
  });

  testWidgets('R2.2/R2.3: vardiya + bildirim YOKKEN bolumler gizli, ekran '
      'calisir', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Vardiya Durumu'), findsNothing);
    expect(find.text('Son Hareketler'), findsNothing);
    expect(find.text('Görev Yönetimi'), findsOneWidget);
  });

  testWidgets('R2.3: Son Hareketler — bildirimlerden yonetim akisi '
      '(referans yonetici.jpeg)', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(bildirimler: [
      AppNotification(
          id: 'n1',
          tip: 'kacirilan_tur',
          mesaj: 'Gece turu kaçırıldı',
          okundu: false,
          createdAt: DateTime(2026, 7, 23, 9, 32)),
      AppNotification(
          id: 'n2',
          tip: 'gecikmis_okutma',
          mesaj: 'B Blok noktası geç okundu',
          okundu: true,
          createdAt: DateTime(2026, 7, 23, 8, 5)),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Son Hareketler'), findsOneWidget);
    expect(find.text('Kaçırılan Tur'), findsOneWidget);
    expect(find.text('Gece turu kaçırıldı'), findsOneWidget);
    expect(find.text('Gecikmiş Okutma'), findsOneWidget);
  });

  testWidgets('R2.1: acik sikayet sayisi "Şikayet / Öneri" kartinda '
      '"N Açık" sayaci', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(acikSikayet: 3));
    await tester.pumpAndSettle();
    expect(find.text('3 Açık'), findsOneWidget);
  });

  testWidgets('okunmamis bildirim sayisi zil + sekme rozetinde (gercek '
      'provider baglanir)', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(unread: 7));
    await tester.pumpAndSettle();
    expect(find.text('7'), findsNWidgets(2));
  });

  testWidgets('finans HATASI ekrani dusurmez: Hızlı Özet sessizce gizli, '
      'kartlar durur', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(finansHata: Exception('500')));
    await tester.pumpAndSettle();

    expect(find.text('Hızlı Özet'), findsNothing);
    expect(find.text('Görev Yönetimi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
