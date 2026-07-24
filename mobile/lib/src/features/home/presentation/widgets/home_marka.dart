import 'package:flutter/material.dart';

import '../../../../core/branding/yonetio_logo.dart';
import '../../../../core/theme/home_tokens.dart';

/// App-bar marka kilidi (referans gorsellerdeki dizilim): solda kalkan
/// isareti, sagda iki satir — kelime isareti (bold) ve altinda harf arali
/// 9px gri alt-baslik.
///
/// NOT — bilincli sapma: referans gorsellerdeki kelime isareti "YÖNETİYOR"dur
/// (hazir mockup markasi). Urunun GERCEK adi **Yönetio**'dur ve launcher
/// ikonu, splash, admin-web ve android kaynaklari bu ada baglidir; mockup
/// metnini kopyalamak urunu kendi markasindan koparirdi. Bu yuzden DIZILIM
/// gorselle birebir, KELIME ISARETI gercek markadir.
class HomeMarka extends StatelessWidget {
  const HomeMarka({super.key});

  /// Referans alt-basligi (marka konumlandirmasi).
  static const altBaslik = 'GÜVENLİK & DANIŞMANLIK';

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const YonetioMasterLogo(size: 30),
        const SizedBox(width: 8),
        // Dar app-bar'da (hamburger + zil + avatar yaninda) kilit BOZULMAZ:
        // kelime isareti + alt-baslik birlikte olceklenir.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Yönetio',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: s.heading,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  altBaslik,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.1,
                    color: s.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
