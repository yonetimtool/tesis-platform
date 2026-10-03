import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/bos_durum.dart';
import '../data/rapor_motoru_api.dart';
import '../domain/rapor_motoru_models.dart';

/// Durum suzgeci (null = hepsi) -> liste.
final icraDosyalariProvider =
    FutureProvider.autoDispose.family<List<IcraDosyasi>, String?>(
  (ref, durum) => ref.watch(raporMotoruApiProvider).icraDosyalari(durum: durum),
);

/// (P253 Asama 2) ICRA DOSYALARI — SALT OKUMA (yonetim + denetci).
///
/// Web `/icra` sayfasinin liste gorunumu: dosya no, borclu, acik borc,
/// avukat, veris tarihi, durum. Dosya acma ve durum degistirme web'de
/// kalir (eylem tablosunda ayri satirlar, Asama 3).
class IcraScreen extends ConsumerStatefulWidget {
  const IcraScreen({super.key});

  @override
  ConsumerState<IcraScreen> createState() => _IcraScreenState();
}

class _IcraScreenState extends ConsumerState<IcraScreen> {
  String? _durum;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final liste = ref.watch(icraDosyalariProvider(_durum));
    final ikincil = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: Text(baslikBuyuk(l10n.rprIcraBaslik, context.dilKodu))),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                for (final d in [null, ...icraDurumlari])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: Key('icra-suzgec-${d ?? 'hepsi'}'),
                      label: Text(d == null ? l10n.rprIcraDurumHepsi : icraDurumu(l10n, d)),
                      selected: _durum == d,
                      onSelected: (_) => setState(() => _durum = d),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: liste.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => BosDurum(
                ikon: Icons.error_outline,
                baslik: e is ApiException && e.message.isNotEmpty ? e.message : l10n.ortakBeklenmeyenHata,
                aciklama: l10n.rprIcraBosAlt,
              ),
              data: (items) => items.isEmpty
                  ? BosDurum(
                      ikon: Icons.gavel_outlined,
                      baslik: l10n.rprIcraKayitYok,
                      aciklama: l10n.rprIcraBosAlt,
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref.refresh(icraDosyalariProvider(_durum).future),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final d = items[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              key: Key('icra-${d.id}'),
                              leading: const Icon(Icons.gavel_outlined),
                              title: Text('${d.dosyaNo} · ${d.userAd ?? '—'}'),
                              subtitle: Text(
                                [
                                  '${l10n.rprIcraAcikBorc}: ${tlTutar(d.acikBorcKurus)}',
                                  if ((d.avukat ?? '').isNotEmpty) '${l10n.rprIcraAvukat}: ${d.avukat}',
                                  if (d.verisTarihi != null)
                                    '${l10n.rprIcraVerisTarihi}: ${tarihBicimi(d.verisTarihi!, context.dilKodu)}',
                                ].join('\n'),
                                style: TextStyle(color: ikincil),
                              ),
                              isThreeLine: true,
                              trailing: Chip(
                                label: Text(icraDurumu(l10n, d.durum)),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
