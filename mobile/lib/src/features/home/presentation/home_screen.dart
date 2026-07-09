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
      // Cok kartli rolde (or. guvenlik) icerik kucuk ekrani asabildiginden
      // liste kaydirilabilir; icerik sigarsa eski gorunum gibi ortali kalir.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                // 48 = dikey padding (24 ust + 24 alt); negatife dusmesin.
                minHeight: (constraints.maxHeight - 48).clamp(0, double.infinity).toDouble(),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'Giris basarili',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
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
      case HomeMenuEntry.announcements:
        return Card(
          child: ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: const Text('Duyurular'),
            subtitle: const Text('Yonetimden tesise duyurular'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.announcements),
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
      case HomeMenuEntry.patrolTracking:
        // Yonetici: salt izleme — panelin canli ozetinin mobil karsiligi.
        return Card(
          child: ListTile(
            leading: const Icon(Icons.route_outlined),
            title: const Text('Devriye takibi'),
            subtitle: const Text(
              'Bugunun turlari, nokta ilerlemesi ve gecmis',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.patrolTracking),
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
        // Gorev-YONETIMI: tum gorev/atama takibi ("Herkes" kapsamiyla
        // acilir). "Yeni gorev" butonu ekranda rol kapilidir (yonetim).
        return Card(
          child: ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('Gorev yonetimi'),
            subtitle: const Text(
              'Tum gorevleri ve atamalari izle; atama yonetimde',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                context.push('${AppRoutes.tasks}?gorunum=yonetim'),
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
      case HomeMenuEntry.reports:
        // Yonetici: ay bazli devriye/gorev/aidat ozeti (salt okuma).
        return Card(
          child: ListTile(
            leading: const Icon(Icons.insights_outlined),
            title: const Text('Aylik raporlar'),
            subtitle: const Text(
              'Devriye, gorev tamamlama ve aidat ozeti',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.reports),
          ),
        );
      case HomeMenuEntry.myDues:
        // Resident: kendi dairelerinin borc durumu (salt okuma).
        return Card(
          child: ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Aidatim'),
            subtitle: const Text(
              'Daire borc durumu, tahakkuk ve odeme gecmisi',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.myDues),
          ),
        );
      case HomeMenuEntry.complaints:
        // Sakin<->yonetim kanali: sakin talep acar, yonetim yanitlar.
        return Card(
          child: ListTile(
            leading: const Icon(Icons.rate_review_outlined),
            title: const Text('Sikayet / Oneri'),
            subtitle: const Text(
              'Yonetime talep ilet, durum ve yaniti izle',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.complaints),
          ),
        );
    }
  }
}
