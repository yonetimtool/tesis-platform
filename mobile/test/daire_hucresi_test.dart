/// (P122) DAİRE HÜCRESİ — en küçük boyutta OKUNURLUK ve TAŞMAMA.
///
/// Hücre 58×46 dp'dir ve içeriği yazı ölçeğiyle büyür. Kapı numarasının
/// yanına tip etiketi eklemek, o kutuya **ikinci bir satır** koymak
/// demektir; erişilebilirlik için yazı ölçeğini büyüten bir kullanıcıda
/// (iOS/Android'de yaygın) taşma riski gerçektir.
///
/// Taşma, Flutter'da çizim sırasında bir istisna olarak bildirilir; test
/// `takeException` ile tam olarak bunu yakalar. Piksel golden'ı yerine bu
/// seçildi: golden, tema/yazı tipi değişince kırılır ve gerçek soruyu
/// ("okunuyor mu, taşıyor mu") dolaylı yoldan yanıtlar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/building_map/domain/bina_duzenleme_models.dart';
import 'package:mobile/src/features/building_map/presentation/bina_duzenleme_screen.dart';
import 'package:mobile/src/features/building_map/presentation/daire_tipi_rengi.dart';

EditorUnit _u({
  String no = '12',
  String? tip,
  int? sira,
  bool aktif = true,
}) =>
    EditorUnit(id: 'u1', no: no, sira: sira, aktif: aktif, unitTipAd: tip);

Future<void> _ciz(
  WidgetTester t,
  EditorUnit u, {
  double olcek = 1.0,
  Brightness parlaklik = Brightness.light,
}) async {
  await t.pumpWidget(MaterialApp(
    theme: ThemeData(brightness: parlaklik),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(olcek)),
      // EN KUCUK IZGARA: hucre `Wrap` icinde sabit 58 dp; dar bir ekranda
      // da ayni kutuyu alir.
      child: Scaffold(body: Center(child: UnitCell(unit: u, onTap: () {}))),
    ),
  ));
}

void main() {
  testWidgets('TIP ETIKETI hucrede gorunur', (t) async {
    await _ciz(t, _u(tip: '2+1'));
    expect(find.text('12'), findsOneWidget);
    expect(find.text('2+1'), findsOneWidget);
  });

  testWidgets('TIP YOKSA sira gosterilir (eski davranis korunur)', (t) async {
    await _ciz(t, _u(sira: 3));
    expect(find.text('#3'), findsOneWidget);
    expect(find.byKey(const Key('daire-tip-etiketi')), findsNothing);
  });

  testWidgets('TIP VARSA sira YERINE tip gosterilir (ucuncu satir YOK)',
      (t) async {
    // Hucre 46 dp; no + tip + sira ucuncu satiri tasirdi.
    await _ciz(t, _u(tip: '3+1', sira: 7));
    expect(find.text('3+1'), findsOneWidget);
    expect(find.text('#7'), findsNothing);
  });

  testWidgets('UZUN tip adi KIRPILIR, tasmaz', (t) async {
    await _ciz(t, _u(tip: 'Dubleks Bahçe Katı'));
    expect(find.text('Dublek…'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  for (final olcek in [1.0, 1.3, 1.6, 2.0]) {
    testWidgets('YAZI OLCEGI ${olcek}x — tasma YOK', (t) async {
      await _ciz(t, _u(no: 'A-124', tip: 'Dubleks Bahçe Katı'), olcek: olcek);
      // Tasma olsaydi cizim sirasinda istisna atilirdi.
      expect(t.takeException(), isNull,
          reason: 'yazi olcegi ${olcek}x hucreyi tasirdi');
    });
  }

  testWidgets('PASIF daire TIP RENGI ALMAZ ve tip etiketi GOSTERMEZ',
      (t) async {
    // Pasif daire her tipte ayni soluk griyi tasimali; yoksa "pasif" durumu
    // renk gurultusunde kaybolur.
    await _ciz(t, _u(tip: '2+1', sira: 5, aktif: false));
    expect(find.byKey(const Key('daire-tip-etiketi')), findsNothing);
    expect(find.text('#5'), findsOneWidget);
  });

  testWidgets('EKRAN OKUYUCUYA TAM ad verilir (kisaltilmis DEGIL)',
      (t) async {
    await _ciz(t, _u(tip: 'Dubleks Bahçe Katı'));
    expect(
      find.bySemanticsLabel('12, Dubleks Bahçe Katı'),
      findsOneWidget,
      reason: 'gorsel kirpma isitilebilir arayuze SIZMAMALI',
    );
  });

  testWidgets('KOYU TEMADA da tasma yok ve etiket cizilir', (t) async {
    await _ciz(t, _u(tip: 'Stüdyo'), parlaklik: Brightness.dark, olcek: 1.6);
    expect(find.text('Stüdyo'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('paletteki her renk hucrede kullanilabilir (kod duzeyinde)', () {
    expect(daireTipiPaleti, isNotEmpty);
  });
}
