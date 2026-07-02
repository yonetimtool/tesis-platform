import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../scan/domain/scan.dart';
import '../../scan/presentation/scan_controller.dart';
import '../domain/nfc_read_result.dart';
import 'nfc_controller.dart';

/// "Etiketi okutun" ekrani. Etiketi okur (UID/tag tipi), ardindan okutmayi
/// `POST /scans` ile backend'e gonderir (Idempotency-Key ile).
class NfcScreen extends ConsumerWidget {
  const NfcScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nfcControllerProvider);
    final nfc = ref.read(nfcControllerProvider.notifier);
    final scanState = ref.watch(scanControllerProvider);
    final scan = ref.read(scanControllerProvider.notifier);

    // Yeni okumaya gecerken onceki gonderim sonucunu temizle.
    Future<void> startNewRead() async {
      scan.reset();
      await nfc.startReading();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('NFC etiket okuma')),
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
                _ScanSection(
                  result: state.result!,
                  scanState: scanState,
                  onSubmit: () => scan.submit(
                    ScanDraft(
                      nfcTagUid: state.result!.uid!,
                      okutmaZamani:
                          state.result!.readAt ?? DateTime.now().toUtc(),
                    ),
                  ),
                ),
              ],
              if (state.status == NfcStatus.error)
                _ErrorBox(message: state.errorMessage ?? 'Hata'),
              const SizedBox(height: 32),
              _ActionButton(
                status: state.status,
                onRead: startNewRead,
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
            _KvRow(label: 'UID', value: result.uid ?? '-'),
            const SizedBox(height: 8),
            _KvRow(label: 'Tip', value: result.tagType.name),
            if (sdm != null) ...[
              const Divider(height: 24),
              const Text(
                'SDM (ham, dogrulanmamis)',
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

/// Okuma sonrasi gonderim bolumu: "Gonder" butonu, spinner ve sonuc kutusu.
class _ScanSection extends StatelessWidget {
  const _ScanSection({
    required this.result,
    required this.scanState,
    required this.onSubmit,
  });

  final NfcReadResult result;
  final ScanSubmitState scanState;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    switch (scanState.status) {
      case ScanSubmitStatus.submitting:
        return const Padding(
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
              Text('Gonderiliyor...'),
            ],
          ),
        );
      case ScanSubmitStatus.created:
        return _ScanOutcome(
          icon: Icons.check_circle,
          color: Colors.green,
          text: 'Okutma kaydedildi.',
        );
      case ScanSubmitStatus.duplicate:
        return _ScanOutcome(
          icon: Icons.info_outline,
          color: Colors.blueGrey,
          text: 'Bu okutma zaten kayitliydi.',
        );
      case ScanSubmitStatus.notMatched:
        return _ScanOutcome(
          icon: Icons.link_off,
          color: Colors.orange,
          text: scanState.message ?? 'Eslesme bulunamadi.',
        );
      case ScanSubmitStatus.error:
        return Column(
          children: [
            _ScanOutcome(
              icon: Icons.error_outline,
              color: Colors.red,
              text: scanState.message ?? 'Gonderilemedi.',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar gonder'),
            ),
          ],
        );
      case ScanSubmitStatus.idle:
        return FilledButton.icon(
          onPressed: onSubmit,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('Okutmayi gonder'),
        );
    }
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
          label: const Text('Vazgec'),
        );
      case NfcStatus.ready:
        return FilledButton.icon(
          onPressed: onRead,
          icon: const Icon(Icons.nfc),
          label: const Text('Okumayi baslat'),
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
