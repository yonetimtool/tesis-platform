import 'package:flutter/material.dart';

import '../../auth/domain/user_role.dart';
import '../domain/home_featured.dart';
import '../domain/home_menu.dart';
import 'module_card_spec.dart';
import 'widgets/home_header.dart';
import 'widgets/module_card.dart';
import 'widgets/section_header.dart';

/// Sakin ana ekraninin GOVDESI — saf sunum: veriyi disaridan alir, kart
/// dokunuslarini [onOpen] ile geri bildirir (provider/router BAGIMSIZ, tam
/// test edilebilir). Duzen referans site-sakini.jpeg: karsilama + 2 sutunlu
/// "one cikan" kart izgarasi ([featuredMenuForRole]) + "Tüm Modüller"
/// ([moreMenuForRole]).
class ResidentHomeBody extends StatelessWidget {
  const ResidentHomeBody({
    super.key,
    required this.greetingName,
    required this.subtitle,
    required this.onOpen,
    this.weather,
  });

  final String greetingName;
  final String subtitle;
  final ValueChanged<HomeMenuEntry> onOpen;
  final HomeWeather? weather;

  @override
  Widget build(BuildContext context) {
    final featured = featuredMenuForRole(UserRole.resident);
    final more = moreMenuForRole(UserRole.resident);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        HomeHeader(
          greetingName: greetingName,
          subtitle: subtitle,
          weather: weather,
        ),
        const SizedBox(height: 16),
        _grid(featured),
        if (more.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SectionHeader(title: 'Tüm Modüller'),
          const SizedBox(height: 8),
          _grid(more),
        ],
      ],
    );
  }

  Widget _grid(List<HomeMenuEntry> entries) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: [
        for (final entry in entries)
          Builder(builder: (context) {
            final spec = moduleCardSpec(entry);
            return ModuleCard(
              icon: spec.icon,
              title: spec.title,
              accent: spec.accent,
              onTap: () => onOpen(entry),
            );
          }),
      ],
    );
  }
}
