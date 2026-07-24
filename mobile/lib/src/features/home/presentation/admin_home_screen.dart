import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import 'widgets/bildir_menu_sheet.dart';
import '../../notifications/data/notifications_controller.dart';
import '../../profile/data/profile_api.dart';
import '../../scan/data/scan_outbox.dart';
import '../../weather/data/weather_api.dart';
import '../../weather/domain/weather_models.dart';
import '../domain/home_menu.dart';
import 'module_card_spec.dart';
import 'role_home_body.dart';
import 'widgets/home_header.dart';
import 'widgets/home_shell.dart';

/// Platform admin ana ekrani — eski izgara HomeScreen'in emekliligiyle admin
/// de yeni tasarima gecti (rol-gorunurluk yine home_menu/home_featured tek
/// kaynagindan). Admin agirlikla PANEL kullanir; mobil ekrani operasyon
/// kartlari + outbox sayaci (saha kaniti) + bildirim rozetiyle sinirlidir.
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ad = ref.watch(profileProvider).value?.ad ?? '';
    final pending = ref.watch(scanOutboxProvider).pendingCount;
    // Admin /notifications RBAC-izinli; hata/yukleme → 0 (rozet yok).
    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
    // Baslik hava blogu — veri gelince gorunur; yukleme/hatada SESSIZCE gizli.
    final hava = ref.watch(weatherProvider).maybeWhen(
          data: (w) => HomeWeather(
            tempLabel: w.tempLabel,
            city: w.konumAd,
            icon: weatherIcon(w.durum),
          ),
          orElse: () => null,
        );

    return HomeShell(
      role: UserRole.admin,
      currentIndex: 0,
      unreadCount: unread,
      onDestinationSelected: (i) => _onTab(context, i),
      // WP2.4: merkez FAB rol-bazli olusturma menusu acar.
      onBildir: () => showBildirMenu(context, girisler: const [
        BildirGiris(icon: Icons.rate_review_outlined,
            label: 'Olay Bildir', route: AppRoutes.complaints),
        BildirGiris(icon: Icons.task_alt,
            label: 'Görevlerim', route: AppRoutes.tasks),
      ], onSec: (r) => context.push(r)),
      onProfile: () => context.push(AppRoutes.profile),
      onLogout: () =>
          ref.read(authControllerProvider.notifier).logout(),
      body: RoleHomeBody(
        role: UserRole.admin,
        greetingName: ad,
        subtitle: UserRole.admin.label,
        weather: hava,
        onOpen: (entry) => context.push(moduleCardSpec(entry).route),
        counters: {
          if (pending > 0) HomeMenuEntry.outbox: '$pending bekleyen',
        },
      ),
    );
  }

  void _onTab(BuildContext context, int index) {
    switch (index) {
      case 1: // Bildirimler inbox (RBAC: admin izinli).
        context.push(AppRoutes.notifications);
      case 3: // Raporlar (RBAC: admin izinli).
        context.push(AppRoutes.reports);
      case 4: // Ayarlar.
        context.push(AppRoutes.settings);
    }
  }
}
