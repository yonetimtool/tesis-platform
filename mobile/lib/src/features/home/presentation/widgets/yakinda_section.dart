import 'package:flutter/material.dart';

import 'module_card.dart';
import 'section_header.dart';

/// "Yakında Eklenecekler" pasif kart izgarasinin tek karti: MISSING-BACKEND
/// bir referans ogesi (servis gelince gercek karta/bolume doner).
class YakindaKart {
  const YakindaKart({
    required this.icon,
    required this.title,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final Color accent;
}

/// MISSING-BACKEND referans kartlari — gorunur-ama-pasif "Yakında" izgarasi
/// (dokunma ModuleCard.comingSoon'da yutulur). Rol ekranlari kendi listesini
/// gecer (saha + yonetici). Liste bossa bolum HIC cizilmez.
class YakindaSection extends StatelessWidget {
  const YakindaSection({super.key, required this.kartlar});

  final List<YakindaKart> kartlar;

  @override
  Widget build(BuildContext context) {
    if (kartlar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Yakında Eklenecekler'),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            for (final k in kartlar)
              ModuleCard(
                icon: k.icon,
                title: k.title,
                accent: k.accent,
                comingSoon: true,
              ),
          ],
        ),
      ],
    );
  }
}
