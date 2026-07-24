import 'package:flutter/material.dart';

import '../../../../core/theme/home_tokens.dart';
import '../../../auth/domain/user_role.dart';
import '../../domain/home_menu.dart';
import '../module_card_spec.dart';
import 'home_card.dart';
import 'home_marka.dart';

/// App-bar'daki hamburger menunun actigi cekmece — rolun TUM modulleri.
///
/// Referans ana ekranlarda hizli erisim izgarasi 8 (gorevlide 5) sabit karta
/// indi; geri kalan moduller (turlar, gorevler, demirbas, rezervasyon,
/// entegrasyonlar...) erisilebilir kalsin diye buraya tasindi. Gorunurluk
/// TEK KAYNAK [homeMenuForRole]'dan gelir — cekmece kendi listesini tutmaz.
class HomeDrawer extends StatelessWidget {
  const HomeDrawer({
    super.key,
    required this.role,
    required this.onModul,
    this.onProfile,
    this.onLogout,
  });

  final UserRole role;

  /// Secilen modulun rotasi.
  final ValueChanged<String> onModul;

  final VoidCallback? onProfile;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    final moduller = homeMenuForRole(role);

    return Drawer(
      backgroundColor: s.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: HomeMarka(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                role.label,
                style: HomeText.cardCounter.copyWith(color: s.muted),
              ),
            ),
            Divider(height: 1, color: s.divider),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final entry in moduller)
                    Builder(builder: (context) {
                      final spec = moduleCardSpec(entry);
                      return ListTile(
                        leading: HomeIconBox(
                          icon: spec.icon,
                          accent: spec.accent,
                          size: 36,
                          radius: 10,
                          iconSize: 20,
                        ),
                        title: Text(
                          spec.title,
                          style:
                              HomeText.cardTitle.copyWith(color: s.heading),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          onModul(spec.route);
                        },
                      );
                    }),
                ],
              ),
            ),
            Divider(height: 1, color: s.divider),
            ListTile(
              leading: Icon(Icons.person_outline, color: s.body),
              title: Text('Profil',
                  style: HomeText.cardTitle.copyWith(color: s.heading)),
              onTap: () {
                Navigator.of(context).pop();
                onProfile?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: HomeTokens.red),
              title: Text('Çıkış Yap',
                  style: HomeText.cardTitle.copyWith(color: HomeTokens.red)),
              onTap: () {
                Navigator.of(context).pop();
                onLogout?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}
