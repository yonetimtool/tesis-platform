import 'package:flutter/material.dart';

import '../../announcements/domain/announcement_models.dart';
import 'widgets/section_header.dart';

const _amber = Color(0xFFD97706);

/// Ana ekranin "Duyurular" karti (site-sakini.jpeg) — en yeni duyurunun
/// baslik + govde ozeti + tarih; 3 gunden yeni ise amber "Yeni" cipi.
/// "Tümünü Gör" duyuru listesine goturur. Duyuru yoksa kart HIC cizilmez.
class DuyurularKarti extends StatelessWidget {
  const DuyurularKarti({
    super.key,
    required this.duyurular,
    required this.now,
    required this.onTumu,
  });

  /// En-yeni-ustte duyurular (yalniz ilki cizilir).
  final List<Announcement> duyurular;
  final DateTime now;
  final VoidCallback onTumu;

  @override
  Widget build(BuildContext context) {
    if (duyurular.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final d = duyurular.first;
    final yeni = now.difference(d.createdAt) <= const Duration(days: 3);
    final tarih = '${d.createdAt.day.toString().padLeft(2, '0')}.'
        '${d.createdAt.month.toString().padLeft(2, '0')}.'
        '${d.createdAt.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Duyurular', onSeeAll: onTumu),
        const SizedBox(height: 8),
        Card(
          child: InkWell(
            onTap: onTumu,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          d.baslik,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (yeni)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Yeni',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: _amber, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    d.govde,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tarih,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
