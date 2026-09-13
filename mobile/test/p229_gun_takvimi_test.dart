import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/shifts/presentation/widgets/gun_takvimi.dart';

import 'helpers/l10n_test_app.dart';

/// (P229 §2) VARDIYA GUN TAKVIMI — coklu secim.
///
/// Web'de (P207/P214) ay gorunumu + keyfi coklu secim VARDI; mobilde
/// yalniz BITISIK ARALIK secilebiliyordu. Bu dosya mobil tarafin
/// davranisini kilitler.

/// Takvimi SABIT bir ayla cizer: `DateTime.now()` ile calisan bir test
/// ayin son gunlerinde (ornegin 31 Ocak) bir sonraki aya kayar ve
/// KODA BAGLI OLMAYAN bir kirmizi uretirdi.
final _ay = DateTime(2026, 3); // Mart 2026: 1'i PAZAR, 31 gun.

Widget _kur(Set<String> secili, void Function(Set<String>) onDegisti,
        {Locale locale = const Locale('tr')}) =>
    l10nApp(
      Scaffold(
        body: SingleChildScrollView(
          child: GunTakvimi(
            ay: _ay,
            secili: secili,
            onDegisti: onDegisti,
          ),
        ),
      ),
      locale: locale,
    );

void main() {
  testWidgets('DOKUN: gunu ekler, tekrar dokunmak CIKARIR', (tester) async {
    var secili = <String>{};
    await tester.pumpWidget(
        _kur(secili, (y) => secili = y));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('vardiya-takvim-gun-2026-03-05')));
    expect(secili, {'2026-03-05'});

    await tester.pumpWidget(_kur(secili, (y) => secili = y));
    await tester.tap(find.byKey(const Key('vardiya-takvim-gun-2026-03-05')));
    expect(secili, isEmpty, reason: 'ikinci dokunus SECIMI KALDIRMALI');
  });

  testWidgets('DOKUN: BITISIK OLMAYAN gunler secilebilir', (tester) async {
    // Istegin ta kendisi. `showDateRangePicker` bunu YAPAMAZ — bilesenin
    // varlik sebebi budur.
    var secili = <String>{};
    for (final g in ['2026-03-03', '2026-03-07', '2026-03-19']) {
      await tester.pumpWidget(_kur(secili, (y) => secili = y));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('vardiya-takvim-gun-$g')));
    }
    expect(secili, {'2026-03-03', '2026-03-07', '2026-03-19'});
  });

  testWidgets('UZUN BAS: son secilenden buraya kadar ARALIGI doldurur',
      (tester) async {
    var secili = <String>{};
    await tester.pumpWidget(_kur(secili, (y) => secili = y));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vardiya-takvim-gun-2026-03-10')));

    await tester.pumpWidget(_kur(secili, (y) => secili = y));
    await tester.pumpAndSettle();
    await tester.longPress(
        find.byKey(const Key('vardiya-takvim-gun-2026-03-13')));
    expect(secili,
        {'2026-03-10', '2026-03-11', '2026-03-12', '2026-03-13'});
  });

  testWidgets('UZUN BAS: hicbir sey secili degilken TEKIL gibi davranir',
      (tester) async {
    // Aksi hâlde jest SESSIZCE hicbir sey yapardi ve kullanici
    // bilesenin bozuk oldugunu sanirdi.
    var secili = <String>{};
    await tester.pumpWidget(_kur(secili, (y) => secili = y));
    await tester.pumpAndSettle();
    await tester
        .longPress(find.byKey(const Key('vardiya-takvim-gun-2026-03-08')));
    expect(secili, {'2026-03-08'});
  });

  testWidgets('HAFTA GUNU BASLIGI: ayin TUM o gunlerini secer',
      (tester) async {
    // P207'de web'de vardi ("tum pazartesiler"); onsuz yonetici ayin
    // dort pazartesisini TEK TEK dokunarak secerdi.
    var secili = <String>{};
    await tester.pumpWidget(_kur(secili, (y) => secili = y));
    await tester.pumpAndSettle();
    // 1 = pazartesi. Mart 2026'da pazartesiler: 2, 9, 16, 23, 30.
    await tester.tap(find.byKey(const Key('vardiya-takvim-haftagunu-1')));
    expect(secili,
        {'2026-03-02', '2026-03-09', '2026-03-16', '2026-03-23', '2026-03-30'});
  });

  testWidgets('DOKUNMA HEDEFI 48dp altina DUSMEZ (P220 kilidi)',
      (tester) async {
    // 320dp'de 7 sutun ~45dp'ye duser; GENISLIK daralabilir ama
    // YUKSEKLIK 48'de sabit kalmali.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_kur({}, (_) {}));
    await tester.pumpAndSettle();
    final boyut =
        tester.getSize(find.byKey(const Key('vardiya-takvim-gun-2026-03-15')));
    expect(boyut.height, greaterThanOrEqualTo(kMinInteractiveDimension));
  });

  testWidgets('SECILI GUN EKRAN OKUYUCUDA da isaretli', (tester) async {
    // Renk TEK BASINA yetmez: secim yalniz dolgu rengiyle anlatilsaydi
    // ekran okuyucu kullanan yonetici hangi gunleri sectigini bilemezdi.
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_kur({'2026-03-15'}, (_) {}));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byKey(const Key('vardiya-takvim-gun-2026-03-15'))),
      matchesSemantics(isSelected: true, isButton: true, hasTapAction: true,
          hasLongPressAction: true, hasSelectedState: true, isFocusable: true,
          hasFocusAction: true, label: '15'),
    );
    handle.dispose();
  });

  testWidgets('7 DILDE cizilir ve TASMA uretmez', (tester) async {
    // Gun adlari sozlukten DEGIL `DateFormat.E(dil)`den geliyor; bir dil
    // icin yerel veri yuklenmemisse ekran burada duser.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final d in ['tr', 'en', 'de', 'fr', 'es', 'ru', 'ar']) {
      await tester.pumpWidget(_kur({}, (_) {}, locale: Locale(d)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: d);
      expect(find.byKey(const Key('vardiya-takvim-gun-2026-03-15')),
          findsOneWidget,
          reason: d);
    }
  });
}
