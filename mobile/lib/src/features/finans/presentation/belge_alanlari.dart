/// (P253 Asama 1) Tahsilat ve gider/gelir formlarinin ORTAK alanlari:
/// islem TARIHI ve BELGE NO — web hareket formuyla ayni (`hareket-modali`).
///
/// Belge no BOS birakilabilir: sunucu merkezi seriyi kendisi uretir
/// (`belge_no.py`). Bos dize gondermek "kullanici bir sey yazdi" gibi
/// okunurdu; cagiran bos metni `null` gonderir.
library;

import 'package:flutter/material.dart';

import '../../../core/girdi_siniri.dart';
import '../../../core/i18n/l10n.dart';

/// Sunucu `belge_no` siniri (HareketSatir / TahsilatCreate): 50.
const belgeNoAzami = 50;

class TarihBelgeAlanlari extends StatelessWidget {
  const TarihBelgeAlanlari({
    super.key,
    required this.anahtarOnEki,
    required this.tarih,
    required this.onTarih,
    required this.belgeNo,
  });

  /// Test anahtarlari icin (`tahsilat` / `gider`).
  final String anahtarOnEki;
  final DateTime tarih;
  final ValueChanged<DateTime> onTarih;
  final TextEditingController belgeNo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          key: Key('$anahtarOnEki-tarih'),
          icon: const Icon(Icons.event_outlined),
          label: Text(l10n.finTarihDegeri(tarihBicimi(tarih, context.dilKodu))),
          onPressed: () async {
            final simdi = DateTime.now();
            final secilen = await showDatePicker(
              context: context,
              initialDate: tarih,
              firstDate: DateTime(simdi.year - 5),
              lastDate: DateTime(simdi.year + 1, 12, 31),
            );
            if (secilen != null) onTarih(secilen);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          key: Key('$anahtarOnEki-belge-no'),
          controller: belgeNo,
          maxLength: belgeNoAzami,
          inputFormatters: GirdiSiniri.sinir(belgeNoAzami),
          decoration: InputDecoration(
            labelText: l10n.finBelgeNo,
            helperText: l10n.finBelgeNoIpucu,
            counterText: '',
          ),
        ),
      ],
    );
  }
}

/// Bos metni `null` yapar (sunucu seriyi uretsin).
String? bosIseNull(String metin) {
  final t = metin.trim();
  return t.isEmpty ? null : t;
}
