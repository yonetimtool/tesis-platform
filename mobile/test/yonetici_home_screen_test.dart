import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/budget/data/budget_api.dart';
import 'package:mobile/src/features/budget/domain/budget_models.dart';
import 'package:mobile/src/features/complaints/data/complaint_api.dart';
import 'package:mobile/src/features/home/data/home_api.dart';
import 'package:mobile/src/features/home/data/activity_api.dart';
import 'package:mobile/src/features/home/domain/activity_models.dart';
import 'package:mobile/src/features/home/domain/parking_occupancy.dart';
import 'package:mobile/src/features/home/presentation/widgets/home_states.dart';
import 'package:mobile/src/features/home/presentation/yonetici_home_screen.dart';
import 'package:mobile/src/features/notifications/data/notifications_controller.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/shifts/data/shifts_api.dart';
import 'package:mobile/src/features/shifts/domain/shift_models.dart';
import 'package:mobile/src/features/weather/data/weather_api.dart';
import 'helpers/l10n_test_app.dart';
import 'package:mobile/src/core/i18n/locale_controller.dart';

Widget _app({
  Object? finansHata,
  int unread = 0,
  int? acikTalep,
  int? toplamDaire,
  int? aktifGorev,
  int? daireSikayet,
  List<Shift> vardiyalar = const [],
  List<ActivityItem> hareketler = const [],
  Object? hareketHata,
  int? yeniIhlal,
  ParkingOccupancy? otopark = const ParkingOccupancy(
      kapasite: 120, dolu: 3, oran: 2),
}) =>
    ProviderScope(
      overrides: [
        unreadNotificationCountProvider.overrideWith((ref) async => unread),
        acikSikayetSayisiProvider.overrideWith(
            (ref) async => acikTalep ?? (throw Exception('403'))),
        toplamDaireSayisiProvider.overrideWith(
            (ref) async => toplamDaire ?? (throw Exception('403'))),
        aktifGorevSayisiProvider.overrideWith(
            (ref) async => aktifGorev ?? (throw Exception('403'))),
        acikDaireSikayetSayisiProvider.overrideWith(
            (ref) async => daireSikayet ?? (throw Exception('403'))),
        sonHareketlerProvider.overrideWith((ref) async {
          if (hareketHata != null) throw hareketHata;
          return hareketler;
        }),
        yeniIhlalSayisiProvider.overrideWith(
            (ref) async => yeniIhlal ?? (throw Exception('403'))),
        otoparkDolulukProvider.overrideWith(
            (ref) async => otopark ?? (throw Exception('500'))),
        shiftsProvider.overrideWith((ref) async => vardiyalar),
        // Hava ucu testte aga cikmasin — hata → hava blogu HIC cizilmez.
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
      child: MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: supportedLocales,
      localizationsDelegates: testLocalizationsDelegates,
      home: YoneticiHomeScreen()),
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
    await tester.pumpWidget(_app(
      vardiyalar: const [
        Shift(
            id: 'v1',
            ad: 'Sabah Vardiyası',
            baslangicSaat: '06:00',
            bitisSaat: '14:00',
            gunTipi: 'hafta_ici'),
      ],
      hareketler: [
        ActivityItem(
          id: 'talep:t1',
          tur: ActivityTur.talep,
          baslik: 'Yeni Talep',
          altMetin: 'Asansör',
          zaman: DateTime(2026, 7, 23, 9),
          kaynakId: 't1',
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Merhaba, Kerem'), findsOneWidget);
    expect(find.text('Yönetici Paneli'), findsOneWidget);
    // Hava ucu hatali → uydurma 24°C YOK.
    expect(find.text('24°C'), findsNothing);

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

  testWidgets('Hızlı Özet TAMAMEN gercek uctan: /units toplami + finans '
      'tahsilat/oran + GERCEK otopark orani ("Yakında" KALMADI)',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(toplamDaire: 52));
    await tester.pumpAndSettle();

    expect(find.text('Hızlı Özet'), findsOneWidget);
    expect(find.text('52'), findsOneWidget); // GERCEK daire sayisi
    expect(find.text('₺248.750,00'), findsOneWidget); // gercek tahsilat
    expect(find.text('%86'), findsOneWidget); // gercek tahsilat orani
    expect(find.text('%2'), findsOneWidget); // GERCEK otopark orani
    expect(find.text('Şu An'), findsOneWidget); // kutu alt etiketi
    expect(find.text('3 / 120'), findsOneWidget); // izgara karti "dolu/kapasite"
    // Referans gorseldeki uydurma degerler ARTIK YOK.
    expect(find.text('512'), findsNothing);
    expect(find.text('₺248.750'), findsNothing);
    expect(find.text('78 / 120'), findsNothing);
    // Sozlesme boslugu kalmadi: hicbir kart/kutu 'Yakında' gostermez.
    expect(find.text('Yakında'), findsNothing);
  });

  testWidgets('G4: kapasite TANIMSIZ iken kart "N araç" gosterir, oran kutusu '
      '"—" (uydurma kapasite/yuzde YOK)', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(
      otopark: const ParkingOccupancy(dolu: 7),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('7 araç'), findsOneWidget);
    expect(find.textContaining('/'), findsNothing);
    expect(find.text('—'), findsWidgets); // oran kutusu
  });

  testWidgets('G2: ihlal sayaci gercek uctan ("N Yeni")', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(yeniIhlal: 2));
    await tester.pumpAndSettle();
    expect(find.text('2 Yeni'), findsOneWidget);
  });

  testWidgets('G2: ihlal ucu 403/500 verirse kart sayi UYDURMAZ ("—")',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app()); // yeniIhlal null -> 403
    await tester.pumpAndSettle();
    expect(find.text('2 Yeni'), findsNothing);
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('izgara sayaclari gercek uctan: gorev / geciken daire / talep / '
      'daire sikayeti', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(
      aktifGorev: 6,
      acikTalep: 9,
      daireSikayet: 3,
      vardiyalar: const [],
    ));
    await tester.pumpAndSettle();

    expect(find.text('6 Bekliyor'), findsOneWidget); // Görevler
    expect(find.text('4 Daire'), findsOneWidget); // geciken_daire_sayisi
    expect(find.text('9 Açık'), findsOneWidget); // Geri Bildirim
    expect(find.text('3 Açık'), findsOneWidget); // Şikayetler
  });

  testWidgets('finans HATASI ekrani dusurmez: kutular "—", kartlar durur',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(finansHata: Exception('500')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Hızlı Özet'), findsOneWidget);
    expect(find.text('Görevler'), findsOneWidget); // kartlar duruyor
    // Uydurma deger YOK: hata → '—'.
    expect(find.text('₺248.750'), findsNothing);
    expect(find.text('—'), findsWidgets);
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

  testWidgets('vardiya YOKKEN bolum HIC cizilmez (uydurma vardiya yok)',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Sabah Vardiyası'), findsNothing);
    expect(find.text('Vardiya Durumu'), findsOneWidget); // yalniz izgara karti
  });

  testWidgets('Son Hareketler TEK uctan (/activity) cizilir — istemci '
      'birlestirmesi YOK', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(hareketler: [
      ActivityItem(
        id: 'alarm:n1',
        tur: ActivityTur.alarm,
        baslik: 'Kaçırılan Tur',
        altMetin: 'A Blok turu kaçırıldı',
        zaman: DateTime(2026, 7, 23, 9, 32),
        renk: ActivityRenk.alarm,
        kaynakId: 'n1',
      ),
      ActivityItem(
        id: 'gorev_tamamlama:c1',
        tur: ActivityTur.gorevTamamlama,
        baslik: 'Görev Tamamlandı',
        altMetin: 'Çöp toplama — Temizlik',
        zaman: DateTime(2026, 7, 23, 9, 10),
        renk: ActivityRenk.olumlu,
        kaynakId: 'c1',
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Son Hareketler'), findsOneWidget);
    expect(find.text('Kaçırılan Tur'), findsOneWidget);
    expect(find.text('A Blok turu kaçırıldı'), findsOneWidget);
    expect(find.text('Görev Tamamlandı'), findsOneWidget);
    // Referans (uydurma) satirlar ARTIK YOK.
    expect(find.text('Kamera İhlal Tespiti'), findsNothing);
  });

  testWidgets('Son Hareketler HATASI: "Yüklenemedi" + yeniden dene',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(hareketHata: Exception('500')));
    await tester.pumpAndSettle();

    expect(find.byType(HomeBolumHatasi), findsOneWidget);
    expect(find.text('Yüklenemedi'), findsOneWidget);
    expect(find.text('Yeniden dene'), findsOneWidget);
  });

  testWidgets('okunmamis bildirim sayisi zil + sekme rozetinde', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(unread: 4));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsNWidgets(2));
  });
}
