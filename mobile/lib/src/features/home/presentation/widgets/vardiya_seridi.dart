import 'package:flutter/material.dart';

import '../../../../core/theme/home_tokens.dart';
import '../../domain/home_view_models.dart';
import 'section_header.dart';
import 'section_padding.dart';
import 'shift_status_card.dart';

/// Referans "Vardiya Durumu" bolumu — yatay kaydirilabilir [ShiftStatusCard]
/// seridi. gorevli.jpeg ve yonetici.jpeg'de AYNI bolum: tek widget, iki
/// ekranda paylasilir. Bos listede bolum HIC cizilmez.
class VardiyaSeridi extends StatelessWidget {
  const VardiyaSeridi({
    super.key,
    required this.kartlar,
    this.onSeeAll,
  });

  final List<VardiyaKart> kartlar;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (kartlar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionPad(
          child: SectionHeader(title: 'Vardiya Durumu', onSeeAll: onSeeAll),
        ),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: kHomePagePadding),
            itemCount: kartlar.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: HomeTokens.gridGap),
            itemBuilder: (context, i) => ShiftStatusCard(kart: kartlar[i]),
          ),
        ),
      ],
    );
  }
}
