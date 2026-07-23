import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../auth/domain/user_role.dart';
import '../../budget/data/budget_api.dart';
import '../../complaints/data/complaint_api.dart';
import '../../notifications/data/notifications_controller.dart';
import '../../profile/data/profile_api.dart';
import '../domain/home_menu.dart';
import 'module_card_spec.dart';
import 'role_home_body.dart';
import 'widgets/home_shell.dart';
import 'yonetici_quick_stats.dart';

/// Yonetici ana ekrani (R2) — [HomeShell] + [RoleHomeBody]. Sakin ekraniyla
/// ayni push-tabanli desen; fark: alt-basligi "Yönetici Paneli", Raporlar
/// sekmesi aylik raporlara (/reports) gider. Rol-ozel zengin bolumler (Hizli
/// Ozet, Vardiya Durumu, Son Hareketler) R2.1'de [RoleHomeBody.sections]
/// uzerinden eklenecek.
class YoneticiHomeScreen extends ConsumerWidget {
  const YoneticiHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ad = ref.watch(profileProvider).value?.ad ?? '';
    // Hizli Ozet: veri gelince gorunur; yuklenirken/hatada SESSIZCE gizli
    // (ana ekran finans ucuna rehin degil — kartlar her durumda calisir).
    final finans = ref.watch(financialSummaryProvider).value;
    // Okunmamis bildirim rozeti; hata/yukleme → 0 (rozet yok, ekran calisir).
    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
    // R2.1: acik sikayet sayaci; hata → sayacsiz kart (ekran calisir).
    final acikSikayet = ref.watch(acikSikayetSayisiProvider).value ?? 0;

    return HomeShell(
      role: UserRole.yonetici,
      currentIndex: 0,
      unreadCount: unread,
      onDestinationSelected: (i) => _onTab(context, i),
      onBildir: () => context.push(AppRoutes.complaints),
      onProfile: () => context.push(AppRoutes.profile),
      body: RoleHomeBody(
        role: UserRole.yonetici,
        greetingName: ad,
        subtitle: 'Yönetici Paneli',
        onOpen: (entry) => context.push(moduleCardSpec(entry).route),
        counters: {
          if (acikSikayet > 0)
            HomeMenuEntry.complaints: '$acikSikayet Açık',
        },
        sections: [
          if (finans != null) ...[
            const SizedBox(height: 12),
            YoneticiQuickStats(summary: finans),
          ],
        ],
      ),
    );
  }

  void _onTab(BuildContext context, int index) {
    switch (index) {
      case 1: // Bildirimler inbox (RBAC: yonetici izinli).
        context.push(AppRoutes.notifications);
      case 3: // Raporlar — yonetici aylik raporlari.
        context.push(AppRoutes.reports);
      case 4: // Ayarlar.
        context.push(AppRoutes.settings);
    }
  }
}
