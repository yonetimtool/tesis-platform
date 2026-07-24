import 'package:flutter/material.dart';

import '../../../../core/theme/home_tokens.dart';

/// Referans ana ekranin tekrar eden bolum basligi: solda 18 bold baslik,
/// sagda opsiyonel "Tümünü Gör ›" (14 medium, primary mavi + kucuk chevron).
/// [onSeeAll] null ise baglanti gizlenir.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.seeAllLabel = 'Tümünü Gör',
  });

  final String title;
  final VoidCallback? onSeeAll;
  final String seeAllLabel;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(seeAllLabel, style: HomeText.link),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right,
                        size: 18, color: HomeTokens.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
