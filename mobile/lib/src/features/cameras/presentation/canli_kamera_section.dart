import 'package:flutter/material.dart';

import '../../home/presentation/widgets/section_header.dart';
import '../domain/camera_models.dart';

/// Ana ekranin "Canlı Kamera" seridi (WP-F, referans gorevli.jpeg) —
/// kameralari yatay koyu kartlarla listeler; dokununca [onIzle] cagrilir.
/// Bos listede bolum HIC cizilmez (ana ekran rehin degil).
class CanliKameraSection extends StatelessWidget {
  const CanliKameraSection({
    super.key,
    required this.kameralar,
    required this.onIzle,
  });

  final List<Camera> kameralar;
  final ValueChanged<Camera> onIzle;

  @override
  Widget build(BuildContext context) {
    if (kameralar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Canlı Kamera'),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kameralar.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final k = kameralar[i];
              return _KameraKarti(kamera: k, onTap: () => onIzle(k));
            },
          ),
        ),
      ],
    );
  }
}

class _KameraKarti extends StatelessWidget {
  const _KameraKarti({required this.kamera, required this.onTap});

  final Camera kamera;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: Colors.black87,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              const Positioned.fill(
                child: Center(
                  child: Icon(Icons.play_circle_fill,
                      color: Colors.white70, size: 36),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      kamera.ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    const Row(
                      children: [
                        Icon(Icons.circle, color: Color(0xFF16A34A), size: 8),
                        SizedBox(width: 4),
                        Text('Canlı',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
