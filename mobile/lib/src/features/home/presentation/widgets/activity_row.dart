import 'package:flutter/material.dart';

import '../../../../core/theme/home_tokens.dart';
import 'home_card.dart';

/// Referans "Son Hareketler" akisindaki TEK SATIR: solda 40px tint yuvarlak
/// ikon, ortada baslik (14 semibold) + alt metin (12 gri), sagda saat/tarih
/// (12 gri) + 8px renkli durum noktasi + gri chevron.
///
/// [accent] ikonun rengi (MODULUN rengi), [noktaRengi] sagdaki noktanin rengi
/// (OLAYIN durumu). Referans gorsellerde bu ikisi bazi satirlarda farklidir
/// (or. kirmizi gurultu ikonu + turuncu nokta); [noktaRengi] verilmezse
/// [accent] kullanilir.
class ActivityRow extends StatelessWidget {
  const ActivityRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    this.accent,
    this.noktaRengi,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final Color? accent;
  final Color? noktaRengi;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    final accentColor = accent ?? HomeTokens.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            HomeIconBox(
              icon: icon,
              accent: accentColor,
              size: HomeTokens.rowIconBox,
              radius: HomeTokens.rowIconBox / 2,
              iconSize: 20,
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
                    style: HomeText.cardTitle.copyWith(color: s.heading),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HomeText.rowSub.copyWith(color: s.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              time,
              style: HomeText.rowSub.copyWith(color: s.muted),
            ),
            const SizedBox(width: 8),
            HomeDot(color: noktaRengi ?? accentColor),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 18, color: s.muted),
          ],
        ),
      ),
    );
  }
}
