import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/scan_outbox.dart';
import '../domain/outbox_entry.dart';

/// Outbox durumu: bekleyen/gonderilen/kalici hatali kayitlarin listesi,
/// manuel "simdi senkronla" ve kalici hatalari temizleme. Islevsel/basit.
class OutboxScreen extends ConsumerWidget {
  const OutboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanOutboxProvider);
    final outbox = ref.read(scanOutboxProvider.notifier);

    // En yeni ustte gorunsun (gonderim sirasi yine FIFO'dur).
    final entries = state.entries.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gonderim kuyrugu'),
        actions: [
          if (state.failedCount > 0)
            IconButton(
              tooltip: 'Kalici hatalari temizle',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => outbox.clearFailed(),
            ),
        ],
      ),
      body: Column(
        children: [
          _SyncBar(state: state, onSync: outbox.syncNow),
          const Divider(height: 1),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('Kuyruk bos.'))
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) =>
                        _EntryTile(entry: entries[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SyncBar extends StatelessWidget {
  const _SyncBar({required this.state, required this.onSync});

  final ScanOutboxState state;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${state.pendingCount} bekliyor · ${state.failedCount} kalici hata',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          if (state.syncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            FilledButton.tonalIcon(
              onPressed: state.pendingCount > 0 ? onSync : null,
              icon: const Icon(Icons.sync),
              label: const Text('Simdi senkronla'),
            ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final OutboxEntry entry;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (entry.status) {
      OutboxStatus.bekliyor => (
          Icons.schedule,
          Colors.orange,
          'Bekliyor${entry.attemptCount > 0 ? ' (deneme: ${entry.attemptCount})' : ''}',
        ),
      OutboxStatus.gonderiliyor => (
          Icons.sync,
          Colors.blue,
          'Gonderiliyor...',
        ),
      OutboxStatus.gonderildi => (
          Icons.check_circle_outline,
          Colors.green,
          entry.outcome == OutboxOutcome.duplicate
              ? 'Gonderildi (zaten kayitliydi)'
              : 'Gonderildi (yeni kayit)',
        ),
      OutboxStatus.kaliciHata => (
          Icons.link_off,
          Colors.red,
          'Kalici hata: ${entry.lastError ?? 'etiket eslesmedi'}',
        ),
    };

    final local = entry.okutmaZamani.toLocal();
    final ts =
        '${local.year}-${_p(local.month)}-${_p(local.day)} ${_p(local.hour)}:${_p(local.minute)}:${_p(local.second)}';

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        entry.nfcTagUid,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
      subtitle: Text('$ts\n$label'),
      isThreeLine: true,
      dense: true,
    );
  }

  static String _p(int v) => v.toString().padLeft(2, '0');
}
