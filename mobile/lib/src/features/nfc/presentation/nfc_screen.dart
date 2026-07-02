import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/nfc_read_result.dart';
import 'nfc_controller.dart';

/// "Etiketi okutun" ekrani. Durum gosterimi + okunan UID/tag tipi + hata
/// mesaji + tekrar oku butonu.
class NfcScreen extends ConsumerWidget {
  const NfcScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nfcControllerProvider);
    final controller = ref.read(nfcControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('NFC etiket okuma')),
      body: Center(
        child: Padding(
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
              if (state.status == NfcStatus.success && state.result != null)
                _ResultCard(result: state.result!),
              if (state.status == NfcStatus.error)
                _ErrorBox(message: state.errorMessage ?? 'Hata'),
              const SizedBox(height: 32),
              _ActionButton(state: state, controller: controller),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(NfcStatus status) {
    return switch (status) {
      NfcStatus.ready => 'Okumaya hazir. Baslat\'a dokunun.',
      NfcStatus.reading => 'Etiketi telefonun arkasina yaklastirin...',
      NfcStatus.success => 'Etiket okundu.',
      NfcStatus.error => 'Etiket okunamadi.',
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
            _row('UID', result.uid ?? '-'),
            const SizedBox(height: 8),
            _row('Tip', result.tagType.name),
            if (sdm != null) ...[
              const Divider(height: 24),
              const Text(
                'SDM (ham, dogrulanmamis)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _row('PICCData', sdm.piccData ?? '-'),
              _row('CMAC', sdm.cmac ?? '-'),
              _row('URL', sdm.rawUrl),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
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
  const _ActionButton({required this.state, required this.controller});

  final NfcState state;
  final NfcController controller;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case NfcStatus.reading:
        return OutlinedButton.icon(
          onPressed: controller.cancel,
          icon: const Icon(Icons.close),
          label: const Text('Vazgec'),
        );
      case NfcStatus.ready:
        return FilledButton.icon(
          onPressed: controller.startReading,
          icon: const Icon(Icons.nfc),
          label: const Text('Okumayi baslat'),
        );
      case NfcStatus.success:
      case NfcStatus.error:
        return FilledButton.icon(
          onPressed: controller.startReading,
          icon: const Icon(Icons.refresh),
          label: const Text('Tekrar oku'),
        );
    }
  }
}
