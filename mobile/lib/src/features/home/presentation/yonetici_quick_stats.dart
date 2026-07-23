import 'package:flutter/material.dart';

import '../../../core/branding/yonetio_logo.dart';
import '../../budget/domain/budget_models.dart';
import 'widgets/section_header.dart';
import 'widgets/stat_tile.dart';

const _green = Color(0xFF16A34A);
const _amber = Color(0xFFD97706);

/// Yonetici ana ekranin "Hızlı Özet" bolumu (referans yonetici.jpeg) —
/// GET /reports/financial-summary verisinden 4 istatistik blogu: Toplam
/// Tahsilat, Tahsilat Orani, Toplam Gelir, Kasa. SAF sunum: [summary]
/// disaridan gelir. [TahsilatOzet] yetki geregi null olabilir → ilgili
/// kutular "—" gosterir (cokme yok).
class YoneticiQuickStats extends StatelessWidget {
  const YoneticiQuickStats({super.key, required this.summary});

  final FinancialSummary summary;

  @override
  Widget build(BuildContext context) {
    final tahsilat = summary.tahsilat;
    final oran = tahsilat?.tahsilatOraniYuzde;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Hızlı Özet'),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: [
            StatTile(
              icon: Icons.payments_outlined,
              value: tahsilat == null
                  ? '—'
                  : '₺${formatKurusAsTl(tahsilat.tahsilatKurus)}',
              label: 'Toplam Tahsilat',
              sublabel: 'Bu Ay',
              accent: _green,
            ),
            StatTile(
              icon: Icons.percent,
              value: oran == null ? '—' : '%$oran',
              label: 'Tahsilat Oranı',
              sublabel: 'Bu Ay',
              accent: _amber,
            ),
            StatTile(
              icon: Icons.trending_up,
              value: '₺${formatKurusAsTl(summary.toplamGelirKurus)}',
              label: 'Toplam Gelir',
              accent: YonetioColors.teal,
            ),
            StatTile(
              icon: Icons.account_balance_outlined,
              value: '₺${formatKurusAsTl(summary.bakiyeKurus)}',
              label: 'Kasa',
              accent: YonetioColors.navy,
            ),
          ],
        ),
      ],
    );
  }
}
