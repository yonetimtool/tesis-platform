import 'package:flutter/material.dart';

import '../../../../core/branding/yonetio_logo.dart';

/// Referans "Son Hareketler" akisindaki tek satir: renkli daire-ikon + baslik
/// + alt-satir, sagda saat + renkli nokta + chevron. [accent] olay turunun
/// rengidir (null → marka navy). [onTap] ile detaya gidilir.
class ActivityRow extends StatelessWidget {
  const ActivityRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    this.accent,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = accent ?? YonetioColors.navy;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: accentColor.withValues(alpha: 0.12),
              child: Icon(icon, size: 18, color: accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              time,
              style:
                  theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: theme.hintColor),
          ],
        ),
      ),
    );
  }
}
