// Marka varlik ureticisi — TEK kaynak: assets/branding/logo_master.png
// (saglanan hazir logo; yeniden tasarlanmaz). Ortamda PIL/ImageMagick yok;
// dart:ui PNG'yi natif cozer, bu yuzden tum turevler burada uretilir.
//
// Dosya adi `_test.dart` ile BITMEDIGI icin `flutter test` (argumansiz) bunu
// ATLAR. Acikca calistirilir:
//
//   flutter test test/tools/generate_branding_assets.dart
//
// Cikti:
//   assets/branding/icon_master.png      kirpilmis kare master (launcher +
//                                        giris + splash kaynagi)
//   assets/branding/icon_background.png  adaptive zemin: master'dan orneklenen
//                                        mavi→teal gradyan
//   assets/branding/icon_foreground.png  adaptive on katman: beyaz isaret,
//                                        seffaf zemin, %66 guvenli bolgede
//   android/.../drawable-*/ic_stat_yonetio.png
//                                        bildirim kucuk ikonu — basitlestirilmis
//                                        isaret, beyaz-on-seffaf (Android bunu
//                                        alfa maskesi olarak boyar: monokrom
//                                        ZORUNLU)
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/branding/yonetio_logo.dart';

const _dir = 'assets/branding';
const _resDir = 'android/app/src/main/res';

/// Master'in yuvarlak-kare kose yaricapi (kenar oranı) — kirpma sonrasi
/// gorsel olcumden. Isaret cikarilirken kose disindaki beyaz kenar bosluğunu
/// elemek icin kullanilir.
const _cornerRadiusRatio = 0.22;

Future<void> _writePng(String path, ui.Image image) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<ui.Image> _decode(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

Future<ui.Image> _render(void Function(Canvas, Size) paint, int px) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paint(canvas, Size(px.toDouble(), px.toDouble()));
  return recorder.endRecording().toImage(px, px);
}

/// RGBA piksel erisimi — oto-kirpma, gradyan ornekleme, isaret cikarma.
class _Pixels {
  _Pixels(this.data, this.width, this.height);

  final ByteData data;
  final int width;
  final int height;

  static Future<_Pixels> of(ui.Image img) async {
    final d = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    return _Pixels(d!, img.width, img.height);
  }

  int _at(int x, int y) => data.getUint32((y * width + x) * 4);

  int r(int x, int y) => (_at(x, y) >> 24) & 0xFF;
  int g(int x, int y) => (_at(x, y) >> 16) & 0xFF;
  int b(int x, int y) => (_at(x, y) >> 8) & 0xFF;
  int a(int x, int y) => _at(x, y) & 0xFF;

  /// En kucuk renk kanali — "beyazlik" olcusu. Gradyan zeminin en parlak
  /// noktasinda bile bir kanal dusuktur (teal'in R'si, navy'nin R/G'si);
  /// beyaz isarette uc kanal da yuksektir. Ayrim bu yuzden guvenli.
  int minChannel(int x, int y) {
    final rr = r(x, y), gg = g(x, y), bb = b(x, y);
    return rr < gg ? (rr < bb ? rr : bb) : (gg < bb ? gg : bb);
  }

  bool isMargin(int x, int y) =>
      a(x, y) < 8 || (r(x, y) > 244 && g(x, y) > 244 && b(x, y) > 244);

  Color colorAt(int x, int y) =>
      Color.fromARGB(a(x, y), r(x, y), g(x, y), b(x, y));
}

/// Kenarlardan iceri tarayarak beyaz boslugu atar; sonucu kareye tamamlar.
Rect _contentBounds(_Pixels px) {
  bool rowBlank(int y) {
    for (var x = 0; x < px.width; x++) {
      if (!px.isMargin(x, y)) return false;
    }
    return true;
  }

  bool colBlank(int x) {
    for (var y = 0; y < px.height; y++) {
      if (!px.isMargin(x, y)) return false;
    }
    return true;
  }

  var top = 0, bottom = px.height - 1, left = 0, right = px.width - 1;
  while (top < bottom && rowBlank(top)) {
    top++;
  }
  while (bottom > top && rowBlank(bottom)) {
    bottom--;
  }
  while (left < right && colBlank(left)) {
    left++;
  }
  while (right > left && colBlank(right)) {
    right--;
  }

  final w = right - left + 1, h = bottom - top + 1;
  final side = (w > h ? w : h).toDouble();
  final cx = left + w / 2, cy = top + h / 2;
  final sx = (cx - side / 2).clamp(0.0, px.width - side);
  final sy = (cy - side / 2).clamp(0.0, px.height - side);
  return Rect.fromLTWH(sx, sy, side, side);
}

