import 'package:flutter/material.dart';

import '../../../../core/branding/yonetio_logo.dart';

/// Referans ana ekranin (docs/design-refs) "one cikan" modul karti:
/// pastel yuvarlak-kare ikon chip + kalin baslik (CUMLE duzeni — mevcut
/// izgaranin BUYUK-HARF trUpper deseninden bilincli sapma) + renkli sayac
/// satiri. MISSING-BACKEND moduller [comingSoon] ile pasif "Yakında" olarak
/// gorunur; dokunma yutulur (yanlislikla bos ekran acilmaz).
class ModuleCard extends StatelessWidget {
  const ModuleCard({
    super.key,
    required this.icon,
    required this.title,
    this.counter,
    this.accent,
    this.onTap,
    this.comingSoon = false,
  });

  final IconData icon;
  final String title;

  /// Ikincil satir: "6 Bekliyor", "Borç Yok", "5 Yeni" gibi. null → gizli.
  final String? counter;

  /// Chip/sayac vurgu rengi (kategori pasteli). null → marka navy.
  final Color? accent;

  final VoidCallback? onTap;

  /// MISSING-BACKEND: pasif "Yakında" varyanti (dokunma yutulur).
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color accentColor =
        comingSoon ? theme.disabledColor : (accent ?? YonetioColors.navy);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // comingSoon: onTap null'lanir → InkWell pasif, dokunma cagri uretmez.
        onTap: comingSoon ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pastel yuvarlak-kare ikon chip.
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: comingSoon ? 0.10 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 24, color: accentColor),
              ),
              const SizedBox(height: 12),
              // Flexible: dar izgara hucresinde baslik sikisirsa tasma yerine
              // ellipsis'e duser (2 satir -> gerekirse 1).
              Flexible(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: comingSoon ? theme.disabledColor : null,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // Alt satir: "Yakında" rozeti (comingSoon) ya da sayac / bos.
              if (comingSoon)
                _YakindaPill(color: accentColor)
              else if (counter != null)
                Text(
                  counter!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: accent ?? YonetioColors.navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pasif modul rozeti — "Yakında" (MISSING-BACKEND kartlar).
class _YakindaPill extends StatelessWidget {
  const _YakindaPill({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Yakında',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
