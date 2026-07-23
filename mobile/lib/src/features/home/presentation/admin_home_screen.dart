import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../auth/domain/user_role.dart';
import '../../notifications/data/notifications_controller.dart';
import '../../profile/data/profile_api.dart';
import '../../scan/data/scan_outbox.dart';
import '../domain/home_menu.dart';
import 'module_card_spec.dart';
import 'role_home_body.dart';
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

    return HomeShell(
      role: UserRole.admin,
      currentIndex: 0,
      unreadCount: unread,
      onDestinationSelected: (i) => _onTab(context, i),
      onBildir: () => context.push(AppRoutes.complaints),
      onProfile: () => context.push(AppRoutes.profile),
      body: RoleHomeBody(
        role: UserRole.admin,
        greetingName: ad,
        subtitle: UserRole.admin.label,
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
