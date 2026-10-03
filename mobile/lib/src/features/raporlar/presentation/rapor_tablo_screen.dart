import 'package:flutter/material.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/ui/bos_durum.dart';
import '../domain/rapor_motoru_models.dart';

/// (P253 Asama 2) "GOSTER" CIKTISI — web tablosunun mobil karsiligi.
///
/// Genis tablo telefonda okunmaz (plan §2.1): her satir bir KART, sutunlar
/// "baslik: deger" satirlari. KURUS sutunu TL'ye cevrilir — Excel/PDF ile
/// ayni rakam. Serbest metin bolumu (yaslandirma, ihtar govdesi) ustte.
class RaporTabloScreen extends StatelessWidget {
  const RaporTabloScreen({super.key, required this.tablo});
  final RaporTablo tablo;

  static const _yok = '—';

  String _hucre(RaporSutun s, Object? ham) {
    if (ham == null) return _yok;
    if (s.tip == 'kurus' && ham is num) return tlTutar(ham.toInt());
    return '$ham';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ikincil = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: Text(tablo.baslik)),
      body: tablo.satirlar.isEmpty && (tablo.metin ?? '').isEmpty
          ? BosDurum(
              ikon: Icons.table_rows_outlined,
              baslik: l10n.rprSatirYok,
              aciklama: l10n.rprSatirYokAlt,
            )
          : ListView(
              key: const Key('rpr-tablo'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if ((tablo.metin ?? '').isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(tablo.metin!),
                    ),
                  ),
                for (final satir in tablo.satirlar)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final s in tablo.sutunlar)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(s.baslik, style: TextStyle(color: ikincil, fontSize: 12)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      _hucre(s, satir[s.anahtar]),
                                      textAlign: s.tip == 'kurus' ? TextAlign.end : TextAlign.start,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
