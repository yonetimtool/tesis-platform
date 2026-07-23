import 'package:flutter/material.dart';

import '../domain/task_models.dart';

/// Gorev oncelik (dusuk|orta|yuksek) renk + TR etiket. Bilinmeyen/null -> notr.
/// Renkler complaints paletiyle uyumlu (yesil/amber/kirmizi).
({Color color, String label}) taskOncelikStyle(String? oncelik) => switch (oncelik) {
      'dusuk' => (color: Colors.green, label: 'Düşük'),
      'orta' => (color: Colors.amber.shade800, label: 'Orta'),
      'yuksek' => (color: Colors.red, label: 'Yüksek'),
      _ => (color: Colors.blueGrey, label: 'Öncelik'),
    };

/// "Talepten geldi" rozeti — gorev bir talepten (complaint) donusturulmusse.
/// _KategoriChip stiliyle ayni (icon + pill).
class TalepGeldiChip extends StatelessWidget {
  const TalepGeldiChip({super.key});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF3949AB); // marka indigo (bilgi/baglam)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.report_problem_outlined, size: 14, color: color),
          SizedBox(width: 4),
          Text('Talepten geldi',
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Oncelik rozeti — [taskOncelikStyle] paletiyle (dusuk/orta/yuksek).
class OncelikBadge extends StatelessWidget {
  const OncelikBadge({super.key, required this.oncelik});

  final String? oncelik;

  @override
  Widget build(BuildContext context) {
    final s = taskOncelikStyle(oncelik);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(s.label,
          style: TextStyle(
              color: s.color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Bagli talebin (ticket) kompakt baglam karti — detay ekraninda.
/// _LinkedWorkOrderCard stilinin talep→gorev tersi. Kategori + kisa aciklama +
/// (varsa) daire + durum.
class TicketBaglamKarti extends StatelessWidget {
  const TicketBaglamKarti({super.key, required this.ticket});

  final TicketSummary ticket;

  static const _durumLabel = {
    'acik': 'Açık',
    'is_emri': 'İş Emri',
    'cozuldu': 'Çözüldü',
    'reddedildi': 'Reddedildi',
  };

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF3949AB);
    final scheme = Theme.of(context).colorScheme;
    final alt = <String>[
      if (ticket.kategoriAd != null) ticket.kategoriAd!,
      if (ticket.unitLabel != null) 'Daire ${ticket.unitLabel}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.report_problem_outlined, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Bağlı talep',
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                Text(
                  _durumLabel[ticket.durum] ?? ticket.durum,
                  style:
                      const TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(ticket.baslik,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (alt.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(alt,
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}