/// Master'in BEYAZ ISARETINI seffaf zemine cikarir (adaptive fg katmani icin).
///
/// Neden esikleme calisir: yuvarlak-kare icinde beyaz olan TEK sey isarettir —
/// gradyan zeminde her zaman bir renk kanali dusuk, yumusak golge ise koyu.
/// Yuvarlak kosenin DISINDA kalan beyaz kenar boslugu ise ayrica maskelenir,
/// yoksa kose blob'lari olarak sizardi.
///
/// [lo]..[hi] rampasi kenar yumusatmasini korur (sert esik testere yapardi).
Future<ui.Image> _extractMark(
  _Pixels px,
  Rect crop, {
  int lo = 170,
  int hi = 225,
}) async {
  final side = crop.width.round();
  final out = Uint8List(side * side * 4);

  // Maske, yuvarlak karenin kenarindan ICERI cekilir. Kaynakta yuvarlak kare
  // beyaz zemine gomulu geldiginden kenar pikselleri beyaza dogru
  // yumusatilmis; bu rim esigi gecip isaretin etrafinda hayalet bir
  // yuvarlak-kare cercevesi birakiyordu. Isaret zaten cok iceride, pay bedava.
  const insetRatio = 0.045;
  final inset = side * insetRatio;
  final maskSide = side - inset * 2;
  final radius = maskSide * _cornerRadiusRatio;

  // Yuvarlak-kare icinde mi? (kose yaylarinin disini eler)
  bool inRoundedSquare(double px0, double py0) {
    final x = px0 - inset, y = py0 - inset;
    if (x < 0 || y < 0 || x > maskSide || y > maskSide) return false;
    final dx = x < radius
        ? radius - x
        : (x > maskSide - radius ? x - (maskSide - radius) : 0.0);
    final dy = y < radius
        ? radius - y
        : (y > maskSide - radius ? y - (maskSide - radius) : 0.0);
    if (dx == 0 || dy == 0) return true; // kenar seritleri
    return dx * dx + dy * dy <= radius * radius; // kose ceyrek dairesi
  }

  for (var y = 0; y < side; y++) {
    for (var x = 0; x < side; x++) {
      final i = (y * side + x) * 4;
      final sxp = (crop.left + x).round().clamp(0, px.width - 1);
      final syp = (crop.top + y).round().clamp(0, px.height - 1);

      var alpha = 0;
      if (inRoundedSquare(x + 0.5, y + 0.5)) {
        final m = px.minChannel(sxp, syp);
        if (m >= hi) {
          alpha = 255;
        } else if (m > lo) {
          alpha = (((m - lo) / (hi - lo)) * 255).round();
        }
      }
      // rawRgba/decodeImageFromPixels ON-CARPILMIS (premultiplied) alfa
      // kullanir; beyaz icin bu (a,a,a,a) demektir.
      out[i] = alpha;
      out[i + 1] = alpha;
      out[i + 2] = alpha;
      out[i + 3] = alpha;
    }
  }

  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(out, side, side, ui.PixelFormat.rgba8888,
      completer.complete);
  return completer.future;
}

/// Saydam olmayan piksellerin sinir kutusu — isareti tuvale hassas oturtmak
/// icin (goz kararı olcek yerine olculen kutu).
Future<Rect> _alphaBounds(ui.Image img, {int threshold = 8}) async {
  final p = await _Pixels.of(img);
  var top = -1, bottom = -1, left = p.width, right = -1;
  for (var y = 0; y < p.height; y++) {
    for (var x = 0; x < p.width; x++) {
      if (p.a(x, y) <= threshold) continue;
      if (top < 0) top = y;
      bottom = y;
      if (x < left) left = x;
      if (x > right) right = x;
    }
  }
  if (top < 0) throw StateError('isaret bulunamadi: tum pikseller saydam');
  return Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    (right + 1).toDouble(),
    (bottom + 1).toDouble(),
  );
}

