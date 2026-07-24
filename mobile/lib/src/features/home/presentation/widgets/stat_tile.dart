import 'package:flutter/material.dart';

import '../../../../core/branding/yonetio_logo.dart';

/// Referans "Hızlı Özet" bloklarindan biri: pastel ikon + BUYUK deger + etiket
/// (+ opsiyonel alt-etiket, or. "Bu Ay"). Salt gosterim — dokunma yok.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.sublabel,
    this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? sublabel;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = accent ?? YonetioColors.navy;
    return Card(
      child: Padding(
        // WP-A: 4'lu izgarada dar/kisa hucreye sigmasi icin 14 -> 10
        // (home_grid'in dense ModuleCard'iyla tutarli kompaklik).
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: accentColor),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 1),
            // WP-A: 4'lu dar hucrede 2 satir etiket yukseklik tasmasina yol
            // aciyordu; kisa Turkce etiketler zaten tek satira sigar.
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w500),
            ),
            if (sublabel != null) ...[
              const SizedBox(height: 1),
              Text(
                sublabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
