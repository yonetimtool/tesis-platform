import 'package:auto_size_text/auto_size_text.dart';
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
    this.dense = false,
    this.titleGroup,
    this.counterGroup,
  });

  final IconData icon;
  final String title;

  /// dense (4'lu izgara) tipografiyi TEK TIP yapan gruplar — ayni grubu
  /// paylasan tum kartlar basligi/sayaci AYNI (sigan en buyuk) boyutta cizer.
  final AutoSizeGroup? titleGroup;
  final AutoSizeGroup? counterGroup;

  /// Ikincil satir: "6 Bekliyor", "Borç Yok", "5 Yeni" gibi. null → gizli.
  final String? counter;

  /// Chip/sayac vurgu rengi (kategori pasteli). null → marka navy.
  final Color? accent;

  final VoidCallback? onTap;

  /// MISSING-BACKEND: pasif "Yakında" varyanti (dokunma yutulur).
  final bool comingSoon;

  /// Kompakt varyant — 4'lu izgara hucresine sigmasi icin kucultulmus
  /// chip/ikon/padding/tipografi (WP-A).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color accentColor =
        comingSoon ? theme.disabledColor : (accent ?? YonetioColors.navy);
    final double chip = dense ? 36 : 46;
    final double iconSize = dense ? 20 : 24;
    final EdgeInsets pad = EdgeInsets.all(dense ? 10 : 14);
    final TextStyle? titleStyle =
        (dense ? theme.textTheme.labelMedium : theme.textTheme.titleSmall)
            ?.copyWith(
      fontWeight: FontWeight.w700,
      color: comingSoon ? theme.disabledColor : null,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // comingSoon: onTap null'lanir → InkWell pasif, dokunma cagri uretmez.
        onTap: comingSoon ? null : onTap,
        child: Padding(
          padding: pad,
          child: Column(
            // Referans 1:1 (WP2): kart icerigi ORTALI (ikon ustte-orta,
            // baslik + sayac ortada) — eski sola-hizali gorunumden sapmaydi.
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pastel yuvarlak-kare ikon chip.
              Container(
                width: chip,
                height: chip,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: comingSoon ? 0.10 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: iconSize, color: accentColor),
              ),
              SizedBox(height: dense ? 8 : 12),
              // Dense (4'lu izgara): AutoSizeText + paylasilan grup → tum
              // kartlar AYNI okunakli boyutta (uzunluga gore degismez); uzun
              // baslik 2 satira sarar, gerekirse grup boyunca birlikte kuculur
              // (minFontSize okunaklilik tabani). Non-dense (2 sutun): mevcut.
              if (dense)
                Flexible(
                  child: AutoSizeText(
                    title,
                    group: titleGroup,
                    maxLines: 2,
                    minFontSize: 10,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                )
              else
                Flexible(
                  child: Text(
                    title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
              const SizedBox(height: 2),
              // Alt satir: "Yakında" rozeti (comingSoon) ya da sayac / bos.
              if (comingSoon)
                _YakindaPill(color: accentColor)
              else if (counter != null)
                dense
                    ? AutoSizeText(
                        counter!,
                        group: counterGroup,
                        maxLines: 1,
                        minFontSize: 9,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accent ?? YonetioColors.navy,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : Text(
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
