import 'package:flutter/material.dart';

import '../../../../core/i18n/l10n.dart';
import '../../../../core/theme/home_tokens.dart';

/// Referans ana ekranin tekrar eden bolum basligi: solda 18 bold baslik,
/// sagda opsiyonel "Tümünü Gör ›" (14 medium, primary mavi + kucuk chevron).
/// [onSeeAll] null ise baglanti gizlenir.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.seeAllLabel,
  });

  final String title;
  final VoidCallback? onSeeAll;

  /// Ozel baglanti metni; null → aktif dilde "Tümünü Gör" (const yapici
  /// oldugu icin varsayilan CIZIM ANINDA cozulur).
  final String? seeAllLabel;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    final etiket = seeAllLabel ?? context.l10n.ortakTumunuGor;
    return Padding(
      // Baglanti dokunma hedefi 48 dp'ye cikinca satir zaten yukseldi:
      // alt bosluk buyudugu kadar kisaltilir (gorsel ritim korunur).
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HomeText.section.copyWith(color: s.heading),
            ),
          ),
          if (onSeeAll != null)
            InkWell(
              onTap: onSeeAll,
              borderRadius: BorderRadius.circular(HomeTokens.chipRadius),
              // DOKUNMA HEDEFI 48 dp (tur 34): baglanti 28 dp yuksekligindeydi
              // ve Android kilavuzunun altinda kaliyordu. Metin buyumez —
              // yalnizca dokunulabilir alan bosluklarla 48'e cikar; bolum
              // basligi satiri da bu yukseklige oturur.
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Koyu temada vurgu METNI acik tona cozulur (tur 32).
                    // 2.0x olcekte uzun ceviri ("Alle anzeigen") satiri
                    // tasiriyordu: baglanti metni de kisalabilmeli (tur 34).
                    Flexible(
                      child: Text(
                        etiket,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HomeText.link.copyWith(
                          color: s.accentText(HomeTokens.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: HomeTokens.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
