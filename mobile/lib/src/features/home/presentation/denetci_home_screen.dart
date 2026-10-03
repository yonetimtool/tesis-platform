import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/l10n.dart';
import '../../../routing/app_router.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/home_menu.dart';
import 'module_card_spec.dart';

/// (P253 Asama 2, karar §A-1) DENETCI ANA EKRANI — SALT OKUMA.
///
/// ONCEDEN (P139.2) denetci bir "web'i kullanin" ekrani goruyordu ve o
/// ekranda CIKIS bile yoktu. Karar degisti: denetci mobilde web'deki
/// kumesinin salt okuma karsiliklarini gorur (raporlar, seffaflik, icra,
/// bakim). Liste `homeMenuForRole(denetci)`DEN gelir — menu kilitleri
/// (`p251_menu_paritesi`) onu olcer; burada ikinci bir liste yok.
///
/// Fazla mesai mobilde Asama 3'te gelir; o gune kadar ve masabasi isleri
/// icin web adresi alt bilgide durur (kopyalanabilir).
class DenetciHomeScreen extends ConsumerWidget {
  const DenetciHomeScreen({super.key});

  /// Tesis yuzeyinin adresi — MARKA ADRESIDIR; cevrilmez.
  static const String adres = 'app.yonetiyor.com';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ikincil = Theme.of(context).colorScheme.onSurfaceVariant;
    final girisler = homeMenuForRole(UserRole.denetci);
    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.dntBaslik, context.dilKodu)),
        actions: [
          TextButton.icon(
            key: const Key('dnt-profil'),
            icon: const Icon(Icons.person_outline),
            label: Text(l10n.kabukProfil),
            onPressed: () => context.push(AppRoutes.profile),
          ),
          TextButton.icon(
            key: const Key('dnt-cikis'),
            icon: const Icon(Icons.logout),
            label: Text(l10n.kabukCikisYap),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(l10n.dntAlt, style: TextStyle(color: ikincil)),
          const SizedBox(height: 12),
          for (final e in girisler)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                key: Key('dnt-giris-${e.name}'),
                leading: Icon(moduleCardSpec(e).icon, color: moduleCardSpec(e).accent),
                title: Text(moduleBaslik(l10n, e)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(moduleCardSpec(e).route),
              ),
            ),
          const SizedBox(height: 16),
          Text(l10n.denetciWebBaslik, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            l10n.denetciWebGovde(adres),
            style: TextStyle(color: ikincil, fontSize: 12),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => Clipboard.setData(const ClipboardData(text: adres)),
              icon: const Icon(Icons.copy_all_outlined),
              label: Text(l10n.denetciWebKopyala),
            ),
          ),
        ],
      ),
    );
  }
}
