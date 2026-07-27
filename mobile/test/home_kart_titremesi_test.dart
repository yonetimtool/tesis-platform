/// IZGARA KART METNI TITREMESI — 8bf04f9'daki acilis titremesinden BASKA,
/// uygulama KULLANILIRKEN her yeniden cizimde gorunen titreme.
///
/// Kok neden: bolum widget'lari [AutoSizeGroup]'lari `build()` ICINDE
/// uretiyordu. Grup, uyelerin ortak yazi boyutunu tutan KALICI bir
/// denetleyicidir; her cizimde YENISI uretilince `AutoSizeText.didUpdateWidget`
/// grubu degismis gorup yeniden kaydolur ve grubun `_fontSize`i `infinity`ye
/// doner. O tek karede kartlar ortak (kucuk) boyut yerine KENDI (buyuk)
/// boyutlarinda cizilir, sonraki karede ortak boyuta oturur → yazilar zipliyor.
///
/// Bu titreme sayac DEGERI degismeden de olur: 45 sn'lik periyodik yenileme,
/// dil/tema degisimi, kisacasi HER yeniden cizim tetikler. Bu yuzden tum
/// rollerde gorunur.
///
/// IDDIA (regresyon): ayni veriyle yeniden cizimde, cizilen HER karede yazi
/// boyutlari oturmus degerle AYNI kalir; ayrica veri varken iskelet cizilmez.
library;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/budget/data/budget_api.dart';
import 'package:mobile/src/features/budget/domain/budget_models.dart';
import 'package:mobile/src/features/complaints/data/complaint_api.dart';
import 'package:mobile/src/features/home/data/activity_api.dart';
import 'package:mobile/src/features/home/data/home_api.dart';
import 'package:mobile/src/features/home/data/home_repository.dart';
import 'package:mobile/src/features/home/domain/activity_models.dart';
import 'package:mobile/src/features/home/domain/home_kart_id.dart';
import 'package:mobile/src/features/home/domain/home_varyant.dart';
import 'package:mobile/src/features/home/domain/home_view_models.dart';
import 'package:mobile/src/features/home/domain/parking_occupancy.dart';
import 'package:mobile/src/features/home/presentation/widgets/hizli_erisim.dart';
import 'package:mobile/src/features/home/presentation/widgets/home_states.dart';
import 'package:mobile/src/features/home/presentation/widgets/stat_tile.dart';
import 'package:mobile/src/features/home/presentation/yonetici_home_screen.dart';
import 'package:mobile/src/features/notifications/data/notifications_controller.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/shifts/data/shifts_api.dart';
import 'package:mobile/src/features/weather/data/weather_api.dart';

import 'helpers/l10n_test_app.dart';

/// Cizilmis her [AutoSizeText]'in metin → uygulanan `fontSize` haritasi.
/// AutoSizeText, cozdugu boyutu alt `Text`in stiline yazar; titreme burada
/// olculur (goz yerine sayi).
Map<String, double?> _yaziBoyutlari(WidgetTester tester) {
  final boyutlar = <String, double?>{};
  for (final ast in tester.widgetList<AutoSizeText>(find.byType(AutoSizeText))) {
    final metinler = tester.widgetList<Text>(find.descendant(
      of: find.byWidget(ast),
      matching: find.byType(Text),
    ));
    if (metinler.isNotEmpty) {
      boyutlar[ast.data ?? '?'] = metinler.first.style?.fontSize;
    }
  }
  return boyutlar;
}

/// [tetikle] ile yeniden cizim baslatir ve ARDINDAN gelen [kare] karenin
/// HEPSINDE yazi boyutlarinin oturmus degerle ayni kaldigini dogrular.
Future<void> _titremeYok(
  WidgetTester tester, {
  required VoidCallback tetikle,
  int kare = 3,
}) async {
  await tester.pumpAndSettle();
  final oturmus = _yaziBoyutlari(tester);
  expect(oturmus, isNotEmpty, reason: 'olculecek yazi bulunamadi');

  tetikle();

  for (var i = 1; i <= kare; i++) {
    await tester.pump();
    expect(
      _yaziBoyutlari(tester),
      oturmus,
      reason: 'kare $i: yeniden cizimde yazi boyutu degisti (TITREME)',
    );
  }
}

