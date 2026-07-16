// Marka yuzeylerinin GORSEL onizlemesi — giris ekrani logosu (acik/koyu) ve
// ana ekran app-bar isareti. Otomatik test degil, GOZLE bakmak icin: renk,
// olcek ve koyu-tema davranisi ancak boyle dogrulanir.
//
// Dosya adi `_test.dart` ile BITMEDIGI icin `flutter test` (argumansiz) bunu
// ATLAR. Acikca calistirilir:
//
//   flutter test test/tools/preview_branding_screens.dart
//
// Cikti: $TMPDIR/preview_login_{light,dark}.png, preview_appbar.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/branding/yonetio_logo.dart';

Future<void> _shoot(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('shot')),
  );
  // toImage GERCEK async'tir → runAsync sart; testWidgets'in sahte zaman
  // bolgesinde tamamlanmaz.
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('${Directory.systemTemp.path}/$name.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _pump(
  WidgetTester tester,
  Brightness brightness,
  Widget child,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness, useMaterial3: true),
      home: RepaintBoundary(
        key: const Key('shot'),
        child: child,
      ),
    ),
  );
  // Image.asset dosya okuma + PNG cozme yapar: bunlar GERCEK async'tir ve
  // testWidgets'in sahte zaman bolgesinde ASLA tamamlanmaz — onbellege
  // runAsync icinde alinmazsa logo bos cikar. Onbellege alindiktan sonra
  // sonraki pump senkron cizer.
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element);
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('giris ekrani logosu — acik tema', (tester) async {
    tester.view.physicalSize = const Size(420, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _pump(
      tester,
      Brightness.light,
      const Scaffold(body: Center(child: YonetioLogoVertical(iconSize: 120))),
    );
    await _shoot(tester, 'preview_login_light');
  });

  testWidgets('giris ekrani logosu — koyu tema (kelime isareti beyaz olmali)',
      (tester) async {
    tester.view.physicalSize = const Size(420, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _pump(
      tester,
      Brightness.dark,
      const Scaffold(body: Center(child: YonetioLogoVertical(iconSize: 120))),
    );
    await _shoot(tester, 'preview_login_dark');
  });

  testWidgets('ana ekran app-bar — basitlestirilmis isaret', (tester) async {
    tester.view.physicalSize = const Size(420, 120);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _pump(
      tester,
      Brightness.light,
      Scaffold(
        appBar: AppBar(
          leading: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Center(child: YonetioSimpleMark(size: 30)),
          ),
          leadingWidth: 54,
          title: const Text('Yesil Vadi Sitesi'),
        ),
      ),
    );
    await _shoot(tester, 'preview_appbar');
  });
}
