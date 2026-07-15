import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/text/tr_upper.dart';
import '../domain/emergency_models.dart';
import 'emergency_controller.dart';

/// ACIL DURUM (panik) ekrani — kucuk ve tek amacli:
///
///   1. Opsiyonel kisa not + buyuk kirmizi buton.
///   2. Basista Idempotency-Key sabitlenir, ONAY dialogu acilir (yanlis
///      basmaya karsi; uzun-bas yerine dialog tercih edildi — stres/eldiven
///      altinda uzun-bas guvenilmez ve kesfedilebilirligi dusuk).
///   3. Onayda GPS best-effort eklenip alarm gonderilir; sonucta yonetim
///      numarasi `tel:` ile aranabilir.
///   4. OFFLINE: durust hata — kuyruklama YOK, "tekrar dene" + numara yine
///      gorunur (arama sebekeden calisabilir).
class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _startPanic() async {
    final controller = ref.read(emergencyControllerProvider.notifier);
    // Basis ANI: taslak + Idempotency-Key burada sabitlenir.
    controller.arm(_noteController.text);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber, color: Colors.red, size: 40),
        title: const Text('Acil durum bildirilsin mi?'),
        content: const Text(
          'Yönetim paneline yüksek öncelikli alarm gönderilecek ve '
          'yöneticilere bildirim gidecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('BİLDİR'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.confirm();
    } else {
      controller.disarm();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(emergencyControllerProvider);
    final controller = ref.read(emergencyControllerProvider.notifier);
    final sending = state.phase == EmergencyPhase.sending;

    return Scaffold(
      appBar: AppBar(title: Text(trUpper('Acil durum'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.phase == EmergencyPhase.sent)
            _SentCard(state: state, onDone: controller.reset)
          else if (state.phase == EmergencyPhase.failed)
            _FailedCard(state: state, onRetry: controller.retry)
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Alarm, yönetim panelinde ANINDA görünür ve '
                            'yöneticilere bildirim gider. Konumunuz '
                            'alınabiliyorsa eklenir (alınamazsa alarm '
                            'beklemez).',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteController,
                      enabled: !sending,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Kısa not (isteğe bağlı)',
                        hintText: 'Örn. B blok otopark girişi',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 72,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: sending ? null : _startPanic,
                icon: sending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sos, size: 32),
                label: Text(
                  sending ? 'ALARM GÖNDERİLİYOR...' : 'ACİL DURUM BİLDİR',
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (state.phone != null) _CallTile(phone: state.phone!),
        ],
      ),
    );
  }
}

/// "Yonetimi ara" — `tel:` URI cihazin arama ekranini acar (arama karari ve
/// tusu kullanicida kalir; uygulama kendisi aramaz).
class _CallTile extends StatelessWidget {
  const _CallTile({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    final uri = telUri(phone);
    if (uri == null) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.call, color: Colors.green),
        title: const Text('Yönetimi ara'),
        subtitle: Text(phone),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => launchUrl(uri),
      ),
    );
  }
}

class _SentCard extends StatelessWidget {
  const _SentCard({required this.state, required this.onDone});

  final EmergencyState state;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final result = state.result!;
    return Card(
      color: Colors.green.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 56),
            const SizedBox(height: 8),
            Text(
              result.wasDuplicate
                  ? 'Alarm ZATEN iletilmişti ✓ (tekrar gönderim — çift '
                      'alarm oluşmadı)'
                  : 'Alarm iletildi ✓',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Yönetim paneli bilgilendirildi'
              '${result.alert.gpsLat != null ? ' · konum eklendi' : ''}.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onDone, child: const Text('Tamam')),
          ],
        ),
      ),
    );
  }
}

class _FailedCard extends StatelessWidget {
  const _FailedCard({required this.state, required this.onRetry});

  final EmergencyState state;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 56),
            const SizedBox(height: 8),
            Text(
              state.errorMessage ?? 'Alarm iletilemedi.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}
