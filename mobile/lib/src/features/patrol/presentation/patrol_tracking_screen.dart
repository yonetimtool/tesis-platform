import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/text/tr_upper.dart';
import '../../checkpoints/presentation/checkpoints_screen.dart';
import '../data/scan_report_api.dart';
import '../domain/patrol_models.dart';
import '../domain/tracking_ozet.dart';
import 'patrol_history_view.dart';
import 'patrol_tracking_controller.dart';

/// "Devriye takibi" — yonetici (site yoneticisi) icin SALT IZLEME ekrani.
/// Saha ekrani (Turlarim) /me/patrol-window kullanir ve okutma yapar; burasi
/// panelin canli ozetinin mobil karsiligi:
///   * Bugun sekmesi : `GET /dashboard/live` — bugunun pencereleri, durum +
///                     okutulan/beklenen ilerleme.
///   * Gecmis sekmesi: `GET /patrol-windows` — ozet + son pencereler
///                     (Turlarim "Gecmis" ile AYNI paylasilan gorunum).
class PatrolTrackingScreen extends ConsumerWidget {
  const PatrolTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading =
        ref.watch(patrolTrackingControllerProvider.select((s) => s.loading));
    final controller = ref.read(patrolTrackingControllerProvider.notifier);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(trUpper('Devriye takibi')),
          actions: [
            IconButton(
              tooltip: 'Kontrol noktaları',
              icon: const Icon(Icons.add_location_alt_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CheckpointsScreen()),
              ),
            ),
            IconButton(
              tooltip: 'Yenile',
              icon: const Icon(Icons.refresh),
              onPressed: loading ? null : controller.refresh,
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Bugün'),
              Tab(text: 'Geçmiş'),
              Tab(text: 'Tarama günlüğü'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TodayTab(),
            PatrolHistoryView(),
            _ScanLogTab(),
          ],
        ),
      ),
    );
  }
}

class _TodayTab extends ConsumerWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(patrolTrackingControllerProvider);
    final controller = ref.read(patrolTrackingControllerProvider.notifier);

    if (state.loading && state.windows.isEmpty && state.errorMessage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now().toUtc();
    final ozet = trackingOzet(state.windows, now);

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (state.errorMessage != null)
            PatrolErrorBanner(
              message: state.forbidden
                  ? 'Devriye takibi için yetkiniz yok. Bu ekran yönetici '
                      've güvenlik rollerine açıktır.'
                  : state.errorMessage!,
              onRetry: state.forbidden ? null : controller.refresh,
            ),
          if (state.windows.isNotEmpty) ...[
            _TodaySummary(ozet: ozet),
            const SizedBox(height: 12),
            for (final w in state.windows) _WindowCard(window: w, now: now),
          ] else if (state.errorMessage == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Bugün için planlanmış devriye penceresi yok.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.ozet});

  final TrackingOzet ozet;

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
        chip('Şimdi aktif', ozet.aktif, Colors.blue),
        chip('Yaklaşan', ozet.yaklasan, Colors.blueGrey),
        chip('Tamamlandı', ozet.tamamlandi, Colors.green),
        chip('Kaçırıldı', ozet.kacirildi, Colors.red),
      ],
    );
  }
}

class _WindowCard extends StatelessWidget {
  const _WindowCard({required this.window, required this.now});

  final ActivePatrolWindow window;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final w = window;
    final (color, label) = switch (w.durum) {
      PatrolWindowDurum.tamamlandi => (Colors.green, 'Tamamlandı'),
      PatrolWindowDurum.kacirildi => (Colors.red, 'Kaçırıldı'),
      _ => w.isActiveAt(now)
          ? (Colors.blue, 'Şimdi aktif')
          : w.isUpcomingAt(now)
              ? (Colors.blueGrey, 'Yaklaşan')
              : (Colors.red, 'Süresi geçti'),
    };
    final start = w.pencereBaslangic.toLocal();
    final end = w.pencereBitis.toLocal();
    final beklenen = w.beklenenCheckpointSayisi;
    final okutulan = w.okutulanCheckpointSayisi;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    w.patrolPlanAd ?? 'Devriye turu',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Chip(
                  label: Text(label),
                  labelStyle: TextStyle(color: color),
                  backgroundColor: color.withValues(alpha: 0.12),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${fmtClock(start)} – ${fmtClock(end)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (beklenen > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (okutulan / beklenen).clamp(0.0, 1.0),
                  minHeight: 6,
                  color: okutulan >= beklenen ? Colors.green : Colors.blue,
                  backgroundColor: Colors.blueGrey.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$okutulan/$beklenen nokta okutuldu',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tarama gunlugu (Parca D) — yonetici gun secer; o gunun (tenant tz) TUM
/// taramalari: KIM (guardAd) · HANGI NOKTA (checkpointAd) · NE ZAMAN (saat).
class _ScanLogTab extends ConsumerStatefulWidget {
  const _ScanLogTab();

  @override
  ConsumerState<_ScanLogTab> createState() => _ScanLogTabState();
}

class _ScanLogTabState extends ConsumerState<_ScanLogTab> {
  late DateTime _day = _today();

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void _shift(int days) =>
      setState(() => _day = _day.add(Duration(days: days)));

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2024),
      lastDate: _today().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _day = DateTime(picked.year, picked.month, picked.day));
    }
  }

  String _fmtDay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  String _fmtTime(DateTime utc) {
    final l = utc.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(scanReportProvider(_day));
    return Column(
      children: [
        // Gun secici: onceki / gun / sonraki + takvim.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shift(-1),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_fmtDay(_day)),
                  onPressed: _pick,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                // Bugunden ileri gitme.
                onPressed: _day.isBefore(_today()) ? () => _shift(1) : null,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Message(
              e is ApiException ? e.message : 'Tarama günlüğü alınamadı.',
              onRetry: () => ref.invalidate(scanReportProvider(_day)),
            ),
            data: (items) => items.isEmpty
                ? const _Message('Bu gün için okutma yok.')
                : RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(scanReportProvider(_day)),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final it = items[i];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(_fmtTime(it.okutmaZamani),
                                  style: const TextStyle(fontSize: 12)),
                            ),
                            title: Text(it.checkpointAd),
                            subtitle: Text('${it.guardAd}'
                                '${it.imzaDogrulandi ? ' · imzalı ✓' : ''}'),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 48),
        Center(child: Text(text, textAlign: TextAlign.center)),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          Center(
            child: FilledButton.tonal(
                onPressed: onRetry, child: const Text('Tekrar dene')),
          ),
        ],
      ],
    );
  }
}
