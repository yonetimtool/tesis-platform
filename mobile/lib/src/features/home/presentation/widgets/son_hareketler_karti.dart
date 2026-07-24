import 'package:flutter/material.dart';

import '../../../../core/theme/home_tokens.dart';
import '../../domain/home_view_models.dart';
import 'activity_row.dart';
import 'home_card.dart';
import 'section_header.dart';

/// Referans "Son Hareketler" bolumu — bolum basligi + TEK beyaz kart icinde
/// satirlar, aralarinda 1px ayrac. Uc rol varyantinda AYNI widget; fark
/// yalniz satir verisidir. Bos akista bolum HIC cizilmez.
class SonHareketlerKarti extends StatelessWidget {
  const SonHareketlerKarti({
    super.key,
    required this.satirlar,
    this.onSeeAll,
    this.onSatir,
  });

  final List<HareketSatiri> satirlar;
  final VoidCallback? onSeeAll;
  final ValueChanged<HareketSatiri>? onSatir;

  @override
  Widget build(BuildContext context) {
    if (satirlar.isEmpty) return const SizedBox.shrink();
    final s = HomeSurface.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Son Hareketler', onSeeAll: onSeeAll),
        HomeCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < satirlar.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, thickness: 1, color: s.divider),
                ActivityRow(
                  icon: satirlar[i].ikon,
                  title: satirlar[i].baslik,
                  subtitle: satirlar[i].altBaslik,
                  time: satirlar[i].zaman,
                  accent: satirlar[i].ikonAccent,
                  noktaRengi: satirlar[i].noktaRengi,
                  onTap:
                      onSatir == null ? null : () => onSatir!(satirlar[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
