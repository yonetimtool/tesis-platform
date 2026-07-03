import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../scan/data/scan_outbox.dart';

/// Giris sonrasi placeholder ana ekran. Icerik (vardiya/devriye/scan) sonraki
/// promptlarda eklenecek.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outboxState = ref.watch(scanOutboxProvider);
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
              const Text(
                'Operasyon ekranlari sonraki adimlarda eklenecek.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // ACIL DURUM — belirgin (kirmizi) giris; yanlis basmaya karsi
              // asil koruma ekrandaki ONAY dialogudur.
              Card(
                color: Colors.red,
                child: ListTile(
                  leading:
                      const Icon(Icons.sos, color: Colors.white, size: 32),
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
                  trailing:
                      const Icon(Icons.chevron_right, color: Colors.white),
                  onTap: () => context.push(AppRoutes.emergency),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.directions_walk),
                  title: const Text('Turlarim'),
                  subtitle: const Text(
                    'Aktif devriye penceresi ve nokta ilerlemesi',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.patrol),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.task_alt),
                  title: const Text('Gorevlerim'),
                  subtitle: const Text(
                    'Gorev listesi ve foto kanitli tamamlama',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.tasks),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Demirbas'),
                  subtitle: const Text(
                    'NFC ile zimmet al/birak, uzerimdekiler',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.assets),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.nfc),
                  title: const Text('NFC etiket okuma'),
                  subtitle: const Text('Devriye noktasi etiketini okut'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.nfc),
                ),
              ),
              Card(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
