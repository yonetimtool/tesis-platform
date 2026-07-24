import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

import '../../auth/domain/user_role.dart';
import '../domain/home_featured.dart';
import '../domain/home_menu.dart';
import 'module_card_spec.dart';
import 'widgets/home_grid.dart';
import 'widgets/home_header.dart';
import 'widgets/module_card.dart';
import 'widgets/section_header.dart';

/// Rol-parametrik ana ekran GOVDESI — saf sunum: veriyi disaridan alir, kart
/// dokunuslarini [onOpen] ile geri bildirir (provider/router BAGIMSIZ, tam
/// test edilebilir). Duzen referans tasarimlarin ortak iskeleti: karsilama +
/// 4'lu (dar ekranda 2'li) "one cikan" izgara ([featuredMenuForRole]) +
/// "Tüm Modüller" ([moreMenuForRole]). Rol-ozel ek bolumler (Hizli Ozet, Son
/// Hareketler...) [sections] ile one cikan izgaranin ALTINA eklenir.
class RoleHomeBody extends StatelessWidget {
  const RoleHomeBody({
    super.key,
    required this.role,
    required this.greetingName,
    required this.subtitle,
    required this.onOpen,
    this.weather,
    this.sections = const [],
    this.counters = const {},
  });

  final UserRole role;
  final String greetingName;
  final String subtitle;
  final ValueChanged<HomeMenuEntry> onOpen;
  final HomeWeather? weather;

  /// One cikan izgara ile "Tüm Modüller" ARASINA giren rol-ozel bolumler
  /// (or. yonetici Hizli Ozet / Son Hareketler — R2.1).
  final List<Widget> sections;

  /// Kart alt-satiri sayaclari (or. outbox → "3 bekleyen"). Girisi olmayan
  /// kartlar sayacsiz cizilir.
  final Map<HomeMenuEntry, String> counters;

  @override
  Widget build(BuildContext context) {
    final featured = featuredMenuForRole(role);
    final more = moreMenuForRole(role);
    // Tum modul kartlari (one cikan + Tüm Modüller) TEK TIP boyutta cizsin
    // diye ayni gruplari paylasir.
    final titleGroup = AutoSizeGroup();
    final counterGroup = AutoSizeGroup();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        HomeHeader(
          greetingName: greetingName,
          subtitle: subtitle,
          weather: weather,
        ),
        const SizedBox(height: 16),
        _grid(featured, titleGroup, counterGroup),
        ...sections,
        if (more.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SectionHeader(title: 'Tüm Modüller'),
          const SizedBox(height: 8),
          _grid(more, titleGroup, counterGroup),
        ],
      ],
    );
  }

  Widget _grid(
    List<HomeMenuEntry> entries,
    AutoSizeGroup titleGroup,
    AutoSizeGroup counterGroup,
  ) {
    return LayoutBuilder(builder: (context, c) {
      final cols = homeGridCols(c.maxWidth);
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: homeGridAspect(cols),
        children: [
          for (final entry in entries)
            Builder(builder: (context) {
              final spec = moduleCardSpec(entry);
              return ModuleCard(
                icon: spec.icon,
                title: spec.title,
                accent: spec.accent,
                counter: counters[entry],
                dense: cols == 4,
                titleGroup: titleGroup,
                counterGroup: counterGroup,
                onTap: () => onOpen(entry),
              );
            }),
        ],
      );
    });
  }
}
