import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/text/tr_upper.dart';
import '../domain/unit_complaint_models.dart';
import 'my_complaints_controller.dart';

/// "Şikayetlerim" (D-viz Rev-1.1) — sakin KENDI actigi daire sikayetlerini
/// (gitti mi geri bildirimi) gorur: hedef daire + kategori + tarih + durum.
/// Yogunluk/renk YOK; baska sakinlerin kayitlari YOK; complainant (kendisi) YOK.
class MyComplaintsScreen extends ConsumerWidget {
  const MyComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myComplaintsControllerProvider);
    final controller = ref.read(myComplaintsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(trUpper('Şikayetlerim')),
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
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [Center(child: Text(state.errorMessage!))],
      );
    }
    if (state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Center(
            child: Text(
              'Henüz şikayet açmadınız.\nŞikayet Haritası’ndan bir daire seçip '
              'şikayet edebilirsiniz.',
              textAlign: TextAlign.center,
            ),
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

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.complaint});

  final UnitComplaint complaint;

  @override
  Widget build(BuildContext context) {
    final c = complaint;
    final acik = c.acik;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          acik ? Icons.hourglass_bottom_outlined : Icons.check_circle_outline,
          color: acik ? Colors.orange : Colors.green,
        ),
        title: Text('Daire ${c.unitNo ?? '-'} · ${c.kategori.label}'),
        subtitle: Text(_fmtDate(c.createdAt.toLocal())),
        trailing: _DurumChip(acik: acik),
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
        acik ? 'Açık' : 'Kapandı',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

String _fmtDate(DateTime dt) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(dt.day)}.${p(dt.month)}.${dt.year} ${p(dt.hour)}:${p(dt.minute)}';
}
