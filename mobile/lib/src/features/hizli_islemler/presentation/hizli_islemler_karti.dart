/// (P250 §6) HIZLI İŞLEMLER kartı — yönetici ana ekranı (web özet kartının
/// ikizi). Kullanıcının seçtiği işlemler, seçtiği sırayla. "Özelleştir"
/// seçim/sıralama ekranını açar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/l10n.dart';
import '../data/hizli_islemler_api.dart';
import 'hizli_islemler_ozellestir_screen.dart';

class HizliIslemlerKarti extends ConsumerWidget {
  const HizliIslemlerKarti({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final veri = ref.watch(hizliIslemlerProvider).value;
    if (veri == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final gorunen = [
      for (final k in veri.secili)
        if (hizliIslemKatalogu[k] != null) k,
    ];
    return Card(
      key: const Key('hizli-islemler-karti'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.panoHizliIslemler,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  key: const Key('hizli-ozellestir'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HizliIslemlerOzellestirScreen(),
                    ),
                  ),
                  child: Text(l10n.panoHizliOzellestir),
                ),
              ],
            ),
            if (gorunen.isEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: Text(l10n.panoHizliBos),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in gorunen)
                    OutlinedButton.icon(
                      key: Key('hizli-$k'),
                      onPressed: () =>
                          context.push(hizliIslemKatalogu[k]!.rota),
                      icon: Icon(hizliIslemKatalogu[k]!.ikon, size: 18),
                      label: Text(hizliIslemKatalogu[k]!.etiket(l10n)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
