import 'package:flutter/material.dart';

import '../../budget/domain/budget_models.dart' show formatKurusAsTl;
import '../../dues/domain/dues_models.dart';
import 'widgets/section_header.dart';

const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);

/// Sakin ana ekranin "Ödeme ve Aidat Durumu" karti (site-sakini.jpeg) —
/// GET /me/dues verisinden: dairelerin toplam bakiyesi. Borcsuzsa yesil
/// "Borç Yok" cipi; borcluysa kirmizi toplam. "Geçmiş Ödemeler" detaya
/// goturur ([onDetay] → /my-dues). Daire listesi bos ise kart HIC cizilmez.
class AidatOzetKarti extends StatelessWidget {
  const AidatOzetKarti({
    super.key,
    required this.units,
    required this.onDetay,
  });

  final List<MyDuesUnit> units;
  final VoidCallback onDetay;

  @override
  Widget build(BuildContext context) {
    if (units.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final toplamBorc =
        units.fold<int>(0, (t, u) => t + (u.bakiyeKurus > 0 ? u.bakiyeKurus : 0));
    final borcVar = toplamBorc > 0;
    final daireler = units.map((u) => u.no).join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Ödeme ve Aidat Durumu'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daire $daireler',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                ),
                const SizedBox(height: 8),
                // Dar ekranda tasmasin: deger/cip Expanded, buton kompakt.
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: borcVar
                            ? FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '₺${formatKurusAsTl(toplamBorc)}',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: _red),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Borç Yok',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                      color: _green,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: onDetay,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('Geçmiş Ödemeler', maxLines: 1),
                    ),
                  ],
                ),
                if (borcVar) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Toplam borç',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
