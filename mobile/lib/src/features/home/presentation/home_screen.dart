import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../scan/data/scan_outbox.dart';
import '../domain/home_menu.dart';

/// Giris sonrasi ana ekran — menu, role gore bilesir (home_menu.dart;
/// contracts/auth.md §4 UX aynasi). Rol cozulene kadar (storage okumasi,
/// saniye alti) yalnizca baslik gorunur.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outboxState = ref.watch(scanOutboxProvider);
    final role =
        ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    final entries = homeMenuForRole(role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ana ekran'),
        actions: [
          IconButton(
            tooltip: 'Cikis yap',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Giris basarili',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (role != UserRole.unknown)
                Text(
                  role.label,
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
              const SizedBox(height: 24),
              for (final entry in entries)
                _menuCard(context, entry, outboxState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuCard(
    BuildContext context,
    HomeMenuEntry entry,
    ScanOutboxState outboxState,
  ) {
    switch (entry) {
      case HomeMenuEntry.emergency:
        // Belirgin (kirmizi) giris; yanlis basmaya karsi asil koruma
        // ekrandaki ONAY dialogudur.
        return Card(
          color: Colors.red,
          child: ListTile(
            leading: const Icon(Icons.sos, color: Colors.white, size: 32),
            title: const Text(
              'ACIL DURUM',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: const Text(
              'Panik butonu — yonetime alarm gonder',
              style: TextStyle(color: Colors.white70),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white),
            onTap: () => context.push(AppRoutes.emergency),
          ),
        );
      case HomeMenuEntry.patrol:
        return Card(
          child: ListTile(
            leading: const Icon(Icons.directions_walk),
            title: const Text('Turlarim'),
            subtitle: const Text(
              'Aktif devriye penceresi ve nokta ilerlemesi',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.patrol),
          ),
        );
      case HomeMenuEntry.tasks:
        return Card(
          child: ListTile(
            leading: const Icon(Icons.task_alt),
            title: const Text('Gorevlerim'),
            subtitle: const Text(
              'Gorev listesi ve foto kanitli tamamlama',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.tasks),
          ),
        );
      case HomeMenuEntry.taskTracking:
        // Yonetici: ayni gorev listesi, tamamlama akisi detayda gizli.
        return Card(
          child: ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('Gorev takibi'),
            subtitle: const Text(
              'Gorevleri izle — tamamlama saha personelinde',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.tasks),
          ),
        );
      case HomeMenuEntry.assets:
        return Card(
          child: ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Demirbas'),
            subtitle: const Text(
              'NFC ile zimmet al/birak, uzerimdekiler',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.assets),
          ),
        );
      case HomeMenuEntry.nfc:
        return Card(
          child: ListTile(
            leading: const Icon(Icons.nfc),
            title: const Text('NFC etiket okuma'),
            subtitle: const Text('Devriye noktasi etiketini okut'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.nfc),
          ),
        );
      case HomeMenuEntry.outbox:
        return Card(
          child: ListTile(
            leading: Badge(
              isLabelVisible: outboxState.pendingCount > 0,
              label: Text('${outboxState.pendingCount}'),
              child: const Icon(Icons.outbox_outlined),
            ),
            title: const Text('Gonderim kuyrugu'),
            subtitle: Text(
              outboxState.pendingCount > 0
                  ? '${outboxState.pendingCount} okutma gonderim bekliyor'
                  : outboxState.failedCount > 0
                      ? '${outboxState.failedCount} kalici hata var'
                      : 'Bekleyen okutma yok',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.outbox),
          ),
        );
      case HomeMenuEntry.yoneticiInfo:
        return const Card(
          child: ListTile(
            leading: Icon(Icons.insights_outlined),
            title: Text('Devriye takibi ve raporlar'),
            subtitle: Text(
              'NFC tur takibi, aylik raporlar ve duyurular sonraki '
              'surumde bu ekrana eklenecek.',
            ),
          ),
        );
      case HomeMenuEntry.residentInfo:
        return const Card(
          child: ListTile(
            leading: Icon(Icons.home_outlined),
            title: Text('Sakin ozellikleri hazirlaniyor'),
            subtitle: Text(
              'Aidat goruntuleme ve duyurular sonraki surumde '
              'kullanima acilacak.',
            ),
          ),
        );
    }
  }
}
