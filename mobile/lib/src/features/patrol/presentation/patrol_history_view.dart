import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/patrol_models.dart';
import 'patrol_history_controller.dart';

/// Pencere gecmisi gorunumu (`GET /patrol-windows` — ozet + son pencereler).
/// Iki ekranda paylasilir: Turlarim "Gecmis" sekmesi (saha) ve yonetici
/// "Devriye takibi" ekrani. Veri: [patrolHistoryControllerProvider].
class PatrolHistoryView extends ConsumerWidget {
  const PatrolHistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(patrolHistoryControllerProvider);
    final controller = ref.read(patrolHistoryControllerProvider.notifier);

    if (state.loading && state.items.isEmpty && state.errorMessage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (state.errorMessage != null)
            PatrolErrorBanner(
              message: state.forbidden
                  ? 'Tur geçmişi için yetkiniz yok. Bu liste güvenlik '
                      've yönetici rollerine açıktır.'
                  : state.errorMessage!,
              onRetry: state.forbidden ? null : controller.refresh,
            ),
          if (state.items.isNotEmpty) ...[
            PatrolHistorySummary(ozet: state.ozet),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < state.items.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    PatrolHistoryTile(item: state.items[i]),
                  ],
                ],
              ),
            ),
          ] else if (state.errorMessage == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Henüz tur penceresi kaydı yok.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PatrolHistorySummary extends StatelessWidget {
  const PatrolHistorySummary({super.key, required this.ozet});

  final PatrolWindowOzet ozet;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, int value, Color color) => Chip(
          avatar: CircleAvatar(backgroundColor: color, radius: 6),
          label: Text('$label $value'),
          visualDensity: VisualDensity.compact,
        );
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        chip('Toplam', ozet.toplam, Colors.blueGrey),
        chip('Tamamlandı', ozet.tamamlandi, Colors.green),
        chip('Kaçırıldı', ozet.kacirildi, Colors.red),
        chip('Bekliyor', ozet.bekliyor, Colors.orange),
      ],
    );
  }
}

class PatrolHistoryTile extends StatelessWidget {
  const PatrolHistoryTile({super.key, required this.item});

  final PatrolWindowHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (item.durum) {
      PatrolWindowDurum.tamamlandi => (
          Icons.check_circle,
          Colors.green,
          'Tamamlandı',
        ),
      PatrolWindowDurum.kacirildi => (Icons.cancel, Colors.red, 'Kaçırıldı'),
      PatrolWindowDurum.bekliyor => (
          Icons.hourglass_top,
          Colors.orange,
          'Bekliyor',
        ),
      PatrolWindowDurum.bilinmiyor => (
          Icons.help_outline,
          Colors.grey,
          'Bilinmiyor',
        ),
    };
    final start = item.pencereBaslangic.toLocal();
    final end = item.pencereBitis.toLocal();
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(item.planAdi ?? 'Devriye turu'),
      subtitle: Text(
        '${fmtDate(start)} · ${fmtClock(start)} – ${fmtClock(end)}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: TextStyle(color: color)),
          Text(
            '${item.okutulanCheckpointSayisi}/${item.beklenenCheckpointSayisi}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Hata banner'i — retry butonlu (patrol ekranlarinin ortak parcasi).
class PatrolErrorBanner extends StatelessWidget {
  const PatrolErrorBanner({super.key, required this.message, this.onRetry});

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.withValues(alpha: 0.08),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.red)),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: () => onRetry!(),
                child: const Text('Tekrar dene'),
              ),
          ],
        ),
      ),
    );
  }
}

String _two(int v) => v.toString().padLeft(2, '0');

String fmtClock(DateTime local) => '${_two(local.hour)}:${_two(local.minute)}';

String fmtDate(DateTime local) =>
    '${_two(local.day)}.${_two(local.month)}.${local.year}';

String fmtDuration(Duration d) {
  if (d.inHours >= 1) {
    return '${d.inHours} sa ${_two(d.inMinutes % 60)} dk';
  }
  if (d.inMinutes >= 1) {
    return '${d.inMinutes} dk ${_two(d.inSeconds % 60)} sn';
  }
  return '${d.inSeconds} sn';
}
