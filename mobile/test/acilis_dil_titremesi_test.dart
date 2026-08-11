/// ACILIS TITREMESI (regresyon): ilk boyanan kare ZATEN kayitli dilde olmali.
///
/// KUSUR: dil/tema tercihi guvenli depodan ASENKRON okunuyordu; denetleyiciler
/// once varsayilani dondurup (dil → CIHAZ dili) deger gelince `state`'i
/// degistiriyordu. Cihaz dili secilen dilden farkliysa uygulama ilk kareyi
/// yanlis dille boyayip hemen yeniden ciziyordu — gorunen METIN TITREMESI.
///
/// COZUM: tercihler `runApp`'ten ONCE okunur ve [acilisTercihleriProvider] ile
/// tohumlanir. Asagidaki testler tohumsuz (eski) davranisi da olcer; ikisinin
/// FARKI kusurun ta kendisidir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:mobile/src/core/i18n/locale_controller.dart';
import 'package:mobile/src/core/startup/acilis_tercihleri.dart';
import 'package:mobile/src/core/theme/theme_controller.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/push/presentation/push_setup.dart';
import 'package:mobile/src/features/scan/data/scan_outbox.dart';

import 'helpers/bellek_depo.dart';

import 'helpers/sosyal_kapali.dart';

class _FakeOutbox extends ScanOutbox {
  @override
  ScanOutboxState build() => const ScanOutboxState(loaded: true);
}

/// Uygulama koku. [tohum] null ise `runApp` oncesi on-okuma YAPILMAMIS gibi
/// davranir (kusurun yasadigi eski yol).
///
/// NOT: on-okuma `main()` icinde `runApp`'ten ONCE ve widget agaci disinda
/// tamamlanir; testte de ayni sekilde HAZIR deger olarak verilir (sahte saat
/// altinda `await` etmek kilitlenmeye yol acar).
Widget _uygulama(BellekDepo depo, {AcilisTercihleri? tohum}) {
  return ProviderScope(
    overrides: [...sosyalKapali, 
      secureStorageProvider.overrideWithValue(depo),
      if (tohum != null) acilisTercihleriProvider.overrideWithValue(tohum),
      outboxAutoSyncProvider.overrideWithValue(null),
      pushSetupProvider.overrideWithValue(null),
      scanOutboxProvider.overrideWith(_FakeOutbox.new),
    ],
    child: const TesisGuvenlikApp(),
  );
}

/// O an gecerli dil — uygulamanin ICINDEN (Localizations cozumu). Ilk karede
/// yonlendirici henuz sayfa insa etmemis olabilir; bu yuzden `Localizations`
/// widget'inin ALTINDAKI ilk eleman uzerinden okunur.
String _dil(WidgetTester tester) {
  final el = find
      .descendant(
        of: find.byType(Localizations).first,
        matching: find.byType(Directionality),
      )
      .evaluate()
      .first;
  return Localizations.localeOf(el).languageCode;
}

void main() {
  setUp(() {
    // CIHAZ dili Ingilizce; KAYITLI secim Turkce olacak → ikisi FARKLI.
    // Titreme tam da bu farkta gorunur.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('ILK KARE kayitli dilde boyanir (cihaz: en, secim: tr) ve '
      'sonrasinda DEGISMEZ', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    // Depo GERCEKCI: platform kanali gibi gecikir (yaris ancak boyle gorunur).
    await tester.pumpWidget(_uygulama(
      BellekDepo({'ui.locale': 'tr'}, const Duration(milliseconds: 30)),
      tohum: const AcilisTercihleri(dil: AppDil.tr),
    ));
    await tester.pump(); // ILK kare

    final ilkKare = _dil(tester);
    expect(ilkKare, 'tr', reason: 'ilk kare kayitli dilde boyanmali');

    // Yerlesme tamamlandiktan sonra dil DEGISMEMELI (= titreme yok).
    await tester.pump(const Duration(seconds: 1));
    expect(_dil(tester), ilkKare, reason: 'acilistan sonra dil degisemez');
  });

  testWidgets('TOHUMSUZ (eski yol) ilk kare CIHAZ dilinde acilip sonra '
      'degisiyordu — kusurun kaydi', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(_uygulama(
        BellekDepo({'ui.locale': 'tr'}, const Duration(milliseconds: 30))));
    await tester.pump();

    expect(_dil(tester), 'en'); // ilk kare: cihaz dili
    await tester.pump(const Duration(seconds: 1));
    expect(_dil(tester), 'tr'); // ...ve sonra degisiyor = TITREME
  });

  testWidgets('secim yoksa ilk kare CIHAZ dilinde acilir ve degismez',
      (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('de')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(
        _uygulama(BellekDepo(), tohum: const AcilisTercihleri()));
    await tester.pump();
    expect(_dil(tester), 'de');
    await tester.pump(const Duration(seconds: 1));
    expect(_dil(tester), 'de');
  });

  testWidgets('desteklenmeyen cihaz dili → TURKCE (ilk kareden itibaren)',
      (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ja')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(
        _uygulama(BellekDepo(), tohum: const AcilisTercihleri()));
    await tester.pump();
    expect(_dil(tester), 'tr');
  });

  group('tema tercihi de ilk kareden itibaren gecerli (acik/koyu cakmasi yok)',
      () {
    test('on-okuma tema modunu da getirir', () async {
      final t = await acilisTercihleriniOku(BellekDepo({
        'ui.locale': 'ar',
        'ui.theme_mode': 'dark',
      }));
      expect(t.dil?.kod, 'ar');
      expect(t.temaModu, ThemeMode.dark);
    });

    test('tohumlanan container ILK okumada koyu temayi verir', () async {
      final depo = BellekDepo({'ui.theme_mode': 'dark'});
      final container = ProviderContainer(overrides: [...sosyalKapali, 
        secureStorageProvider.overrideWithValue(depo),
        acilisTercihleriProvider
            .overrideWithValue(await acilisTercihleriniOku(depo)),
      ]);
      addTearDown(container.dispose);
      // Hic beklemeden (ilk kare esdegeri) dogru mod.
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('bozuk/eksik depo degeri acilisi KILITLEMEZ (varsayilanlara duser)',
        () async {
      final t = await acilisTercihleriniOku(BellekDepo({
        'ui.locale': 'klingon',
        'ui.theme_mode': 'neon',
      }));
      expect(t.dil, isNull);
      expect(t.temaModu, isNull);
    });
  });
}
