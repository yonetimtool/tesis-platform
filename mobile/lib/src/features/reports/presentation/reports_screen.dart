import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/i18n/l10n.dart';
import '../../patrol/presentation/patrol_history_view.dart'
    show PatrolErrorBanner;
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
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.raporBaslik, context.dilKodu)),
      ),
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
    final l10n = context.l10n;
    final dil = context.dilKodu;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.raporOncekiAy,
            icon: const Icon(Icons.chevron_left),
            onPressed: state.loading ? null : controller.prevMonth,
          ),
          Expanded(
            child: Text(
              l10n.raporAyBaslik(ayAdi(state.ay, dil), '${state.yil}'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: l10n.raporSonrakiAy,
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
    final l10n = context.l10n;
    final hata = akisHatasiCoz(l10n, state.hataKimligi, state.errorMessage);
    if (state.loading && state.rapor == null && hata == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final rapor = state.rapor;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (hata != null)
          PatrolErrorBanner(
            message: state.forbidden ? l10n.raporYetkiYok : hata,
            onRetry: state.forbidden ? null : controller.refresh,
          ),
        if (rapor != null) ...[
          _SectionTitle(
              icon: Icons.route_outlined, title: l10n.etiketDevriye),
          _DevriyeCard(rapor: rapor),
          const SizedBox(height: 16),
          _SectionTitle(
              icon: Icons.task_alt, title: l10n.raporGorevTamamlama),
          _GorevCard(rapor: rapor),
          const SizedBox(height: 16),
          _SectionTitle(icon: Icons.payments_outlined, title: l10n.raporAidat),
          _AidatCard(ozet: rapor.aidat),
          if (rapor.sonTamamlamalar.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle(
              icon: Icons.history,
              title: l10n.raporSonTamamlamalar,
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
          // Uzun ceviriler ("Achèvement des tâches") satiri tasiriyordu.
          Expanded(
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
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
          // Etiket kucultulebilir (uzun ceviriler + ICU cogul sayaclari);
          // DEGER kirpilmaz, gerekirse kuculur (tur 6/9 emsali).
          Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                value,
                style: TextStyle(fontWeight: FontWeight.w600, color: valueColor),
              ),
            ),
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
    final l10n = context.l10n;
    final yuzde = rapor.devriyeYuzde;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StatRow(
                label: l10n.raporPlanlananPencere,
                value: '${rapor.devriyeToplam}'),
            _StatRow(
              label: l10n.devriyeDurumTamamlandi,
              value: '${rapor.devriyeTamamlandi}',
              valueColor: Colors.green,
            ),
            _StatRow(
              label: l10n.devriyeDurumKacirildi,
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
                // YON-DUYARLI: Arapca'da sola hizalanir.
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  l10n.raporTamamlanmaYuzde('$yuzde'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.raporPencereYok),
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
    final l10n = context.l10n;
    final g = rapor.gorev;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: g.toplam == 0
            ? Text(l10n.raporGorevYok)
            : Column(
                children: [
                  _StatRow(
                      label: l10n.raporToplamTamamlama, value: '${g.toplam}'),
                  // Kategori bazli kirilim; null kategori cizimde cozulur.
                  for (final k in g.kalemler)
                    _StatRow(
                      label: k.kategoriAd ?? l10n.gorevKategoriDiger,
                      value: '${k.sayi}',
                    ),
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
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final yuzde = ozet.tahsilatYuzde;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ozet.tahakkukAdet == 0 && ozet.tahsilatAdet == 0
            ? Text(l10n.raporAidatKayitYok)
            : Column(
                children: [
                  _StatRow(
                    label: l10n.raporTahakkukDaire(ozet.tahakkukAdet),
                    value: tlSonEkli(ozet.tahakkukKurus, dil),
                  ),
                  _StatRow(
                    label: l10n.raporTahsilatOdeme(ozet.tahsilatAdet),
                    value: tlSonEkli(ozet.tahsilatKurus, dil),
                    valueColor: Colors.green,
                  ),
                  _StatRow(
                    label: l10n.raporKalanBakiye,
                    value: tlSonEkli(ozet.bakiyeKurus, dil),
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
                      // YON-DUYARLI: Arapca'da sola hizalanir.
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text(
                        l10n.butTahsilatYuzde(yuzde),
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
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final style = taskKategoriStyle(item.kategoriAd);
    return ListTile(
      dense: true,
      leading: Icon(style.icon, color: style.color),
      title: Text(item.taskAdi ?? style.ad ?? l10n.gorevKategoriDiger),
      subtitle: Text('${tarihBicimi(item.tamamlanmaZamani, dil)} · '
          '${saatBicimi(item.tamamlanmaZamani, dil)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.nfcDogrulandi)
            const Padding(
              padding: EdgeInsetsDirectional.only(start: 4),
              child: Icon(Icons.nfc, size: 16),
            ),
          if (item.fotoVar)
            const Padding(
              padding: EdgeInsetsDirectional.only(start: 4),
              child: Icon(Icons.photo_camera_outlined, size: 16),
            ),
        ],
      ),
    );
  }
}
