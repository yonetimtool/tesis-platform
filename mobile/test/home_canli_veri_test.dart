/// CANLI VERI yenilemesi — dort tetikleyici ("53 daire" bayat sayac hatasi).
///
/// Iddia: her tetikleyici sayac/akis saglayicilarini YENIDEN hesaplatir ve bu
/// sirada ONCEKI deger ekranda kalir (iskelet YALNIZ ilk yuklemede). Testler
/// gercek aga cikmaz: saglayicilar sayac artiran sahte uclarla override edilir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/home/data/activity_api.dart';
import 'package:mobile/src/features/home/data/home_api.dart';
import 'package:mobile/src/features/home/domain/activity_models.dart';
import 'package:mobile/src/features/home/domain/home_varyant.dart';
import 'package:mobile/src/features/home/presentation/home_refresh.dart';
import 'package:mobile/src/features/shifts/data/shifts_api.dart';

/// Kac kez cagrildigini sayan sahte uc.
class _Sayac {
  int cagri = 0;
  int sonraki() => ++cagri;
}

/// Ana ekran yerine SADE bir govde: yenilemenin saglayicilara dokundugunu
/// olcmek icin ekranin tamamina gerek yok.
class _Ekran extends ConsumerWidget {
  const _Ekran({required this.varyant});

  final HomeVaryant varyant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daire = ref.watch(toplamDaireSayisiProvider);
    final akis = ref.watch(sonHareketlerProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => homeVerisiniYenile(ref, varyant),
        child: ListView(
          children: [
            // hasValue iken ESKI deger cizilir (yenileme sirasinda titreme yok).
            Text(daire.hasValue ? 'Daire: ${daire.value}' : 'Daire: iskelet'),
            Text('Akış: ${akis.value?.length ?? -1}'),
            const SizedBox(height: 800), // pull-to-refresh icin kaydirilabilir
          ],
        ),
      ),
    );
  }
}

// NOT: `Override` tipi flutter_riverpod 3'te export edilmiyor — donus tipi
// bilerek yazilmadi (fab_menu_test.dart ile ayni desen).
// ignore: strict_top_level_inference
_overrides(_Sayac daire, _Sayac akis) => [
      toplamDaireSayisiProvider.overrideWith((ref) async => daire.sonraki()),
      sonHareketlerProvider.overrideWith(
        (ref) async => List.generate(
          akis.sonraki(),
          (i) => ActivityItem(
            id: 'talep:$i',
            tur: ActivityTur.talep,
            baslikKimlik: AkisBaslik.talepAcik,
            veri: {'baslik': 'Olay $i'},
            zaman: DateTime(2026, 7, 25),
            kaynakId: '$i',
          ),
        ),
      ),
      shiftsProvider.overrideWith((ref) async => const []),
    ];

void main() {
  testWidgets('(3) asagi cekip yenileme: sayac saglayicilari YENIDEN sorulur',
      (tester) async {
    final daire = _Sayac();
    final akis = _Sayac();
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(daire, akis),
      child: MaterialApp(
        home: HomeCanliVeri(
          varyant: HomeVaryant.yonetici,
          child: const _Ekran(varyant: HomeVaryant.yonetici),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Daire: 1'), findsOneWidget);
    expect(daire.cagri, 1);

    // Asagi cek (RefreshIndicator).
    await tester.fling(find.byType(ListView), const Offset(0, 320), 1000);
    await tester.pumpAndSettle();

    expect(daire.cagri, 2, reason: 'pull-to-refresh sayaci yenilemeli');
    expect(find.text('Daire: 2'), findsOneWidget);
  });

  testWidgets('(2) on plana donus: tam yenileme tetiklenir', (tester) async {
    final daire = _Sayac();
    final akis = _Sayac();
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(daire, akis),
      child: MaterialApp(
        home: HomeCanliVeri(
          varyant: HomeVaryant.yonetici,
          child: const _Ekran(varyant: HomeVaryant.yonetici),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(daire.cagri, 1);

    // Arka plan → on plan (WidgetsBindingObserver).
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(daire.cagri, 2);
  });

  testWidgets('(1) baska ekrandan DONUS: yenileme tetiklenir (RouteAware)',
      (tester) async {
    final daire = _Sayac();
    final akis = _Sayac();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(daire, akis),
      child: MaterialApp(
        navigatorKey: navigator,
        // Ana ekranin gozlemcisi router'a takilidir; testte de ayni gozlemci.
        navigatorObservers: [homeRouteObserver],
        home: HomeCanliVeri(
          varyant: HomeVaryant.yonetici,
          child: const _Ekran(varyant: HomeVaryant.yonetici),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(daire.cagri, 1);

    // Ustune bir ekran ac...
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('detay'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('detay'), findsOneWidget);
    expect(daire.cagri, 1, reason: 'ustteki ekranda yenileme YAPILMAZ');

    // ...ve geri don → yenileme.
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(daire.cagri, 2);
  });

  testWidgets('(4) periyodik yumusak yenileme: 45 sn sonra sayac artar, '
      'zamanlayici arka planda DURUR', (tester) async {
    final daire = _Sayac();
    final akis = _Sayac();
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(daire, akis),
      child: MaterialApp(
        home: HomeCanliVeri(
          varyant: HomeVaryant.yonetici,
          child: const _Ekran(varyant: HomeVaryant.yonetici),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(daire.cagri, 1);

    await tester.pump(const Duration(seconds: 46));
    await tester.pumpAndSettle();
    expect(daire.cagri, 2, reason: 'periyodik yumusak yenileme');

    // Arka plana gecince zamanlayici durur: sure gecse de yenileme YOK.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(const Duration(seconds: 120));
    await tester.pumpAndSettle();
    expect(daire.cagri, 2, reason: 'arka planda zamanlayici durmali');
  });

  testWidgets('yenileme sirasinda ESKI deger ekranda kalir (TITREME YOK)',
      (tester) async {
    final daire = _Sayac();
    final akis = _Sayac();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        // Ikinci cagri GECIKMELI: arada iskelet gorunmemeli.
        toplamDaireSayisiProvider.overrideWith((ref) async {
          final n = daire.sonraki();
          if (n > 1) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
          }
          return n;
        }),
        ..._overrides(_Sayac(), akis).skip(1),
      ],
      child: MaterialApp(
        home: HomeCanliVeri(
          varyant: HomeVaryant.yonetici,
          child: const _Ekran(varyant: HomeVaryant.yonetici),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Daire: 1'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(); // yenileme basladi, yeni deger HENUZ yok
    expect(find.text('Daire: iskelet'), findsNothing);
    expect(find.text('Daire: 1'), findsOneWidget, reason: 'onceki deger kalir');

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Daire: 2'), findsOneWidget);
  });
}
