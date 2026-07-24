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
import 'package:mobile/src/features/weather/data/weather_api.dart';

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
  int? acikSikayet,
  List<Shift> vardiyalar = const [],
  List<AppNotification> bildirimler = const [],
}) =>
    ProviderScope(
      overrides: [
        unreadNotificationCountProvider.overrideWith((ref) async => unread),
        acikSikayetSayisiProvider.overrideWith((ref) async =>
            acikSikayet ?? (throw Exception('403'))),
        shiftsProvider.overrideWith((ref) async => vardiyalar),
        notificationsProvider
            .overrideWith(() => _FakeNotifications(bildirimler)),
        // Hava ucu testte aga cikmasin — hata → mock taban (24°C).
        weatherProvider.overrideWith((ref) async => throw Exception('offline')),
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
  testWidgets('referans bolum SIRASI (yonetici.jpeg): karsilama → 4x2 izgara '
      '→ Vardiya Durumu → Hızlı Özet → Son Hareketler', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Merhaba, Kerem'), findsOneWidget);
    expect(find.text('Yönetici Paneli'), findsOneWidget);
    expect(find.text('24°C'), findsOneWidget); // hava mock tabani
    expect(find.text('Olay Bildir'), findsOneWidget);

    // Izgaranin referans kartlari.
    for (final baslik in [
      'Görevler',
      'Aidat Durumu',
      'Otopark Kullanımı',
      'İhlaller',
      'Şikayetler',
    ]) {
      expect(find.text(baslik), findsOneWidget, reason: baslik);
    }
    // "Vardiya Durumu" iki yerde mesru: izgara karti + bolum basligi;
    // "Raporlar" da oyle: izgara karti + alt-bar sekmesi.
    expect(find.text('Vardiya Durumu'), findsNWidgets(2));
    expect(find.text('Raporlar'), findsNWidgets(2));

    final sira = [
      for (final baslik in ['Görevler', 'Hızlı Özet', 'Son Hareketler'])
        tester.getTopLeft(find.text(baslik).first).dy
    ];
    expect(sira[0] < sira[1], isTrue);
    expect(sira[1] < sira[2], isTrue);
  });

  testWidgets('Hızlı Özet: finans verisi gelince GERCEK tahsilat + oran mock '
      'tabani ezer; digerleri (Toplam Daire / Otopark) mock kalir',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Hızlı Özet'), findsOneWidget);
    expect(find.text('₺248.750,00'), findsOneWidget); // gercek tahsilat
    expect(find.text('%86'), findsOneWidget); // gercek oran
    expect(find.text('512'), findsOneWidget); // mock: Toplam Daire
    // "78 / 120" iki yerde: izgara karti (Otopark Kullanımı) + ozet kutusu.
    expect(find.text('78 / 120'), findsNWidgets(2));
  });

  testWidgets('finans HATASI ekrani dusurmez: Hızlı Özet mock tabanla cizilir',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(finansHata: Exception('500')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Hızlı Özet'), findsOneWidget);
    expect(find.text('₺248.750'), findsOneWidget); // mock deger
    expect(find.text('Görevler'), findsOneWidget); // kartlar duruyor
  });

  testWidgets('Vardiya Durumu: gercek /shifts verisi + sonda yonetici karti',
      (tester) async {
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

    expect(find.text('Sabah Vardiyası'), findsOneWidget);
    expect(find.text('06:00 - 14:00'), findsOneWidget);
    // Serinin sonundaki yonetici karti oturum sahibinin adiyla.
    expect(find.text('Kerem'), findsOneWidget);
    expect(find.text('YÖNETİCİ'), findsOneWidget);
  });

  testWidgets('vardiya YOKKEN bolum mock tabanla cizilir (bos ekran yok)',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Sabah Vardiyası'), findsOneWidget); // mock kart
  });

  testWidgets('Son Hareketler: bildirim varsa GERCEK akis mock tabani ezer',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(bildirimler: [
      AppNotification(
        id: 'n1',
        tip: 'kacirilan_tur',
        mesaj: 'A Blok turu kaçırıldı',
        createdAt: DateTime(2026, 7, 23, 9, 32),
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Son Hareketler'), findsOneWidget);
    expect(find.text('Kaçırılan Tur'), findsOneWidget);
    expect(find.text('A Blok turu kaçırıldı'), findsOneWidget);
    // Mock satiri artik yok — gercek veri ezdi.
    expect(find.text('Kamera İhlal Tespiti'), findsNothing);
  });

  testWidgets('acik sikayet sayisi izgara kartinin sayacini EZER',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(acikSikayet: 9));
    await tester.pumpAndSettle();
    expect(find.text('9 Açık'), findsOneWidget);
    expect(find.text('3 Yeni'), findsNothing); // mock sayac ezildi
  });

  testWidgets('okunmamis bildirim sayisi zil + sekme rozetinde', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(unread: 4));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsNWidgets(2));
  });
}
