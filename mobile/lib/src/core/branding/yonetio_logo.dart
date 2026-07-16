import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Yönetio marka kimligi — "Concept 15" (sinyal yayan site) logosu + kelime
/// isareti. Vektorel (CustomPainter) oldugu icin 28px (app-bar) ile 100px+
/// (giris) arasi her olcekte net; ekstra bagimlilik (flutter_svg) gerektirmez.
///
/// Ayni geometri `assets/branding/logo.svg` ve admin-web'deki inline SVG ile
/// birebir eslesir. Launcher PNG'leri de bu painter'dan uretilir
/// (test/tools/generate_branding_assets.dart).
class YonetioColors {
  const YonetioColors._();

  /// Ikon zemini + acik-baglamda kelime isareti.
  static const navy = Color(0xFF1E3A5F);

  /// Kisa (sol) blok.
  static const white = Color(0xFFFFFFFF);

  /// Uzun (sag) blok.
  static const mint = Color(0xFF7FD1C9);

  /// Sinyal yaylari + kaynak nokta.
  static const teal = Color(0xFF0E9594);
}

/// Logo ikonu (yalniz isaret; yuvarlak-kare navy zemin + iki blok + sinyal).
/// [background] false ise seffaf zemin (adaptive icon foreground katmani icin).
class YonetioLogoMark extends StatelessWidget {
  const YonetioLogoMark({super.key, this.size = 40, this.background = true});

  final double size;
  final bool background;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: YonetioLogoPainter(background: background),
        isComplex: false,
      ),
    );
  }
}

/// Kelime isareti — kucuk harf "yönetio", geometrik sans (Roboto — projede
/// zaten var; yeni font bagimliligi yok), orta agirlik. Acik baglamda navy,
/// koyu baglamda beyaz.
class YonetioWordmark extends StatelessWidget {
  const YonetioWordmark({super.key, this.fontSize = 26, this.color});

  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      'yönetio',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        letterSpacing: fontSize * 0.005,
        height: 1.0,
        color: color ?? (dark ? Colors.white : YonetioColors.navy),
      ),
    );
  }
}

/// Dikey yerlesim (giris ekrani): ikon ustte, kelime isareti altta.
class YonetioLogoVertical extends StatelessWidget {
  const YonetioLogoVertical({super.key, this.iconSize = 100});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        YonetioLogoMark(size: iconSize),
        SizedBox(height: iconSize * 0.16),
        YonetioWordmark(fontSize: iconSize * 0.30),
      ],
    );
  }
}

/// Yatay yerlesim (ikon + kelime isareti yan yana).
class YonetioLogoHorizontal extends StatelessWidget {
  const YonetioLogoHorizontal({super.key, this.iconSize = 32, this.color});

  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        YonetioLogoMark(size: iconSize),
        SizedBox(width: iconSize * 0.28),
        YonetioWordmark(fontSize: iconSize * 0.72, color: color),
      ],
    );
  }
}

/// Logonun tum geometrisi 0..1 normalize edilip [size] ile olceklenir; boylece
/// tek kaynak her boyutta ayni orani korur.
class YonetioLogoPainter extends CustomPainter {
  const YonetioLogoPainter({this.background = true});

  final bool background;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    double u(double v) => v * s; // normalize -> piksel

    // 1) Yuvarlak-kare navy zemin (flat; golge/gradyan yok).
    if (background) {
      final bg = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, s, s),
        Radius.circular(u(0.22)),
      );
      canvas.drawRRect(bg, Paint()..color = YonetioColors.navy);
    }

    // 2) Iki blok — ortak taban cizgisi 0.80.
    final leftBlock = RRect.fromRectAndRadius(
      Rect.fromLTRB(u(0.23), u(0.38), u(0.45), u(0.80)),
      Radius.circular(u(0.03)),
    );
    final rightBlock = RRect.fromRectAndRadius(
      Rect.fromLTRB(u(0.55), u(0.26), u(0.77), u(0.80)),
      Radius.circular(u(0.03)),
    );
    canvas.drawRRect(leftBlock, Paint()..color = YonetioColors.white);
    canvas.drawRRect(rightBlock, Paint()..color = YonetioColors.mint);

    // 3) 2x2 navy pencereler (her blogun ust yarisinda) — basit kareler.
    final winPaint = Paint()..color = YonetioColors.navy;
    _windows(canvas, leftBlock.outerRect, winPaint);
    _windows(canvas, rightBlock.outerRect, winPaint);

    // 4) Sinyal: iki es-merkezli yay + altta kaynak nokta (bosluk ustunde).
    final teal = Paint()
      ..color = YonetioColors.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = u(0.045)
      ..strokeCap = StrokeCap.round;
    final center = Offset(u(0.5), u(0.47));
    // yukari acilan yay: -90° (yukari) etrafinda 120° kavis.
    const start = -math.pi / 2 - math.pi / 3; // -150°
    const sweep = 2 * math.pi / 3; // 120°
    for (final r in [0.11, 0.165]) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: u(r)),
        start,
        sweep,
        false,
        teal,
      );
    }
    canvas.drawCircle(
      Offset(u(0.5), u(0.45)),
      u(0.028),
      Paint()..color = YonetioColors.teal,
    );
  }

  void _windows(Canvas canvas, Rect block, Paint paint) {
    final win = block.width * 0.24;
    final marginX = block.width * 0.20;
    final x0 = block.left + marginX;
    final x1 = block.right - marginX - win;
    final y0 = block.top + block.height * 0.12;
    final y1 = y0 + win + block.height * 0.10;
    for (final x in [x0, x1]) {
      for (final y in [y0, y1]) {
        canvas.drawRect(Rect.fromLTWH(x, y, win, win), paint);
      }
    }
  }

  @override
  bool shouldRepaint(YonetioLogoPainter oldDelegate) =>
      oldDelegate.background != background;
}
