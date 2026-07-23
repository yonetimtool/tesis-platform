import 'package:flutter/material.dart';

import '../../home/presentation/widgets/section_header.dart';
import '../../home/presentation/widgets/shift_status_card.dart';
import '../domain/shift_models.dart';

/// Ana ekranin "Vardiya Durumu" bolumu (referans) — /shifts tanimlarini yatay
/// [ShiftStatusCard] listesi olarak cizer. Durum SAF hesap: [now] araligin
/// icindeyse AKTİF, degilse PLANLANDI ([Shift.aktifMi]; `now` disaridan →
/// testler deterministik). Bos listede bolum HIC cizilmez.
class VardiyaSection extends StatelessWidget {
  const VardiyaSection({
    super.key,
    required this.vardiyalar,
    required this.now,
    this.onSeeAll,
  });

  final List<Shift> vardiyalar;
  final DateTime now;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (vardiyalar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Vardiya Durumu', onSeeAll: onSeeAll),
        const SizedBox(height: 8),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: vardiyalar.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final v = vardiyalar[i];
              final aktif = v.aktifMi(now);
              return ShiftStatusCard(
                title: v.ad,
                subtitle: '${v.baslangicSaat} - ${v.bitisSaat}',
                status: aktif ? ShiftStatus.aktif : ShiftStatus.planlandi,
                footer: gunTipiLabel(v.gunTipi),
              );
            },
          ),
        ),
      ],
    );
  }
}
