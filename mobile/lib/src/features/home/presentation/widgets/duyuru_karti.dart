import 'package:flutter/material.dart';

import '../../../../core/theme/home_tokens.dart';
import '../../domain/home_view_models.dart';
import 'home_card.dart';
import 'section_header.dart';

/// Sakin ana ekraninin "Duyurular" karti (site-sakini.jpeg): solda 96x72
/// radius-12 gorsel (yoksa gri yer tutucu), sagda baslik (semibold), ozet
/// (gri), tarih (gri) ve sag altta mavi tint "Yeni" cipi.
class DuyuruKarti extends StatelessWidget {
  const DuyuruKarti({
    super.key,
    required this.duyuru,
    required this.onTumu,
  });

  final DuyuruOzeti duyuru;
  final VoidCallback onTumu;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Duyurular', onSeeAll: onTumu),
        HomeCard(
          onTap: onTumu,
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Gorsel(url: duyuru.fotoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      duyuru.baslik,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HomeText.cardTitle.copyWith(color: s.heading),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      duyuru.govde,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HomeText.rowSub.copyWith(color: s.muted),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            duyuru.tarih,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HomeText.rowSub.copyWith(color: s.muted),
                          ),
                        ),
                        if (duyuru.yeni)
                          const HomeChip(
                              label: 'Yeni', accent: HomeTokens.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 96x72 radius-12 gorsel. URL yoksa (ya da yuklenemezse) gri yer tutucu —
/// referans gorseldeki cerceve korunur, kart bozulmaz.
class _Gorsel extends StatelessWidget {
  const _Gorsel({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    final placeholder = Container(
      width: 96,
      height: 72,
      color: s.placeholder,
      child: Icon(Icons.image_outlined, size: 24, color: s.muted),
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
