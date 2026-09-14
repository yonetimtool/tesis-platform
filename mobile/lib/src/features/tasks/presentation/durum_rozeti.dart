import 'package:flutter/material.dart';

import '../../../core/i18n/l10n.dart';
import '../domain/task_models.dart';

/// (P230 §4) Durum rozeti — RENK TEK BASINA YETMEZ.
///
/// Yalniz renkle ayrilan bir rozet, renk korlugu olan kullanicida ve ekran
/// okuyucuda HICBIR SEY soylemez (depo kurali; `Rozet` bileseninin web
/// tarafindaki gerekcesiyle ayni). Bu yuzden metin de yazilir.
class DurumRozeti extends StatelessWidget {
  const DurumRozeti({super.key, required this.durum, this.gecikmeGun});

  final TaskDurum durum;
  final int? gecikmeGun;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (metin, renk) = switch (durum) {
      TaskDurum.tamamlandi => (l10n.gorevDurumTamamlandi, Colors.green),
      TaskDurum.gecikti => (l10n.gorevDurumGecikti, Colors.red),
      TaskDurum.baslandi => (l10n.gorevDurumBaslandi, Colors.blue),
      TaskDurum.atandi => (l10n.gorevDurumAtandi, Colors.grey),
    };
    final ek = durum == TaskDurum.gecikti && gecikmeGun != null
        ? ' ${l10n.gorevGecikmeGun(gecikmeGun!)}'
        : '';
    return Container(
      key: Key('gorev-durum-${durum.wire}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: renk.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$metin$ek',
        style: TextStyle(
          color: renk,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
