import 'package:flutter/material.dart';

import '../../../core/i18n/l10n.dart';
import '../domain/task_models.dart';
import 'task_tip_style.dart';

/// Oncelik etiketi — KIMLIKTEN cizim aninda cozulur (bkz. task_tip_style.dart).
String oncelikEtiketi(AppLocalizations l10n, TaskOncelik o) => switch (o) {
      TaskOncelik.dusuk => l10n.gorevOncelikDusuk,
      TaskOncelik.orta => l10n.gorevOncelikOrta,
      TaskOncelik.yuksek => l10n.gorevOncelikYuksek,
      TaskOncelik.yok => l10n.gorevOncelik,
    };

/// Talep durumu (wire) -> gorunen metin. Wire degerleri TEKNIK SABITTIR.
String talepDurumEtiketi(AppLocalizations l10n, String durum) => switch (durum) {
      'acik' => l10n.talepDurumAcik,
      'is_emri' => l10n.talepDurumIsEmri,
      'cozuldu' => l10n.talepDurumCozuldu,
      'reddedildi' => l10n.talepDurumReddedildi,
      // Sunucu yeni bir durum eklerse ham deger gosterilir (ekran dusmez).
      _ => durum,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.report_problem_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Text(context.l10n.gorevTaleptenGeldi,
              style: const TextStyle(
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
    final kimlik = taskOncelikKimligi(oncelik);
    final renk = taskOncelikRengi(kimlik);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(oncelikEtiketi(context.l10n, kimlik),
          style: TextStyle(
              color: renk, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Bagli talebin (ticket) kompakt baglam karti — detay ekraninda.
/// _LinkedWorkOrderCard stilinin talep→gorev tersi. Kategori + kisa aciklama +
/// (varsa) daire + durum.
class TicketBaglamKarti extends StatelessWidget {
  const TicketBaglamKarti({super.key, required this.ticket});

  final TicketSummary ticket;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF3949AB);
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final alt = <String>[
      if (ticket.kategoriAd != null) ticket.kategoriAd!,
      if (ticket.unitLabel != null) l10n.gorevDaireEtiket(ticket.unitLabel!),
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
                  child: Text(l10n.gorevBagliTalep,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                Text(
                  talepDurumEtiketi(l10n, ticket.durum),
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
