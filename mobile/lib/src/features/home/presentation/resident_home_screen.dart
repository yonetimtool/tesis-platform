import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../auth/domain/user_role.dart';
import '../../profile/data/profile_api.dart';
import 'module_card_spec.dart';
import 'resident_home_body.dart';
import 'widgets/home_shell.dart';

/// Sakin ana ekrani (R1) — [HomeShell] + [ResidentHomeBody] birlestirir,
/// provider'lari ve gezinmeyi baglar. Yalniz sakin rolune gosterilir (HomeGate
/// yonlendirir). Alt-bar push tabanli (uygulama geneli deseni): sekmeler hedef
/// rotayi acar, "Ana Sayfa" (index 0) bu ekranin kendisidir.
class ResidentHomeScreen extends ConsumerWidget {
  const ResidentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ad = ref.watch(profileProvider).value?.ad ?? '';

    return HomeShell(
      role: UserRole.resident,
      currentIndex: 0,
      onDestinationSelected: (i) => _onTab(context, i),
      onBildir: () => context.push(AppRoutes.complaints),
      onProfile: () => context.push(AppRoutes.profile),
      body: ResidentHomeBody(
        greetingName: ad,
        subtitle: UserRole.resident.label,
        onOpen: (entry) => context.push(moduleCardSpec(entry).route),
      ),
    );
  }

  void _onTab(BuildContext context, int index) {
    switch (index) {
      case 1: // Bildirimler — inbox ekrani henuz yok (MISSING-MOBILE).
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
