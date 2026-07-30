import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/announcements/data/announcement_api.dart';
import 'package:mobile/src/features/announcements/domain/announcement_models.dart';
import 'package:mobile/src/features/complaints/data/complaint_api.dart';
import 'package:mobile/src/features/dues/data/dues_api.dart';
import 'package:mobile/src/features/dues/domain/dues_models.dart';
import 'package:mobile/src/features/home/data/activity_api.dart';
import 'package:mobile/src/features/home/data/home_api.dart';
import 'package:mobile/src/features/home/domain/activity_models.dart';
import 'package:mobile/src/features/home/presentation/resident_home_screen.dart';
import 'package:mobile/src/features/home/presentation/widgets/home_states.dart';
import 'package:mobile/src/features/kargo/data/kargo_api.dart';
import 'package:mobile/src/features/kargo/domain/kargo_models.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/visitors/data/visitor_api.dart';
import 'package:mobile/src/features/visitors/domain/visitor_models.dart';
import 'package:mobile/src/features/weather/data/weather_api.dart';
import 'helpers/ekran_surus.dart';
import 'helpers/l10n_test_app.dart';
import 'package:mobile/src/core/i18n/locale_controller.dart';

/// Ana ekran artik SADECE gercek uclardan beslenir; testte her uc override
/// edilir. `hata: true` tum uclari dusurur — ekran cokmemeli, bolumler
/// "Yüklenemedi" + yeniden dene gostermeli.
Widget _app({
  List<MyDuesUnit> units = const [],
  List<Kargo> kargolar = const [],
  List<Visitor> ziyaretciler = const [],
  List<Announcement> duyurular = const [],
  int acikTalep = 0,
  int daireSikayet = 0,
  int gurultuSikayet = 0,
  List<ActivityItem> hareketler = const [],
  bool hata = false,
  bool gecikme = false,
  Locale dil = const Locale('tr'),
}) {
  Future<T> uc<T>(T deger) async {
    if (hata) throw Exception('500');
    if (gecikme) {
      return Future.delayed(const Duration(milliseconds: 400), () => deger);
    }
    return deger;
  }

  return ProviderScope(
    overrides: [
      profileProvider.overrideWith(
        (ref) async =>
            const Profile(ad: 'Çiğdem', role: 'resident', aranabilir: false),
      ),
      // Hava ucu testte aga cikmasin — hata → baslik hava blogu cizilmez.
      weatherProvider.overrideWith((ref) async => throw Exception('offline')),
      myDuesProvider.overrideWith((ref) => uc(units)),
      kargoListProvider.overrideWith((ref) => uc(kargolar)),
      visitorsListProvider.overrideWith((ref) => uc(ziyaretciler)),
      sonDuyurularProvider.overrideWith((ref) => uc(duyurular)),
      acikSikayetSayisiProvider.overrideWith((ref) => uc(acikTalep)),
      kendiDaireSikayetSayisiProvider.overrideWith((ref) => uc(daireSikayet)),
      // G6: gurultu sayaci — kategori suzgeci sunucuda.
      kendiGurultuSikayetSayisiProvider.overrideWith(
        (ref) => uc(gurultuSikayet),
      ),
      // G5: akis TEK uctan (/activity) — istemci birlestirmesi YOK.
      sonHareketlerProvider.overrideWith((ref) => uc(hareketler)),
    ],
    child: MaterialApp(
      locale: dil,
      supportedLocales: supportedLocales,
      localizationsDelegates: testLocalizationsDelegates,
      // Tur 32: koyu tema surusu bu anahtari cevirir (varsayilan null =
      // acik tema, mevcut testler etkilenmez).
      theme: testTemasi,
      home: ResidentHomeScreen(),
    ),
  );
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 4200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

final _borcsuz = [
  MyDuesUnit(
    unitId: 'u1',
    no: '12',
    tahakkukKurus: 125000,
    odenenKurus: 125000,
    bakiyeKurus: 0,
    assessments: [DuesAssessment(donem: '2026-06', tutarKurus: 125000)],
  ),
];

final _borclu = [
  MyDuesUnit(
    unitId: 'u1',
    no: '12',
    tahakkukKurus: 250000,
    odenenKurus: 125000,
    bakiyeKurus: 125000,
    assessments: [DuesAssessment(donem: '2026-07', tutarKurus: 125000)],
  ),
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
      'izgara → Ödeme ve Aidat Durumu → Son Hareketler → Duyurular', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(
      _app(
        units: _borcsuz,
        kargolar: [_kargo('k1')],
        hareketler: [
          ActivityItem(
            id: 'kargo:k1',
            tur: ActivityTur.kargo,
            baslikKimlik: AkisBaslik.kargo,
            sunucuBaslik: 'Kargo Kaydedildi',
            sunucuAltMetin: 'Mng — Daire 12',
            zaman: DateTime(2026, 7, 23, 9),
            kaynakId: 'k1',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Merhaba, Çiğdem'), findsOneWidget);
    // Daire/blok alt satiri GERCEK /me/dues'ten.
    expect(find.textContaining('Daire 12  •  '), findsOneWidget);
    // Hava ucu hatali → uydurma 24°C YOK, blok hic cizilmez.
    expect(find.text('24°C'), findsNothing);

    // Izgaranin 8 karti (referans sirasi).
    for (final baslik in [
      'Ziyaretçiler',
      'Kargolarım',
      'Aidat Bilgileri',
      'Gürültü Şikayeti',
      'Geri Bildirim',
      'Şikayetlerim',
      'Site Raporları',
    ]) {
      expect(find.text(baslik), findsOneWidget, reason: baslik);
    }
    // "Duyurular" iki yerde mesru degil: duyuru YOKKEN bolum cizilmez →
    // yalniz izgara karti kalir.
    expect(find.text('Duyurular'), findsOneWidget);

    final sira = [
      for (final baslik in [
        'Ziyaretçiler',
        'Ödeme ve Aidat Durumu',
        'Son Hareketler',
      ])
        tester.getTopLeft(find.text(baslik).first).dy,
    ];
    expect(sira[0] < sira[1], isTrue);
    expect(sira[1] < sira[2], isTrue);
  });

  testWidgets('borcsuz sakin: gercek /me/dues izgara sayacini besler '
      '("Borç Yok")', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(units: _borcsuz));
    await tester.pumpAndSettle();

    expect(find.text('Ödeme ve Aidat Durumu'), findsOneWidget);
    expect(find.text('Borç Yok'), findsOneWidget); // izgara kartinin 2. satiri
    expect(find.text('₺1.250,00'), findsWidgets);
  });

  testWidgets('borclu sakin: izgara sayaci borc tutari + "Borç Var"; kargo '
      'sayaci listeden turetilir', (tester) async {
    _tall(tester);
    await tester.pumpWidget(
      _app(
        units: _borclu,
        kargolar: [_kargo('k1'), _kargo('k2'), _kargo('k3')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Borç Var'), findsOneWidget);
    expect(find.text('3 Bekliyor'), findsOneWidget); // Kargolarım sayaci
  });

  testWidgets('sayaclar GERCEK uctan: ziyaretci/talep/daire sikayeti/duyuru', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(
      _app(
        units: _borcsuz,
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
        acikTalep: 2,
        daireSikayet: 1,
        gurultuSikayet: 3,
        duyurular: [
          Announcement(
            id: 'd1',
            baslik: 'Asansör Bakımı',
            govde: 'Perşembe günü asansör bakımı yapılacaktır.',
            olusturanUserId: 'y1',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 Kayıt'), findsOneWidget); // Ziyaretçiler
    expect(find.text('2 Açık'), findsOneWidget); // Geri Bildirim
    expect(find.text('1 Açık'), findsOneWidget); // Şikayetlerim
    // G6: gurultu sayaci ?kategori=gurultu suzgecinden (istemci suzmez).
    expect(find.text('3 Açık'), findsOneWidget); // Gürültü Şikayeti
    expect(find.text('Bildirim Yap'), findsNothing);
    expect(find.text('1 Yeni'), findsOneWidget); // Duyurular (son 3 gun)
    expect(find.text('Asansör Bakımı'), findsOneWidget); // duyuru karti
  });

  testWidgets('Son Hareketler TEK uctan (/activity): sunucu metinleri aynen '
      'cizilir, istemci birlestirmez', (tester) async {
    _tall(tester);
    await tester.pumpWidget(
      _app(
        hareketler: [
          ActivityItem(
            id: 'kargo:k1',
            tur: ActivityTur.kargo,
            baslikKimlik: AkisBaslik.kargo,
            sunucuBaslik: 'Kargo Kaydedildi',
            sunucuAltMetin: 'Aras Kargo — Daire A-12',
            zaman: DateTime(2026, 7, 23, 11),
            kaynakId: 'k1',
          ),
          ActivityItem(
            id: 'ziyaretci_giris:z1',
            tur: ActivityTur.ziyaretciGiris,
            baslikKimlik: AkisBaslik.ziyaretciGiris,
            sunucuBaslik: 'Ziyaretçi Girişi',
            sunucuAltMetin: 'Ahmet Yılmaz — Daire A-12',
            zaman: DateTime(2026, 7, 23, 10),
            kaynakId: 'z1',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Son Hareketler'), findsOneWidget);
    expect(find.text('Kargo Kaydedildi'), findsOneWidget);
    expect(find.text('Ahmet Yılmaz — Daire A-12'), findsOneWidget);
  });

  testWidgets('veri HATALARI ekrani dusurmez: bolumler "Yüklenemedi" + '
      'yeniden dene gosterir, sayaclar "—"', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(hata: true));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Bolumler bos beyaz degil: hata karti + yenileme dugmesi.
    expect(find.text('Ödeme ve Aidat Durumu'), findsOneWidget);
    expect(find.text('Son Hareketler'), findsOneWidget);
    expect(find.text('Duyurular'), findsWidgets);
    expect(find.text('Yüklenemedi'), findsNWidgets(3));
    expect(find.byType(HomeBolumHatasi), findsNWidgets(3));
    // Kart sayaclari uydurmuyor: '—'.
    expect(find.text('Ziyaretçiler'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('UYDURMA SAYI YOK: veri gelmeden sayac yerine iskelet cizilir', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(_app(units: _borcsuz, gecikme: true));
    await tester.pump(); // uclar henuz cevap vermedi

    expect(find.byType(HomeSayacIskeleti), findsWidgets);
    expect(find.byType(HomeBolumIskeleti), findsWidgets);
    // Referans gorselin sabit degerleri HICBIR ZAMAN gorunmez.
    expect(find.text('₺1.250,00'), findsNothing);
    expect(find.text('2 Bekliyor'), findsNothing);

    // Zamanlayicilari bosalt (aksi halde "Timer is still pending").
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  });

  // ---- TUR 32: KOYU TEMA ----
  // Ana ekran surusun EN RISKLI ekrani: yeniden tasarimda (README §16)
  // lacivert/teal SABIT renkler ve degradeler geldi — bunlar temayla
  // degismez, yani koyu zeminde okunmayabilirler.
  testWidgets('KOYU TEMA: sakin ana ekrani 7 dilde (kontrast + tasma)', (
    tester,
  ) async {
    _tall(tester);
    await koyuTemaSurusu(
      tester,
      (dil) => _app(units: _borcsuz, dil: Locale(dil)),
      veri: surusVerisi,
    );
  });

  // ---- TUR 33: KLAVYE ----
  testWidgets('KLAVYE: ana ekran (odak sirasi + tuzak + dokunma-yalniz)', (
    tester,
  ) async {
    _tall(tester);
    await klavyeSurusu(
      tester,
      (dil) => _app(units: _borcsuz, dil: Locale(dil)),
    );
  });

  // ---- TUR 34: FOTOGRAFLI VERI ----
  testWidgets('FOTOGRAFLI: sakin ana ekrani (bes eksen birden)', (
    tester,
  ) async {
    _tall(tester);
    await fotografliSurus(
      tester,
      (dil) => _app(
        units: _borcsuz,
        dil: Locale(dil),
        duyurular: [
          Announcement(
            id: 'd1',
            // Duyuru metni SUNUCU verisidir (cevrilmez) — surusun TR
            // sizinti kilidine takilmamasi icin veri kumesinden secildi.
            baslik: 'Acme duyuru',
            govde: 'Demo duyuru govdesi.',
            olusturanUserId: 'y1',
            fotoKey: 't/duyuru/x.jpg',
            fotoUrl: 'https://ornek/duyuru.jpg',
            createdAt: DateTime.utc(2026, 7, 20),
            updatedAt: DateTime.utc(2026, 7, 20),
          ),
        ],
      ),
      veri: surusVerisi,
    );
  });

  // ---- TUR 59: EKSEN KOMBINASYONLARI ----
  testWidgets('EKSEN: sakin ana ekrani (7 kombinasyon x 3 dil)', (
    tester,
  ) async {
    await eksenKombinasyonSurusu(
      tester,
      (dil) => _app(units: _borcsuz, dil: Locale(dil)),
      veri: surusVerisi,
    );
  });
  testWidgets('ANIMASYON: sakin ana ekrani her karede tasmaz', (tester) async {
    await animasyonSurusu(
      tester,
      (dil) => _app(units: _borcsuz, dil: Locale(dil)),
    );
  });
}
