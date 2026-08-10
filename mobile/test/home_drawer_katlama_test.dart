/// (P154 / Asama 7.1) CEKMECE KATLAMA — davranis + kaliciligi.
///
/// `home_menu_grup_test.dart` VERIYI olcuyor (hangi modul hangi bolumde);
/// bu dosya CIZIMI olcuyor. Ikisi ayri hata sinifi: gruplama dogru olup
/// cekmecenin onu okumamasi da mumkundur.
///
/// EN PAHALI SONUC: katlamanin KALICI OLMAMASI. Tercih widget'in yerel
/// `State`inde tutulsaydi cekmece her kapanip acilista sifirlanir ve
/// katlama bir kolaylik degil bir ENGEL olurdu — kullanici her seferinde
/// ayni bolumu yeniden acardi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/gen/app_localizations.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/data/menu_bolum_tercihi.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';
import 'package:mobile/src/features/home/presentation/widgets/home_drawer.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';

/// ROL SAHTELENIR VE BU SART: tercih anahtari rol basinadir
/// (`ui.menu_bolum_kapali.<rol>`). Rol `unknown` kalirsa denetleyici
/// HICBIR SEY YAZMAZ — olculdu: kaliciligi sinayan test o hâlde YANLIS
/// SEBEPLE geciyordu.
ProviderScope _kapsam(BellekDepo depo, {required Widget child}) =>
    ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(depo),
        currentUserRoleProvider.overrideWith((ref) async => UserRole.yonetici),
      ],
      child: child,
    );

ProviderContainer _konteyner(BellekDepo depo) => ProviderContainer(
  overrides: [
    secureStorageProvider.overrideWithValue(depo),
    currentUserRoleProvider.overrideWith((ref) async => UserRole.yonetici),
  ],
);

Widget _cekmece(BellekDepo depo) => _kapsam(
  depo,
  child: l10nApp(
    Scaffold(
      body: HomeDrawer(role: UserRole.yonetici, onModul: (_) {}),
    ),
  ),
);

/// Bir bolumun basligi (dugme gorevi goren satir).
Finder _baslik(String metin) => find.text(metin);