/// Her cizimde `tik`i artan, sayac DEGERLERI sabit kabuk: olculen tek sey
/// yeniden cizimin kendisidir.
class _YenidenCizim extends StatefulWidget {
  const _YenidenCizim({super.key, required this.govde});

  final Widget Function(int tik) govde;

  @override
  State<_YenidenCizim> createState() => _YenidenCizimState();
}

class _YenidenCizimState extends State<_YenidenCizim> {
  int tik = 0;

  void ciz() => setState(() => tik++);

  @override
  Widget build(BuildContext context) => widget.govde(tik);
}

/// Yonetici izgarasi — sayaclari GERCEKCI uzunluklarda (kisa "1 Yeni" ile
/// uzun "Otopark Kullanımı" ayni grupta oldugu icin ortak boyut kuculur).
List<HizliErisimKart> _yoneticiKartlari() => [
      for (final k in const MockHomeRepository().hizliErisim(HomeVaryant.yonetici))
        switch (k.id) {
          HomeKartId.vardiyaDurumu => k.sayacla('2 Aktif'),
          HomeKartId.gorevler => k.sayacla('7 Bekliyor'),
          HomeKartId.aidatDurumu => k.sayacla('4 Daire'),
          HomeKartId.otoparkKullanimi => k.sayacla('3 / 120'),
          HomeKartId.ihlaller => k.sayacla('1 Yeni'),
          HomeKartId.geriBildirim => k.sayacla('5 Açık'),
          HomeKartId.sikayetler => k.sayacla('9 Açık'),
          _ => k,
        },
    ];

