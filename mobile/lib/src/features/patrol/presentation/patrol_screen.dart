import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../scan/data/scan_outbox.dart';
import '../domain/patrol_models.dart';
import 'patrol_controller.dart';
import 'patrol_history_controller.dart';

/// "Turlarim" — guvenlik elemaninin asil calisma ekrani.
///
///   * Aktif sekme: aktif pencere karti (plan adi, saat araligi, canli kalan
///     sure, ilerleme) + nokta listesi (okutuldu ✓ / gonderiliyor / bekliyor)
///     + NFC okutmaya gecis. Nokta durumlari sunucu plan verisi + BU CIHAZIN
///     yerel okutma kaydinin birlesimidir (offline'da bile ilerleme gorunur).
///   * Gecmis sekme: son pencereler (tamamlandi/kacirildi/bekliyor + sayilar).
class PatrolScreen extends ConsumerWidget {
  const PatrolScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount =
        ref.watch(scanOutboxProvider.select((s) => s.pendingCount));
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Turlarim'),
          actions: [
            IconButton(
              tooltip: pendingCount > 0
                  ? '$pendingCount okutma gonderim bekliyor'
                  : 'Gonderim kuyrugu',
              onPressed: () => context.push(AppRoutes.outbox),
              icon: Badge(
                isLabelVisible: pendingCount > 0,
                label: Text('$pendingCount'),
                child: const Icon(Icons.outbox_outlined),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Aktif'),
              Tab(text: 'Gecmis'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ActiveTourTab(),
            _HistoryTab(),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// AKTIF SEKME
// --------------------------------------------------------------------------

class _ActiveTourTab extends ConsumerWidget {
  const _ActiveTourTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(patrolTourControllerProvider);
    final controller = ref.read(patrolTourControllerProvider.notifier);

    if (state.loading && state.active == null && state.errorMessage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (state.errorMessage != null)
            _ErrorBanner(
              message: state.forbidden
                  ? 'Bu ekrandaki veriler icin yetkiniz yok. '
                      'Tur takibi guvenlik (ve yonetici) rolune aciktir.'
                  : state.errorMessage!,
              onRetry: state.forbidden ? null : controller.refresh,
            ),
          if (state.active != null) ...[
            _ActiveWindowCard(state: state),
            const SizedBox(height: 16),
            _CheckpointList(state: state),
          ] else if (!state.forbidden) ...[
            _NoActiveWindowCard(next: state.next),
          ],
          if (state.refreshedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Son guncelleme: ${_fmtClock(state.refreshedAt!.toLocal())} '
                '(otomatik yenileme: 60 sn)',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// Aktif pencere karti: plan adi, saat araligi, canli kalan sure, ilerleme.
class _ActiveWindowCard extends ConsumerWidget {
  const _ActiveWindowCard({required this.state});

  final PatrolTourState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = state.active!;
    final beklenen = state.beklenen;
    final okutulan = state.okutulanBirlesik;
    final progress = beklenen > 0 ? (okutulan / beklenen).clamp(0.0, 1.0) : 0.0;
    final tamamlandi = beklenen > 0 && okutulan >= beklenen;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  tamamlandi ? Icons.verified : Icons.directions_walk,
                  color: tamamlandi ? Colors.green : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    active.patrolPlanAd ?? 'Devriye turu',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Pencere: ${_fmtClock(active.pencereBaslangic.toLocal())}'
              ' – ${_fmtClock(active.pencereBitis.toLocal())}',
            ),
            const SizedBox(height: 4),
            _CountdownText(until: active.pencereBitis),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      color: tamamlandi ? Colors.green : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$okutulan/$beklenen nokta',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (tamamlandi) ...[
              const SizedBox(height: 8),
              const Text(
                'Tum noktalar okutuldu — tur tamamlaniyor. ✓',
                style: TextStyle(color: Colors.green),
              ),
            ],
            // Sunucu bu cihazin bilmedigi okutmalar da sayabilir (baska
            // gorevli/cihaz). Kullanici saskinligini onlemek icin belirtilir.
            if (active.okutulanCheckpointSayisi > state.localOkutulan) ...[
              const SizedBox(height: 8),
              Text(
                'Sunucuda ${active.okutulanCheckpointSayisi} okutma kayitli '
                '(diger cihazlarin okutmalari dahil olabilir).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _goScan(context, ref),
                icon: const Icon(Icons.nfc),
                label: const Text('Nokta okut (NFC)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// NFC okutma ekranina gider; donuste sunucu verisini sessizce tazeler.
/// (Yerel ✓ zaten outbox dinleyicisiyle ANINDA islenir — bu cagri yalnizca
/// sunucu sayilarini yetistirmek icindir.)
Future<void> _goScan(BuildContext context, WidgetRef ref) async {
  await context.push(AppRoutes.nfc);
  unawaited(
    ref.read(patrolTourControllerProvider.notifier).refresh(silent: true),
  );
}

/// Aktif pencere yokken gosterilen kart (+ varsa siradaki pencere bilgisi).
class _NoActiveWindowCard extends StatelessWidget {
  const _NoActiveWindowCard({required this.next});

  final ActivePatrolWindow? next;

  @override
  Widget build(BuildContext context) {
    final n = next;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.nightlight_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Su an aktif devriye penceresi yok.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (n != null)
              Text(
                'Siradaki: ${n.patrolPlanAd ?? 'Devriye turu'} · '
                '${_fmtClock(n.pencereBaslangic.toLocal())}'
                ' – ${_fmtClock(n.pencereBitis.toLocal())}',
                textAlign: TextAlign.center,
              )
            else
              const Text(
                'Bugun icin planlanmis baska pencere gorunmuyor.',
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

/// Nokta listesi: her satirda ad + duruma gore ikon/aciklama.
class _CheckpointList extends StatelessWidget {
  const _CheckpointList({required this.state});

  final PatrolTourState state;

  @override
  Widget build(BuildContext context) {
    final checkpoints = state.checkpoints;
    if (checkpoints.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Bu planin nokta listesi alinamadi veya plana nokta atanmamis.',
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Kontrol noktalari',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < checkpoints.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _CheckpointTile(status: checkpoints[i]),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
          child: Text(
            'Nokta durumlari bu cihazin okutmalarina goredir; baska cihazin '
            'okutmalari yalnizca yukaridaki sunucu sayisina yansir.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _CheckpointTile extends StatelessWidget {
  const _CheckpointTile({required this.status});

  final CheckpointStatus status;

  @override
  Widget build(BuildContext context) {
    final cp = status.checkpoint;
    final ad = cp.ad ??
        'Nokta ${cp.checkpointId.length > 8 ? cp.checkpointId.substring(0, 8) : cp.checkpointId}';
    final (icon, color, sub) = switch (status.durum) {
      CheckpointScanDurum.okutuldu => (
          Icons.check_circle,
          Colors.green,
          'Okutuldu ✓'
              '${status.okutmaZamani != null ? ' · ${_fmtClock(status.okutmaZamani!.toLocal())}' : ''}',
        ),
      CheckpointScanDurum.gonderiliyor => (
          Icons.cloud_upload_outlined,
          Colors.teal,
          'Okutuldu ✓ — gonderiliyor (kuyrukta)',
        ),
      CheckpointScanDurum.bekliyor => (
          Icons.radio_button_unchecked,
          Colors.grey,
          'Bekliyor',
        ),
    };
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(ad),
      subtitle: Text(sub, style: TextStyle(color: color)),
      trailing: Text(
        '${cp.sira + 1}',
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

/// Kalan sureyi saniyede bir tazeleyen canli sayac.
class _CountdownText extends StatefulWidget {
  const _CountdownText({required this.until});

  /// Pencere bitisi (UTC).
  final DateTime until;

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.until.difference(DateTime.now().toUtc());
    if (remaining.isNegative) {
      return const Text(
        'Pencere suresi doldu.',
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
      );
    }
    final urgent = remaining < const Duration(minutes: 10);
    return Row(
      children: [
        Icon(
          Icons.timer_outlined,
          size: 18,
          color: urgent ? Colors.red : Colors.blueGrey,
        ),
        const SizedBox(width: 6),
        Text(
          'Kalan sure: ${_fmtDuration(remaining)}',
          style: TextStyle(
            color: urgent ? Colors.red : null,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// GECMIS SEKME
// --------------------------------------------------------------------------

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

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
            _ErrorBanner(
              message: state.forbidden
                  ? 'Tur gecmisi icin yetkiniz yok. Bu liste guvenlik '
                      '(ve yonetici) rolune aciktir.'
                  : state.errorMessage!,
              onRetry: state.forbidden ? null : controller.refresh,
            ),
          if (state.items.isNotEmpty) ...[
            _HistorySummary(ozet: state.ozet),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < state.items.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _HistoryTile(item: state.items[i]),
                  ],
                ],
              ),
            ),
          ] else if (state.errorMessage == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Henuz tur penceresi kaydi yok.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistorySummary extends StatelessWidget {
  const _HistorySummary({required this.ozet});

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
        chip('Tamamlandi', ozet.tamamlandi, Colors.green),
        chip('Kacirildi', ozet.kacirildi, Colors.red),
        chip('Bekliyor', ozet.bekliyor, Colors.orange),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final PatrolWindowHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (item.durum) {
      PatrolWindowDurum.tamamlandi => (
          Icons.check_circle,
          Colors.green,
          'Tamamlandi',
        ),
      PatrolWindowDurum.kacirildi => (Icons.cancel, Colors.red, 'Kacirildi'),
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
        '${_fmtDate(start)} · ${_fmtClock(start)} – ${_fmtClock(end)}',
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

// --------------------------------------------------------------------------
// ORTAK PARCALAR
// --------------------------------------------------------------------------

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, this.onRetry});

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

String _fmtClock(DateTime local) => '${_two(local.hour)}:${_two(local.minute)}';

String _fmtDate(DateTime local) =>
    '${_two(local.day)}.${_two(local.month)}.${local.year}';

String _fmtDuration(Duration d) {
  if (d.inHours >= 1) {
    return '${d.inHours} sa ${_two(d.inMinutes % 60)} dk';
  }
  if (d.inMinutes >= 1) {
    return '${d.inMinutes} dk ${_two(d.inSeconds % 60)} sn';
  }
  return '${d.inSeconds} sn';
}
