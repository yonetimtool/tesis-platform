import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/text/tr_upper.dart';
import '../../../routing/app_router.dart';
import '../../scan/data/scan_outbox.dart';
import '../../scan/domain/outbox_entry.dart';
import '../../scan/domain/scan.dart';
import '../domain/nfc_read_result.dart';
import 'nfc_controller.dart';

/// "Etiketi okutun" ekrani. Etiket okununca okutma ANINDA kalici outbox'a
/// yazilir (offline'da kaybolmaz); baglanti varsa arka planda hemen gonderilir
/// ve sonuc (yeni / zaten kayitli / eslesmedi) burada gosterilir.
class NfcScreen extends ConsumerStatefulWidget {
  const NfcScreen({super.key});

  @override
  ConsumerState<NfcScreen> createState() => _NfcScreenState();
}

class _NfcScreenState extends ConsumerState<NfcScreen> {
  /// Bu ekranda son okutulan kaydin outbox anahtari — durum kutusu bunu izler.
  String? _currentKey;

  Future<void> _startNewRead() async {
    setState(() => _currentKey = null);
    await ref.read(nfcControllerProvider.notifier).startReading();
    if (!mounted) return;

    final result = ref.read(nfcControllerProvider).result;
    if (result == null || !result.isSuccess || result.uid == null) return;

    // Okuma aninda taslak uret: okutma zamani + idempotency-key SABITLENIR.
    // NTAG424 SDM alanlari (varsa) taslaga eklenir; NTAG21x'te null kalir ve
    // govdeye hic girmez — mevcut akis degismez.
    final sdm = result.sdmData;
    final draft = ScanDraft(
      nfcTagUid: result.uid!,
      okutmaZamani: result.readAt ?? DateTime.now().toUtc(),
      sdmPiccData: sdm?.piccData,
      sdmCmac: sdm?.cmac,
    );
    setState(() => _currentKey = draft.idempotencyKey);
    await ref.read(scanOutboxProvider.notifier).enqueue(draft);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nfcControllerProvider);
    final nfc = ref.read(nfcControllerProvider.notifier);
    final outboxState = ref.watch(scanOutboxProvider);
    final currentEntry =
        _currentKey == null ? null : outboxState.byKey(_currentKey!);

    return Scaffold(
      appBar: AppBar(
        title: Text(trUpper('NFC etiket okuma')),
        actions: [
          _OutboxBadge(
            pendingCount: outboxState.pendingCount,
            onTap: () => context.push(AppRoutes.outbox),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusIcon(status: state.status),
              const SizedBox(height: 16),
              Text(
                _statusLabel(state.status),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (state.status == NfcStatus.success && state.result != null) ...[
                _ResultCard(result: state.result!),
                const SizedBox(height: 16),
                _OutboxOutcome(entry: currentEntry),
              ],
              if (state.status == NfcStatus.error)
                _ErrorBox(message: state.errorMessage ?? 'Hata'),
              const SizedBox(height: 32),
              _ActionButton(
                status: state.status,
                onRead: _startNewRead,
                onCancel: nfc.cancel,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(NfcStatus status) {
    return switch (status) {
      NfcStatus.ready => 'Okumaya hazır. Başlat\'a dokunun.',
      NfcStatus.reading => 'Etiketi telefonun arkasına yaklaştırın...',
      NfcStatus.success => 'Etiket okundu.',
      NfcStatus.error => 'Etiket okunamadı.',
    };
  }
}

/// AppBar'daki bekleyen-kayit rozeti ("3 bekliyor" → kuyruk ekrani).
class _OutboxBadge extends StatelessWidget {
  const _OutboxBadge({required this.pendingCount, required this.onTap});

  final int pendingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: pendingCount > 0
          ? '$pendingCount okutma gönderim bekliyor'
          : 'Gönderim kuyruğu',
      onPressed: onTap,
      icon: Badge(
        isLabelVisible: pendingCount > 0,
        label: Text('$pendingCount'),
        child: const Icon(Icons.outbox_outlined),
      ),
    );
  }
}

/// Okutmanin outbox'taki durumunu kullaniciya anlasilir yansitir:
/// kaydedildi (gonderilecek) / gonderiliyor / gonderildi / eslesmedi.
class _OutboxOutcome extends StatelessWidget {
  const _OutboxOutcome({required this.entry});

  final OutboxEntry? entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    if (e == null) return const SizedBox.shrink();

    return switch (e.status) {
      OutboxStatus.bekliyor => const _ScanOutcome(
          icon: Icons.check_circle,
          color: Colors.teal,
          text:
              'Kaydedildi ✓ — bağlantı gelince otomatik gönderilecek.',
        ),
      OutboxStatus.gonderiliyor => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Kaydedildi ✓ — gönderiliyor...'),
            ],
          ),
        ),
      OutboxStatus.gonderildi => e.outcome == OutboxOutcome.duplicate
          ? const _ScanOutcome(
              icon: Icons.info_outline,
              color: Colors.blueGrey,
              text: 'Gönderildi ✓ — bu okutma zaten kayıtlıydı.',
            )
          : const _ScanOutcome(
              icon: Icons.check_circle,
              color: Colors.green,
              text: 'Gönderildi ✓ — okutma kaydedildi.',
            ),
      OutboxStatus.kaliciHata => _ScanOutcome(
          icon: Icons.link_off,
          color: Colors.orange,
          text: e.lastError ?? 'Bu etiket hiçbir checkpoint ile eşleşmiyor.',
        ),
    };
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final NfcStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == NfcStatus.reading) {
      return const SizedBox(
        width: 64,
        height: 64,
        child: CircularProgressIndicator(strokeWidth: 5),
      );
    }
    final (icon, color) = switch (status) {
      NfcStatus.ready => (Icons.nfc, Colors.blueGrey),
      NfcStatus.success => (Icons.check_circle_outline, Colors.green),
      NfcStatus.error => (Icons.error_outline, Colors.red),
      NfcStatus.reading => (Icons.nfc, Colors.blueGrey),
    };
    return Icon(icon, size: 64, color: color);
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final NfcReadResult result;

  @override
  Widget build(BuildContext context) {
    final sdm = result.sdmData;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _KvRow(label: 'UID', value: result.uid ?? '-'),
            const SizedBox(height: 8),
            _KvRow(label: 'Tip', value: result.tagType.name),
            if (sdm != null) ...[
              const Divider(height: 24),
              const Text(
                'SDM (ham, doğrulanmamış)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _KvRow(label: 'PICCData', value: sdm.piccData ?? '-'),
              _KvRow(label: 'CMAC', value: sdm.cmac ?? '-'),
              _KvRow(label: 'URL', value: sdm.rawUrl),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScanOutcome extends StatelessWidget {
  const _ScanOutcome({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Flexible(child: Text(text, style: TextStyle(color: color))),
      ],
    );
  }
}

class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(color: Colors.red)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.status,
    required this.onRead,
    required this.onCancel,
  });

  final NfcStatus status;
  final VoidCallback onRead;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case NfcStatus.reading:
        return OutlinedButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.close),
          label: const Text('Vazgeç'),
        );
      case NfcStatus.ready:
        return FilledButton.icon(
          onPressed: onRead,
          icon: const Icon(Icons.nfc),
          label: const Text('Okumayı başlat'),
        );
      case NfcStatus.success:
      case NfcStatus.error:
        return OutlinedButton.icon(
          onPressed: onRead,
          icon: const Icon(Icons.refresh),
          label: const Text('Tekrar oku'),
        );
    }
  }
}
