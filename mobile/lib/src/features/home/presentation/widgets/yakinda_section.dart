import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

import 'home_grid.dart';
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

    // Bolum ici kartlar TEK TIP boyutta cizsin diye ayni grubu paylasir.
    final titleGroup = AutoSizeGroup();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Yakında Eklenecekler'),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, c) {
          final cols = homeGridCols(c.maxWidth);
          return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: homeGridAspect(cols),
            children: [
              for (final k in kartlar)
                ModuleCard(
                  icon: k.icon,
                  title: k.title,
                  accent: k.accent,
                  dense: cols == 4,
                  comingSoon: true,
                  titleGroup: titleGroup,
                ),
            ],
          );
        }),
      ],
    );
  }
}
