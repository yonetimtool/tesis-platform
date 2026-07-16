import 'package:flutter/material.dart';

/// Yönetio marka kimligi.
///
/// TEK kaynak: `assets/branding/icon_master.png` — saglanan hazir logo
/// (mavi→teal gradyan yuvarlak-kare; beyaz isaret: uc bina + chevron/cati +
/// kucuk ev + insanlar + yay). OLDUGU GIBI kullanilir, yeniden cizilmez.
/// `logo_master.png`'den beyaz kenar boslugu kirpilarak uretilir
/// (test/tools/generate_branding_assets.dart).
///
/// Master ~32px altinda okunmaz (insanlar/yay/yan bloklar bulanir). Bu yuzden
/// kucuk boyutlar icin BASITLESTIRILMIS tek-renk turev kullanilir
/// ([YonetioSimpleMark]) — yalniz merkez bina + chevron/cati silueti.
///
/// | Yuzey                  | Surum                |
/// |------------------------|----------------------|
/// | launcher, giris, splash| master (tam)         |
/// | app-bar, bildirim, favicon | basitlestirilmis |
class YonetioColors {
  const YonetioColors._();

  /// Kelime isareti (acik tema) + splash zemini — master gradyaninin KOYU ucu.
  /// Deger elle secilmedi: logonun kose pikselinden orneklendi
  /// (test/tools/generate_branding_assets.dart). android values/colors.xml
  /// (`yonetio_navy`) ve admin-web ile ayni.
  static const navy = Color(0xFF0E3C91);

  /// Gradyanin ACIK ucu (teal) — ayni sekilde orneklendi (`yonetio_teal`).
  static const teal = Color(0xFF1DB2B6);
}

/// Tam master logo (gradyan zemin dahil). Giris ekrani ve ~40px ustu yuzeyler.
class YonetioMasterLogo extends StatelessWidget {
  const YonetioMasterLogo({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/icon_master.png',
      width: size,
      height: size,
      // Master zaten yuvarlak-kare; ek kirpma/koseleme YOK.
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Yönetio',
    );
  }
}

/// Basitlestirilmis tek-renk isaret — merkez bina + chevron/cati silueti.
/// Master'in kucuk-boyut turevi: app-bar (~28-32px), bildirim kucuk ikonu
/// (Android monokrom zorunlulugu) ve favicon.
class YonetioSimpleMark extends StatelessWidget {
  const YonetioSimpleMark({super.key, this.size = 30, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: YonetioSimpleMarkPainter(
          color: color ?? scheme.onSurface,
        ),
        isComplex: false,
      ),
    );
  }
}

/// Kelime isareti — kucuk harf "yönetio", Roboto (projede zaten var; yeni font
/// bagimliligi yok). Acik baglamda navy, koyu baglamda beyaz.
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
        letterSpacing: fontSize * 0.01,
        height: 1.0,
        color: color ?? (dark ? Colors.white : YonetioColors.navy),
      ),
    );
  }
}

/// Dikey yerlesim (giris ekrani): tam master ustte, kelime isareti altta.
class YonetioLogoVertical extends StatelessWidget {
  const YonetioLogoVertical({super.key, this.iconSize = 120});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        YonetioMasterLogo(size: iconSize),
        SizedBox(height: iconSize * 0.14),
        YonetioWordmark(fontSize: iconSize * 0.26),
      ],
    );
  }
}

/// Basitlestirilmis isaretin geometrisi — 0..1 normalize, [size] ile olceklenir.
/// Master'in merkez binasi (egik cati cizgisi) + uzerine binen chevron/cati.
/// Yan bloklar, insanlar ve yay ATILIR: 32px altinda bulaniyorlar.
///
/// Ayni geometri admin-web'de inline SVG olarak aynalanir
/// (admin-web/components/YonetioLogo.tsx).
class YonetioSimpleMarkPainter extends CustomPainter {
  const YonetioSimpleMarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    double u(double v) => v * s;

    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    // 1) Merkez bina — TIKNAZ blok, egik cati cizgisi sol-ustten saga
    //    yukselir. Master'daki uzun binanin silueti. Blogun tiknaz olmasi
    //    sart: ince olursa cati ile birlikte "tripod" gibi okunuyor.
    final tower = Path()
      ..moveTo(u(0.35), u(0.24))
      ..lineTo(u(0.58), u(0.09)) // egik cati
      ..lineTo(u(0.66), u(0.09))
      ..lineTo(u(0.66), u(0.50))
      ..lineTo(u(0.35), u(0.50))
      ..close();
    canvas.drawPath(tower, paint);

    // 2) Chevron/cati — DOLU ucgen, tabani duz. Cizgi (stroke + yuvarlak uc)
    //    olarak denendi: 24px'te cati degil "ayrik bacaklar" gibi okunuyordu.
    //    Dolu ve genis-yayvan ucgen (~21:8) cati olarak net okunuyor; bina
    //    tepesinden disari tasar.
    final roof = Path()
      ..moveTo(u(0.09), u(0.78))
      ..lineTo(u(0.50), u(0.44))
      ..lineTo(u(0.91), u(0.78))
      ..close();
    canvas.drawPath(roof, paint);
  }

  @override
  bool shouldRepaint(YonetioSimpleMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