void main() {
  late ui.Image master;
  late _Pixels px;
  late Rect crop;

  setUpAll(() async {
    master = await _decode('$_dir/logo_master.png');
    px = await _Pixels.of(master);
    crop = _contentBounds(px);
    debugPrint(
      'MASTER ${master.width}x${master.height} -> kirpma $crop '
      '(${crop.width.toInt()}px kare)',
    );
  });

  test('icon_master.png — kirpilmis kare master, koseler SEFFAF', () async {
    final side = crop.width.round();
    // BUYUTULMEZ: kirpilmis natif boyut korunur.
    //
    // Yuvarlak karenin DISINDA kalan beyaz koseler seffaflastirilir: kaynakta
    // logo beyaz zemine gomulu geldi. Kirpilmazsa koyu temada giris ekraninda
    // beyaz kose ucgenleri olarak gorunurdu.
    final img = await _render((canvas, size) {
      final r = Radius.circular(size.width * _cornerRadiusRatio);
      canvas.clipRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          r,
        ),
      );
      canvas.drawImageRect(
        master,
        crop,
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..filterQuality = FilterQuality.high,
      );
    }, side);
    await _writePng('$_dir/icon_master.png', img);
    expect(File('$_dir/icon_master.png').existsSync(), isTrue);
  });

  test('icon_background.png — master kosesinden orneklenen gradyan', () async {
    // Kose renklerini GERCEK pikselden ornekle (elle hex tahmini yok).
    final inset = crop.width * 0.16;
    final topRight = px.colorAt(
      (crop.right - inset).round().clamp(0, px.width - 1),
      (crop.top + inset).round().clamp(0, px.height - 1),
    );
    final bottomLeft = px.colorAt(
      (crop.left + inset).round().clamp(0, px.width - 1),
      (crop.bottom - inset).round().clamp(0, px.height - 1),
    );
    debugPrint('GRADYAN ornek: bottomLeft=$bottomLeft topRight=$topRight');

    final img = await _render((canvas, size) {
      final rect = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            rect.bottomLeft,
            rect.topRight,
            [bottomLeft, topRight],
          ),
      );
    }, 1024);
    await _writePng('$_dir/icon_background.png', img);
    expect(File('$_dir/icon_background.png').existsSync(), isTrue);
  });

  test('icon_foreground.png — beyaz isaret, seffaf, dairesel maskeye sigar',
      () async {
    final mark = await _extractMark(px, crop);
    final bbox = await _alphaBounds(mark);
    debugPrint('ISARET sinir kutusu: $bbox (kaynak ${mark.width}px)');

    // Adaptive ikon geometrisi: 108dp tuval, disaridaki 18dp'lik cerceve maske
    // /paralaks payi → gorunur bolge 72dp = tuvalin %66.7'si. Maskeler bu
    // 72dp karenin icine cizilir; DAIRESEL maskede cap = %66.7.
    //
    // Isaretin dairesel maskede HIC kirpilmamasi icin sinir kutusunun
    // KOSEGENI bu capa sigmali (kutu genisligini capa esitlemek yetmez —
    // koseler daireden tasardi).
    const canvas = 1024.0;
    const maskDiameter = canvas * 0.66;
    final diagonal = math.sqrt(bbox.width * bbox.width + bbox.height * bbox.height);
    final scale = maskDiameter / diagonal;
    final w = bbox.width * scale, h = bbox.height * scale;
    debugPrint(
      'ISARET olcek=${scale.toStringAsFixed(3)} -> '
      '${w.toStringAsFixed(0)}x${h.toStringAsFixed(0)} / $canvas tuval',
    );

    final img = await _render((c, size) {
      // Sinir kutusunu tuvalin merkezine otur (kaynaktaki bosluk simetrik
      // olmayabilir; kutuya gore hizala).
      c.drawImageRect(
        mark,
        bbox,
        Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h),
        Paint()..filterQuality = FilterQuality.high,
      );
    }, canvas.round());
    await _writePng('$_dir/icon_foreground.png', img);
    expect(File('$_dir/icon_foreground.png').existsSync(), isTrue);
  });

  test('ic_stat_yonetio.png — bildirim kucuk ikonu, tum yogunluklar', () async {
    // Android kucuk ikonu ALFA MASKESI olarak boyar → renk atilir, yalniz
    // saydamlik kalir. Bu yuzden basitlestirilmis isaret, beyaz-on-seffaf.
    const densities = <String, int>{
      'mdpi': 24,
      'hdpi': 36,
      'xhdpi': 48,
      'xxhdpi': 72,
      'xxxhdpi': 96,
    };
    const painter = YonetioSimpleMarkPainter(color: Colors.white);
    for (final entry in densities.entries) {
      final img = await _render((canvas, size) {
        const scale = 0.86; // sistem ikonlarinda adet olan optik pay
        final inner = size.width * scale;
        final off = (size.width - inner) / 2;
        canvas.save();
        canvas.translate(off, off);
        painter.paint(canvas, Size(inner, inner));
        canvas.restore();
      }, entry.value);
      final path = '$_resDir/drawable-${entry.key}/ic_stat_yonetio.png';
      await _writePng(path, img);
      expect(File(path).existsSync(), isTrue);
    }
  });

  test('splash_logo.png — acilis ekrani logosu, tum yogunluklar', () async {
    // Splash elle baglanir (flutter_native_splash YOK): launch_background.xml
    // navy zemin + ortada bu bitmap. @mipmap/ic_launcher yerine ayri ve daha
    // buyuk bir drawable uretilir — launcher ikonu 48dp icin olcekli, splash'ta
    // bulanik kalirdi.
    const densities = <String, int>{
      'mdpi': 96,
      'hdpi': 144,
      'xhdpi': 192,
      'xxhdpi': 288,
      'xxxhdpi': 384,
    };
    for (final entry in densities.entries) {
      final img = await _render((canvas, size) {
        final r = Radius.circular(size.width * _cornerRadiusRatio);
        canvas.clipRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.width, size.height),
            r,
          ),
        );
        canvas.drawImageRect(
          master,
          crop,
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..filterQuality = FilterQuality.high,
        );
      }, entry.value);
      final path = '$_resDir/drawable-${entry.key}/splash_logo.png';
      await _writePng(path, img);
      expect(File(path).existsSync(), isTrue);
    }
  });

  test('DOGRULAMA onizleme — adaptive fg/bg birlesimi + maske', () async {
    // Beyaz-on-seffaf fg'yi gozle dogrulamak icin: tek basina bakildiginda
    // beyaz-uzerine-beyaz gorunur (ayirt edilemez). Launcher'in yaptigi gibi
    // zemin uzerine bindirip, dairesel maskeyi de cizerek bakilir.
    final bg = await _decode('$_dir/icon_background.png');
    final fg = await _decode('$_dir/icon_foreground.png');
    final img = await _render((canvas, size) {
      final full = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawImageRect(
        bg,
        Rect.fromLTWH(0, 0, bg.width.toDouble(), bg.height.toDouble()),
        full,
        Paint(),
      );
      canvas.drawImageRect(
        fg,
        Rect.fromLTWH(0, 0, fg.width.toDouble(), fg.height.toDouble()),
        full,
        Paint(),
      );
      // GERCEK dairesel maske siniri: 108dp tuvalde gorunur bolge 72dp →
      // cap = tuvalin %66.7'si (tuvalin tamami DEGIL). Isaret bunun disina
      // TASMAMALI. Maskenin disinda kalan alan yalniz paralaks payidir.
      canvas.drawCircle(
        full.center,
        size.width * 0.667 / 2,
        Paint()
          ..color = const Color(0xFFFF0000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.006,
      );
      // Maskenin disi karartilir — launcher'da bu bolge GORUNMEZ.
      final outside = Path.combine(
        PathOperation.difference,
        Path()..addRect(full),
        Path()..addOval(Rect.fromCircle(
            center: full.center, radius: size.width * 0.667 / 2)),
      );
      canvas.drawPath(outside, Paint()..color = const Color(0x99000000));
    }, 512);
    await _writePng('${Directory.systemTemp.path}/adaptive_preview.png', img);
  });

  test('DOGRULAMA onizleme — basitlestirilmis isaret gercek boyutlarda',
      () async {
    // 24/32/48px'te okunakli mi? Navy zemin uzerine beyaz, 6x buyutulmus.
    const painter = YonetioSimpleMarkPainter(color: Colors.white);
    for (final px in [24, 32, 48]) {
      final tiny = await _render((canvas, size) {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = const Color(0xFF0E3C91),
        );
        painter.paint(canvas, size);
      }, px);
      final big = await _render((canvas, size) {
        canvas.drawImageRect(
          tiny,
          Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()),
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..filterQuality = FilterQuality.none,
        );
      }, px * 6);
      await _writePng('${Directory.systemTemp.path}/simple_mark_$px.png', big);
    }
  });

  test('favicon karari — tam master 16/32px onizleme (8x buyutulmus)',
      () async {
    // Tam logonun kucuk boyutta okunakliligini GOZLE degerlendirmek icin.
    // Karar docs/superpowers/specs/... icinde dokumante edilir.
    for (final small in [16, 32]) {
      final tiny = await _render((canvas, size) {
        canvas.drawImageRect(
          master,
          crop,
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..filterQuality = FilterQuality.high,
        );
      }, small);
      final big = await _render((canvas, size) {
        canvas.drawImageRect(
          tiny,
          Rect.fromLTWH(0, 0, small.toDouble(), small.toDouble()),
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..filterQuality = FilterQuality.none, // piksel piksel
        );
      }, small * 8);
      await _writePng('${Directory.systemTemp.path}/favicon_$small.png', big);
    }
  });
}
