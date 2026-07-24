import 'package:flutter/material.dart';

import '../../../../core/theme/home_tokens.dart';
import '../../domain/home_view_models.dart';
import 'home_card.dart';
import 'section_header.dart';

/// Sakin ana ekraninin "Ödeme ve Aidat Durumu" karti (site-sakini.jpeg):
/// TEK beyaz kart, ortada dikey ince ayracla IKI SUTUN.
///
/// Sol sutun: "Bu Ayki Aidat" (12 gri) → tutar (22 bold) + yesil "Ödendi"
/// cipi → "Son Ödeme: ..." (12 gri).
/// Sag sutun: "Gelecek Ödeme" (12 gri) → tarih (18 bold) → tutar (12 gri) →
/// acik mavi zeminli "Geçmiş Ödemeler" butonu.
class OdemeKarti extends StatelessWidget {
  const OdemeKarti({
    super.key,
    required this.ozet,
    required this.onGecmis,
    this.onSeeAll,
  });

  final OdemeOzeti ozet;
  final VoidCallback onGecmis;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Ödeme ve Aidat Durumu', onSeeAll: onSeeAll),
        HomeCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _SolSutun(ozet: ozet)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: VerticalDivider(
                      width: 1, thickness: 1, color: s.divider),
                ),
                Expanded(
                  child: _SagSutun(ozet: ozet, onGecmis: onGecmis),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SolSutun extends StatelessWidget {
  const _SolSutun({required this.ozet});

  final OdemeOzeti ozet;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Bu Ayki Aidat',
            style: HomeText.rowSub.copyWith(color: s.muted)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  ozet.buAyTutar,
                  maxLines: 1,
                  style: HomeText.money.copyWith(color: s.heading),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (ozet.odendi)
              const HomeChip(label: 'Ödendi', accent: HomeTokens.green)
            else
              const HomeChip(label: 'Ödenmedi', accent: HomeTokens.red),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Son Ödeme: ${ozet.sonOdeme}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HomeText.rowSub.copyWith(color: s.muted),
        ),
      ],
    );
  }
}

class _SagSutun extends StatelessWidget {
  const _SagSutun({required this.ozet, required this.onGecmis});

  final OdemeOzeti ozet;
  final VoidCallback onGecmis;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Gelecek Ödeme',
            style: HomeText.rowSub.copyWith(color: s.muted)),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            ozet.gelecekTarih,
            maxLines: 1,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)
                .copyWith(color: s.heading),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          ozet.gelecekTutar,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HomeText.rowSub.copyWith(color: s.muted),
        ),
        const SizedBox(height: 10),
        // Acik mavi zeminli (primary %10) radius-10 buton.
        Material(
          color: HomeTokens.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            key: const Key('gecmis-odemeler'),
            onTap: onGecmis,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.format_list_bulleted,
                      size: 16, color: HomeTokens.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Geçmiş Ödemeler',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HomeText.cardCounter
                          .copyWith(color: HomeTokens.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
