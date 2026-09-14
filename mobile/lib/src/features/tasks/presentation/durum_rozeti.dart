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
    // KOYU TONLAR — WCAG AA (4.5:1) GEREGI.
    //
    // Ilk yazimda Material'in varsayilan `Colors.green/red/blue/grey`
    // tonlari kullanilmisti ve kontrast denetimi 12 puntoda 2.31
    // olculdu — esigin YARISINDAN AZ. Yasli goz dusuk kontrasti zaten
    // zor secer; §2'nin amaci tam da buydu. Tonlar `shade800`e
    // cekildi ve zemin saydamligi dusuruldu.
    final (metin, renk) = switch (durum) {
      TaskDurum.tamamlandi => (l10n.gorevDurumTamamlandi, Colors.green.shade900),
      TaskDurum.gecikti => (l10n.gorevDurumGecikti, Colors.red.shade900),
      TaskDurum.baslandi => (l10n.gorevDurumBaslandi, Colors.blue.shade900),
      TaskDurum.atandi => (l10n.gorevDurumAtandi, Colors.grey.shade800),
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
