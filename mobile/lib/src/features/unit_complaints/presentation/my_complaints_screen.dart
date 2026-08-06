import 'package:mobile/src/core/error/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/i18n/l10n.dart';
import '../domain/unit_complaint_models.dart';
import 'my_complaints_controller.dart';
import 'kategori_adi.dart';
import '../../../core/theme/home_tokens.dart';

/// "Şikayetlerim" (D-viz Rev-1.1) — sakin KENDI actigi daire sikayetlerini
/// (gitti mi geri bildirimi) gorur: hedef daire + kategori + tarih + durum.
/// Yogunluk/renk YOK; baska sakinlerin kayitlari YOK; complainant (kendisi) YOK.
class MyComplaintsScreen extends ConsumerWidget {
  const MyComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myComplaintsControllerProvider);
    final controller = ref.read(myComplaintsControllerProvider.notifier);

    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.modulSikayetlerim, context.dilKodu)),
        actions: [
          IconButton(
            tooltip: l10n.ortakYenile,
            icon: const Icon(Icons.refresh),
            onPressed: state.loading ? null : controller.refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: _Body(state: state),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final MyComplaintsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final hata = akisHatasiCoz(l10n, state.hataKimligi, state.errorMessage);
    if (hata != null && state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [Center(child: Text(hata))],
      );
    }
    if (state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Text(l10n.sikayetYokSakin, textAlign: TextAlign.center),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: state.items.length,
      itemBuilder: (context, i) => _ComplaintCard(complaint: state.items[i]),
    );
  }
}

class _ComplaintCard extends ConsumerStatefulWidget {
  const _ComplaintCard({required this.complaint});

  final UnitComplaint complaint;

  @override
  ConsumerState<_ComplaintCard> createState() => _ComplaintCardState();
}

class _ComplaintCardState extends ConsumerState<_ComplaintCard> {
  bool _calisiyor = false;

  /// (P146) Geri alma TERMINALDIR — once onay sorulur, sonra sunucuya
  /// gidilir. Basarisizlik SnackBar'a yazilir; sessiz basarisizlik yok.
  Future<void> _geriAl() async {
    final l10n = context.l10n;
    final onay = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.sikayetGeriAl),
        content: Text(l10n.talepGeriAlOnay),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: Text(l10n.ortakVazgec),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: Text(l10n.sikayetGeriAl),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    setState(() => _calisiyor = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(myComplaintsControllerProvider.notifier)
          .withdraw(widget.complaint.id);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.sikayetGeriAlindi)));
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
    if (mounted) setState(() => _calisiyor = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.complaint;
    final acik = c.acik;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          acik ? Icons.hourglass_bottom_outlined : Icons.check_circle_outline,
          color: acik ? Colors.orange : Colors.green,
        ),
        title: Text(
          context.l10n.sikayetSatirBaslik(
            c.unitNo ?? '-',
            unitComplaintKategoriAdi(context.l10n, c.kategori),
          ),
        ),
        subtitle: Text(tarihSaatBicimi(c.createdAt, context.dilKodu)),
        // (P146) Geri alma YALNIZ acik sikayette: yonetim kapattiktan
        // sonra karar verilmis kaydi sahibi tek tarafli degistiremez.
        trailing: acik
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DurumChip(acik: acik),
                  IconButton(
                    onPressed: _calisiyor ? null : _geriAl,
                    icon: const Icon(Icons.undo),
                    tooltip: context.l10n.sikayetGeriAl,
                  ),
                ],
              )
            : _DurumChip(acik: acik),
      ),
    );
  }
}

class _DurumChip extends StatelessWidget {
  const _DurumChip({required this.acik});

  final bool acik;

  @override
  Widget build(BuildContext context) {
    final color = acik ? Colors.orange : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        acik ? context.l10n.talepDurumAcik : context.l10n.sikayetDurumKapandi,
        style: TextStyle(
          color: okunurVurgu(context, color),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
