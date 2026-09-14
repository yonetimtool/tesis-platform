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
    // TEMA DUYARLI TONLAR — WCAG AA (4.5:1) HER IKI TEMADA.
    //
    // IKI KEZ OLCULDU, IKISINDE DE DUSTU:
    //   1. Material varsayilanlari (`Colors.green/red/...`) -> ACIK
    //      temada 2.31 (esigin yarisindan az).
    //   2. `shade900` -> acik temada gecti ama KOYU temada 1.65: koyu
    //      zemin (0.11) uzerinde koyu metin okunmuyor.
    // Yasli goz dusuk kontrasti zaten zor secer; §2'nin amaci tam da
    // buydu. Ton artik temaya gore secilir: acik temada `shade900`,
    // koyu temada `shade200`.
    final koyuTema = Theme.of(context).brightness == Brightness.dark;
    MaterialColor tabanRenk = switch (durum) {
      TaskDurum.tamamlandi => Colors.green,
      TaskDurum.gecikti => Colors.red,
      TaskDurum.baslandi => Colors.blue,
      TaskDurum.atandi => Colors.grey,
    };
    final renk = koyuTema ? tabanRenk.shade200 : tabanRenk.shade900;
    final metin = switch (durum) {
      TaskDurum.tamamlandi => l10n.gorevDurumTamamlandi,
      TaskDurum.gecikti => l10n.gorevDurumGecikti,
      TaskDurum.baslandi => l10n.gorevDurumBaslandi,
      TaskDurum.atandi => l10n.gorevDurumAtandi,
    };
    final ek = durum == TaskDurum.gecikti && gecikmeGun != null
        ? ' ${l10n.gorevGecikmeGun(gecikmeGun!)}'
        : '';
    return Container(
      key: Key('gorev-durum-${durum.wire}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.08),
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
