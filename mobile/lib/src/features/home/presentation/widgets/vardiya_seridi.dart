import 'package:flutter/material.dart';

import '../../../../core/theme/home_tokens.dart';
import '../../domain/home_view_models.dart';
import 'section_header.dart';
import 'section_padding.dart';
import 'shift_status_card.dart';
import '../../../../core/i18n/l10n.dart';
import 'hizli_erisim.dart';

/// Referans "Vardiya Durumu" bolumu — yatay kaydirilabilir [ShiftStatusCard]
/// seridi. gorevli.jpeg ve yonetici.jpeg'de AYNI bolum: tek widget, iki
/// ekranda paylasilir. Bos listede bolum HIC cizilmez.
class VardiyaSeridi extends StatelessWidget {
  const VardiyaSeridi({super.key, required this.kartlar, this.onSeeAll});

  final List<VardiyaKart> kartlar;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (kartlar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionPad(
          child: SectionHeader(
            title: context.l10n.bolumVardiyaDurumu,
            onSeeAll: onSeeAll,
          ),
        ),
        SizedBox(
          // YAZI OLCEGIYLE BUYUR (tur 34) — kamera seridiyle ayni gerekce.
          height: seritYuksekligi(context, 196),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: kHomePagePadding),
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
