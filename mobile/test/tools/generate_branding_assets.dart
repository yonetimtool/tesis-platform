// Launcher-icon kaynak PNG'lerini ORTAK painter'dan (YonetioLogoPainter) uretir
// — ortamda SVG rasterizer olmadigindan dart:ui ile. Dosya adi `_test.dart` ile
// bitmedigi icin `flutter test` (argumansiz) bunu ATLAR; acikca calistirilir:
//
//   flutter test test/tools/generate_branding_assets.dart
//
// Cikti (flutter_launcher_icons girdisi):
//   assets/branding/icon_1024.png            (tam ikon: navy zemin + isaret)
//   assets/branding/icon_foreground_1024.png (adaptive foreground; guvenli
//                                             bolgede ~%66 merkezli, seffaf)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/branding/yonetio_logo.dart';

Future<void> _writePng(String path, ui.Image image) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<ui.Image> _render(void Function(Canvas, Size) paint, int px) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paint(canvas, Size(px.toDouble(), px.toDouble()));
  final picture = recorder.endRecording();
  return picture.toImage(px, px);
}

void main() {
  const dir = 'assets/branding';

  test('tam ikon PNG uret (navy zemin + isaret)', () async {
    const painter = YonetioLogoPainter(background: true);
    final img = await _render(painter.paint, 1024);
    await _writePng('$dir/icon_1024.png', img);
    expect(File('$dir/icon_1024.png').existsSync(), isTrue);
  });

  test('adaptive foreground PNG uret (seffaf, guvenli bolge ~%66)', () async {
    const painter = YonetioLogoPainter(background: false);
    // 1024 seffaf tuval; isaret merkezde 0.66 olcekte (adaptive safe zone).
    final img = await _render((canvas, size) {
      const scale = 0.66;
      final inner = size.width * scale;
      final off = (size.width - inner) / 2;
      canvas.save();
      canvas.translate(off, off);
      painter.paint(canvas, Size(inner, inner));
      canvas.restore();
    }, 1024);
    await _writePng('$dir/icon_foreground_1024.png', img);
    expect(File('$dir/icon_foreground_1024.png').existsSync(), isTrue);
  });
}
