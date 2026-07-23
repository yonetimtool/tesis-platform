import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../auth/domain/user_role.dart';
import '../../budget/domain/budget_models.dart' show formatKurusAsTl;
import '../../dues/data/dues_api.dart';
import '../../kargo/data/kargo_api.dart';
import '../../profile/data/profile_api.dart';
import '../domain/home_menu.dart';
import 'aidat_ozet_karti.dart';
import 'module_card_spec.dart';
import 'role_home_body.dart';
import 'widgets/home_shell.dart';

/// Sakin ana ekrani (R1 + R1.1) — [HomeShell] + [RoleHomeBody] birlestirir,
/// provider'lari ve gezinmeyi baglar. R1.1 zenginlestirme: "Ödeme ve Aidat
/// Durumu" karti (/me/dues) + Aidatım ve Kargo kart sayaclari. Veri hatasi
/// ana ekrani DUSURMEZ: kart/sayac sessizce gizlenir, izgara calisir.
/// Ziyaretci "bekliyor" sayaci YOK — veri modelinde durum alani yok
/// (bilgilendirme akisi, onay yok).
class ResidentHomeScreen extends ConsumerWidget {
  const ResidentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ad = ref.watch(profileProvider).value?.ad ?? '';
    final units = ref.watch(myDuesProvider).value ?? const [];
    final kargoBekleyen = ref.watch(kargoBekleyenSayisiProvider).value ?? 0;

    final toplamBorc = units.fold<int>(
        0, (t, u) => t + (u.bakiyeKurus > 0 ? u.bakiyeKurus : 0));

    return HomeShell(
      role: UserRole.resident,
      currentIndex: 0,
      onDestinationSelected: (i) => _onTab(context, i),
      onBildir: () => context.push(AppRoutes.complaints),
      onProfile: () => context.push(AppRoutes.profile),
      body: RoleHomeBody(
        role: UserRole.resident,
        greetingName: ad,
        subtitle: UserRole.resident.label,
        onOpen: (entry) => context.push(moduleCardSpec(entry).route),
        counters: {
          if (units.isNotEmpty)
            HomeMenuEntry.myDues: toplamBorc > 0
                ? '₺${formatKurusAsTl(toplamBorc)} borç'
                : 'Borç Yok',
          if (kargoBekleyen > 0)
            HomeMenuEntry.kargo: '$kargoBekleyen Bekliyor',
        },
        sections: [
          if (units.isNotEmpty) ...[
            const SizedBox(height: 12),
            AidatOzetKarti(
              units: units,
              onDetay: () => context.push(AppRoutes.myDues),
            ),
          ],
        ],
      ),
    );
  }

  void _onTab(BuildContext context, int index) {
    switch (index) {
      case 1: // Bildirimler — /notifications RBAC sakine kapali (backend).
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Bildirimler yakında')),
          );
      case 3: // Raporlar — sakin icin seffaflik (aylik anonim ozet).
        context.push(AppRoutes.transparency);
      case 4: // Ayarlar.
        context.push(AppRoutes.settings);
    }
  }
}
