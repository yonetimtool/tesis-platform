import 'package:flutter/material.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/theme/home_tokens.dart';
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
String talepDurumEtiketi(AppLocalizations l10n, String durum) =>
    switch (durum) {
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
    // ZEMIN ham indigo tinti kalir (anlam tasir); METIN temaya gore cozulur.
    // Tur 52: koyu temada ham indigo, %12 tint zemin uzerinde 2.06:1 veriyor
    // (esik 4.5) — `okunurVurgu` 8.46'ya cikarir.
    final metin = okunurVurgu(context, color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.report_problem_outlined, size: 14, color: metin),
          const SizedBox(width: 4),
          // Rozet metni de kisalabilmeli: Fransizca "Issu d'une demande"
          // 320 dp'de satiri 6.5 px tasiriyordu (tur 52). `Wrap` kaba genislik
          // sinirini verir; `Flexible` o sinirda metni sikistirir.
          Flexible(
            child: Text(
              context.l10n.gorevTaleptenGeldi,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: metin,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
    // Zemin ham renk tinti; metin temaya gore (tur 52).
    final metin = okunurVurgu(context, renk);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        oncelikEtiketi(context.l10n, kimlik),
        style: TextStyle(
          color: metin,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
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
    final metin = okunurVurgu(context, color);
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
                Icon(
                  Icons.report_problem_outlined,
                  size: 20,
                  color: metin,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.gorevBagliTalep,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                // DURUM metni de esnek olmali: Fransizca "Ordre de travail"
                // 320 dp'de satiri 6.5 px tasiriyordu (tur 52 — bu kart ilk
                // kez surulunce gorundu).
                Flexible(
                  child: Text(
                    talepDurumEtiketi(l10n, ticket.durum),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: metin,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              ticket.baslik,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (alt.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                alt,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
