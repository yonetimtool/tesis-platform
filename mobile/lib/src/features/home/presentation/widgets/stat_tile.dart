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
    this.dense = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? sublabel;
  final Color? accent;

  /// Kompakt varyant — 4'lu izgara hucresine sigmasi icin kucultulmus
  /// padding/ikon/etiket (WP-A). dense=false: eski (2 sutunlu) boyutlar.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = accent ?? YonetioColors.navy;
    final double chip = dense ? 32 : 40;
    final EdgeInsets pad = EdgeInsets.all(dense ? 10 : 14);
    return Card(
      child: Padding(
        // WP-A: 4'lu izgarada dar/kisa hucreye sigmasi icin dense=true iken
        // 14 -> 10 (home_grid'in dense ModuleCard'iyla tutarli kompaklik).
        padding: pad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: chip,
              height: chip,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: dense ? 18 : 22, color: accentColor),
            ),
            SizedBox(height: dense ? 4 : 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: dense ? 1 : 2),
            // WP-A: 4'lu dar hucrede 2 satir etiket yukseklik tasmasina yol
            // aciyordu; dense=true iken 1 satira dusuruldu. dense=false
            // (2 sutunlu genis hucre) eski 2 satirlik gorunumu korur.
            Text(
              label,
              maxLines: dense ? 1 : 2,
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
