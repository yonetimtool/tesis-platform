import 'package:flutter/material.dart';

import '../../../../core/i18n/l10n.dart';
import '../../../../core/theme/home_tokens.dart';
import '../../../cameras/domain/camera_models.dart';
import '../../../cameras/presentation/kamera_karti.dart';
import 'section_header.dart';
import 'section_padding.dart';
import 'hizli_erisim.dart';

/// Ana ekranin "Canlı Kamera" seridi (gorevli.jpeg): yatay kaydirilabilir
/// kamera kartlari. Kart tipi Kameralar ekranindaki izgarayla AYNIDIR
/// ([KameraKarti]) — ad + konum + "• Canlı" / "Oynatılamıyor".
///
/// Liste SUNUCUDAN gelir ve sunucuda rol'e gore suzulmustur; bu widget
/// EK SUZGEC UYGULAMAZ (sakin/gorevli yalniz kendisine gonderilen kameralari
/// gorur — istemci "gizli" bir kamerayi eleyip guvenlik gibi davranmaz).
class KameraSeridi extends StatelessWidget {
  const KameraSeridi({
    super.key,
    required this.kameralar,
    required this.onAc,
    this.onSeeAll,
  });

  final List<Camera> kameralar;

  /// Secilen kamera — oynatilabilir mi kararini cagiran katman verir.
  final ValueChanged<Camera> onAc;

  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (kameralar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionPad(
          child: SectionHeader(
            title: context.l10n.kameraSeritBaslik,
            onSeeAll: onSeeAll,
          ),
        ),
        SizedBox(
          // 168 genislik − 16 kart boslugu = 152 gorsel; 16:10 → 95px. Ustune
          // ad (17) + konum (15) + durum (15) satirlari ve boslukiar: 196
          // hepsini KONUMLU kartta da tasmadan alir (testle kilitli).
          // YAZI OLCEGIYLE BUYUR (tur 34): sabit 196 dp, 2.0x olcekte ve
          // dar ekranda serit kartlarini tasiriyordu. Ust sinir 320: serit
          // ekrani yutmasin.
          height: seritYuksekligi(context, 196),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: kHomePagePadding),
            itemCount: kameralar.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: HomeTokens.gridGap),
            itemBuilder: (context, i) => KameraKarti(
              kamera: kameralar[i],
              // Kart GENISLIGI de yazi olcegiyle buyur (tur 34).
              width: MediaQuery.textScalerOf(
                context,
              ).scale(168).clamp(168.0, 336.0),
              onTap: () => onAc(kameralar[i]),
            ),
          ),
        ),
      ],
    );
  }
}
