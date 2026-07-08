import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../patrol/presentation/patrol_history_view.dart'
    show PatrolErrorBanner, fmtClock, fmtDate;
import '../../reports/domain/report_models.dart' show kurusToTl;
import '../domain/dues_models.dart';
import 'my_dues_controller.dart';

/// "Aidatim" — sakinin KENDI dairelerinin borc durumu (salt okuma).
/// Odeme bu ekrandan YAPILAMAZ: odeme durumu yalnizca odeme saglayicisi
/// webhook'uyla degisir (auth.md §4) — ekran yonetime odenen tutarlari ve
/// tahakkuklari seffaf gosterir.
class MyDuesScreen extends ConsumerWidget {
  const MyDuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myDuesControllerProvider);
    final controller = ref.read(myDuesControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aidatim'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: state.loading ? null : controller.refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: _Body(state: state, controller: controller),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.controller});

  final MyDuesState state;
  final MyDuesController controller;

  @override
  Widget build(BuildContext context) {
    if (state.loading && state.units.isEmpty && state.errorMessage == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (state.errorMessage != null)
          PatrolErrorBanner(
            message: state.forbidden
                ? 'Aidat bilgisi yalnizca site sakini hesabina aciktir.'
                : state.errorMessage!,
            onRetry: state.forbidden ? null : controller.refresh,
          ),
        if (state.units.isEmpty && state.errorMessage == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Uzerinize kayitli daire bulunamadi. Yonetiminizle '
                'iletisime gecin.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (state.units.length > 1) ...[
          _ToplamBakiyeCard(bakiyeKurus: state.toplamBakiyeKurus),
          const SizedBox(height: 12),
        ],
        for (final unit in state.units) _UnitCard(unit: unit),
      ],
    );
  }
}

class _ToplamBakiyeCard extends StatelessWidget {
  const _ToplamBakiyeCard({required this.bakiyeKurus});

  final int bakiyeKurus;

  @override
  Widget build(BuildContext context) {
    final borc = bakiyeKurus > 0;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          borc ? Icons.account_balance_wallet_outlined : Icons.check_circle,
          color: borc ? Colors.red : Colors.green,
        ),
        title: const Text('Toplam bakiye (tum daireler)'),
        trailing: Text(
          kurusToTl(bakiyeKurus),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: borc ? Colors.red : Colors.green,
          ),
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({required this.unit});

  final MyDuesUnit unit;

  @override
  Widget build(BuildContext context) {
    final borc = unit.borcVar;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.home_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Daire ${unit.no}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Chip(
                  label: Text(borc ? 'Borc var' : 'Borc yok'),
                  labelStyle:
                      TextStyle(color: borc ? Colors.red : Colors.green),
                  backgroundColor: (borc ? Colors.red : Colors.green)
                      .withValues(alpha: 0.12),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _row('Toplam tahakkuk', kurusToTl(unit.tahakkukKurus)),
            _row('Toplam odenen', kurusToTl(unit.odenenKurus),
                valueColor: Colors.green),
            _row('Bakiye', kurusToTl(unit.bakiyeKurus),
                valueColor: borc ? Colors.red : Colors.green, bold: true),
            if (unit.assessments.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Tahakkuklar (${unit.assessments.length})',
                  style: const TextStyle(fontSize: 14),
                ),
                children: [
                  for (final a in unit.assessments)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text('${a.donem}'
                          '${a.aciklama == null ? '' : ' — ${a.aciklama}'}'),
                      subtitle: a.sonOdemeTarihi == null
                          ? null
                          : Text(
                              'Son odeme: ${fmtDate(a.sonOdemeTarihi!)}',
                            ),
                      trailing: Text(
                        kurusToTl(a.tutarKurus),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ],
            if (unit.payments.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Odemeler (${unit.payments.length})',
                  style: const TextStyle(fontSize: 14),
                ),
                children: [
                  for (final p in unit.payments) _PaymentTile(payment: p),
                ],
              ),
            const SizedBox(height: 4),
            Text(
              'Odeme durumu yalnizca odeme saglayicisindan gelen onayla '
              'guncellenir; sorulariniz icin yonetiminize basvurun.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value,
      {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});

  final DuesPayment payment;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final (color, icon) = switch (p.durum) {
      'basarili' => (Colors.green, Icons.check_circle_outline),
      'bekliyor' => (Colors.orange, Icons.hourglass_top),
      'iptal' => (Colors.red, Icons.cancel_outlined),
      _ => (Colors.grey, Icons.help_outline),
    };
    final local = p.odemeZamani.toLocal();
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        '${fmtDate(local)} ${fmtClock(local)} · ${yontemLabel(p.yontem)}'
        '${p.donem == null ? '' : ' · ${p.donem}'}',
      ),
      subtitle: p.makbuzNo == null ? null : Text('Makbuz: ${p.makbuzNo}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            kurusToTl(p.tutarKurus),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(durumLabel(p.durum),
              style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
