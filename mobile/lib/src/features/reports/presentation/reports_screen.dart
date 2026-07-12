import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../patrol/presentation/patrol_history_view.dart'
    show PatrolErrorBanner, fmtClock, fmtDate;
import '../../tasks/domain/task_models.dart' show taskTipFromJson;
import '../../tasks/presentation/task_tip_style.dart';
import '../domain/report_models.dart';
import 'reports_controller.dart';

/// "Aylik raporlar" — yonetici icin ay bazli ozet: devriye, gorev
/// tamamlama, aidat tahsilati. Salt okuma; kaynak uclar auth.md §4'te
/// yonetici'ye acik olanlardir.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportsControllerProvider);
    final controller = ref.read(reportsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Aylık raporlar')),
      body: Column(
        children: [
          _MonthBar(state: state, controller: controller),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: _Body(state: state, controller: controller),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.state, required this.controller});

  final ReportsState state;
  final ReportsController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Önceki ay',
            icon: const Icon(Icons.chevron_left),
            onPressed: state.loading ? null : controller.prevMonth,
          ),
          Expanded(
            child: Text(
              ayBaslik(state.yil, state.ay),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'Sonraki ay',
            icon: const Icon(Icons.chevron_right),
            onPressed:
                state.loading || !controller.canGoNext ? null : controller.nextMonth,
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.controller});

  final ReportsState state;
  final ReportsController controller;

  @override
  Widget build(BuildContext context) {
    if (state.loading && state.rapor == null && state.errorMessage == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final rapor = state.rapor;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (state.errorMessage != null)
          PatrolErrorBanner(
            message: state.forbidden
                ? 'Aylık raporlar için yetkiniz yok. Bu ekran yönetici '
                    'rolüne açıktır.'
                : state.errorMessage!,
            onRetry: state.forbidden ? null : controller.refresh,
          ),
        if (rapor != null) ...[
          _SectionTitle(icon: Icons.route_outlined, title: 'Devriye'),
          _DevriyeCard(rapor: rapor),
          const SizedBox(height: 16),
          _SectionTitle(icon: Icons.task_alt, title: 'Görev tamamlama'),
          _GorevCard(rapor: rapor),
          const SizedBox(height: 16),
          _SectionTitle(icon: Icons.payments_outlined, title: 'Aidat'),
          _AidatCard(ozet: rapor.aidat),
          if (rapor.sonTamamlamalar.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle(
              icon: Icons.history,
              title: 'Son tamamlamalar (ilk 10)',
            ),
            _SonTamamlamalarCard(items: rapor.sonTamamlamalar),
          ],
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Etiket + buyuk deger satiri (rapor kartlarinin ortak dokusu).
class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600, color: valueColor),
          ),
        ],
      ),
    );
  }
}

class _DevriyeCard extends StatelessWidget {
  const _DevriyeCard({required this.rapor});

  final AylikRapor rapor;

  @override
  Widget build(BuildContext context) {
    final yuzde = rapor.devriyeYuzde;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StatRow(label: 'Planlanan pencere', value: '${rapor.devriyeToplam}'),
            _StatRow(
              label: 'Tamamlandı',
              value: '${rapor.devriyeTamamlandi}',
              valueColor: Colors.green,
            ),
            _StatRow(
              label: 'Kaçırıldı',
              value: '${rapor.devriyeKacirildi}',
              valueColor: rapor.devriyeKacirildi > 0 ? Colors.red : null,
            ),
            if (yuzde != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: yuzde / 100,
                  minHeight: 6,
                  color: yuzde >= 80 ? Colors.green : Colors.orange,
                  backgroundColor: Colors.blueGrey.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Tamamlanma %$yuzde',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Bu ay planlanmış devriye penceresi yok.'),
              ),
          ],
        ),
      ),
    );
  }
}

class _GorevCard extends StatelessWidget {
  const _GorevCard({required this.rapor});

  final AylikRapor rapor;

  @override
  Widget build(BuildContext context) {
    final g = rapor.gorev;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: g.toplam == 0
            ? const Text('Bu ay görev tamamlaması yok.')
            : Column(
                children: [
                  _StatRow(label: 'Toplam tamamlama', value: '${g.toplam}'),
                  if (g.temizlik > 0)
                    _StatRow(label: 'Temizlik', value: '${g.temizlik}'),
                  if (g.kontrol > 0)
                    _StatRow(label: 'Kontrol', value: '${g.kontrol}'),
                  if (g.ilaclama > 0)
                    _StatRow(label: 'İlaçlama', value: '${g.ilaclama}'),
                  if (g.peyzaj > 0)
                    _StatRow(label: 'Peyzaj', value: '${g.peyzaj}'),
                  if (g.diger > 0)
                    _StatRow(label: 'Bakım/diğer', value: '${g.diger}'),
                ],
              ),
      ),
    );
  }
}

class _AidatCard extends StatelessWidget {
  const _AidatCard({required this.ozet});

  final AidatOzet ozet;

  @override
  Widget build(BuildContext context) {
    final yuzde = ozet.tahsilatYuzde;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ozet.tahakkukAdet == 0 && ozet.tahsilatAdet == 0
            ? const Text('Bu dönem için tahakkuk/ödeme kaydı yok.')
            : Column(
                children: [
                  _StatRow(
                    label: 'Tahakkuk (${ozet.tahakkukAdet} daire)',
                    value: kurusToTl(ozet.tahakkukKurus),
                  ),
                  _StatRow(
                    label: 'Tahsilat (${ozet.tahsilatAdet} ödeme)',
                    value: kurusToTl(ozet.tahsilatKurus),
                    valueColor: Colors.green,
                  ),
                  _StatRow(
                    label: 'Kalan bakiye',
                    value: kurusToTl(ozet.bakiyeKurus),
                    valueColor: ozet.bakiyeKurus > 0 ? Colors.red : Colors.green,
                  ),
                  if (yuzde != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: yuzde / 100,
                        minHeight: 6,
                        color: yuzde >= 80 ? Colors.green : Colors.orange,
                        backgroundColor:
                            Colors.blueGrey.withValues(alpha: 0.15),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Tahsilat %$yuzde',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _SonTamamlamalarCard extends StatelessWidget {
  const _SonTamamlamalarCard({required this.items});

  final List<SonTamamlama> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _SonTamamlamaTile(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _SonTamamlamaTile extends StatelessWidget {
  const _SonTamamlamaTile({required this.item});

  final SonTamamlama item;

  @override
  Widget build(BuildContext context) {
    final style = taskTipStyle(taskTipFromJson(item.tip));
    final local = item.tamamlanmaZamani.toLocal();
    return ListTile(
      dense: true,
      leading: Icon(style.icon, color: style.color),
      title: Text(item.taskAdi ?? style.label),
      subtitle: Text('${fmtDate(local)} · ${fmtClock(local)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.nfcDogrulandi)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.nfc, size: 16),
            ),
          if (item.fotoVar)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.photo_camera_outlined, size: 16),
            ),
        ],
      ),
    );
  }
}
