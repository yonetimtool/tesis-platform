import 'package:flutter/material.dart';

import '../../../../core/theme/home_tokens.dart';

/// Referans tasarimin BEYAZ KARTI — radius 16, golge yok, %4 siyah 1px
/// kenarlik ([HomeSurface.cardDecoration]). Tum ana ekran bolumleri bunu
/// kullanir; kart gorunumu tek yerden degisir.
class HomeCard extends StatelessWidget {
  const HomeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(HomeTokens.cardPadding),
    this.onTap,
    this.width,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final decoration = HomeSurface.of(context).cardDecoration;
    final content = Padding(padding: padding, child: child);
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: decoration,
        child: onTap == null
            ? content
            : Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(HomeTokens.cardRadius),
                  child: content,
                ),
              ),
      ),
    );
  }
}

/// Kartlarin ve satirlarin ortak "tint zeminli yuvarlak-kare ikon" kutusu.
/// Varsayilan olcu referans spesifikasyonundan: 56x56, radius 14, 26px ikon.
class HomeIconBox extends StatelessWidget {
  const HomeIconBox({
    super.key,
    required this.icon,
    required this.accent,
    this.size = HomeTokens.iconBox,
    this.radius = HomeTokens.iconBoxRadius,
    this.iconSize = HomeTokens.iconSize,
  });

  final IconData icon;
  final Color accent;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: HomeTokens.tint(accent),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: accent),
    );
  }
}

/// Tint zeminli + accent metinli kucuk rozet (AKTİF / PLANLANDI / YÖNETİCİ /
/// Ödendi / Yeni). Radius 8, 11px semibold.
class HomeChip extends StatelessWidget {
  const HomeChip({
    super.key,
    required this.label,
    required this.accent,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: HomeTokens.tint(accent),
        borderRadius: BorderRadius.circular(HomeTokens.chipRadius),
      ),
      child: Text(label, style: HomeText.chip.copyWith(color: accent)),
    );
  }
}

/// 8px renkli durum noktasi (son hareketler satiri + online gostergesi).
class HomeDot extends StatelessWidget {
  const HomeDot({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
