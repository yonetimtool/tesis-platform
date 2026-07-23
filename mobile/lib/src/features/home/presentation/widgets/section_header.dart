import 'package:flutter/material.dart';

import '../../../../core/branding/yonetio_logo.dart';

/// Referans ana ekranin tekrar eden bolum basligi: solda kalin baslik, sagda
/// opsiyonel "Tümünü Gör" baglantisi (teal vurgu). [onSeeAll] null ise baglanti
/// gizlenir (or. "Hızlı Özet" — tam liste yok).
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: YonetioColors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: Text(seeAllLabel),
            ),
        ],
      ),
    );
  }
}