void _uzunEkran(WidgetTester tester, {double yukseklik = 2400}) {
  tester.view.physicalSize = Size(400, yukseklik);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Yonetici ana ekrani — tum uclar sabit (yenilemede AYNI deger doner), yani
/// ekranda gorunen her degisiklik TITREMEDIR.
Widget _yoneticiEkrani() => ProviderScope(
      overrides: [
        unreadNotificationCountProvider.overrideWith((ref) async => 0),
        acikSikayetSayisiProvider.overrideWith((ref) async => 5),
        toplamDaireSayisiProvider.overrideWith((ref) async => 53),
        aktifGorevSayisiProvider.overrideWith((ref) async => 7),
        acikDaireSikayetSayisiProvider.overrideWith((ref) async => 9),
        yeniIhlalSayisiProvider.overrideWith((ref) async => 1),
        otoparkDolulukProvider.overrideWith(
            (ref) async => const ParkingOccupancy(kapasite: 120, dolu: 3, oran: 2)),
        shiftsProvider.overrideWith((ref) async => const []),
        weatherProvider.overrideWith((ref) async => throw Exception('offline')),
        profileProvider.overrideWith((ref) async =>
            const Profile(ad: 'Kerem', role: 'yonetici', aranabilir: false)),
        sonHareketlerProvider.overrideWith((ref) async => <ActivityItem>[]),
        financialSummaryProvider.overrideWith((ref) async => const FinancialSummary(
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
            )),
      ],
      child: l10nApp(const YoneticiHomeScreen()),
    );

void main() {
  testWidgets('4x2 izgara: yeniden cizimde kart yazilari ZIPLAMAZ',
      (tester) async {
    _uzunEkran(tester);
    final key = GlobalKey<_YenidenCizimState>();
    await tester.pumpWidget(l10nScaffold(_YenidenCizim(
      key: key,
      govde: (_) =>
          HizliErisimIzgarasi(kartlar: _yoneticiKartlari(), onSec: (_) {}),
    )));

    await _titremeYok(tester, tetikle: () => key.currentState!.ciz());
  });

  testWidgets('gorevli seridi: yeniden cizimde kart yazilari ZIPLAMAZ',
      (tester) async {
    _uzunEkran(tester);
    // Sayaclar FARKLI uzunlukta: ortak boyut en uzun metne gore kuculur, yani
    // grup gercekten is yapar (hepsi ayni uzunlukta olsa titreme gorunmezdi).
    const sayaclar = [
      '3 Aktif',
      '12 Bekleyen Kargo',
      '2 İçerde',
      '48 Giriş',
      '1 Yeni',
      '7 Bekliyor',
      '2 Zimmet',
      'Devriye',
    ];
    final taban =
        const MockHomeRepository().hizliErisim(HomeVaryant.gorevli);
    final kartlar = [
      for (var i = 0; i < taban.length; i++)
        taban[i].sayacla(sayaclar[i % sayaclar.length]),
    ];
    final key = GlobalKey<_YenidenCizimState>();
    await tester.pumpWidget(l10nScaffold(_YenidenCizim(
      key: key,
      govde: (_) => HizliErisimSeridi(kartlar: kartlar, onSec: (_) {}),
    )));

    await _titremeYok(tester, tetikle: () => key.currentState!.ciz());
  });

  testWidgets('Hızlı Özet kutulari: yeniden cizimde degerler ZIPLAMAZ',
      (tester) async {
    _uzunEkran(tester);
    final kutular = [
      for (final k in const MockHomeRepository().ozet())
        switch (k.id) {
          OzetKutuId.toplamDaire => k.degerle('53'),
          OzetKutuId.toplamTahsilat => k.degerle('₺248.750'),
          OzetKutuId.tahsilatOrani => k.degerle('%86'),
          OzetKutuId.otoparkDoluluk => k.degerle('%2'),
        },
    ];
    final key = GlobalKey<_YenidenCizimState>();
    await tester.pumpWidget(l10nScaffold(_YenidenCizim(
      key: key,
      govde: (_) => HizliOzetIzgarasi(kutular: kutular),
    )));

    await _titremeYok(tester, tetikle: () => key.currentState!.ciz());
  });

  testWidgets(
      'YENILEME DONGUSU (on plana donus): sayaclar yerinde guncellenir — '
      'ne iskelet ne boyut ziplamasi', (tester) async {
    _uzunEkran(tester);
    await tester.pumpWidget(_yoneticiEkrani());
    await tester.pumpAndSettle();

    // Ilk yukleme bitti: gercek sayaclar ekranda, iskelet yok.
    expect(find.text('7 Bekliyor'), findsOneWidget);
    expect(find.byType(HomeSayacIskeleti), findsNothing);
    final oturmus = _yaziBoyutlari(tester);

    // Tetikleyici (2): on plana donus → TAM yenileme (tum saglayicilar
    // invalidate). Yenileme boyunca cizilen HER kare denetlenir.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    for (var i = 1; i <= 4; i++) {
      await tester.pump();
      expect(find.byType(HomeSayacIskeleti), findsNothing,
          reason: 'kare $i: veri VARKEN iskelete dusuldu');
      expect(find.text('7 Bekliyor'), findsOneWidget,
          reason: 'kare $i: sayac degeri kayboldu');
      expect(_yaziBoyutlari(tester), oturmus,
          reason: 'kare $i: yenilemede yazi boyutu degisti (TITREME)');
    }

    await tester.pumpAndSettle();
    expect(_yaziBoyutlari(tester), oturmus);
  });

  testWidgets('PERIYODIK yenileme (45 sn) sayaclari titretmez', (tester) async {
    _uzunEkran(tester);
    await tester.pumpWidget(_yoneticiEkrani());
    await tester.pumpAndSettle();
    final oturmus = _yaziBoyutlari(tester);

    // Tetikleyici (4): yumusak yenileme — sayac + akis. DIKKAT: zamanlayiciyi
    // isleten `pump` kendisi de bir kare cizer; ilk denetim O KARE uzerinde
    // olmali (titreme bir sonraki kareye degil, ilk cizime dusuyor).
    await tester.pump(const Duration(seconds: 46));
    expect(_yaziBoyutlari(tester), oturmus,
        reason: 'periyodik yenilemenin ILK karesinde yazi boyutu degisti');

    for (var i = 1; i <= 3; i++) {
      await tester.pump();
      expect(find.byType(HomeSayacIskeleti), findsNothing,
          reason: 'kare $i: periyodik yenilemede iskelet');
      expect(_yaziBoyutlari(tester), oturmus,
          reason: 'kare $i: periyodik yenilemede yazi boyutu degisti');
    }
  });
}
