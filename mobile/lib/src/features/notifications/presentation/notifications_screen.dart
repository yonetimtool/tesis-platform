import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/presentation/widgets/activity_row.dart';
import '../data/notifications_controller.dart';
import '../domain/notification_models.dart';

const _red = Color(0xFFDC2626);
const _amber = Color(0xFFD97706);
const _navy = Color(0xFF0E3C91);

/// Bildirimler inbox'i (yonetici + guvenlik; RBAC sakin/tesis gorevlisine
/// kapali). Liste en-yeni-ustte; okunmamis satirda "Yeni" rozeti, dokununca
/// okundu isaretlenir (iyimser) — okunmusa dokunmak PATCH uretmez.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: async.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('Bildirim yok'))
            : RefreshIndicator(
                onRefresh: () => ref.refresh(notificationsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) =>
                      _NotificationRow(bildirim: items[i]),
                ),
              ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Bildirimler yüklenemedi.\n$e',
                textAlign: TextAlign.center),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _NotificationRow extends ConsumerWidget {
  const _NotificationRow({required this.bildirim});

  final AppNotification bildirim;

  /// Alarm tipleri kirmizi, gecikmeler amber, geri kalan navy.
  Color get _accent => switch (bildirim.tip) {
        'kacirilan_tur' || 'eksik_checkpoint' => _red,
        'gecikmis_okutma' => _amber,
        _ => _navy,
      };

  IconData get _icon => switch (bildirim.tip) {
        'kacirilan_tur' => Icons.directions_walk,
        'eksik_checkpoint' || 'gecikmis_okutma' => Icons.location_on_outlined,
        _ => Icons.notifications_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = bildirim.createdAt?.toLocal();
    final zaman = t == null
        ? ''
        : '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')} '
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Row(
      children: [
        Expanded(
          child: ActivityRow(
            icon: _icon,
            title: bildirim.mesaj,
            subtitle: bildirim.tip.replaceAll('_', ' '),
            time: zaman,
            accent: _accent,
            onTap: bildirim.okundu
                ? null
                : () => ref
                    .read(notificationsProvider.notifier)
                    .markRead(bildirim.id),
          ),
        ),
        if (!bildirim.okundu)
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Yeni',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _accent, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}
