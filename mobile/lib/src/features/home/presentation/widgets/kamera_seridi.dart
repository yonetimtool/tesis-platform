import 'package:flutter/material.dart';

import '../../../../core/theme/home_tokens.dart';
import '../../domain/home_view_models.dart';
import 'home_card.dart';
import 'section_header.dart';
import 'section_padding.dart';

/// Gorevli ana ekraninin "Canlı Kamera" seridi (gorevli.jpeg): yatay
/// kaydirilabilir kucuk kartlar — 16:10 gri kare + ortada yari saydam
/// oynat butonu, altinda kamera adi ve yesil "• Canlı".
///
/// Kart icinde VIDEO OYNATILMAZ; kare yalnizca yer tutucudur. Dokunma
/// [onIzle] ile disariya (gercek oynatici ekranina) birakilir.
class KameraSeridi extends StatelessWidget {
  const KameraSeridi({
    super.key,
    required this.kameralar,
    required this.onIzle,
    this.onSeeAll,
  });

  final List<KameraOzeti> kameralar;

  /// Secilen kameranin listedeki indeksi.
  final ValueChanged<int> onIzle;

  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (kameralar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionPad(
          child: SectionHeader(title: 'Canlı Kamera', onSeeAll: onSeeAll),
        ),
        SizedBox(
          // 168 genislik − 16 padding = 152 gorsel; 16:10 → 95 + baslik/etiket.
          height: 164,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: kHomePagePadding),
            itemCount: kameralar.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: HomeTokens.gridGap),
            itemBuilder: (context, i) => _KameraKarti(
              kamera: kameralar[i],
              onTap: () => onIzle(i),
            ),
          ),
        ),
      ],
    );
  }
}

class _KameraKarti extends StatelessWidget {
  const _KameraKarti({required this.kamera, required this.onTap});

  final KameraOzeti kamera;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    return HomeCard(
      width: 168,
      padding: const EdgeInsets.all(8),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Container(
                color: s.placeholder,
                child: const Center(
                  child: _OynatButonu(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            kamera.ad,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HomeText.cardTitle.copyWith(color: s.heading),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              const HomeDot(color: HomeTokens.online, size: 7),
              const SizedBox(width: 5),
              Text('Canlı',
                  style: HomeText.rowSub.copyWith(color: HomeTokens.green)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Yari saydam siyah daire + beyaz ucgen — referans yer tutucunun oynat
/// butonu (islev: karti actirir, video baslatmaz).
class _OynatButonu extends StatelessWidget {
  const _OynatButonu();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: Color(0x8C000000),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
    );
  }
}
