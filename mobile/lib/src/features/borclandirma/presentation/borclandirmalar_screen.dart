/// (P253 Asama 2) BORCLANDIRMALAR — web `finans/borclandirmalar` karsiligi.
///
/// Liste (`ListeEkrani`, sunucu sayfalamasi + tur suzgeci), karta dokununca
/// ayrinti + ters kayit (§C, sebep zorunlu). Ust cubukta etiketli girisler:
/// gecikme faizi ve toplu tahakkuk sihirbazi; FAB tek daire borclandirma.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/ui/liste_ekrani.dart';
import '../../../routing/app_router.dart';
import '../data/borclandirma_api.dart';
import '../domain/borclandirma_models.dart';
import 'borc_etiketleri.dart';
import 'gecikme_faizi.dart';
import 'tahakkuk_islemleri.dart';
import 'tekil_borclandirma.dart';

class BorclandirmalarScreen extends ConsumerStatefulWidget {
  const BorclandirmalarScreen({super.key});

  @override
  ConsumerState<BorclandirmalarScreen> createState() => _BorclandirmalarState();
}

class _BorclandirmalarState extends ConsumerState<BorclandirmalarScreen> {
  final _liste = GlobalKey<ListeEkraniState<Tahakkuk>>();

  void _tazele() => _liste.currentState?.yenile();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final api = ref.watch(borclandirmaApiProvider);
    final daireler = ref.watch(borcDairelerProvider).value ?? const [];
    final daireNo = {for (final d in daireler) d.id: d.no};
    final turler = ref.watch(borcTurleriProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.webBorclandirmalar, context.dilKodu)),
        actions: [
          TextButton.icon(
            key: const Key('brc-faiz-ac'),
            icon: const Icon(Icons.percent_outlined),
            label: Text(l10n.brcFaiz),
            onPressed: () async {
              final oldu = await gecikmeFaiziAc(context);
              if (oldu == true) _tazele();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('brc-tekil-ac'),
        icon: const Icon(Icons.add),
        label: Text(l10n.brcTekil),
        onPressed: () async {
          final oldu = await tekilBorclandirmaAc(context);
          if (oldu == true) _tazele();
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('brc-toplu-ac'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.playlist_add_outlined),
                label: Text(l10n.brcToplu),
                onPressed: () async {
                  final oldu = await context.push<bool>(AppRoutes.topluTahakkuk);
                  if (oldu == true) _tazele();
                },
              ),
            ),
          ),
          Expanded(
            child: ListeEkrani<Tahakkuk>(
              key: _liste,
              kimlik: (t) => t.id,
              suzgecler: [
                if (turler.isNotEmpty)
                  SuzgecTanimi(
                    ad: 'tur',
                    etiket: (l) => l.brcTur,
                    secenekler: [for (final t in turler) SuzgecSecenegi(t.id, (_) => t.ad)],
                  ),
              ],
              bosMetin: (l) => l.brcYok,
              yukle: (s) async {
                final r = await api.tahakkuklar(
                  limit: s.limit,
                  offset: s.offset,
                  tanimId: s.suzgec['tur'],
                );
                return ListeSayfasi(r.items, toplam: r.toplam);
              },
              kart: (context, t, _) => _TahakkukKarti(t: t, daireNo: daireNo[t.unitId]),
              onDokun: (t) async {
                final oldu = await tahakkukAyrintisi(context, t, daireNo: daireNo[t.unitId]);
                if (oldu == true) _tazele();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TahakkukKarti extends StatelessWidget {
  const _TahakkukKarti({required this.t, this.daireNo});

  final Tahakkuk t;
  final String? daireNo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final soluk = t.iptalEdildi || t.tersKayitId != null;
    return Card(
      key: Key('brc-kart-${t.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(
          hedefMetni([daireNo, t.hedefAd]),
          style: soluk ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant) : null,
        ),
        subtitle: Text(hedefMetni([
          t.tanimAd ?? kalemTipiAdi(l10n, t.kalemTipi),
          l10n.brcDonem(t.donem),
          if (t.iptalEdildi) l10n.brcDuzeltildi,
          if (t.tersKayitId != null) l10n.brcDuzeltme,
        ])),
        trailing: Text(tlTutar(t.tutarKurus), style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
