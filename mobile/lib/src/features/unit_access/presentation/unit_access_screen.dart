import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/error/api_exception.dart';
import '../../../routing/app_router.dart';
import '../domain/unit_access_models.dart';
import 'unit_access_controller.dart';
import '../../../core/error/akis_hatasi.dart';

/// Tek-seferlik daire goruntuleme izni ekrani (rol-uyarlamali, KVKK):
///   * admin/yonetici: "Yeni istek" ile TEK daire; "Tüm daireler" ile TOPLU
///     izin ister; onaylanan taleplerde ziyaretci/kargo kayitlarini BiR KEZ
///     goruntuler. Toplu istek per-daire sakin RIZASINI baypas ETMEZ.
///   * resident: kendi dairesine gelen talepleri Onayla/Reddet eder.
class UnitAccessScreen extends ConsumerWidget {
  const UnitAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(unitAccessControllerProvider);
    final controller = ref.read(unitAccessControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(context.l10n.izinBaslik, context.dilKodu)),
        actions: [
          if (state.canRequest)
            IconButton(
              tooltip: context.l10n.izinTumDairelere,
              icon: Icon(Icons.apartment_outlined),
              onPressed: () => _bulkRequest(context, ref),
            ),
        ],
      ),
      floatingActionButton: state.canRequest
          ? FloatingActionButton.extended(
              icon: Icon(Icons.add),
              label: Text(context.l10n.izinYeniIstek),
              onPressed: () => _newRequest(context, ref),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: state.loading && state.items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (state.errorMessage != null)
                    Card(
                      color: Colors.red.withValues(alpha: 0.08),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          state.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  // Talep edenin SU AN goruntuleyebilecegi (onayli+kullanilmamis)
                  // daireler — bulk sonrasi "hangi daireler acildi" ozeti.
                  if (state.canRequest && state.grantedUnits.isNotEmpty)
                    _GrantedUnitsCard(units: state.grantedUnits),
                  if (state.items.isEmpty && state.errorMessage == null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          state.canRequest
                              ? context.l10n.izinIstekYokYonetim
                              : context.l10n.izinIstekYokSakin,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  for (final r in state.sirali)
                    _RequestCard(request: r, canDecide: state.canDecide),
                ],
              ),
      ),
    );
  }

  Future<void> _bulkRequest(BuildContext context, WidgetRef ref) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.izinTumDairelere),
        content: Text(context.l10n.izinTumDaireUyari),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.ortakVazgec),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.talepGonder),
          ),
        ],
      ),
    );
    if (onay != true) return;
    try {
      final res =
          await ref.read(unitAccessControllerProvider.notifier).createBulkRequest();
      if (context.mounted) {
        final atlandi = res.skipped > 0 ? context.l10n.izinAtlandiEki('${res.skipped}') : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.izinTopluGonderildi(
                '${res.created}', atlandi)),
          ),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n
              .izinGonderilemedi(apiHataMetni(context.l10n, e)))),
        );
      }
    }
  }

  Future<void> _newRequest(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final unitNo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.izinIsteBaslik),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.l10n.izinDaireNo,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.ortakVazgec),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(context.l10n.izinIstekGonder),
          ),
        ],
      ),
    );
    if (unitNo == null || unitNo.isEmpty) return;
    try {
      await ref.read(unitAccessControllerProvider.notifier).createRequest(unitNo);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.izinIstekGonderildi)),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n
              .izinGonderilemedi(apiHataMetni(context.l10n, e)))),
        );
      }
    }
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request, required this.canDecide});

  final UnitAccessRequest request;
  final bool canDecide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = request;
    final daire = r.unitNo == null ? '' : ' — ${r.unitNo}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.izinDaireIstegi(daire),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                _DurumBadge(durum: r.durum, used: r.used),
              ],
            ),
            if (r.yoneticiAd != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(context.l10n.izinIsteyen(r.yoneticiAd!)),
              ),
            // resident: bekleyen talebi onayla/reddet.
            if (canDecide && r.bekliyor)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _DecideButtons(id: r.id),
              ),
            // admin/yonetici: onaylanmis + kullanilmamis izinle bir kez goruntule.
            if (!canDecide && r.kullanilabilir)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: Icon(Icons.emoji_people_outlined, size: 18),
                      label: Text(context.l10n.modulZiyaretciler),
                      onPressed: () => _openRecords(context, r, 'visitor'),
                    ),
                    OutlinedButton.icon(
                      icon: Icon(Icons.local_shipping_outlined, size: 18),
                      label: Text(context.l10n.izinKargolar),
                      onPressed: () => _openRecords(context, r, 'kargo'),
                    ),
                  ],
                ),
              ),
            if (!canDecide &&
                r.durum == AccessRequestDurum.onaylandi &&
                r.used)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  context.l10n.izinKullanildiUyari,
                  style: const TextStyle(color: Colors.orange),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openRecords(BuildContext context, UnitAccessRequest r, String kind) {
    context.push(
      '${AppRoutes.unitAccessRecords}?unit_id=${r.unitId}'
      '&unit_no=${r.unitNo ?? ''}&kind=$kind',
    );
  }
}

/// Talep edenin SU AN goruntuleyebilecegi daireler (onayli + kullanilmamis).
/// Bulk sonrasi "hangi daireler acildi" gorunumu — bir daire okununca (izin
/// tuketilince) listeden duser.
class _GrantedUnitsCard extends StatelessWidget {
  const _GrantedUnitsCard({required this.units});

  final List<GrantedUnit> units;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.withValues(alpha: 0.08),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_open_outlined, size: 18, color: Colors.green),
                const SizedBox(width: 6),
                Text(
                  context.l10n.izinGoruntulenebilirDaireler('${units.length}'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final u in units)
                  Chip(
                    label: Text(u.unitNo ?? u.unitId.substring(0, 6)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DurumBadge extends StatelessWidget {
  const _DurumBadge({required this.durum, required this.used});

  final AccessRequestDurum durum;
  final bool used;

  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (durum) {
      AccessRequestDurum.bekliyor =>
        (Colors.orange, context.l10n.devriyeDurumBekliyor),
      AccessRequestDurum.onaylandi => used
          ? (Colors.grey, context.l10n.izinKullanildi)
          : (Colors.green, context.l10n.izinOnayli),
      AccessRequestDurum.reddedildi => (Colors.red, context.l10n.talepDurumReddedildi),
      AccessRequestDurum.unknown =>
        (Colors.grey, context.l10n.devriyeDurumBilinmiyor),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

class _DecideButtons extends ConsumerStatefulWidget {
  const _DecideButtons({required this.id});

  final String id;

  @override
  ConsumerState<_DecideButtons> createState() => _DecideButtonsState();
}

class _DecideButtonsState extends ConsumerState<_DecideButtons> {
  bool _busy = false;

  Future<void> _decide(bool onayla) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(unitAccessControllerProvider.notifier)
          .decide(widget.id, onayla: onayla);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(onayla ? context.l10n.izinVerildi : context.l10n.talepDurumReddedildi)),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiHataMetni(context.l10n, e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Row(
      children: [
        FilledButton(
          onPressed: () => _decide(true),
          child: Text(context.l10n.izinOnayla),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => _decide(false),
          child: Text(context.l10n.talepReddet),
        ),
      ],
    );
  }
}