void main() {
  testWidgets('BOLUM BASLIKLARI cizilir ve ogeler altinda durur', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_cekmece(BellekDepo()));
    await tester.pumpAndSettle();

    // Yoneticinin bolumleri — VERIDEN turetiliyor, elle yazilmiyor;
    // menu degisince test bosa gecmesin.
    final gruplar = homeMenuGruplariForRole(UserRole.yonetici);
    expect(gruplar.length, greaterThan(1));
    for (final g in gruplar.keys) {
      expect(
        _baslik(_ad(tester, g)),
        findsOneWidget,
        reason: '${g.name} basligi cizilmedi',
      );
    }
  });

  testWidgets('BASLIGA dokununca bolum KAPANIR — ogeler AGACTAN CIKAR', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_cekmece(BellekDepo()));
    await tester.pumpAndSettle();

    final gruplar = homeMenuGruplariForRole(UserRole.yonetici);
    final grup = gruplar.keys.first;
    final ilkModul = gruplar[grup]!.first;
    final modulAdi = _modulAdi(tester, ilkModul);

    expect(find.text(modulAdi), findsOneWidget);

    await tester.tap(_baslik(_ad(tester, grup)));
    await tester.pumpAndSettle();

    // "Gorunmez ama odaklanilabilir" satir, ekran okuyucuyla gezinmenin en
    // can sikici hatasidir: oge agactan TAMAMEN cikmali.
    expect(find.text(modulAdi), findsNothing);
  });

  testWidgets('KARAR SAKLANIR — yeni bir agacta da kapali gelir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // AYNI depo, IKI ayri widget agaci = "uygulama yeniden basladi".
    final depo = BellekDepo();
    await tester.pumpWidget(_cekmece(depo));
    await tester.pumpAndSettle();

    final gruplar = homeMenuGruplariForRole(UserRole.yonetici);
    final grup = gruplar.keys.first;
    final modulAdi = _modulAdi(tester, gruplar[grup]!.first);

    await tester.tap(_baslik(_ad(tester, grup)));
    await tester.pumpAndSettle();
    expect(find.text(modulAdi), findsNothing);

    await tester.pumpWidget(_cekmece(depo));
    await tester.pumpAndSettle();
    expect(
      find.text(modulAdi),
      findsNothing,
      reason: 'katlama karari saklanmadi',
    );
    // TESTIN BOSA GECMEDIGINI KANITLA: `pumpWidget` ayni tipte bir agaci
    // YENIDEN KULLANIR, yani `ProviderContainer` da yasamaya devam eder —
    // ikinci cizimin kapali gelmesi TEK BASINA kaliciligi kanitlamaz.
    // Gercek kanit: (a) deponun yazilmis olmasi, (b) SIFIRDAN bir
    // konteynerin ayni karari OKUYABILMESI.
    expect(
      depo.kutu.keys.where((k) => k.startsWith('ui.menu_bolum_kapali')),
      isNotEmpty,
      reason: 'hicbir sey yazilmadi — test yanlis sebeple geciyor',
    );
  });

  // AYRI ve SAF bir test: `testWidgets` SAHTE SAAT altinda kosar ve orada
  // `await Future.delayed(...)` bir `pump` olmadan ASLA tamamlanmaz —
  // olculdu: kalicilik iddiasini widget testine koyunca kosum 10 dakika
  // asilip dustu. Depodan okuma gercek bir asenkron istir; yeri burasi.
  test('KALICI: SIFIRDAN bir konteyner ayni karari okur', () async {
    final depo = BellekDepo();
    final grup = homeMenuGruplariForRole(UserRole.yonetici).keys.first;

    final ilk = _konteyner(depo);
    addTearDown(ilk.dispose);
    await ilk.read(currentUserRoleProvider.future);
    await ilk.read(menuBolumTercihiProvider.notifier).cevir(grup);
    expect(depo.kutu, contains('ui.menu_bolum_kapali.yonetici'));

    final taze = _konteyner(depo);
    addTearDown(taze.dispose);
    // DINLEYICI SART: `read` tek seferlik bir okumadir ve dinleyicisi
    // olmayan bir saglayici, rol cozulunce KENDILIGINDEN yeniden
    // hesaplanmaz. Gercek uygulamada bu dinleyici widget'in kendisidir;
    // testte de bir tane kurulmali, yoksa "yuklenmiyor" sonucu urunun
    // degil kurulumun kusuru olur.
    taze.listen(menuBolumTercihiProvider, (_, _) {});
    await taze.read(currentUserRoleProvider.future);
    // Depodan okuma gercek bir asenkron istir; tek mikro-gorev yetmez.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      taze.read(menuBolumTercihiProvider),
      contains(grup),
      reason: 'sifirdan konteyner karari okuyamadi',
    );
  });

  testWidgets('BOZUK KAYIT cekmeceyi KIRMAZ (tum bolumler acik)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final depo = BellekDepo({'ui.menu_bolum_kapali.yonetici': 'bu json degil'});
    await tester.pumpWidget(_cekmece(depo));
    await tester.pumpAndSettle();

    final gruplar = homeMenuGruplariForRole(UserRole.yonetici);
    final modulAdi = _modulAdi(tester, gruplar.values.first.first);
    expect(find.text(modulAdi), findsOneWidget);
  });
}

// --------------------------------------------------------------------------
// Etiketler AGACTAN okunur (sabit Turkce yazmak, dil degisince testi
// yalancilastirirdi).
// --------------------------------------------------------------------------
String _ad(WidgetTester tester, HomeMenuGrup g) =>
    homeMenuGrupBasligi(_l10n(tester), g);

String _modulAdi(WidgetTester tester, HomeMenuEntry e) =>
    moduleBaslik(_l10n(tester), e);

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(HomeDrawer)));
