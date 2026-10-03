import 'package:flutter/material.dart';

import '../../../core/girdi_siniri.dart';
import '../../../core/i18n/l10n.dart';

/// (P253 Asama 1) Kisi listelerinin ORTAK arama + durum suzgeci (web
/// Kisiler listesindeki arama kutusu ve Aktif/Pasif secimi).
enum KisiDurumSuzgeci { tumu, aktif, pasif }

/// Ad icinde (buyuk/kucuk harf duyarsiz, Turkce I/i dahil) arar; durumu suzer.
List<T> kisiSuz<T>(
  List<T> liste,
  String ara,
  KisiDurumSuzgeci durum, {
  required String Function(T) ad,
  required bool Function(T) aktif,
}) {
  String norm(String s) => s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
  final q = norm(ara.trim());
  return [
    for (final k in liste)
      if ((q.isEmpty || norm(ad(k)).contains(q)) &&
          switch (durum) {
            KisiDurumSuzgeci.tumu => true,
            KisiDurumSuzgeci.aktif => aktif(k),
            KisiDurumSuzgeci.pasif => !aktif(k),
          })
        k,
  ];
}

class KisiSuzgecSeridi extends StatelessWidget {
  const KisiSuzgecSeridi({
    super.key,
    required this.ara,
    required this.durum,
    required this.onDegisti,
    required this.onAra,
  });

  final TextEditingController ara;
  final KisiDurumSuzgeci durum;
  final ValueChanged<KisiDurumSuzgeci> onDegisti;
  final VoidCallback onAra;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('kisi-ara'),
            controller: ara,
            maxLength: GirdiSiniri.arama,
            onChanged: (_) => onAra(),
            decoration: InputDecoration(
              hintText: l10n.kisiAra,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              counterText: '',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final d in KisiDurumSuzgeci.values)
                ChoiceChip(
                  key: Key('kisi-durum-${d.name}'),
                  label: Text(switch (d) {
                    KisiDurumSuzgeci.tumu => l10n.kisTumu,
                    KisiDurumSuzgeci.aktif => l10n.ortakAktif,
                    KisiDurumSuzgeci.pasif => l10n.ortakPasif,
                  }),
                  selected: durum == d,
                  onSelected: (_) => onDegisti(d),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
