import 'package:flutter/material.dart';

import '../../../../core/theme/home_tokens.dart';
import '../../domain/home_view_models.dart';
import 'home_card.dart';
import 'section_header.dart';

/// Sakin ana ekraninin ICERIK BOLUMU — "Duyurular" kartiyla AYNI gorsel
/// desen (solda 96x72 gorsel/yer tutucu, sagda baslik + ozet + alt satir +
/// opsiyonel cip), ama COK SATIRLI: bolum basligi + 2-3 kayit + "Tümünü Gör".
///
/// "Site Kuralları" ve "Etkinlikler" bolumleri bunu kullanir; kayit sayisi
/// cagiran katmanda sinirlanir (ana ekran uzamasin).
class IcerikBolumu extends StatelessWidget {
  const IcerikBolumu({
    super.key,
    required this.baslik,
    required this.satirlar,
    required this.onTumu,
    this.onSec,
  });

  final String baslik;
  final List<IcerikOzeti> satirlar;

  /// "Tümünü Gör" — tam liste ekrani.
  final VoidCallback onTumu;

  /// Tek kayda dokunma; null → kart tumune gider.
  final ValueChanged<IcerikOzeti>? onSec;

  @override
  Widget build(BuildContext context) {
    // Veri YOKSA bolum HIC cizilmez (bos kart yerine bosluk) — duyuru
    // bolumuyle ayni kural.
    if (satirlar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: baslik, onSeeAll: onTumu),
        for (var i = 0; i < satirlar.length; i++) ...[
          if (i > 0) const SizedBox(height: HomeTokens.gridGap),
          _IcerikKarti(
            ozet: satirlar[i],
            onTap: () =>
                onSec == null ? onTumu() : onSec!(satirlar[i]),
          ),
        ],
      ],
    );
  }
}

class _IcerikKarti extends StatelessWidget {
  const _IcerikKarti({required this.ozet, required this.onTap});

  final IcerikOzeti ozet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    return HomeCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Gorsel(url: ozet.fotoUrl, ikon: ozet.ikon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ozet.baslik,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HomeText.cardTitle.copyWith(color: s.heading),
                ),
                const SizedBox(height: 5),
                Text(
                  ozet.altMetin,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HomeText.rowSub.copyWith(color: s.muted),
                ),
                if (ozet.tarih != null || ozet.cip != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ozet.tarih ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HomeText.rowSub.copyWith(color: s.muted),
                        ),
                      ),
                      if (ozet.cip != null)
                        HomeChip(
                          label: ozet.cip!,
                          accent: ozet.cipAccent ?? HomeTokens.primary,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 96x72 radius-12 gorsel; URL yoksa/yuklenemezse gri yer tutucu (bolum
/// cercevesi korunur, kart bozulmaz) — duyuru kartiyla ayni davranis.
class _Gorsel extends StatelessWidget {
  const _Gorsel({this.url, required this.ikon});

  final String? url;
  final IconData ikon;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    final placeholder = Container(
      width: 96,
      height: 72,
      color: s.placeholder,
      child: Icon(ikon, size: 24, color: s.muted),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: url == null
          ? placeholder
          : Image.network(
              url!,
              width: 96,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}
