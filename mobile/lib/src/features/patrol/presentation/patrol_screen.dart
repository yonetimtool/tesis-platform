import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../scan/data/scan_outbox.dart';
import '../domain/patrol_models.dart';
import 'patrol_controller.dart';
import 'patrol_history_view.dart';

/// "Turlarim" — guvenlik elemaninin asil calisma ekrani.
///
///   * Aktif sekme: aktif pencere karti (plan adi, saat araligi, canli kalan
///     sure, ilerleme) + nokta listesi (okutuldu ✓ / gonderiliyor / bekliyor)
///     + NFC okutmaya gecis. Nokta durumlari SUNUCUDAN gelir
///     (GET /me/patrol-window, pencere-geneli — baska elemanin okutmasi da ✓
///     gorunur); bu cihazin outbox'ta bekleyen okutmalari "gonderiliyor"
///     olarak uzerine bindirilir (offline'da bile ilerleme gorunur).
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
            PatrolHistoryView(),
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
            PatrolErrorBanner(
              message: state.forbidden
                  ? 'Bu ekrandaki veriler icin yetkiniz yok. '
                      'Tur takibi guvenlik (ve yonetici) rolune aciktir.'
                  : state.errorMessage!,
              onRetry: state.forbidden ? null : controller.refresh,
            ),
          if (state.active != null) ...[
            if (state.windows.length > 1) ...[
              _WindowSelector(state: state),
              const SizedBox(height: 12),
            ],
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
                'Son guncelleme: ${fmtClock(state.refreshedAt!.toLocal())} '
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

/// Birden cok plan ayni anda aktifken pencere secici (`/me/patrol-window` →
/// `windows[]`). Varsayilan secim sunucunun en acil (bitisi en yakin)
/// penceresidir; kullanici digerine gecebilir.
class _WindowSelector extends ConsumerWidget {
  const _WindowSelector({required this.state});

  final PatrolTourState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final w in state.windows)
          ChoiceChip(
            label: Text(
              '${w.patrolPlanAd ?? 'Devriye turu'} · '
              'bitis ${fmtClock(w.pencereBitis.toLocal())}',
            ),
            selected: w.patrolWindowId == state.selectedWindowId,
            onSelected: (_) => ref
                .read(patrolTourControllerProvider.notifier)
                .selectWindow(w.patrolWindowId),
          ),
      ],
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
              'Pencere: ${fmtClock(active.pencereBaslangic.toLocal())}'
              ' – ${fmtClock(active.pencereBitis.toLocal())}',
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
                '${fmtClock(n.pencereBaslangic.toLocal())}'
                ' – ${fmtClock(n.pencereBitis.toLocal())}',
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
            'Nokta durumlari sunucudandir; tum gorevlilerin okutmalari ✓ '
            'gorunur. "Gonderiliyor" satirlar bu cihazin henuz gonderilmemis '
            'okutmalaridir.',
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
              '${status.okutmaZamani != null ? ' · ${fmtClock(status.okutmaZamani!.toLocal())}' : ''}',
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
          'Kalan sure: ${fmtDuration(remaining)}',
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
// ORTAK PARCALAR
// --------------------------------------------------------------------------
