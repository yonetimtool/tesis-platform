import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/announcements/data/announcement_api.dart';
import 'package:mobile/src/features/announcements/domain/announcement_models.dart';
import 'package:mobile/src/features/dues/data/dues_api.dart';
import 'package:mobile/src/features/dues/domain/dues_models.dart';
import 'package:mobile/src/features/home/presentation/resident_home_screen.dart';
import 'package:mobile/src/features/kargo/data/kargo_api.dart';
import 'package:mobile/src/features/kargo/domain/kargo_models.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/visitors/data/visitor_api.dart';
import 'package:mobile/src/features/visitors/domain/visitor_models.dart';
import 'package:mobile/src/features/weather/data/weather_api.dart';

Widget _app({
  List<MyDuesUnit> units = const [],
  List<Kargo> kargolar = const [],
  List<Visitor> ziyaretciler = const [],
  List<Announcement> duyurular = const [],
  bool hata = false,
}) =>
    ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) async => const Profile(
              ad: 'Çiğdem',
              role: 'resident',
              aranabilir: false,
            )),
        // Hava ucu testte aga cikmasin — hata → mock taban (24°C).
        weatherProvider.overrideWith((ref) async => throw Exception('offline')),
        myDuesProvider.overrideWith(
            (ref) async => hata ? throw Exception('500') : units),
        kargoListProvider.overrideWith(
            (ref) async => hata ? throw Exception('500') : kargolar),
        visitorsListProvider.overrideWith(
            (ref) async => hata ? throw Exception('500') : ziyaretciler),
        sonDuyurularProvider.overrideWith(
            (ref) async => hata ? throw Exception('500') : duyurular),
      ],
      child: const MaterialApp(home: ResidentHomeScreen()),
    );

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 4200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

const _borcsuz = [
  MyDuesUnit(
      unitId: 'u1',
      no: '12',
      tahakkukKurus: 125000,
      odenenKurus: 125000,
      bakiyeKurus: 0),
];

const _borclu = [
  MyDuesUnit(
      unitId: 'u1',
      no: '12',
      tahakkukKurus: 250000,
      odenenKurus: 125000,
      bakiyeKurus: 125000),
];

Kargo _kargo(String id, {KargoDurum durum = KargoDurum.bekliyor}) => Kargo(
      id: id,
      unitId: 'u1',
      unitNo: '12',
      firma: 'Mng',
      durum: durum,
      kaydedenUserId: 'g1',
      createdAt: DateTime(2026, 7, 23, 9),
    );

void main() {
  testWidgets('referans bolum SIRASI (site-sakini.jpeg): karsilama → 4x2 '
      'izgara → Ödeme ve Aidat Durumu → Son Hareketler → Duyurular',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Merhaba, Çiğdem'), findsOneWidget);
    // Hava: gercek uc hatali → mock taban.
    expect(find.text('24°C'), findsOneWidget);
    expect(find.text('İstanbul'), findsOneWidget);

    // Izgaranin 8 karti (referans sirasi).
    for (final baslik in [
      'Ziyaretçiler',
      'Kargolarım',
      'Aidat Bilgileri',
      'Gürültü Şikayeti',
      'Şikayetlerim',
      'Site Raporları',
    ]) {
      expect(find.text(baslik), findsOneWidget, reason: baslik);
    }
    // "Duyurular" iki yerde mesru: izgara karti + bolum basligi; "Geri
    // Bildirim" de oyle: izgara karti + referans hareket satiri.
    expect(find.text('Duyurular'), findsNWidgets(2));
    expect(find.text('Geri Bildirim'), findsNWidgets(2));

    final sira = [
      for (final baslik in [
        'Ziyaretçiler',
        'Ödeme ve Aidat Durumu',
        'Son Hareketler',
      ])
        tester.getTopLeft(find.text(baslik).first).dy
    ];
    expect(sira[0] < sira[1], isTrue);
    expect(sira[1] < sira[2], isTrue);
  });

  testWidgets('borcsuz sakin: gercek /me/dues izgara sayacini EZER '
      '("Borç Yok")', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(units: _borcsuz));
    await tester.pumpAndSettle();

    expect(find.text('Ödeme ve Aidat Durumu'), findsOneWidget);
    expect(find.text('Borç Yok'), findsOneWidget); // izgara kartinin 2. satiri
  });

  testWidgets('borclu sakin: izgara sayaci borc tutari + "Borç Var"; kargo '
      'sayaci listeden turetilir', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(
      units: _borclu,
      kargolar: [_kargo('k1'), _kargo('k2'), _kargo('k3')],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Borç Var'), findsOneWidget);
    expect(find.text('3 Bekliyor'), findsOneWidget); // Kargolarım sayaci
  });

  testWidgets('Son Hareketler GERCEK akistan (kargo+ziyaretci) beslenir ve '
      'mock tabani ezer', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(
      kargolar: [_kargo('k1')],
      ziyaretciler: [
        Visitor(
          id: 'z1',
          unitId: 'u1',
          unitNo: '12',
          ziyaretciAd: 'Ahmet Yılmaz',
          kaydedenUserId: 'g1',
          targetResidentUserId: 'r1',
          createdAt: DateTime(2026, 7, 23, 10),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Son Hareketler'), findsOneWidget);
    expect(find.text('Kargo Kaydedildi'), findsOneWidget);
    expect(find.text('Ahmet Yılmaz - Daire 12'), findsOneWidget);
    // Mock satiri (referans) artik gorunmuyor — gercek veri ezdi.
    expect(find.text('Gürültü Şikayeti Bildirimi'), findsNothing);
  });

  testWidgets('gercek duyuru varsa kart onu gosterir', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(duyurular: [
      Announcement(
        id: 'd1',
        baslik: 'Asansör Bakımı',
        govde: 'Perşembe günü asansör bakımı yapılacaktır.',
        olusturanUserId: 'y1',
        createdAt: DateTime(2026, 7, 22),
        updatedAt: DateTime(2026, 7, 22),
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Asansör Bakımı'), findsOneWidget);
    expect(find.text('Bahçe Düzenlemesi'), findsNothing); // mock ezildi
  });

  testWidgets('veri HATALARI ekrani dusurmez: bolumler mock tabanla cizilir',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(hata: true));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Referans duzen ayakta: bolumler bos beyaz ekrana donmuyor.
    expect(find.text('Ödeme ve Aidat Durumu'), findsOneWidget);
    expect(find.text('Son Hareketler'), findsOneWidget);
    expect(find.text('Bahçe Düzenlemesi'), findsOneWidget); // mock duyuru
    expect(find.text('Ziyaretçiler'), findsOneWidget);
  });
}
